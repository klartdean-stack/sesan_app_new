import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_app/admin_dividend_screen.dart';
import 'package:my_app/admin_transfer_requests_screen.dart';
import 'package:my_app/shareholders_list_screen.dart';

class AdminStockManagement extends StatefulWidget {
  const AdminStockManagement({super.key});

  @override
  State<AdminStockManagement> createState() => _AdminStockManagementState();
}

class _AdminStockManagementState extends State<AdminStockManagement> {
  final _priceController = TextEditingController();
  final _sharesController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          title: const Text(
            "Admin Panel - Sesan",
            style: TextStyle(
              color: Colors.black87,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: Colors.white,
          elevation: 0,
          bottom: const TabBar(
            labelColor: Colors.blueAccent,
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(icon: Icon(Icons.pending_actions), text: "សំណើទិញ"),
              Tab(icon: Icon(Icons.settings), text: "កំណត់តម្លៃ/ហ៊ុន"),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.groups_rounded, color: Colors.blueAccent),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ShareholdersListScreen(),
                ),
              ),
            ),
          ],
        ),
        drawer: Drawer(
          child: ListView(
            children: [
              const DrawerHeader(child: Text("Sesan Admin Menu")),
              ListTile(
                leading: const Icon(Icons.swap_horiz, color: Colors.orange),
                title: const Text("សំណើសុំផ្ទេរភាគហ៊ុន"),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AdminTransferRequestsScreen(),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.monetization_on, color: Colors.green),
                title: const Text("ចែកប្រាក់ចំណេញ"),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AdminDividendScreen(),
                  ),
                ),
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildRequestListTab(), // កន្លែង Approve
            _buildStockSettingsTab(), // កន្លែងកែតម្លៃហ៊ុន
          ],
        ),
      ),
    );
  }

  // --- ១. ផ្នែកសម្រាប់ Approve (យកតាមកូដដែលមេពេញចិត្ត) ---
  Widget _buildRequestListTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('investment_requests')
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        var docs = snapshot.data!.docs;
        if (docs.isEmpty)
          return const Center(child: Text("មិនទាន់មានសំណើទិញថ្មីទេ"));

        return ListView.builder(
          padding: const EdgeInsets.all(15),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            var data = docs[index].data() as Map<String, dynamic>;
            String docId = docs[index].id;
            return Card(
              margin: const EdgeInsets.only(bottom: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              child: Padding(
                padding: const EdgeInsets.all(15.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "ឈ្មោះ៖ ${data['name']}",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          "${data['shares']} ហ៊ុន",
                          style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const Divider(),
                    _detailItem(Icons.phone, "លេខទូរស័ព្ទ៖", data['phone']),
                    _detailItem(
                      Icons.payments,
                      "សរុប៖",
                      "${data['total_price']} ៛",
                    ),
                    const SizedBox(height: 10),
                    if (data['receipt_url'] != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          data['receipt_url'],
                          height: 150,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                    const SizedBox(height: 15),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _rejectRequest(docId),
                            child: const Text("បដិសេធ"),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                            ),
                            onPressed: () =>
                                _approveRequest(context, docId, data),
                            child: const Text(
                              "Approve",
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- ២. ផ្នែកសម្រាប់កែតម្លៃ និងចំនួនហ៊ុន (Update ទៅ Firebase 'current') ---
  Widget _buildStockSettingsTab() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('app_equity_stats')
          .doc('current')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        var data = snapshot.data!.data() as Map<String, dynamic>?;

        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _statBox(
                "តម្លៃហ៊ុនបច្ចុប្បន្ន",
                "${data?['price_per_share'] ?? 0} ៛",
                Colors.green,
              ),
              _statBox(
                "ហ៊ុនដែលនៅសល់",
                "${data?['available_shares'] ?? 0} ហ៊ុន",
                Colors.blue,
              ),
              const SizedBox(height: 30),
              TextField(
                controller: _priceController,
                decoration: const InputDecoration(
                  labelText: "បញ្ចូលតម្លៃថ្មី (៛)",
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _sharesController,
                decoration: const InputDecoration(
                  labelText: "បញ្ចូលចំនួនហ៊ុនសរុបថ្មី",
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 25),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () async {
                    await FirebaseFirestore.instance
                        .collection('app_equity_stats')
                        .doc('current')
                        .update({
                          if (_priceController.text.isNotEmpty)
                            'price_per_share': int.parse(_priceController.text),
                          if (_sharesController.text.isNotEmpty)
                            'available_shares': int.parse(
                              _sharesController.text,
                            ),
                        });
                    _priceController.clear();
                    _sharesController.clear();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("✅ បានកែសម្រួលរួចរាល់!")),
                    );
                  },
                  child: const Text("រក្សាទុកការកែប្រែ"),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- Logic សំខាន់ៗ (Approve / Reject) ---
  Future<void> _approveRequest(
    BuildContext context,
    String docId,
    Map<String, dynamic> data,
  ) async {
    String uid = data['user_id'] ?? "";
    int sharesToAdd = int.tryParse(data['shares'].toString()) ?? 0;
    double amountPaid = double.tryParse(data['total_price'].toString()) ?? 0.0;

    WriteBatch batch = FirebaseFirestore.instance.batch();
    try {
      batch.update(
        FirebaseFirestore.instance.collection('investment_requests').doc(docId),
        {'status': 'success', 'approved_at': FieldValue.serverTimestamp()},
      );

      DocumentReference shareholderRef = FirebaseFirestore.instance
          .collection('shareholders')
          .doc(uid);
      // 🎯 នៅក្នុង File Admin កន្លែងចុច Approve
      batch.set(shareholderRef, {
        'name': data['name'],
        'total_shares': FieldValue.increment(sharesToAdd),
        'invested_amount': FieldValue.increment(amountPaid),

        // ⬇️ ថែម Field ទាំងនេះដើម្បីឱ្យផ្ទាំង Detail បង្ហាញព័ត៌មានគ្រប់គ្រាន់
        'phone': data['phone'], // លេខទូរស័ព្ទ
        'id_card': data['id_card'], // អត្តសញ្ញាណប័ណ្ណ
        'address': data['address'], // អាសយដ្ឋាន
        'bank_name': data['bank_name'], // ឈ្មោះធនាគារ
        'bank_account': data['bank_account'], // លេខគណនី
      }, SetOptions(merge: true));
      DocumentReference statsRef = FirebaseFirestore.instance
          .collection('app_equity_stats')
          .doc('current');
      batch.update(statsRef, {
        'available_shares': FieldValue.increment(-sharesToAdd),
      });

      await batch.commit();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.green,
          content: Text("✅ Approve ជោគជ័យ!"),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("❌ បរាជ័យ៖ $e")));
    }
  }

  Future<void> _rejectRequest(String docId) async {
    await FirebaseFirestore.instance
        .collection('investment_requests')
        .doc(docId)
        .update({'status': 'rejected'});
  }

  Widget _detailItem(IconData icon, String label, String? value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(color: Colors.grey)),
        const SizedBox(width: 5),
        Text(value ?? "---"),
      ],
    ),
  );

  Widget _statBox(String label, String value, Color color) => Card(
    child: ListTile(
      title: Text(label),
      trailing: Text(
        value,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
    ),
  );
  // ✅ កូដបង្កើតរូបរាងប៊ូតុង Admin
  Widget _buildAdminButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Card(
      color: const Color(0xFF1E2235),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: Colors.blueAccent),
        title: Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          color: Colors.white24,
          size: 14,
        ),
      ),
    );
  }
}
