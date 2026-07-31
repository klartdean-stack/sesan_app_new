import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // សម្រាប់ format ថ្ងៃខែ និងលេខ

class ShareholderDividendHistory extends StatelessWidget {
  final int userShares; // ទទួលចំនួនហ៊ុនរបស់ User ពី Screen Dashboard

  const ShareholderDividendHistory({super.key, required this.userShares});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A), // ពណ៌ងងឹតតាម Style App
      appBar: AppBar(
        title: const Text("ប្រវត្តិទទួលបានប្រាក់ចំណេញ"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // 🎯 ទាញទិន្នន័យពី Collection របស់ Admin
        stream: FirebaseFirestore.instance
            .collection('dividend_history')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                "មិនទាន់មានប្រវត្តិចែកប្រាក់ចំណេញនៅឡើយទេ",
                style: TextStyle(color: Colors.white54),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 10),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var data =
                  snapshot.data!.docs[index].data() as Map<String, dynamic>;

              // 🧮 គណនាលុយដែល User ទទួលបាន (តម្លៃក្នុង ១ ហ៊ុន x ចំនួនហ៊ុនគាត់មាន)
              double amountPerShare = (data['amount_per_share'] ?? 0)
                  .toDouble();
              double myTotalEarning = amountPerShare * userShares;

              // 📅 បំប្លែងថ្ងៃខែ
              DateTime date = (data['timestamp'] as Timestamp).toDate();
              String formattedDate = DateFormat(
                'dd MMM yyyy, hh:mm a',
              ).format(date);

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.white10),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(15),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_rounded,
                      color: Colors.greenAccent,
                    ),
                  ),
                  title: Text(
                    "+ ${NumberFormat("#,###").format(myTotalEarning)} ៛",
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Text(
                      "កាលបរិច្ឆេទ៖ $formattedDate\n${data['note'] ?? 'ចែកប្រាក់ចំណេញ'}",
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        "${amountPerShare.toInt()} ៛/ហ៊ុន",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        "ជោគជ័យ",
                        style: TextStyle(
                          color: Colors.blueAccent,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
