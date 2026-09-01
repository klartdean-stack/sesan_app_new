import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:my_app/dispute_system.dart';

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  String _userId = '';
  bool _isLoading = true;
  final currencyFormat = NumberFormat("#,###");
  final Map<String, String> _sellerNameCache = {};

  @override
  void initState() {
    super.initState();
    _loadUserId();
  }

  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _userId = prefs.getString('user_uid') ?? '';
        _isLoading = false;
      });
    }
  }

  Future<String> _getSellerName(String sellerId) async {
    if (_sellerNameCache.containsKey(sellerId)) return _sellerNameCache[sellerId]!;
    try {
      var sellerDoc = await FirebaseFirestore.instance.collection('sellers').doc(sellerId).get();
      if (sellerDoc.exists) {
        var data = sellerDoc.data() as Map<String, dynamic>?;
        String name = data?['seller_name'] ?? data?['name'] ?? 'order_seller'.tr;
        _sellerNameCache[sellerId] = name;
        return name;
      }
      var userDoc = await FirebaseFirestore.instance.collection('users').doc(sellerId).get();
      if (userDoc.exists) {
        var data = userDoc.data() as Map<String, dynamic>?;
        String name = data?['name'] ?? data?['seller_name'] ?? 'order_seller'.tr;
        _sellerNameCache[sellerId] = name;
        return name;
      }
      return 'order_seller'.tr;
    } catch (e) {
      debugPrint("Get seller name error: $e");
      return 'order_seller'.tr;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending': return const Color(0xFFFF9800);
      case 'confirmed': return const Color(0xFF2196F3);
      case 'packing': return const Color(0xFF9C27B0);
      case 'on_delivery': return const Color(0xFF00BCD4);
      case 'delivered': return const Color(0xFF4CAF50);
      default: return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending': return 'order_status_pending'.tr;
      case 'confirmed': return 'order_status_confirmed'.tr;
      case 'packing': return 'order_status_packing'.tr;
      case 'on_delivery': return 'order_status_shipping'.tr;
      case 'delivered': return 'order_status_delivered'.tr;
      default: return status.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text('order_history_title'.tr, style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Siemreap', fontSize: 18)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _userId.isEmpty
              ? _buildEmptyState()
              : StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('orders').where('customer_id', isEqualTo: _userId).orderBy('created_at', descending: true).snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                    if (snapshot.hasError) {
                      debugPrint("Order Stream Error: ${snapshot.error}");
                      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.error_outline, color: Colors.red[300], size: 64),
                        const SizedBox(height: 16),
                        Text('order_history_load_error'.tr, style: TextStyle(color: Colors.red[300])),
                      ]));
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return _buildEmptyState();
                    return ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: snapshot.data!.docs.length,
                      itemBuilder: (context, index) {
                        var order = snapshot.data!.docs[index];
                        var orderData = order.data() as Map<String, dynamic>;
                        List items = orderData['items'] ?? [];
                        DateTime date = orderData['created_at'] != null ? (orderData['created_at'] as Timestamp).toDate() : DateTime.now();
                        String status = orderData['status'] ?? 'pending';
                        String orderId = order.id.substring(0, 8).toUpperCase();
                        return _buildOrderCard(context: context, order: order, orderData: orderData, items: items, date: date, status: status, orderId: orderId);
                      },
                    );
                  },
                ),
    );
  }

  Widget _buildOrderCard({
    required BuildContext context,
    required QueryDocumentSnapshot order,
    required Map<String, dynamic> orderData,
    required List items,
    required DateTime date,
    required String status,
    required String orderId,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 2,
      child: Column(children: [
        ListTile(
          leading: Icon(Icons.receipt_long, color: _getStatusColor(status)),
          title: Text('order_receipt_number'.trParams({'id': orderId}), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          subtitle: Text(DateFormat('dd-MM-yyyy • hh:mm a').format(date), style: const TextStyle(fontSize: 12)),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: _getStatusColor(status).withOpacity(0.1), borderRadius: BorderRadius.circular(15)),
            child: Text(_getStatusText(status), style: TextStyle(color: _getStatusColor(status), fontWeight: FontWeight.bold, fontSize: 11, fontFamily: 'Siemreap')),
          ),
        ),
        const Divider(height: 1),
        ...items.map((item) {
          String sellerId = item['seller_id']?.toString() ?? '';
          return Column(children: [
            ListTile(
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(item['image_url'] ?? "", width: 50, height: 50, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported)),
              ),
              title: Text(item['product_name'] ?? 'order_unknown_name'.tr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Siemreap'), maxLines: 2, overflow: TextOverflow.ellipsis),
              isThreeLine: true,
              subtitle: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 40),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text("${currencyFormat.format(double.tryParse(item['price'].toString()) ?? 0)} ៛", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13)),
                  _buildSellerName(sellerId),
                ]),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.gavel_rounded, color: Colors.red, size: 20),
                onPressed: () => _startDisputeProcess(context, order.id, item, orderData),
              ),
            ),
            const Divider(indent: 70, endIndent: 20, height: 1),
          ]);
        }).toList(),
        Padding(
          padding: const EdgeInsets.all(15),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('order_total_price'.tr, style: const TextStyle(color: Colors.grey, fontSize: 12, fontFamily: 'Siemreap')),
              Text("${currencyFormat.format(double.tryParse(orderData['total_amount'].toString()) ?? 0)} ៛", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red)),
            ]),
            ElevatedButton.icon(
              onPressed: () => _reOrderItems(context, items),
              icon: const Icon(Icons.refresh, size: 18),
              label: Text('order_buy_again'.tr, style: const TextStyle(fontFamily: 'Siemreap')),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _buildSellerName(String sellerId) {
    if (sellerId.isEmpty) {
      return Text('order_unknown_seller'.tr, style: const TextStyle(fontSize: 11, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis);
    }
    return FutureBuilder<String>(
      future: _getSellerName(sellerId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Text('order_loading'.tr, style: TextStyle(fontSize: 11, color: Colors.grey[400]), maxLines: 1);
        }
        String sellerName = snapshot.data ?? 'order_seller'.tr;
        return Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.storefront_outlined, size: 12, color: Colors.green[600]),
          const SizedBox(width: 4),
          Flexible(child: Text('order_seller_label'.trParams({'name': sellerName}), style: TextStyle(fontSize: 11, color: Colors.green[700], fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis)),
        ]);
      },
    );
  }

  Future<void> _startDisputeProcess(BuildContext context, String orderId, Map<String, dynamic> item, Map<String, dynamic> fullOrderData) async {
    String sellerId = item['seller_id']?.toString() ?? '';
    String sellerName = await _getSellerName(sellerId);
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
    try {
      Map<String, dynamic> completeDisputeData = {
        'order_id': orderId,
        'product_id': item['product_id'],
        'product_name': item['product_name'] ?? 'order_unknown_name'.tr,
        'product_image': item['image_url'] ?? '',
        'customer_phone': fullOrderData['phone_number'] ?? 'order_unknown_phone'.tr,
        'shipping_address': fullOrderData['shipping_address'] ?? 'order_unknown_address'.tr,
        'seller_id': sellerId,
        'seller_name': sellerName,
        'seller_phone': item['seller_phone'] ?? 'order_unknown_phone'.tr,
      };
      if (context.mounted) Navigator.pop(context);
      if (context.mounted) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => DisputeSystem(orderData: completeDisputeData)));
      }
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
    }
  }

  Future<void> _reOrderItems(BuildContext context, List items) async {
    if (_userId.isEmpty) return;
    try {
      WriteBatch batch = FirebaseFirestore.instance.batch();
      for (var item in items) {
        DocumentReference cartRef = FirebaseFirestore.instance.collection('carts').doc();
        batch.set(cartRef, {
          'customer_id': _userId,
          'product_name': item['product_name'],
          'price': item['price'],
          'quantity': 1,
          'seller_id': item['seller_id'],
          'seller_name': item['seller_name'] ?? 'order_general_seller'.tr,
          'image_url': item['image_url'],
          'created_at': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('order_added_cart'.tr, style: const TextStyle(fontFamily: 'Siemreap')), backgroundColor: Colors.green));
      }
    } catch (e) {
      debugPrint('ReOrder Error: $e');
    }
  }

  Widget _buildEmptyState() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey[400]),
      const SizedBox(height: 20),
      Text('order_no_history'.tr, style: const TextStyle(color: Colors.grey, fontSize: 16, fontFamily: 'Siemreap')),
    ]));
  }
}
