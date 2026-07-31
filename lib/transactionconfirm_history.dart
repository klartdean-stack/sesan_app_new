import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
class TransactionConfirmHistory extends StatelessWidget {
  const TransactionConfirmHistory({super.key});

  @override
  Widget build(BuildContext context) {
    // 🎯 សម្រាប់អេក្រង់ Admin បងមិនបាច់ឆែក isAdmin ច្រើននាំតែញ៉ាំញ៉ៃទេ
    // គឺយើងទាញយកទិន្នន័យដែលបាញ់លុយជោគជ័យទាំងអស់មកបង្ហាញតែម្តង

    return Scaffold(
        appBar: AppBar(
          title: const Text(
            "ប្រវត្តិបាញ់លុយទៅអ្នកលក់", // ដាក់ឈ្មោះឱ្យដូចក្នុងរូបបង
            style: TextStyle(fontFamily: 'KHMEROS', fontSize: 18),
          ),
          backgroundColor: const Color(0xFF003F63), // ពណ៌ទឹកប៊ិច ABA
          centerTitle: true,
        ),
        body: StreamBuilder<QuerySnapshot>(
          // ទាញយកតែ Status: success និងតម្រៀបតាមម៉ោងដែល Admin ចុចយល់ព្រម
            stream: FirebaseFirestore.instance
                .collection('withdraw_requests')
                .where('status', isEqualTo: 'success')
                .orderBy('approved_at', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text("មិនទាន់មានប្រវត្តិបាញ់លុយទេ"));
              }

              return ListView.builder(
                  padding: const EdgeInsets.all(10),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var data = snapshot.data!.docs[index].data() as Map<String, dynamic>;

                    // កំណត់ទម្រង់ថ្ងៃខែឱ្យដូចក្នុងរូប (ថ្ងៃ/ខែ/ឆ្នាំ ម៉ោង:នាទី)
                    String dateStr = data['approved_at'] != null
                        ? DateFormat('dd/MM/yyyy HH:mm').format((data['approved_at'] as Timestamp).toDate())
                        : "N/A";

                    return Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ExpansionTile(
                            leading: const CircleAvatar(
                              backgroundColor: Color(0xFFE8F5E9),
                              child: Icon(Icons.check_circle, color: Colors.green),
                            ),
                            title: Row(
                              children: [
                                Text(
                                  "${data['amount']} ៛",
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green),
                                ),
                              ],
                            ),
                            subtitle: Text("ID: ${data['seller_id']?.toString().substring(0,6)} • $dateStr"),
                            children: [
                        Padding(
                        padding: const EdgeInsets.all(15),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                            const Divider(),
                        _buildRow("ឈ្មោះអ្នកលក់:", "${data['account_name'] ?? 'N/A'}"),
                        _buildRow("ធនាគារ:", "${data['bank_name'] ?? 'N/A'}"),
                        _buildRow("ឈ្មោះគណនី:", "${data['account_name'] ?? 'N/A'}"),
                        _buildRow("លេខគណនី:", "${data['account_number'] ?? 'N/A'}"),

                        const SizedBox(height: 15),
                        const Text("ភស្តុតាងពី Admin៖", style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),

                        // បង្ហាញរូបភាពបង្កាន់ដៃបាញ់លុយ
                        if (data['admin_receipt'] != null)
                    ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        data['admin_receipt'],
                        width: double.infinity,
                        height: 250,
                        fit: BoxFit.contain,
                      ),
                    )
                        else
                          const Text("មិនមានរូបភាពភស្តុតាង", style: TextStyle(color: Colors.red)),
                            ],
                        ),
                        ),
                            ],
                        ),
                    );
                  },
              );
            },
        ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
  void _viewImage(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)),
            ),
            InteractiveViewer(child: Image.network(url)),
          ],
        ),
      ),
    );
  }