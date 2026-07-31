import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'admin_actions_service.dart';

class AdminDisputeScreen extends StatefulWidget {
  const AdminDisputeScreen({super.key});

  @override
  State<AdminDisputeScreen> createState() => _AdminDisputeScreenState();
}

class _AdminDisputeScreenState extends State<AdminDisputeScreen> {
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("មជ្ឈមណ្ឌលកាត់ក្ដីបណ្ដឹង"),
        centerTitle: true,
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          _buildSearchField(), // 🔍 របារស្វែងរក
          Expanded(child: _buildDisputeList()), // 📜 បញ្ជីបណ្ដឹង
        ],
      ),
    );
  }

  // --- ១. ផ្នែកស្វែងរក ---
  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: "ស្វែងរកតាមលេខបុង (ឧ: JFYT...)",
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
          filled: true,
          fillColor: Colors.white,
        ),
        onChanged: (value) =>
            setState(() => _searchQuery = value.trim().toUpperCase()),
      ),
    );
  }

  // --- ២. ផ្នែកបញ្ជីបណ្ដឹង ---
  Widget _buildDisputeList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('complaints')
          .orderBy('time', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
          return const Center(child: Text("មិនទាន់មានបណ្ដឹង"));

        var docs = snapshot.data!.docs.where((doc) {
          var d = doc.data() as Map<String, dynamic>;
          return (d['order_id'] ?? "").toString().toUpperCase().contains(
            _searchQuery,
          );
        }).toList();

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) => _buildDisputeCard(docs[index]),
        );
      },
    );
  }

  // --- ៣. កាតបង្ហាញព័ត៌មានបណ្ដឹង (Card) ---
  Widget _buildDisputeCard(DocumentSnapshot doc) {
    var data = doc.data() as Map<String, dynamic>;
    String sId = data['seller_id'] ?? "";

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ExpansionTile(
        title: Text(
          data['product_name'] ?? "គ្មានឈ្មោះទំនិញ",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          "បុង៖ ${data['order_id']} | ស្ថានភាព៖ ${data['status'] ?? 'pending'}",
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- ផ្នែកទី ១: ព័ត៌មានអ្នកលក់ (Seller) ---
                _sectionHeader("🏦 ព័ត៌មានអ្នកលក់", Colors.blue),
                FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('users')
                      .doc(sId)
                      .get(),
                  builder: (context, sellerSnap) {
                    if (sellerSnap.hasData && sellerSnap.data!.exists) {
                      var sData =
                          sellerSnap.data!.data() as Map<String, dynamic>;
                      // បូមយក Key តាម Database មេបេះបិទ (name និង phone)
                      return Column(
                        children: [
                          _infoRow(
                            Icons.store,
                            "ហាង",
                            sData['name'] ?? "ហាងគ្មានឈ្មោះ",
                          ),
                          _infoRow(
                            Icons.phone,
                            "លេខអ្នកលក់",
                            sData['phone'] ?? "គ្មានលេខ",
                          ),
                        ],
                      );
                    }
                    return const Text("កំពុងទាញទិន្នន័យ...");
                  },
                ),
                _buildSellerWallet(sId), // បង្ហាញលុយក្នុង Wallet អ្នកលក់

                const SizedBox(height: 15),

                // --- ផ្នែកទី ២: ព័ត៌មានអ្នកទិញ (Customer) ---
                _sectionHeader("👤 ព័ត៌មានអ្នកប្ដឹង", Colors.green),
                _infoRow(Icons.person, "ឈ្មោះ", data['customer_name']),
                _infoRow(
                  Icons.phone_android,
                  "លេខអ្នកទិញ",
                  data['customer_phone'],
                ),
                _infoRow(
                  Icons.location_on,
                  "អាសយដ្ឋាន",
                  data['shipping_address'],
                ),

                const SizedBox(
                  height: 15,
                ), // --- ផ្នែកទី ៣: មូលហេតុ និងភស្តុតាង ---
                _sectionHeader("⚖️ ភស្តុតាងបណ្ដឹង", Colors.red),
                _infoRow(
                  Icons.warning_amber_rounded,
                  "មូលហេតុ",
                  data['reason'],
                ),
                _infoRow(
                  Icons.description,
                  "ការពន្យល់",
                  data['description'] ?? "គ្មាន",
                ),
                if (data['screenshot_order'] != null &&
                    data['screenshot_order'] != "")
                  _buildEvidenceImage(data['screenshot_order']),

                const SizedBox(height: 20),

                // 🎯 កែជួរ ១៨៨ ដល់ ១៩៣ ឱ្យទៅជាបែបនេះវិញ៖
                _buildActionButtons(
                  sId, // ១. String sId (ប្រើ sId ដែលមេទាញបាននៅជួរ ៩៥)
                  doc.id, // ២. String docId
                  data, // ៣. Map data
                  sId, // ៤. 🎯 ប្តូរពី data['sellerId'] មកជា sId វិញឱ្យចំគោលដៅ
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Widgets បន្ថែមសម្រាប់ជំនួយ UI ---

  Widget _sectionHeader(String title, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
            fontSize: 15,
          ),
        ),
        const Divider(),
      ],
    );
  }

  Widget _infoRow(IconData icon, String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Text("$label: ", style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(value ?? "N/A", overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  Widget _buildSellerWallet(String sId) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(sId)
          .snapshots(),
      builder: (context, userSnap) {
        double balance = 0;
        if (userSnap.hasData && userSnap.data!.exists) {
          balance = (userSnap.data!['balance'] ?? 0).toDouble();
        }
        return Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Wallet អ្នកលក់:",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                "${NumberFormat("#,###").format(balance)} ៛",
                style: const TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEvidenceImage(String url) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: InkWell(
        onTap: () => showDialog(
          context: context,
          builder: (context) =>
              Dialog(child: InteractiveViewer(child: Image.network(url))),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.network(
            url,
            height: 200,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }

  // --- ផ្នែកប៊ូតុងសកម្មភាព ---
  Widget _buildActionButtons(
    String sId,
    String docId,
    Map<String, dynamic> data, // 🎯 data នៅត្រង់នេះ
    String sellerId,
  ) {
    return Wrap(
      spacing: 8.0,
      runSpacing: 8.0,
      alignment: WrapAlignment.center,
      children: [
        _buildSmallButton(
          label: "បង្កកលុយ",
          color: Colors.orange,
          icon: Icons.lock,
          onTap: () async {
            await AdminActionsService.toggleFreeze(sId, true);
            _showSuccessSheet("✅ បានបង្កក់គណនីរួចរាល់");
          },
        ),
        _buildSmallButton(
          label: "ដោះបង្កក់",
          color: Colors.blue,
          icon: Icons.lock_open,
          onTap: () async {
            await AdminActionsService.unfreezeUser(sId);
            _showSuccessSheet("🔓 បានដោះបង្កក់រួចរាល់");
          },
        ),
        // 🎯 កែត្រង់នេះ៖ បោះ data ទៅឱ្យ Function ខាងក្រោម
        _buildSmallButton(
          label: "កាត់លុយ",
          color: Colors.red,
          icon: Icons.remove_circle,
          onTap: () => _showDeductDialog(sId, docId, data),
        ),
        _buildSmallButton(
          label: "រួចរាល់",
          color: Colors.teal,
          icon: Icons.check_circle,
          onTap: () async {
            await AdminActionsService.resolveDispute(docId);
            setState(() {});
            _showSuccessSheet("🎯 បានដោះស្រាយរួចរាល់");
          },
        ),
      ],
    );
  }

  Widget _buildSmallButton({
    required String label,
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: 100, // កំណត់ទំហំឱ្យសមល្មម
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: onTap,
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  void _showSuccessSheet(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  // 🎯 ដាក់តែមួយនេះមក គឺបាត់ក្រហមហ្មងមេ!
  void _showDeductDialog(String sId, String docId, Map<String, dynamic> data) {
    final c = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("កាត់លុយពិន័យ"),
        content: TextField(
          controller: c,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: "ចំនួនលុយ (៛)"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("បោះបង់"),
          ),
          ElevatedButton(
            onPressed: () async {
              double amt = double.tryParse(c.text) ?? 0;
              if (amt > 0) {
                // ✅ បាញ់ orderId ទៅ Service ដើម្បីបិទបុងការពារ Cloud Function
                await AdminActionsService.deductBalance(
                  sellerId: sId,
                  orderId: data['order_id'] ?? "",
                  amount: amt,
                  reason: "ពិន័យលើបណ្ដឹង $docId",
                );
                if (mounted) Navigator.pop(context);
                _showSuccessSheet("✅ កាត់លុយរួចរាល់");
                setState(() {}); // Update UI ឱ្យឃើញលុយថយចុះភ្លាម
              }
            },
            child: const Text("បញ្ជាក់"),
          ),
        ],
      ),
    );
  }
}
