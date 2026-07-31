import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class OrderDetailScreen extends StatelessWidget {
  final String orderId;
  const OrderDetailScreen({super.key, required this.orderId});

  static const _statusMap = {
    'pending': ('រង់ចាំ', Colors.orange),
    'confirmed': ('បានបញ្ជាក់', Colors.blue),
    'on_delivery': ('កំពុងដឹក', Colors.purple),
    'delivered': ('ដឹកដល់ហើយ', Colors.green),
    'cancelled': ('បានបោះបង់', Colors.red),
  };

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###');

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: const Text(
          'លម្អិតការលក់',
          style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Siemreap'),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('orders')
            .doc(orderId)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || !snapshot.data!.exists)
            return const Center(
              child: Text(
                'រកមិនឃើញទិន្នន័យបុងនេះទេ',
                style: TextStyle(fontFamily: 'Siemreap'),
              ),
            );

          final order = snapshot.data!.data() as Map<String, dynamic>;

          // ✅ ទាញ items array ពិតប្រាកដ
          final items = (order['items'] as List<dynamic>?) ?? [];
          final earnings = (order['seller_earnings'] ?? 0).toDouble();
          final total = (order['total_amount'] ?? 0).toDouble();
          final date = (order['created_at'] as Timestamp).toDate();
          final status = order['status'] ?? 'pending';
          final statusInfo = _statusMap[status] ?? ('មិនស្គាល់', Colors.grey);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // ── ១. Card ចំណូលសុទ្ធ ──────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.green.shade700, Colors.green.shade500],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'ចំណូលសុទ្ធទទួលបាន',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontFamily: 'Siemreap',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${fmt.format(earnings)} ៛',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Status badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          statusInfo.$1,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Siemreap',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── ២. ព័ត៌មានបុង ────────────────────────────
                _buildSection('📋 ព័ត៌មានការលក់', [
                  _buildRow(
                    'លេខបុង',
                    '#${orderId.substring(0, 8).toUpperCase()}',
                  ),
                  _buildRow(
                    'កាលបរិច្ឆេទ',
                    DateFormat('dd/MM/yyyy • HH:mm').format(date),
                  ),
                  _buildRow(
                    'ស្ថានភាព',
                    statusInfo.$1,
                    valueColor: statusInfo.$2,
                  ),
                  _buildRow(
                    'ការទូទាត់',
                    order['payment_status'] == 'paid'
                        ? '✅ បានទូទាត់'
                        : '⏳ រង់ចាំ',
                  ),
                ]),
                const SizedBox(height: 12),

                // ── ៣. បញ្ជីទំនិញ ✅ ទាញពី items array ──────
                _buildSection(
                  '🛍 ទំនិញដែលបានលក់',
                  items.isEmpty
                      ? [
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'គ្មានទំនិញ',
                        style: TextStyle(
                          color: Colors.grey,
                          fontFamily: 'Siemreap',
                        ),
                      ),
                    ),
                  ]
                      : items.map((item) {
                    final i = item as Map<String, dynamic>;
                    final name = i['product_name'] ?? 'ទំនិញ';
                    final qty = i['quantity'] ?? 1;
                    final price = (i['price'] ?? 0).toDouble();
                    final imgUrl = i['image_url'] ?? '';

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          // រូបភាពទំនិញ
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: imgUrl.isNotEmpty
                                ? CachedNetworkImage(
                              imageUrl: imgUrl,
                              width: 56,
                              height: 56,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(
                                width: 56,
                                height: 56,
                                color: Colors.grey[200],
                              ),
                              errorWidget: (_, __, ___) => Container(
                                width: 56,
                                height: 56,
                                color: Colors.grey[100],
                                child: const Icon(
                                  Icons.shopping_bag_outlined,
                                  color: Colors.green,
                                ),
                              ),
                            )
                                : Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(
                                  10,
                                ),
                              ),
                              child: const Icon(
                                Icons.shopping_bag_outlined,
                                color: Colors.green,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'ចំនួន: $qty × '
                                      '${fmt.format(price)} ៛',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                    fontFamily: 'Siemreap',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${fmt.format(price * qty)} ៛',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: Colors.green,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),

                // ── ៤. សង្ខេបតម្លៃ ───────────────────────────
                _buildSection('💰 សង្ខេបហិរញ្ញវត្ថុ', [
                  _buildRow('តម្លៃសរុប', '${fmt.format(total)} ៛'),
                  _buildRow(
                    'កម្រៃគ្រប់គ្រង (7%)',
                    '- ${fmt.format(total * 0.07)} ៛',
                    valueColor: Colors.red,
                  ),
                  const Divider(height: 20),
                  _buildRow(
                    'ចំណូលសុទ្ធ',
                    '${fmt.format(earnings)} ៛',
                    valueColor: Colors.green,
                    isBold: true,
                  ),
                ]),
                const SizedBox(height: 12),

                // ── ៥. ព័ត៌មានអតិថិជន ────────────────────────
                _buildSection('👤 ផ្ញើទៅកាន់', [
                  _buildRow('អតិថិជន', order['customer_name'] ?? 'ភ្ញៀវទូទៅ'),
                  _buildRow('លេខទូរស័ព្ទ', order['phone_number'] ?? 'N/A'),
                  _buildRow(
                    'ទីតាំង',
                    order['shipping_address'] ?? 'ភ្នំពេញ',
                    isLongText: true,
                  ),
                ]),

                const SizedBox(height: 30),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Section Container ──────────────────────────────────────
  Widget _buildSection(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: Color(0xFF1A237E),
              fontFamily: 'Siemreap',
            ),
          ),
          const Divider(height: 24),
          ...children,
        ],
      ),
    );
  }

  // ── Row Helper ─────────────────────────────────────────────
  Widget _buildRow(
      String label,
      String value, {
        Color? valueColor,
        bool isLongText = false,
        bool isBold = false,
      }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: isLongText
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 13,
              fontFamily: 'Siemreap',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
                fontSize: isBold ? 16 : 13,
                color: valueColor ?? Colors.black87,
                fontFamily: 'Siemreap',
              ),
            ),
          ),
        ],
      ),
    );
  }
}