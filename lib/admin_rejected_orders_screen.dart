import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AdminRejectedOrdersScreen extends StatefulWidget {
  const AdminRejectedOrdersScreen({super.key});

  @override
  State<AdminRejectedOrdersScreen> createState() => _AdminRejectedOrdersScreenState();
}

class _AdminRejectedOrdersScreenState extends State<AdminRejectedOrdersScreen> {
  final currencyFormat = NumberFormat('#,###');
  final Map<String, String> _sesanIdCache = {};

  Future<String> _getSesanId(String customerId) async {
    if (customerId.isEmpty) return '';
    if (_sesanIdCache.containsKey(customerId)) {
      return _sesanIdCache[customerId]!;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(customerId)
          .get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final sesanId = (data['sesan_id'] ?? '').toString();
        _sesanIdCache[customerId] = sesanId;
        return sesanId;
      }
    } catch (e) {
      debugPrint("Error fetching sesan_id: $e");
    }
    _sesanIdCache[customerId] = '';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text(
            'ការកម្ម៉ង់ដែលបានបដិសេធ',
            style: TextStyle(fontFamily: 'Siemreap', fontSize: 16),
          ),
          backgroundColor: Colors.red[700],
          foregroundColor: Colors.white,
          centerTitle: true,
        ),
        body: StreamBuilder<QuerySnapshot>(
          // ✅ លុប orderBy ចេញ ដើម្បីកុំឲ្យវាត្រងឯកសារដែលគ្មាន Field rejected_at
          stream: FirebaseFirestore.instance
              .collection('orders')
              .where('status', isEqualTo: 'rejected')
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.cancel_outlined, size: 80, color: Colors.grey[300]),
                    const SizedBox(height: 16),
                    Text(
                      'មិនមានការកម្ម៉ង់ដែលត្រូវបានបដិសេធ',
                      style: TextStyle(color: Colors.grey[500], fontSize: 16, fontFamily: 'Siemreap'),
                    ),
                  ],
                ),
              );
            }

            // ✅ តម្រៀបនៅក្នុង Flutter វិញ
            final orders = snapshot.data!.docs.toList()
              ..sort((a, b) {
                final aData = a.data() as Map<String, dynamic>;
                final bData = b.data() as Map<String, dynamic>;
                final aTime = aData['rejected_at'] ?? aData['created_at'] ?? Timestamp.now();
                final bTime = bData['rejected_at'] ?? bData['created_at'] ?? Timestamp.now();
                return (bTime as Timestamp).compareTo(aTime as Timestamp);
              });

              final docs = snapshot.data!.docs;

              return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: docs.length,
                itemBuilder: (context, index) {
                  final orderData = orders[index].data() as Map<String, dynamic>;
                  final String orderId = orders[index].id;
                  final String customerName = orderData['customer_name'] ?? 'មិនស្គាល់ឈ្មោះ';
                  final String phone = orderData['phone_number'] ?? 'គ្មានលេខ';
                  final String address = orderData['shipping_address'] ?? 'គ្មានអាសយដ្ឋាន';
                  final double totalAmount = (orderData['total_amount'] ?? 0).toDouble();
                  final List items = orderData['items'] as List? ?? [];
                  final String customerId = orderData['customer_id']?.toString() ?? '';

                  // ✅ កាលបរិច្ឆេទកម្ម៉ង់
                  final Timestamp? createdAt = orderData['created_at'];
                  String orderDateStr = 'មិនមានកាលបរិច្ឆេទ';
                  if (createdAt != null) {
                    orderDateStr = DateFormat('dd/MM/yyyy HH:mm').format(createdAt.toDate());
                  }

                  // ✅ កាលបរិច្ឆេទបដិសេធ
                  final Timestamp? rejectedAt = orderData['rejected_at'];
                  String rejectedDateStr = 'មិនមានកាលបរិច្ឆេទ';
                  if (rejectedAt != null) {
                    rejectedDateStr = DateFormat('dd/MM/yyyy HH:mm').format(rejectedAt.toDate());
                  }

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ExpansionTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.red[100],
                          child: Text(
                            customerName.isNotEmpty ? customerName[0].toUpperCase() : '?',
                            style: TextStyle(color: Colors.red[700], fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(
                          customerName,
                          style: const TextStyle(fontFamily: 'Siemreap', fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'កម្ម៉ង់នៅ: $orderDateStr',
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                            Text(
                              'បដិសេធនៅ: $rejectedDateStr',
                              style: const TextStyle(fontSize: 11, color: Colors.red),
                            ),
                            Text(
                              'ទូរស័ព្ទ: $phone',
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
                        children: [
                    Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                    // Address
                    Row(
                    children: [
                    const Icon(Icons.location_on, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(child: Text(address, style: const TextStyle(fontSize: 13))),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Sesan ID
                  if (customerId.isNotEmpty)
                  _buildSesanIdRow(customerId),

                  const SizedBox(height: 12),
                  // Items
                  if (items.isNotEmpty) ...[
                  const Text('បញ្ជីទំនិញ:', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Siemreap')),
                  const SizedBox(height: 8),
                  ...items.map((item) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: item['image_url'] != null && item['image_url'].toString().isNotEmpty
                  ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(item['image_url'], width: 40, height: 40, fit: BoxFit.cover),
                  )
                      : null,
                  title: Text(item['product_name'] ?? 'ទំនិញ', style: const TextStyle(fontSize: 13)),
                  subtitle: Text(
                  '${item['quantity'] ?? 1} x ${currencyFormat.format(double.tryParse(item['price']?.toString() ?? '0') ?? 0)} ៛',
                    style: TextStyle(color: Colors.red[700], fontSize: 12),
                  ),
                  )),
                  ],
                          const Divider(),
                          // Total
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('សរុប', style: TextStyle(fontWeight: FontWeight.bold)),
                              Text(
                                '${currencyFormat.format(totalAmount)} ៛',
                                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ],
                          ),
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
  Widget _buildSesanIdRow(String customerId) {
    return FutureBuilder<String>(
      future: _getSesanId(customerId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(height: 6);
        }
        final sesanId = snapshot.data ?? '';
        if (sesanId.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Icon(Icons.tag, size: 16, color: Colors.blue[700]),
              const SizedBox(width: 8),
              const Text('Sesan ID: ', style: TextStyle(fontSize: 13, fontFamily: 'Siemreap')),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Text(
                  sesanId,
                  style: TextStyle(fontSize: 12, color: Colors.blue[700], fontWeight: FontWeight.w500, fontFamily: 'Siemreap'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}