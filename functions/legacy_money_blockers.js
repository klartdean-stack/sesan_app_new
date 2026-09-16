const { onDocumentUpdated } = require("firebase-functions/v2/firestore");

// SECURITY: Legacy approveSale used client-controlled sales/{saleId}.status to move
// wallet_balance -> available_balance. Keep the deployed function name so Firebase
// updates the existing trigger, but intentionally perform no money mutation.
exports.approveSale = onDocumentUpdated(
  {
    document: "sales/{saleId}",
    region: "asia-southeast1",
  },
  async (event) => {
    console.log("approveSale legacy money path disabled", {
      saleId: event.params?.saleId || "",
    });
  }
);

// SECURITY: today_income is now updated inside secureSellerOrderStatus-v2 in the
// same authenticated transaction that credits the seller pending wallet. This old
// order-update trigger is kept only as a no-op to prevent direct client status writes
// from changing money-related counters.
exports.onOrderPackingUpdate = onDocumentUpdated(
  {
    document: "orders/{orderId}",
    region: "asia-southeast1",
  },
  async (event) => {
    console.log("onOrderPackingUpdate legacy money path disabled", {
      orderId: event.params?.orderId || "",
    });
  }
);
