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

function positiveMoney(value) {
  const amount = Number(value);
  if (!Number.isFinite(amount) || amount <= 0) {
    throw new HttpsError("failed-precondition", "seller_earnings មិនត្រឹមត្រូវ");
  }
  return amount;
}

exports.secureSellerOrderStatus = onCall(
  { region: "asia-southeast1" },
  async (request) => {
    const uid = requireAuth(request);
    const orderId = String(request.data?.orderId ?? "").trim();
    const newStatus = String(request.data?.status ?? "").trim();

    if (!orderId) {
      throw new HttpsError("invalid-argument", "Missing orderId");
    }

    const allowed = new Set(["packing", "on_delivery", "delivered", "rejected"]);
    if (!allowed.has(newStatus)) {
      throw new HttpsError("invalid-argument", "Invalid order status");
    }

    const orderRef = db.collection("orders").doc(orderId);

    const result = await db.runTransaction(async (tx) => {
      const orderSnap = await tx.get(orderRef);
      if (!orderSnap.exists) {
        throw new HttpsError("not-found", "រកមិនឃើញការកម្ម៉ង់នេះទេ");
      }

      const order = orderSnap.data() || {};
      const sellerId = String(order.seller_id || "").trim();
      if (!sellerId || sellerId !== uid) {
        throw new HttpsError(
          "permission-denied",
          "អ្នកមិនមែនជាអ្នកលក់នៃការកម្ម៉ង់នេះទេ"
        );
      }

      const currentStatus = String(order.status || "pending");
      if (currentStatus === newStatus) {
        return { changed: false, status: currentStatus };
      }

      const transitions = {
        confirmed: new Set(["packing", "rejected"]),
        packing: new Set(["on_delivery"]),
        on_delivery: new Set(["delivered"]),
      };
      if (!transitions[currentStatus]?.has(newStatus)) {
        throw new HttpsError(
          "failed-precondition",
          `មិនអាចប្តូរស្ថានភាពពី ${currentStatus} ទៅ ${newStatus} បានទេ`
        );
      }

      const now = admin.firestore.FieldValue.serverTimestamp();
      const orderUpdate = {
        status: newStatus,
        last_update: now,
        status_updated_by_uid: uid,
        status_updated_via: "secureSellerOrderStatus-v2",
      };

      if (newStatus === "packing") {
        if (order.seller_wallet_credited === true) {
          throw new HttpsError(
            "failed-precondition",
            "ការកម្ម៉ង់នេះបានបញ្ចូលប្រាក់ទៅកាបូបរួចហើយ"
          );
        }

        const earnings = positiveMoney(
          order.seller_earnings_payable ?? order.seller_earnings
        );
        const sellerRef = db.collection("users").doc(sellerId);
        const sellerSnap = await tx.get(sellerRef);
        if (!sellerSnap.exists) {
          throw new HttpsError("not-found", "រកមិនឃើញគណនីអ្នកលក់ទេ");
        }

        const seller = sellerSnap.data() || {};
        for (const field of ["balance", "wallet_balance", "today_income"]) {
          const value = Number(seller[field] ?? 0);
          if (!Number.isFinite(value)) {
            throw new HttpsError(
              "failed-precondition",
              `ទិន្នន័យ ${field} មិនត្រឹមត្រូវ`
            );
          }
        }

        tx.set(
          sellerRef,
          {
            balance: admin.firestore.FieldValue.increment(earnings),
            wallet_balance: admin.firestore.FieldValue.increment(earnings),
            today_income: admin.firestore.FieldValue.increment(earnings),
          },
          { merge: true }
        );

        const appWalletRef = db.collection("system_settings").doc("wallet");
        tx.set(
          appWalletRef,
          {
            total_seller_payout: admin.firestore.FieldValue.increment(earnings),
            updated_at: now,
          },
          { merge: true }
        );

        orderUpdate.packing_date = now;
        orderUpdate.is_settled = false;
        orderUpdate.seller_wallet_credited = true;
        orderUpdate.seller_wallet_credited_at = now;
        orderUpdate.seller_wallet_credited_via = "secureSellerOrderStatus-v2";
      } else if (newStatus === "on_delivery") {
        if (order.seller_wallet_credited !== true) {
          throw new HttpsError(
            "failed-precondition",
            "Order មិនទាន់បានបញ្ចូលប្រាក់ទៅ Pending wallet ទេ"
          );
        }
        orderUpdate.delivery_started_at = now;
      } else if (newStatus === "delivered") {
        if (order.seller_wallet_credited !== true) {
          throw new HttpsError(
            "failed-precondition",
            "Order មិនទាន់បានបញ្ចូលប្រាក់ទៅ Pending wallet ទេ"
          );
        }
        orderUpdate.delivered_at = now;
      } else if (newStatus === "rejected") {
        if (order.seller_wallet_credited === true) {
          throw new HttpsError(
            "failed-precondition",
            "Order ដែលបានចូល Pending wallet រួច មិនអាច Reject តាមផ្លូវនេះបានទេ"
          );
        }

        if (order.stock_restored !== true) {
          const rawItems = Array.isArray(order.items) ? order.items : [];
          const itemsByProduct = new Map();

          for (const raw of rawItems) {
            if (!raw || raw.stock_tracked !== true) continue;
            const productId = String(raw.product_id || "").trim();
            const qty = Number(raw.quantity);
            if (!productId || !Number.isSafeInteger(qty) || qty <= 0) continue;
            itemsByProduct.set(productId, (itemsByProduct.get(productId) || 0) + qty);
          }

          const productSnaps = new Map();
          for (const productId of itemsByProduct.keys()) {
            const ref = db.collection("products").doc(productId);
            productSnaps.set(productId, await tx.get(ref));
          }

          for (const [productId, qty] of itemsByProduct.entries()) {
            const snap = productSnaps.get(productId);
            if (!snap?.exists) continue;
            const product = snap.data() || {};
            const stock = Number(product.stock_quantity ?? 0);
            const sold = Number(product.sold_quantity ?? 0);
            if (!Number.isFinite(stock) || !Number.isFinite(sold)) continue;

            tx.set(
              snap.ref,
              {
                stock_quantity: stock + qty,
                sold_quantity: Math.max(0, sold - qty),
                is_available: true,
                stock_updated_at: now,
              },
              { merge: true }
            );
          }

          orderUpdate.stock_restored = true;
          orderUpdate.stock_restored_at = now;
          orderUpdate.stock_restored_via = "secureSellerOrderStatus-v2";
        }
      }

      tx.update(orderRef, orderUpdate);
      return { changed: true, status: newStatus };
    });

    return { success: true, ...result };
  }
);
