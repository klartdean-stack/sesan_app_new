import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'wanted_detail_screen.dart';

class WantedRelatedProductsWidget extends StatelessWidget {
  final String category;
  final String currentProductId;

  const WantedRelatedProductsWidget({
    super.key,
    required this.category,
    required this.currentProductId,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Text(
            "ប្រកាសទិញស្រដៀងគ្នា",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'Siemreap',
            ),
          ),
        ),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('wanted_products')
              .limit(20)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            var relatedItems = snapshot.data!.docs
                .where((doc) => doc.id != currentProductId)
                .toList();

            if (relatedItems.isEmpty) return const SizedBox();

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: MediaQuery.of(context).size.width < 600 ? 2 : 5,
                childAspectRatio: MediaQuery.of(context).size.width < 600 ? 0.7 : 0.8,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: relatedItems.length,
              itemBuilder: (context, index) {
                var item = relatedItems[index].data() as Map<String, dynamic>;
                item['id'] = relatedItems[index].id;

                // យក logic ពី WantedGridView._buildWantedCard
                return _buildWantedCard(context, item);
              },
            );
          },
        ),
      ],
    );
  }

  // ✅ ចម្លង logic ទាំងស្រុងពី WantedGridView._buildWantedCard
  Widget _buildWantedCard(BuildContext context, Map<String, dynamic> data) {
    // --- ១. Logic គណនាថ្ងៃផុតកំណត់ ---
    final createdAt = (data['createdAt'] as Timestamp).toDate();
    final expiryDate = createdAt.add(const Duration(days: 15));
    final remaining = expiryDate.difference(DateTime.now());
    final daysLeft = remaining.inDays;
    final countdownText = daysLeft > 0
        ? "នៅសល់ $daysLeft ថ្ងៃ"
        : "ជិតផុតកំណត់";

    // ទាញរូប
    String imageUrl = '';
    final urls = data['imageUrls'];
    if (urls is List && urls.isNotEmpty) {
      imageUrl = urls[0].toString();
    }

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
                // រូបភាព
                Container(
                width: double.infinity,
                decoration: BoxDecoration(borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(10),
                ),
                  image: DecorationImage(
                    image: imageUrl.isNotEmpty
                        ? CachedNetworkImageProvider(imageUrl)
                        : const AssetImage('assets/no_image.png') as ImageProvider,
                    fit: BoxFit.cover,
                  ),
                ),
                ),
              // Countdown badge
              Positioned(
                top: 5,
                right: 5,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
