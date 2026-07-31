import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';


class AdminVipConfirmScreen extends StatelessWidget {
  const AdminVipConfirmScreen({super.key});


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('បញ្ជាក់សំណើ VIP'),
        backgroundColor: Colors.amber[700],
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('vip_requests')
            .where('status', isEqualTo: 'pending')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('មិនមានសំណើ VIP ដែលកំពុងរង់ចាំ'));
          }
          final docs = snapshot.data!.docs;
          return ListView.builder(
            itemCount: docs.length,
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final docId = docs[index].id;
              final timestamp = data['timestamp'] as Timestamp?;
              final date = timestamp != null
                  ? DateFormat('dd/MM/yyyy HH:mm').format(timestamp.toDate())
                  : '';


              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.person, color: Colors.amber),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              data['name'] ?? 'គ្មានឈ្មោះ',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          Text(
                            date,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('📞 ${data['phone'] ?? 'គ្មានលេខ'}'),
                      Text('🆔 Sesan ID: ${data['sesan_id'] ?? 'មិនមាន'}'),
                      Text(
                        '💰 ${NumberFormat('#,###').format(data['amount'] ?? 15000)} ៛',
                      ),
                      const SizedBox(height: 10),
                      if (data['receipt_url'] != null)
                        GestureDetector(
                          onTap: () {
                            // បង្ហាញរូបវិក្កយបត្រពេញអេក្រង់
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => Scaffold(
                                  appBar: AppBar(
                                    title: const Text('វិក្កយបត្រ'),
                                  ),
                                  body: Center(
                                    child: InteractiveViewer(
                                      child: Image.network(data['receipt_url']),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                          child: Container(
                            height: 120,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                data['receipt_url'],
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                const Icon(Icons.broken_image, size: 40),
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            onPressed: () => _rejectRequest(docId),
                            icon: const Icon(Icons.cancel, color: Colors.red),
                            label: const Text('បដិសេធ'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton.icon(
                            onPressed: () => _approveRequest(docId, data),
                            icon: const Icon(
                              Icons.check_circle,
                              color: Colors.white,
                            ),
                            label: const Text('អនុម័ត'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
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


  Future<void> _approveRequest(String docId, Map<String, dynamic> data) async {
    final userId = data['user_id'];
    if (userId == null) return;


    try {
      await FirebaseFirestore.instance
          .collection('vip_requests')
          .doc(docId)
          .update({'status': 'approved'});
      // ធ្វើបច្ចុប្បន្នភាព user ទៅជា VIP
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'isVip': true,
      });
    } catch (e) {
      debugPrint('Error approving VIP: $e');
    }
  }


  Future<void> _rejectRequest(String docId) async {
    try {
      await FirebaseFirestore.instance
          .collection('vip_requests')
          .doc(docId)
          .update({'status': 'rejected'});
    } catch (e) {
      debugPrint('Error rejecting VIP: $e');
    }
  }
}



