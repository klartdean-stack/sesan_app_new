import 'dart:async';
import 'dart:ui'; // បន្ថែមសម្រាប់ FontFeature.tabularFigures()
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:my_app/luxury_appbar_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auction_detail_screen.dart';
import 'auction_add_screen.dart';


class AuctionMainScreen extends StatefulWidget {
  const AuctionMainScreen({super.key});


  @override
  State<AuctionMainScreen> createState() => _AuctionMainScreenState();
}


class _AuctionMainScreenState extends State<AuctionMainScreen>
    with TickerProviderStateMixin {
  // ── Config ──────────────────
  static const _adminId = 'WBdQVvrgEIPBTcgIlumu6bAZGUl2';


  // ── Theme ──────────────────
  static const _bg = Color(0xFF0D1117);
  static const _card = Color(0xFF161B22);
  static const _border = Color(0xFF30363D);
  static const _accent = Color(0xFF238636);
  static const _accentBlue = Color(0xFF1F6FEB);
  static const _text = Color(0xFFE6EDF3);
  static const _textMuted = Color(0xFF8B949E);
  static const _red = Color(0xFFDA3633);
  static const _gold = Color(0xFFFFB300);


  late Timer _timer;


  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }


  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }




  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;


    return Scaffold(
      backgroundColor: _bg,
      // ── ១. Appbar តុបតែងថ្មី ──────────────────
      // ── ហៅប្រើ AppBar ថ្មីរបស់បងនៅទីនេះ ──
      appBar: buildLuxuryAppBar(
        context,
            () => _showVisionBottomSheet(
          context,
        ), // ហៅ Function បង្ហាញ BottomSheet ដែលយើងធ្វើហើយ
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final prefs = await SharedPreferences.getInstance();
          if (prefs.getBool('is_guest') == true) {
            if (context.mounted) {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text("សូមចូលប្រើប្រាស់"),
                  content: const Text(
                    "ត្រូវចូលប្រើប្រាស់គណនីដើម្បីដាក់ដេញថ្លៃ។",
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text("មើលសិន"),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.pushNamed(context, '/login');
                      },
                      child: const Text("ចូលប្រើ"),
                    ),
                  ],
                ),
              );
            }
            return;
          }
          // បើមិនមែនភ្ញៀវ ទើបទៅទម្រង់
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AuctionAddScreen()),
          );
        },
        backgroundColor: _accent,
        elevation: 4,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'ដាក់ដេញថ្លៃ',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontFamily: 'Siemreap',
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection(
          'auction_products',
        ) // 🎯 ប្តូរមកកាន់ Collection ថ្មីសម្រាប់របស់ដេញថ្លៃ
            .where(
          'status',
          isEqualTo: 'auction',
        ) // 🎯 យកតែរបស់ណាដែល Admin បានចុច Approve រួចរាល់
            .orderBy('created_at', descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (!snap.hasData)
            return const Center(
              child: CircularProgressIndicator(color: _accentBlue),
            );
          final docs = snap.data!.docs;
          if (docs.isEmpty) return _buildEmptyState();


          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            itemCount: docs.length,
            itemBuilder: (ctx, i) {
              final data = docs[i].data() as Map<String, dynamic>;
              return _buildAuctionCard(context, docs[i].id, data, currentUser);
            },
          );
        },
      ),
    );
  }




  void _showVisionBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors
          .transparent, // ធ្វើឱ្យផ្ទៃខាងក្រោយថ្លាដើម្បីប្រើ Container តុបតែង
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1C2128), // ពណ៌ប្រផេះចាស់បែប GitHub Dark
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // បន្ទាត់តូចខាងលើ (Handle bar)
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 25),


            // រូប Icon ដែលមានពន្លឺជុំវិញ
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFB300).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: Color(0xFFFFB300),
                size: 40,
              ),
            ),
            const SizedBox(height: 20),


            // ចំណងជើង
            const Text(
              'ចក្ខុវិស័យ និងតម្លៃមរតក',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                fontFamily: 'Siemreap',
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 15),


            // អត្ថបទរៀបរាប់ (រៀបឃ្លាឱ្យមានគម្លាតស្រួលអាន)
            // ក្នុង Column នៃ BottomSheet
            Text(
              "រាល់ទំនិញដែលដាក់ដេញថ្លៃនៅទីនេះ សុទ្ធតែមានតម្លៃ និងរឿងរ៉ាវរៀងៗខ្លួន។ ចាប់តាំងពីឧបករណ៍កសិកម្មបុរាណដែលបន្សល់ពីដូនតា រហូតដល់គ្រឿងចក្រទំនើបៗ ត្រាក់ទ័រ ឡាន ម៉ូតូ ទូរស័ព្ទ និងឧបករណ៍អេឡិចត្រូនិកជាច្រើនទៀត។\n\n"
                  "យើងបង្កើតវេទិកាដេញថ្លៃនេះឡើង ដើម្បីផ្តល់ឱកាសឱ្យអ្នកលក់អាចទទួលបានតម្លៃសមរម្យ និងអ្នកទិញអាចស្វែងរកទំនិញដែលខ្លួនត្រូវការក្នុងតម្លៃដែលខ្លួនពេញចិត្ត។\n\n"
                  "មិនថាទំនិញថ្មី ឬមួយទឹក គ្រឿងបន្លាស់ ឬគ្រឿងចក្រធំៗ អ្នកអាចដាក់ដេញថ្លៃបានទាំងអស់នៅលើវេទិកាសេសាន។ សូមចូលរួមដេញថ្លៃដោយសុវត្ថិភាព និងតម្លាភាព។",
              textAlign: TextAlign.start,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 14,
                height: 1.8, // ដាក់ឱ្យទូលាយស្រឡះភ្នែក
                fontFamily: 'Siemreap',
              ),
            ),
            const SizedBox(height: 30),


            // ប៊ូតុងបិទ (ធ្វើឱ្យមើលទៅពេញលក្ខណៈ)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF238636),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'យល់ព្រម',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Siemreap',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }


  Widget _buildAuctionCard(
      BuildContext context,
      String docId,
      Map<String, dynamic> data,
      User? currentUser,
      ) {
    final fmt = NumberFormat('#,###');
    final currentPrice =
        int.tryParse(data['current_price']?.toString() ?? '0') ?? 0;
    final endTime = data['end_time'] as Timestamp?;
    final isFinished =
        endTime != null && endTime.toDate().isBefore(DateTime.now());
    final images = (data['image_urls'] as List?) ?? [];
    final imageUrl = images.isNotEmpty ? images[0].toString() : '';


    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AuctionDetailScreen(productId: docId),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _border),
        ),
        child: Column(
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(19),
                  ),
                  child: imageUrl.isEmpty
                      ? Container(
                    height: 180,
                    color: _bg,
                    child: const Icon(Icons.image, color: _textMuted),
                  )
                      : CachedNetworkImage(
                    imageUrl: imageUrl,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ), // ── ៤. បង្ហាញ Viewer Count ──────────────────
                // ── ៤. បង្ហាញ Viewer Count ──────────────────
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection(
                    'auction_products',
                  ) // 🎯 ប្តូរផ្លូវ Sub-collection ឱ្យមកតាមដានក្នុងរបស់ដេញថ្លៃវិញ
                      .doc(docId)
                      .collection('viewers')
                      .snapshots(),
                  builder: (context, vSnap) {
                    final count = vSnap.hasData ? vSnap.data!.docs.length : 0;
                    if (count == 0) return const SizedBox();
                    return Positioned(
                      bottom: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.visibility,
                              color: Colors.white,
                              size: 12,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$count',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                // Status Badge
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: isFinished ? _border : _red,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isFinished ? Icons.lock : Icons.circle,
                          size: 7,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          isFinished ? 'ចប់ហើយ' : 'LIVE',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data['product_name'] ?? 'គ្មានឈ្មោះ',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _text,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Siemreap',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      // ── ៣. បង្រួមតម្លៃឱ្យតូច (FittedBox) ──────────────────
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'តម្លៃបច្ចុប្បន្ន',
                              style: TextStyle(
                                color: _textMuted,
                                fontSize: 10,
                                fontFamily: 'Siemreap',
                              ),
                            ),
                            const SizedBox(height: 2),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                '${fmt.format(currentPrice)} ៛',
                                style: const TextStyle(
                                  color: _accent,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildTimer(endTime),
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


  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.gavel_rounded,
            size: 64,
            color: _textMuted.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            'មិនទាន់មានការដេញថ្លៃនៅឡើយទេ',
            style: TextStyle(color: _textMuted, fontFamily: 'Siemreap'),
          ),
        ],
      ),
    );
  }


  Widget _buildTimer(dynamic endTime) {
    if (endTime == null) return const SizedBox();
    final end = (endTime as Timestamp).toDate();
    final remaining = end.difference(DateTime.now());
    final finished = remaining.isNegative;
    final urgent = !finished && remaining.inMinutes < 30;


    if (finished) return const SizedBox();


    final h = remaining.inHours;
    final m = remaining.inMinutes % 60;
    final s = remaining.inSeconds % 60;
    final color = urgent ? _red : _accentBlue;


    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}',
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}


// ── Rule Item Widget ───────────────────────────────────────────────
class _RuleItem extends StatelessWidget {
  final String number;
  final String title;
  final String desc;
  final Color color;


  const _RuleItem({
    required this.number,
    required this.title,
    required this.desc,
    required this.color,
  });


  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Siemreap',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: const TextStyle(
                    color: Color(0xFF8B949E),
                    fontSize: 13,
                    height: 1.5,
                    fontFamily: 'Siemreap',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}



