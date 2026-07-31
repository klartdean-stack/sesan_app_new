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


  static const _bg = Color(0xFF0D1117);
  static const _card = Color(0xFF161B22);
  static const _border = Color(0xFF30363D);
  static const _accent = Color(0xFF238636);
  static const _accentBlue = Color(0xFF1F6FEB);
  static const _text = Color(0xFFE6EDF3);
  static const _textMuted = Color(0xFF8B949E);
  static const _red = Color(0xFFDA3633);


  final List<Map<String, dynamic>> _packages = [
    {
      'key': 'basic',
      'label': 'កញ្ចប់ធម្មតា',
      'price': 10000,
      'duration': '24 ម៉ោង',
      'icon': Icons.local_offer_outlined,
      'color': const Color(0xFF42A5F5),
      'features': ['បង្ហាញក្នុង Feed', 'រូបភាព ៤ សន្លឹក', 'Support ជាមូលដ្ឋាន'],
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
    final Uri _url = Uri.parse('https://pay.ababank.com/oRF8/lq8jgwzb');
    try {
      await launchUrl(_url, mode: LaunchMode.externalApplication);
    } catch (e) {
      await launchUrl(_url, mode: LaunchMode.platformDefault);
    }
  }


  Future<void> _downloadQR() async {
    try {
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
      _showSuccessSnack('✅ បានរក្សាទុកក្នុង Gallery រួចរាល់!');
    } catch (e) {
      _showErrorSnack('❌ មិនអាចរក្សាទុកបាន: $e');
    }
  }


  Future<void> _pickProductImages() async {
    if (_isPickingImage) return;
    if (_productImages.length >= 8) {
      _showErrorSnack('គ្រប់ 8 សន្លឹកហើយ!');
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
        _showErrorSnack('គ្រប់ 8 សន្លឹកហើយ!');
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
      _showSuccessSnack('បានជ្រើសរើសវីដេអូជោគជ័យ');
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
      _showErrorSnack('❌ សូមបំពេញព័ត៌មានឱ្យបានគ្រប់គ្រាន់');
      return;
    }


    // បិទ dialog
    Navigator.of(context, rootNavigator: true).pop();
    Navigator.of(context).pop();


    // បង្ហាញ Progress
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


      // Upload video
      String? videoUrl;
      if (_productVideo != null) {
        _uploadController.uploadProgress.value = 0.1;
        videoUrl = await _uploadFile(_productVideo!, 'auction_videos');
      }


      // Upload images
      final List<String> productUrls = [];
      for (int i = 0; i < _productImages.length; i++) {
        _uploadController.uploadProgress.value =
            0.1 + ((i + 1) / _productImages.length * 0.5);
        final url = await _uploadFile(_productImages[i], 'auction_products');
        if (url != null) productUrls.add(url);
      }


      // Upload payment
      String? paymentUrl;
      if (_paymentImage != null) {
        _uploadController.uploadProgress.value = 0.8;
        paymentUrl = await _uploadFile(_paymentImage!, 'auction_payments');
      }


      _uploadController.uploadProgress.value = 0.95;


      // 🎯 កែប្រែទៅកាន់ Collection ថ្មីដាច់ដោយឡែកសម្រាប់របស់ដេញថ្លៃ
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
        'status':
        'pending', // រក្សាទុក 'pending' ដដែល ដើម្បីឱ្យ Admin ពិនិត្យក្នុងទំព័រ Auction Admin
        'owner_id': ownerId,
        'owner_name': ownerName,
        'owner_photo': ownerPhoto,
        'created_at': FieldValue.serverTimestamp(),
      });


      _uploadController.uploadProgress.value = 1.0;
      _showSuccessSnack('🎉 បញ្ជូនការដេញថ្លៃជោគជ័យ!');
    } catch (e) {
      _uploadController.uploadProgress.value = 0.0;
      _showErrorSnack('❌ មានបញ្ហា: $e');
    } finally {
      _uploadController.isUploading.value = false;
      Future.delayed(const Duration(seconds: 3), () {
        _uploadController.uploadProgress.value = 0.0;
      });
    }
  }


  String? _validateRequired(String? v) =>
      (v == null || v.trim().isEmpty) ? 'សូមបំពេញព័ត៌មាននេះ' : null;


  String? _validateNumber(String? v) {
    if (v == null || v.trim().isEmpty) return 'សូមបំពេញលេខ';
    final n = int.tryParse(v.replaceAll(',', ''));
    if (n == null || n <= 0) return 'សូមបញ្ចូលលេខត្រឹមត្រូវ';
    return null;
  }


  bool get _step0Valid =>
      _productNameCtrl.text.isNotEmpty && _productImages.isNotEmpty;
  bool get _step1Valid =>
      _validateNumber(_startPriceCtrl.text) == null &&
          _validateNumber(_bidStepCtrl.text) == null &&
          _endDate != null;
  bool get _step2Valid => _selectedPackage != null;


  void _nextStep() {
    if (_currentStep == 0 && !_step0Valid) {
      _showErrorSnack('សូមបំពេញឈ្មោះទំនិញ និងរូបភាព');
      return;
    }
    if (_currentStep == 1 && !_step1Valid) {
      _showErrorSnack('សូមបំពេញតម្លៃ និងថ្ងៃបញ្ចប់');
      return;
    }
    if (_currentStep == 2 && !_step2Valid) {
      _showErrorSnack('សូមជ្រើសរើសកញ្ចប់សេវា');
      return;
    }
    if (_currentStep < 2) {
      setState(() => _currentStep++);
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
            decoration: BoxDecoration(
              color: const Color(0xFF1B5E20),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(12),
              ),
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
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: _accentBlue,
            surface: _card,
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
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: _accentBlue,
            surface: _card,
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
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B5E20),
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(12),
                        ),
                      ),
                      child: SafeArea(
                        bottom: false,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'កំពុងបញ្ជូន... ${(_uploadController.uploadProgress.value * 100).toInt()}%',
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


  // បន្ថែមមុខងារនេះដើម្បីបាត់ក្រហមត្រង់ជួរ 447
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
      title: const Text(
        'ដាក់ដេញថ្លៃទំនិញ',
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
    final steps = ['ទំនិញ', 'តម្លៃ', 'សេវា'];
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
                      ? const LinearGradient(colors: [_accentBlue, _accent])
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
                      ? _accentBlue
                      : _card,
                  border: Border.all(
                    color: isDone
                        ? _accent
                        : isActive
                        ? _accentBlue
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
        return _buildStep1();
      case 2:
        return _buildStep2();
      default:
        return const SizedBox();
    }
  }


  Widget _buildStep0() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('📦', 'ព័ត៌មានទំនិញ', 'បំពេញព័ត៌មានអំពីទំនិញ'),
        const SizedBox(height: 20),
        _buildLabel('វីដេអូបង្ហាញទំនិញ (អតិបរមា ៩០វិនាទី) *'),
        const SizedBox(height: 8),
        _buildVideoPicker(),
        const SizedBox(height: 20),
        _buildLabel('រូបភាពទំនិញ (ដល់ ៨ សន្លឹក) *'),
        const SizedBox(height: 8),
        _buildImagePicker(),
        const SizedBox(height: 8),
        _buildLabel('ឈ្មោះទំនិញ *'),
        const SizedBox(height: 8),
        _buildTextField(
          controller: _productNameCtrl,
          hint: 'ឧ. រទេះគោសាឡី',
          icon: Icons.shopping_bag_outlined,
          validator: _validateRequired,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        _buildLabel('ការរៀបរាប់'),
        const SizedBox(height: 8),
        _buildTextField(
          controller: _descriptionCtrl,
          hint: 'ពិព័រណ៍អំពីស្ថានភាព លក្ខណៈពិសេស...',
          icon: Icons.description_outlined,
          maxLines: 4,
        ),
        const SizedBox(height: 16),
        _buildLabel('លេខទូរស័ព្ទ *'),
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
          children: const [
            Icon(Icons.video_call_rounded, color: _accentBlue),
            SizedBox(width: 10),
            Text(
              'ចុចដើម្បីបន្ថែមវីដេអូ',
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
        height: _productImages.isEmpty ? 140 : 120,
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
            const Text(
              'ចុចដើម្បីបន្ថែមរូបភាព',
              style: TextStyle(
                color: _accentBlue,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'JPG, PNG · រើសបានច្រើនបំផុត 8 សន្លឹក',
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
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_rounded,
                        color: _accentBlue,
                        size: 24,
                      ),
                      SizedBox(height: 4),
                      Text(
                        'បន្ថែម',
                        style: TextStyle(
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
        _sectionHeader('💰', 'តម្លៃ & ពេលវេលា', 'កំណត់តម្លៃ និងពេលបញ្ចប់'),
        const SizedBox(height: 20),
        _buildLabel('តម្លៃចាប់ផ្តើម (រៀល) *'),
        const SizedBox(height: 8),
        _buildTextField(
          controller: _startPriceCtrl,
          hint: 'ឧ. 50,000',
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
        _buildLabel('ជំហានបង្កើនតម្លៃ (រៀល) *'),
        const SizedBox(height: 8),
        _buildTextField(
          controller: _bidStepCtrl,
          hint: 'ឧ. 5000',
          icon: Icons.trending_up_rounded,
          keyboard: TextInputType.number,
          suffix: '៛',
          validator: _validateNumber,
          onChanged: (_) => setState(() {}),
        ),
        if (_startPriceCtrl.text.isNotEmpty && _bidStepCtrl.text.isNotEmpty)
          _buildPricePreview(),
        const SizedBox(height: 20),
        _buildLabel('ថ្ងៃ & ម៉ោងបញ្ចប់ *'),
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
          _miniStat('ដំបូង', '${fmt.format(start)} ៛', _accentBlue),
          Container(width: 1, height: 30, color: _border),
          _miniStat('ដេញទី១', '${fmt.format(start + step)} ៛', _accent),
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
                    ? 'ជ្រើសរើសថ្ងៃ និងម៉ោង'
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
          'ជ្រើសកញ្ចប់សេវា',
          'ជ្រើសរើសកញ្ចប់ដែលស្របតាមការចង់បាន',
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
                      const Text(
                        'រៀល',
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
                const Text(
                  'បង់សេវាដាក់ដេញថ្លៃ',
                  style: TextStyle(
                    color: _text,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Siemreap',
                  ),
                ),
                const Divider(color: _border, height: 40),
                const Text(
                  "ស្កេនបង់ប្រាក់មកកាន់ QR ខាងក្រោម",
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
                        "assets/aba_qr.png",
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
                  "${NumberFormat('#,###').format(total)} ៛",
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
                  label: const Text(
                    "ចុចដើម្បីបង់ប្រាក់តាម App ABA",
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
                const Text(
                  "បញ្ជាក់៖ សូមចុចសង្កត់លើ QR ដើម្បីរក្សាទុក រួចថតរូបវិក្កយបត្របញ្ចូលខាងក្រោម",
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
                      children: const [
                        Icon(
                          Icons.add_a_photo_rounded,
                          size: 40,
                          color: _textMuted,
                        ),
                        SizedBox(height: 8),
                        Text(
                          "ដាក់រូបវិក្កយបត្រ",
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
                      if (ctx.mounted) setSheet(() => isLoader = false);
                      _showErrorSnack("បញ្ហាបច្ចេកទេស៖ $e");
                    } finally {
                      if (ctx.mounted) setSheet(() => isLoader = false);
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
                      : const Text(
                    "បញ្ជាក់ និងបញ្ជូនសំណើ",
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
            backgroundColor: _accentBlue,
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
                _currentStep == 2 ? 'បន្តការបង់ប្រាក់' : 'បន្ទាប់',
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
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      maxLines: maxLines,
      style: const TextStyle(color: _text, fontSize: 14),
      validator: validator,
      onChanged: onChanged,
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



