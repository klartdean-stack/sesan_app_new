import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_app/product_detail.dart';
import 'package:my_app/seller_profile_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

class SavedScreen extends StatelessWidget {
  const SavedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SharedPreferences>(
        future: SharedPreferences.getInstance(),
        builder: (context, prefsSnapshot) {
          if (!prefsSnapshot.hasData) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator(color: Colors.green)),
            );
          }

          final String currentUserId =
              prefsSnapshot.data!.getString('user_uid') ?? '';

          return Scaffold(
              appBar: AppBar(
                title: const Text(
                  "ទំនិញរក្សាទុក",
                  style: TextStyle(fontFamily: 'Siemreap'),
                ),
                backgroundColor: Colors.green,
              ),
              body: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('bookmarks')
                      .where('userId', isEqualTo: currentUserId)
                      .orderBy('savedAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError)
                      return const Center(child: Text("មានបញ្ហា!"));
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.data!.docs.isEmpty) {
                      return const Center(
                        child: Text("មិនទាន់មានទំនិញរក្សាទុកនៅឡើយ"),
                      );
                    }

                    return ListView.builder(
                        padding: const EdgeInsets.all(10),
                        itemCount: snapshot.data!.docs.length,
                        itemBuilder: (context, index) {
                          var data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                          String docId = snapshot.data!.docs[index].id;

                          // ✅ ទាញរូបភាពឲ្យត្រឹមត្រូវ
                          String imageUrl = '';
                          if (data['image_urls'] != null && (data['image_urls'] as List).isNotEmpty) {
                            imageUrl = (data['image_urls'] as List).first.toString();
                          } else if (data['image_url'] != null && data['image_url'].toString().isNotEmpty) {
                            imageUrl = data['image_url'].toString();
                          }

                          // ✅ ទាញឈ្មោះ
                          String productName = data['product_name']?.toString() ?? 'គ្មានឈ្មោះ';

                          // ✅ ទាញតម្លៃ
                          String price = data['price']?.toString() ?? '0';
                          String currency = data['currency']?.toString() ?? '៛';

                          // ✅ ទាញឈ្មោះអ្នកលក់
                          String sellerName = data['seller_name']?.toString() ?? 'មិនស្គាល់';
                          String sellerId = data['seller_id']?.toString() ?? '';

                          return Card(
                              elevation: 2,
                              margin: const EdgeInsets.only(bottom: 10),
                              child: ListTile(
                                  leading: ClipRRect(
                                      borderRadius: BorderRadius.circular(5),
                                      child: imageUrl.isNotEmpty
                                          ? CachedNetworkImage(
                                          imageUrl: imageUrl,
                                          width: 60,
                                          height: 60,
                                          fit: BoxFit.cover,
                                          placeholder: (_, __) => Container(color: Colors.grey[200],
                                            child: const Icon(Icons.image),
                                          ),
                                          errorWidget: (_, __, ___) => const Icon(Icons.image),
                              )
                                : Container(
                            width: 60,
                            height: 60,
                            color: Colors.grey[200],
                            child: const Icon(Icons.image),
                          ),
                          ),
                          title: Text(
                          productName,
                          style: const TextStyle(
                          fontFamily: 'Siemreap',
                          fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                          Text(
                          "$price $currency",
                          style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                          ),
                          ),
                          if (sellerName.isNotEmpty)
                          Text(
                          "អ្នកលក់: $sellerName",
                          style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          ),
                          ),
                          ],
                          ),
                          trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                          // ✅ ប៊ូតុងមើលហាង
                          if (sellerId.isNotEmpty)
                          IconButton(
                          icon: const Icon(Icons.store, color: Colors.blue, size: 20),
                          onPressed: () {
                          Navigator.push(
                          context,
                          MaterialPageRoute(
                          builder: (context) => SellerProfileScreen(
                          sellerId: sellerId,
                          sellerName: sellerName,
                          ),
                          ),
                          );
                          },
                          ),
                          // ✅ ប៊ូតុងលុប
                          IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () {
                          FirebaseFirestore.instance
                              .collection('bookmarks')
                              .doc(docId)
                              .delete();
                          },
                          ),
                          ],
                          ),
                          onTap: () {
                          // ✅ បញ្ជូនទិន្នន័យពេញលេញទៅ ProductDetailScreen
                          data['id'] = data['productId'] ?? docId;
                          Navigator.push(
                          context,
                          MaterialPageRoute(
                          builder: (context) => ProductDetailScreen(
                          product: Map<String, dynamic>.from(data),
                          ),
                          ),
                          );
                          },
                          ),
                          );
                        },
                    );
                  },
              ),
          );
        },
    );
  }
}