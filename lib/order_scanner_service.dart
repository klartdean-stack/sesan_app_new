import 'package:ai_barcode_scanner/ai_barcode_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

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

  static Future<void> _processScannedOrder(
    BuildContext context,
    String orderId,
    String sellerId,
  ) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .get();

      if (!doc.exists) {
        _showMsg(context, 'រកមិនឃើញបុងនេះទេ!', Colors.red);
        return;
      }

      final data = doc.data() as Map<String, dynamic>;
      final directSellerId = (data['seller_id'] ?? '').toString();
      final legacySellerIds = (data['seller_ids'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const <String>[];

      if (directSellerId != sellerId && !legacySellerIds.contains(sellerId)) {
        _showMsg(context, 'បុងនេះមិនមែនជារបស់មេទេ!', Colors.orange);
        return;
      }

      _showUpdateDialog(context, orderId, data);
    } catch (e) {
      _showMsg(context, 'មានបញ្ហាទាញ Order: $e', Colors.red);
    }
  }

  static void _showUpdateDialog(
    BuildContext context,
    String id,
    Map<String, dynamic> data,
  ) {
    bool isSubmitting = false;
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('ស្កែនឃើញអីវ៉ាន់'),
          content: Text(
            "ID: $id\nស្ថានភាពបច្ចុប្បន្ន: ${data['status'] ?? 'N/A'}",
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting
                  ? null
                  : () => Navigator.pop(dialogContext),
              child: const Text('បោះបង់'),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      setDialogState(() => isSubmitting = true);
                      try {
                        final callable = FirebaseFunctions.instanceFor(
                          region: 'asia-southeast1',
                        ).httpsCallable('secureSellerOrderStatus');
                        await callable.call({
                          'orderId': id,
                          'status': 'on_delivery',
                        });
                        if (!dialogContext.mounted) return;
                        Navigator.pop(dialogContext);
                        if (context.mounted) {
                          _showMsg(
                            context,
                            "បានប្ដូរទៅ 'កំពុងដឹក'",
                            Colors.green,
                          );
                        }
                      } on FirebaseFunctionsException catch (e) {
                        if (dialogContext.mounted) {
                          setDialogState(() => isSubmitting = false);
                        }
                        if (context.mounted) {
                          _showMsg(
                            context,
                            e.message ?? 'មិនអាចប្ដូរស្ថានភាពបានទេ',
                            Colors.red,
                          );
                        }
                      } catch (e) {
                        if (dialogContext.mounted) {
                          setDialogState(() => isSubmitting = false);
                        }
                        if (context.mounted) {
                          _showMsg(context, 'Error: $e', Colors.red);
                        }
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text("ប្ដូរទៅ 'កំពុងដឹក'"),
            ),
          ],
        ),
      ),
    );
  }

  static void _showMsg(BuildContext context, String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }
}
