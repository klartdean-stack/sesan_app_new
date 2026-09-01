import 'package:flutter/material.dart';
import 'package:ai_barcode_scanner/ai_barcode_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OrderScannerService {
  static void startScan(BuildContext context, String currentSellerId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AiBarcodeScanner(
          onDetect: (BarcodeCapture capture) {
            final String? value = capture.barcodes.first.rawValue;
            if (value != null) {
              Navigator.pop(context);
              _processScannedOrder(context, value, currentSellerId);
            }
          },
        ),
      ),
    );
  }

  static void _processScannedOrder(
    BuildContext context,
    String orderId,
    String sellerId,
  ) async {
    var doc = await FirebaseFirestore.instance
        .collection('orders')
        .doc(orderId)
        .get();

    if (!doc.exists) {
      _showMsg(context, "រកមិនឃើញបុងនេះទេ!", Colors.red);
      return;
    }

    var data = doc.data() as Map<String, dynamic>;
    List sellerIds = data['seller_ids'] ?? [];

    if (!sellerIds.contains(sellerId)) {
      _showMsg(context, "បុងនេះមិនមែនជារបស់មេទេ!", Colors.orange);
      return;
    }

    _showUpdateDialog(context, orderId, data);
  }

  static void _showUpdateDialog(BuildContext context, String id, Map data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("ស្កែនឃើញអីវ៉ាន់"),
        content: Text("ID: $id\nស្ថានភាពបច្ចុប្បន្ន: ${data['status']}"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("បោះបង់"),
          ),
          ElevatedButton(
            onPressed: () {
              FirebaseFirestore.instance.collection('orders').doc(id).update({
                'status': 'on_delivery',
              });
              Navigator.pop(context);
            },
            child: const Text("ប្ដូរទៅ 'កំពុងដឹក'"),
          ),
        ],
      ),
    );
  }

  static void _showMsg(BuildContext context, String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }
}
