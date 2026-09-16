const { onCall, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

if (admin.apps.length === 0) admin.initializeApp();
const db = admin.firestore();
const ADMIN_UIDS = new Set(["WBdQVvrgEIPBTcgIlumu6bAZGUl2"]);

function requireAdmin(request) {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "សូមចូលគណនីជាមុនសិន!");
  }
  if (!ADMIN_UIDS.has(request.auth.uid)) {
    throw new HttpsError("permission-denied", "អ្នកមិនមានសិទ្ធិ Admin ទេ!");
  }
  return request.auth.uid;
}

exports.secureApproveInvestment = onCall(
  { region: "asia-southeast1" },
  async (request) => {
    const adminUid = requireAdmin(request);
    const requestId = String(request.data?.requestId ?? "").trim();
    if (!requestId) throw new HttpsError("invalid-argument", "Missing requestId");

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

      const uid = String(investment.user_id || investment.uid || "").trim();
      const shares = Number(investment.shares ?? 0);
      if (!uid || !Number.isSafeInteger(shares) || shares <= 0) {
        throw new HttpsError("failed-precondition", "ទិន្នន័យចំនួនហ៊ុនមិនត្រឹមត្រូវ");
      }

      const stats = statsSnap.data() || {};
      const availableShares = Number(stats.available_shares ?? 0);
      const currentPrice = Number(stats.price_per_share ?? 0);
      if (!Number.isSafeInteger(currentPrice) || currentPrice <= 0) {
        throw new HttpsError("failed-precondition", "តម្លៃហ៊ុនបច្ចុប្បន្នមិនត្រឹមត្រូវ");
      }
      if (!Number.isSafeInteger(availableShares) || availableShares < shares) {
        throw new HttpsError("failed-precondition", "ចំនួនហ៊ុននៅសល់មិនគ្រប់គ្រាន់");
      }

      // Hardened requests preserve the server-snapshotted purchase price.
      // Legacy client-created requests are recalculated from the current server price,
      // so client-supplied total_price can never control the approved money value.
      let approvedPrice = currentPrice;
      if (investment.created_via === "secureSubmitInvestment") {
        const snapPrice = Number(investment.price_per_share ?? 0);
        if (Number.isSafeInteger(snapPrice) && snapPrice > 0) {
          approvedPrice = snapPrice;
        }
      }

      const amountPaid = shares * approvedPrice;
      if (!Number.isSafeInteger(amountPaid) || amountPaid <= 0) {
        throw new HttpsError("failed-precondition", "ទឹកប្រាក់វិនិយោគមិនត្រឹមត្រូវ");
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
        approved_price_per_share: approvedPrice,
        approved_total_price: amountPaid,
        approved_at: admin.firestore.FieldValue.serverTimestamp(),
        approved_by_uid: adminUid,
        approved_via: "secureApproveInvestment-v2",
      });
    });

    return { success: true };
  }
);
