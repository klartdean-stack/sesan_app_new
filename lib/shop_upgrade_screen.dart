import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';

class ShopUpgradeScreen extends StatefulWidget {
  const ShopUpgradeScreen({super.key});
  @override
  State<ShopUpgradeScreen> createState() => _ShopUpgradeScreenState();
}

class _ShopUpgradeScreenState extends State<ShopUpgradeScreen> {
  String? _selectedTier;
  File? _receiptImage;
  bool _isSubmitting = false;
  bool _isLoadingUser = true;
  final formatter = NumberFormat('#,###');
  String? _currentUserId;
  String? _currentShopName;
  String? _currentUserName;
  String? _currentPhone;
  String? _currentShopTier;
  bool _isCheckingName = false;
  bool? _isNameAvailable;
  String? _nameCheckError;

  static const Color bgColor = Color(0xFF0A0E21);
  static const Color cardColor = Color(0xFF1A1F3D);
  static const Color accentColor = Color(0xFF3B5BFF);
  static const Color amberColor = Color(0xFFFFB300);
  static const Color redColor = Color(0xFFDA3633);
  static const Color greenColor = Color(0xFF00C48C);
  static const int basicPrice = 15000;
  static const int premiumPrice = 40000;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoadingUser = true);
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getString('user_uid') ?? '';
    if (uid.isEmpty) {
      setState(() => _isLoadingUser = false);
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _currentUserId = uid;
          _currentShopName = data['name'] ?? '—';
          _currentUserName = data['name'] ?? '—';
          _currentPhone = data['phone'] ?? data['phone1'] ?? '—';
          _currentShopTier = data['shop_tier'];
        });
      }
    } catch (e) {
      debugPrint("load error: $e");
    }
    setState(() => _isLoadingUser = false);
  }

  Future<bool> _checkShopNameAvailability(String name) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('shop_names').doc(name).get();
      if (!doc.exists) return true;
      return (doc.data()?['owner_id'] ?? '') == _currentUserId;
    } catch (_) {
      return false;
    }
  }

  Future<void> _performNameCheck() async {
    if (_currentShopName == null) return;
    setState(() {
      _isCheckingName = true;
      _isNameAvailable = null;
      _nameCheckError = null;
    });
    try {
      final ok = await _checkShopNameAvailability(_currentShopName!);
      setState(() {
        _isNameAvailable = ok;
        _nameCheckError = ok ? null : 'ឈ្មោះនេះមានម្ចាស់ហើយ!';
      });
    } catch (_) {
      setState(() => _nameCheckError = 'មិនអាចពិនិត្យបាន');
    } finally {
      setState(() => _isCheckingName = false);
    }
  }

  void _onTierSelected(String tier) {
    setState(() {
      _selectedTier = tier;
      if (tier == 'premium') _performNameCheck();
      else {
        _isNameAvailable = null;
        _nameCheckError = null;
      }
    });
  }

  Future<String?> _uploadImage(File image) async {
    try {
      final uid = _currentUserId ?? 'unknown';
      final ref = FirebaseStorage.instance.ref().child(
        'shop_upgrade_receipts/${DateTime.now().millisecondsSinceEpoch}_$uid.png',
      );
      await ref.putFile(image);
      return await ref.getDownloadURL();
    } catch (e) {
      return null;
    }
  }Future<void> _launchABA() async {
    final Uri url = Uri.parse('https://pay.ababank.com/oRF8/lq8jgwzb');
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      await launchUrl(url, mode: LaunchMode.platformDefault);
    }
  }

  Future<void> _downloadQR(BuildContext rootContext) async {
    try {
      final byteData = await rootBundle.load('assets/aba_qr.png');
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/aba_qr_download.png');
      await file.writeAsBytes(byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));
      await Gal.putImage(file.path);
      if (!mounted) return;
      ScaffoldMessenger.of(rootContext).showSnackBar(
        SnackBar(
          content: const Text('✅ បានរក្សាទុកក្នុង Gallery រួចរាល់!',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          backgroundColor: const Color(0xFF238636),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(rootContext).showSnackBar(
        SnackBar(
          content: Text('❌ មិនអាចរក្សាទុកបាន: $e',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          backgroundColor: redColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        backgroundColor: isError ? redColor : const Color(0xFF238636),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _submitRequest(BuildContext context, StateSetter setModalState) async {
    if (_selectedTier == null || _receiptImage == null) return;
    if (_selectedTier == 'premium' && _isNameAvailable != true) {
      _showSnack('ឈ្មោះហាងមានម្ចាស់ហើយ មិនអាចទិញបាន', isError: true);
      return;
    }
    setModalState(() => _isSubmitting = true);
    try {
      final url = await _uploadImage(_receiptImage!);
      if (url == null) throw Exception('Upload failed');
      String sesanId = '';
      try {
        final d = await FirebaseFirestore.instance.collection('users').doc(_currentUserId).get();
        if (d.exists) sesanId = d.data()?['sesan_id']?.toString() ?? '';
      } catch (_) {}
      await FirebaseFirestore.instance.collection('shop_upgrade_requests').add({
        'user_id': _currentUserId,
        'name': _currentUserName,
        'phone': _currentPhone,
        'tier': _selectedTier,
        'price': _selectedTier == 'premium' ? premiumPrice : basicPrice,
        'shop_name': _selectedTier == 'premium' ? _currentShopName : null,
        'receipt_url': url,
        'status': 'pending',
        'sesan_id': sesanId,
        'timestamp': FieldValue.serverTimestamp(),
      });
      setState(() {
        _receiptImage = null;
        _selectedTier = null;
        _isNameAvailable = null;
      });
      if (mounted) {
        Navigator.pop(context);
        _showSnack('✅ សំណើដំឡើងហាងត្រូវបានបញ្ជូន!', isError: false);
      }
    } catch (e) {
      if (mounted) _showSnack('❌ មានបញ្ហា: $e', isError: true);
    } finally {
      setModalState(() => _isSubmitting = false);
    }
  }void _showPurchaseDialog(BuildContext context) {
    final rootContext = context;
    int currentStep = 0;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: bgColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => DraggableScrollableSheet(
            initialChildSize: 0.9,
            expand: false,
            builder: (context, scrollController) => Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                  Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  _selectedTier == 'premium' ? '💎 Premium Shop' : '✓ Basic Shop',
                  style: TextStyle(
                    color: _selectedTier == 'premium' ? amberColor : Colors.blueAccent,
                    fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Siemreap',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "ជំហាន ${currentStep + 1}/3",
                  style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 12),
                ),
                const SizedBox(height: 20),
                Row(children: [
                  _stepDot(0, currentStep), _stepLine(0, currentStep),
                  _stepDot(1, currentStep), _stepLine(1, currentStep),
                  _stepDot(2, currentStep),
                ]),
                const SizedBox(height: 24),
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    child: currentStep == 0
                        ? _buildSummaryStep()
                        : currentStep == 1
                        ? _buildPaymentStep(rootContext)
                        : _buildUploadStep(setModalState),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                    children: [
                    if (currentStep > 0) ...[
            Expanded(
            child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
            side: BorderSide(color: Colors.white.withOpacity(0.2)),
        padding: const EdgeInsets.symmetric(vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: () => setModalState(() => currentStep--),
      icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white54, size: 14),
      label: const Text('ថយក្រោយ', style: TextStyle(color: Colors.white60, fontFamily: 'Siemreap')),
    ),
    ),
    const SizedBox(width: 12),
    ],
    Expanded(
    flex: currentStep == 0 ? 1 : 2,
    child: ElevatedButton(
    style: ElevatedButton.styleFrom(
    backgroundColor: currentStep == 2
    ? (_selectedTier == 'premium' ? amberColor : accentColor)
        : accentColor,
    foregroundColor: Colors.white,
    padding: const EdgeInsets.symmetric(vertical: 14),shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 3,
    ),
      onPressed: _isSubmitting ? null : () {
        if (currentStep < 2) setModalState(() => currentStep++);
        else _submitRequest(context, setModalState);
      },
      child: _isSubmitting
          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
          : Text(currentStep < 2 ? 'បន្ត →' : '✓ បញ្ជូនសំណើ',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Siemreap')),
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

  Widget _stepDot(int step, int current) {
    final active = step <= current;
    final isCurrent = step == current;
    return Container(
      width: 32, height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? accentColor : Colors.white.withOpacity(0.08),
        border: isCurrent ? Border.all(color: Colors.white, width: 2) : null,
        boxShadow: active ? [BoxShadow(color: accentColor.withOpacity(0.4), blurRadius: 8, spreadRadius: -2)] : null,
      ),
      child: Center(
        child: Text(
          '${step + 1}',
          style: TextStyle(color: active ? Colors.white : Colors.white.withOpacity(0.3), fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ),
    );
  }

  Widget _stepLine(int step, int current) => Expanded(
    child: Container(
      height: 2,
      color: step < current ? accentColor : Colors.white.withOpacity(0.1),
    ),
  );

  Widget _buildSummaryStep() {
    final price = _selectedTier == 'premium' ? premiumPrice : basicPrice;
    final color = _selectedTier == 'premium' ? amberColor : Colors.blueAccent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
      Container(
      width: double.infinity, padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color.withOpacity(0.2), color.withOpacity(0.05)]),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_selectedTier == 'premium' ? '💎 Premium Shop' : '✓ Basic Shop',
                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15, fontFamily: 'Siemreap')),
            const SizedBox(height: 4),
            const Text('ទិញម្ដងប្រើអស់មួយជីវិត', style: TextStyle(color: Colors.white38, fontSize: 11, fontFamily: 'Siemreap')),
          ]),
          Text('${formatter.format(price)} ៛', style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.bold)),
        ],
      ),
    ),
    const SizedBox(height: 20),
    _infoCard([
    _infoRow('👤 ឈ្មោះអ្នកលក់', _currentUserName ?? '—'),
    _infoRow('📱 លេខទូរស័ព្ទ', _currentPhone ?? '—'),
    _infoRow('🏪 ឈ្មោះហាង', _currentShopName ?? '—'),
    ]),
    if (_selectedTier == 'premium') ...[
    const SizedBox(height: 12),
    _buildNameStatus(),
    const SizedBox(height: 12),
    Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
    color: amberColor.withOpacity(0.08),borderRadius: BorderRadius.circular(10),
      border: Border.all(color: amberColor.withOpacity(0.25)),
    ),
      child: const Row(children: [
        Icon(Icons.info_outline, color: Colors.amber, size: 16),
        SizedBox(width: 8),
        Expanded(
          child: Text('ឈ្មោះហាងនឹងក្លាយជាកម្មសិទ្ធិផ្ដាច់របស់អ្នក',
              style: TextStyle(color: Colors.amber, fontSize: 12, fontFamily: 'Siemreap')),
        ),
      ]),
    ),
    ],
      ],
    );
  }

  Widget _infoCard(List<Widget> children) => Container(
    width: double.infinity, padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.04),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.white.withOpacity(0.08)),
    ),
    child: Column(children: children),
  );

  Widget _infoRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(children: [
      Text(label, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13, fontFamily: 'Siemreap')),
      const SizedBox(width: 8),
      Expanded(
        child: Text(value, textAlign: TextAlign.right,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13, fontFamily: 'Siemreap')),
      ),
    ]),
  );

  Widget _buildNameStatus() {
    if (_isCheckingName)
      return Row(children: [
        const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white38)),
        const SizedBox(width: 8),
        Text('កំពុងពិនិត្យ...', style: TextStyle(color: Colors.white.withOpacity(0.5), fontFamily: 'Siemreap')),
      ]);
    if (_nameCheckError != null) return _statusRow(Icons.error_outline, _nameCheckError!, redColor);
    if (_isNameAvailable == true) return _statusRow(Icons.check_circle_outline, 'ឈ្មោះហាងអាចប្រើបាន', greenColor);
    return const SizedBox.shrink();
  }

  Widget _statusRow(IconData icon, String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
    child: Row(children: [
      Icon(icon, color: color, size: 16), const SizedBox(width: 6),
      Text(text, style: TextStyle(color: color, fontSize: 12, fontFamily: 'Siemreap')),
    ]),
  );

  Widget _buildPaymentStep(BuildContext rootContext) {
    final price = _selectedTier == 'premium' ? premiumPrice : basicPrice;
    final color = _selectedTier == 'premium' ? amberColor : Colors.blueAccent;
    return Column(children: [
        Container(
        width: double.infinity, padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [color.withOpacity(0.18), color.withOpacity(0.04)]),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.35)),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('ចំនួនទឹកប្រាក់', style: TextStyle(color: Colors.white38, fontSize: 11, fontFamily: 'Siemreap')),
              const SizedBox(height: 4),
              Text('${formatter.format(price)} ៛', style: TextStyle(color: color, fontSize: 26, fontWeight: FontWeight.bold)),
            ]),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),child: Text(_selectedTier == 'premium' ? 'Premium' : 'Basic', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
        ),
        ]),
        ),
      const SizedBox(height: 20),
      const Text('QR Code បង់ប្រាក់', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Siemreap')),
      const SizedBox(height: 4),
      Text('សង្កត់ជាប់ដើម្បីទាញ QR', style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 11)),
      const SizedBox(height: 14),
      GestureDetector(
        onLongPress: () => _downloadQR(rootContext),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: color.withOpacity(0.2), blurRadius: 20, spreadRadius: -5)],
          ),
          padding: const EdgeInsets.all(12),
          child: Image.asset('assets/aba_qr.png', height: 170, fit: BoxFit.contain,
              errorBuilder: (c, e, s) => const SizedBox(height: 170, child: Center(child: Icon(Icons.qr_code_2, size: 100, color: Colors.black38)))),
        ),
      ),
      const SizedBox(height: 16),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _launchABA,
          icon: const Icon(Icons.open_in_new, size: 18),
          label: const Text('បើក App ABA', style: TextStyle(fontFamily: 'Siemreap')),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF005D7E),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 13),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    ]);
  }

  Widget _buildUploadStep(StateSetter setModalState) => Column(children: [
  Container(
  padding: const EdgeInsets.all(14), margin: const EdgeInsets.only(bottom: 16),
  decoration: BoxDecoration(
  color: greenColor.withOpacity(0.08),
  borderRadius: BorderRadius.circular(12),
  border: Border.all(color: greenColor.withOpacity(0.3)),
  ),
  child: const Row(children: [
  Icon(Icons.check_circle_outline, color: Color(0xFF00C48C), size: 18),
  SizedBox(width: 10),
  Expanded(
  child: Text('ភ្ជាប់រូបថតវិក្កយបត្របង់ប្រាក់', style: TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'Siemreap')),
  ),
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
  border: Border.all(
  color: _receiptImage != null ? greenColor.withOpacity(0.5) : Colors.white.withOpacity(0.12),
  width: _receiptImage != null ? 2 : 1,
  ),
  ),
  child: _receiptImage == null
  ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
  Icon(Icons.add_a_photo_outlined, color: Colors.white.withOpacity(0.3), size: 44),
  const SizedBox(height: 10),
  Text('ចុចដើម្បីជ្រើសរូបភាព', style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 13, fontFamily: 'Siemreap')),
  ])
      : ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.file(_receiptImage!, fit: BoxFit.cover)),),
  ),
    if (_receiptImage != null)
      TextButton.icon(
        onPressed: () => setModalState(() => _receiptImage = null),
        icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
        label: const Text('លុបចេញ', style: TextStyle(color: Colors.redAccent, fontFamily: 'Siemreap')),
      ),
  ]);

  @override
  Widget build(BuildContext context) {
    final bool canSelectBasic = _currentShopTier == null;
    final bool canSelectPremium = _currentShopTier != 'premium';
    final bool canPurchase = _selectedTier != null && (_selectedTier != 'premium' || _isNameAvailable == true);
    final bool alreadyPremium = _currentShopTier == 'premium';
    final price = _selectedTier == 'premium' ? premiumPrice : basicPrice;

    return Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          title: const Text('ដំឡើងហាង', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
          backgroundColor: Colors.transparent, elevation: 0,
          leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white), onPressed: () => Navigator.pop(context)),
        ),
        body: _isLoadingUser
            ? _buildShimmer()
            : SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _buildHeroBanner(),
            const SizedBox(height: 28),
            _sectionLabel('ជ្រើសកញ្ចប់'),
            const SizedBox(height: 14),
            _buildTierCard(
              tier: 'basic', title: 'Basic Shop', subtitle: 'ល្អសម្រាប់ហាងដំបូង',
              price: basicPrice, color: Colors.blueAccent, icon: Icons.verified_user_rounded,
              benefits: const ['ផ្លាក Blue Verify ✓', 'ស្ថិតិអ្នកចូលមើលហាង', 'បញ្ជីអ្នក Follow'],
              enabled: canSelectBasic,
              statusLabel: _currentShopTier == 'basic' ? 'ទិញរួច' : _currentShopTier == 'premium' ? 'មាន Premium' : null,
            ),
            const SizedBox(height: 14),
            _buildTierCard(
              tier: 'premium', title: 'Premium Shop', subtitle: 'ហាងពេញលេញ + ឈ្មោះផ្ដាច់',
              price: premiumPrice, color: amberColor, icon: Icons.diamond_rounded,
              benefits: const ['ផ្លាក Gold Verify ✓', 'ស្ថិតិ + អ្នក Follow', 'Event Space លើហាង', 'ភាពជាម្ចាស់ឈ្មោះហាង'],
              showShopNameStatus: true, enabled: canSelectPremium,
              statusLabel: _currentShopTier == 'premium' ? 'មានរួច' : null, isBestValue: true,
            ),
            const SizedBox(height: 28),
            if (alreadyPremium)
        _buildAlreadyPremiumCard()
    else ...[
    SizedBox(
    width: double.infinity, height: 56,
    child: ElevatedButton.icon(
    style: ElevatedButton.styleFrom(
    backgroundColor: canPurchase
    ? (_selectedTier == 'premium' ? amberColor : accentColor)
        : Colors.white.withOpacity(0.08),
    foregroundColor: canPurchase ? Colors.white : Colors.white38,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    elevation: canPurchase ? 5 : 0,
    shadowColor: canPurchase
    ? (_selectedTier == 'premium' ? amberColor.withOpacity(0.4) : accentColor.withOpacity(0.4))
        : Colors.transparent,
    ),
    onPressed: canPurchase ? () => _showPurchaseDialog(context) : null,icon: Icon(canPurchase ? Icons.shopping_cart_checkout_rounded : Icons.touch_app_outlined, size: 20),
      label: Text(
        _selectedTier == null
            ? 'ជ្រើសកញ្ចប់ខាងលើ'
            : (_selectedTier == 'premium' && _isNameAvailable == false
            ? 'ឈ្មោះហាងមិនទំនេរ'
            : 'ទិញ${_selectedTier == 'premium' ? ' Premium' : ' Basic'} · ${formatter.format(price)} ៛'),
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, fontFamily: 'Siemreap'),
      ),
    ),
    ),
              if (_selectedTier == null) ...[
                const SizedBox(height: 10),
                Center(child: Text('👆 ជ្រើសកញ្ចប់ Basic ឬ Premium', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12, fontFamily: 'Siemreap'))),
              ],
            ],
            ]),
        ),
    );
  }

  Widget _buildHeroBanner() {
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [amberColor.withOpacity(0.22), Colors.orange.withOpacity(0.08)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: amberColor.withOpacity(0.35)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: amberColor.withOpacity(0.15), borderRadius: BorderRadius.circular(16)),
          child: const Icon(Icons.store_mall_directory_rounded, color: amberColor, size: 32),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('ដំឡើងហាងរបស់អ្នក', style: TextStyle(color: Colors.amber, fontSize: 17, fontWeight: FontWeight.bold, fontFamily: 'Siemreap')),
            const SizedBox(height: 5),
            Text('ទិញម្ដង ✦ ប្រើអស់មួយជីវិត ✦ គ្មានថ្លៃប្រចាំខែ', style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 12, fontFamily: 'Siemreap')),
            const SizedBox(height: 10),
            if (_currentShopName != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
                child: Text('🏪 ${_currentShopName}', style: const TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'Siemreap')),
              ),
          ]),
        ),
      ]),
    );
  }

  Widget _sectionLabel(String text) => Row(children: [
    Container(width: 4, height: 18, decoration: BoxDecoration(color: amberColor, borderRadius: BorderRadius.circular(2))),
    const SizedBox(width: 8),
    Text(text, style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Siemreap')),
  ]);

  Widget _buildTierCard({
    required String tier, required String title, required String subtitle, required int price,
    required Color color, required IconData icon, required List<String> benefits,
    bool showShopNameStatus = false, bool enabled = true, String? statusLabel, bool isBestValue = false,
  }) {
    final isSelected = _selectedTier == tier;
    return GestureDetector(
        onTap: (enabled && !isSelected) ? () => _onTierSelected(tier) : null,
        child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isSelected ? color.withOpacity(0.1) : Colors.white.withOpacity(0.03),borderRadius: BorderRadius.circular(18),
              border: Border.all(color: isSelected ? color : Colors.white.withOpacity(0.09), width: isSelected ? 2 : 1),
              boxShadow: isSelected ? [BoxShadow(color: color.withOpacity(0.2), blurRadius: 20, spreadRadius: -5, offset: const Offset(0, 6))] : null,
            ),
            child: Stack(children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: enabled ? color.withOpacity(0.15) : Colors.grey.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                      child: Icon(icon, color: enabled ? color : Colors.grey, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(title, style: TextStyle(color: enabled ? color : Colors.grey, fontWeight: FontWeight.bold, fontSize: 15, fontFamily: 'Siemreap')),
                        Text(subtitle, style: TextStyle(color: enabled ? Colors.white.withOpacity(0.45) : Colors.grey.withOpacity(0.5), fontSize: 11, fontFamily: 'Siemreap')),
                      ]),
                    ),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text('${formatter.format(price)} ៛', style: TextStyle(color: enabled ? color : Colors.grey, fontSize: 15, fontWeight: FontWeight.bold)),
                      Text('ម្ដងអស់ជីវិត', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 9, fontFamily: 'Siemreap')),
                    ]),
                  ]),
                  const SizedBox(height: 14),
                  Divider(color: Colors.white.withOpacity(0.07)),
                  const SizedBox(height: 10),
                  ...benefits.map((b) => Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: Row(children: [
                      Icon(Icons.check_circle_rounded, color: enabled ? color : Colors.grey, size: 15),
                      const SizedBox(width: 8),
                      Text(b, style: TextStyle(color: enabled ? Colors.white70 : Colors.grey, fontSize: 13, fontFamily: 'Siemreap')),
                    ]),
                  )),
                  if (showShopNameStatus && isSelected && enabled) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(10)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          const Icon(Icons.store_rounded, color: Colors.white38, size: 15), const SizedBox(width: 6),
                          Text('ឈ្មោះហាង: ', style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 12, fontFamily: 'Siemreap')),
                          Expanded(child: Text(_currentShopName ?? '—', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12, fontFamily: 'Siemreap'))),
                        ]),
                        const SizedBox(height: 8),
                        _buildNameStatus(),
                      ]),
                    ),
                  ],
                ]),
            Positioned(
              top: 0, right: 0,
              child: enabled
                  ? Icon(isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                  color: isSelected ? color : Colors.white.withOpacity(0.2), size: 22)
                  : const Icon(Icons.lock_rounded, color: Colors.grey, size: 18),
            ),
            if (statusLabel != null)
        Positioned(
        bottom: 0, right: 0,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),decoration: BoxDecoration(
          color: enabled ? greenColor.withOpacity(0.85) : Colors.orange.withOpacity(0.8),
          borderRadius: BorderRadius.circular(10),
        ),
          child: Text(statusLabel, style: const TextStyle(color: Colors.white, fontSize: 10, fontFamily: 'Siemreap', fontWeight: FontWeight.bold)),
        ),
        ),
              if (isBestValue && enabled && !isSelected)
                Positioned(
                  top: -2, left: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(color: amberColor, borderRadius: BorderRadius.circular(8)),
                    child: const Text('⭐ Best Value', style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ),
            ]),
        ),
    );
  }

  Widget _buildAlreadyPremiumCard() {
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [amberColor.withOpacity(0.18), amberColor.withOpacity(0.05)]),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: amberColor.withOpacity(0.4)),
        boxShadow: [BoxShadow(color: amberColor.withOpacity(0.15), blurRadius: 20, spreadRadius: -5)],
      ),
      child: Column(children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: amberColor.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.workspace_premium_rounded, color: amberColor, size: 24),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Premium Shop · Active', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 15, fontFamily: 'Siemreap')),
              Text('ឈ្មោះហាងត្រូវបានការពារ', style: TextStyle(color: Colors.white38, fontSize: 11, fontFamily: 'Siemreap')),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: greenColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: greenColor.withOpacity(0.4)),
            ),
            child: const Text('✓ ACTIVE', style: TextStyle(color: Color(0xFF00C48C), fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ]),
        const SizedBox(height: 16),
        Divider(color: Colors.white.withOpacity(0.08)),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => _showSnack('មុខងារផ្ទេរកម្មសិទ្ធិកំពុងអភិវឌ្ឍន៍', isError: false),
          icon: const Icon(Icons.swap_horiz_rounded, color: Colors.white54, size: 18),
          label: const Text('ផ្ទេរកម្មសិទ្ធិហាង', style: TextStyle(color: Colors.white60, fontFamily: 'Siemreap')),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: Colors.white.withOpacity(0.15)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          ),
        ),
      ]),
    );
  }

  Widget _buildShimmer() {
    return Shimmer.fromColors(
        baseColor: const Color(0xFF1A1F3D),
        highlightColor: const Color(0xFF2A2F4D),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(children: [
              Container(height: 100, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20))),const SizedBox(height: 20),
            Container(height: 160, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18))),
            const SizedBox(height: 14),
            Container(height: 190, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18))),
          ]),
        ),
    );
  }
}