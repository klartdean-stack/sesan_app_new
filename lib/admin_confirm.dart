import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:my_app/admin_shop_upgra%20de_confirm_screen.dart';
import 'package:my_app/admin_vip_confirm_screen.dart';
import 'package:my_app/adminreport_screen.dart';
import 'package:my_app/app_accountant_screen.dart';
import 'package:my_app/marketplace_analytics_service.dart';
import 'admin_history.dart';
import 'admin_rejected_orders_screen.dart';
import 'auction_admin_screen.dart';
import 'admin_refund_screen.dart';

class AdminConfirmPage extends StatelessWidget {
  const AdminConfirmPage({super.key});

  FirebaseFunctions get _functions =>
      FirebaseFunctions.instanceFor(region: 'asia-southeast1');

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat('#,###');

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Text(
          'បញ្ជាក់ការបង់ប្រាក់',
          style: TextStyle(
            fontFamily: 'Siemreap',
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: false,
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        elevation: 1,
        actions: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('orders')
                .where('status', isEqualTo: 'pending')
                .snapshots(),
            builder: (context, snapshot) {
              final count = snapshot.hasData ? snapshot.data!.docs.length : 0;
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.notifications_active_outlined,
                      color: Colors.white,
                    ),
                    onPressed: () {},
                  ),
                  if (count > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFF1A237E),
                            width: 1.5,
                          ),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          '$count',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.grid_view_rounded, color: Colors.white),
            offset: const Offset(0, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            onSelected: (value) {
              switch (value) {
                case 'history':
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AdminHistoryPage()),
                  );
                  break;
                case 'accountant':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AppAccountantScreen(),
                    ),
                  );
                  break;
                case 'report':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AdminReportScreen(),
                    ),
                  );
                  break;
                case 'auction':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AuctionAdminScreen(),
                    ),
                  );
                  break;
                case 'vip':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AdminVipConfirmScreen(),
                    ),
                  );
                  break;
                case 'shop_upgrade':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AdminShopUpgradeConfirmScreen(),
                    ),
                  );
                  break;
                case 'refund':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AdminRefundScreen(),
                    ),
                  );
                  break;
                case 'rejected':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AdminRejectedOrdersScreen(),
                    ),
                  );
                  break;
              }
            },
            itemBuilder: (context) => [
              _buildPopupItem(
                'history',
                Icons.history_rounded,
                'ប្រវត្តិទទួលការកម្ម៉ង់',
                Colors.orange,
              ),
              _buildPopupItem(
                'accountant',
                Icons.account_balance_wallet_rounded,
                'គណនេយ្យករ',
                Colors.amber,
              ),
              _buildPopupItem(
                'report',
                Icons.bar_chart_rounded,
                'របាយការណ៍',
                Colors.blue,
              ),
              _buildPopupItem(
                'auction',
                Icons.gavel_rounded,
                'ការដេញថ្លៃ',
                Colors.pink,
              ),
              _buildPopupItem(
                'vip',
                Icons.diamond_outlined,
                'បញ្ជាក់សំណើ VIP',
                Colors.amber,
              ),
              _buildPopupItem(
                'shop_upgrade',
                Icons.store_mall_directory,
                'បញ្ជាក់ដំឡើងហាង',
                Colors.teal,
              ),
              _buildPopupItem(
                'refund',
                Icons.currency_exchange_rounded,
                'គ្រប់គ្រង Refund',
                Colors.redAccent,
              ),
              _buildPopupItem(
                'rejected',
                Icons.cancel_outlined,
                'ការបដិសេធ',
                Colors.red,
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where('status', isEqualTo: 'pending')
            .orderBy('created_at', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('មានបញ្ហាទាញទិន្នន័យ'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox_rounded, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    'មិនទាន់មានការកម្មង់ថ្មី',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 16,
                      fontFamily: 'Siemreap',
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final orderDoc = snapshot.data!.docs[index];
              final orderData = orderDoc.data() as Map<String, dynamic>;
              final totalPrice =
                  (orderData['total_amount'] ?? orderData['total_price'] ?? 0)
                      .toDouble();
              final customerName =
                  orderData['customer_name'] ?? 'ភ្ញៀវមិនស្គាល់ឈ្មោះ';
              final phone = orderData['phone_number'] ?? 'មិនមានលេខ';
              final address =
                  orderData['shipping_address'] ?? 'មិនមានអាសយដ្ឋាន';
              final paymentImage =
                  orderData['payment_image'] ?? orderData['paymentProof'] ?? '';
              final items = orderData['items'] as List? ?? [];
              final timestamp = orderData['created_at'] is Timestamp
                  ? orderData['created_at'] as Timestamp
                  : Timestamp.now();
              final formattedDate =
                  DateFormat('dd-MM-yyyy HH:mm').format(timestamp.toDate());

              return _buildOrderCard(
                context: context,
                format: currencyFormat,
                orderId: orderDoc.id,
                orderData: orderData,
                customerName: customerName,
                phone: phone,
                address: address,
                formattedDate: formattedDate,
                paymentImage: paymentImage,
                items: items,
                totalPrice: totalPrice,
              );
            },
          );
        },
      ),
    );
  }

  PopupMenuItem<String> _buildPopupItem(
    String value,
    IconData icon,
    String title,
    Color color,
  ) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Siemreap',
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard({
    required BuildContext context,
    required NumberFormat format,
    required String orderId,
    required Map<String, dynamic> orderData,
    required String customerName,
    required String phone,
    required String address,
    required String formattedDate,
    required String paymentImage,
    required List items,
    required double totalPrice,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildCustomerHeader(customerName, formattedDate, phone, address),
          _buildSellerAndItemsSection(orderData, items),
          if (paymentImage.toString().isNotEmpty) ...[
            const Divider(height: 1),
            _buildPaymentProof(context, paymentImage.toString()),
          ],
          _buildActionFooter(
            context,
            format,
            totalPrice,
            orderId,
            orderData,
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerHeader(
    String name,
    String date,
    String phone,
    String address,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(
        color: Color(0xFFE8EAF6),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFF3949AB),
            radius: 22,
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    fontFamily: 'Siemreap',
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '📅 $date',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
                Text(
                  '📞 $phone',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
                Text(
                  '📍 $address',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.orange,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Pending',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSellerAndItemsSection(
    Map<String, dynamic> orderData,
    List items,
  ) {
    String sellerId = '';
    if (items.isNotEmpty && items[0]['seller_id'] != null) {
      sellerId = items[0]['seller_id'].toString();
    } else if (orderData['seller_id'] != null) {
      sellerId = orderData['seller_id'].toString();
    }

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FutureBuilder<QuerySnapshot>(
            future: sellerId.isNotEmpty
                ? FirebaseFirestore.instance
                    .collection('products')
                    .where('seller_id', isEqualTo: sellerId)
                    .limit(1)
                    .get()
                : null,
            builder: (context, snapshot) {
              String sellerName = 'មិនស្គាល់ឈ្មោះ';
              String sellerPhoto = '';
              String sellerPhone = 'គ្មានលេខ';

              if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                final productData =
                    snapshot.data!.docs.first.data() as Map<String, dynamic>;
                sellerName =
                    productData['seller_name']?.toString() ?? sellerName;
                sellerPhoto = productData['seller_photo']?.toString() ?? '';
                sellerPhone =
                    productData['seller_phone']?.toString() ??
                    productData['phone1']?.toString() ??
                    sellerPhone;
              } else if (items.isNotEmpty) {
                sellerName = items[0]['seller_name']?.toString() ?? sellerName;
                sellerPhoto = items[0]['seller_photo']?.toString() ?? '';
                sellerPhone =
                    items[0]['seller_phone']?.toString() ??
                    items[0]['phone1']?.toString() ??
                    sellerPhone;
              } else {
                sellerName =
                    orderData['seller_name']?.toString() ?? sellerName;
                sellerPhoto = orderData['seller_photo']?.toString() ?? '';
                sellerPhone =
                    orderData['seller_phone']?.toString() ??
                    orderData['phone1']?.toString() ??
                    sellerPhone;
              }

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade100),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: Colors.green.shade100,
                      backgroundImage: sellerPhoto.isNotEmpty
                          ? NetworkImage(sellerPhoto)
                          : null,
                      child: sellerPhoto.isEmpty
                          ? Icon(
                              Icons.storefront_rounded,
                              color: Colors.green[700],
                              size: 22,
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sellerName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              fontFamily: 'Siemreap',
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.phone_android_rounded,
                                size: 14,
                                color: Colors.green[700],
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  sellerPhone,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.green[800],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '🏪 អ្នកលក់',
                        style: TextStyle(
                          color: Colors.green[800],
                          fontSize: 11,
                          fontFamily: 'Siemreap',
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          ...items.map((item) => _buildItemRow(item)),
        ],
      ),
    );
  }

  Widget _buildItemRow(dynamic item) {
    final imageUrl = item['image_url']?.toString() ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: imageUrl.isNotEmpty
                ? Image.network(
                    imageUrl,
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildImgPlaceholder(),
                  )
                : _buildImgPlaceholder(),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['product_name'] ?? 'ទំនិញ',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    fontFamily: 'Siemreap',
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${NumberFormat('#,###').format(double.tryParse(item['price']?.toString() ?? '0') ?? 0)} ៛',
                  style: TextStyle(color: Colors.red[700], fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            'x${item['quantity'] ?? 1}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildImgPlaceholder() => Container(
        width: 52,
        height: 52,
        color: Colors.grey[200],
        child: const Icon(Icons.image_outlined, color: Colors.grey),
      );

  Widget _buildPaymentProof(BuildContext context, String url) {
    return GestureDetector(
      onTap: () => _showFullImage(context, url),
      child: Container(
        margin: const EdgeInsets.all(14),
        height: 180,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(url, fit: BoxFit.cover),
        ),
      ),
    );
  }

  Widget _buildActionFooter(
    BuildContext context,
    NumberFormat format,
    double total,
    String orderId,
    Map<String, dynamic> orderData,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      child: Column(
        children: [
          _buildSummaryLine(
            'ទឹកប្រាក់សរុប',
            '${format.format(total)} ៛',
            Colors.black87,
            isBold: true,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _handleRejectOrder(context, orderId),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                  ),
                  child: const Text(
                    'បដិសេធ',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () => _handleConfirmOrder(
                    context,
                    orderId,
                    orderData,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                  ),
                  child: const Text(
                    'យល់ព្រមបូកលុយ',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryLine(
    String label,
    String value,
    Color color, {
    bool isBold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontFamily: 'Siemreap'),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 16 : 13,
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Future<void> _handleConfirmOrder(
    BuildContext context,
    String orderId,
    Map<String, dynamic> orderData,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          '✅ បញ្ជាក់ការបង់ប្រាក់',
          style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'បុងលេខ: ${orderId.substring(0, 8).toUpperCase()}\n\nតើបានពិនិត្យស្លីបរួចហើយមែន?',
          style: const TextStyle(
            color: Colors.white70,
            fontFamily: 'Siemreap',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ទេ', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[700],
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'យល់ព្រម',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (!context.mounted || confirm != true) return;

    try {
      final callable = _functions.httpsCallable('secureAdminConfirmOrder');
      await callable.call({'orderId': orderId});

      final completedItems = orderData['items'] as List? ?? const [];
      final firstProductId = completedItems.isNotEmpty
          ? ((completedItems.first as Map?)?['product_id'] ?? '').toString()
          : '';
      await MarketplaceAnalyticsService.logOrderCompleted(
        orderId: orderId,
        buyerId: (orderData['customer_id'] ?? '').toString(),
        sellerId: (orderData['seller_id'] ?? '').toString(),
        productId: firstProductId,
        totalAmount: orderData['total_amount'] is num
            ? orderData['total_amount'] as num
            : num.tryParse((orderData['total_amount'] ?? '').toString()),
      );

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.green,
          content: Text(
            '✅ Admin បញ្ជាក់ជោគជ័យ!',
            style: TextStyle(fontFamily: 'Siemreap'),
          ),
        ),
      );
    } on FirebaseFunctionsException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ ${e.message ?? 'មិនអាចបញ្ជាក់ Order បានទេ'}'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ មានបញ្ហា: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handleRejectOrder(BuildContext context, String orderId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          '❌ បដិសេធការកម្មង់?',
          style: TextStyle(fontFamily: 'Siemreap'),
        ),
        content: const Text(
          'ករណីអស់ទំនិញ ឬកម្មង់ខ្យល់ — Order នេះនឹងត្រូវបានបដិសេធ ហើយស្តុកនឹងត្រូវស្តារតាម Backend។',
          style: TextStyle(fontFamily: 'Siemreap'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ទេ'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'យល់ព្រម',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (!context.mounted || confirm != true) return;

    try {
      final callable = _functions.httpsCallable('secureAdminRejectOrder');
      await callable.call({'orderId': orderId});

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'បានបដិសេធ Order! ទិន្នន័យត្រូវបានរក្សាទុក',
            style: TextStyle(fontFamily: 'Siemreap'),
          ),
          backgroundColor: Colors.red,
        ),
      );
    } on FirebaseFunctionsException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ ${e.message ?? 'មិនអាចបដិសេធ Order បានទេ'}'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ មានបញ្ហា: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showFullImage(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        child: InteractiveViewer(child: Image.network(url)),
      ),
    );
  }
}
