const { onCall, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

if (admin.apps.length === 0) admin.initializeApp();
const db = admin.firestore();
const ADMIN_UIDS = new Set(["WBdQVvrgEIPBTcgIlumu6bAZGUl2"]);

function requireAdmin(request) {
  if (!request.auth) throw new HttpsError("unauthenticated", "សូមចូលគណនីជាមុនសិន!");
  if (!ADMIN_UIDS.has(request.auth.uid)) {
    throw new HttpsError("permission-denied", "អ្នកមិនមានសិទ្ធិ Admin ទេ!");
  }
  return request.auth.uid;
}

exports.secureAdminConfirmOrder = onCall(
  { region: "asia-southeast1" },
  async (request) => {
    const adminUid = requireAdmin(request);
    const orderId = String(request.data?.orderId ?? "").trim();
    if (!orderId) throw new HttpsError("invalid-argument", "Missing orderId");

    const orderRef = db.collection("orders").doc(orderId);
    await db.runTransaction(async (tx) => {
      const snap = await tx.get(orderRef);
      if (!snap.exists) throw new HttpsError("not-found", "Order not found");
      const order = snap.data() || {};
      if (order.status === "confirmed") return;
      if (order.status !== "pending") {
        throw new HttpsError("failed-precondition", "Order is not pending");
      }

      const items = Array.isArray(order.items) ? order.items : [];
      const now = admin.firestore.FieldValue.serverTimestamp();
      for (const item of items) {
        const sellerId = String(item?.seller_id || order.seller_id || "").trim();
        if (!sellerId) continue;
        const price = Number(item?.price ?? 0);
        const qty = Number(item?.quantity ?? 1);
        const amount = Number.isFinite(price) && Number.isFinite(qty) ? price * qty : 0;
        const historyRef = db.collection("admin_confirm_history").doc();
        tx.set(historyRef, {
          order_id: orderId,
          product_name: String(item?.product_name || "ទំនិញ"),
          amount,
          customer_name: String(order.customer_name || ""),
          customer_phone: String(order.phone_number || ""),
          customer_id: String(order.customer_id || ""),
          seller_id: sellerId,
          receipt_image: String(order.payment_image || order.paymentProof || ""),
          confirm_date: now,
          status: "confirmed",
          confirmed_by_uid: adminUid,
          confirmed_via: "secureAdminConfirmOrder",
        });
      }

      tx.update(orderRef, {
        status: "confirmed",
        admin_confirmed_at: now,
        admin_confirmed_by_uid: adminUid,
        admin_confirmed_via: "secureAdminConfirmOrder",
      });
    });
    return { success: true };
  }
);

exports.secureAdminRejectOrder = onCall(
  { region: "asia-southeast1" },
  async (request) => {
    const adminUid = requireAdmin(request);
    const orderId = String(request.data?.orderId ?? "").trim();
    if (!orderId) throw new HttpsError("invalid-argument", "Missing orderId");

    const orderRef = db.collection("orders").doc(orderId);

    await db.runTransaction(async (tx) => {
      const snap = await tx.get(orderRef);
      if (!snap.exists) throw new HttpsError("not-found", "Order not found");

      const order = snap.data() || {};
      if (order.status === "rejected") return;
      if (order.status !== "pending") {
        throw new HttpsError("failed-precondition", "Order is not pending");
      }

      const items = Array.isArray(order.items) ? order.items : [];
      const now = admin.firestore.FieldValue.serverTimestamp();
      const itemsByProduct = new Map();

      if (order.stock_restored !== true) {
        for (const item of items) {
          if (item?.stock_tracked !== true) continue;
          const productId = String(item?.product_id || "").trim();
          const qty = Number(item?.quantity);
          if (!productId || !Number.isInteger(qty) || qty <= 0) continue;
          itemsByProduct.set(productId, (itemsByProduct.get(productId) || 0) + qty);
        }
      }

      const productSnaps = new Map();
      for (const productId of itemsByProduct.keys()) {
        const productRef = db.collection("products").doc(productId);
        productSnaps.set(productId, await tx.get(productRef));
      }

      for (const [productId, qty] of itemsByProduct.entries()) {
        const productSnap = productSnaps.get(productId);
        if (!productSnap?.exists) continue;
        const product = productSnap.data() || {};
        const stock = Number(product.stock_quantity ?? 0);
        const sold = Number(product.sold_quantity ?? 0);
        if (!Number.isFinite(stock) || !Number.isFinite(sold)) continue;

        tx.set(
          productSnap.ref,
          {
            stock_quantity: stock + qty,
            sold_quantity: Math.max(0, sold - qty),
            is_available: true,
            stock_updated_at: now,
          },
          { merge: true }
        );
      }

      for (const item of items) {
        const sellerId = String(item?.seller_id || order.seller_id || "").trim();
        if (!sellerId) continue;
        const price = Number(item?.price ?? 0);
        const qty = Number(item?.quantity ?? 1);
        const amount = Number.isFinite(price) && Number.isFinite(qty) ? price * qty : 0;
        const historyRef = db.collection("admin_confirm_history").doc();
        tx.set(historyRef, {
          order_id: orderId,
          product_name: String(item?.product_name || "ទំនិញ"),
          amount,
          total_amount: Number(order.total_amount ?? 0),
          customer_name: String(order.customer_name || ""),
          customer_phone: String(order.phone_number || ""),
          customer_id: String(order.customer_id || ""),
          customer_address: String(order.shipping_address || ""),
          seller_id: sellerId,
          receipt_image: String(order.payment_image || order.paymentProof || ""),
          items,
          reject_date: now,
          status: "rejected",
          rejected_by_uid: adminUid,
          rejected_via: "secureAdminRejectOrder",
        });
      }

      tx.update(orderRef, {
        status: "rejected",
        rejected_at: now,
        rejected_by_uid: adminUid,
        rejected_via: "secureAdminRejectOrder",
        stock_restored: true,
        stock_restored_at: now,
        stock_restored_via: "secureAdminRejectOrder",
      });
    });

    return { success: true };
  }
);

exports.secureDistributeDividends = onCall(
  { region: "asia-southeast1", timeoutSeconds: 120 },
  async (request) => {
    const adminUid = requireAdmin(request);
    const amountPerShare = Number(request.data?.amountPerShare);
    if (!Number.isFinite(amountPerShare) || amountPerShare <= 0) {
      throw new HttpsError("invalid-argument", "Invalid amount per share");
    }

    const shareholders = await db.collection("shareholders").where("total_shares", ">", 0).get();
    if (shareholders.empty) return { success: true, investors: 0 };
    if (shareholders.size > 400) {
      throw new HttpsError("resource-exhausted", "Too many shareholders for one distribution");
    }

    const historyRef = db.collection("dividend_history").doc();
    await db.runTransaction(async (tx) => {
      for (const doc of shareholders.docs) {
        const fresh = await tx.get(doc.ref);
        if (!fresh.exists) continue;
        const data = fresh.data() || {};
        const shares = Number(data.total_shares ?? 0);
        if (!Number.isFinite(shares) || shares <= 0) continue;
        const earned = shares * amountPerShare;
        tx.update(doc.ref, {
          balance: admin.firestore.FieldValue.increment(earned),
          total_earned: admin.firestore.FieldValue.increment(earned),
        });
      }
      tx.set(historyRef, {
        amount_per_share: amountPerShare,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        total_investors: shareholders.size,
        distributed_by_uid: adminUid,
        distributed_via: "secureDistributeDividends",
      });
    });

    return { success: true, investors: shareholders.size, historyId: historyRef.id };
  }
);
