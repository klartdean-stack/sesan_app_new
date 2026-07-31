import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';


class AdminShopUpgradeConfirmScreen extends StatelessWidget {
  const AdminShopUpgradeConfirmScreen({super.key});


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('បញ្ជាក់ដំឡើងហាង'),
        backgroundColor: Colors.amber[700],
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('shop_upgrade_requests')
            .where('status', isEqualTo: 'pending')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('មិនមានសំណើដំឡើងហាងទេ'));
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
                      // ឈ្មោះ និងកាលបរិច្ឆេទ
                      Row(
                        children: [
                          const Icon(Icons.store, color: Colors.amber),
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
                      // ព័ត៌មានទំនាក់ទំនង
                      Text('📞 ${data['phone'] ?? 'គ្មានលេខ'}'),
                      if (data['sesan_id'] != null &&
                          data['sesan_id'].toString().isNotEmpty)
                        Text('🆔 Sesan ID: ${data['sesan_id']}'),
                      const SizedBox(height: 4),
                      // កញ្ចប់ និងតម្លៃ
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color:
                          (data['tier'] == 'premium'
                              ? Colors.amber
                              : Colors.blue)
                              .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${data['tier'] == 'premium' ? 'Premium' : 'Basic'} Shop · ${NumberFormat('#,###').format(data['price'] ?? 0)} ៛',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: data['tier'] == 'premium'
                                ? Colors.amber[800]
                                : Colors.blue[800],
                          ),
                        ),
                      ),
                      // ឈ្មោះហាងសម្រាប់ Premium
                      if (data['shop_name'] != null &&
                          data['shop_name'].toString().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '🏪 ឈ្មោះហាង៖ ${data['shop_name']}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      const SizedBox(height: 10),
                      // រូបភាពវិក្កយបត្រ
                      if (data['receipt_url'] != null)
                        GestureDetector(
                          onTap: () {
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
    final tier = data['tier'] ?? 'basic';
    final shopName = data['shop_name'];


    if (userId == null) return;


    try {
      final batch = FirebaseFirestore.instance.batch();


      // 1. ធ្វើបច្ចុប្បន្នភាពសំណើ
      batch.update(
        FirebaseFirestore.instance
            .collection('shop_upgrade_requests')
            .doc(docId),
        {'status': 'approved'},
      );


      // 2. ធ្វើបច្ចុប្បន្នភាពអ្នកប្រើ
      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId);
      batch.update(userRef, {
        'shop_tier': tier,
        'shop_upgrade_date': FieldValue.serverTimestamp(),
      });


      // 3. បើជា Premium ត្រូវចាក់សោឈ្មោះហាង
      if (tier == 'premium' && shopName != null && shopName.isNotEmpty) {
        final shopNameRef = FirebaseFirestore.instance
            .collection('shop_names')
            .doc(shopName);
        batch.set(shopNameRef, {
          'owner_id': userId,
          'created_at': FieldValue.serverTimestamp(),
        });
      }


      await batch.commit();
    } catch (e) {
      debugPrint('Error approving shop upgrade: $e');
    }
  }


  Future<void> _rejectRequest(String docId) async {
    try {
      await FirebaseFirestore.instance
          .collection('shop_upgrade_requests')
          .doc(docId)
          .update({'status': 'rejected'});
    } catch (e) {
      debugPrint('Error rejecting shop upgrade: $e');
    }
  }
}



