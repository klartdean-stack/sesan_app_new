const { onCall, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

if (admin.apps.length === 0) admin.initializeApp();
const db = admin.firestore();
const ADMIN_UIDS = new Set(["WBdQVvrgEIPBTcgIlumu6bAZGUl2"]);
const FEE_RATE = 0.07;

function requireAdmin(request) {
  if (!request.auth) throw new HttpsError("unauthenticated", "សូមចូលគណនីជាមុនសិន!");
  if (!ADMIN_UIDS.has(request.auth.uid)) {
    throw new HttpsError("permission-denied", "អ្នកមិនមានសិទ្ធិ Admin ទេ!");
  }
  return request.auth.uid;
}

function money(value) {
  const n = Number(value);
  if (!Number.isFinite(n) || n < 0) throw new HttpsError("failed-precondition", "ទិន្នន័យតម្លៃមិនត្រឹមត្រូវ");
  return Math.round(n);
}

function itemKey(item, index) {
  return String(item?.line_id || item?.cart_item_id || item?.product_id || index);
}

exports.secureAdminPreviewRefund = onCall(
  { region: "asia-southeast1" },
  async (request) => {
    requireAdmin(request);
    const orderId = String(request.data?.orderId || "").trim();
    const selections = Array.isArray(request.data?.items) ? request.data.items : [];
    const liableParty = String(request.data?.liableParty || "").trim();
    if (!orderId || selections.length === 0) {
      throw new HttpsError("invalid-argument", "សូមជ្រើសទំនិញដែលត្រូវ Refund");
    }
    const snap = await db.collection("orders").doc(orderId).get();
    if (!snap.exists) throw new HttpsError("not-found", "រកមិនឃើញ Order");
    const order = snap.data() || {};
    const items = Array.isArray(order.items) ? order.items : [];
    let refundAmount = 0;
    const lines = [];
    for (const choice of selections) {
      const index = Number(choice?.index);
      if (!Number.isInteger(index) || index < 0 || index >= items.length) {
        throw new HttpsError("invalid-argument", "ជួរទំនិញមិនត្រឹមត្រូវ");
      }
      const item = items[index] || {};
      const orderedQty = money(item.quantity ?? 1);
      const refundQty = money(choice.refundQty);
      if (refundQty <= 0 || refundQty > orderedQty) {
        throw new HttpsError("invalid-argument", "ចំនួន Refund លើសចំនួនបញ្ជាទិញ");
      }
      const unitPrice = money(item.price ?? item.unit_price ?? 0);
      const amount = unitPrice * refundQty;
      refundAmount += amount;
      lines.push({
        index,
        lineId: itemKey(item, index),
        productId: String(item.product_id || ""),
        productName: String(item.product_name || item.name || "ទំនិញ"),
        sellerId: String(item.seller_id || order.seller_id || ""),
        orderedQty,
        refundQty,
        unitPrice,
        refundAmount: amount,
      });
    }
    const adminFee = liableParty === "seller" ? Math.round(refundAmount * FEE_RATE) : 0;
    return {
      success: true,
      currency: "KHR",
      refundAmount,
      adminFee,
      commissionReversed: Math.round(refundAmount * FEE_RATE),
      buyerReceives: refundAmount,
      lines,
    };
  }
);

exports.secureAdminProcessRefund = onCall(
  { region: "asia-southeast1", timeoutSeconds: 60 },
  async (request) => {
    const adminUid = requireAdmin(request);
    const orderId = String(request.data?.orderId || "").trim();
    const complaintId = String(request.data?.complaintId || "").trim();
    const reason = String(request.data?.reason || "").trim();
    const liableParty = String(request.data?.liableParty || "").trim();
    const selections = Array.isArray(request.data?.items) ? request.data.items : [];

    if (!orderId || !complaintId || !reason || selections.length === 0) {
      throw new HttpsError("invalid-argument", "ព័ត៌មាន Refund មិនទាន់គ្រប់");
    }
    if (!["seller", "buyer", "carrier", "sesan"].includes(liableParty)) {
      throw new HttpsError("invalid-argument", "អ្នកទទួលខុសត្រូវមិនត្រឹមត្រូវ");
    }

    const orderRef = db.collection("orders").doc(orderId);
    const complaintRef = db.collection("complaints").doc(complaintId);
    const refundRef = db.collection("refunds").doc();
    const ledgerRef = db.collection("money_ledger").doc("refund-" + refundRef.id);

    const result = await db.runTransaction(async (tx) => {
      const [orderSnap, complaintSnap] = await Promise.all([
        tx.get(orderRef),
        tx.get(complaintRef),
      ]);
      if (!orderSnap.exists) throw new HttpsError("not-found", "រកមិនឃើញ Order");
      if (!complaintSnap.exists) throw new HttpsError("not-found", "រកមិនឃើញបណ្ដឹង");
      const complaint = complaintSnap.data() || {};
      if (String(complaint.order_id || complaint.orderId || "") !== orderId) {
        throw new HttpsError("failed-precondition", "បណ្ដឹងមិនត្រូវនឹង Order");
      }
      if (complaint.refund_processed === true) {
        throw new HttpsError("already-exists", "បណ្ដឹងនេះបាន Refund រួចហើយ");
      }

      const order = orderSnap.data() || {};
      const orderItems = Array.isArray(order.items) ? order.items : [];
      const previous = Array.isArray(order.refund_lines) ? order.refund_lines : [];
      const alreadyByLine = new Map();
      for (const line of previous) {
        const key = String(line.line_id || line.lineId || line.product_id || line.index);
        alreadyByLine.set(key, (alreadyByLine.get(key) || 0) + money(line.refund_qty || line.refundQty || 0));
      }

      const lines = [];
      const sellerTotals = new Map();
      let refundAmount = 0;
      for (const choice of selections) {
        const index = Number(choice?.index);
        if (!Number.isInteger(index) || index < 0 || index >= orderItems.length) {
          throw new HttpsError("invalid-argument", "ជួរទំនិញមិនត្រឹមត្រូវ");
        }
        const item = orderItems[index] || {};
        const key = itemKey(item, index);
        const orderedQty = money(item.quantity ?? 1);
        const refundQty = money(choice.refundQty);
        const previouslyRefunded = alreadyByLine.get(key) || 0;
        if (refundQty <= 0 || refundQty + previouslyRefunded > orderedQty) {
          throw new HttpsError("failed-precondition", "ចំនួន Refund លើសចំនួនដែលនៅសល់");
        }
        const unitPrice = money(item.price ?? item.unit_price ?? 0);
        const amount = unitPrice * refundQty;
        const sellerId = String(item.seller_id || order.seller_id || "").trim();
        if (!sellerId) throw new HttpsError("failed-precondition", "ទំនិញគ្មាន Seller ID");
        refundAmount += amount;
        sellerTotals.set(sellerId, (sellerTotals.get(sellerId) || 0) + amount);
        lines.push({
          index,
          line_id: key,
          product_id: String(item.product_id || ""),
          product_name: String(item.product_name || item.name || "ទំនិញ"),
          seller_id: sellerId,
          ordered_qty: orderedQty,
          refund_qty: refundQty,
          unit_price: unitPrice,
          refund_amount: amount,
          status: refundQty + previouslyRefunded === orderedQty ? "refunded" : "partial_refund",
        });
      }

      const customerId = String(order.customer_id || order.customerId || "").trim();
      if (!customerId) throw new HttpsError("failed-precondition", "Order គ្មាន Buyer ID");
      const buyerRef = db.collection("users").doc(customerId);
      const sellerRefs = [...sellerTotals.keys()].map((id) => db.collection("users").doc(id));
      const accountSnaps = await Promise.all([tx.get(buyerRef), ...sellerRefs.map((r) => tx.get(r))]);
      if (!accountSnaps[0].exists) throw new HttpsError("not-found", "រកមិនឃើញកាបូប Buyer");

      const sellerResults = [];
      for (let i = 0; i < sellerRefs.length; i++) {
        const sellerRef = sellerRefs[i];
        const sellerSnap = accountSnaps[i + 1];
        if (!sellerSnap.exists) throw new HttpsError("not-found", "រកមិនឃើញកាបូប Seller");
        const sellerId = sellerRef.id;
        const gross = sellerTotals.get(sellerId) || 0;
        const commission = Math.round(gross * FEE_RATE);
        const earningsReversal = gross - commission;
        const adminFee = liableParty === "seller" ? commission : 0;
        const seller = sellerSnap.data() || {};
        let pending = money(seller.wallet_balance ?? 0);
        let available = money(seller.available_balance ?? 0);
        let debt = money(seller.refund_debt_balance ?? 0);
        let remaining = earningsReversal + adminFee;

        const fromPending = Math.min(pending, remaining);
        pending -= fromPending;
        remaining -= fromPending;
        const fromAvailable = Math.min(available, remaining);
        available -= fromAvailable;
        remaining -= fromAvailable;
        debt += remaining;

        tx.set(sellerRef, {
          wallet_balance: pending,
          available_balance: available,
          refund_debt_balance: debt,
          refund_frozen_balance: admin.firestore.FieldValue.increment(0),
          withdrawal_blocked_by_refund: debt > 0,
          wallet_updated_at: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });

        sellerResults.push({
          seller_id: sellerId,
          gross_refund: gross,
          commission_reversed: commission,
          earnings_reversed: earningsReversal,
          admin_fee: adminFee,
          deducted_pending: fromPending,
          deducted_available: fromAvailable,
          debt_created: remaining,
        });
      }

      tx.set(buyerRef, {
        available_balance: admin.firestore.FieldValue.increment(refundAmount),
        refund_received_total: admin.firestore.FieldValue.increment(refundAmount),
        wallet_updated_at: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });

      const allRefunded = orderItems.every((item, index) => {
        const key = itemKey(item, index);
        const oldQty = alreadyByLine.get(key) || 0;
        const newQty = lines.filter((l) => l.line_id === key).reduce((n, l) => n + l.refund_qty, 0);
        return oldQty + newQty >= money(item?.quantity ?? 1);
      });
      const now = admin.firestore.FieldValue.serverTimestamp();
      const adminFeeTotal = sellerResults.reduce((n, s) => n + s.admin_fee, 0);
      const commissionReversed = sellerResults.reduce((n, s) => n + s.commission_reversed, 0);

      tx.set(refundRef, {
        order_id: orderId,
        complaint_id: complaintId,
        customer_id: customerId,
        lines,
        seller_results: sellerResults,
        liable_party: liableParty,
        reason,
        refund_amount: refundAmount,
        buyer_receives: refundAmount,
        admin_fee: adminFeeTotal,
        commission_reversed: commissionReversed,
        fee_rate: FEE_RATE,
        currency: "KHR",
        status: "completed",
        processed_by_uid: adminUid,
        processed_at: now,
        immutable: true,
      });
      tx.set(ledgerRef, {
        type: "REFUND",
        refund_id: refundRef.id,
        order_id: orderId,
        complaint_id: complaintId,
        amount: refundAmount,
        admin_fee: adminFeeTotal,
        commission_reversed: commissionReversed,
        currency: "KHR",
        actor_uid: adminUid,
        created_at: now,
        immutable: true,
      });
      tx.update(complaintRef, {
        status: "refunded",
        refund_processed: true,
        refund_id: refundRef.id,
        refund_amount: refundAmount,
        resolved_by_uid: adminUid,
        resolved_at: now,
      });
      tx.update(orderRef, {
        refund_status: allRefunded ? "refunded" : "partially_refunded",
        refund_lines: admin.firestore.FieldValue.arrayUnion(...lines),
        refunded_total: admin.firestore.FieldValue.increment(refundAmount),
        last_refund_id: refundRef.id,
        last_refund_at: now,
      });
      return { refundAmount, adminFee: adminFeeTotal, refundId: refundRef.id, allRefunded };
    });

    return { success: true, ...result };
  }
);
