const { onCall, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

if (admin.apps.length === 0) admin.initializeApp();
const db = admin.firestore();

function requireAuth(request) {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "សូមចូលគណនីជាមុនសិន!");
  }
  return request.auth.uid;
}

exports.secureBuyerConfirmReceipt = onCall(
  { region: "asia-southeast1" },
  async (request) => {
    const uid = requireAuth(request);
    const orderId = String(request.data?.orderId ?? "").trim();
    if (!orderId) {
      throw new HttpsError("invalid-argument", "Missing orderId");
    }

    const orderRef = db.collection("orders").doc(orderId);

    const result = await db.runTransaction(async (tx) => {
      const snap = await tx.get(orderRef);
      if (!snap.exists) {
        throw new HttpsError("not-found", "រកមិនឃើញ Order នេះទេ");
      }

      const order = snap.data() || {};
      const customerId = String(order.customer_id || "").trim();
      if (!customerId || customerId !== uid) {
        throw new HttpsError(
          "permission-denied",
          "អ្នកមិនមែនជាអ្នកទិញនៃ Order នេះទេ"
        );
      }

      if (order.receivedByBuyer === true && order.status === "delivered") {
        return { changed: false, status: "delivered" };
      }

      if (order.status !== "on_delivery") {
        throw new HttpsError(
          "failed-precondition",
          "Order មិនទាន់ស្ថិតក្នុងដំណាក់កាលដឹកជញ្ជូនទេ"
        );
      }

      const now = admin.firestore.FieldValue.serverTimestamp();
      tx.update(orderRef, {
        status: "delivered",
        delivered_at: now,
        receivedByBuyer: true,
        receivedAt: now,
        buyer_confirmed_uid: uid,
        buyer_confirmed_via: "secureBuyerConfirmReceipt",
      });

      return { changed: true, status: "delivered" };
    });

    return { success: true, ...result };
  }
);
