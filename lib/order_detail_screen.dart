import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class OrderDetailScreen extends StatelessWidget {
  final String orderId;
  const OrderDetailScreen({super.key, required this.orderId});

  String _t(BuildContext context, String km, String en) =>
      Localizations.localeOf(context).languageCode == 'en' ? en : km;

  (String, Color) _statusInfo(BuildContext context, String status) {
    switch (status) {
      case 'pending':
        return (_t(context, 'រង់ចាំ', 'Pending'), Colors.orange);
      case 'confirmed':
        return (_t(context, 'បានបញ្ជាក់', 'Confirmed'), Colors.blue);
      case 'packing':
        return (_t(context, 'កំពុងរៀបចំ', 'Packing'), Colors.blueGrey);
      case 'on_delivery':
        return (_t(context, 'កំពុងដឹក', 'On delivery'), Colors.purple);
      case 'delivered':
        return (_t(context, 'ដឹកដល់ហើយ', 'Delivered'), Colors.green);
      case 'payout_completed':
        return (_t(context, 'បានទូទាត់ជូនអ្នកលក់', 'Payout completed'), Colors.green);
      case 'cancelled':
        return (_t(context, 'បានបោះបង់', 'Cancelled'), Colors.red);
      default:
        return (_t(context, 'មិនស្គាល់', 'Unknown'), Colors.grey);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###');

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: Text(
          _t(context, 'លម្អិតការលក់', 'Sales Details'),
          style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Siemreap'),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('orders').doc(orderId).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(
              child: Text(
                _t(context, 'រកមិនឃើញទិន្នន័យបុងនេះទេ', 'Sales record not found'),
                style: const TextStyle(fontFamily: 'Siemreap'),
              ),
            );
          }

          final order = snapshot.data!.data() as Map<String, dynamic>;
          final items = (order['items'] as List<dynamic>?) ?? [];
          final earnings = (order['seller_earnings'] ?? 0).toDouble();
          final total = (order['total_amount'] ?? 0).toDouble();
          final createdAt = order['created_at'];
          final date = createdAt is Timestamp ? createdAt.toDate() : DateTime.now();
          final status = order['status']?.toString() ?? 'pending';
          final statusInfo = _statusInfo(context, status);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
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
                      Text(
                        _t(context, 'ចំណូលសុទ្ធទទួលបាន', 'Net earnings received'),
                        style: const TextStyle(color: Colors.white70, fontSize: 13, fontFamily: 'Siemreap'),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${fmt.format(earnings)} ៛',
                        style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          statusInfo.$1,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontFamily: 'Siemreap'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _buildSection(_t(context, '📋 ព័ត៌មានការលក់', '📋 Sales information'), [
                  _buildRow(_t(context, 'លេខបុង', 'Receipt number'), '#${orderId.substring(0, orderId.length < 8 ? orderId.length : 8).toUpperCase()}'),
                  _buildRow(_t(context, 'កាលបរិច្ឆេទ', 'Date'), DateFormat('dd/MM/yyyy • HH:mm').format(date)),
                  _buildRow(_t(context, 'ស្ថានភាព', 'Status'), statusInfo.$1, valueColor: statusInfo.$2),
                  _buildRow(
                    _t(context, 'ការទូទាត់', 'Payment'),
                    order['payment_status'] == 'paid'
                        ? _t(context, '✅ បានទូទាត់', '✅ Paid')
                        : _t(context, '⏳ រង់ចាំ', '⏳ Pending'),
                  ),
                ]),
                const SizedBox(height: 12),
                _buildSection(
                  _t(context, '🛍 ទំនិញដែលបានលក់', '🛍 Sold items'),
                  items.isEmpty
                      ? [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              _t(context, 'គ្មានទំនិញ', 'No items'),
                              style: const TextStyle(color: Colors.grey, fontFamily: 'Siemreap'),
                            ),
                          ),
                        ]
                      : items.map((item) {
                          final i = item as Map<String, dynamic>;
                          final name = i['product_name'] ?? _t(context, 'ទំនិញ', 'Product');
                          final qty = i['quantity'] ?? 1;
                          final price = (i['price'] ?? 0).toDouble();
                          final imgUrl = i['image_url'] ?? '';
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: imgUrl.isNotEmpty
                                      ? CachedNetworkImage(
                                          imageUrl: imgUrl,
                                          width: 56,
                                          height: 56,
                                          fit: BoxFit.cover,
                                          placeholder: (_, __) => Container(width: 56, height: 56, color: Colors.grey[200]),
                                          errorWidget: (_, __, ___) => Container(
                                            width: 56,
                                            height: 56,
                                            color: Colors.grey[100],
                                            child: const Icon(Icons.shopping_bag_outlined, color: Colors.green),
                                          ),
                                        )
                                      : Container(
                                          width: 56,
                                          height: 56,
                                          decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(10)),
                                          child: const Icon(Icons.shopping_bag_outlined, color: Colors.green),
                                        ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(name.toString(), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${_t(context, 'ចំនួន', 'Qty')}: $qty × ${fmt.format(price)} ៛',
                                        style: TextStyle(color: Colors.grey[600], fontSize: 12, fontFamily: 'Siemreap'),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '${fmt.format(price * (qty is num ? qty : 1))} ៛',
                                  style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.green, fontSize: 14),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                ),
                const SizedBox(height: 12),
                _buildSection(_t(context, '💰 សង្ខេបហិរញ្ញវត្ថុ', '💰 Financial summary'), [
                  _buildRow(_t(context, 'តម្លៃសរុប', 'Total'), '${fmt.format(total)} ៛'),
                  _buildRow(_t(context, 'កម្រៃគ្រប់គ្រង (7%)', 'Service fee (7%)'), '- ${fmt.format(total * 0.07)} ៛', valueColor: Colors.red),
                  const Divider(height: 20),
                  _buildRow(_t(context, 'ចំណូលសុទ្ធ', 'Net earnings'), '${fmt.format(earnings)} ៛', valueColor: Colors.green, isBold: true),
                ]),
                const SizedBox(height: 12),
                _buildSection(_t(context, '👤 ផ្ញើទៅកាន់', '👤 Ship to'), [
                  _buildRow(_t(context, 'អតិថិជន', 'Customer'), order['customer_name'] ?? _t(context, 'ភ្ញៀវទូទៅ', 'Guest')),
                  _buildRow(_t(context, 'លេខទូរស័ព្ទ', 'Phone number'), order['phone_number'] ?? 'N/A'),
                  _buildRow(_t(context, 'ទីតាំង', 'Location'), order['shipping_address'] ?? _t(context, 'មិនមានទីតាំង', 'No location'), isLongText: true),
                ]),
                const SizedBox(height: 30),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1A237E), fontFamily: 'Siemreap')),
          const Divider(height: 24),
          ...children,
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value, {Color? valueColor, bool isLongText = false, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: isLongText ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13, fontFamily: 'Siemreap')),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(fontWeight: isBold ? FontWeight.w800 : FontWeight.w600, fontSize: isBold ? 16 : 13, color: valueColor ?? Colors.black87, fontFamily: 'Siemreap'),
            ),
          ),
        ],
      ),
    );
  }
}
