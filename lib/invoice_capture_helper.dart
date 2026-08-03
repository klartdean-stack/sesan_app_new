import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:screenshot/screenshot.dart';
import 'package:gal/gal.dart';
import 'package:my_app/create_invoice_sheet.dart';

class InvoiceCaptureHelper {
  /// ថតវិក្កយបត្រទាំងមូល (បំបែកជាច្រើនសន្លឹកបើចាំបាច់)
  static Future<void> captureInvoice({
    required BuildContext context,
    required ScreenshotController screenshotController,
    required String sellerName,
    required String sellerPhone,
    required String sellerSesanId,
    required String sellerLocation,
  }) async {
    try {
      // ✅ អានថ្លៃដឹកជញ្ជូនពី CreateInvoiceSheet
      final String shipText = CreateInvoiceSheet.shipPrice.text.replaceAll(
        ',',
        '',
      );
      final double shipPrice = double.tryParse(shipText) ?? 0.0;

      // ✅ គណនាថ្លៃសរុបទំនិញ (មិនរាប់ថ្លៃដឹក)
      double subtotal = CreateInvoiceSheet.items.fold(0, (sum, item) {
        final qtyText = item['qty']!.text.replaceAll(',', '');
        final priceText = item['price']!.text.replaceAll(',', '');
        final qty = double.tryParse(qtyText) ?? 0;
        final price = double.tryParse(priceText) ?? 0;
        return sum + (qty * price);
      });

      final double totalWithShipping = subtotal + shipPrice;

      const int itemsPerPage = 10;
      int totalItems = CreateInvoiceSheet.items.length;
      int totalPages = (totalItems / itemsPerPage).ceil();

      for (int i = 0; i < totalPages; i++) {
        int start = i * itemsPerPage;
        int end = (start + itemsPerPage > totalItems)
            ? totalItems
            : start + itemsPerPage;
        List currentPageItems = CreateInvoiceSheet.items.sublist(start, end);

        final imageUint8List = await screenshotController.captureFromWidget(
            Material(
                color: Colors.white,
                child: Directionality(
                    textDirection: ui.TextDirection.ltr,
                    child: Container(
                      width: 375,
                      padding: const EdgeInsets.all(15),
                      color: Colors.white,
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                          if (i == 0)
                      _buildCaptureHeader(
                      sellerName: sellerName,
                      sellerPhone: sellerPhone,
                      sellerSesanId: sellerSesanId,
                      sellerLocation: sellerLocation,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "បញ្ជីទំនិញ (សន្លឹកទី ${i + 1})",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.black,
                      ),
                    ),
                    const Divider(thickness: 1, color: Colors.black),
                    ...currentPageItems.asMap().entries.map((entry) {
                  int localIndex = entry.key;
                  dynamic item = entry.value;
                  int globalIndex = start + localIndex;
                  return _buildCaptureItemRow(item, globalIndex);
                }).toList(),
                if (i == totalPages - 1) ...[
            const Divider(thickness: 1, color: Colors.black),
            _buildCaptureTotalAndQR(
        subtotal: subtotal,
        shipPrice: shipPrice,
        totalWithShipping: totalWithShipping,
        ),
    ],
    const SizedBox(height: 6),
    Center(
    child: Text(
    "--- ${i + 1} / $totalPages ---",
    style: const TextStyle(
    fontSize: 10,
    color: Colors.grey,
    ),
    ),
    ),],
                      ),
                    ),
                ),
            ),
          pixelRatio: 3.0,
        );

        if (imageUint8List != null) {
          await Gal.putImageBytes(imageUint8List);
        }
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("✅ បានថតបំបែកជា $totalPages សន្លឹកក្នុង Gallery"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint("❌ Invoice capture error: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("❌ ថតមិនបាន៖ $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ─── Widgets សម្រាប់បង្កើតរូបភាពវិក្កយបត្រ ──────────────

  static Widget _buildCaptureHeader({
    required String sellerName,
    required String sellerPhone,
    required String sellerSesanId,
    required String sellerLocation,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Center(
          child: Text(
            "វិក្កយបត្រ / INVOICE",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ),
        const SizedBox(height: 2),
        const Divider(thickness: 1.5, color: Colors.black),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '🏪 អ្នកលក់៖ $sellerName',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  color: Colors.black,
                ),
              ),
              if (sellerPhone.isNotEmpty) ...[
                const SizedBox(height: 1),
                Text(
                  '📞 លេខទូរស័ព្ទ៖ $sellerPhone',
                  style: const TextStyle(fontSize: 10, color: Colors.black87),
                ),
              ],
              if (sellerSesanId.isNotEmpty) ...[
                const SizedBox(height: 1),
                Text(
                  '🆔 Sesan ID៖ $sellerSesanId',
                  style: const TextStyle(fontSize: 10, color: Colors.black87),
                ),
              ],
              if (sellerLocation.isNotEmpty) ...[
                const SizedBox(height: 1),
                Text(
                  '📍 ទីតាំង៖ $sellerLocation',
                  style: const TextStyle(fontSize: 10, color: Colors.black87),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "👤 អ្នកទិញ៖ ${CreateInvoiceSheet.cusName.text}",
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                "📞 លេខទូរស័ព្ទ៖ ${CreateInvoiceSheet.cusPhone.text}",
                style: const TextStyle(fontSize: 10, color: Colors.black87),
              ),
              const SizedBox(height: 1),
              Text(
                "🏠 អាសយដ្ឋាន៖ ${CreateInvoiceSheet.cusAddress.text}",
                style: const TextStyle(fontSize: 10, color: Colors.black87),
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
      ],
    );
  }

  static Widget _buildCaptureItemRow(dynamic item, int index) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            child: Text(
              "${index + 1}.",
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(
              item['desc']!.text,
              style: const TextStyle(color: Colors.black),
            ),
          ),
          Text(
            "${item['qty']!.text} x ${item['price']!.text} ៛",
            style: const TextStyle(color: Colors.black),
          ),
        ],
      ),
    );
  }

  static Widget _buildCaptureTotalAndQR({
    required double subtotal,
    required double shipPrice,
    required double totalWithShipping,
  }) {
    return Column(
      children: [
        // ✅ បង្ហាញថ្លៃដឹកជញ្ជូន
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "ថ្លៃដឹកជញ្ជូន៖",
              style: TextStyle(fontSize: 14, color: Colors.black87),
            ),
            Text(
              "${NumberFormat('#,###').format(shipPrice)} ៛",
              style: const TextStyle(fontSize: 14, color: Colors.black87),
            ),
          ],
        ),
        const SizedBox(height: 4),
        // ✅ បង្ហាញសរុបចុងក្រោយ (រួមទាំងថ្លៃដឹក)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "សរុបចុងក្រោយ៖",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            Text(
              "${NumberFormat('#,###').format(totalWithShipping)} ៛",
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
          ],
        ),
        if (CreateInvoiceSheet.qrFile != null) ...[
          const SizedBox(height: 20),
          const Center(
            child: Text(
              "Scan ដើម្បីបង់ប្រាក់",
              style: TextStyle(fontSize: 12, color: Colors.black),
            ),
          ),
          const SizedBox(height: 10),
          Center(child: Image.file(CreateInvoiceSheet.qrFile!, width: 160)),
        ],
      ],
    );
  }

  /// គណនាថ្លៃសរុប (រួមទាំងថ្លៃដឹក)
  static double calculateGrandTotal() {
    double subtotal = CreateInvoiceSheet.items.fold(0, (sum, item) {
      final qtyText = item['qty']!.text.replaceAll(',', '');
      final priceText = item['price']!.text.replaceAll(',', '');
      final qty = double.tryParse(qtyText) ?? 0;
      final price = double.tryParse(priceText) ?? 0;
      return sum + (qty * price);
    });
    final shipText = CreateInvoiceSheet.shipPrice.text.replaceAll(',', '');
    final shipPrice = double.tryParse(shipText) ?? 0.0;
    return subtotal + shipPrice;
  }
}