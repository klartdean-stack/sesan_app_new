import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'order_service.dart';

class AdminOrderScreen extends StatelessWidget {
  const AdminOrderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    final OrderService orderService = OrderService();

    // ឆែកលេខទូរស័ព្ទ Admin
    if (user?.phoneNumber != '+85511930717' &&
        user?.phoneNumber != '011930717') {
      return Scaffold(
        appBar: AppBar(title: const Text("Access Denied")),
        body: const Center(
          child: Text("សូមទោស! អ្នកមិនមានសិទ្ធិចូលមើល Admin ទេ។"),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          "បញ្ជីកុម្ម៉ង់រង់ចាំការបញ្ជាក់",
          style: TextStyle(fontSize: 18),
        ),
        backgroundColor: Colors.blueAccent,
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: orderService.getPendingOrders(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
            return const Center(child: Text("មិនទាន់មានការកុម្ម៉ង់ថ្មី"));

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 10),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var order =
                  snapshot.data!.docs[index].data() as Map<String, dynamic>;
              var orderId = snapshot.data!.docs[index].id;
              var items = order['items'] as List;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: ExpansionTile(
                  leading: const CircleAvatar(child: Icon(Icons.shopping_cart)),
                  title: Text(
                    "ភ្ញៀវ៖ ${order['customer_name']}",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),

                  // បន្ថែមការបង្ហាញ ID អ្នកលក់ត្រង់នេះមេ!
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "ID អ្នកលក់៖ ${order['seller_id'] ?? 'រកមិនឃើញ'}",
                        style: const TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        "តម្លៃសរុប៖ ${order['total_amount']} ៛",
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Divider(),
                          // បង្ហាញការបែងចែកលុយឱ្យច្បាស់ (Accounting Detail)
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.green[50],
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              children: [
                                _buildMoneyRow(
                                  "៧% របស់ Admin:",
                                  "${order['admin_commission'] ?? 0} ៛",
                                  Colors.green,
                                ),
                                _buildMoneyRow(
                                  "៩៣% ឱ្យអ្នកលក់:",
                                  "${order['seller_earnings'] ?? 0} ៛",
                                  Colors.orange,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 15),
                          _buildInfoRow(
                            Icons.phone,
                            "លេខទូរស័ព្ទអតិថិជន",
                            order['phone_number'] ?? 'គ្មានលេខ',
                          ),
                          _buildInfoRow(
                            Icons.location_on,
                            "អាសយដ្ឋានដឹកជញ្ជូន",
                            order['shipping_address'] ?? 'គ្មានអាសយដ្ឋាន',
                          ),
                          const SizedBox(height: 15),
                          const Text(
                            "📦 ទំនិញដែលបានកុម្ម៉ង់៖",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const Divider(), // ថែមបន្ទាត់កាត់ទទឹងឱ្យមើលទៅស្អាត
                          ...items.map((item) {
                            return Card(
                              elevation: 0,
                              color: Colors.grey[50],
                              margin: const EdgeInsets.symmetric(vertical: 5),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(10),
                                // --- បង្ហាញរូបភាពទំនិញ (ដក const ចេញដើម្បីឱ្យវាទាញរូបបាន) ---
                                leading: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    width: 55,
                                    height: 55,
                                    color: Colors.white,
                                    child: Image.network(
                                      item['image_url']
                                          .toString(), // ទាញរូបចេញពី Firebase
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              const Icon(
                                                Icons.image_not_supported,
                                                color: Colors.grey,
                                              ),
                                      loadingBuilder:
                                          (context, child, loadingProgress) {
                                            if (loadingProgress == null)
                                              return child;
                                            return const Center(
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            );
                                          },
                                    ),
                                  ),
                                ),
                                title: Text(
                                  "• ${item['product_name'] ?? 'ទំនិញ'}", // បង្ហាញឈ្មោះ "វាសកាយដី"
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 5),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.badge,
                                          size: 14,
                                          color: Colors.blue,
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          "ID អ្នកលក់៖ ${order['seller_id'] ?? 'រកមិនឃើញ'}",
                                          style: const TextStyle(
                                            color: Colors.blue,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.phone_android,
                                          size: 14,
                                          color: Colors.green,
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          "លេខអ្នកលក់៖ ${order['seller_phone'] ?? 'គ្មានលេខ'}",
                                          style: const TextStyle(
                                            color: Colors.green,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      "តម្លៃ៖ ${item['price']} ៛ | ចំនួន៖ ${item['quantity']}",
                                      style: TextStyle(
                                        color: Colors.grey[700],
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                          const SizedBox(height: 15),
                          const Text(
                            "🖼 វិក្កយបត្រផ្ទេរប្រាក់៖",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 10),
                          GestureDetector(
                            onTap: () =>
                                _showFullImage(context, order['payment_image']),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(
                                order['payment_image'],
                                height: 200,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (c, e, s) =>
                                    const Icon(Icons.broken_image, size: 50),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              minimumSize: const Size(double.infinity, 50),
                            ),
                            onPressed: () => _confirmPaymentDialog(
                              context,
                              orderService,
                              orderId,
                            ),
                            child: const Text(
                              "បញ្ជាក់ការទទួលប្រាក់ (Confirm)",
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildMoneyRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(
          value,
          style: TextStyle(color: color, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 8),
          Text("$label: $value"),
        ],
      ),
    );
  }

  void _showFullImage(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) =>
          Dialog(child: InteractiveViewer(child: Image.network(imageUrl))),
    );
  }

  void _confirmPaymentDialog(
    BuildContext context,
    OrderService service,
    String orderId,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("បញ្ជាក់ការបង់ប្រាក់"),
        content: const Text("តើអ្នកប្រាកដទេថាបានទទួលប្រាក់រួចរាល់?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("ទេ"),
          ),
          TextButton(
            onPressed: () async {
              await service.confirmPayment(orderId);
              Navigator.pop(context);
              await service.confirmPayment(orderId);
              Navigator.pop(context); // បិទ Dialog

              // ថែមដុំនេះដើម្បីបង្ហាញសារលោតពីខាងក្រោម (Snackbar)
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("✅ បញ្ជាក់ការបង់ប្រាក់ជោគជ័យ!"),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: const Text("បាទ/ចាស", style: TextStyle(color: Colors.green)),
          ),
        ],
      ),
    );
  }

  Widget _buildNoImage() {
    return Container(
      width: 50,
      height: 50,
      color: Colors.grey[200],
      child: const Icon(Icons.image, color: Colors.grey),
    );
  }
}
