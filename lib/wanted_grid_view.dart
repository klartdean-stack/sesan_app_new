import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:my_app/wanted_detail_screen.dart';

class WantedGridView extends StatelessWidget {
  final String searchQuery; // ✅ បន្ថែម
  const WantedGridView({super.key, this.searchQuery = ""}); // ✅ បន្ថែម

  @override
  Widget build(BuildContext context) {
    // 🎯 Filter យកតែផុសក្នុងរង្វង់ ១៥ ថ្ងៃ
    DateTime fifteenDaysAgo = DateTime.now().subtract(const Duration(days: 15));

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('wanted_products')
          .where('createdAt', isGreaterThanOrEqualTo: fifteenDaysAgo)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return const Center(child: Text("មានបញ្ហាភ្ជាប់ទិន្នន័យ"));
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());

        var docs = snapshot.data!.docs;

        // ✅ ត្រងតាម searchQuery (ឈ្មោះផលិតផល)
        if (searchQuery.isNotEmpty) {
          docs = docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final name = (data['productName'] ?? '').toString().toLowerCase();
            final location = (data['location'] ?? '').toString().toLowerCase();
            final query = searchQuery.toLowerCase();
            return name.contains(query) || location.contains(query);
          }).toList();
        }

        if (docs.isEmpty)
          return Center(
            child: Text(
              searchQuery.isNotEmpty
                  ? "រកមិនឃើញការប្រកាសទិញដែលត្រូវនឹង '$searchQuery'"
                  : "មិនទាន់មានការប្រកាសទិញទេ",
              style: const TextStyle(
                color: Colors.grey,
                fontFamily: 'Siemreap',
                fontSize: 14,
              ),
            ),
          );

        return GridView.builder(
          padding: const EdgeInsets.all(10),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: MediaQuery.of(context).size.width > 700 ? 4 : 2,
            childAspectRatio: MediaQuery.of(context).size.width > 700
                ? 0.8
                : 0.75,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            data['id'] = docs[index].id;
            return _buildWantedCard(context, data);
          },
        );
      },
    );
  }

  Widget _buildWantedCard(BuildContext context, Map<String, dynamic> data) {
    // --- Logic គណនាថ្ងៃផុតកំណត់ ---
    DateTime createdAt = (data['createdAt'] as Timestamp).toDate();
    DateTime expiryDate = createdAt.add(const Duration(days: 15));
    Duration remaining = expiryDate.difference(DateTime.now());
    int daysLeft = remaining.inDays;
    String countdownText = daysLeft > 0
        ? "នៅសល់ $daysLeft ថ្ងៃ"
        : "ជិតផុតកំណត់";

    return InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => WantedDetailScreen(data: data),
            ),
          );
        },
        child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: Colors.blue, width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Expanded(
            child: Stack(
            children: [
              Container(
              width: double.infinity,decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(10),
                ),
                image: DecorationImage(
                  image: (data['imageUrls'] != null &&
                      (data['imageUrls'] as List).isNotEmpty)
                      ? NetworkImage(data['imageUrls'][0])
                      : const AssetImage('assets/no_image.png')
                  as ImageProvider,
                  fit: BoxFit.cover,
                ),
              ),
              ),
              Positioned(
                top: 5,
                right: 5,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    countdownText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
            ],
            ),
            ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data['productName'] ?? '',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "📅 ${createdAt.day}/${createdAt.month}/${createdAt.year}",
                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "ត្រូវការ៖ ${data['quantity']} ${data['unit']}",
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        "តម្លៃ៖ ${data['price']} ${data['currency']}",
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "📍 ${data['location']}",
                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ),
    );
  }
}