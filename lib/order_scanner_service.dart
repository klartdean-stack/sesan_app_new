import 'package:flutter/material.dart';
import 'package:ai_barcode_scanner/ai_barcode_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OrderScannerService {
  // មុខងារបើកកាមេរ៉ាស្កែន
  static void startScan(BuildContext context, String currentSellerId) {


  }

  // មុខងារឆែកទិន្នន័យបន្ទាប់ពីស្កែនបាន ID
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
    // ឆែកថាមាន Seller ID របស់គាត់ក្នុងបុងហ្នឹងអត់ (ករណី ១ បុង ច្រើន Seller)
    List sellerIds = data['seller_ids'] ?? [];

    if (!sellerIds.contains(sellerId)) {
      _showMsg(context, "បុងនេះមិនមែនជារបស់មេទេ!", Colors.orange);
      return;
    }

    // បង្ហាញផ្ទាំង Update
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }
}
