import 'dart:io';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:gal/gal.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'vip_member_card_download.dart';

class VipMembershipScreen extends StatefulWidget {
  const VipMembershipScreen({super.key});
  @override
  State<VipMembershipScreen> createState() => _VipMembershipScreenState();
}

class _VipMembershipScreenState extends State<VipMembershipScreen> {
  final _formKey = GlobalKey<FormState>();
  String _t(String km, String en) =>
      Localizations.localeOf(context).languageCode == 'en' ? en : km;

  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  File? _receiptImage;
  bool _isSubmitting = false;
  final formatter = NumberFormat('#,###');
  static const int vipPrice = 15000;
  static const Color primaryColor = Color(0xFF0A0E21);
  static const Color accentColor = Color(0xFF3B5BFF);
  static const Color amberColor = Color(0xFFFFB300);
  static const Color cardColor = Color(0xFF1A1F3D);

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  Future<Map<String, List<int>>> _fetchMonthlyActivityStats() async {
    final currentYear = DateTime.now().year;
    Map<String, List<int>> result = {
      'newUsers': List.filled(12, 0),
      'logins': List.filled(12, 0),
      'newProducts': List.filled(12, 0),
      'newAuctions': List.filled(12, 0),
    };
    try {
      final startOfYear = DateTime(currentYear, 1, 1);
      final endOfYear = DateTime(currentYear + 1, 1, 1);
      final usersSnap = await FirebaseFirestore.instance
          .collection('users')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfYear))
          .where('createdAt', isLessThan: Timestamp.fromDate(endOfYear))
          .get();
      for (var doc in usersSnap.docs) {
        final date = doc['createdAt'] as Timestamp?;
        if (date != null) result['newUsers']![date.toDate().month - 1]++;
      }
      final loginsSnap = await FirebaseFirestore.instance
          .collection('users')
          .where('lastLogin', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfYear))
          .where('lastLogin', isLessThan: Timestamp.fromDate(endOfYear))
          .get();
      for (var doc in loginsSnap.docs) {
        final date = doc['lastLogin'] as Timestamp?;
        if (date != null) result['logins']![date.toDate().month - 1]++;
      }
      final productsSnap = await FirebaseFirestore.instance
          .collection('products')
          .where('created_at', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfYear))
          .where('created_at', isLessThan: Timestamp.fromDate(endOfYear))
          .get();
      for (var doc in productsSnap.docs) {
        final date = doc['created_at'] as Timestamp?;
        if (date != null) result['newProducts']![date.toDate().month - 1]++;
      }
      final auctionsSnap = await FirebaseFirestore.instance
          .collection('auction_products')
          .where('created_at', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfYear))
          .where('created_at', isLessThan: Timestamp.fromDate(endOfYear))
          .get();
      for (var doc in auctionsSnap.docs) {
        final date = doc['created_at'] as Timestamp?;
        if (date != null) result['newAuctions']![date.toDate().month - 1]++;
      }
    } catch (e) {
      debugPrint("Error: $e");
    }
    return result;
  }Future<Map<String, int>> _fetchDailyStats() async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));
    try {
      final results = await Future.wait([
        FirebaseFirestore.instance
            .collection('users')
            .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
            .where('createdAt', isLessThan: Timestamp.fromDate(todayEnd))
            .count()
            .get(),
        FirebaseFirestore.instance
            .collection('users')
            .where('lastLogin', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
            .where('lastLogin', isLessThan: Timestamp.fromDate(todayEnd))
            .count()
            .get(),
        FirebaseFirestore.instance
            .collection('products')
            .where('created_at', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
            .where('created_at', isLessThan: Timestamp.fromDate(todayEnd))
            .count()
            .get(),
        FirebaseFirestore.instance
            .collection('auction_products')
            .where('created_at', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
            .where('created_at', isLessThan: Timestamp.fromDate(todayEnd))
            .count()
            .get(),
      ]);
      return {
        'newUsers': results[0].count ?? 0,
        'loginsToday': results[1].count ?? 0,
        'newProducts': results[2].count ?? 0,
        'newAuctions': results[3].count ?? 0,
      };
    } catch (e) {
      return {'newUsers': 0, 'loginsToday': 0, 'newProducts': 0, 'newAuctions': 0};
    }
  }

  Future<String?> _uploadImage(File image) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
      final ref = FirebaseStorage.instance.ref().child(
        'vip_receipts/${DateTime.now().millisecondsSinceEpoch}_$uid.png',
      );
      await ref.putFile(image);
      return await ref.getDownloadURL();
    } catch (e) {
      return null;
    }
  }

  Future<void> _launchABA() async {
    final Uri url = Uri.parse('https://pay.ababank.com/oRF8/oizn40j9');
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      await launchUrl(url, mode: LaunchMode.platformDefault);
    }
  }

  // Android47 parity: top payment feedback
  void _showTopMessage(String message, {bool isError = false}) {
    final overlay = Overlay.of(context, rootOverlay: true);
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (overlayContext) => Positioned(
        top: MediaQuery.of(overlayContext).padding.top + 12,
        left: 16,
        right: 16,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 220),
          builder: (_, value, child) => Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, -24 * (1 - value)),
              child: child,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isError
                    ? const Color(0xFFDA3633)
                    : const Color(0xFF238636),
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    isError
                        ? Icons.error_outline_rounded
                        : Icons.check_circle_outline_rounded,
                    color: Colors.white,
                    size: 21,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'Siemreap',
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 3), () {
      if (entry.mounted) entry.remove();
    });
  }

  Future<void> _downloadQR() async {
    try {
      if (!await Gal.hasAccess()) {
        await Gal.requestAccess();
      }
      if (!await Gal.hasAccess()) {
        throw Exception('Gallery permission denied');
      }
      final byteData = await rootBundle.load('assets/aba_qr.png');
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/aba_qr_download.png');
      await file.writeAsBytes(
        byteData.buffer.asUint8List(
          byteData.offsetInBytes,
          byteData.lengthInBytes,
        ),
      );
      await Gal.putImage(file.path);
      if (!mounted) return;
      _showTopMessage(_t('✅ បានរក្សាទុកក្នុង Gallery!', '✅ Saved to Gallery!'));
    } catch (e) {
      if (!mounted) return;
      _showTopMessage(_t('❌ មិនអាចរក្សាទុក: $e', '❌ Could not save: $e'), isError: true);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        backgroundColor: isError ? const Color(0xFFDA3633) : const Color(0xFF238636),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _clearForm() {
    nameController.clear();
    phoneController.clear();
    setState(() => _receiptImage = null);
  }

  Future<void> _submitVipRequest(BuildContext context, StateSetter setModalState) async {
    if (!_formKey.currentState!.validate() || _receiptImage == null) {
      _showSnack(_t('សូមបំពេញទិន្នន័យ និងភ្ជាប់រូបភាព', 'Please complete the information and attach a receipt image.'), isError: true);
      return;
    }
    setModalState(() => _isSubmitting = true);try {
      final prefs = await SharedPreferences.getInstance();
      final uid = prefs.getString('user_uid') ?? '';
      String sesanId = '';
      try {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        if (userDoc.exists) sesanId = userDoc.data()?['sesan_id']?.toString() ?? '';
      } catch (_) {}
      final url = await _uploadImage(_receiptImage!);
      if (url == null) throw Exception('Upload failed');
      await FirebaseFirestore.instance.collection('vip_requests').add({
        'name': nameController.text.trim(),
        'phone': phoneController.text.trim(),
        'amount': vipPrice,
        'receipt_url': url,
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
        'user_id': uid,
        'sesan_id': sesanId,
      });
      _clearForm();
      if (mounted) {
        Navigator.pop(context);
        _showSnack(_t('✅ សំណើ VIP ត្រូវបានបញ្ជូន!', '✅ VIP request submitted!'), isError: false);
      }
    } catch (e) {
      if (mounted) _showSnack(_t('❌ មានបញ្ហា: $e', '❌ Error: $e'), isError: true);
    } finally {
      setModalState(() => _isSubmitting = false);
    }
  }

  Widget _buildVipCard(Map<String, dynamic> userData, String uid) {
    final name = userData['name']?.toString() ?? 'VIP Member';
    final sesanId = userData['sesan_id']?.toString() ?? '—';
    String joinDate = '—';
    try {
      final raw = userData['vip_since'];
      if (raw is Timestamp) {
        joinDate = DateFormat('dd/MM/yyyy').format(raw.toDate());
      } else if (raw is String && raw.isNotEmpty) {
        joinDate = raw;
      }
    } catch (_) {}
    String issuedDate = DateFormat('dd/MM/yyyy').format(DateTime.now());
    try {
      final raw = userData['vip_since'];
      if (raw is Timestamp) {
        issuedDate = DateFormat('dd/MM/yyyy').format(raw.toDate());
      }
    } catch (_) {}
    return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF3D2900), Color(0xFF7A5200), Color(0xFFB8860B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: [0.0, 0.5, 1.0],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(color: amberColor.withOpacity(0.35), blurRadius: 24, offset: const Offset(0, 10), spreadRadius: -4),
          ],
          border: Border.all(color: Colors.white.withOpacity(0.15), width: 1),
        ),
        child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Stack(
                  children: [
                  Positioned(
                  right: -30, bottom: -30,
                  child: Container(width: 150, height: 150, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.05))),
                ),
                Positioned(
                  left: -20, top: -20,
                  child: Container(width: 100, height: 100, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.03))),
                ),
                Padding(
                    padding: const EdgeInsets.all(4),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                        Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                    Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                    child: const Row(children: [Icon(Icons.diamond, color: Colors.amber, size: 12),
                      SizedBox(width: 5),
                      Text("SESAN VIP MEMBER", style: TextStyle(color: Colors.white, fontSize: 9, letterSpacing: 1.5, fontWeight: FontWeight.bold)),
                    ]),
                    ),
                          Icon(Icons.workspace_premium, color: Colors.amber.withOpacity(0.8), size: 24),
                        ],
                        ),
                          const SizedBox(height: 20),
                          Text(name.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 1.2, fontFamily: 'Siemreap')),
                          const SizedBox(height: 18),
                          Row(children: [
                            _vipCardInfo("SESAN ID", sesanId),
                            const SizedBox(width: 40),
                            _vipCardInfo("VIP ID", "VIP-${uid.substring(0, 5).toUpperCase()}"),
                          ]),
                          const SizedBox(height: 18),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _vipCardInfo(_t('ចូលជាសមាជិកពី', 'Member since'), joinDate),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  _vipCardInfo(_t('ថ្ងៃចេញកាត', 'Issued on'), issuedDate),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.amber.withOpacity(0.5)),
                                    ),
                                    child: Text(_t('✓ សកម្ម', '✓ ACTIVE'), style: TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                    ),
                ),
                  ],
                ),
            ),
        ),
    );
  }

  Widget _vipCardInfo(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 9, letterSpacing: 0.5)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }

  Widget _buildShimmer() {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF1A1F3D),
      highlightColor: const Color(0xFF2A2F4D),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          Container(height: 200, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24))),
          const SizedBox(height: 20),
          Container(height: 120, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16))),
          const SizedBox(height: 20),
          Container(height: 220, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16))),
        ]),
      ),
    );
  }

  Widget _buildBenefitsCard() {
    final benefits = [
    {'icon': Icons.workspace_premium, 'color': Colors.amber, 'title': _t('ផ្លាកសញ្ញា VIP', 'VIP badge'), 'desc': _t('ផ្លាកពិសេសបង្ហាញលើប្រវត្តិរូប', 'Special badge shown on your profile')},
    {'icon': Icons.bar_chart_rounded, 'color': Colors.blueAccent, 'title': _t('ស្ថិតិផ្ទាល់', 'Real-time stats'), 'desc': _t('មើលចំនួនអ្នកប្រើ ទំនិញ និងការបញ្ជាទិញ', 'View users, products and orders in real time')},{'icon': Icons.show_chart, 'color': Colors.greenAccent, 'title': _t('ក្រាបទិន្នន័យ', 'Activity charts'), 'desc': _t('ក្រាបសកម្មភាពប្រចាំឆ្នាំ ៤ ខ្សែ', 'Four annual activity charts')},
      {'icon': Icons.notifications_active, 'color': Colors.orangeAccent, 'title': _t('ការជូនដំណឹងមុនគេ', 'Priority notifications'), 'desc': _t('ទទួលព័ត៌មានពិសេសសម្រាប់ VIP', 'Receive special VIP updates')},
      {'icon': Icons.support_agent, 'color': Colors.purpleAccent, 'title': _t('ជំនួយពិសេស', 'Priority support'), 'desc': _t('ការគាំទ្រផ្ទាល់ពីក្រុមការងារ', 'Direct support from the Sesan team')},
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: amberColor.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: amberColor.withOpacity(0.15), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.diamond, color: amberColor, size: 20)),
            const SizedBox(width: 12),
            Text(_t('អត្ថប្រយោជន៍ VIP', 'VIP benefits'), style: TextStyle(color: Colors.amber, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Siemreap')),
          ]),
          const SizedBox(height: 16),
          ...benefits.map((b) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(children: [
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: (b['color'] as Color).withOpacity(0.12), borderRadius: BorderRadius.circular(10)), child: Icon(b['icon'] as IconData, color: b['color'] as Color, size: 18)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(b['title'] as String, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'Siemreap')),
                  Text(b['desc'] as String, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11, fontFamily: 'Siemreap')),
                ]),
              ),
              Icon(Icons.check_circle, color: (b['color'] as Color).withOpacity(0.7), size: 16),
            ]),
          )),
        ],
      ),
    );
  }

  Widget _buildSecuredContent() {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
    Row(children: [
    Container(width: 4, height: 20, decoration: BoxDecoration(color: amberColor, borderRadius: BorderRadius.circular(2))),
    const SizedBox(width: 8),
    Text(_t('សកម្មភាពប្រចាំឆ្នាំ', 'Annual activity'), style: TextStyle(color: Colors.white70, fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'Siemreap')),
    ]),
    const SizedBox(height: 12),
    FutureBuilder<Map<String, List<int>>>(
    future: _fetchMonthlyActivityStats(),
    builder: (context, snap) {
    if (!snap.hasData) return Shimmer.fromColors(baseColor: const Color(0xFF1A1F3D), highlightColor: const Color(0xFF2A2F4D), child: Container(height: 250, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16))));
    return _buildLineChart(snap.data!);
    },
    ),
    const SizedBox(height: 24),
    Row(children: [
    Container(width: 4, height: 20, decoration: BoxDecoration(color: Colors.blueAccent, borderRadius: BorderRadius.circular(2))),
    const SizedBox(width: 8),
    Text(_t('ស្ថិតិថ្ងៃនេះ', "Today's stats"), style: TextStyle(color: Colors.white70, fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'Siemreap')),
    const Spacer(),
    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: Colors.green.withOpacity(0.15), borderRadius: BorderRadius.circular(8)), child: const Row(children: [Icon(Icons.circle, color: Colors.greenAccent, size: 8), SizedBox(width: 4), Text("Live", style: TextStyle(color: Colors.greenAccent, fontSize:10))])),
    ]),
          const SizedBox(height: 12),
          FutureBuilder<Map<String, int>>(
            future: _fetchDailyStats(),
            builder: (context, snap) {
              if (!snap.hasData) return Shimmer.fromColors(baseColor: const Color(0xFF1A1F3D), highlightColor: const Color(0xFF2A2F4D), child: Container(height: 90, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16))));
              final stats = snap.data!;
              return Row(children: [
                _statCard(_t('អ្នកថ្មី', 'New users'), stats['newUsers'] ?? 0, Icons.person_add, Colors.blue),
                const SizedBox(width: 10),
                _statCard(_t('ចូលថ្ងៃនេះ', 'Logins today'), stats['loginsToday'] ?? 0, Icons.login, Colors.green),
                const SizedBox(width: 10),
                _statCard(_t('ទំនិញថ្មី', 'New products'), stats['newProducts'] ?? 0, Icons.add_shopping_cart, Colors.orange),
                const SizedBox(width: 10),
                _statCard(_t('ដេញថ្លៃថ្មី', 'New auctions'), stats['newAuctions'] ?? 0, Icons.gavel, Colors.purpleAccent),
              ]);
            },
          ),
        ],
    );
  }

  Widget _buildLineChart(Map<String, List<int>> data) {
    const lineColors = {
      'newUsers': Colors.blueAccent,
      'logins': Colors.greenAccent,
      'newProducts': Colors.orangeAccent,
      'newAuctions': Colors.purpleAccent,
    };
    final lineLabels = {
      'newUsers': _t('អ្នកថ្មី', 'New users'),
      'logins': _t('ចូលប្រើ', 'Logins'),
      'newProducts': _t('ទំនិញផុស', 'Products'),
      'newAuctions': _t('ដេញថ្លៃ', 'Auctions'),
    };
    final months = Localizations.localeOf(context).languageCode == 'en'
        ? const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
        : const ['មក', 'កុម', 'មីនា', 'មេសា', 'ឧស', 'មិថុ', 'កក្ក', 'សីហា', 'កញ្ញា', 'តុលា', 'វិច', 'ធ្នូ'];
    List<LineChartBarData> bars = [];
    for (var key in ['newUsers', 'logins', 'newProducts', 'newAuctions']) {
      final values = data[key]!;
      bars.add(LineChartBarData(
        spots: List.generate(values.length, (i) => FlSpot(i.toDouble(), values[i].toDouble())),
        isCurved: true,
        color: lineColors[key]!,
        barWidth: 2.5,
        dotData: FlDotData(show: true, getDotPainter: (s, p, b, i) => FlDotCirclePainter(radius: 3.5, color: lineColors[key]!, strokeWidth: 1.5, strokeColor: Colors.white)),
        belowBarData: BarAreaData(show: true, color: lineColors[key]!.withOpacity(0.08)),
      ));
    }
    return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.08))),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(_t('និន្នាការប្រចាំឆ្នាំ', 'Annual trends'), style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'Siemreap')),
          Text(DateTime.now().year.toString(), style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12)),
        ]),
        const SizedBox(height: 14),
        SizedBox(
            height: 180,
            child: LineChart(LineChartData(
                gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => const FlLine(color: Colors.white10, strokeWidth: 1)),
                titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, interval: 1, getTitlesWidget: (val, meta) {
                      final idx = val.toInt();
                      return idx >= 0 && idx < 12 ? Text(months[idx], style: const TextStyle(color: Colors.grey, fontSize: 8)) : const Text('');
                    })),
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, interval: 1, getTitlesWidget: (value, meta) {
                      if (value == value.roundToDouble()) return Text(value.toInt().toString(), style: const TextStyle(color: Colors.grey, fontSize: 8));return const Text('');
                    })),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
              borderData: FlBorderData(show: false),
              lineBarsData: bars,
            )),
        ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 16, runSpacing: 6,
                children: lineLabels.entries.map((e) => Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: lineColors[e.key]!, shape: BoxShape.circle)),
                  const SizedBox(width: 5),
                  Text(e.value, style: const TextStyle(color: Colors.white60, fontSize: 10)),
                ])).toList(),
              ),
            ],
        ),
    );
  }

  Widget _buildLockedSection() {
    return LayoutBuilder(
      builder: (context, constraints) => Stack(
        children: [
          Opacity(opacity: 0.12, child: IgnorePointer(child: SizedBox(width: constraints.maxWidth, child: _buildSecuredContent()))),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Colors.black.withOpacity(0.5), Colors.black.withOpacity(0.75)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              alignment: Alignment.center,
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(color: amberColor.withOpacity(0.15), shape: BoxShape.circle, border: Border.all(color: amberColor.withOpacity(0.4), width: 2)),
                    child: const Icon(Icons.lock_outline, color: amberColor, size: 36),
                  ),
                  const SizedBox(height: 16),
                  Text(_t('ដោះសោទិន្នន័យពិសេស', 'Unlock exclusive data'), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Siemreap')),
                  const SizedBox(height: 8),
                  Text(_t('ក្លាយជាសមាជិក VIP ដើម្បីមើលក្រាប\nស្ថិតិ Real-time និងទិន្នន័យពិសេស', 'Become a VIP member to view charts,\nreal-time stats and exclusive data'),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 13, fontFamily: 'Siemreap', height: 1.6)),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: amberColor,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 13),
                      elevation: 4,
                      shadowColor: amberColor.withOpacity(0.4),
                    ),
                    onPressed: () => _showVipPurchaseDialog(context),
                    icon: const Icon(Icons.diamond, size: 18),
                    label: Text(_t('ទិញ VIP ឥឡូវនេះ', 'Buy VIP now'), style: const TextStyle(fontFamily: 'Siemreap', fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                  const SizedBox(height: 10),
                  Text(_t('តម្លៃ ${formatter.format(vipPrice)} ៛ / ខែ', 'Price ${formatter.format(vipPrice)} KHR / month'), style: TextStyle(color: amberColor.withOpacity(0.7), fontSize: 12, fontFamily: 'Siemreap')),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showVipPurchaseDialog(BuildContext context) {int currentStep = 0;
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF0F121F),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (ctx) => StatefulBuilder(
      builder: (context, setModalState) => DraggableScrollableSheet(
          initialChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) => Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                  children: [
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              Text(_t('ក្លាយជាសមាជិក VIP', 'Become a VIP member'), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Siemreap')),
              const SizedBox(height: 4),
              Text(_t('ជំហាន ${currentStep + 1}/3', 'Step ${currentStep + 1}/3'), style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 12)),
              const SizedBox(height: 20),
              Row(children: [
                _stepDot(0, currentStep), _stepLine(0, currentStep),
                _stepDot(1, currentStep), _stepLine(1, currentStep),
                _stepDot(2, currentStep),
              ]),
              const SizedBox(height: 24),
              Expanded(
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    controller: scrollController,
                    child: currentStep == 0 ? _buildStep1() : currentStep == 1 ? _buildStep2(setModalState) : _buildStep3(setModalState),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                  children: [
                  if (currentStep > 0) ...[
          Expanded(
          child: OutlinedButton(
          style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white24), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      onPressed: () => setModalState(() => currentStep--),
      child: Text(_t('ថយក្រោយ', 'Back'), style: const TextStyle(color: Colors.white70)),
    ),
  ),
    const SizedBox(width: 10),
    ],
    Expanded(
    flex: currentStep == 0 ? 1 : 2,
    child: ElevatedButton(
    style: ElevatedButton.styleFrom(
    backgroundColor: currentStep == 2 ? amberColor : accentColor,
    foregroundColor: currentStep == 2 ? Colors.black : Colors.white,
    padding: const EdgeInsets.symmetric(vertical: 14),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    elevation: 3,
    ),
    onPressed: _isSubmitting ? null : () {
    if (currentStep < 2) {
    if (currentStep == 0 && !_formKey.currentState!.validate()) return;
    setModalState(() => currentStep++);
    } else {
    _submitVipRequest(context, setModalState);
    }
    },
    child: _isSubmitting
    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)): Text(currentStep < 2 ? _t('បន្ត →', 'Continue →') : _t('✓ បញ្ជូនសំណើ', '✓ Submit request'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
    ),
    ),
                  ],
              ),
                  ],
              ),
          ),
      ),
    ),
  );
  }

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(14), margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(color: accentColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: accentColor.withOpacity(0.3))),
          child: Row(children: [
            const Icon(Icons.info_outline, color: Colors.blueAccent, size: 18), const SizedBox(width: 10),
            Expanded(child: Text(_t('បំពេញព័ត៌មានដើម្បីបញ្ជាក់អត្តសញ្ញាណ', 'Enter your information to verify your identity'), style: const TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'Siemreap'))),
          ]),
        ),
        _buildDarkInput(_t('ឈ្មោះពេញ *', 'Full name *'), nameController, Icons.person),
        _buildDarkInput(_t('លេខទូរស័ព្ទ *', 'Phone number *'), phoneController, Icons.phone, TextInputType.phone),
      ],
    );
  }

  Widget _buildStep2(StateSetter setModalState) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [amberColor.withOpacity(0.2), amberColor.withOpacity(0.05)]),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: amberColor.withOpacity(0.4)),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_t('តម្លៃ VIP Membership', 'VIP Membership price'), style: const TextStyle(color: Colors.white60, fontSize: 11, fontFamily: 'Siemreap')),
              const SizedBox(height: 4),
              Text(_t('សមាជិកភាព ១ ខែ', '1-month membership'), style: const TextStyle(color: Colors.white54, fontSize: 10)),
            ]),
            Text("${formatter.format(vipPrice)} ៛", style: const TextStyle(color: Colors.amber, fontSize: 24, fontWeight: FontWeight.bold)),
          ]),
        ),
        const SizedBox(height: 20),
        Text(_t('QR Code បង់ប្រាក់', 'Payment QR Code'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Siemreap')),
        const SizedBox(height: 4),
        Text(_t('Long press ដើម្បីទាញ QR', 'Long press to save QR'), style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11)),
        const SizedBox(height: 12),
        GestureDetector(
          onLongPress: _downloadQR,
          child: Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: amberColor.withOpacity(0.2), blurRadius: 20, spreadRadius: -5)]),
            padding: const EdgeInsets.all(12),
            child: Image.asset('assets/aba_qr.png', height: 170, fit: BoxFit.contain, errorBuilder: (c, e, s) => const SizedBox(height: 170, child: Center(child: Icon(Icons.qr_code_2, size: 100, color: Colors.black54)))),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _launchABA,
            icon: const Icon(Icons.open_in_new, size: 18),
            label: Text(_t('បើក App ABA', 'Open ABA App'), style: const TextStyle(fontFamily: 'Siemreap')),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF005D7E), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          ),
        ),
      ],
    );
  }

  Widget _buildStep3(StateSetter setModalState) {return Column(
    children: [
      Container(
        padding: const EdgeInsets.all(14), margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(color: Colors.green.withOpacity(0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.greenAccent.withOpacity(0.3))),
        child: Row(children: [
          const Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 18), const SizedBox(width: 10),
          Expanded(child: Text(_t('ភ្ជាប់រូបថតវិក្កយបត្របង់ប្រាក់', 'Attach your payment receipt image'), style: const TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'Siemreap'))),
        ]),
      ),
      GestureDetector(
        onTap: () async {
          final xfile = await ImagePicker().pickImage(source: ImageSource.gallery);
          if (xfile != null) setModalState(() => _receiptImage = File(xfile.path));
        },
        child: Container(
          height: 200, width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _receiptImage != null ? Colors.greenAccent.withOpacity(0.5) : Colors.white.withOpacity(0.12), width: _receiptImage != null ? 2 : 1),
          ),
          child: _receiptImage == null
              ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.add_a_photo_outlined, color: Colors.white.withOpacity(0.35), size: 44),
            const SizedBox(height: 10),
            Text(_t('ចុចដើម្បីជ្រើសរើស', 'Tap to select'), style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13, fontFamily: 'Siemreap')),
          ])
              : ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.file(_receiptImage!, fit: BoxFit.cover)),
        ),
      ),
      if (_receiptImage != null) ...[
        const SizedBox(height: 10),
        TextButton.icon(
          onPressed: () => setModalState(() => _receiptImage = null),
          icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
          label: Text(_t('លុបចេញ', 'Remove'), style: const TextStyle(color: Colors.redAccent, fontFamily: 'Siemreap')),
        ),
      ],
    ],
  );
  }

  Widget _stepDot(int step, int current) {
    final active = step <= current;
    final isCurrent = step == current;
    return Container(
      width: 32, height: 32,
      decoration: BoxDecoration(
        color: active ? (isCurrent ? accentColor : accentColor.withOpacity(0.7)) : Colors.white.withOpacity(0.1),
        shape: BoxShape.circle,
        border: isCurrent ? Border.all(color: Colors.white, width: 2) : null,
        boxShadow: active ? [BoxShadow(color: accentColor.withOpacity(0.4), blurRadius: 8, spreadRadius: -2)] : null,
      ),
      child: Center(child: Text("${step + 1}", style: TextStyle(color: active ? Colors.white : Colors.white.withOpacity(0.3), fontWeight: FontWeight.bold, fontSize: 13))),
    );
  }

  Widget _stepLine(int step, int current) {
    return Expanded(
      child: Container(
        height: 2,
        decoration: BoxDecoration(
          gradient: step < current ? const LinearGradient(colors: [accentColor, Color(0xFF6B84FF)]) : null,
          color: step < current ? null : Colors.white.withOpacity(0.1),
        ),
      ),
    );
  }

  Widget _buildDarkInput(String label, TextEditingController ctrl, IconData icon, [TextInputType? type]) {
    return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: TextFormField(
            controller: ctrl,
            keyboardType: type,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: label,
              labelStyle: TextStyle(color: Colors.white.withOpacity(0.55), fontFamily: 'Siemreap', fontSize: 13),prefixIcon: Icon(icon, color: Colors.white.withOpacity(0.4), size: 20),
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: accentColor, width: 1.5)),
              errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.redAccent)),
            ),
          validator: (v) => (v == null || v.trim().isEmpty) ? _t('សូមបំពេញ ${label.replaceAll(' *', '')}', 'Please enter ${label.replaceAll(' *', '')}') : null,
        ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryColor,
      appBar: AppBar(
        title: const Text("SESAN VIP", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        backgroundColor: Colors.transparent, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white), onPressed: () => Navigator.pop(context)),
      ),
      body: FutureBuilder<SharedPreferences>(
        future: SharedPreferences.getInstance(),
        builder: (context, prefsSnap) {
          if (!prefsSnap.hasData) return _buildShimmer();
          final uid = prefsSnap.data!.getString('user_uid') ?? '';
          if (uid.isEmpty) {
            return Center(child: Text(_t('សូមចូលប្រើគណនីដើម្បីបន្ត', 'Please log in to continue'), style: const TextStyle(color: Colors.white70, fontFamily: 'Siemreap')));
          }
          return StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return _buildShimmer();
              final userData = snapshot.hasData && snapshot.data!.exists ? (snapshot.data!.data() as Map<String, dynamic>) : <String, dynamic>{};
              final bool isVip = userData['isVip'] == true;
              return RefreshIndicator(
                onRefresh: () async => setState(() {}),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (isVip) ...[
                      VipMemberCardDownload(
                        card: _buildVipCard(userData, uid),
                      ),
                      const SizedBox(height: 20),
                    ],
                    _buildBenefitsCard(),
                    const SizedBox(height: 24),
                    isVip ? _buildSecuredContent() : _buildLockedSection(),
                    const SizedBox(height: 28),
                    if (!isVip)
                      SizedBox(
                        width: double.infinity, height: 56,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: amberColor, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 6, shadowColor: amberColor.withOpacity(0.45)),
                          onPressed: () => _showVipPurchaseDialog(context),
                          icon: const Icon(Icons.diamond, size: 20),
                          label: Text(_t('ចាប់ផ្ដើមជាសមាជិក VIP', 'Become a VIP member'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, fontFamily: 'Siemreap')),
                        ),
                      ),
                  ]),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _benefitItem(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 13, fontFamily: 'Siemreap')),
  );Widget _statCard(String title, int value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withOpacity(0.25))),
        child: Column(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text("$value", style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
          Text(title, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 9, fontFamily: 'Siemreap'), textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}