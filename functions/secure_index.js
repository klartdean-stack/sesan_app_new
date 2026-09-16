const legacy = require("./index.js");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");

if (admin.apps.length === 0) {
  admin.initializeApp();
}

const db = admin.firestore();

const ADMIN_UIDS = new Set(["WBdQVvrgEIPBTcgIlumu6bAZGUl2"]);
const ADMIN_PHONE_NUMBERS = new Set(["+85511930717", "011930717"]);
const FIVE_DAYS_MS = 5 * 24 * 60 * 60 * 1000;

function normalizeKhPhone(value) {
  const raw = String(value ?? "").replace(/[\s-]/g, "");
  if (raw.startsWith("+855")) return raw;
  if (raw.startsWith("0")) return `+855${raw.substring(1)}`;
  return raw;
}

function assertAdmin(request) {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "សូមចូលគណនីជាមុនសិន!");
  }

  if (ADMIN_UIDS.has(request.auth.uid)) {
    return request.auth.uid;
  }

  const tokenPhone = normalizeKhPhone(request.auth.token?.phone_number);
  const allowed = [...ADMIN_PHONE_NUMBERS].map(normalizeKhPhone);
  if (tokenPhone && allowed.includes(tokenPhone)) {
    return request.auth.uid;
  }

  throw new HttpsError("permission-denied", "អ្នកមិនមានសិទ្ធិ Admin ទេ!");
}

exports.secureWithdraw = onCall({ region: "asia-southeast1" }, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "សូមចូលគណនីជាមុនសិន!");
  }

  const uid = request.auth.uid;
  const amount = Number(request.data?.amount);
  const pin = String(request.data?.pin ?? "").trim();

  if (!Number.isFinite(amount) || amount <= 0) {
    throw new HttpsError("invalid-argument", "ចំនួនទឹកប្រាក់មិនត្រឹមត្រូវ!");
  }

  if (!pin) {
    throw new HttpsError("invalid-argument", "សូមបញ្ចូលលេខសម្ងាត់!");
  }

  const userRef = db.collection("users").doc(uid);
  const requestRef = db.collection("withdraw_requests").doc();

  await db.runTransaction(async (tx) => {
    const userSnap = await tx.get(userRef);
    if (!userSnap.exists) {
      throw new HttpsError("not-found", "រកមិនឃើញគណនីអ្នកប្រើ!");
    }

    const userData = userSnap.data() || {};
    const savedPin = String(userData.password ?? "");
    if (!savedPin || savedPin !== pin) {
      throw new HttpsError("permission-denied", "លេខសម្ងាត់មិនត្រឹមត្រូវ!");
    }

    const available = Number(userData.available_balance ?? 0);
    const reserved = Number(userData.reserved_withdraw_balance ?? 0);
    const spendable = available - reserved;

    if (!Number.isFinite(available) || !Number.isFinite(reserved)) {
      throw new HttpsError("failed-precondition", "ទិន្នន័យសមតុល្យមិនត្រឹមត្រូវ!");
    }

    if (amount > spendable) {
      throw new HttpsError("failed-precondition", "ទឹកប្រាក់អាចដកបានមិនគ្រប់គ្រាន់!");
    }

    const sellerName = String(
      userData.full_name_kh || userData.full_name || userData.name || ""
    ).trim();
    const bankName = String(userData.bank_name || "ABA").trim();
    const accountNumber = String(userData.bank_account_number || "").trim();
    const khqrUrl = String(userData.bank_qr_url || "").trim();

    if (!accountNumber) {
      throw new HttpsError(
        "failed-precondition",
        "សូមបំពេញលេខគណនីធនាគារជាមុនសិន!"
      );
    }

    tx.set(requestRef, {
      user_id: uid,
      seller_id: uid,
      seller_name: sellerName,
      bank_name: bankName,
      account_name: sellerName,
      account_number: accountNumber,
      khqr_url: khqrUrl,
      method: bankName,
      amount,
      status: "pending",
      created_at: admin.firestore.FieldValue.serverTimestamp(),
      reserved_amount: amount,
      reserve_settled: false,
      created_via: "secureWithdraw",
    });

    tx.set(
      userRef,
      {
        reserved_withdraw_balance: admin.firestore.FieldValue.increment(amount),
      },
      { merge: true }
    );
  });

  return { success: true, requestId: requestRef.id };
});

exports.secureApproveWithdrawal = onCall(
  { region: "asia-southeast1" },
  async (request) => {
    const adminUid = assertAdmin(request);
    const requestId = String(request.data?.requestId ?? "").trim();
    const receiptUrl = String(request.data?.receiptUrl ?? "").trim();

    if (!requestId) {
      throw new HttpsError("invalid-argument", "Missing requestId");
    }

    const withdrawRef = db.collection("withdraw_requests").doc(requestId);

    await db.runTransaction(async (tx) => {
      const withdrawSnap = await tx.get(withdrawRef);
      if (!withdrawSnap.exists) {
        throw new HttpsError("not-found", "Withdrawal request not found");
      }

      const data = withdrawSnap.data() || {};
      if (data.status !== "pending") {
        throw new HttpsError("failed-precondition", "Withdrawal request is not pending");
      }

      const sellerId = String(data.seller_id || data.user_id || "").trim();
      const amount = Number(data.amount);
      const reservedAmount = Number(data.reserved_amount ?? amount);
      const reserveSettled = data.reserve_settled === true;

      if (!sellerId || !Number.isFinite(amount) || amount <= 0) {
        throw new HttpsError("failed-precondition", "Invalid withdrawal data");
      }

      const userRef = db.collection("users").doc(sellerId);
      const userSnap = await tx.get(userRef);
      if (!userSnap.exists) {
        throw new HttpsError("not-found", "Seller account not found");
      }

      const userData = userSnap.data() || {};
      const available = Number(userData.available_balance ?? 0);
      if (!Number.isFinite(available) || available < amount) {
        throw new HttpsError("failed-precondition", "Insufficient available balance");
      }

      const userUpdate = {
        available_balance: admin.firestore.FieldValue.increment(-amount),
        total_withdraw: admin.firestore.FieldValue.increment(amount),
      };

      const withdrawUpdate = {
        status: "success",
        admin_receipt: receiptUrl,
        approved_at: admin.firestore.FieldValue.serverTimestamp(),
        approved_by_uid: adminUid,
        approved_via: "secureApproveWithdrawal",
      };

      if (!reserveSettled && Number.isFinite(reservedAmount) && reservedAmount > 0) {
        const currentReserved = Number(userData.reserved_withdraw_balance ?? 0);
        if (!Number.isFinite(currentReserved) || currentReserved < reservedAmount) {
          throw new HttpsError("failed-precondition", "Reserved withdrawal balance is invalid");
        }
        userUpdate.reserved_withdraw_balance = admin.firestore.FieldValue.increment(-reservedAmount);
        withdrawUpdate.reserve_settled = true;
        withdrawUpdate.reserve_settled_at = admin.firestore.FieldValue.serverTimestamp();
      }

      tx.set(userRef, userUpdate, { merge: true });
      tx.update(withdrawRef, withdrawUpdate);
    });

    return { success: true };
  }
);

exports.secureRejectWithdrawal = onCall(
  { region: "asia-southeast1" },
  async (request) => {
    const adminUid = assertAdmin(request);
    const requestId = String(request.data?.requestId ?? "").trim();

    if (!requestId) {
      throw new HttpsError("invalid-argument", "Missing requestId");
    }

    const withdrawRef = db.collection("withdraw_requests").doc(requestId);

    await db.runTransaction(async (tx) => {
      const withdrawSnap = await tx.get(withdrawRef);
      if (!withdrawSnap.exists) {
        throw new HttpsError("not-found", "Withdrawal request not found");
      }

      const data = withdrawSnap.data() || {};
      if (data.status !== "pending") {
        throw new HttpsError("failed-precondition", "Withdrawal request is not pending");
      }

      const sellerId = String(data.seller_id || data.user_id || "").trim();
      const amount = Number(data.amount);
      const reservedAmount = Number(data.reserved_amount ?? amount);
      const reserveSettled = data.reserve_settled === true;

      if (!sellerId || !Number.isFinite(amount) || amount <= 0) {
        throw new HttpsError("failed-precondition", "Invalid withdrawal data");
      }

      const withdrawUpdate = {
        status: "rejected",
        rejected_at: admin.firestore.FieldValue.serverTimestamp(),
        rejected_by_uid: adminUid,
        rejected_via: "secureRejectWithdrawal",
      };

      if (!reserveSettled && Number.isFinite(reservedAmount) && reservedAmount > 0) {
        const userRef = db.collection("users").doc(sellerId);
        const userSnap = await tx.get(userRef);
        if (!userSnap.exists) {
          throw new HttpsError("not-found", "Seller account not found");
        }

        const userData = userSnap.data() || {};
        const currentReserved = Number(userData.reserved_withdraw_balance ?? 0);
        if (!Number.isFinite(currentReserved) || currentReserved < reservedAmount) {
          throw new HttpsError("failed-precondition", "Reserved withdrawal balance is invalid");
        }

        tx.set(
          userRef,
          {
            reserved_withdraw_balance: admin.firestore.FieldValue.increment(-reservedAmount),
          },
          { merge: true }
        );

        withdrawUpdate.reserve_settled = true;
        withdrawUpdate.reserve_settled_at = admin.firestore.FieldValue.serverTimestamp();
      }

      tx.update(withdrawRef, withdrawUpdate);
    });

    return { success: true };
  }
);

exports.settleWithdrawReserve = onDocumentUpdated(
  {
    document: "withdraw_requests/{requestId}",
    region: "asia-southeast1",
  },
  async (event) => {
    const before = event.data.before.data() || {};
    const after = event.data.after.data() || {};

    if (before.status === after.status) return;
    if (after.reserve_settled === true) return;
    if (!["success", "rejected"].includes(after.status)) return;

    const sellerId = String(after.seller_id || after.user_id || "").trim();
    const amount = Number(after.reserved_amount ?? after.amount ?? 0);
    if (!sellerId || !Number.isFinite(amount) || amount <= 0) return;

    const userRef = db.collection("users").doc(sellerId);
    const withdrawRef = event.data.after.ref;

    await db.runTransaction(async (tx) => {
      const latestWithdraw = await tx.get(withdrawRef);
      const latest = latestWithdraw.data() || {};
      if (latest.reserve_settled === true) return;
      if (!["success", "rejected"].includes(latest.status)) return;

      const userSnap = await tx.get(userRef);
      if (!userSnap.exists) return;
      const userData = userSnap.data() || {};
      const currentReserved = Number(userData.reserved_withdraw_balance ?? 0);
      if (!Number.isFinite(currentReserved) || currentReserved < amount) return;

      tx.set(
        userRef,
        {
          reserved_withdraw_balance: admin.firestore.FieldValue.increment(-amount),
        },
        { merge: true }
      );
      tx.update(withdrawRef, {
        reserve_settled: true,
        reserve_settled_at: admin.firestore.FieldValue.serverTimestamp(),
        reserve_settled_via: "settleWithdrawReserve",
      });
    });
  }
);

// Legacy test trigger previously moved seller money whenever any order document was updated.
// Keep the deployed function name/trigger shape, but make it a no-op so there is only one
// authoritative settlement path.
exports.testWalletNow = onDocumentUpdated(
  {
    document: "orders/{orderId}",
    region: "asia-southeast1",
  },
  async (event) => {
    console.log(
      "testWalletNow disabled; settlement handled only by scheduledWalletSettlement",
      event.params?.orderId || ""
    );
  }
);

// Authoritative seller settlement: runs hourly and moves eligible earnings from
// wallet_balance -> available_balance exactly once, inside one Firestore transaction.
exports.scheduledWalletSettlement = onSchedule(
  {
    schedule: "0 * * * *",
    timeZone: "Asia/Phnom_Penh",
    region: "asia-southeast1",
  },
  async () => {
    const cutoffMillis = Date.now() - FIVE_DAYS_MS;

    // Single-field query avoids requiring a composite index. We filter packing_date
    // in code and cap each run so one bad/large dataset cannot exhaust the function.
    const candidates = await db
      .collection("orders")
      .where("is_settled", "==", false)
      .limit(200)
      .get();

    let settledCount = 0;
    let skippedCount = 0;

    for (const orderDoc of candidates.docs) {
      try {
        const result = await db.runTransaction(async (tx) => {
          const orderRef = orderDoc.ref;
          const freshOrderSnap = await tx.get(orderRef);
          if (!freshOrderSnap.exists) return "missing-order";

          const order = freshOrderSnap.data() || {};
          if (order.is_settled !== false) return "already-settled";

          const packingTimestamp = order.packing_date;
          if (!(packingTimestamp instanceof admin.firestore.Timestamp)) {
            return "missing-packing-date";
          }
          if (packingTimestamp.toMillis() > cutoffMillis) {
            return "not-due";
          }

          const sellerId = String(order.seller_id || "").trim();
          const earnings = Number(order.seller_earnings);
          if (!sellerId || !Number.isFinite(earnings) || earnings <= 0) {
            return "invalid-order-money";
          }

          const userRef = db.collection("users").doc(sellerId);
          const userSnap = await tx.get(userRef);
          if (!userSnap.exists) return "missing-seller";

          const user = userSnap.data() || {};
          const walletBalance = Number(user.wallet_balance ?? 0);
          const availableBalance = Number(user.available_balance ?? 0);
          if (!Number.isFinite(walletBalance) || !Number.isFinite(availableBalance)) {
            return "invalid-user-balance";
          }
          if (walletBalance < earnings) {
            console.error("Settlement blocked: wallet_balance is smaller than earnings", {
              orderId: orderRef.id,
              sellerId,
              walletBalance,
              earnings,
            });
            return "insufficient-wallet-balance";
          }

          tx.set(
            userRef,
            {
              wallet_balance: admin.firestore.FieldValue.increment(-earnings),
              available_balance: admin.firestore.FieldValue.increment(earnings),
            },
            { merge: true }
          );

          tx.update(orderRef, {
            is_settled: true,
            settled_at: admin.firestore.FieldValue.serverTimestamp(),
            settlement_via: "scheduledWalletSettlement",
          });

          return "settled";
        });

        if (result === "settled") {
          settledCount += 1;
        } else {
          skippedCount += 1;
        }
      } catch (error) {
        skippedCount += 1;
        console.error("Settlement transaction failed", {
          orderId: orderDoc.id,
          error: error?.message || String(error),
        });
      }
    }

    console.log("scheduledWalletSettlement finished", {
      checked: candidates.size,
      settled: settledCount,
      skipped: skippedCount,
    });
  }
);

for (const [name, fn] of Object.entries(legacy)) {
  if (!(name in exports)) {
    exports[name] = fn;
  }
}
