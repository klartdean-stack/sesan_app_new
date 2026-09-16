const crypto = require("crypto");
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

function parseRiel(value) {
  const normalized = String(value ?? "").replace(/,/g, "").trim();
  const amount = Number(normalized);
  if (!Number.isSafeInteger(amount) || amount <= 0) {
    throw new HttpsError(
      "failed-precondition",
      "តម្លៃទំនិញត្រូវតែជាចំនួនរៀលគត់ និងធំជាង 0"
    );
  }
  return amount;
}

function makeCheckoutKey(customerId, paymentImage) {
  return crypto
    .createHash("sha256")
    .update(`${customerId}|${paymentImage}`)
    .digest("hex");
}

exports.secureCreateOrder = onCall(
  { region: "asia-southeast1", timeoutSeconds: 60 },
  async (request) => {
    const customerId = requireAuth(request);
    const rawItems = Array.isArray(request.data?.items) ? request.data.items : [];
    const customerName = String(request.data?.customerName ?? "").trim();
    const phoneNumber = String(request.data?.phoneNumber ?? "").trim();
    const shippingAddress = String(request.data?.shippingAddress ?? "").trim();
    const paymentImage = String(request.data?.paymentImage ?? "").trim();

    if (rawItems.length === 0 || rawItems.length > 100) {
      throw new HttpsError("invalid-argument", "បញ្ជីទំនិញមិនត្រឹមត្រូវ");
    }
    if (!customerName || !phoneNumber || !shippingAddress || !paymentImage) {
      throw new HttpsError(
        "invalid-argument",
        "ព័ត៌មានការកម្ម៉ង់មិនទាន់គ្រប់គ្រាន់"
      );
    }

    const requestedByProduct = new Map();
    for (const raw of rawItems) {
      const productId = String(raw?.product_id ?? "").trim();
      const qty = Number(raw?.quantity);
      if (!productId || !Number.isSafeInteger(qty) || qty <= 0 || qty > 100000) {
        throw new HttpsError(
          "invalid-argument",
          "Product ឬ quantity មិនត្រឹមត្រូវ"
        );
      }
      requestedByProduct.set(
        productId,
        (requestedByProduct.get(productId) || 0) + qty
      );
    }

    const checkoutKey = makeCheckoutKey(customerId, paymentImage);
    const checkoutRef = db.collection("checkout_requests").doc(checkoutKey);

    const result = await db.runTransaction(async (tx) => {
      // Idempotency: the same authenticated buyer + same uploaded payment receipt
      // can only create one checkout, even if the callable is retried or tapped twice.
      const checkoutSnap = await tx.get(checkoutRef);
      if (checkoutSnap.exists) {
        const existing = checkoutSnap.data() || {};
        if (String(existing.customer_id || "") !== customerId) {
          throw new HttpsError("permission-denied", "Invalid checkout owner");
        }
        return {
          orderIds: Array.isArray(existing.order_ids) ? existing.order_ids : [],
          duplicate: true,
        };
      }

      const productSnaps = new Map();
      for (const productId of requestedByProduct.keys()) {
        const ref = db.collection("products").doc(productId);
        productSnaps.set(productId, await tx.get(ref));
      }

      const groups = new Map();

      for (const [productId, qty] of requestedByProduct.entries()) {
        const snap = productSnaps.get(productId);
        if (!snap?.exists) {
          throw new HttpsError("not-found", `រកមិនឃើញទំនិញ ${productId}`);
        }

        const product = snap.data() || {};
        const sellerId = String(product.seller_id || "").trim();
        if (!sellerId) {
          throw new HttpsError(
            "failed-precondition",
            "ទំនិញនេះមិនមាន seller_id ត្រឹមត្រូវ"
          );
        }

        const price = parseRiel(product.price);
        const trackStock = product.track_stock === true;
        let available = null;

        if (trackStock) {
          available = Number(product.stock_quantity ?? 0);
          if (!Number.isSafeInteger(available) || available < qty) {
            const name = String(product.product_name || productId);
            throw new HttpsError(
              "failed-precondition",
              `ស្តុក ${name} មិនគ្រប់គ្រាន់ (មាន ${Number.isFinite(available) ? available : 0})`
            );
          }
        }

        const item = {
          product_id: productId,
          product_name: String(product.product_name || "គ្មានឈ្មោះ"),
          price,
          quantity: qty,
          stock_tracked: trackStock,
          stock_unit: String(product.stock_unit || "item"),
          seller_id: sellerId,
          seller_name: String(product.seller_name || "អាជីវករ សេសាន"),
          seller_photo: String(product.seller_photo || ""),
          seller_phone: String(
            product.seller_phone || product.phone1 || product.phone || ""
          ),
          category: String(product.category || "ទូទៅ"),
          image_url: String(
            product.image_url ||
              (Array.isArray(product.image_urls) ? product.image_urls[0] : "") ||
              ""
          ),
        };

        if (!groups.has(sellerId)) groups.set(sellerId, []);
        groups.get(sellerId).push(item);

        if (trackStock) {
          const remaining = available - qty;
          tx.set(
            snap.ref,
            {
              stock_quantity: remaining,
              sold_quantity: admin.firestore.FieldValue.increment(qty),
              is_available: remaining > 0,
              stock_updated_at: admin.firestore.FieldValue.serverTimestamp(),
            },
            { merge: true }
          );
        }
      }

      const createdOrderIds = [];
      const nowDate = new Date();
      const monthKey = `${nowDate.getFullYear()}-${String(
        nowDate.getMonth() + 1
      ).padStart(2, "0")}`;
      const dateKey = `${monthKey}-${String(nowDate.getDate()).padStart(2, "0")}`;

      for (const [sellerId, items] of groups.entries()) {
        const subTotal = items.reduce(
          (sum, item) => sum + item.price * item.quantity,
          0
        );
        if (!Number.isSafeInteger(subTotal) || subTotal <= 0) {
          throw new HttpsError(
            "failed-precondition",
            "ទឹកប្រាក់សរុបមិនត្រឹមត្រូវ"
          );
        }

        // KHR has no smaller unit in Sesan wallet. Round commission to the nearest riel.
        const adminCommission = Math.round((subTotal * 7) / 100);
        const sellerEarnings = subTotal - adminCommission;
        const orderRef = db.collection("orders").doc();

        tx.set(orderRef, {
          order_id: orderRef.id,
          checkout_key: checkoutKey,
          is_settled: false,
          stock_restored: false,
          seller_wallet_credited: false,
          items,
          total_amount: subTotal,
          admin_commission: adminCommission,
          seller_earnings: sellerEarnings,
          seller_earnings_payable: sellerEarnings,
          commission_rate: 0.07,
          money_unit: "KHR_RIEL_INTEGER",
          money_calculated_via: "secureCreateOrder-v2",
          seller_id: sellerId,
          seller_phone: String(items[0]?.seller_phone || ""),
          customer_id: customerId,
          customer_name: customerName,
          phone_number: phoneNumber,
          shipping_address: shippingAddress,
          payment_image: paymentImage,
          status: "pending",
          payment_status: "paid",
          created_at: admin.firestore.FieldValue.serverTimestamp(),
          month_key: monthKey,
          date_key: dateKey,
          created_via: "secureCreateOrder-v2",
        });
        createdOrderIds.push(orderRef.id);
      }

      tx.create(checkoutRef, {
        customer_id: customerId,
        payment_image: paymentImage,
        order_ids: createdOrderIds,
        status: "created",
        created_at: admin.firestore.FieldValue.serverTimestamp(),
        created_via: "secureCreateOrder-v2",
      });

      return { orderIds: createdOrderIds, duplicate: false };
    });

    return {
      success: true,
      orderIds: result.orderIds,
      sellerOrderCount: result.orderIds.length,
      duplicate: result.duplicate,
    };
  }
);
