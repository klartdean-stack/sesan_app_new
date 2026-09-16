import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:my_app/order_scanner_service.dart';
import 'package:url_launcher/url_launcher.dart';

class OrderManagementScreen extends StatefulWidget {
  final String sellerId;
  const OrderManagementScreen({super.key, required this.sellerId});

  @override
  _OrderManagementScreenState createState() => _OrderManagementScreenState();
}

class _OrderManagementScreenState extends State<OrderManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Set<String> _updatingOrders = <String>{};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) await launchUrl(launchUri);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8F3),
      appBar: AppBar(
        backgroundColor: const Color(0xFF388E3C),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'sales_management'.tr,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(text: 'sales_new_orders'.tr),
            Tab(text: 'sales_delivery_list'.tr),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.qr_code_scanner,
              color: Colors.white,
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
            child: CircularProgressIndicator(color: Color(0xFF388E3C)),
          );
        }

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return Center(
            child: Text(
              'sales_no_data'.tr,
              style: const TextStyle(color: Color(0xFF6B746B)),
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
    final DateTime orderDate =
        (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now();
    final int daysDifference = DateTime.now().difference(orderDate).inDays;
    final bool isExpired = daysDifference >= 7;
    final List items = data['items'] ?? [];
    final String customerName =
        data['customer_name'] ?? 'sales_unknown_customer'.tr;
    final String customerPhone = data['phone_number'] ?? 'sales_no_phone'.tr;
    final String address = data['shipping_address'] ?? 'sales_no_address'.tr;
    final String status = data['status'] ?? 'pending';

    double totalPrice = 0;
    for (var item in items) {
      final double price =
          double.tryParse(item['price']?.toString() ?? '0') ?? 0;
      final int qty = int.tryParse(item['quantity']?.toString() ?? '1') ?? 1;
      totalPrice += price * qty;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDCE7DC)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2E7D32).withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
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
                        const Icon(Icons.person, color: Color(0xFF388E3C), size: 18),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            customerName,
                            style: const TextStyle(
                              color: Color(0xFF202520),
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
                              color: Color(0xFF5F685F),
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
                            color: Color(0xFF388E3C),
                            size: 16,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            customerPhone,
                            style: const TextStyle(
                              color: Color(0xFF2E7D32),
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
                          color: Color(0xFF7A837A),
                          size: 14,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          DateFormat('dd-MM-yyyy HH:mm').format(orderDate),
                          style: TextStyle(
                            color: isExpired
                                ? Colors.redAccent
                                : const Color(0xFF7A837A),
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
                      color: Color(0xFF7A837A),
                      fontSize: 10,
                    ),
                  ),
                  Text(
                    '${totalPrice.toStringAsFixed(0)} ៛',
                    style: const TextStyle(
                      color: Color(0xFF2E7D32),
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
            child: Divider(color: Color(0xFFE3E9E3), thickness: 1),
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
                                    color: Color(0xFFF0F4F0),
                                    child: const Icon(
                                      Icons.broken_image,
                                      color: Color(0xFF9AA39A),
                                    ),
                                  ),
                            )
                          : Container(
                              width: 60,
                              height: 60,
                              color: Color(0xFFF0F4F0),
                              child: const Icon(
                                Icons.image,
                                color: Color(0xFF9AA39A),
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
                              color: Color(0xFF202520),
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${item['price'] ?? 0} ៛  x  ${item['quantity'] ?? 1}',
                            style: const TextStyle(
                              color: Color(0xFF697269),
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
                                      (data['order_date'] as Timestamp)
                                          .toDate(),
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
    final bool busy = _updatingOrders.contains(docId);

    if (status == 'confirmed') {
      return Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: isExpired ? Colors.grey : Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: isExpired || busy
                  ? null
                  : () => _updateStatus(docId, 'packing'),
              icon: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.inventory_2_outlined, size: 18),
              label: Text('sales_accept_order'.tr),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isExpired ? Colors.grey[800] : Colors.redAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: isExpired || busy
                  ? null
                  : () => _updateStatus(docId, 'rejected'),
              icon: const Icon(Icons.close_rounded, size: 18),
              label: Text('sales_reject'.tr),
            ),
          ),
        ],
      );
    }

    final int currentStep = switch (status) {
      'packing' => 0,
      'on_delivery' => 1,
      'delivered' => 2,
      _ => 0,
    };

    final String currentLabel = switch (status) {
      'packing' => 'sales_prepare'.tr,
      'on_delivery' => 'sales_shipping'.tr,
      'delivered' => 'sales_delivered'.tr,
      _ => status,
    };

    final IconData currentIcon = switch (status) {
      'packing' => Icons.inventory_2_rounded,
      'on_delivery' => Icons.local_shipping_rounded,
      'delivered' => Icons.check_circle_rounded,
      _ => Icons.info_outline_rounded,
    };

    final Color currentColor = switch (status) {
      'packing' => Colors.amber,
      'on_delivery' => Colors.blueAccent,
      'delivered' => const Color(0xFF388E3C),
      _ => Colors.amber,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: currentColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: currentColor.withOpacity(0.55)),
          ),
          child: Row(
            children: [
              Icon(currentIcon, color: currentColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  currentLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: currentColor,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (busy)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: currentColor,
                  ),
                )
              else
                Icon(
                  status == 'delivered'
                      ? Icons.verified_rounded
                      : Icons.radio_button_checked_rounded,
                  color: currentColor,
                  size: 19,
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildStatusStep(
                icon: Icons.inventory_2_outlined,
                label: 'sales_prepare'.tr,
                stepIndex: 0,
                currentStep: currentStep,
              ),
            ),
            _buildStepConnector(currentStep >= 1),
            Expanded(
              child: _buildStatusStep(
                icon: Icons.local_shipping_outlined,
                label: 'sales_shipping'.tr,
                stepIndex: 1,
                currentStep: currentStep,
              ),
            ),
            _buildStepConnector(currentStep >= 2),
            Expanded(
              child: _buildStatusStep(
                icon: Icons.check_circle_outline_rounded,
                label: 'sales_delivered'.tr,
                stepIndex: 2,
                currentStep: currentStep,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (status == 'packing')
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFFE0E5E0),
              disabledForegroundColor: const Color(0xFF9AA19A),
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: isExpired || busy
                ? null
                : () => _updateStatus(docId, 'on_delivery'),
            icon: busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.local_shipping_rounded),
            label: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    'sales_shipping'.tr,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.arrow_forward_rounded, size: 18),
              ],
            ),
          )
        else if (status == 'on_delivery')
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFFE0E5E0),
              disabledForegroundColor: const Color(0xFF9AA19A),
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: isExpired || busy
                ? null
                : () => _updateStatus(docId, 'delivered'),
            icon: busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check_circle_outline_rounded),
            label: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    'sales_delivered'.tr,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.arrow_forward_rounded, size: 18),
              ],
            ),
          )
        else if (status == 'delivered')
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF388E3C).withOpacity(0.35)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.verified_rounded,
                  color: Color(0xFF388E3C),
                  size: 19,
                ),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    'sales_delivered'.tr,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF388E3C),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildStatusStep({
    required IconData icon,
    required String label,
    required int stepIndex,
    required int currentStep,
  }) {
    final bool completed = stepIndex < currentStep;
    final bool current = stepIndex == currentStep;
    final Color color = completed
        ? const Color(0xFF388E3C)
        : current
            ? const Color(0xFFF9A825)
            : const Color(0xFFB0B8B0);

    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: current ? 36 : 32,
          height: current ? 36 : 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: current
                ? const Color(0xFFFFF3CD)
                : completed
                    ? const Color(0xFFE8F5E9)
                    : const Color(0xFFF1F4F1),
            border: Border.all(
              color: color,
              width: current ? 2.2 : 1.4,
            ),
          ),
          child: Icon(
            completed ? Icons.check_rounded : icon,
            color: color,
            size: current ? 19 : 17,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: color,
            fontSize: 9.5,
            fontWeight: current || completed
                ? FontWeight.bold
                : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildStepConnector(bool completed) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(left: 3, right: 3, bottom: 23),
        decoration: BoxDecoration(
          color: completed
              ? const Color(0xFF388E3C)
              : const Color(0xFFD5DCD5),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Future<void> _updateStatus(String docId, String newStatus) async {
    if (_updatingOrders.contains(docId)) return;
    setState(() => _updatingOrders.add(docId));

    try {
      final callable = FirebaseFunctions.instanceFor(
        region: 'asia-southeast1',
      ).httpsCallable('secureSellerOrderStatus');

      await callable.call({
        'orderId': docId,
        'status': newStatus,
      });

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
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text(
              e.message ?? 'មិនអាចកែស្ថានភាពការកម្ម៉ង់បានទេ',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text('មានបញ្ហា៖ $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _updatingOrders.remove(docId));
      }
    }
  }
}
