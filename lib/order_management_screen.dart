import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
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
        title: const Text(
          'ការងារលក់ដូរ',
          style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.amber,
          labelColor: Colors.amber,
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(text: 'កម្មង់ថ្មី'),
            Tab(text: 'បញ្ជីដឹកជញ្ជូន'),
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
              // ហៅ Service ដែលយើងបានបំបែក File មិញមកប្រើ
              OrderScannerService.startScan(context, widget.sellerId);
            },
          ),
          const SizedBox(width: 10), // ថែមឃ្លាតបន្តិចឱ្យស្អាត
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
        if (!snapshot.hasData)
          return const Center(
            child: CircularProgressIndicator(color: Colors.amber),
          );
        final docs = snapshot.data!.docs;
        if (docs.isEmpty)
          return const Center(
            child: Text(
              'មិនទាន់មានទិន្នន័យនៅឡើយ',
              style: TextStyle(color: Colors.white54),
            ),
          );


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
    // --- ទាញទិន្នន័យពី Firebase (ផ្ទៀងផ្ទាត់ Key ឱ្យត្រូវ ១០០%) ---
    final String customerName =
        data['customer_name'] ?? 'ភ្ញៀវមិនស្គាល់ឈ្មោះ'; // បន្ថែមឈ្មោះភ្ញៀវ
    final String customerPhone = data['phone_number'] ?? 'គ្មានលេខទូរស័ព្ទ'; //
    final String address = data['shipping_address'] ?? 'គ្មានអាសយដ្ឋាន'; //
    final String status = data['status'] ?? 'pending';


    // មុខងារគណនាតម្លៃសរុបក្នុងបុង
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
          // --- ផ្នែកព័ត៌មានអតិថិជន (ឈ្មោះ, ទីតាំង, លេខទូរស័ព្ទ) ---
          Row(
            crossAxisAlignment:
            CrossAxisAlignment.start, // ឱ្យវាផ្ដើមពីលើស្មើគ្នា
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ១. បង្ហាញឈ្មោះអតិថិជន
                    Row(
                      children: [
                        const Icon(Icons.person, color: Colors.amber, size: 18),
                        const SizedBox(width: 5),
                        Expanded(
                          // 🎯 ថែម Expanded ទីនេះការពារឈ្មោះភ្ញៀវវែងពេក
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
                    // ២. បង្ហាញអាសយដ្ឋាន (មាន Expanded រួចហើយ ល្អណាស់)
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
                    // ៣. បង្ហាញលេខទូរស័ព្ទ
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
                    // ៤. កាលបរិច្ឆេទ
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


                    // 🎯 ៥. អក្សរព្រមាន (រុញមកដាក់ក្រោមនេះវិញ ទើបលែង Overflow)
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
                          child: const Text(
                            "⚠️ ហួសសុពលភាព ៧ ថ្ងៃ",
                            style: TextStyle(
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


              const SizedBox(width: 10), // ឃ្លាតពី Column ឆ្វេងបន្តិច
              // --- ផ្នែកតម្លៃសរុប (នៅខាងស្ដាំដដែល តែលែងមានអីបុកវាហើយ) ---
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'សរុបក្នុងបុង',
                    style: TextStyle(color: Colors.white54, fontSize: 10),
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


          // --- បង្ហាញបញ្ជីទំនិញ (Unlimited Items) ---
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final item = items[i] as Map<String, dynamic>;
              final String imgUrl = item['image_url'] ?? ''; //


              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    // រូបភាពទំនិញ
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
                            item['product_name'] ?? 'មិនស្គាល់ឈ្មោះ',
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


                          // --- កែមកដាក់ក្នុង Row បែបនេះវិញមេ ទើបនាឡិកានិងម៉ោងនៅជួរជាមួយគ្នា ---
                          if (data['order_date'] !=
                              null) // ថែម if ការពារ App គាំង
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
          // ប៊ូតុងបញ្ជាស្ថានភាព
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
                // 🎯 បើហួស ៧ ថ្ងៃ ឱ្យចេញពណ៌ប្រផេះ
                backgroundColor: isExpired ? Colors.grey : Colors.green,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              // 🎯 បើហួស ៧ ថ្ងៃ ឱ្យ onPressed = null (ចុចលែងកើត)
              onPressed: isExpired
                  ? null
                  : () => _updateStatus(docId, 'packing'),
              child: const Text(
                'យល់ព្រមកម្មង់',
                style: TextStyle(color: Colors.white),
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
              child: const Text(
                'បដិសេធ',
                style: TextStyle(color: Colors.white),
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
          // 🎯 បញ្ជូន isExpired ទៅឱ្យ _statusChip ដែរ
          _statusChip(
            docId,
            'packing',
            '📦 រៀបចំខ្ចប់',
            status == 'packing',
            isExpired,
          ),
          _statusChip(
            docId,
            'on_delivery',
            '🚚 កំពុងដឹក',
            status == 'on_delivery',
            isExpired,
          ),
          _statusChip(
            docId,
            'delivered',
            '✅ បានដល់',
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
        // 🎯 បើ active ពណ៌ amber, បើ expired ពណ៌ខ្មៅស្រអាប់, បើធម្មតាពណ៌សស្រអាប់
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
        // 🎯 បើហួស ៧ ថ្ងៃ ឱ្យចុចលែងចេញ
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


    // ទាញយកលុយដែលត្រូវឱ្យអ្នកលក់ (៩៣%) ដែលមេបានគណនាទុកតាំងពីពេលបង្កើតបុង
    double sellerEarnings =
        double.tryParse(orderData['seller_earnings']?.toString() ?? '0') ?? 0;


    WriteBatch batch = FirebaseFirestore.instance.batch();


    // ១. រៀបចំទិន្នន័យសម្រាប់ Update
    Map<String, dynamic> updateData = {
      'status': newStatus,
      'last_update':
      FieldValue.serverTimestamp(), // ថែមនេះដើម្បីឱ្យ Cloud ដឹងថាមានការប្រែប្រួលថ្មី
    };


    // 🎯 បន្ថែមលក្ខខណ្ឌពិសេសសម្រាប់ Status នីមួយៗ
    if (newStatus == 'packing') {
      updateData['packing_date'] = FieldValue.serverTimestamp();
      updateData['is_settled'] = false;
    } else if (newStatus == 'on_delivery') {
      updateData['delivery_started_at'] = FieldValue.serverTimestamp();
    } else if (newStatus == 'delivered') {
      updateData['delivered_at'] = FieldValue.serverTimestamp();
    }


    // 🚀 Update ចូល Firestore
    batch.update(
      FirebaseFirestore.instance.collection('orders').doc(docId),
      updateData,
    );


    // ២. Logic បាញ់លុយចូលកាបូប (Wallet) ពេលដូរទៅ Packing
    // 🎯 នេះជាកន្លែងដែលធ្វើឱ្យលុយមេដើរត្រូវតាម UI កាបូបលុយថ្មី
    if (newStatus == 'packing' && orderData['status'] == 'confirmed') {
      DocumentReference userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(sellerId);


      batch.update(userRef, {
        'balance': FieldValue.increment(sellerEarnings), // បូកចូលកញ្ចប់សរុប
        'wallet_balance': FieldValue.increment(
          sellerEarnings,
        ), // បូកចូលកញ្ចប់រង់ចាំ
      });


      // បើមានបូកលុយចូល System Settings (របាយការណ៍ Admin) មេអាចទុកកូដចាស់មេនៅទីនេះបាន
      var appWalletRef = FirebaseFirestore.instance
          .collection('system_settings')
          .doc('wallet');
      batch.update(appWalletRef, {
        'total_seller_payout': FieldValue.increment(sellerEarnings),
      });
    }


    await batch.commit();


    // បង្ហាញដំណឹងប្រាប់អ្នកលក់
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("បានប្តូរទៅជា $newStatus និងរៀបចំប្រព័ន្ធលុយរួចរាល់"),
        ),
      );
    }
  }
}



