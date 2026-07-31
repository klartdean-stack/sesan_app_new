import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart'; // នាំចូល package ថ្មី

class AuctionAdminScreen extends StatelessWidget {
  const AuctionAdminScreen({super.key});

  static const _bg = Color(0xFF0D1117);
  static const _card = Color(0xFF161B22);
  static const _border = Color(0xFF30363D);
  static const _accent = Color(0xFF238636);
  static const _accentBlue = Color(0xFF1F6FEB);
  static const _text = Color(0xFFE6EDF3);
  static const _textMuted = Color(0xFF8B949E);
  static const _red = Color(0xFFDA3633);
  static const _gold = Color(0xFFFFB300);

  void _showZoomImage(BuildContext context, List images, {String? videoUrl}) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            // ផ្នែកអូសមើលរូបភាព
            PageView.builder(
              itemCount: images.length,
              itemBuilder: (context, index) {
                return InteractiveViewer(
                  child: CachedNetworkImage(
                    imageUrl: images[index],
                    fit: BoxFit.contain,
                  ),
                );
              },
            ),

            // ── ប៊ូតុងសម្រាប់មើលវីដេអូ (បង្ហាញតែពេលមាន Link វីដេអូ) ──
            if (videoUrl != null && videoUrl.isNotEmpty)
              Positioned(
                bottom: 60,
                left: 0,
                right: 0,
                child: Center(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _red, // ប្រើពណ៌ក្រហមឱ្យដូច YouTube
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    onPressed: () async {
                      final Uri url = Uri.parse(videoUrl);
                      if (!await launchUrl(
                        url,
                        mode: LaunchMode.externalApplication,
                      )) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('មិនអាចបើកវីដេអូបានទេ')),
                        );
                      }
                    },
                    icon: const Icon(
                      Icons.play_circle_fill_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                    label: const Text(
                      'ចុចដើម្បីមើលវីដេអូ',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Siemreap',
                      ),
                    ),
                  ),
                ),
              ),

            // ប៊ូតុងបិទ
            Positioned(
              top: 40,
              right: 16,
              child: IconButton(
                icon: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 30,
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Approve Auction ───────────────────────────────────────────
  Future<void> _approveAuction(
      BuildContext context,
      String requestId,
      Map<String, dynamic> data,
      ) async {
    try {
      // បង្ហាញ Loading ជាមុនសិនដើម្បីកុំឱ្យ User ចុចជាន់គ្នា
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // 🎯 ១. គណនាពេលវេលាបញ្ចប់ដេញថ្លៃ (ផ្អែកលើម៉ោងដែល Admin ចុច Approve)
      final hours =
          int.tryParse(data['duration_hours']?.toString() ?? '24') ?? 24;
      final endTime = DateTime.now().add(Duration(hours: hours));

      // 🎯 ២. ធ្វើការ Update ស្ថានភាពទៅជា 'auction' នៅក្នុង Collection ថ្មីដាច់ដោយឡែក
      await FirebaseFirestore.instance
          .collection('auction_products') // 🚀 ប្តូរទៅកាន់ Collection ថ្មី
          .doc(requestId) // 🚀 ប្រើ Document ID ដដែលដើម្បី Update
          .update({
        'status':
        'auction', // 🚀 ប្តូរពី 'pending' ទៅជា 'auction' ដើម្បីឱ្យ Users ឃើញ
        'current_price':
        data['start_price'], // កំណត់តម្លៃដំបូងស្មើនឹងតម្លៃចាប់ផ្តើម
        'end_time': Timestamp.fromDate(endTime), // ពេលវេលាបញ្ចប់ពិតប្រាកដ
        'last_bidder': null,
        'last_bidder_id': null,
        'approved_at':
        FieldValue.serverTimestamp(), // កត់ត្រាថ្ងៃដែល Admin បានអនុម័ត
      });

      // 💡 ចំណាំ៖ កូដចាស់ដែលវាតែងតែហៅទៅលុបសំណើចេញពី 'auction_requests' (ត្រង់ផ្នែកខាងក្រោម)
      // គឺបងត្រូវលុបវាចោលផងដែរ (លុបចោលការ delete()) ព្រោះយើងមិនបាច់លុបវាទៀតទេ គឺយើងគ្រាន់តែ Update status នៅក្នុង Collection តែមួយហ្នឹងហ្មង។

      // ៣. បិទ Loading Dialog
      if (!context.mounted) return;
      Navigator.pop(context);

      // ៤. បង្ហាញសារជោគជ័យ
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            '✅ អនុម័តជោគជ័យ! ការដេញថ្លៃចាប់ផ្តើមហើយ',
            style: TextStyle(fontFamily: 'Siemreap'),
          ),
          backgroundColor: _accent,
        ),
      );
    } catch (e) {
      // ប្រសិនបើមាន Error ត្រូវបិទ Loading ដែរ
      if (context.mounted) Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error: $e'), backgroundColor: _red),
      );
    }
  }

  // ── Delete Dialog ─────────────────────────────────────────────
  void _showDeleteDialog(BuildContext context, String docId) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _red.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.delete_outline_rounded,
                  color: _red,
                  size: 30,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'លុបសំណើ?',
                style: TextStyle(
                  color: _text,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Siemreap',
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'សំណើនេះនឹងត្រូវលុបចោលជាអចិន្ត្រៃយ៍',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _textMuted,
                  fontSize: 13,
                  fontFamily: 'Siemreap',
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _textMuted,
                        side: const BorderSide(color: _border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text(
                        'បោះបង់',
                        style: TextStyle(fontFamily: 'Siemreap'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _red,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () {
                        // 🎯 លុបចេញពី Collection ថ្មី
                        FirebaseFirestore.instance
                            .collection('auction_products')
                            .doc(docId)
                            .delete();
                        Navigator.pop(ctx);
                      },
                      child: const Text(
                        'លុប',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Siemreap',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  } // ══════════════════════════════════════════════════════════════

  // BUILD
  // ══════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        title: const Text(
          'សំណើដាក់ដេញថ្លៃ',
          style: TextStyle(
            color: _text,
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _border),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('auction_products') // 🎯 ចូលទៅយកក្នុង Collection ថ្មី
            .where(
          'status',
          isEqualTo: 'pending',
        ) // 🎯 យកតែសំណើណាដែលរង់ចាំ Admin ពិនិត្យ
            .orderBy('created_at', descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (!snap.hasData)
            return const Center(
              child: CircularProgressIndicator(color: _accentBlue),
            );

          final docs = snap.data!.docs;

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: _card,
                      shape: BoxShape.circle,
                      border: Border.all(color: _border),
                    ),
                    child: const Icon(
                      Icons.inbox_outlined,
                      color: _textMuted,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'មិនមានសំណើថ្មីទេ',
                    style: TextStyle(
                      color: _textMuted,
                      fontSize: 16,
                      fontFamily: 'Siemreap',
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final doc = docs[i];
              final data = doc.data() as Map<String, dynamic>;
              return _buildRequestCard(context, doc.id, data);
            },
          );
        },
      ),
    );
  }

  Widget _buildImagePreview(
      BuildContext context,
      String label,
      List images, { // ប្តូរមកជាទទួល List images វិញ
        String? videoUrl,
      }) {
    // បង្កើត firstImg និង imageCount នៅខាងក្នុងនេះតែម្តង ដើម្បីបាត់ក្រហមខាងក្រៅ
    final String firstImg = images.isNotEmpty ? images[0].toString() : '';
    final int imageCount = images.length;

    return GestureDetector(
      onTap: () => _showZoomImage(context, images, videoUrl: videoUrl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: _textMuted,
                  fontSize: 11,
                  fontFamily: 'Siemreap',
                ),
              ),
              if (videoUrl != null && videoUrl.isNotEmpty) ...[
                const SizedBox(width: 4),
                const Icon(Icons.videocam_rounded, color: _red, size: 14),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Stack(
            children: [
              Container(
                width: double.infinity,
                height: 110,
                decoration: BoxDecoration(
                  color: _bg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _border),
                ),
                child: firstImg.isEmpty
                    ? const Icon(
                  Icons.image_not_supported_outlined,
                  color: _textMuted,
                )
                    : ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: CachedNetworkImage(
                    imageUrl: firstImg,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(color: _bg),
                    errorWidget: (_, __, ___) =>
                    const Icon(Icons.broken_image, color: _textMuted),
                  ),
                ),
              ),
              if (imageCount > 1)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '+$imageCount',
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Request Card ──────────────────────────────────────────────
  Widget _buildRequestCard(
      BuildContext context,
      String docId,
      Map<String, dynamic> data,
      ) {
    final fmt = NumberFormat('#,###');
    final images = (data['image_urls'] as List?) ?? [];
    final firstImg = images.isNotEmpty ? images[0].toString() : '';
    final payImg = data['payment_image_url'] ?? '';
    final createdAt = data['created_at'] != null
        ? (data['created_at'] as Timestamp).toDate()
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ───────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _gold.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _gold.withOpacity(0.3)),
                  ),
                  child: const Text(
                    'PENDING',
                    style: TextStyle(
                      color: _gold,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const Spacer(),
                if (createdAt != null)
                  Text(
                    DateFormat('dd/MM/yyyy HH:mm').format(createdAt),
                    style: const TextStyle(color: _textMuted, fontSize: 11),
                  ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: _buildImagePreview(
                    context,
                    'រូបទំនិញ',
                    images, // បញ្ជូន List ទៅផ្ទាល់ (បាត់ក្រហម)
                    videoUrl: data['video_url'],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildImagePreview(
                    context,
                    'វិក្កយបត្រ',
                    payImg.isNotEmpty
                        ? [payImg]
                        : [], // បញ្ជូនជា List (បាត់ក្រហម)
                  ),
                ),
              ],
            ),
          ), // ── Product Info ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data['product_name'] ?? 'គ្មានឈ្មោះ',
                  style: const TextStyle(
                    color: _text,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Siemreap',
                  ),
                ),
                const SizedBox(height: 12),

                // Price info row
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _infoChip(
                      Icons.attach_money_rounded,
                      'ចាប់ផ្តើម',
                      '${fmt.format(int.tryParse(data['start_price']?.toString() ?? '0') ?? 0)} ៛',
                      _accent,
                    ),
                    const SizedBox(width: 8),
                    _infoChip(
                      Icons.trending_up_rounded,
                      'Step',
                      '+${fmt.format(int.tryParse(data['bid_step']?.toString() ?? '0') ?? 0)} ៛',
                      _gold,
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // End time
                if (data['end_time'] != null)
                  _infoChip(
                    Icons.schedule_rounded,
                    'បញ្ចប់នៅ',
                    DateFormat(
                      'dd/MM/yyyy HH:mm',
                    ).format((data['end_time'] as Timestamp).toDate()),
                    _accentBlue,
                  ),

                // Package
                if (data['selected_package'] != null) ...[
                  const SizedBox(height: 8),
                  _infoChip(
                    Icons.workspace_premium_outlined,
                    'Package',
                    data['selected_package'],
                    const Color(0xFFBB86FC),
                  ),
                ],

                // Phone
                if (data['customer_phone'] != null) ...[
                  const SizedBox(height: 8),
                  _infoChip(
                    Icons.phone_outlined,
                    'ទូរស័ព្ទ',
                    data['customer_phone'],
                    _textMuted,
                  ),
                ],

                // Description
                if ((data['description'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _bg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _border),
                    ),
                    child: Text(
                      data['description'],
                      style: const TextStyle(
                        color: _textMuted,
                        fontSize: 13,
                        fontFamily: 'Siemreap',
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 16),
                const Divider(color: _border, height: 1),
                const SizedBox(height: 16),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _accent,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () => _approveAuction(context, docId, data),
                        icon: const Icon(
                          Icons.check_circle_outline_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        label: const Text(
                          'អនុម័ត',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Siemreap',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _red,
                        side: const BorderSide(color: _red),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                      ),
                      onPressed: () => _showDeleteDialog(context, docId),
                      child: const Icon(Icons.delete_outline_rounded, size: 20),
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

  // ── Info Chip ─────────────────────────────────────────────────
  Widget _infoChip(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 5),
          Text(
            '$label: ',
            style: TextStyle(
              color: color.withOpacity(0.7),
              fontSize: 11,
              fontFamily: 'Siemreap',
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              fontFamily: 'Siemreap',
            ),
          ),
        ],
      ),
    );
  }
}


