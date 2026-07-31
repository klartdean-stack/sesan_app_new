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


  // ✅ Cache ឈ្មោះអ្នកលក់ កុំឱ្យបូមឡើងវិញច្រើនដង
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


  // ✅ មុខងារទាញឈ្មោះអ្នកលក់ពី seller_id
  Future<String> _getSellerName(String sellerId) async {
    // បើមានក្នុង Cache យកចេញមកវិញ
    if (_sellerNameCache.containsKey(sellerId)) {
      return _sellerNameCache[sellerId]!;
    }


    try {
      // ព្យាយាមយកពី Collection 'sellers' ជាមុន
      var sellerDoc = await FirebaseFirestore.instance
          .collection('sellers')
          .doc(sellerId)
          .get();


      if (sellerDoc.exists) {
        var data = sellerDoc.data() as Map<String, dynamic>?;
        String name = data?['seller_name'] ?? data?['name'] ?? 'អ្នកលក់';
        _sellerNameCache[sellerId] = name;
        return name;
      }


      // បើអត់ឃើញ ព្យាយាមយកពី Collection 'users'
      var userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(sellerId)
          .get();


      if (userDoc.exists) {
        var data = userDoc.data() as Map<String, dynamic>?;
        String name = data?['name'] ?? data?['seller_name'] ?? 'អ្នកលក់';
        _sellerNameCache[sellerId] = name;
        return name;
      }


      return 'អ្នកលក់';
    } catch (e) {
      debugPrint("Get seller name error: $e");
      return 'អ្នកលក់';
    }
  }


  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return const Color(0xFFFF9800);
      case 'confirmed':
        return const Color(0xFF2196F3);
      case 'packing':
        return const Color(0xFF9C27B0);
      case 'on_delivery':
        return const Color(0xFF00BCD4);
      case 'delivered':
        return const Color(0xFF4CAF50);
      default:
        return Colors.grey;
    }
  }


  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return '⏳ រង់ចាំ';
      case 'confirmed':
        return '✅ បញ្ជាក់ហើយ';
      case 'packing':
        return '📦 កំពុងខ្ចប់';
      case 'on_delivery':
        return '🚚 កំពុងដឹក';
      case 'delivered':
        return '✅ ដល់ទីតាំង';
      default:
        return status.toUpperCase();
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'ប្រវត្តិកម្មង់របស់ខ្ញុំ',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontFamily: 'Siemreap',
            fontSize: 18,
          ),
        ),
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
        stream: FirebaseFirestore.instance
            .collection('orders') // 🎯 ចូលទៅរកក្នុង collection orders
            .where(
          'customer_id',
          isEqualTo: _userId,
        ) // 🎯 ប្រើ 'customer_id' ឱ្យត្រូវតាម Database មេ
            .orderBy('created_at', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            debugPrint("Order Stream Error: ${snapshot.error}");
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Colors.red[300],
                    size: 64,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "មិនអាចផ្ទុកប្រវត្តិបាន",
                    style: TextStyle(color: Colors.red[300]),
                  ),
                ],
              ),
            );
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState();
          }


          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var order = snapshot.data!.docs[index];
              var orderData = order.data() as Map<String, dynamic>;
              List items = orderData['items'] ?? [];
              DateTime date = orderData['created_at'] != null
                  ? (orderData['created_at'] as Timestamp).toDate()
                  : DateTime.now();
              String status = orderData['status'] ?? 'pending';
              String orderId = order.id.substring(0, 8).toUpperCase();


              return _buildOrderCard(
                context: context,
                order: order,
                orderData: orderData,
                items: items,
                date: date,
                status: status,
                orderId: orderId,
              );
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
      child: Column(
        children: [
          // Header
          ListTile(
            leading: Icon(Icons.receipt_long, color: _getStatusColor(status)),
            title: Text(
              "បុងលេខ: $orderId",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            subtitle: Text(
              DateFormat('dd-MM-yyyy • hh:mm a').format(date),
              style: const TextStyle(fontSize: 12),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _getStatusColor(status).withOpacity(0.1),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Text(
                _getStatusText(status),
                style: TextStyle(
                  color: _getStatusColor(status),
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  fontFamily: 'Siemreap',
                ),
              ),
            ),
          ),
          const Divider(height: 1), // Items List
          ...items.map((item) {
            String sellerId = item['seller_id']?.toString() ?? '';


            return Column(
              children: [
                ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      item['image_url'] ?? "",
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                      const Icon(Icons.image_not_supported),
                    ),
                  ),
                  title: Text(
                    item['product_name'] ?? "គ្មានឈ្មោះ",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      fontFamily: 'Siemreap',
                    ),
                    maxLines: 2, // ✅ កំណត់ max lines
                    overflow: TextOverflow.ellipsis, // ✅ កាត់អក្សរ
                  ),
                  isThreeLine: true, // ✅ អនុញ្ញាតឱ្យមាន 3 បន្ទាត់
                  subtitle: ConstrainedBox(
                    // ✅ កំណត់ទំហំ
                    constraints: const BoxConstraints(maxHeight: 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "${currencyFormat.format(double.tryParse(item['price'].toString()) ?? 0)} ៛",
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        // ✅ ប្រើ FutureBuilder ទាញឈ្មោះអ្នកលក់
                        _buildSellerName(sellerId),
                      ],
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(
                      Icons.gavel_rounded,
                      color: Colors.red,
                      size: 20,
                    ),
                    onPressed: () => _startDisputeProcess(
                      context,
                      order.id,
                      item,
                      orderData,
                    ),
                  ),
                ),
                const Divider(indent: 70, endIndent: 20, height: 1),
              ],
            );
          }).toList(),


          // Footer
          Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "តម្លៃសរុប",
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                        fontFamily: 'Siemreap',
                      ),
                    ),
                    Text(
                      "${currencyFormat.format(double.tryParse(orderData['total_amount'].toString()) ?? 0)} ៛",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () => _reOrderItems(context, items),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text(
                    "ទិញម្ដងទៀត",
                    style: TextStyle(fontFamily: 'Siemreap'),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildSellerName(String sellerId) {
    if (sellerId.isEmpty) {
      return const Text(
        "អ្នកលក់៖ មិនស្គាល់",
        style: TextStyle(fontSize: 11, color: Colors.grey),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }


    return FutureBuilder<String>(
      future: _getSellerName(sellerId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Text(
            "កំពុងទាញយក...",
            style: TextStyle(fontSize: 11, color: Colors.grey[400]),
            maxLines: 1,
          );
        }


        String sellerName = snapshot.data ?? 'អ្នកលក់';


        return Row(
          mainAxisSize: MainAxisSize.min, // ✅ កុំឱ្យរីកធំហួស
          children: [
            Icon(Icons.storefront_outlined, size: 12, color: Colors.green[600]),
            const SizedBox(width: 4),
            Flexible(
              // ✅ អនុញ្ញាតឱ្យអក្សរកាត់បើវែង
              child: Text(
                "អ្នកលក់៖ $sellerName",
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.green[700],
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );
      },
    );
  }


  Future<void> _startDisputeProcess(
      BuildContext context,
      String orderId,
      Map<String, dynamic> item,
      Map<String, dynamic> fullOrderData,
      ) async {
    // ទាញឈ្មោះអ្នកលក់ជាមុន
    String sellerId = item['seller_id']?.toString() ?? '';
    String sellerName = await _getSellerName(sellerId);


    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      Map<String, dynamic> completeDisputeData = {
        'order_id': orderId,
        'product_id': item['product_id'],
        'product_name': item['product_name'] ?? 'គ្មានឈ្មោះ',
        'product_image': item['image_url'] ?? '',
        'customer_phone': fullOrderData['phone_number'] ?? 'គ្មានលេខ',
        'shipping_address':
        fullOrderData['shipping_address'] ?? 'គ្មានអាសយដ្ឋាន',
        'seller_id': sellerId,
        'seller_name': sellerName, // ✅ ប្រើឈ្មោះពិតប្រាកដ
        'seller_phone': item['seller_phone'] ?? 'គ្មានលេខ',
      };
      Navigator.pop(context);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DisputeSystem(orderData: completeDisputeData),
        ),
      );
    } catch (e) {
      Navigator.pop(context);
    }
  }


  Future<void> _reOrderItems(BuildContext context, List items) async {
    if (_userId.isEmpty) return;
    try {
      WriteBatch batch = FirebaseFirestore.instance.batch();
      for (var item in items) {
        DocumentReference cartRef = FirebaseFirestore.instance
            .collection('carts')
            .doc();
        batch.set(cartRef, {
          'customer_id': _userId,
          'product_name': item['product_name'],
          'price': item['price'],
          'quantity': 1,
          'seller_id': item['seller_id'],
          'seller_name': item['seller_name'] ?? 'អ្នកលក់ទូទៅ',
          'image_url': item['image_url'],
          'created_at': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '🛒 បានថែមចូលកន្ត្រកហើយ!',
            style: TextStyle(fontFamily: 'Siemreap'),
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint('ReOrder Error: $e');
    }
  }


  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 20),
          const Text(
            'មិនទាន់មានប្រវត្តិកម្មង់',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 16,
              fontFamily: 'Siemreap',
            ),
          ),
        ],
      ),
    );
  }
}



