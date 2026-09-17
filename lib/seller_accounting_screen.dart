import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:my_app/order_detail_screen.dart';
import 'package:my_app/seller_withdrawal_detail.dart';
import 'package:rxdart/rxdart.dart';

class SellerAccountingScreen extends StatefulWidget {
  final String sellerId;
  const SellerAccountingScreen({super.key, required this.sellerId});

  @override
  State<SellerAccountingScreen> createState() => _SellerAccountingScreenState();
}

class _SellerAccountingScreenState extends State<SellerAccountingScreen> {
  final currencyFormat = NumberFormat('#,###');

  String _t(String km, String en) =>
      Localizations.localeOf(context).languageCode == 'en' ? en : km;

  Stream<List<Map<String, dynamic>>> _getCombinedTransactions() {
    final incomeStream = FirebaseFirestore.instance
        .collection('orders')
        .where('seller_id', isEqualTo: widget.sellerId)
        .where('status', whereIn: ['packing', 'on_delivery', 'delivered', 'payout_completed'])
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              return {
                ...data,
                'id': doc.id,
                'trans_type': 'income',
                'display_date': data['display_date'] ?? data['admin_confirmed_at'] ?? data['created_at'],
              };
            }).toList());

    final withdrawStream = FirebaseFirestore.instance
        .collection('withdraw_requests')
        .where('seller_id', isEqualTo: widget.sellerId)
        .where('status', isEqualTo: 'success')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              return {
                ...data,
                'id': doc.id,
                'trans_type': 'withdraw',
                'display_date': data['approved_at'] ?? data['date'],
              };
            }).toList());

    return Rx.combineLatest2<List<Map<String, dynamic>>, List<Map<String, dynamic>>, List<Map<String, dynamic>>>(
      incomeStream,
      withdrawStream,
      (incomes, withdraws) {
        final all = [...incomes, ...withdraws];
        all.sort((a, b) {
          final tA = a['display_date'] is Timestamp ? a['display_date'] as Timestamp : Timestamp(0, 0);
          final tB = b['display_date'] is Timestamp ? b['display_date'] as Timestamp : Timestamp(0, 0);
          return tB.compareTo(tA);
        });
        return all;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FA),
      appBar: AppBar(
        elevation: 0,
        title: Text(
          _t('មជ្ឈមណ្ឌលហិរញ្ញវត្ថុ', 'Finance Center'),
          style: const TextStyle(fontFamily: 'KHMEROS', fontSize: 18, fontWeight: FontWeight.bold),
        ),
        foregroundColor: Colors.white,
        backgroundColor: const Color(0xFF1A237E),
        centerTitle: true,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(widget.sellerId).snapshots(),
        builder: (context, walletSnapshot) {
          if (walletSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final walletData = walletSnapshot.data?.data() as Map<String, dynamic>?;
          final totalBalance = (walletData?['balance'] ?? 0).toDouble();
          final todayEarnings = (walletData?['today_income'] ?? 0).toDouble();
          final totalWithdraw = (walletData?['total_withdraw'] ?? 0).toDouble();

          return StreamBuilder<List<Map<String, dynamic>>>(
            stream: _getCombinedTransactions(),
            builder: (context, snapshot) {
              final transactions = snapshot.data ?? [];
              return Column(
                children: [
                  _buildBankStyleHeader(totalBalance, todayEarnings, totalWithdraw),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(25, 25, 25, 10),
                            child: Text(
                              _t('ប្រតិបត្តិការថ្មីៗ', 'Recent transactions'),
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A237E)),
                            ),
                          ),
                          Expanded(
                            child: transactions.isEmpty
                                ? _buildEmptyState()
                                : ListView.builder(
                                    padding: const EdgeInsets.symmetric(horizontal: 15),
                                    itemCount: transactions.length,
                                    itemBuilder: (context, index) => _buildTransactionItem(transactions[index]),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildBankStyleHeader(double total, double today, double withdraw) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 35),
      decoration: const BoxDecoration(color: Color(0xFF1A237E)),
      child: Column(
        children: [
          Text(_t('សមតុល្យសរុប', 'Total balance'), style: const TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 10),
          Text('${currencyFormat.format(total)} ៛', style: const TextStyle(color: Colors.white, fontSize: 35, fontWeight: FontWeight.bold)),
          const SizedBox(height: 30),
          Row(
            children: [
              _buildFlowCard(_t('ចំណូលថ្ងៃនេះ', "Today's income"), today, Icons.arrow_downward, Colors.greenAccent),
              const SizedBox(width: 15),
              _buildFlowCard(_t('ដកប្រាក់សរុប', 'Total withdrawn'), withdraw, Icons.arrow_upward, Colors.orangeAccent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFlowCard(String label, double amount, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [Icon(icon, color: color, size: 16), const SizedBox(width: 5), Expanded(child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)))]),
            const SizedBox(height: 8),
            Text('${currencyFormat.format(amount)} ៛', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionItem(Map<String, dynamic> data) {
    final isWithdraw = data['trans_type'] == 'withdraw';
    final amount = (data['seller_earnings'] ?? data['amount'] ?? 0).toDouble();
    final ts = data['display_date'] is Timestamp ? data['display_date'] as Timestamp : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          if (isWithdraw) {
            Navigator.push(context, MaterialPageRoute(builder: (context) => SellerWithdrawalDetail(data: data)));
          } else {
            Navigator.push(context, MaterialPageRoute(builder: (context) => OrderDetailScreen(orderId: data['order_id'] ?? data['id'] ?? '')));
          }
        },
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Row(
            children: [
              Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  color: isWithdraw ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(isWithdraw ? Icons.upload_rounded : Icons.download_rounded, color: isWithdraw ? Colors.redAccent : Colors.green, size: 20),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isWithdraw ? _t('ដកប្រាក់ចេញ', 'Withdrawal') : _t('ចំណូលបានពីការលក់', 'Sales income'),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1A237E), fontFamily: 'KHMEROS'),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      ts != null ? DateFormat('dd/MM/yyyy • HH:mm').format(ts.toDate()) : _t('មិនទាន់មានកាលបរិច្ឆេទ', 'No date available'),
                      style: TextStyle(color: Colors.grey[500], fontSize: 11),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${isWithdraw ? '-' : '+'} ${currencyFormat.format(amount)} ៛',
                    style: TextStyle(color: isWithdraw ? Colors.redAccent : Colors.green, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.grey[300]),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_rounded, size: 60, color: Colors.grey[300]),
          const SizedBox(height: 10),
          Text(_t('មិនទាន់មានប្រតិបត្តិការនៅឡើយ', 'No transactions yet'), style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
