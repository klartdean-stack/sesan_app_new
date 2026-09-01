import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OrderTrackingScreen extends StatefulWidget {
  const OrderTrackingScreen({super.key});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadUserId();
  }

  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _currentUserId = prefs.getString('user_uid'));
  }

  Future<void> _confirmReceipt(BuildContext context, String docId) async {
    try {
      await FirebaseFirestore.instance.collection('orders').doc(docId).update({
        'status': 'delivered',
        'receivedByBuyer': true,
        'receivedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('tracking_received_thanks'.tr)),
        );
      }
    } catch (e) {
      debugPrint("Error updating status: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F101A),
      appBar: AppBar(
        title: Text('tracking_title'.tr,
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: _currentUserId == null
          ? const Center(child: CircularProgressIndicator(color: Colors.amber))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('orders')
                  .where('customer_id', isEqualTo: _currentUserId)
                  .orderBy('created_at', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.amber));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return _buildEmptyState();
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var doc = snapshot.data!.docs[index];
                    var order = doc.data() as Map<String, dynamic>;
                    String status = order['status'] ?? 'pending';
                    List items = order['items'] ?? [];
                    DateTime orderDate = (order['created_at'] as Timestamp?)?.toDate() ?? DateTime.now();
                    String formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(orderDate);
                    return _buildOrderCard(context, doc.id, order, status, items, formattedDate);
                  },
                );
              },
            ),
    );
  }

  Widget _buildOrderCard(
    BuildContext context,
    String docId,
    Map order,
    String status,
    List items,
    String date,
  ) {
    final createdAt = order['created_at'] is Timestamp
        ? (order['created_at'] as Timestamp).toDate()
        : DateTime.now();
    return Container(
      margin: const EdgeInsets.only(bottom: 25),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1C2E),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('tracking_code'.trParams({'code': docId.substring(0, 8).toUpperCase()}),
                  style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 4),
              Text(date, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)),
              Text('tracking_purchase_date'.trParams({'date': DateFormat('dd-MM-yyyy').format(createdAt)}),
                  style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ]),
          ),
          IconButton(
            onPressed: () => _showQRDialog(context, docId),
            icon: const Icon(Icons.qr_code_scanner, color: Colors.white70),
          ),
        ]),
        Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              items.isNotEmpty ? (items[0]['image_url'] ?? '') : '',
              width: 50,
              height: 50,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(Icons.inventory, color: Colors.white24),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Text(
              items.isNotEmpty ? (items[0]['product_name'] ?? 'tracking_package'.tr) : 'tracking_package'.tr,
              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
        ]),
        const Divider(color: Colors.white10, height: 30),
        _buildTrackingTimeline(status),
        const SizedBox(height: 25),
        if (status == 'shipped' || status == 'on_delivery')
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              minimumSize: const Size(double.infinity, 45),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            ),
            onPressed: () => _confirmReceipt(context, docId),
            child: Text('tracking_confirm_received'.tr,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
      ]),
    );
  }

  Widget _buildTrackingTimeline(String status) {
    return Column(children: [
      _buildStep(
        Icons.check_circle,
        'tracking_order_received_title'.tr,
        'tracking_order_received_sub'.tr,
        status == 'pending' || status == 'confirmed' || status == 'packing' || status == 'on_delivery' || status == 'delivered',
        isFirst: true,
      ),
      _buildStep(
        Icons.inventory_2,
        'tracking_packing_title'.tr,
        'tracking_packing_sub'.tr,
        status == 'packing' || status == 'on_delivery' || status == 'delivered',
      ),
      _buildStep(
        Icons.local_shipping,
        'tracking_shipping_title'.tr,
        'tracking_shipping_sub'.tr,
        status == 'on_delivery' || status == 'delivered',
      ),
      _buildStep(
        Icons.location_on,
        'tracking_delivered_title'.tr,
        'tracking_delivered_sub'.tr,
        status == 'delivered',
        isLast: true,
      ),
    ]);
  }

  Widget _buildStep(
    IconData icon,
    String title,
    String subTitle,
    bool isDone, {
    bool isFirst = false,
    bool isLast = false,
  }) {
    Color activeColor = isDone ? Colors.blue : Colors.white10;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Column(children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDone ? activeColor.withOpacity(0.2) : Colors.transparent,
            border: Border.all(color: activeColor, width: 2),
          ),
          child: Icon(icon, size: 16, color: activeColor),
        ),
        if (!isLast) Container(width: 2, height: 40, color: isDone ? activeColor : Colors.white10),
      ]),
      const SizedBox(width: 15),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: TextStyle(color: isDone ? Colors.white : Colors.white30, fontWeight: FontWeight.bold, fontSize: 14)),
          Text(subTitle, style: TextStyle(color: isDone ? Colors.white54 : Colors.white10, fontSize: 11)),
          const SizedBox(height: 20),
        ]),
      ),
    ]);
  }

  Widget _buildEmptyState() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.local_mall_outlined, size: 80, color: Colors.white.withOpacity(0.1)),
      const SizedBox(height: 15),
      Text('tracking_no_orders'.tr, style: const TextStyle(color: Colors.white30)),
    ]));
  }

  void _showQRDialog(BuildContext context, String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        backgroundColor: const Color(0xFF1A1C2E),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('tracking_qr_title'.tr,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
            child: const Icon(Icons.qr_code_2, size: 150, color: Colors.black),
          ),
          const SizedBox(height: 20),
          Text("#$id", style: const TextStyle(color: Colors.white54, fontSize: 10)),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('common_close'.tr, style: const TextStyle(color: Colors.amber)),
          ),
        ]),
      ),
    );
  }
}
