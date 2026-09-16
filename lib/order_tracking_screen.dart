import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

class OrderTrackingScreen extends StatefulWidget {
  const OrderTrackingScreen({super.key});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  String? _currentUserId;
  final Set<String> _confirmingOrders = <String>{};

  @override
  void initState() {
    super.initState();
    _loadUserId();
  }

  Future<void> _loadUserId() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (!mounted) return;
    setState(() {
      _currentUserId = uid;
    });
  }

  Future<void> _confirmReceipt(BuildContext context, String docId) async {
    if (_confirmingOrders.contains(docId)) return;
    setState(() => _confirmingOrders.add(docId));

    try {
      final callable = FirebaseFunctions.instanceFor(
        region: 'asia-southeast1',
      ).httpsCallable('secureBuyerConfirmReceipt');

      await callable.call({'orderId': docId});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('tracking_received_thanks'.tr)),
        );
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message ?? 'Unable to confirm receipt'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error confirming receipt: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _confirmingOrders.remove(docId));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F5),
      appBar: AppBar(
        title: Text(
          'tracking_title'.tr,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1F2D24),
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF2E7D32), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        centerTitle: true,
      ),
      body: _currentUserId == null
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF43A047)))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('orders')
                  .where('customer_id', isEqualTo: _currentUserId)
                  .orderBy('created_at', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF43A047)),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState();
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 10,
                  ),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final doc = snapshot.data!.docs[index];
                    final order = doc.data() as Map<String, dynamic>;
                    final String status = order['status'] ?? 'pending';
                    final List items = order['items'] ?? [];

                    final DateTime orderDate =
                        (order['created_at'] as Timestamp?)?.toDate() ??
                            DateTime.now();
                    final String formattedDate =
                        DateFormat('dd-MM-yyyy, hh:mm a').format(orderDate);

                    return _buildOrderCard(
                      context,
                      doc.id,
                      order,
                      status,
                      items,
                      formattedDate,
                    );
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
    final bool confirming = _confirmingOrders.contains(docId);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE1E8E2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'tracking_code'.trParams({
                        'code': docId.substring(0, 8).toUpperCase(),
                      }),
                      style: const TextStyle(
                        color: const Color(0xFF2E7D32),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      date,
                      style: TextStyle(
                        color: const Color(0xFF7A847D),
                        fontSize: 11,
                      ),
                    ),

                  ],
                ),
              ),
              IconButton(
                onPressed: () => _showQRDialog(context, docId),
                icon: const Icon(Icons.qr_code_scanner, color: Color(0xFF2E7D32)),
              ),
            ],
          ),
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  items.isNotEmpty ? items[0]['image_url'] ?? '' : '',
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.inventory, color: Color(0xFFB0B8B2)),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Text(
                  items.isNotEmpty
                      ? items[0]['product_name'] ?? 'tracking_package'.tr
                      : 'tracking_package'.tr,
                  style: const TextStyle(
                    color: const Color(0xFF1F2D24),
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const Divider(color: Color(0xFFE8ECE9), height: 24),
          _buildTrackingTimeline(status),
          const SizedBox(height: 25),
          if (status == 'on_delivery')
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF43A047),
                minimumSize: const Size(double.infinity, 45),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              onPressed: confirming
                  ? null
                  : () => _confirmReceipt(context, docId),
              child: confirming
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'tracking_confirm_received'.tr,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
        ],
      ),
    );
  }

  Widget _buildTrackingTimeline(String status) {
    return Column(
      children: [
        _buildStep(
          Icons.check_circle,
          'tracking_order_received_title'.tr,
          'tracking_order_received_sub'.tr,
          status == 'pending' ||
              status == 'confirmed' ||
              status == 'packing' ||
              status == 'on_delivery' ||
              status == 'delivered',
          isFirst: true,
        ),
        _buildStep(
          Icons.inventory_2,
          'tracking_packing_title'.tr,
          'tracking_packing_sub'.tr,
          status == 'packing' ||
              status == 'on_delivery' ||
              status == 'delivered',
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
      ],
    );
  }

  Widget _buildStep(
    IconData icon,
    String title,
    String subTitle,
    bool isDone, {
    bool isFirst = false,
    bool isLast = false,
  }) {
    final Color activeColor = isDone ? const Color(0xFF43A047) : const Color(0xFFD5DDD7);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDone
                    ? activeColor.withOpacity(0.2)
                    : Colors.transparent,
                border: Border.all(color: activeColor, width: 2),
              ),
              child: Icon(icon, size: 16, color: activeColor),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 32,
                color: isDone ? activeColor : const Color(0xFFE1E7E2),
              ),
          ],
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: isDone ? const Color(0xFF1F2D24) : const Color(0xFF9AA39C),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text(
                subTitle,
                style: TextStyle(
                  color: isDone ? const Color(0xFF6F7A72) : const Color(0xFFB8C0BA),
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 14),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.local_mall_outlined,
            size: 80,
            color: const Color(0xFFD7DED8),
          ),
          const SizedBox(height: 15),
          Text(
            'tracking_no_orders'.tr,
            style: const TextStyle(color: Color(0xFF7A847D)),
          ),
        ],
      ),
    );
  }

  void _showQRDialog(BuildContext context, String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        backgroundColor: Colors.white,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'tracking_qr_title'.tr,
              style: const TextStyle(
                color: const Color(0xFF1F2D24),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.qr_code_2,
                size: 150,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              '#$id',
              style: const TextStyle(color: Color(0xFF7A847D), fontSize: 10),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'common_close'.tr,
                style: const TextStyle(color: Color(0xFF2E7D32)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
