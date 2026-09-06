import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminMarketplaceAnalyticsScreen extends StatefulWidget {
  const AdminMarketplaceAnalyticsScreen({super.key});

  @override
  State<AdminMarketplaceAnalyticsScreen> createState() =>
      _AdminMarketplaceAnalyticsScreenState();
}

class _AdminMarketplaceAnalyticsScreenState
    extends State<AdminMarketplaceAnalyticsScreen> {
  String _range = '7d';

  DateTime? get _start {
    final now = DateTime.now();
    switch (_range) {
      case 'today':
        return DateTime(now.year, now.month, now.day);
      case '7d':
        return now.subtract(const Duration(days: 7));
      case '30d':
        return now.subtract(const Duration(days: 30));
      default:
        return null;
    }
  }

  Query<Map<String, dynamic>> get _query {
    Query<Map<String, dynamic>> q = FirebaseFirestore.instance
        .collection('marketplace_events')
        .orderBy('createdAt', descending: true);
    final start = _start;
    if (start != null) {
      q = q.where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start));
    }
    return q;
  }

  String _label(String type) {
    switch (type) {
      case 'phone_reveal':
        return 'Phone Reveal';
      case 'chat_seller':
        return 'Seller Chat';
      case 'add_to_cart':
        return 'Add to Cart';
      case 'checkout_started':
        return 'Checkout Started';
      case 'order_completed':
        return 'Order Completed';
      default:
        return type;
    }
  }

  IconData _icon(String type) {
    switch (type) {
      case 'phone_reveal':
        return Icons.visibility_outlined;
      case 'chat_seller':
        return Icons.chat_bubble_outline;
      case 'add_to_cart':
        return Icons.add_shopping_cart;
      case 'checkout_started':
        return Icons.payments_outlined;
      case 'order_completed':
        return Icons.check_circle_outline;
      default:
        return Icons.insights_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Marketplace Analytics')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _query.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Could not load analytics: ${snapshot.error}', textAlign: TextAlign.center),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;
          int count(String type) => docs.where((d) => d.data()['type'] == type).length;

          final phone = count('phone_reveal');
          final chat = count('chat_seller');
          final cart = count('add_to_cart');
          final checkout = count('checkout_started');
          final orders = count('order_completed');
          final conversion = phone == 0 ? 0.0 : (orders / phone * 100);

          return RefreshIndicator(
            onRefresh: () async => setState(() {}),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _chip('Today', 'today'),
                    _chip('7 Days', '7d'),
                    _chip('30 Days', '30d'),
                    _chip('All Time', 'all'),
                  ],
                ),
                const SizedBox(height: 18),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1.35,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  children: [
                    _metric(Icons.visibility_outlined, 'Phone Reveals', phone),
                    _metric(Icons.chat_bubble_outline, 'Seller Chats', chat),
                    _metric(Icons.add_shopping_cart, 'Add to Cart', cart),
                    _metric(Icons.payments_outlined, 'Checkout Started', checkout),
                    _metric(Icons.check_circle_outline, 'Orders Completed', orders),
                    _metric(Icons.trending_up, 'Reveal → Order', conversion, suffix: '%'),
                  ],
                ),
                const SizedBox(height: 28),
                const Text('Recent Activity', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                if (docs.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: Text('No marketplace activity yet')),
                  ),
                ...docs.take(100).map((doc) {
                  final d = doc.data();
                  final type = (d['type'] ?? '').toString();
                  final ts = d['createdAt'];
                  final time = ts is Timestamp
                      ? ts.toDate().toLocal().toString().substring(0, 16)
                      : '';
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      leading: Icon(_icon(type), size: 25),
                      title: Text(_label(type), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        'Buyer: ${(d['buyerId'] ?? '-')}\n'
                        'Seller: ${(d['sellerId'] ?? '-')}\n'
                        'Source: ${(d['source'] ?? '-')} ${time.isEmpty ? '' : '• $time'}',
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _chip(String text, String value) => ChoiceChip(
        label: Text(text, style: const TextStyle(fontSize: 13)),
        selected: _range == value,
        onSelected: (_) => setState(() => _range = value),
      );

  Widget _metric(IconData icon, String label, num value, {String suffix = ''}) {
    final display = value is double ? value.toStringAsFixed(1) : value.toString();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(.25)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 24),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text('$display$suffix', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, height: 1.0)),
          ),
          const SizedBox(height: 5),
          Flexible(
            child: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, height: 1.15)),
          ),
        ],
      ),
    );
  }
}
