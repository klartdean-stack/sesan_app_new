import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AppAccountantScreen extends StatelessWidget {
  const AppAccountantScreen({super.key});

  String _t(BuildContext context, String km, String en) =>
      Localizations.localeOf(context).languageCode == 'en' ? en : km;

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat("#,###", "en_US");

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF1A1A2E),
        title: Text(
          _t(context, 'Accountant Pro ជំនួយការ Admin', 'Accountant Pro · Admin Assistant'),
          style: const TextStyle(
            color: Colors.amber,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('system_settings')
            .doc('wallet')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                _t(context, 'មានបញ្ហាទិន្នន័យ', 'Unable to load financial data'),
                style: const TextStyle(color: Colors.white),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};

          return ListView(
            padding: const EdgeInsets.all(15),
            children: [
              _buildFinanceCard(
                _t(context, 'ចំណូលសរុប (100%)', 'Gross revenue (100%)'),
                data['total_gross_revenue'] ?? 0,
                Colors.blueAccent,
                Icons.trending_up,
                currencyFormat,
              ),
              const SizedBox(height: 12),
              _buildFinanceCard(
                _t(context, 'ប្រាក់ចំណេញសុទ្ធ (7%)', 'Company earnings (7%)'),
                data['total_earnings'] ?? 0,
                Colors.greenAccent,
                Icons.account_balance_wallet,
                currencyFormat,
              ),
              const SizedBox(height: 12),
              _buildFinanceCard(
                _t(context, 'បានទូទាត់ទៅអ្នកលក់ (93%)', 'Paid to sellers (93%)'),
                data['total_seller_payout'] ?? 0,
                Colors.orangeAccent,
                Icons.outbox,
                currencyFormat,
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Divider(color: Colors.white24, thickness: 1),
              ),
              _buildFinanceCard(
                _t(context, 'លុយ 7% កំពុងរង់ចាំ', 'Pending commission (7%)'),
                data['pending_commissions'] ?? 0,
                Colors.grey,
                Icons.hourglass_bottom,
                currencyFormat,
              ),
              const SizedBox(height: 20),
              Text(
                _t(context, 'របាយការណ៍សង្ខេប', 'Summary'),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              ListTile(
                leading: const Icon(Icons.check_circle, color: Colors.blue),
                title: Text(
                  _t(
                    context,
                    'រាល់ទិន្នន័យត្រូវបានបូកសរុបស្វ័យប្រវត្តិពេលអ្នកលក់ទទួលយកការបញ្ជាទិញ',
                    'Financial totals are updated automatically when a seller accepts an order.',
                  ),
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFinanceCard(
    String title,
    dynamic amount,
    Color color,
    IconData icon,
    NumberFormat format,
  ) {
    final value = double.tryParse(amount.toString()) ?? 0;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 5),
                Text(
                  '${format.format(value)} ៛',
                  style: TextStyle(
                    color: color,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
