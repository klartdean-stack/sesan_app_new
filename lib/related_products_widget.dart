import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'product_detail.dart';


class RelatedProductsWidget extends StatefulWidget {
  final String category;
  final String currentProductId;


  const RelatedProductsWidget({
    super.key,
    required this.category,
    required this.currentProductId,
  });


  @override
  State<RelatedProductsWidget> createState() => _RelatedProductsWidgetState();
}


class _RelatedProductsWidgetState extends State<RelatedProductsWidget> {
  String? _currentUserId;


  @override
  void initState() {
    super.initState();
    _loadUserId();
  }


  Future<void> _loadUserId() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        _currentUserId = user.uid;
      } else {
        final prefs = await SharedPreferences.getInstance();
        _currentUserId = prefs.getString('user_uid');
      }
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint("Error loading UID: $e");
    }
  }


  // ── ADD TO CART (Logic ដូច product_list.dart) ────────────────
  Future<void> _fastAddToCart(Map<String, dynamic> product) async {
    if (_currentUserId == null) return;


    final String finalImageUrl =
        product['image_url'] ??
            (product['image_urls'] != null &&
                (product['image_urls'] as List).isNotEmpty
                ? product['image_urls'][0]
                : "");


    try {
      await FirebaseFirestore.instance.collection('carts').add({
        'product_id': product['id'] ?? '',
        'product_name': product['product_name'] ?? 'គ្មានឈ្មោះ',
        'price': product['price'] ?? 0,
        'currency': product['currency'] ?? '៛',
        'image_url': finalImageUrl,
        'quantity': 1,
        'customer_id': _currentUserId,
        'created_at': FieldValue.serverTimestamp(),
        'seller_id': product['seller_id'] ?? '',
        'seller_name': product['seller_name'] ?? 'អាជីវករ សេសាន',
        'seller_phone': product['seller_phone'] ?? product['phone1'] ?? '',
        'seller_photo': product['seller_photo'] ?? '',
      });


      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✅ បន្ថែមទៅកន្ត្រករួចរាល់!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint("Add to Cart Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("❌ បរាជ័យ: $e")));
      }
    }
  }


  // ── FORMAT TIME AGO ─────────────────────────────────────
  String _formatTimeAgo(dynamic timestamp) {
    if (timestamp == null) return "មុននេះបន្តិច";


    DateTime date;
    if (timestamp is Timestamp) {
      date = timestamp.toDate();
    } else if (timestamp is DateTime) {
      date = timestamp;
    } else {
      return "មុននេះបន្តិច";
    }


    final Duration diff = DateTime.now().difference(date);


    if (diff.inMinutes < 1) return "មុននេះបន្តិច";
    if (diff.inMinutes < 60) return "${diff.inMinutes} នាទីមុន";
    if (diff.inHours < 24) return "${diff.inHours} ម៉ោងមុន";
    if (diff.inDays < 7) return "${diff.inDays} ថ្ងៃមុន";
    return "${date.day}/${date.month}/${date.year}";
  }


  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Text(
            "ទំនិញស្រដៀងគ្នា",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('products')
              .where('category', isEqualTo: widget.category)
              .limit(20)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData)
              return const Center(child: CircularProgressIndicator());


            var relatedItems = snapshot.data!.docs
                .where((doc) => doc.id != widget.currentProductId)
                .toList();


            if (relatedItems.isEmpty) return const SizedBox();


            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: MediaQuery.of(context).size.width < 600 ? 2 : 5,
                childAspectRatio: MediaQuery.of(context).size.width < 600
                    ? 0.7
                    : 0.8,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: relatedItems.length,
              itemBuilder: (context, index) {
                var item = relatedItems[index].data() as Map<String, dynamic>;
                item['id'] = relatedItems[index].id;


                final String name = item['product_name'] ?? 'គ្មានឈ្មោះ';
                final String price = (item['price'] ?? '0').toString();
                final String location = (item['location'] ?? 'ភ្នំពេញ')
                    .toString();
                final dynamic timestamp = item['created_at'];
                final bool isLocked = item['is_locked'] ?? false;


                String imageUrl = "";
                final urls = item['image_urls'];
                if (urls is List && urls.isNotEmpty) {
                  imageUrl = urls[0].toString();
                } else if (item['image_url'] != null) {
                  imageUrl = item['image_url'].toString();
                }


                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            ProductDetailScreen(product: item),
                      ),
                    );
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 🖼 រូបភាព
                        // 🖼 រូបភាព (មាន Verified Badge និង Play Icon)
                        Expanded(
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(12),
                                ),
                                child: imageUrl.isNotEmpty
                                    ? CachedNetworkImage(
                                  imageUrl: imageUrl,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) =>
                                      Container(color: Colors.grey[100]),
                                  errorWidget: (context, url, error) =>
                                  const Icon(
                                    Icons.broken_image,
                                    color: Colors.grey,
                                  ),
                                )
                                    : Container(
                                  color: Colors.grey[100],
                                  child: const Icon(
                                    Icons.image_not_supported,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                              // ✅ Verified Badge (ដូច ProductGridView)
                              if (item['shop_tier'] != null &&
                                  (item['shop_tier'] == 'basic' ||
                                      item['shop_tier'] == 'premium'))
                                Positioned(
                                  bottom: 4,
                                  left: 4,
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      color: item['shop_tier'] == 'premium'
                                          ? Colors.amber.withOpacity(0.8)
                                          : Colors.blueAccent.withOpacity(0.8),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      item['shop_tier'] == 'premium'
                                          ? Icons.diamond_rounded
                                          : Icons.verified_user_rounded,
                                      color: Colors.white,
                                      size: 14,
                                    ),
                                  ),
                                ),
                              // ✅ Play Icon (ដូច ProductGridView)
                              if (item['video_url'] != null &&
                                  item['video_url'].toString().isNotEmpty)
                                Positioned(
                                  bottom: 4,
                                  right: 4,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    padding: const EdgeInsets.all(4),
                                    child: const Icon(
                                      Icons.play_arrow_rounded,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),


                        // 📝 ព័ត៌មាន
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ឈ្មោះ
                              Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  fontFamily: 'Siemreap',
                                ),
                              ),
                              const SizedBox(height: 4),


                              // ✅ កាលបរិច្ឆេទ និងទីតាំង
                              Row(
                                children: [
                                  const Icon(
                                    Icons.access_time,
                                    size: 10,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    _formatTimeAgo(timestamp),
                                    style: const TextStyle(
                                      fontSize: 9,
                                      color: Colors.grey,
                                      fontFamily: 'Siemreap',
                                    ),
                                  ),
                                  const Text(
                                    " • ",
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      location,
                                      style: const TextStyle(
                                        fontSize: 9,
                                        color: Colors.grey,
                                        fontFamily: 'Siemreap',
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),


                              const SizedBox(height: 6),


                              // ✅ តម្លៃ និងប៊ូតុងកន្ត្រក
                              Row(
                                mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "$price ៛",
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  // ✅ ប៊ូតុង Add to Cart
                                  GestureDetector(
                                    onTap: isLocked
                                        ? null
                                        : () => _fastAddToCart(item),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: isLocked
                                            ? Colors.grey[200]
                                            : Colors.green[50],
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        Icons.add_shopping_cart,
                                        color: isLocked
                                            ? Colors.grey
                                            : Colors.green,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}



