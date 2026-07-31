import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

  // 🎯 Stream រួមបញ្ចូលគ្នា (Orders + Withdraw Requests)
  Stream<List<Map<String, dynamic>>> _getCombinedTransactions() {
    // ១. Stream លុយចូល (ទាញពី Collection orders)
    var incomeStream = FirebaseFirestore.instance
        .collection('orders')
        .where('seller_id', isEqualTo: widget.sellerId)
        .where(
          'status',
          whereIn: ['packing', 'on_delivery', 'delivered', 'payout_completed'],
        )
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map((doc) {
            var data = doc.data();
            return {
              ...data,
              'id': doc.id,
              'trans_type': 'income',
              // បើអត់មាន display_date ឱ្យប្រើ admin_confirmed_at ឬ created_at ជំនួស
              'display_date':
                  data['display_date'] ??
                  data['admin_confirmed_at'] ??
                  data['created_at'],
            };
          }).toList(),
        );

    // ២. Stream លុយចេញ (ទាញពី Collection withdraw_requests)
    var withdrawStream = FirebaseFirestore.instance
        .collection('withdraw_requests')
        .where('seller_id', isEqualTo: widget.sellerId)
        .where('status', isEqualTo: 'success')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map((doc) {
            var data = doc.data();
            return {
              ...data,
              'id': doc.id,
              'trans_type': 'withdraw',
              'display_date': data['approved_at'] ?? data['date'],
            };
          }).toList(),
        );

    return Rx.combineLatest2<
      List<Map<String, dynamic>>,
      List<Map<String, dynamic>>,
      List<Map<String, dynamic>>
    >(incomeStream, withdrawStream, (incomes, withdraws) {
      var all = [...incomes, ...withdraws];
      // តម្រៀបតាមថ្ងៃខែ ថ្មីបំផុតនៅខាងលើ
      all.sort((a, b) {
        Timestamp tA = a['display_date'] ?? Timestamp.now();
        Timestamp tB = b['display_date'] ?? Timestamp.now();
        return tB.compareTo(tA);
      });
      return all;
    });
  }

  // 🎯 Stream សម្រាប់ទាញទិន្នន័យកាបូបលុយផ្ទាល់ (ចំណូលថ្ងៃនេះ, លុយអាចដកបាន)
  Stream<DocumentSnapshot> _getWalletStream() {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(widget.sellerId)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FA),
      appBar: AppBar(
        elevation: 0,
        title: const Text(
          "មជ្ឈមណ្ឌលហិរញ្ញវត្ថុ",
          style: TextStyle(
            fontFamily: 'KHMEROS',
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        foregroundColor: Colors.white,
        backgroundColor: const Color(0xFF1A237E),
        centerTitle: true,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        // ១. Stream ថ្មីសម្រាប់ទាញ Key: today_income, available_balance
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(widget.sellerId)
            .snapshots(),
        builder: (context, walletSnapshot) {
          if (walletSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          var walletData = walletSnapshot.data?.data() as Map<String, dynamic>?;

          // ១. ចាប់យកសមតុល្យដែលមានស្រាប់ ២៧ លាន
          double totalBalance = (walletData?['balance'] ?? 0).toDouble();

          // ២. ចាប់យកចំណូលថ្ងៃនេះ (ដែល Cloud បូកបញ្ចូលឱ្យ)
          double todayEarnings = (walletData?['today_income'] ?? 0).toDouble();

          // ៣. ចាប់យកលុយដែលបានដកសរុប (កែឈ្មោះ Key ឱ្យត្រូវតាម Database មេ)
          double totalWithdraw = (walletData?['total_withdraw'] ?? 0)
              .toDouble();
          return StreamBuilder<List<Map<String, dynamic>>>(
            // ២. Stream ដើមសម្រាប់បង្ហាញ List ប្រតិបត្តិការខាងក្រោម
            stream: _getCombinedTransactions(),
            builder: (context, snapshot) {
              var transactions = snapshot.data ?? [];

              return Column(
                children: [
                  // បង្ហាញលេខដែលទាញបានពី Key ផ្ទាល់
                  _buildBankStyleHeader(
                    totalBalance,
                    todayEarnings,
                    totalWithdraw,
                  ),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(30),
                          topRight: Radius.circular(30),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.fromLTRB(25, 25, 25, 10),
                            child: Text(
                              "ប្រតិបត្តិការថ្មីៗ",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A237E),
                              ),
                            ),
                          ),
                          Expanded(
                            child: transactions.isEmpty
                                ? _buildEmptyState()
                                : ListView.builder(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 15,
                                    ),
                                    itemCount: transactions.length,
                                    itemBuilder: (context, index) =>
                                        _buildTransactionItem(
                                          transactions[index],
                                        ),
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
          const Text(
            "សមតុល្យសរុប",
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 10),
          Text(
            "${currencyFormat.format(total)} ៛",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 35,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 30),
          Row(
            children: [
              _buildFlowCard(
                "ចំណូលថ្ងៃនេះ",
                today,
                Icons.arrow_downward,
                Colors.greenAccent,
              ),
              const SizedBox(width: 15),
              _buildFlowCard(
                "ដកប្រាក់សរុប",
                withdraw,
                Icons.arrow_upward,
                Colors.orangeAccent,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFlowCard(
    String label,
    double amount,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 16),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              "${currencyFormat.format(amount)} ៛",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionItem(Map<String, dynamic> data) {
    // ១. កំណត់ប្រភេទប្រតិបត្តិការ
    bool isWithdraw = data['trans_type'] == 'withdraw';
    double amount = (data['seller_earnings'] ?? data['amount'] ?? 0).toDouble();
    Timestamp? ts = data['display_date'];

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        // ២. Logic ពេលចុច៖ បែងចែកផ្លូវទៅតាមប្រភេទប្រតិបត្តិការ
        onTap: () {
          if (isWithdraw) {
            // បើដកលុយ ទៅផ្ទាំង SellerWithdrawalDetail
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SellerWithdrawalDetail(data: data),
              ),
            );
          } else {
            // បើចំណូលលក់ ទៅផ្ទាំង OrderDetailScreen
            // យើងប្រើ ID របស់ Document ដើម្បីឱ្យវាទៅទាញបុងមកបង្ហាញ
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => OrderDetailScreen(
                  orderId: data['order_id'] ?? data['id'] ?? "",
                ),
              ),
            );
          }
        },
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // ៣. Icon តំណាង (Modern Design)
              Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  color: isWithdraw
                      ? Colors.red.withOpacity(0.1)
                      : Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isWithdraw ? Icons.upload_rounded : Icons.download_rounded,
                  color: isWithdraw ? Colors.redAccent : Colors.green,
                  size: 20,
                ),
              ),
              const SizedBox(width: 15),

              // ៤. ព័ត៌មានប្រតិបត្តិការ (ឈ្មោះ និង ថ្ងៃខែ)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isWithdraw ? "ដកប្រាក់ចេញ" : "ចំណូលបានពីការលក់",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Color(0xFF1A237E), // ពណ៌ទឹកប៊ិចចាស់ដែលមេចូលចិត្ត
                        fontFamily: 'KHMEROS',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      ts != null
                          ? DateFormat('dd/MM/yyyy • HH:mm').format(ts.toDate())
                          : "មិនទាន់មានកាលបរិច្ឆេទ",
                      style: TextStyle(color: Colors.grey[500], fontSize: 11),
                    ),
                  ],
                ),
              ),

              // ៥. ចំនួនទឹកប្រាក់ និង ព្រួញបង្ហាញថាអាចចុចចូលបាន
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "${isWithdraw ? '-' : '+'} ${currencyFormat.format(amount)} ៛",
                    style: TextStyle(
                      color: isWithdraw ? Colors.redAccent : Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 12,
                    color: Colors.grey[300],
                  ),
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
          const Text(
            "មិនទាន់មានប្រតិបត្តិការនៅឡើយ",
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
