const crypto = require("crypto");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

if (admin.apps.length === 0) admin.initializeApp();
const db = admin.firestore();
const ADMIN_UIDS = new Set(["WBdQVvrgEIPBTcgIlumu6bAZGUl2"]);

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

function requiredText(value, label) {
  const text = String(value ?? "").trim();
  if (!text) throw new HttpsError("invalid-argument", `${label} មិនអាចទទេបាន`);
  return text;
}

exports.secureSubmitInvestment = onCall(
  { region: "asia-southeast1" },
  async (request) => {
    const uid = requireAuth(request);
    const shares = Number(request.data?.shares);
    if (!Number.isSafeInteger(shares) || shares <= 0 || shares > 1000000) {
      throw new HttpsError("invalid-argument", "ចំនួនហ៊ុនមិនត្រឹមត្រូវ");
    }

    const name = requiredText(request.data?.name, "ឈ្មោះ");
    const idCard = requiredText(request.data?.idCard, "លេខអត្តសញ្ញាណប័ណ្ណ");
    const phone = requiredText(request.data?.phone, "លេខទូរស័ព្ទ");
    const address = requiredText(request.data?.address, "អាសយដ្ឋាន");
    const bankAccount = requiredText(request.data?.bankAccount, "លេខគណនី");
    const bankName = requiredText(request.data?.bankName || "ABA", "ធនាគារ");
    const receiptUrl = requiredText(request.data?.receiptUrl, "វិក្កយបត្រ");

    const idempotencyKey = crypto
      .createHash("sha256")
      .update(`${uid}|${receiptUrl}`)
      .digest("hex");
    const requestRef = db.collection("investment_requests").doc(idempotencyKey);
    const statsRef = db.collection("app_equity_stats").doc("current");

    const result = await db.runTransaction(async (tx) => {
      const existing = await tx.get(requestRef);
      if (existing.exists) {
        const data = existing.data() || {};
        if (String(data.user_id || "") !== uid) {
          throw new HttpsError("permission-denied", "Invalid investment request owner");
        }
        return { duplicate: true, requestId: requestRef.id };
      }

      const statsSnap = await tx.get(statsRef);
      if (!statsSnap.exists) {
        throw new HttpsError("failed-precondition", "មិនទាន់មាន Equity settings ទេ");
      }
      const stats = statsSnap.data() || {};
      const pricePerShare = Number(stats.price_per_share ?? 0);
      const availableShares = Number(stats.available_shares ?? 0);
      if (!Number.isSafeInteger(pricePerShare) || pricePerShare <= 0) {
        throw new HttpsError("failed-precondition", "តម្លៃហ៊ុនមិនត្រឹមត្រូវ");
      }
      if (!Number.isSafeInteger(availableShares) || availableShares < shares) {
        throw new HttpsError("failed-precondition", "ចំនួនហ៊ុននៅសល់មិនគ្រប់គ្រាន់");
      }

      const totalPrice = shares * pricePerShare;
      if (!Number.isSafeInteger(totalPrice) || totalPrice <= 0) {
        throw new HttpsError("failed-precondition", "តម្លៃវិនិយោគសរុបមិនត្រឹមត្រូវ");
      }

      tx.create(requestRef, {
        user_id: uid,
        name,
        shares,
        price_per_share: pricePerShare,
        total_price: totalPrice,
        id_card: idCard,
        phone,
        address,
        bank_account: bankAccount,
        bank_name: bankName,
        receipt_url: receiptUrl,
        status: "pending",
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        created_via: "secureSubmitInvestment",
        money_unit: "KHR_RIEL_INTEGER",
      });

      return { duplicate: false, requestId: requestRef.id };
    });

    return { success: true, ...result };
  }
);

exports.secureApproveInvestment = onCall(
  { region: "asia-southeast1" },
  async (request) => {
    const adminUid = requireAdmin(request);
    const requestId = requiredText(request.data?.requestId, "requestId");
    const investmentRef = db.collection("investment_requests").doc(requestId);
    const statsRef = db.collection("app_equity_stats").doc("current");

    await db.runTransaction(async (tx) => {
      const [investmentSnap, statsSnap] = await Promise.all([
        tx.get(investmentRef),
        tx.get(statsRef),
      ]);
      if (!investmentSnap.exists) {
        throw new HttpsError("not-found", "រកមិនឃើញសំណើវិនិយោគ");
      }
      if (!statsSnap.exists) {
        throw new HttpsError("failed-precondition", "មិនទាន់មាន Equity settings ទេ");
      }

      const investment = investmentSnap.data() || {};
      if (investment.status === "success") return;
      if (investment.status !== "pending") {
        throw new HttpsError("failed-precondition", "សំណើនេះមិនមែន Pending ទេ");
      }

      const uid = String(investment.user_id || "").trim();
      const shares = Number(investment.shares ?? 0);
      const amountPaid = Number(investment.total_price ?? 0);
      const pricePerShare = Number(investment.price_per_share ?? 0);
      if (
        !uid ||
        !Number.isSafeInteger(shares) ||
        shares <= 0 ||
        !Number.isSafeInteger(amountPaid) ||
        amountPaid <= 0 ||
        !Number.isSafeInteger(pricePerShare) ||
        amountPaid !== shares * pricePerShare
      ) {
        throw new HttpsError("failed-precondition", "ទិន្នន័យសំណើវិនិយោគមិនត្រឹមត្រូវ");
      }

      const stats = statsSnap.data() || {};
      const availableShares = Number(stats.available_shares ?? 0);
      if (!Number.isSafeInteger(availableShares) || availableShares < shares) {
        throw new HttpsError("failed-precondition", "ចំនួនហ៊ុននៅសល់មិនគ្រប់គ្រាន់");
      }

      const shareholderRef = db.collection("shareholders").doc(uid);
      tx.set(
        shareholderRef,
        {
          name: String(investment.name || ""),
          total_shares: admin.firestore.FieldValue.increment(shares),
          invested_amount: admin.firestore.FieldValue.increment(amountPaid),
          phone: String(investment.phone || ""),
          id_card: String(investment.id_card || ""),
          address: String(investment.address || ""),
          bank_name: String(investment.bank_name || ""),
          bank_account: String(investment.bank_account || ""),
          updated_at: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

      tx.update(statsRef, {
        available_shares: admin.firestore.FieldValue.increment(-shares),
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
      });
      tx.update(investmentRef, {
        status: "success",
        approved_at: admin.firestore.FieldValue.serverTimestamp(),
        approved_by_uid: adminUid,
        approved_via: "secureApproveInvestment",
      });
    });

    return { success: true };
  }
);

exports.secureRejectInvestment = onCall(
  { region: "asia-southeast1" },
  async (request) => {
    const adminUid = requireAdmin(request);
    const requestId = requiredText(request.data?.requestId, "requestId");
    const ref = db.collection("investment_requests").doc(requestId);

    await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      if (!snap.exists) throw new HttpsError("not-found", "រកមិនឃើញសំណើវិនិយោគ");
      const data = snap.data() || {};
      if (data.status === "rejected") return;
      if (data.status !== "pending") {
        throw new HttpsError("failed-precondition", "សំណើនេះមិនមែន Pending ទេ");
      }
      tx.update(ref, {
        status: "rejected",
        rejected_at: admin.firestore.FieldValue.serverTimestamp(),
        rejected_by_uid: adminUid,
        rejected_via: "secureRejectInvestment",
      });
    });

    return { success: true };
  }
);

exports.secureUpdateEquitySettings = onCall(
  { region: "asia-southeast1" },
  async (request) => {
    const adminUid = requireAdmin(request);
    const hasPrice = request.data?.pricePerShare !== undefined && request.data?.pricePerShare !== null;
    const hasAvailable = request.data?.availableShares !== undefined && request.data?.availableShares !== null;
    if (!hasPrice && !hasAvailable) {
      throw new HttpsError("invalid-argument", "គ្មានទិន្នន័យកែប្រែ");
    }

    const update = {
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
      updated_by_uid: adminUid,
      updated_via: "secureUpdateEquitySettings",
    };

    if (hasPrice) {
      const value = Number(request.data.pricePerShare);
      if (!Number.isSafeInteger(value) || value <= 0) {
        throw new HttpsError("invalid-argument", "តម្លៃក្នុងមួយហ៊ុនមិនត្រឹមត្រូវ");
      }
      update.price_per_share = value;
    }

    if (hasAvailable) {
      const value = Number(request.data.availableShares);
      if (!Number.isSafeInteger(value) || value < 0) {
        throw new HttpsError("invalid-argument", "ចំនួនហ៊ុននៅសល់មិនត្រឹមត្រូវ");
      }
      update.available_shares = value;
    }

    await db.collection("app_equity_stats").doc("current").set(update, { merge: true });
    return { success: true };
  }
);
