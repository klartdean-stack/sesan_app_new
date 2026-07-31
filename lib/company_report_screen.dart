import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CompanyReportScreen extends StatelessWidget {
  const CompanyReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F121F), // ពណ៌ Dark ដូចក្នុង App
      appBar: AppBar(
        title: const Text(
          "របាយការណ៍ក្រុមហ៊ុន",
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // 🎯 ទាញទិន្នន័យពី Collection 'reports'
        stream: FirebaseFirestore.instance
            .collection('reports')
            .orderBy('date', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());

          var reports = snapshot.data!.docs;
          if (reports.isEmpty)
            return const Center(
              child: Text(
                "មិនទាន់មានរបាយការណ៍ថ្មីៗឡើយ",
                style: TextStyle(color: Colors.white54),
              ),
            );

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: reports.length,
            itemBuilder: (context, index) {
              var report = reports[index].data() as Map<String, dynamic>;
              return _buildReportCard(report);
            },
          );
        },
      ),
    );
  }

  Widget _buildReportCard(Map<String, dynamic> data) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2235),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ១. រូបភាពសកម្មភាព ឬ Cover របាយការណ៍
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: Image.network(
              data['image_url'] ?? "https://via.placeholder.com/400x200",
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ២. ចំណងជើង និងកាលបរិច្ឆេទ
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      data['title'] ?? "របាយការណ៍ប្រចាំខែ",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      data['month'] ?? "មីនា 2026",
                      style: const TextStyle(
                        color: Colors.blueAccent,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // ៣. ការរៀបរាប់សង្ខេប
                Text(
                  data['description'] ??
                      "សេចក្តីសង្ខេបនៃលទ្ធផលការងារប្រចាំខែរបស់ក្រុមការងារ SESAN...",
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 13,
                    height: 1.5,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const Divider(color: Colors.white10, height: 25),
                // ៤. ប៊ូតុងអានបន្ថែម ឬ ទាញយក
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        // បើក Link PDF ឬបន្តទៅកាន់ Detail Screen
                      },
                      icon: const Icon(Icons.menu_book, size: 18),
                      label: const Text("អានរបាយការណ៍ពេញ"),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
