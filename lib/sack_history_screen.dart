import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';


class SackHistoryScreen extends StatefulWidget {
  const SackHistoryScreen({super.key});


  @override
  State<SackHistoryScreen> createState() => _SackHistoryScreenState();
}


class _SackHistoryScreenState extends State<SackHistoryScreen> {
  String? userId;
  bool isLoading = true;


  @override
  void initState() {
    super.initState();
    _loadUserId();
  }


  Future<void> _loadUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String uid = prefs.getString('user_uid') ?? '';


      // ✅ Debug — ពិនិត្យ uid ពិតប្រាកដ
      debugPrint('SackHistory UID: "$uid"');


      if (mounted) {
        setState(() {
          userId = uid.isNotEmpty ? uid : null;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Load UID Error: $e');
      if (mounted) setState(() => isLoading = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("ប្រវត្តិថ្លឹងបាវ"),
          backgroundColor: Colors.green[700],
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.green),
              SizedBox(height: 16),
              Text("កំពុងផ្ទុក...", style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }


    if (userId == null || userId!.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("ប្រវត្តិថ្លឹងបាវ"),
          backgroundColor: Colors.green[700],
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.account_circle_outlined,
                size: 80,
                color: Colors.grey[300],
              ),
              const SizedBox(height: 16),
              const Text(
                "សូម Login មុននឹងមើលប្រវត្តិ",
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () async {
                  setState(() => isLoading = true);
                  await _loadUserId();
                },
                icon: const Icon(Icons.refresh),
                label: const Text("ព្យាយាមម្តងទៀត"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }


    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text(
          "ប្រវត្តិថ្លឹងបាវ",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('sack_history')
            .where('seller_id', isEqualTo: userId)
            .orderBy('created_at', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            debugPrint("Stream Error: ${snapshot.error}");
            return _buildErrorWidget(snapshot.error.toString());
          }


          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingWidget();
          }
          final docs = snapshot.data?.docs ?? [];


          if (docs.isEmpty) {
            return _buildEmptyWidget();
          }


          return ListView.builder(
            itemCount: docs.length,
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              try {
                var data = docs[index].data() as Map<String, dynamic>?;
                if (data == null) return const SizedBox.shrink();


                return _ExpandableHistoryCard(data: data, index: index);
              } catch (e) {
                debugPrint("Card build error: $e");
                return const SizedBox.shrink();
              }
            },
          );
        },
      ),
    );
  }


  Widget _buildLoadingWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              color: Colors.green[700],
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            "កំពុងផ្ទុកប្រវត្តិ...",
            style: TextStyle(color: Colors.grey[500], fontSize: 16),
          ),
        ],
      ),
    );
  }


  Widget _buildEmptyWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.inventory_2_outlined,
              size: 60,
              color: Colors.grey[300],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            "មិនទាន់មានប្រវត្តិនៅឡើយ",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "ថ្លឹងបាវដំបូងរបស់អ្នកនឹងបង្ហាញនៅទីនេះ",
            style: TextStyle(fontSize: 14, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }


  Widget _buildErrorWidget(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red[300], size: 80),
            const SizedBox(height: 16),
            const Text(
              "មិនអាចផ្ទុកប្រវត្តិបាន",
              style: TextStyle(fontSize: 18, color: Colors.red),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => setState(() {}),
              icon: const Icon(Icons.refresh),
              label: const Text("ព្យាយាមម្តងទៀត"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700],
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// Custom Expandable Card ជំនួស ExpansionTile - ជៀស overflow
class _ExpandableHistoryCard extends StatefulWidget {
  final Map<String, dynamic> data;
  final int index;


  const _ExpandableHistoryCard({required this.data, required this.index});


  @override
  State<_ExpandableHistoryCard> createState() => _ExpandableHistoryCardState();
}


class _ExpandableHistoryCardState extends State<_ExpandableHistoryCard> {
  bool _isExpanded = false;
  @override
  Widget build(BuildContext context) {
    List<dynamic> sacks = widget.data['sacks_data'] ?? [];
    DateTime? date;


    try {
      if (widget.data['created_at'] != null) {
        date = (widget.data['created_at'] as Timestamp).toDate();
      }
    } catch (e) {
      debugPrint("Date parse error: $e");
    }


    String formattedDate = date != null
        ? DateFormat('dd/MM/yyyy • HH:mm').format(date)
        : "មិនស្គាល់កាលបរិច្ឆេទ";


    String note = widget.data['note']?.toString() ?? "បញ្ជីគ្មានឈ្មោះ";
    int totalSacks = (widget.data['total_sacks'] ?? 0).toInt();
    double totalWeight = (widget.data['total_weight'] ?? 0).toDouble();
    double totalPrice = (widget.data['total_price'] ?? 0).toDouble();
    String currency = widget.data['currency']?.toString() ?? '៛';


    return TweenAnimationBuilder(
      duration: Duration(milliseconds: 300 + (widget.index * 100)),
      tween: Tween<double>(begin: 0, end: 1),
      builder: (context, double value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            children: [
              // Header - Custom InkWell ជំនួស ExpansionTile
              InkWell(
                onTap: () => setState(() => _isExpanded = !_isExpanded),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Leading
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.inventory_2_rounded,
                          color: Colors.green[700],
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),


                      // Title + Subtitle (Expanded ដើម្បីយកកន្លែងដែលនៅសល់)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              note,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  size: 11,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    formattedDate,
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 11,
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


                      const SizedBox(width: 8),


                      // Trailing
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Text(
                          "$totalSacks បាវ",
                          style: TextStyle(
                            color: Colors.green[700],
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),


                      const SizedBox(width: 4),


                      // Expand Icon
                      AnimatedRotation(
                        turns: _isExpanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(Icons.expand_more, color: Colors.grey[400]),
                      ),
                    ],
                  ),
                ),
              ),


              // Expandable Content
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: _buildExpandedContent(
                  sacks: sacks,
                  totalSacks: totalSacks,
                  totalWeight: totalWeight,
                  totalPrice: totalPrice,
                  currency: currency,
                ),
                crossFadeState: _isExpanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 200),
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildExpandedContent({
    required List<dynamic> sacks,
    required int totalSacks,
    required double totalWeight,
    required double totalPrice,
    required String currency,
  }) {
    // ✅ ធ្វើទ្រង់ទ្រាយទម្ងន់ និងតម្លៃឲ្យមានសញ្ញាក្បៀស
    final weightFormatted = NumberFormat('#,###.#').format(totalWeight);
    final priceFormatted = currency == '៛'
        ? NumberFormat('#,###').format(totalPrice)
        : NumberFormat('#,###.##').format(totalPrice);


    return Container(
      width: double.infinity,
      color: const Color(0xFFF8F9FA),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ផ្នែកទម្ងន់បាវលម្អិត
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 20,
                      decoration: BoxDecoration(
                        color: Colors.green[700],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      "ទម្ងន់បាវលម្អិត",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),


                // បាវនីមួយៗ
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: sacks.asMap().entries.map((entry) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.green[200]!,
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withOpacity(0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: Colors.green[700],
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Center(
                              child: Text(
                                "${entry.key + 1}",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "${entry.value} គីឡូ",
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ), // សរុបទាំងអស់
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.green[100]!),
            ),
            child: Column(
              children: [
                _buildSummaryRow(
                  "ចំនួនបាវសរុប",
                  "$totalSacks បាវ",
                  Icons.inventory_2_outlined,
                ),
                const Divider(height: 20),
                // 🎯 ទម្ងន់សរុប (ប្រើ weightFormatted)
                _buildSummaryRow(
                  "ទម្ងន់សរុប",
                  "$weightFormatted គីឡូ",
                  Icons.scale_outlined,
                ),
                const Divider(height: 20),
                // 🎯 ទឹកប្រាក់សរុប (ប្រើ priceFormatted)
                _buildSummaryRow(
                  "ទឹកប្រាក់សរុប",
                  "$priceFormatted $currency",
                  Icons.payments_outlined,
                  isTotal: true,
                ),
              ],
            ),
          ),


          const SizedBox(height: 20),
        ],
      ),
    );
  }


  Widget _buildSummaryRow(
      String label,
      String value,
      IconData icon, {
        bool isTotal = false,
      }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isTotal ? Colors.orange[50] : Colors.green[50],
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: isTotal ? Colors.orange[700] : Colors.green[700],
            size: 18,
          ),
        ),
        const SizedBox(width: 10),


        // 🎯 កែត្រង់នេះ៖ ប្រើ Flexible ជំនួស Expanded ដើម្បីកុំឱ្យវាបុក Space របស់តម្លៃ
        Flexible(
          fit: FlexFit.loose,
          child: Text(
            label,
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),


        const SizedBox(width: 12), // ថែម Space បន្តិចកុំឱ្យវាបុកគ្នាពេក
        // ✅ ផ្នែកតម្លៃដែលមេដាក់ FittedBox គឺល្អហើយ
        // ថែម ConstrainedBox បន្តិចដើម្បីកំណត់ថា យ៉ាងហោចណាស់វាត្រូវយក Space ប៉ុន្មាន
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 80),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              value,
              style: TextStyle(
                color: isTotal ? Colors.orange[700] : Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: isTotal ? 17 : 14, // បើជាសរុប ឱ្យវាធំជាងមុនបន្តិច
              ),
            ),
          ),
        ),
      ],
    );
  }
}



