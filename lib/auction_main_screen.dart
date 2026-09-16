import 'package:get/get.dart';
import 'dart:async';
import 'dart:ui'; // បន្ថែមសម្រាប់ FontFeature.tabularFigures()
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
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
  static const _bg = Color(0xFFF5F7F5);
  static const _card = Colors.white;
  static const _border = Color(0xFFE1E8E2);
  static const _accent = Color(0xFF43A047);
  static const _accentBlue = Color(0xFF2E7D32);
  static const _text = Color(0xFF1F2D24);
  static const _textMuted = Color(0xFF7A847D);
  static const _red = Color(0xFFDA3633);
  static const _gold = Color(0xFFF9A825);

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
      appBar: AppBar(
        backgroundColor: const Color(0xFF388E3C),
        foregroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: const Color(0xFF388E3C),
        title: Text(
          Get.locale?.languageCode == 'en' ? 'Auction' : 'ដេញថ្លៃ',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            fontFamily: 'Siemreap',
          ),
        ),
        actions: [
          IconButton(
            onPressed: () => _showVisionBottomSheet(context),
            icon: const Icon(Icons.info_outline_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final prefs = await SharedPreferences.getInstance();
          if (prefs.getBool('is_guest') == true) {
            if (context.mounted) {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text('សូមចូលប្រើប្រាស់'.tr),
                  content: Text(
                    'ត្រូវចូលប្រើប្រាស់គណនីដើម្បីដាក់ដេញថ្លៃ។'.tr,
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text('មើលសិន'.tr),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.pushNamed(context, '/login');
                      },
                      child: Text('ចូលប្រើ'.tr),
                    ),
                  ],
                ),
              );
            }
            return;
          }
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AuctionAddScreen()),
          );
        },
        backgroundColor: _accent,
        elevation: 4,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text(
          'ដាក់ដេញថ្លៃ'.tr,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontFamily: 'Siemreap',
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('auction_products')
            .where('status', isEqualTo: 'auction')
            .orderBy('created_at', descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: _accentBlue),
            );
          }
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
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD7DED8),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 25),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF43A047).withOpacity(0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: Color(0xFF2E7D32),
                size: 40,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'ចក្ខុវិស័យ និងតម្លៃមរតក'.tr,
              style: const TextStyle(
                color: _text,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                fontFamily: 'Siemreap',
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 15),
            Text(
              'auction_vision_body'.tr,
              textAlign: TextAlign.start,
              style: const TextStyle(
                color: _textMuted,
                fontSize: 14,
                height: 1.8,
                fontFamily: 'Siemreap',
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF43A047),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'យល់ព្រម'.tr,
                  style: const TextStyle(
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
                ),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('auction_products')
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
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: isFinished ? const Color(0xFF616161) : _red,
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
                          isFinished ? 'auction_ended'.tr : 'LIVE',
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
                    data['product_name'] ?? 'auction_unnamed'.tr,
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
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'តម្លៃបច្ចុប្បន្ន'.tr,
                              style: const TextStyle(
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
                                  color: _red,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      _buildCountdown(endTime, isFinished),
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

  Widget _buildCountdown(Timestamp? endTime, bool isFinished) {
    if (endTime == null) return const SizedBox.shrink();
    final remaining = endTime.toDate().difference(DateTime.now());
    if (isFinished || remaining.isNegative) {
      return Text(
        'auction_ended'.tr,
        style: const TextStyle(
          color: _red,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          fontFamily: 'Siemreap',
        ),
      );
    }

    final hours = remaining.inHours;
    final minutes = remaining.inMinutes.remainder(60);
    final seconds = remaining.inSeconds.remainder(60);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
        style: const TextStyle(
          color: _accentBlue,
          fontWeight: FontWeight.bold,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.gavel_rounded, size: 56, color: _accent),
            const SizedBox(height: 14),
            Text(
              'auction_no_items'.tr,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _textMuted,
                fontSize: 14,
                fontFamily: 'Siemreap',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
