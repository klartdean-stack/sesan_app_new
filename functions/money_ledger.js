const {
  onDocumentCreated,
  onDocumentUpdated,
} = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

if (admin.apps.length === 0) admin.initializeApp();
const db = admin.firestore();

function safeEventId(event) {
  return String(event.id || `${Date.now()}-${Math.random()}`)
    .replace(/[^a-zA-Z0-9_-]/g, "_")
    .slice(0, 180);
}

async function writeLedgerOnce(id, data) {
  const ref = db.collection("money_ledger").doc(id);
  await db.runTransaction(async (tx) => {
    const existing = await tx.get(ref);
    if (existing.exists) return;
    tx.create(ref, {
      ...data,
      created_at: admin.firestore.FieldValue.serverTimestamp(),
      immutable: true,
    });
  });
}

exports.auditOrderMoneyChanges = onDocumentUpdated(
  {
    document: "orders/{orderId}",
    region: "asia-southeast1",
  },
  async (event) => {
    const before = event.data?.before?.data() || {};
    const after = event.data?.after?.data() || {};
    const orderId = String(event.params?.orderId || "");
    const sellerId = String(after.seller_id || before.seller_id || "");
    const eventId = safeEventId(event);

    const writes = [];

    if (
      before.seller_wallet_credited !== true &&
      after.seller_wallet_credited === true
    ) {
      const amount = Number(
        after.seller_earnings_payable ?? after.seller_earnings ?? 0
      );
      writes.push(
        writeLedgerOnce(`order-pending-credit-${eventId}`, {
          type: "ORDER_PENDING_CREDIT",
          order_id: orderId,
          seller_id: sellerId,
          amount: Number.isFinite(amount) ? amount : 0,
          currency: "KHR",
          from_bucket: "order_earnings",
          to_bucket: "wallet_balance",
          source: String(after.seller_wallet_credited_via || "order_update"),
        })
      );
    }

    if (before.is_settled !== true && after.is_settled === true) {
      const amount = Number(
        after.settled_amount ??
          after.seller_earnings_payable ??
          after.seller_earnings ??
          0
      );
      writes.push(
        writeLedgerOnce(`order-settlement-${eventId}`, {
          type: "ORDER_SETTLEMENT",
          order_id: orderId,
          seller_id: sellerId,
          amount: Number.isFinite(amount) ? amount : 0,
          currency: "KHR",
          from_bucket: "wallet_balance",
          to_bucket: "available_balance",
          source: String(after.settlement_via || "order_update"),
        })
      );
    }

    const beforeDeduction = Number(before.dispute_deduction_total ?? 0);
    const afterDeduction = Number(after.dispute_deduction_total ?? 0);
    if (
      Number.isFinite(beforeDeduction) &&
      Number.isFinite(afterDeduction) &&
      afterDeduction > beforeDeduction
    ) {
      writes.push(
        writeLedgerOnce(`order-admin-deduction-${eventId}`, {
          type: "ADMIN_DEDUCTION",
          order_id: orderId,
          seller_id: sellerId,
          amount: afterDeduction - beforeDeduction,
          currency: "KHR",
          from_bucket: "seller_balance",
          to_bucket: "admin_adjustment",
          source: "secureAdminDeductBalance",
        })
      );
    }

    await Promise.all(writes);
  }
);

exports.auditWithdrawCreated = onDocumentCreated(
  {
    document: "withdraw_requests/{requestId}",
    region: "asia-southeast1",
  },
  async (event) => {
    const data = event.data?.data() || {};
    const requestId = String(event.params?.requestId || "");
    const amount = Number(data.amount ?? 0);

    await writeLedgerOnce(`withdraw-reserve-${requestId}`, {
      type: "WITHDRAWAL_RESERVED",
      request_id: requestId,
      seller_id: String(data.seller_id || data.user_id || ""),
      amount: Number.isFinite(amount) ? amount : 0,
      currency: "KHR",
      from_bucket: "available_balance",
      to_bucket: "reserved_withdraw_balance",
      source: String(data.created_via || "withdraw_request"),
    });
  }
);

exports.auditWithdrawStatus = onDocumentUpdated(
  {
    document: "withdraw_requests/{requestId}",
    region: "asia-southeast1",
  },
  async (event) => {
    const before = event.data?.before?.data() || {};
    const after = event.data?.after?.data() || {};
    if (before.status === after.status) return;

    const requestId = String(event.params?.requestId || "");
    const amount = Number(after.amount ?? 0);
    const sellerId = String(after.seller_id || after.user_id || "");

    if (after.status === "success") {
      await writeLedgerOnce(`withdraw-paid-${requestId}`, {
        type: "WITHDRAWAL_PAID",
        request_id: requestId,
        seller_id: sellerId,
        amount: Number.isFinite(amount) ? amount : 0,
        currency: "KHR",
        from_bucket: "available_balance",
        to_bucket: "external_bank",
        source: String(after.approved_via || "withdraw_update"),
        actor_uid: String(after.approved_by_uid || ""),
      });
    } else if (after.status === "rejected") {
      await writeLedgerOnce(`withdraw-rejected-${requestId}`, {
        type: "WITHDRAWAL_RESERVE_RELEASED",
        request_id: requestId,
        seller_id: sellerId,
        amount: Number.isFinite(amount) ? amount : 0,
        currency: "KHR",
        from_bucket: "reserved_withdraw_balance",
        to_bucket: "available_balance",
        source: String(after.rejected_via || "withdraw_update"),
        actor_uid: String(after.rejected_by_uid || ""),
      });
    }
  }
);

exports.auditDividendDistribution = onDocumentCreated(
  {
    document: "dividend_history/{historyId}",
    region: "asia-southeast1",
  },
  async (event) => {
    const data = event.data?.data() || {};
    const historyId = String(event.params?.historyId || "");
    await writeLedgerOnce(`dividend-${historyId}`, {
      type: "DIVIDEND_DISTRIBUTION",
      history_id: historyId,
      amount_per_share: Number(data.amount_per_share ?? 0),
      investor_count: Number(data.total_investors ?? 0),
      currency: "KHR",
      source: String(data.distributed_via || "dividend_history"),
      actor_uid: String(data.distributed_by_uid || ""),
    });
  }
);
