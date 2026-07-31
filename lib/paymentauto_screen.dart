import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class PaymentScreen extends StatelessWidget {
  final double totalAmount;
  final String orderId;

  const PaymentScreen({
    super.key,
    required this.totalAmount,
    required this.orderId,
  });

  // 🎯 កូដបង្កើត KHQR String ដោយប្រើដៃ (No Package Needed)
  String _generateManualKHQR() {
    // នេះជាស្ដង់ដារ KHQR សម្រាប់ ABA
    // មេគ្រាន់តែដូរលេខគណនី "005678716" ទៅជាលេខរបស់មេផ្ទាល់
    String receiverId = "005678716@aba";
    String amountStr = totalAmount.toStringAsFixed(0);

    // Logic នេះនឹងបង្កើត String ឱ្យមេអូតូ (មេមិនបាច់កែទេ)
    return "00020101021226${receiverId.length + 24}0012$receiverId" +
        "520459995303116540${amountStr.length}$amountStr" +
        "5802KH5910DEAN KLART6010Phnom Penh6304";
  }

  Future<void> _launchABA() async {
    final qrData = _generateManualKHQR();
    final url = Uri.parse('abapay://qr?data=$qrData');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F101A),
      appBar: AppBar(title: const Text("ទូទាត់ប្រាក់")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "ទឹកប្រាក់៖ $totalAmount ៛",
              style: const TextStyle(
                color: Colors.red,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(10),
              child: QrImageView(
                data: _generateManualKHQR(),
                version: QrVersions.auto,
                size: 250.0,
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _launchABA,
              child: const Text("បើក App ABA បង់លុយអូតូ"),
            ),
          ],
        ),
      ),
    );
  }
}
