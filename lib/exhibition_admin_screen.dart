import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ExhibitionAdminScreen extends StatelessWidget {
  const ExhibitionAdminScreen({super.key});

  void _showZoomableImage(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(10), // ឱ្យវាធំពេញអេក្រង់បន្តិច
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            // 🎯 នេះជា Widget សំខាន់សម្រាប់ Zoom
            InteractiveViewer(
              panEnabled: true, // អាចអូសចុះឡើងបាន
              minScale: 0.5,
              maxScale: 4.0, // ពង្រីកបាន ៤ ដង
              child: Center(child: Image.network(url, fit: BoxFit.contain)),
            ),
            // ប៊ូតុងខ្វែងបិទវិញ
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0B),
      appBar: AppBar(
        title: const Text(
          "ADMIN APPROVAL",
          style: TextStyle(
            letterSpacing: 2,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.transparent,
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // 🎯 ទាញទិន្នន័យពីសំណើដែលកំពុងរង់ចាំ (Pending Requests)
        stream: FirebaseFirestore.instance
            .collection('exhibition_requests')
            .orderBy('created_at', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;

              return Card(
                color: const Color(0xFF1C1C1E),
                margin: const EdgeInsets.only(bottom: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ១. បង្ហាញរូបផលិតផល និងរូបវិក្កយបត្រក្បែរគ្នា
                      Row(
                        children: [
                          _buildImagePreview(
                            context,
                            "រូបផលិតផល",
                            data['image_url'],
                          ),
                          const SizedBox(width: 10),
                          _buildImagePreview(
                            context,
                            "វិក្កយបត្រ",
                            data['payment_image_url'] ?? '',
                          ), // 🎯 មេត្រូវបាញ់រូបបង់លុយមកឈ្មោះ Field នេះ
                        ],
                      ),
                      const SizedBox(height: 15),

                      // ២. ព័ត៌មានអ្នកស្នើសុំ
                      Text(
                        "ទំនិញ៖ ${data['product_name']}",
                        style: const TextStyle(
                          color: Colors.pinkAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        "អ្នកស្នើ៖ ${data['customer_name']}",
                        style: const TextStyle(color: Colors.white70),
                      ),
                      Text(
                        "លេខទូរស័ព្ទ៖ ${data['customer_phone']}",
                        style: const TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "កញ្ចប់៖ ${data['selected_package']}",
                        style: const TextStyle(color: Colors.amber),
                      ),

                      const Divider(color: Colors.white12, height: 25),

                      // ៣. ប៊ូតុងចាត់ការ
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: () =>
                                  _approveRequest(context, doc.id, data),
                              child: const Text(
                                "យល់ព្រម (Approve)",
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.redAccent,
                            ),
                            onPressed: () => FirebaseFirestore.instance
                                .collection('exhibition_requests')
                                .doc(doc.id)
                                .delete(),
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
      ),
    );
  } // 🖼️ Widget សម្រាប់បង្ហាញរូបភាពតូចៗ

  Widget _buildImagePreview(BuildContext context, String label, String url) {
    return GestureDetector(
      // 🎯 ហៅមុខងារ Zoom ពេលអ្នកប្រើចុចលើរូប
      onTap: () => _showZoomableImage(context, url),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white38, fontSize: 10),
          ),
          const SizedBox(height: 5),
          Container(
            height: 100,
            width: 120,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: Colors.black26,
              image: DecorationImage(
                image: NetworkImage(url),
                fit: BoxFit.cover,
              ),
            ),
            // បង្ហាញ Icon បើទាញរូបមិនបាន
            child: url.isEmpty
                ? const Icon(Icons.image_not_supported, color: Colors.white10)
                : null,
          ),
        ],
      ),
    );
  }

  // 🚀 មុខងារចម្លងទិន្នន័យទៅ Collection 'products' ដើម្បីឱ្យបង្ហាញក្នុងទស្សនាវដ្តី
  Future<void> _approveRequest(
    BuildContext context,
    String requestId,
    Map<String, dynamic> data,
  ) async {
    try {
      await FirebaseFirestore.instance.collection('products').add({
        "product_name": data['product_name'],
        "image_url": data['image_url'],
        "status": "exhibition", // 🎯 ប្តូរ Status ឱ្យត្រូវជាមួយកូដ Magazine
        "created_at": FieldValue.serverTimestamp(),
      });
      // លុបសំណើចេញពីតារាងរង់ចាំក្រោយពេល Approve រួច
      await FirebaseFirestore.instance
          .collection('exhibition_requests')
          .doc(requestId)
          .delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ បានយល់ព្រម និងដាក់តាំងពិព័រណ៍រួចរាល់")),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("❌ Error: $e")));
    }
  }
}
