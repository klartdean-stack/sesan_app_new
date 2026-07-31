import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminTransferRequestsScreen extends StatelessWidget {
  const AdminTransferRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("សំណើសុំផ្ទេរភាគហ៊ុន"),
        backgroundColor: Colors.blueAccent,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // ទាញយកតែសំណើណាដែលមាន Status 'pending' (កំពុងរង់ចាំ)
        stream: FirebaseFirestore.instance
            .collection('transfer_requests')
            .where('status', isEqualTo: 'pending')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("មិនមានសំណើថ្មីឡើយ"));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var request = snapshot.data!.docs[index];
              var data = request.data() as Map<String, dynamic>;

              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 15),
                child: Padding(
                  padding: const EdgeInsets.all(15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(data),
                      const Divider(),
                      _buildRequestDetails(data),
                      const SizedBox(height: 10),
                      _buildEvidenceImage(context, data['agreement_image']),
                      const SizedBox(height: 15),
                      _buildActionButtons(context, request.id, data),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // --- ១. បង្ហាញព័ត៌មានអ្នកផ្ទេរ និងអ្នកទទួល ---
  Widget _buildHeader(Map<String, dynamic> data) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "អ្នកផ្ទេរ (Sender)",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            Text(
              data['sender_name'] ?? "",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const Icon(Icons.arrow_forward, color: Colors.orange),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Text(
              "អ្នកទទួល (Receiver)",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            Text(
              data['receiver_name'] ?? "",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }

  // --- ២. បង្ហាញព័ត៌មានលម្អិតនៃសំណើ ---
  Widget _buildRequestDetails(Map<String, dynamic> data) {
    return Column(
      children: [
        _infoRow("ចំនួនហ៊ុនត្រូវផ្ទេរ:", "${data['amount']} ហ៊ុន", Colors.blue),
        _infoRow(
          "លេខទូរស័ព្ទអ្នកទទួល:",
          data['receiver_phone'] ?? "មិនមាន",
          Colors.black,
        ),
        _infoRow(
          "អត្តសញ្ញាណប័ណ្ណ:",
          data['receiver_id_card'] ?? "មិនមាន",
          Colors.black,
        ),
        if (data['note'] != null && data['note'].toString().isNotEmpty)
          _infoRow("មូលហេតុ:", data['note'], Colors.redAccent),
      ],
    );
  }

  Widget _infoRow(String label, String value, Color valColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: valColor,
            ),
          ),
        ],
      ),
    );
  }

  // --- ៣. បង្ហាញរូបភាពភស្តុតាង (ចុចពង្រីកបាន) ---
  Widget _buildEvidenceImage(BuildContext context, String? imageUrl) {
    if (imageUrl == null) return const Text("គ្មានរូបភាពភស្តុតាង");
    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (c) => Dialog(child: Image.network(imageUrl)),
        );
      },
      child: Container(
        height: 150,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          image: DecorationImage(
            image: NetworkImage(imageUrl),
            fit: BoxFit.cover,
          ),
        ),
        child: const Center(
          child: Icon(Icons.zoom_in, color: Colors.white, size: 40),
        ),
      ),
    );
  }

  // --- ៤. ប៊ូតុង Approve និង Reject ---
  Widget _buildActionButtons(
    BuildContext context,
    String requestId,
    Map<String, dynamic> data,
  ) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => _handleReject(context, requestId),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("បដិសេធ (Reject)"),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton(
            onPressed: () => _handleApprove(context, requestId, data),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text("យល់ព្រម (Approve)"),
          ),
        ),
      ],
    );
  }

  // --- Logic បដិសេធ ---
  Future<void> _handleReject(BuildContext context, String requestId) async {
    await FirebaseFirestore.instance
        .collection('transfer_requests')
        .doc(requestId)
        .update({'status': 'rejected'});
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("បានបដិសេធសំណើ")));
  }

  Future<void> _handleApprove(
    BuildContext context,
    String requestId,
    Map<String, dynamic> data,
  ) async {
    final batch = FirebaseFirestore.instance.batch();

    // ១. បង្កើត Reference ទៅកាន់អ្នកផ្ទេរ (Sender)
    DocumentReference senderRef = FirebaseFirestore.instance
        .collection('shareholders')
        .doc(data['sender_id']);

    // ២. ស្វែងរកអ្នកទទួល (Receiver) តាមរយៈលេខទូរស័ព្ទ
    QuerySnapshot receiverQuery = await FirebaseFirestore.instance
        .collection('shareholders')
        .where('phone', isEqualTo: data['receiver_phone'])
        .limit(1)
        .get();

    if (receiverQuery.docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ រកមិនឃើញគណនីអ្នកទទួលក្នុងប្រព័ន្ធទេ!")),
      );
      return;
    }

    DocumentReference receiverRef = receiverQuery.docs.first.reference;
    int transferAmount = data['amount']; // ចំនួនហ៊ុនដែលត្រូវផ្ទេរ

    try {
      // 執行 Batch Write (ធ្វើការងារទាំងអស់ក្នុងពេលតែមួយ បើបរាជ័យគឺមិនធ្វើទាំងអស់)
      batch.update(senderRef, {
        'total_shares': FieldValue.increment(-transferAmount),
      }); // ដកហ៊ុន
      batch.update(receiverRef, {
        'total_shares': FieldValue.increment(transferAmount),
      }); // បូកហ៊ុន
      batch.update(
        FirebaseFirestore.instance
            .collection('transfer_requests')
            .doc(requestId),
        {'status': 'approved'},
      );

      await batch.commit(); // បញ្ជូនទៅ Firebase

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.green,
          content: Text("✅ ផ្ទេរភាគហ៊ុនជោគជ័យ!"),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("❌ មានបញ្ហា៖ $e")));
    }
  }
}
