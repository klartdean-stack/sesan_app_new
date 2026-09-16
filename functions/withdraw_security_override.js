const crypto = require("crypto");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

if (admin.apps.length === 0) admin.initializeApp();
const db = admin.firestore();
const ADMIN_UIDS = new Set(["WBdQVvrgEIPBTcgIlumu6bAZGUl2"]);
const MIN_WITHDRAW_RIEL = 5000;

function requireAuth(request) {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "សូមចូលគណនីជាមុនសិន!");
  }
  return request.auth.uid;
}

function requireAdmin(request) {
  const uid = requireAuth(request);
  if (!ADMIN_UIDS.has(uid)) {
    throw new HttpsError("permission-denied", "អ្នកមិនមានសិទ្ធិ Admin ទេ!");
  }
  return uid;
}

function hashPin(pin, saltHex) {
  return crypto.scryptSync(pin, Buffer.from(saltHex, "hex"), 32).toString("hex");
}

function timingSafeEqualHex(a, b) {
  try {
    const aa = Buffer.from(String(a || ""), "hex");
    const bb = Buffer.from(String(b || ""), "hex");
    return aa.length === bb.length && aa.length > 0 && crypto.timingSafeEqual(aa, bb);
  } catch (_) {
    return false;
  }
}

exports.secureWithdraw = onCall(
  { region: "asia-southeast1" },
  async (request) => {
    const uid = requireAuth(request);
    const amount = Number(request.data?.amount);
    const pin = String(request.data?.pin ?? "").trim();

    if (!Number.isSafeInteger(amount) || amount < MIN_WITHDRAW_RIEL) {
      throw new HttpsError(
        "invalid-argument",
        `ចំនួនដកត្រូវតែជាចំនួនរៀលគត់ និងចាប់ពី ${MIN_WITHDRAW_RIEL.toLocaleString("en-US")}៛ ឡើងទៅ`
      );
    }
    if (!/^\d{6}$/.test(pin)) {
      throw new HttpsError("invalid-argument", "លេខសម្ងាត់ត្រូវមាន ៦ ខ្ទង់");
    }

    const userRef = db.collection("users").doc(uid);
    const lockRef = db.collection("withdraw_locks").doc(uid);
    const requestRef = db.collection("withdraw_requests").doc();

    await db.runTransaction(async (tx) => {
      const [userSnap, lockSnap] = await Promise.all([
        tx.get(userRef),
        tx.get(lockRef),
      ]);

      if (!userSnap.exists) {
        throw new HttpsError("not-found", "រកមិនឃើញគណនីអ្នកប្រើ!");
      }

      if (lockSnap.exists) {
        const lock = lockSnap.data() || {};
        if (lock.active === true) {
          throw new HttpsError(
            "failed-precondition",
            "អ្នកមានសំណើដកប្រាក់កំពុងរង់ចាំរួចហើយ។ សូមរង់ចាំ Admin ដំណើរការសំណើនោះសិន។"
          );
        }
      }

      const user = userSnap.data() || {};
      let pinVerified = false;
      let pinMigration = null;

      const storedHash = String(user.withdraw_pin_hash || "");
      const storedSalt = String(user.withdraw_pin_salt || "");
      if (storedHash && storedSalt) {
        const candidate = hashPin(pin, storedSalt);
        pinVerified = timingSafeEqualHex(storedHash, candidate);
      } else {
        const legacyPin = String(user.password ?? "");
        pinVerified = legacyPin.length > 0 && legacyPin === pin;
        if (pinVerified) {
          const salt = crypto.randomBytes(16).toString("hex");
          pinMigration = {
            withdraw_pin_salt: salt,
            withdraw_pin_hash: hashPin(pin, salt),
            withdraw_pin_migrated_at: admin.firestore.FieldValue.serverTimestamp(),
            withdraw_pin_version: 1,
          };
        }
      }

      if (!pinVerified) {
        throw new HttpsError("permission-denied", "លេខសម្ងាត់មិនត្រឹមត្រូវ!");
      }

      const available = Number(user.available_balance ?? 0);
      const reserved = Number(user.reserved_withdraw_balance ?? 0);
      if (!Number.isSafeInteger(available) || !Number.isSafeInteger(reserved)) {
        throw new HttpsError("failed-precondition", "ទិន្នន័យសមតុល្យមិនត្រឹមត្រូវ!");
      }
      const spendable = available - reserved;
      if (amount > spendable) {
        throw new HttpsError("failed-precondition", "ទឹកប្រាក់អាចដកបានមិនគ្រប់គ្រាន់!");
      }

      const sellerName = String(
        user.full_name_kh || user.full_name || user.name || ""
      ).trim();
      const bankName = String(user.bank_name || "ABA").trim();
      const accountNumber = String(user.bank_account_number || "").trim();
      const khqrUrl = String(user.bank_qr_url || "").trim();
      if (!accountNumber) {
        throw new HttpsError(
          "failed-precondition",
          "សូមបំពេញលេខគណនីធនាគារជាមុនសិន!"
        );
      }

      tx.create(requestRef, {
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
        created_via: "secureWithdraw-v2",
        money_unit: "KHR_RIEL_INTEGER",
      });

      tx.set(
        userRef,
        {
          reserved_withdraw_balance: admin.firestore.FieldValue.increment(amount),
          ...(pinMigration || {}),
        },
        { merge: true }
      );

      tx.set(lockRef, {
        active: true,
        request_id: requestRef.id,
        amount,
        created_at: admin.firestore.FieldValue.serverTimestamp(),
        created_via: "secureWithdraw-v2",
      });
    });

    return { success: true, requestId: requestRef.id };
  }
);

exports.secureApproveWithdrawal = onCall(
  { region: "asia-southeast1" },
  async (request) => {
    const adminUid = requireAdmin(request);
    const requestId = String(request.data?.requestId ?? "").trim();
    const receiptUrl = String(request.data?.receiptUrl ?? "").trim();
    if (!requestId) throw new HttpsError("invalid-argument", "Missing requestId");

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
      if (!sellerId || !Number.isSafeInteger(amount) || amount <= 0) {
        throw new HttpsError("failed-precondition", "Invalid withdrawal data");
      }

      const userRef = db.collection("users").doc(sellerId);
      const lockRef = db.collection("withdraw_locks").doc(sellerId);
      const [userSnap, lockSnap] = await Promise.all([
        tx.get(userRef),
        tx.get(lockRef),
      ]);
      if (!userSnap.exists) {
        throw new HttpsError("not-found", "Seller account not found");
      }

      const user = userSnap.data() || {};
      const available = Number(user.available_balance ?? 0);
      const reserved = Number(user.reserved_withdraw_balance ?? 0);
      if (!Number.isSafeInteger(available) || available < amount) {
        throw new HttpsError("failed-precondition", "Insufficient available balance");
      }
      if (!Number.isSafeInteger(reserved) || reserved < reservedAmount) {
        throw new HttpsError("failed-precondition", "Reserved withdrawal balance is invalid");
      }

      tx.set(
        userRef,
        {
          available_balance: admin.firestore.FieldValue.increment(-amount),
          reserved_withdraw_balance: admin.firestore.FieldValue.increment(-reservedAmount),
          total_withdraw: admin.firestore.FieldValue.increment(amount),
        },
        { merge: true }
      );
      tx.update(withdrawRef, {
        status: "success",
        admin_receipt: receiptUrl,
        approved_at: admin.firestore.FieldValue.serverTimestamp(),
        approved_by_uid: adminUid,
        approved_via: "secureApproveWithdrawal-v2",
        reserve_settled: true,
        reserve_settled_at: admin.firestore.FieldValue.serverTimestamp(),
      });

      if (lockSnap.exists) {
        const lock = lockSnap.data() || {};
        if (!lock.request_id || String(lock.request_id) === requestId) {
          tx.set(
            lockRef,
            {
              active: false,
              request_id: requestId,
              resolved_at: admin.firestore.FieldValue.serverTimestamp(),
              resolved_status: "success",
            },
            { merge: true }
          );
        }
      }
    });

    return { success: true };
  }
);

exports.secureRejectWithdrawal = onCall(
  { region: "asia-southeast1" },
  async (request) => {
    const adminUid = requireAdmin(request);
    const requestId = String(request.data?.requestId ?? "").trim();
    if (!requestId) throw new HttpsError("invalid-argument", "Missing requestId");

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
      const amount = Number(data.reserved_amount ?? data.amount ?? 0);
      if (!sellerId || !Number.isSafeInteger(amount) || amount <= 0) {
        throw new HttpsError("failed-precondition", "Invalid withdrawal data");
      }

      const userRef = db.collection("users").doc(sellerId);
      const lockRef = db.collection("withdraw_locks").doc(sellerId);
      const [userSnap, lockSnap] = await Promise.all([
        tx.get(userRef),
        tx.get(lockRef),
      ]);
      if (!userSnap.exists) {
        throw new HttpsError("not-found", "Seller account not found");
      }

      const user = userSnap.data() || {};
      const reserved = Number(user.reserved_withdraw_balance ?? 0);
      if (!Number.isSafeInteger(reserved) || reserved < amount) {
        throw new HttpsError("failed-precondition", "Reserved withdrawal balance is invalid");
      }

      tx.set(
        userRef,
        {
          reserved_withdraw_balance: admin.firestore.FieldValue.increment(-amount),
        },
        { merge: true }
      );
      tx.update(withdrawRef, {
        status: "rejected",
        rejected_at: admin.firestore.FieldValue.serverTimestamp(),
        rejected_by_uid: adminUid,
        rejected_via: "secureRejectWithdrawal-v2",
        reserve_settled: true,
        reserve_settled_at: admin.firestore.FieldValue.serverTimestamp(),
      });

      if (lockSnap.exists) {
        const lock = lockSnap.data() || {};
        if (!lock.request_id || String(lock.request_id) === requestId) {
          tx.set(
            lockRef,
            {
              active: false,
              request_id: requestId,
              resolved_at: admin.firestore.FieldValue.serverTimestamp(),
              resolved_status: "rejected",
            },
            { merge: true }
          );
        }
      }
    });

    return { success: true };
  }
);
