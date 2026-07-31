import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class TransactionHistoryPage extends StatelessWidget {
  const TransactionHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? "";
    final f = NumberFormat('#,###');

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "ប្រវត្តិចំណូល",
          style: TextStyle(fontFamily: 'KHMEROS', fontSize: 18),
        ),
        backgroundColor: Colors.purple[700],
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // ទាញយកតែ Transaction ណាដែលជារបស់អ្នកលក់ម្នាក់ហ្នឹង
        stream: FirebaseFirestore.instance
            .collection('transactions')
            .where('sellerId', isEqualTo: currentUserId)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long, size: 80, color: Colors.grey),
                  Text("មិនទាន់មានប្រវត្តិលុយចូលនៅឡើយទេ"),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var trans = snapshot.data!.docs[index];
              var data = trans.data() as Map<String, dynamic>;

              // កំណត់កាលបរិច្ឆេទ
              DateTime date = (data['timestamp'] as Timestamp).toDate();
              String formattedDate = DateFormat(
                'dd-MM-yyyy HH:mm',
              ).format(date);

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.green,
                    child: Icon(Icons.add, color: Colors.white),
                  ),
                  title: Text(
                    "+ ${f.format(data['amount'])} ៛",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                      fontSize: 18,
                    ),
                  ),
                  subtitle: Text(
                    "ID Order: ${data['orderId'].toString().substring(0, 8)}...",
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        "ជោគជ័យ",
                        style: TextStyle(color: Colors.blue, fontSize: 12),
                      ),
                      Text(
                        formattedDate,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 10,
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
