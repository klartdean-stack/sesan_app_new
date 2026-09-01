import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:get/get.dart';
import 'package:my_app/order_scanner_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';

class OrderManagementScreen extends StatefulWidget {
  final String sellerId;
  const OrderManagementScreen({super.key, required this.sellerId});

  @override
  _OrderManagementScreenState createState() => _OrderManagementScreenState();
}

class _OrderManagementScreenState extends State<OrderManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) await launchUrl(launchUri);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        title: Text(
          'sales_management'.tr,
          style: const TextStyle(
            color: Colors.amber,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.amber,
          labelColor: Colors.amber,
          unselectedLabelColor: Colors.white54,
          tabs: [
            Tab(text: 'sales_new_orders'.tr),
            Tab(text: 'sales_delivery_list'.tr),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.qr_code_scanner,
              color: Colors.amber,
              size: 28,
            ),
            onPressed: () {
              OrderScannerService.startScan(context, widget.sellerId);
            },
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOrderList(['confirmed']),
          _buildOrderList(['packing', 'on_delivery', 'delivered']),
        ],
      ),
    );
  }

  Widget _buildOrderList(List<String> statuses) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('seller_id', isEqualTo: widget.sellerId)
          .where('status', whereIn: statuses)
          .orderBy('created_at', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.amber),
          );
        }
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return Center(
            child: Text(
              'sales_no_data'.tr,
              style: const TextStyle(color: Colors.white54),
            ),
          );
        }

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            return _buildOrderCard(data, docs[index].id);
          },
        );
      },
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> data, String docId) {
    DateTime orderDate =
        (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now();
    int daysDifference = DateTime.now().difference(orderDate).inDays;
    bool isExpired = daysDifference >= 7;
    final List items = data['items'] ?? [];
    final String customerName =
        data['customer_name'] ?? 'sales_unknown_customer'.tr;
    final String customerPhone = data['phone_number'] ?? 'sales_no_phone'.tr;
    final String address = data['shipping_address'] ?? 'sales_no_address'.tr;
    final String status = data['status'] ?? 'pending';

    double totalPrice = 0;
    for (var item in items) {
      double price = double.tryParse(item['price']?.toString() ?? '0') ?? 0;
      int qty = int.tryParse(item['quantity']?.toString() ?? '1') ?? 1;
      totalPrice += (price * qty);
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.amber.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.person, color: Colors.amber, size: 18),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            customerName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          color: Colors.redAccent,
                          size: 16,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            address,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () => _makePhoneCall(customerPhone),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.phone,
                            color: Colors.greenAccent,
                            size: 16,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            customerPhone,
                            style: const TextStyle(
                              color: Colors.greenAccent,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_month,
                          color: Colors.white54,
                          size: 14,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          DateFormat('dd-MM-yyyy HH:mm').format(orderDate),
                          style: TextStyle(
                            color: isExpired
                                ? Colors.redAccent
                                : Colors.white54,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    if (isExpired)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            'sales_expired'.tr,
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'sales_receipt_total'.tr,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 10,
                    ),
                  ),
                  Text(
                    '${totalPrice.toStringAsFixed(0)} ៛',
                    style: const TextStyle(
                      color: Colors.amber,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: Colors.white10, thickness: 1),
          ),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final item = items[i] as Map<String, dynamic>;
              final String imgUrl = item['image_url'] ?? '';
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: imgUrl.isNotEmpty
                          ? Image.network(
                              imgUrl,
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                    width: 60,
                                    height: 60,
                                    color: Colors.white10,
                                    child: const Icon(
                                      Icons.broken_image,
                                      color: Colors.white24,
                                    ),
                                  ),
                            )
                          : Container(
                              width: 60,
                              height: 60,
                              color: Colors.white10,
                              child: const Icon(
                                Icons.image,
                                color: Colors.white24,
                              ),
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['product_name'] ?? 'sales_unknown_product'.tr,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${item['price'] ?? 0} ៛  x  ${item['quantity'] ?? 1}',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                          if (data['order_date'] != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.access_time,
                                    size: 14,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    DateFormat('dd/MM/yyyy HH:mm').format(
                                      (data['order_date'] as Timestamp).toDate(),
                                    ),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          _buildActionButtons(docId, status, isExpired),
        ],
      ),
    );
  }

  Widget _buildActionButtons(String docId, String status, bool isExpired) {
    if (status == 'confirmed') {
      return Row(
        children: [
          Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isExpired ? Colors.grey : Colors.green,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: isExpired
                  ? null
                  : () => _updateStatus(docId, 'packing'),
              child: Text(
                'sales_accept_order'.tr,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isExpired
                    ? Colors.grey[800]
                    : Colors.redAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: isExpired
                  ? null
                  : () => _updateStatus(docId, 'rejected'),
              child: Text(
                'sales_reject'.tr,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _statusChip(
            docId,
            'packing',
            'sales_prepare'.tr,
            status == 'packing',
            isExpired,
          ),
          _statusChip(
            docId,
            'on_delivery',
            'sales_shipping'.tr,
            status == 'on_delivery',
            isExpired,
          ),
          _statusChip(
            docId,
            'delivered',
            'sales_delivered'.tr,
            status == 'delivered',
            isExpired,
          ),
        ],
      ),
    );
  }

  Widget _statusChip(
    String docId,
    String val,
    String label,
    bool active,
    bool isExpired,
  ) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        backgroundColor: active
            ? Colors.amber
            : (isExpired ? Colors.black26 : Colors.white10),
        side: BorderSide.none,
        label: Text(
          label,
          style: TextStyle(
            color: active
                ? Colors.black
                : (isExpired ? Colors.white24 : Colors.white),
            fontSize: 11,
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        onPressed: isExpired ? null : () => _updateStatus(docId, val),
      ),
    );
  }

  void _updateStatus(String docId, String newStatus) async {
    final orderDoc = await FirebaseFirestore.instance
        .collection('orders')
        .doc(docId)
        .get();

    if (!orderDoc.exists) return;

    final orderData = orderDoc.data() as Map<String, dynamic>;
    final String sellerId = orderData['seller_id'] ?? '';
    double sellerEarnings =
        double.tryParse(orderData['seller_earnings']?.toString() ?? '0') ?? 0;

    WriteBatch batch = FirebaseFirestore.instance.batch();
    Map<String, dynamic> updateData = {
      'status': newStatus,
      'last_update': FieldValue.serverTimestamp(),
    };

    if (newStatus == 'packing') {
      updateData['packing_date'] = FieldValue.serverTimestamp();
      updateData['is_settled'] = false;
    } else if (newStatus == 'on_delivery') {
      updateData['delivery_started_at'] = FieldValue.serverTimestamp();
    } else if (newStatus == 'delivered') {
      updateData['delivered_at'] = FieldValue.serverTimestamp();
    }

    if (newStatus == 'rejected' &&
        orderData['status'] != 'rejected' &&
        orderData['stock_restored'] != true) {
      final items = orderData['items'] is List
          ? List<Map<String, dynamic>>.from(
              (orderData['items'] as List).whereType<Map>().map(
                    (item) => Map<String, dynamic>.from(item),
                  ),
            )
          : <Map<String, dynamic>>[];

      for (final item in items) {
        if (item['stock_tracked'] != true) continue;
        final productId = item['product_id']?.toString() ?? '';
        final qty = int.tryParse(item['quantity']?.toString() ?? '') ?? 0;
        if (productId.isEmpty || qty <= 0) continue;

        final productRef = FirebaseFirestore.instance
            .collection('products')
            .doc(productId);
        batch.update(productRef, {
          'stock_quantity': FieldValue.increment(qty),
          'sold_quantity': FieldValue.increment(-qty),
          'is_available': true,
          'stock_updated_at': FieldValue.serverTimestamp(),
        });
      }

      updateData['stock_restored'] = true;
      updateData['stock_restored_at'] = FieldValue.serverTimestamp();
    }

    batch.update(
      FirebaseFirestore.instance.collection('orders').doc(docId),
      updateData,
    );

    if (newStatus == 'packing' && orderData['status'] == 'confirmed') {
      DocumentReference userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(sellerId);

      batch.update(userRef, {
        'balance': FieldValue.increment(sellerEarnings),
        'wallet_balance': FieldValue.increment(sellerEarnings),
      });

      var appWalletRef = FirebaseFirestore.instance
          .collection('system_settings')
          .doc('wallet');
      batch.update(appWalletRef, {
        'total_seller_payout': FieldValue.increment(sellerEarnings),
      });
    }

    await batch.commit();

    final translatedStatus = {
          'packing': 'order_status_packing'.tr,
          'on_delivery': 'order_status_shipping'.tr,
          'delivered': 'order_status_delivered'.tr,
          'rejected': 'sales_reject'.tr,
        }[newStatus] ??
        newStatus;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'sales_status_updated'.trParams({'status': translatedStatus}),
          ),
        ),
      );
    }
  }
}
