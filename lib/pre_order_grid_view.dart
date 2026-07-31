import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'pre_order_detail_screen.dart';

class PreOrderGridView extends StatelessWidget {
  final String searchQuery; // ✅ បន្ថែម
  const PreOrderGridView({super.key, this.searchQuery = ""}); // ✅ បន្ថែម

  // ✅ static final - បង្កើតតែម្តង
  static final formatter = NumberFormat('#,###');

  bool isExpired(dynamic harvestDateData) {
    if (harvestDateData == null) return false;

    DateTime harvestDate;
    if (harvestDateData is Timestamp) {
      harvestDate = harvestDateData.toDate();
    } else {
      return false;
    }

    return DateTime.now().isAfter(harvestDate.add(const Duration(days: 1)));
  }

  // ✅ Format តម្លៃដោយកាត់ .0
  String formatPrice(dynamic price) {
    if (price == null) return '0';
    int priceInt = (price is double) ? price.toInt() : (price as num).toInt();
    return '${formatter.format(priceInt)} ៛';
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        // ✅ Info Card នៅខាងលើ
        SliverToBoxAdapter(child: _buildInfoCard(context)),
        // ✅ GridView ដែលឥឡូវប្រើជា SliverGrid
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('pre_orders')
              .orderBy('created_at', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SliverToBoxAdapter(
                child: Center(child: CircularProgressIndicator()),
              );
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return SliverFillRemaining(child: _buildEmptyState());
            }

            // ✅ ត្រងតាមលក្ខខណ្ឌ៖ មិនផុតកំណត់ និងត្រូវតាម searchQuery
            var docs = snapshot.data!.docs.where((doc) {
              var data = doc.data() as Map<String, dynamic>;
              // 1. មិនរាប់បញ្ចូលដែលផុតកំណត់
              if (isExpired(data['harvest_date'])) return false;
              // 2. ✅ ត្រងតាម searchQuery (ឈ្មោះផលិតផល)
              if (searchQuery.isNotEmpty) {
                final name = (data['product_name'] ?? '').toString().toLowerCase();
                return name.contains(searchQuery.toLowerCase());
              }
              return true;
            }).toList();

            if (docs.isEmpty) {
              return SliverFillRemaining(child: _buildEmptyState());
            }

            // ✅ SliverGrid
            return SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: MediaQuery.of(context).size.width > 700 ? 4 : 2,
                childAspectRatio: 0.7,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              delegate: SliverChildBuilderDelegate((context, index) {
                var data = docs[index].data() as Map<String, dynamic>;
                String docId = docs[index].id;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: _buildPreOrderCard(context, data, docId),
                );
              }, childCount: docs.length),
            );
          },
        ),
      ],
    );
  }

  Widget _buildInfoCard(BuildContext context) {
    return Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.orange.shade700, Colors.orange.shade400],
            ),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [BoxShadow(
              color: Colors.orange.withOpacity(0.3),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
            ],
        ),
      child: Row(
        children: [
          const Icon(Icons.auto_graph_rounded, color: Colors.white, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "យល់ដឹងពីមុខងារ 'លក់មុន'",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    fontFamily: 'Siemreap',
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "ផ្ដល់ឱកាសឱ្យម្ចាស់ចម្ការបង្កើតការលក់ទុកជាមុន ដើម្បីធានាទីផ្សារ និងការកក់ពីអតិថិជនយ៉ាងច្បាស់លាស់",
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 10,
                    fontFamily: 'Siemreap',
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 4),
                TextButton(
                  onPressed: () => _showBenefitDialog(context),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    "🔍 អានបន្ថែម",
                    style: TextStyle(
                      color: Colors.orange,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showBenefitDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "អត្ថប្រយោជន៍នៃការលក់មុន (Pre-order)",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _benefitItem(
                Icons.account_balance_wallet_rounded,
                "យុទ្ធសាស្ត្រសម្រាប់ម្ចាស់អាជីវកម្ម",
                "កាត់បន្ថយហានិភ័យនៃតុល្យភាពទីផ្សារ (Market Risk) ធានាបាននូវលំហូរទុនបង្វិល និងបង្កើនប្រសិទ្ធភាពក្នុងការគ្រប់គ្រងស្ដុកកសិផល។",
              ),
              _benefitItem(
                Icons.hub_rounded,
                "ដំណោះស្រាយសម្រាប់ម្ចាស់គម្រោង",
                "ពង្រឹងខ្សែចង្វាក់ផ្គត់ផ្គង់ (Supply Chain) ឱ្យមានស្ថេរភាព និងបង្កើតអំណាចចរចាទីផ្សារទុកជាមុនជូនដល់សមាជិកក្នុងបណ្ដាញផលិតកម្ម។",
              ),
              _benefitItem(
                Icons.stars_rounded,
                "អត្ថប្រយោជន៍សម្រាប់អតិថិជន",
                "ទទួលបានតម្លៃយុទ្ធសាស្ត្រ (Competitive Price) ធានាបាននូវប្រភពទំនិញពិតប្រាកដ និងកាត់បន្ថយភាពមិនច្បាស់លាស់នៃតម្លៃនៅលើទីផ្សារ។",
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("បិទ", style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }Widget _benefitItem(IconData icon, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.orange, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  desc,
                  style: const TextStyle(fontSize: 12, color: Colors.black87),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ✅ កាតបង្ហាញទំនិញ
  Widget _buildPreOrderCard(
      BuildContext context,
      Map<String, dynamic> data,
      String docId,
      ) {
    List<dynamic> images = data['images'] ?? [];
    String? firstImage = images.isNotEmpty ? images[0] : null;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              PreOrderDetailScreen(data: data, documentId: docId),
        ),
      ),
      child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
          Expanded(
          child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
      child: firstImage != null
          ? Image.network(
        firstImage,
        fit: BoxFit.cover,
        width: double.infinity,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                  loadingProgress.expectedTotalBytes!
                  : null,
              strokeWidth: 2,
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) => Container(
          color: Colors.grey[200],
          child: const Icon(
            Icons.broken_image,
            color: Colors.grey,
            size: 40,
          ),
        ),
      )
          : Container(
        color: Colors.grey[200],
        child: const Icon(
          Icons.image,
          color: Colors.grey,
          size: 40,
        ),
      ),
    ),
    ),
    Padding(
    padding: const EdgeInsets.all(10.0),
    child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
    Text(data['product_name'] ?? 'មិនមានឈ្មោះ',
      style: const TextStyle(
        color: Colors.black87,
        fontWeight: FontWeight.bold,
        fontSize: 14,
        fontFamily: 'Siemreap',
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    ),
      const SizedBox(height: 6),
      Text(
        formatPrice(data['price']),
        style: TextStyle(
          color: Colors.red[700],
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
      const SizedBox(height: 6),
      Text(
        "/ ${data['unit'] ?? 'ឯកតា'}",
        style: TextStyle(
          color: Colors.grey[600],
          fontSize: 12,
          fontFamily: 'Siemreap',
        ),
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Icon(
            Icons.calendar_month,
            size: 12,
            color: Colors.grey[400],
          ),
          const SizedBox(width: 4),
          Text(
            "ផុសថ្ងៃ: ${_formatDate(data['created_at'])}",
            style: TextStyle(color: Colors.grey[500], fontSize: 10),
          ),
        ],
      ),
      Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 3,
            ),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: const Text(
              "Pre-order",
              style: TextStyle(
                color: Colors.orange,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Spacer(),
          if (data['harvest_date'] != null)
            Text(
              _formatShortDate(data['harvest_date']),
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[500],
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
  }

  String _formatShortDate(dynamic dateData) {
    if (dateData is Timestamp) {
      return DateFormat('dd/MM').format(dateData.toDate());
    }
    return '';
  }

  String _formatDate(dynamic dateData) {
    if (dateData is Timestamp) {
      return DateFormat('dd/MM/yyyy').format(dateData.toDate());
    }
    return '---';
  }

  Widget _buildEmptyState() {
    return LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,children: [
                        Icon(
                          Icons.hourglass_empty_rounded,
                          size: 50,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          searchQuery.isNotEmpty
                              ? "រកមិនឃើញការលក់មុនដែលត្រូវនឹង '$searchQuery'"
                              : "មិនទាន់មានការប្រកាសលក់មុននៅឡើយទេ",
                          style: const TextStyle(
                            color: Colors.grey,
                            fontFamily: 'Siemreap',
                            fontSize: 14,
                          ),
                        ),
                      ],
                      ),
                  ),
              ),
          );
        },
    );
  }
}