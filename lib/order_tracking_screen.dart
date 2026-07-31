import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class OrderTrackingScreen extends StatelessWidget {
  const OrderTrackingScreen({super.key});

  // មុខងារ Update ស្ថានភាពពេល Buyer ចុចទទួលអីវ៉ាន់
  Future<void> _confirmReceipt(BuildContext context, String docId) async {
    try {
      await FirebaseFirestore.instance.collection('orders').doc(docId).update({
        'status': 'delivered',
        'receivedByBuyer': true,
        'receivedAt': FieldValue.serverTimestamp(),
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("អរគុណ! ការទទួលទំនិញត្រូវបានកត់ត្រាទុក។")),
      );
    } catch (e) {
      debugPrint("Error updating status: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F101A),
      appBar: AppBar(
        title: const Text(
          "តាមដានការដឹកជញ្ជូន",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where(
              'customer_id',
              isEqualTo: FirebaseAuth.instance.currentUser?.uid,
            )
            .orderBy('created_at', descending: true) // Sort របស់ថ្មីមកលើ
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.amber),
            );
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var doc = snapshot.data!.docs[index];
              var order = doc.data() as Map<String, dynamic>;
              String status = order['status'] ?? 'pending';
              List items = order['items'] ?? [];

              // កាលបរិច្ឆេទ
              DateTime orderDate =
                  (order['created_at'] as Timestamp?)?.toDate() ??
                  DateTime.now();
              String formattedDate = DateFormat(
                'dd MMM yyyy, hh:mm a',
              ).format(orderDate);
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
    return Container(
      margin: const EdgeInsets.only(bottom: 25),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1C2E),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: ID & Date
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "លេខកូដ: #${docId.substring(0, 8).toUpperCase()}",
                    style: const TextStyle(
                      color: Colors.amber,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    date,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 11,
                    ),
                  ),
                  // ដាក់នៅក្រោម ID កម្ម៉ង់
                  Text(
                    "ថ្ងៃទិញ៖ ${DateFormat('dd-MM-yyyy').format((order['created_at'] as Timestamp).toDate())}",
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
              IconButton(
                onPressed: () => _showQRDialog(context, docId),
                icon: const Icon(Icons.qr_code_scanner, color: Colors.white70),
              ),
            ],
          ),
          // ថែមដុំកូដនេះដើម្បីបង្ហាញឈ្មោះផលិតផលឡើងវិញ
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  items.isNotEmpty ? items[0]['image_url'] : '',
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.inventory, color: Colors.white24),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Text(
                  items.isNotEmpty ? items[0]['product_name'] : "កញ្ចប់អីវ៉ាន់",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const Divider(color: Colors.white10, height: 30),

          // ៤ ដំណាក់កាល Tracking (Stepper)
          _buildTrackingTimeline(status),

          const SizedBox(height: 25),

          // ប៊ូតុងបញ្ជាក់ការទទួល
          if (status == 'shipped')
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                minimumSize: const Size(double.infinity, 45),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              onPressed: () => _confirmReceipt(context, docId),
              child: const Text(
                "ខ្ញុំបានទទួលអីវ៉ាន់ហើយ",
                style: TextStyle(
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
        // ដំណាក់កាលទី ១: អ្នកលក់បានទទួលការកម្ម៉ង់ (Icon គ្រីសខៀវ)
        _buildStep(
          Icons.check_circle,
          "អ្នកលក់បានទទួលការកម្ម៉ង់",
          "រង់ចាំការបញ្ជាក់",
          status == 'pending' ||
              status == 'packing' ||
              status == 'on_delivery' ||
              status == 'delivered',
          isFirst: true,
        ),

        // ដំណាក់កាលទី ២: កំពុងខ្ចប់ឥវ៉ាន់ (Icon រូបប្រអប់)
        _buildStep(
          Icons.inventory_2,
          "កំពុងខ្ចប់ឥវ៉ាន់",
          "អ្នកលក់កំពុងរៀបចំផ្ញើ",
          status == 'packing' ||
              status == 'on_delivery' ||
              status == 'delivered',
        ),

        // ដំណាក់កាលទី ៣: បានដាក់ផ្ញើ (Icon រូបឡានដឹក)
        _buildStep(
          Icons.local_shipping,
          "បានដាក់ផ្ញើ",
          "ទំនិញកំពុងធ្វើដំណើរមករកអ្នក",
          status == 'on_delivery' || status == 'delivered',
        ),

        // ដំណាក់កាលទី ៤: បានដល់ទីតាំង (Icon រូបទីតាំង)
        _buildStep(
          Icons.location_on,
          "បានដល់ទីតាំង",
          "រីករាយជាមួយទំនិញរបស់អ្នក",
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
    Color activeColor = isDone ? Colors.blue : Colors.white10;
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
                height: 40,
                color: isDone ? activeColor : Colors.white10,
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
                  color: isDone ? Colors.white : Colors.white30,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text(
                subTitle,
                style: TextStyle(
                  color: isDone ? Colors.white54 : Colors.white10,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 20),
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
            color: Colors.white.withOpacity(0.1),
          ),
          const SizedBox(height: 15),
          const Text(
            "មិនទាន់មានការកម្ម៉ង់នៅឡើយទេ",
            style: TextStyle(color: Colors.white30),
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
        backgroundColor: const Color(0xFF1A1C2E),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "QR សម្គាល់អីវ៉ាន់",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
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
            const SizedBox(height: 20),
            Text(
              "#$id",
              style: const TextStyle(color: Colors.white54, fontSize: 10),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("បិទ", style: TextStyle(color: Colors.amber)),
            ),
          ],
        ),
      ),
    );
  }
}
