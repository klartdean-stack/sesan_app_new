import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:my_app/download_helper.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_compress/video_compress.dart';
import 'package:video_player/video_player.dart';
import 'package:get/get.dart';
import 'package:my_app/upload_controller.dart';

class AuctionAddScreen extends StatefulWidget {
  const AuctionAddScreen({super.key});

  @override
  State<AuctionAddScreen> createState() => _AuctionAddScreenState();
}

class _AuctionAddScreenState extends State<AuctionAddScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  String _t(String km, String en) =>
      Localizations.localeOf(context).languageCode == 'en' ? en : km;

  final _productNameCtrl = TextEditingController();
  final _startPriceCtrl = TextEditingController();
  final _bidStepCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final UploadController _uploadController = Get.put(UploadController());

  List<File> _productImages = [];
  File? _productVideo;
  File? _paymentImage;
  DateTime? _endDate;
  bool _isProcessing = false;
  int _currentStep = 0;
  String? _selectedPackage;
  bool isLoader = false;
  VideoPlayerController? _videoPreviewController;
  bool _isPickingImage = false;
  bool _isVideoPreviewReady = false;
  OverlayEntry? _overlayEntry;

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  static const _bg = Color(0xFFF7FAF7);
  static const _card = Colors.white;
  static const _border = Color(0xFFDDE8DF);
  static const _accent = Color(0xFF2E7D32);
  static const _accentBlue = Color(0xFFF57C00);
  static const _text = Color(0xFF1F2933);
  static const _textMuted = Color(0xFF6B7280);
  static const _red = Color(0xFFD32F2F);

  List<Map<String, dynamic>> get _packages => [
    {
      'key': 'basic',
      'label': _t('កញ្ចប់ធម្មតា', 'Basic package'),
      'price': 10000,
      'duration': _t('24 ម៉ោង', '24 hours'),
      'icon': Icons.local_offer_outlined,
      'color': _accent,
      'features': [
        _t('បង្ហាញក្នុង Feed', 'Shown in Feed'),
        _t('រូបភាព ៤ សន្លឹក', '4 photos'),
        _t('Support ជាមូលដ្ឋាន', 'Basic support'),
      ],
    },
  ];

  @override
  void initState() {
    super.initState();
    _selectedPackage = 'basic';
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _overlayEntry?.remove();
    _videoPreviewController?.dispose();
    _fadeCtrl.dispose();
    _productNameCtrl.dispose();
    _startPriceCtrl.dispose();
    _bidStepCtrl.dispose();
    _phoneCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  Future<void> _launchABA() async {
    final Uri _url = Uri.parse('https://pay.ababank.com/oRF8/oizn40j9');
    try {
      await launchUrl(_url, mode: LaunchMode.externalApplication);
    } catch (e) {
      await launchUrl(_url, mode: LaunchMode.platformDefault);
    }
  }

  // Android Build 46 parity: QR result above payment dialog
  void _showTopMessage(String message, {bool isError = false}) {
    final overlay = Overlay.of(context, rootOverlay: true);
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (overlayContext) => Positioned(
        top: MediaQuery.of(overlayContext).padding.top + 12,
        left: 16,
        right: 16,
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
      _showTopMessage(
        _t('✅ បានរក្សាទុកក្នុង Gallery រួចរាល់!', '✅ Saved to Gallery!'),
      );
    } catch (e) {
      if (!mounted) return;
      _showTopMessage(
        _t('❌ មិនអាចរក្សាទុកបាន: $e', '❌ Could not save: $e'),
        isError: true,
      );
    }
  }

  Future<void> _pickProductImages() async {
    if (_isPickingImage) return;
    if (_productImages.length >= 8) {
      _showErrorSnack(_t('គ្រប់ 8 សន្លឹកហើយ!', 'Maximum 8 photos reached!'));
      return;
    }
    try {
      setState(() => _isPickingImage = true);
      final picker = ImagePicker();
      final files = await picker.pickMultiImage(imageQuality: 85);
      if (files.isEmpty) return;
      final remaining = 8 - _productImages.length;
      final toAdd = files.take(remaining).toList();
      setState(() {
        _productImages.addAll(toAdd.map((f) => File(f.path)));
      });
      if (_productImages.length >= 8) {
        _showErrorSnack(_t('គ្រប់ 8 សន្លឹកហើយ!', 'Maximum 8 photos reached!'));
      }
    } finally {
      if (mounted) setState(() => _isPickingImage = false);
    }
  }

  Future<void> _pickProductVideo() async {
    if (_isPickingImage) return;
    try {
      setState(() => _isPickingImage = true);
      final picker = ImagePicker();
      final XFile? pickedVideo = await picker.pickVideo(
        source: ImageSource.gallery,
      );
      if (pickedVideo == null) return;
      setState(() {
        _productVideo = File(pickedVideo.path);
        _isVideoPreviewReady = false;
      });
      _initVideoPreview();
      _showSuccessSnack(
        _t('បានជ្រើសរើសវីដេអូជោគជ័យ', 'Video selected successfully'),
      );
    } finally {
      if (mounted) setState(() => _isPickingImage = false);
    }
  }

  void _initVideoPreview() {
    _videoPreviewController?.dispose();
    if (_productVideo != null) {
      _videoPreviewController = VideoPlayerController.file(_productVideo!)
        ..initialize().then((_) {
          if (mounted) setState(() => _isVideoPreviewReady = true);
        });
    }
  }

  Future<void> _pickPaymentImage({StateSetter? dialogSetState}) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (file != null) {
      final f = File(file.path);
      setState(() => _paymentImage = f);
      dialogSetState?.call(() {});
    }
  }

  Future<String?> _uploadFile(File file, String folder) async {
    try {
      final name =
          '${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
      final ref = FirebaseStorage.instance.ref().child(folder).child(name);
      await ref.putFile(file);
      return await ref.getDownloadURL();
    } catch (_) {
      return null;
    }
  }

  Future<void> _submitAuction() async {
    if (_isProcessing) return;

    if (_productNameCtrl.text.isEmpty || _startPriceCtrl.text.isEmpty) {
      _showErrorSnack(
        _t(
          '❌ សូមបំពេញព័ត៌មានឱ្យបានគ្រប់គ្រាន់',
          '❌ Please complete the required information',
        ),
      );
      return;
    }

    Navigator.of(context, rootNavigator: true).pop();
    Navigator.of(context).pop();

    _uploadController.isUploading.value = true;
    _uploadController.uploadProgress.value = 0.05;

    try {
      final prefs = await SharedPreferences.getInstance();
      String ownerId = prefs.getString('user_uid') ?? '';
      String ownerName = prefs.getString('user_name') ?? 'Sesan User';
      String ownerPhoto = prefs.getString('user_photo') ?? '';

      if (ownerId.isEmpty) {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          ownerId = currentUser.uid;
          ownerName = currentUser.displayName ?? ownerName;
          ownerPhoto = currentUser.photoURL ?? ownerPhoto;
        }
      }

      String? videoUrl;
      if (_productVideo != null) {
        _uploadController.uploadProgress.value = 0.1;
        videoUrl = await _uploadFile(_productVideo!, 'auction_videos');
      }

      final List<String> productUrls = [];
      for (int i = 0; i < _productImages.length; i++) {
        _uploadController.uploadProgress.value =
            0.1 + ((i + 1) / _productImages.length * 0.5);
        final url = await _uploadFile(_productImages[i], 'auction_products');
        if (url != null) productUrls.add(url);
      }

      String? paymentUrl;
      if (_paymentImage != null) {
        _uploadController.uploadProgress.value = 0.8;
        paymentUrl = await _uploadFile(_paymentImage!, 'auction_payments');
      }

      _uploadController.uploadProgress.value = 0.95;

      await FirebaseFirestore.instance.collection('auction_products').add({
        'product_name': _productNameCtrl.text.trim(),
        'description': _descriptionCtrl.text.trim(),
        'start_price': int.parse(_startPriceCtrl.text.replaceAll(',', '')),
        'bid_step': int.parse(_bidStepCtrl.text.replaceAll(',', '')),
        'customer_phone': _phoneCtrl.text.trim(),
        'end_time': _endDate != null ? Timestamp.fromDate(_endDate!) : null,
        'video_url': videoUrl,
        'image_urls': productUrls,
        'payment_image_url': paymentUrl,
        'selected_package': _selectedPackage,
        'status': 'pending',
        'owner_id': ownerId,
        'owner_name': ownerName,
        'owner_photo': ownerPhoto,
        'created_at': FieldValue.serverTimestamp(),
      });

      _uploadController.uploadProgress.value = 1.0;
      _showSuccessSnack(
        _t(
          '🎉 បញ្ជូនការដេញថ្លៃជោគជ័យ!',
          '🎉 Auction request submitted successfully!',
        ),
      );
    } catch (e) {
      _uploadController.uploadProgress.value = 0.0;
      _showErrorSnack(_t('❌ មានបញ្ហា: $e', '❌ Error: $e'));
    } finally {
      _uploadController.isUploading.value = false;
      Future.delayed(const Duration(seconds: 3), () {
        _uploadController.uploadProgress.value = 0.0;
      });
    }
  }

  String? _validateRequired(String? v) => (v == null || v.trim().isEmpty)
      ? _t('សូមបំពេញព័ត៌មាននេះ', 'Please fill in this field')
      : null;

  String? _validateNumber(String? v) {
    if (v == null || v.trim().isEmpty)
      return _t('សូមបំពេញលេខ', 'Please enter a number');
    final n = int.tryParse(v.replaceAll(',', ''));
    if (n == null || n <= 0)
      return _t('សូមបញ្ចូលលេខត្រឹមត្រូវ', 'Please enter a valid number');
    return null;
  }

  bool get _step0Valid =>
      _productNameCtrl.text.isNotEmpty && _productImages.isNotEmpty;
  bool get _step1Valid =>
      _validateNumber(_startPriceCtrl.text) == null &&
      _validateNumber(_bidStepCtrl.text) == null &&
      _endDate != null;

  void _nextStep() {
    if (_currentStep == 0 && !_step0Valid) {
      _showErrorSnack(
        _t(
          'សូមបំពេញឈ្មោះទំនិញ និងរូបភាព',
          'Please add a product name and photos',
        ),
      );
      return;
    }
    if (_currentStep == 1 && !_step1Valid) {
      _showErrorSnack(
        _t(
          'សូមបំពេញតម្លៃ និងថ្ងៃបញ្ចប់',
          'Please enter prices and an end date',
        ),
      );
      return;
    }
    if (_currentStep == 1 && _selectedPackage == null) {
      _showErrorSnack(
        _t('សូមជ្រើសរើសកញ្ចប់សេវា', 'Please select a service package'),
      );
      return;
    }
    if (_currentStep == 0) {
      setState(() => _currentStep = 1);
      _fadeCtrl
        ..reset()
        ..forward();
    } else {
      _showPaymentDialog();
    }
  }

  void _showSuccessSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: _accent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showErrorSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: _red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showProgressOverlay(String message, double progress) {
    _overlayEntry?.remove();
    if (!mounted) return;

    _overlayEntry = OverlayEntry(
      builder: (ctx) => Positioned(
        top: MediaQuery.of(context).padding.top,
        left: 0,
        right: 0,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFF1B5E20),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontFamily: 'Siemreap',
                    ),
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.green[900],
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Colors.white,
                      ),
                      minHeight: 4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideProgressOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Future<void> _selectEndDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (ctx, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(
            primary: _accent,
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: _text,
          ),
        ),
        child: child!,
      ),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (ctx, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(
            primary: _accent,
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: _text,
          ),
        ),
        child: child!,
      ),
    );
    if (time == null) return;
    setState(() {
      _endDate = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: _buildAppBar(),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: Obx(
          () => Stack(
            children: [
              Column(
                children: [
                  _buildStepIndicator(),
                  Expanded(
                    child: FadeTransition(
                      opacity: _fadeAnim,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        child: Form(key: _formKey, child: _buildCurrentStep()),
                      ),
                    ),
                  ),
                  _buildBottomBar(),
                ],
              ),
              if (_uploadController.isUploading.value)
                Positioned(
                  top: MediaQuery.of(context).padding.top,
                  left: 0,
                  right: 0,
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: const BoxDecoration(
                        color: Color(0xFF1B5E20),
                        borderRadius: BorderRadius.vertical(
                          bottom: Radius.circular(12),
                        ),
                      ),
                      child: SafeArea(
                        bottom: false,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _t(
                                'កំពុងបញ្ជូន... ${(_uploadController.uploadProgress.value * 100).toInt()}%',
                                'Uploading... ${(_uploadController.uploadProgress.value * 100).toInt()}%',
                              ),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontFamily: 'Siemreap',
                              ),
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: LinearProgressIndicator(
                                value: _uploadController.uploadProgress.value,
                                backgroundColor: Colors.green[900],
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                                minHeight: 6,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _bg,
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          color: _text,
          size: 20,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        _t('ដាក់ដេញថ្លៃទំនិញ', 'Add auction'),
        style: TextStyle(
          color: _text,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          fontFamily: 'Siemreap',
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: _border, height: 1),
      ),
    );
  }

  Widget _buildStepIndicator() {
    final steps = [
      _t('ទំនិញ', 'Product'),
      _t('តម្លៃ និងសេវា', 'Price & service'),
    ];
    return Container(
      color: _bg,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: List.generate(steps.length * 2 - 1, (i) {
          if (i.isOdd) {
            final done = _currentStep > i ~/ 2;
            return Expanded(
              child: Container(
                height: 2,
                decoration: BoxDecoration(
                  gradient: done
                      ? const LinearGradient(colors: [_accent, _accent])
                      : null,
                  color: done ? null : _border,
                ),
              ),
            );
          }
          final idx = i ~/ 2;
          final isActive = _currentStep == idx;
          final isDone = _currentStep > idx;
          return Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDone
                      ? _accent
                      : isActive
                      ? _accent
                      : _card,
                  border: Border.all(
                    color: isDone
                        ? _accent
                        : isActive
                        ? _accent
                        : _border,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: isDone
                      ? const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 18,
                        )
                      : Text(
                          '${idx + 1}',
                          style: TextStyle(
                            color: isActive ? Colors.white : _textMuted,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                steps[idx],
                style: TextStyle(
                  color: isActive ? _text : _textMuted,
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                  fontFamily: 'Siemreap',
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildStep0();
      case 1:
        return Column(children: [_buildStep1(), _buildStep2()]);
      default:
        return const SizedBox();
    }
  }

  Widget _buildStep0() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          '📦',
          _t('ព័ត៌មានទំនិញ', 'Product information'),
          _t('បំពេញព័ត៌មានអំពីទំនិញ', 'Add details about your product'),
        ),
        const SizedBox(height: 20),
        _buildLabel(
          _t(
            'វីដេអូបង្ហាញទំនិញ (អតិបរមា ៩០វិនាទី) *',
            'Product video (max 90 seconds) *',
          ),
        ),
        const SizedBox(height: 8),
        _buildVideoPicker(),
        const SizedBox(height: 20),
        _buildLabel(
          _t('រូបភាពទំនិញ (ដល់ ៨ សន្លឹក) *', 'Product photos (up to 8) *'),
        ),
        const SizedBox(height: 8),
        _buildImagePicker(),
        const SizedBox(height: 8),
        _buildLabel(_t('ឈ្មោះទំនិញ *', 'Product name *')),
        const SizedBox(height: 8),
        _buildTextField(
          controller: _productNameCtrl,
          hint: Get.locale?.languageCode == 'km'
              ? 'ឧ. ត្រាក់ទ័រខ្នាតតូចសម្រាប់ស្រែ'
              : 'e.g. Rice micro-tractor',
          icon: Icons.shopping_bag_outlined,
          validator: _validateRequired,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        _buildLabel(_t('ការរៀបរាប់', 'Description')),
        const SizedBox(height: 8),
        _buildTextField(
          controller: _descriptionCtrl,
          hint: _t(
            'ពិព័រណ៍អំពីស្ថានភាព លក្ខណៈពិសេស...',
            'Describe the condition and key features...',
          ),
          icon: Icons.description_outlined,
          keyboard: TextInputType.multiline,
          textInputAction: TextInputAction.newline,
          maxLines: 4,
        ),
        const SizedBox(height: 16),
        _buildLabel(_t('លេខទូរស័ព្ទ *', 'Phone number *')),
        const SizedBox(height: 8),
        _buildTextField(
          controller: _phoneCtrl,
          hint: '0XX XXX XXX',
          icon: Icons.phone_outlined,
          keyboard: TextInputType.phone,
          validator: _validateRequired,
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildVideoPicker() {
    return GestureDetector(
      onTap: _productVideo == null ? _pickProductVideo : null,
      child: Container(
        height: 120,
        width: double.infinity,
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _productVideo != null ? _accent : _border),
        ),
        child: _productVideo == null
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.video_call_rounded, color: _accentBlue),
                  SizedBox(width: 10),
                  Text(
                    _t('ចុចដើម្បីបន្ថែមវីដេអូ', 'Tap to add video'),
                    style: TextStyle(
                      color: _accentBlue,
                      fontFamily: 'Siemreap',
                    ),
                  ),
                ],
              )
            : Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child:
                        _isVideoPreviewReady && _videoPreviewController != null
                        ? SizedBox.expand(
                            child: FittedBox(
                              fit: BoxFit.cover,
                              child: SizedBox(
                                width:
                                    _videoPreviewController!.value.size.width,
                                height:
                                    _videoPreviewController!.value.size.height,
                                child: VideoPlayer(_videoPreviewController!),
                              ),
                            ),
                          )
                        : Container(
                            color: Colors.black,
                            child: const Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                  ),
                  if (_isVideoPreviewReady)
                    Positioned.fill(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _videoPreviewController!.value.isPlaying
                                ? _videoPreviewController!.pause()
                                : _videoPreviewController!.play();
                          });
                        },
                        child: Center(
                          child: Icon(
                            _videoPreviewController!.value.isPlaying
                                ? Icons.pause_circle_filled
                                : Icons.play_circle_fill,
                            color: Colors.white70,
                            size: 40,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: GestureDetector(
                      onTap: () {
                        _videoPreviewController?.dispose();
                        setState(() {
                          _productVideo = null;
                          _isVideoPreviewReady = false;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildImagePicker() {
    return GestureDetector(
      onTap: _productImages.length >= 8 ? null : _pickProductImages,
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _productImages.length >= 8 ? _border : _accentBlue,
            width: 2,
          ),
        ),
        child: _productImages.isEmpty
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _accentBlue.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.add_photo_alternate_outlined,
                      color: _accentBlue,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _t('ចុចដើម្បីបន្ថែមរូបភាព', 'Tap to add photos'),
                    style: TextStyle(
                      color: _accentBlue,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _t('រើសបានច្រើនបំផុត 8 សន្លឹក', 'Choose up to 8 photos'),
                    style: TextStyle(color: _textMuted, fontSize: 12),
                  ),
                ],
              )
            : ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(8),
                itemCount:
                    _productImages.length + (_productImages.length < 8 ? 1 : 0),
                itemBuilder: (ctx, i) {
                  if (i == _productImages.length) {
                    return GestureDetector(
                      onTap: _pickProductImages,
                      child: Container(
                        width: 90,
                        margin: const EdgeInsets.only(left: 8),
                        decoration: BoxDecoration(
                          color: _accentBlue.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _accentBlue.withOpacity(0.4),
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.add_rounded,
                              color: _accentBlue,
                              size: 24,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _t('បន្ថែម', 'Add'),
                              style: const TextStyle(
                                color: _accentBlue,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        _productImages[i],
                        width: 90,
                        height: 90,
                        fit: BoxFit.cover,
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          '💰',
          _t('តម្លៃ & ពេលវេលា', 'Price & time'),
          _t('កំណត់តម្លៃ និងពេលបញ្ចប់', 'Set the starting price and end time'),
        ),
        const SizedBox(height: 20),
        _buildLabel(_t('តម្លៃចាប់ផ្តើម (រៀល) *', 'Starting price (KHR) *')),
        const SizedBox(height: 8),
        _buildTextField(
          controller: _startPriceCtrl,
          hint: _t('ឧ. 50,000', 'e.g. 50,000'),
          icon: Icons.account_balance_wallet_rounded,
          keyboard: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            CurrencyInputFormatter(),
          ],
          suffix: '៛',
          validator: _validateNumber,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        _buildLabel(_t('ជំហានបង្កើនតម្លៃ (រៀល) *', 'Bid increment (KHR) *')),
        const SizedBox(height: 8),
        _buildTextField(
          controller: _bidStepCtrl,
          hint: _t('ឧ. 5000', 'e.g. 5,000'),
          icon: Icons.trending_up_rounded,
          keyboard: TextInputType.number,
          suffix: '៛',
          validator: _validateNumber,
          onChanged: (_) => setState(() {}),
        ),
        if (_startPriceCtrl.text.isNotEmpty && _bidStepCtrl.text.isNotEmpty)
          _buildPricePreview(),
        const SizedBox(height: 20),
        _buildLabel(_t('ថ្ងៃ & ម៉ោងបញ្ចប់ *', 'End date & time *')),
        const SizedBox(height: 8),
        _buildDateTile(),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildPricePreview() {
    final start = int.tryParse(_startPriceCtrl.text.replaceAll(',', '')) ?? 0;
    final step = int.tryParse(_bidStepCtrl.text.replaceAll(',', '')) ?? 0;
    final fmt = NumberFormat('#,###');
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _accent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _accent.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _miniStat(
            _t('ដំបូង', 'Start'),
            '${fmt.format(start)} ៛',
            _accentBlue,
          ),
          Container(width: 1, height: 30, color: _border),
          _miniStat(
            _t('ដេញទី១', 'First bid'),
            '${fmt.format(start + step)} ៛',
            _accent,
          ),
          Container(width: 1, height: 30, color: _border),
          _miniStat('Step', '+${fmt.format(step)} ៛', const Color(0xFFFFB300)),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: _textMuted,
              fontSize: 11,
              fontFamily: 'Siemreap',
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateTile() {
    return GestureDetector(
      onTap: _selectEndDate,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _endDate != null ? _accent : _border,
            width: _endDate != null ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (_endDate != null ? _accent : _accentBlue).withOpacity(
                  0.12,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _endDate != null
                    ? Icons.event_available_rounded
                    : Icons.calendar_today_outlined,
                color: _endDate != null ? _accent : _accentBlue,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                _endDate == null
                    ? _t('ជ្រើសរើសថ្ងៃ និងម៉ោង', 'Select date and time')
                    : DateFormat('dd MMM yyyy · HH:mm').format(_endDate!),
                style: TextStyle(
                  color: _endDate == null ? _textMuted : _text,
                  fontSize: 14,
                  fontWeight: _endDate == null
                      ? FontWeight.normal
                      : FontWeight.w600,
                  fontFamily: 'Siemreap',
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: _textMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          '⭐',
          _t('ជ្រើសកញ្ចប់សេវា', 'Choose a service package'),
          _t(
            'ជ្រើសរើសកញ្ចប់ដែលស្របតាមការចង់បាន',
            'Choose the package that fits your needs',
          ),
        ),
        const SizedBox(height: 20),
        ...List.generate(_packages.length, (i) {
          final pkg = _packages[i];
          final isSelected = _selectedPackage == pkg['key'];
          final color = pkg['color'] as Color;
          return GestureDetector(
            onTap: () => setState(() => _selectedPackage = pkg['key']),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isSelected ? color.withOpacity(0.08) : _card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? color : _border,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      pkg['icon'] as IconData,
                      color: color,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                pkg['label'] as String,
                                style: TextStyle(
                                  color: isSelected ? color : _text,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'Siemreap',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          pkg['duration'] as String,
                          style: const TextStyle(
                            color: _textMuted,
                            fontSize: 12,
                            fontFamily: 'Siemreap',
                          ),
                        ),
                        const SizedBox(height: 10),
                        ...((pkg['features'] as List<String>).map(
                          (f) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.check_circle_outline_rounded,
                                  color: color,
                                  size: 14,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    f,
                                    style: const TextStyle(
                                      color: _textMuted,
                                      fontSize: 12,
                                      fontFamily: 'Siemreap',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        NumberFormat('#,###').format(pkg['price'] as int),
                        style: TextStyle(
                          color: color,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        _t('រៀល', 'KHR'),
                        style: TextStyle(
                          color: _textMuted,
                          fontSize: 11,
                          fontFamily: 'Siemreap',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 32),
      ],
    );
  }

  void _showPaymentDialog() {
    final selectedPkgData = _packages.firstWhere(
      (p) => p['key'] == _selectedPackage,
    );
    final total = selectedPkgData['price'] as int;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Container(
          decoration: const BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 32,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  _t('បង់សេវាដាក់ដេញថ្លៃ', 'Pay auction listing fee'),
                  style: TextStyle(
                    color: _text,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Siemreap',
                  ),
                ),
                const Divider(color: _border, height: 40),
                Text(
                  _t(
                    'ស្កេនបង់ប្រាក់មកកាន់ QR ខាងក្រោម',
                    'Scan the QR below to pay',
                  ),
                  style: TextStyle(color: _textMuted, fontFamily: 'Siemreap'),
                ),
                const SizedBox(height: 15),
                GestureDetector(
                  onLongPress: () async => await _downloadQR(),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(
                        'assets/aba_qr.png',
                        height: 160,
                        width: 160,
                        fit: BoxFit.contain,
                        errorBuilder: (c, e, s) => const Icon(
                          Icons.qr_code_2_rounded,
                          size: 80,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '${NumberFormat('#,###').format(total)} ៛',
                  style: const TextStyle(
                    fontSize: 26,
                    color: _accent,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _launchABA,
                  icon: const Icon(
                    Icons.account_balance_wallet,
                    color: Colors.white,
                  ),
                  label: Text(
                    _t(
                      'ចុចដើម្បីបង់ប្រាក់តាម App ABA',
                      'Tap to pay with ABA App',
                    ),
                    style: TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF005D7E),
                    minimumSize: const Size(double.infinity, 45),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                Text(
                  _t(
                    'បញ្ជាក់៖ សូមចុចសង្កត់លើ QR ដើម្បីរក្សាទុក រួចថតរូបវិក្កយបត្របញ្ចូលខាងក្រោម',
                    'Note: Long press the QR to save it, then attach your payment receipt below',
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: _textMuted,
                    fontFamily: 'Siemreap',
                  ),
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () => _pickPaymentImage(dialogSetState: setSheet),
                  child: Container(
                    height: 180,
                    width: 180,
                    decoration: BoxDecoration(
                      color: _bg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _paymentImage == null
                            ? _border
                            : _accent.withOpacity(0.5),
                        width: 2,
                      ),
                    ),
                    child: _paymentImage == null
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.add_a_photo_rounded,
                                size: 40,
                                color: _textMuted,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _t('ដាក់រូបវិក្កយបត្រ', 'Attach receipt'),
                                style: TextStyle(
                                  color: _textMuted,
                                  fontSize: 12,
                                  fontFamily: 'Siemreap',
                                ),
                              ),
                            ],
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.file(
                              _paymentImage!,
                              fit: BoxFit.contain,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 30),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    minimumSize: const Size(double.infinity, 55),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  onPressed: (isLoader || _paymentImage == null)
                      ? null
                      : () async {
                          FocusManager.instance.primaryFocus?.unfocus();
                          setSheet(() => isLoader = true);
                          try {
                            await _submitAuction();
                          } catch (e) {
                            if (ctx.mounted) {
                              setSheet(() => isLoader = false);
                            }
                            _showErrorSnack(
                              _t('បញ្ហាបច្ចេកទេស៖ $e', 'Technical error: $e'),
                            );
                          } finally {
                            if (ctx.mounted) {
                              setSheet(() => isLoader = false);
                            }
                          }
                        },
                  child: _isProcessing
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          _t('បញ្ជាក់ និងបញ្ជូនសំណើ', 'Confirm and submit'),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Siemreap',
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      decoration: const BoxDecoration(
        color: _bg,
        border: Border(top: BorderSide(color: _border)),
      ),
      child: SizedBox(
        height: 54,
        width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _accent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 0,
          ),
          onPressed: _nextStep,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _currentStep == 1
                    ? _t('បន្តការបង់ប្រាក់', 'Continue to payment')
                    : _t('បន្ទាប់', 'Next'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Siemreap',
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String emoji, String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Text(
              title,
              style: const TextStyle(
                color: _text,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                fontFamily: 'Siemreap',
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: const TextStyle(
            color: _textMuted,
            fontSize: 13,
            fontFamily: 'Siemreap',
          ),
        ),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: _text,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        fontFamily: 'Siemreap',
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboard = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    String? suffix,
    int maxLines = 1,
    TextInputAction? textInputAction,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      textInputAction: textInputAction,
      maxLines: maxLines,
      style: const TextStyle(color: _text, fontSize: 14),
      validator: validator,
      onChanged: onChanged,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          color: _textMuted,
          fontSize: 14,
          fontFamily: 'Siemreap',
        ),
        prefixIcon: Icon(icon, color: _textMuted, size: 20),
        suffixText: suffix,
        suffixStyle: const TextStyle(
          color: _textMuted,
          fontWeight: FontWeight.w600,
        ),
        filled: true,
        fillColor: _card,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _accentBlue, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _red),
        ),
        errorStyle: const TextStyle(
          color: _red,
          fontSize: 11,
          fontFamily: 'Siemreap',
        ),
      ),
    );
  }
}

class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.selection.baseOffset == 0) return newValue;
    double value = double.parse(newValue.text.replaceAll(',', ''));
    final formatter = NumberFormat('#,###');
    String newText = formatter.format(value);
    return newValue.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}
