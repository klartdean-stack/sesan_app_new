const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");

if (admin.apps.length === 0) {
  admin.initializeApp();
}

const db = admin.firestore();
const ADMIN_UIDS = new Set(["WBdQVvrgEIPBTcgIlumu6bAZGUl2"]);
const FIVE_DAYS_MS = 5 * 24 * 60 * 60 * 1000;

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

function asPositiveMoney(value, fieldName) {
  const amount = Number(value);
  if (!Number.isFinite(amount) || amount <= 0) {
    throw new HttpsError("failed-precondition", `${fieldName} មិនត្រឹមត្រូវ`);
  }
  return amount;
}

function parseStoredPrice(value) {
  const normalized = String(value ?? "").replace(/,/g, "").trim();
  const price = Number(normalized);
  if (!Number.isFinite(price) || price <= 0) {
    throw new HttpsError("failed-precondition", "តម្លៃទំនិញមិនត្រឹមត្រូវ");
  }
  return price;
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
      throw new HttpsError("invalid-argument", "ព័ត៌មានការកម្ម៉ង់មិនទាន់គ្រប់គ្រាន់");
    }

    const requestedByProduct = new Map();
    for (const raw of rawItems) {
      const productId = String(raw?.product_id ?? "").trim();
      const qty = Number(raw?.quantity);
      if (!productId || !Number.isInteger(qty) || qty <= 0 || qty > 100000) {
        throw new HttpsError("invalid-argument", "Product ឬ quantity មិនត្រឹមត្រូវ");
      }
      requestedByProduct.set(
        productId,
        (requestedByProduct.get(productId) || 0) + qty
      );
    }

    const orderIds = await db.runTransaction(async (tx) => {
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
          throw new HttpsError("failed-precondition", "ទំនិញនេះមិនមាន seller_id ត្រឹមត្រូវ");
        }

        const price = parseStoredPrice(product.price);
        const trackStock = product.track_stock === true;
        let available = null;

        if (trackStock) {
          available = Number(product.stock_quantity ?? 0);
          if (!Number.isInteger(available) || available < qty) {
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
      const now = new Date();
      const monthKey = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, "0")}`;
      const dateKey = `${monthKey}-${String(now.getDate()).padStart(2, "0")}`;

      for (const [sellerId, items] of groups.entries()) {
        const subTotal = items.reduce(
          (sum, item) => sum + Number(item.price) * Number(item.quantity),
          0
        );
        if (!Number.isFinite(subTotal) || subTotal <= 0) {
          throw new HttpsError("failed-precondition", "ទឹកប្រាក់សរុបមិនត្រឹមត្រូវ");
        }

        const adminCommission = subTotal * 0.07;
        const sellerEarnings = subTotal - adminCommission;
        const orderRef = db.collection("orders").doc();

        tx.set(orderRef, {
          order_id: orderRef.id,
          is_settled: false,
          stock_restored: false,
          seller_wallet_credited: false,
          items,
          total_amount: subTotal,
          admin_commission: adminCommission,
          seller_earnings: sellerEarnings,
          seller_earnings_payable: sellerEarnings,
          commission_rate: 0.07,
          money_calculated_via: "secureCreateOrder",
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
          created_via: "secureCreateOrder",
        });

        createdOrderIds.push(orderRef.id);
      }

      return createdOrderIds;
    });

    return {
      success: true,
      orderIds,
      sellerOrderCount: orderIds.length,
    };
  }
);

exports.secureSellerOrderStatus = onCall(
  { region: "asia-southeast1" },
  async (request) => {
    const uid = requireAuth(request);
    const orderId = String(request.data?.orderId ?? "").trim();
    const newStatus = String(request.data?.status ?? "").trim();

    if (!orderId) {
      throw new HttpsError("invalid-argument", "Missing orderId");
    }

    const allowedStatuses = new Set([
      "packing",
      "on_delivery",
      "delivered",
      "rejected",
    ]);
    if (!allowedStatuses.has(newStatus)) {
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
        throw new HttpsError("permission-denied", "អ្នកមិនមែនជាអ្នកលក់នៃការកម្ម៉ង់នេះទេ");
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
        status_updated_via: "secureSellerOrderStatus",
      };

      if (newStatus === "packing") {
        if (order.seller_wallet_credited === true) {
          throw new HttpsError(
            "failed-precondition",
            "ការកម្ម៉ង់នេះបានបញ្ចូលប្រាក់ទៅកាបូបរួចហើយ"
          );
        }

        const earnings = asPositiveMoney(
          order.seller_earnings_payable ?? order.seller_earnings,
          "seller_earnings"
        );
        const userRef = db.collection("users").doc(sellerId);
        const userSnap = await tx.get(userRef);
        if (!userSnap.exists) {
          throw new HttpsError("not-found", "រកមិនឃើញគណនីអ្នកលក់ទេ");
        }

        const userData = userSnap.data() || {};
        const totalBalance = Number(userData.balance ?? 0);
        const walletBalance = Number(userData.wallet_balance ?? 0);
        if (!Number.isFinite(totalBalance) || !Number.isFinite(walletBalance)) {
          throw new HttpsError("failed-precondition", "ទិន្នន័យកាបូបលុយអ្នកលក់មិនត្រឹមត្រូវ");
        }

        orderUpdate.packing_date = now;
        orderUpdate.is_settled = false;
        orderUpdate.seller_wallet_credited = true;
        orderUpdate.seller_wallet_credited_at = now;
        orderUpdate.seller_wallet_credited_via = "secureSellerOrderStatus";

        tx.set(
          userRef,
          {
            balance: admin.firestore.FieldValue.increment(earnings),
            wallet_balance: admin.firestore.FieldValue.increment(earnings),
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
      } else if (newStatus === "on_delivery") {
        orderUpdate.delivery_started_at = now;
      } else if (newStatus === "delivered") {
        orderUpdate.delivered_at = now;
      } else if (newStatus === "rejected") {
        if (order.stock_restored !== true) {
          const rawItems = Array.isArray(order.items) ? order.items : [];
          const itemsByProduct = new Map();

          for (const raw of rawItems) {
            if (!raw || raw.stock_tracked !== true) continue;
            const productId = String(raw.product_id || "").trim();
            const qty = Number(raw.quantity);
            if (!productId || !Number.isInteger(qty) || qty <= 0) continue;
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
          orderUpdate.stock_restored_via = "secureSellerOrderStatus";
        }
      }

      tx.update(orderRef, orderUpdate);
      return { changed: true, status: newStatus };
    });

    return { success: true, ...result };
  }
);

exports.secureAdminDeductBalance = onCall(
  { region: "asia-southeast1" },
  async (request) => {
    const adminUid = requireAdmin(request);
    const sellerId = String(request.data?.sellerId ?? "").trim();
    const orderId = String(request.data?.orderId ?? "").trim();
    const reason = String(request.data?.reason ?? "").trim();
    const amount = asPositiveMoney(request.data?.amount, "amount");

    if (!sellerId || !orderId || !reason) {
      throw new HttpsError("invalid-argument", "ព័ត៌មានកាត់លុយមិនគ្រប់គ្រាន់");
    }

    const sellerRef = db.collection("users").doc(sellerId);
    const orderRef = db.collection("orders").doc(orderId);
    const reportRef = db.collection("admin_reports").doc();

    await db.runTransaction(async (tx) => {
      const [sellerSnap, orderSnap] = await Promise.all([
        tx.get(sellerRef),
        tx.get(orderRef),
      ]);

      if (!sellerSnap.exists) {
        throw new HttpsError("not-found", "រកមិនឃើញគណនីអ្នកលក់");
      }
      if (!orderSnap.exists) {
        throw new HttpsError("not-found", "រកមិនឃើញការកម្ម៉ង់");
      }

      const seller = sellerSnap.data() || {};
      const order = orderSnap.data() || {};
      if (String(order.seller_id || "") !== sellerId) {
        throw new HttpsError("failed-precondition", "Order មិនមែនរបស់អ្នកលក់នេះទេ");
      }

      const walletBalance = Number(seller.wallet_balance ?? 0);
      const availableBalance = Number(seller.available_balance ?? 0);
      if (!Number.isFinite(walletBalance) || !Number.isFinite(availableBalance)) {
        throw new HttpsError("failed-precondition", "ទិន្នន័យកាបូបលុយមិនត្រឹមត្រូវ");
      }

      let pendingDeduction = 0;
      let availableDeduction = amount;
      let payable = Number(order.seller_earnings_payable ?? order.seller_earnings ?? 0);

      if (
        order.is_settled === false &&
        order.seller_wallet_credited === true &&
        Number.isFinite(payable) &&
        payable > 0
      ) {
        pendingDeduction = Math.min(amount, payable);
        availableDeduction = amount - pendingDeduction;
      }

      if (walletBalance < pendingDeduction || availableBalance < availableDeduction) {
        throw new HttpsError("failed-precondition", "សមតុល្យអ្នកលក់មិនគ្រប់សម្រាប់កាត់លុយនេះទេ");
      }

      const sellerUpdate = {};
      if (pendingDeduction > 0) {
        sellerUpdate.wallet_balance = admin.firestore.FieldValue.increment(-pendingDeduction);
      }
      if (availableDeduction > 0) {
        sellerUpdate.available_balance = admin.firestore.FieldValue.increment(-availableDeduction);
      }
      if (Object.keys(sellerUpdate).length > 0) {
        tx.set(sellerRef, sellerUpdate, { merge: true });
      }

      const orderUpdate = {
        dispute_deduction_total: admin.firestore.FieldValue.increment(amount),
        last_money_adjustment_at: admin.firestore.FieldValue.serverTimestamp(),
        last_money_adjustment_by_uid: adminUid,
      };

      if (pendingDeduction > 0) {
        payable = Math.max(0, payable - pendingDeduction);
        orderUpdate.seller_earnings_payable = payable;
        if (payable === 0) {
          orderUpdate.is_settled = true;
          orderUpdate.settled_at = admin.firestore.FieldValue.serverTimestamp();
          orderUpdate.settlement_via = "secureAdminDeductBalance";
        }
      }

      tx.set(orderRef, orderUpdate, { merge: true });
      tx.set(reportRef, {
        seller_id: sellerId,
        order_id: orderId,
        action: "ADMIN_DEDUCTION",
        amount,
        deducted_from_pending: pendingDeduction,
        deducted_from_available: availableDeduction,
        reason,
        admin_uid: adminUid,
        time: admin.firestore.FieldValue.serverTimestamp(),
        created_via: "secureAdminDeductBalance",
      });
    });

    return { success: true };
  }
);

// Override the legacy/earlier scheduler with one authoritative settlement path.
// It supports partial admin deductions through seller_earnings_payable and checks
// every unsettled order so due orders cannot be starved behind a fixed first-page limit.
exports.scheduledWalletSettlement = onSchedule(
  {
    schedule: "0 * * * *",
    timeZone: "Asia/Phnom_Penh",
    region: "asia-southeast1",
  },
  async () => {
    const cutoffMillis = Date.now() - FIVE_DAYS_MS;
    const candidates = await db
      .collection("orders")
      .where("is_settled", "==", false)
      .get();

    let checked = 0;
    let settled = 0;
    let skipped = 0;

    for (const candidate of candidates.docs) {
      checked += 1;
      try {
        const result = await db.runTransaction(async (tx) => {
          const fresh = await tx.get(candidate.ref);
          if (!fresh.exists) return "missing";
          const order = fresh.data() || {};
          if (order.is_settled !== false) return "already-settled";

          const packingDate = order.packing_date;
          if (!(packingDate instanceof admin.firestore.Timestamp)) {
            return "missing-packing-date";
          }
          if (packingDate.toMillis() > cutoffMillis) return "not-due";

          const sellerId = String(order.seller_id || "").trim();
          const payable = Number(order.seller_earnings_payable ?? order.seller_earnings ?? 0);
          if (!sellerId || !Number.isFinite(payable) || payable < 0) {
            return "invalid-money";
          }

          if (payable === 0) {
            tx.update(candidate.ref, {
              is_settled: true,
              settled_at: admin.firestore.FieldValue.serverTimestamp(),
              settlement_via: "scheduledWalletSettlement-zero-payable",
            });
            return "settled";
          }

          const sellerRef = db.collection("users").doc(sellerId);
          const sellerSnap = await tx.get(sellerRef);
          if (!sellerSnap.exists) return "missing-seller";

          const seller = sellerSnap.data() || {};
          const walletBalance = Number(seller.wallet_balance ?? 0);
          const availableBalance = Number(seller.available_balance ?? 0);
          if (!Number.isFinite(walletBalance) || !Number.isFinite(availableBalance)) {
            return "invalid-wallet";
          }
          if (walletBalance < payable) {
            console.error("Settlement blocked by insufficient pending wallet", {
              orderId: candidate.id,
              sellerId,
              walletBalance,
              payable,
            });
            return "insufficient-wallet";
          }

          tx.set(
            sellerRef,
            {
              wallet_balance: admin.firestore.FieldValue.increment(-payable),
              available_balance: admin.firestore.FieldValue.increment(payable),
            },
            { merge: true }
          );
          tx.update(candidate.ref, {
            is_settled: true,
            settled_amount: payable,
            settled_at: admin.firestore.FieldValue.serverTimestamp(),
            settlement_via: "scheduledWalletSettlement",
          });
          return "settled";
        });

        if (result === "settled") settled += 1;
        else skipped += 1;
      } catch (error) {
        skipped += 1;
        console.error("Settlement transaction failed", {
          orderId: candidate.id,
          error: error?.message || String(error),
        });
      }
    }

    console.log("scheduledWalletSettlement finished", {
      checked,
      settled,
      skipped,
    });
  }
);
