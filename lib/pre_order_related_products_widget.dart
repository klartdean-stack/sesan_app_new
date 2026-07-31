import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart'; // សម្រាប់ format កាលបរិច្ឆេទ
import 'pre_order_detail_screen.dart';


class PreOrderRelatedProductsWidget extends StatelessWidget {
  final String category;
  final String currentProductId;


  const PreOrderRelatedProductsWidget({
    super.key,
    required this.category,
    required this.currentProductId,
  });


  // ជំនួយ format តម្លៃ
  String formatPrice(dynamic price) {
    if (price == null) return '0';
    final number = double.tryParse(price.toString());
    if (number == null) return price.toString();
    final formatter = NumberFormat('#,###');
    return '${formatter.format(number)} ៛';
  }


  // ជំនួយ format កាលបរិច្ឆេទ (ពេញ)
  String _formatDate(dynamic date) {
    if (date == null) return 'មិនទាន់កំណត់';
    if (date is Timestamp) {
      return DateFormat('dd/MM/yyyy').format(date.toDate());
    }
    return date.toString();
  }


  // ជំនួយ format កាលបរិច្ឆេទ (ខ្លី)
  String _formatShortDate(dynamic date) {
    if (date == null) return '';
    if (date is Timestamp) {
      return DateFormat('dd/MM').format(date.toDate());
    }
    return date.toString();
  }


  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Text(
            "ប្រកាសលក់មុនដទៃទៀត",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'Siemreap',
            ),
          ),
        ),
        StreamBuilder<QuerySnapshot>(
          // ✅ លុប .where('category', ...) ចេញ ព្រោះមិនមាន field category
          stream: FirebaseFirestore.instance
              .collection('pre_orders')
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
                childAspectRatio: MediaQuery.of(context).size.width < 600
                    ? 0.6
                    : 0.8,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: relatedItems.length,
              itemBuilder: (context, index) {
                var item = relatedItems[index].data() as Map<String, dynamic>;
                item['id'] = relatedItems[index].id;


                final String name =
                    item['product_name'] ??
                        item['productName'] ??
                        'មិនមានឈ្មោះ';
                final String price = formatPrice(item['price']);
                final String unit = item['unit'] ?? 'ឯកតា';
                final dynamic createdAt = item['created_at'];
                final dynamic harvestDate = item['harvest_date'];


                // ទាញយករូបភាព
                String imageUrl = '';
                final urls = item['images'] ?? item['image_urls'];
                if (urls is List && urls.isNotEmpty) {
                  imageUrl = urls[0].toString();
                }
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PreOrderDetailScreen(
                          data: item,
                          documentId: relatedItems[index].id,
                        ),
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
                        // រូបភាព
                        Expanded(
                          flex: 1,
                          child: ClipRRect(
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
                        ),
                        // ព័ត៌មាន
                        // ព័ត៌មាន
                        Padding(
                          padding: const EdgeInsets.all(
                            6.0,
                          ), // ✅ បង្រួមពី 10 ទៅ 6
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  color: Colors.black87,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11, // ✅ បង្រួមពី 14 ទៅ 11
                                  fontFamily: 'Siemreap',
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2), // ✅ បង្រួមពី 6 ទៅ 2
                              Text(
                                price,
                                style: TextStyle(
                                  color: Colors.red[700],
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12, // ✅ បង្រួមពី 16 ទៅ 12
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2), // ✅ បង្រួមពី 6 ទៅ 2
                              Text(
                                "/ $unit",
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 10, // ✅ បង្រួមពី 12 ទៅ 10
                                  fontFamily: 'Siemreap',
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4), // ✅ បង្រួមពី 8 ទៅ 4
                              Row(
                                children: [
                                  Icon(
                                    Icons.calendar_month,
                                    size: 10, // ✅ បង្រួមពី 12 ទៅ 10
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(width: 2), // ✅ បង្រួមពី 4 ទៅ 2
                                  Flexible(
                                    // ✅ ប្រើ Flexible ជំនួស Text ធម្មតា ដើម្បីការពារ overflow
                                    child: Text(
                                      "ផុសថ្ងៃ: ${_formatDate(createdAt)}",
                                      style: TextStyle(
                                        color: Colors.grey[500],
                                        fontSize: 9, // ✅ បង្រួមពី 10 ទៅ 9
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              // Badge Pre-order + ថ្ងៃប្រមូលផល
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5, // ✅ បង្រួមពី 8 ទៅ 5
                                      vertical: 1, // ✅ បង្រួមពី 3 ទៅ 1
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade50,
                                      borderRadius: BorderRadius.circular(
                                        3,
                                      ), // ✅ បង្រួមពី 5 ទៅ 3
                                      border: Border.all(
                                        color: Colors.orange.shade200,
                                      ),
                                    ),
                                    child: const Text(
                                      "Pre-order",
                                      style: TextStyle(
                                        color: Colors.orange,
                                        fontSize: 8, // ✅ បង្រួមពី 10 ទៅ 8
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  if (harvestDate != null)
                                    Flexible(
                                      // ✅ ប្រើ Flexible ជំនួស Text ធម្មតា
                                      child: Text(
                                        _formatShortDate(harvestDate),
                                        style: TextStyle(
                                          fontSize: 9, // ✅ បង្រួមពី 10 ទៅ 9
                                          color: Colors.grey[500],
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
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



