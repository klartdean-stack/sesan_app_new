import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SellerWithdrawalDetail extends StatelessWidget {
  final Map<String, dynamic> data;

  const SellerWithdrawalDetail({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat('#,###');

    // បំលែង Timestamp ទៅជាកាលបរិច្ឆេទសម្រាប់បង្ហាញ
    String approvedAt = data['approved_at'] != null
        ? DateFormat(
            'dd/MM/yyyy • HH:mm',
          ).format((data['approved_at'] as Timestamp).toDate())
        : "កំពុងរង់ចាំ";

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          "លម្អិតប្រតិបត្តិការ",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // ១. បង្ហាញស្ថានភាព និងចំនួនទឹកប្រាក់
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 60),
                  const SizedBox(height: 10),
                  const Text(
                    "ដកប្រាក់ជោគជ័យ",
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    "- ${currencyFormat.format(data['amount'] ?? 0)} ៛",
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.redAccent,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ២. ព័ត៌មានគណនី និងកាលបរិច្ឆេទ
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  _buildDetailRow("ឈ្មោះគណនី", data['account_name'] ?? "N/A"),
                  _buildDetailRow("លេខគណនី", data['account_number'] ?? "N/A"),
                  _buildDetailRow("អត្តសញ្ញាណប័ណ្ណ", data['id_card'] ?? "N/A"),
                  const Divider(height: 30),
                  _buildDetailRow("កាលបរិច្ឆេទអនុម័ត", approvedAt),
                  _buildDetailRow("ស្ថានភាព", "ជោគជ័យ", isStatus: true),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ៣. បង្ហាញសន្លឹកប្រតិបត្តិការដែល Admin បាញ់ឱ្យ (admin_receipt)
            if (data['admin_receipt'] != null)
              _buildImageSection(
                "សន្លឹកបញ្ជាក់ការផ្ទេរប្រាក់ (Receipt)",
                data['admin_receipt'],
              ),

            const SizedBox(height: 15),

            // ៤. បង្ហាញ QR របស់ Seller (khqr_url)
            if (data['khqr_url'] != null)
              _buildImageSection("កូដ QR សម្រាប់ទទួលលុយ", data['khqr_url']),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isStatus = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: isStatus ? Colors.green : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageSection(String title, String imageUrl) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 5, bottom: 10),
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
        ),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.network(
              imageUrl,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return const Padding(
                  padding: EdgeInsets.all(40.0),
                  child: Center(child: CircularProgressIndicator()),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}
