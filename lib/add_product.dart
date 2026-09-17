import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:my_app/location_picker.dart';
import 'package:my_app/map_picker_screen.dart';
import 'package:my_app/upload_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import 'main.dart'; // ដើម្បីឱ្យវាស្គាល់ navigatorKey
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart'; // ថែមជួរនេះចូលមេ!
import 'auction_add_screen.dart';
import 'location_data.dart' hide showLocationPicker;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:video_compress/video_compress.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:video_player/video_player.dart';
import 'category_localization.dart';

class AddProductPage extends StatefulWidget {
  final String? productId;
  final Map<String, dynamic>? initialData;

  const AddProductPage({super.key, this.productId, this.initialData});

  @override
  State<AddProductPage> createState() => _AddProductPageState();
}

class _AddProductPageState extends State<AddProductPage> {
  String _t(String km, String en) =>
      Localizations.localeOf(context).languageCode == 'en' ? en : km;

  String _optionLabel(String value) => localizedCategoryLabel(context, value);
  // --- Controllers ---
  final TextEditingController nameController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  final TextEditingController stockQuantityController = TextEditingController();
  final TextEditingController stockUnitController = TextEditingController();
  final TextEditingController phone1Controller = TextEditingController();
  final TextEditingController phone2Controller = TextEditingController();
  final TextEditingController locationController = TextEditingController();
  bool _locationChosenManually = false;
  double? selectedLat;
  double? selectedLng;
  bool? _shippingIncluded; // true = បូកថ្លៃផ្ញើ, false = មិនទាន់បូក
  bool _isAiGenerating = false;
  String? _aiTitleKm;
  String? _aiTitleEn;
  String? _aiDescriptionKm;
  String? _aiDescriptionEn;

  // --- Media Variables ---
  List<XFile> selectedImages = [];
  XFile? selectedVideo;
  final ImagePicker _picker = ImagePicker();
  final formatter = NumberFormat('#,###');
  final UploadController uploadController = Get.put(UploadController());
  VideoPlayerController? _videoPreviewController;
  bool _isVideoPreviewReady = false;

  String? selectedCategory;
  String? selectedSubCategory; // ✅ បន្ថែមបន្ទាត់នេះ
  String? selectedSubSubCategory; // ✅ បន្ថែមបន្ទាត់នេះ (សម្រាប់ជាន់ទី 3)
  String selectedCurrency = '៛';
  List<String> categories = [
    'គ្រឿងចក្រ',
    'សម្ភារៈកសិកម្ម',
    'ពូជដំណាំ',
    'ពូជសត្វចិញ្ចឹម',
    'ជីនិងថ្នាំ',
    'បន្លែផ្លែឈើ',
    'ត្រីសាច់',
    'សេវាកម្ម',
    'ផ្សេងៗ',
  ];
  // បន្ថែមក្នុង add_product.dart (ជំនួស subCategories ចាស់)
  Map<String, dynamic> subCategories = {
    'គ្រឿងចក្រ': ['ទាំងអស់', 'ថ្មី', 'មួយទឹក', 'កាប់សាច់', 'គ្រឿងបន្លាស់'],

    'សម្ភារៈកសិកម្ម': {
      'ទាំងអស់': [],
      'ម៉ាស៊ីន': ['ទាំងអស់', 'ថ្មី', 'មួយទឹក', 'កាប់សាច់'],
      'ឧបករណ៍': ['ទាំងអស់', 'ថ្មី', 'មួយទឹក', 'កាប់សាច់'],
      'គ្រឿងបន្លាស់': ['ទាំងអស់', 'ថ្មី', 'មួយទឹក', 'កាប់សាច់'],
    },

    'ពូជដំណាំ': ['ទាំងអស់', 'ឈើហូបផ្លែ', 'បន្លែ', 'ផ្ការ', 'ឈើព្រៃ', 'ផ្សេងៗ'],

    'ពូជសត្វចិញ្ចឹម': [
      'ទាំងអស់',
      'គោ',
      'ក្របី',
      'ជ្រូក',
      'ចៀម',
      'ពពែ',
      'មាន់',
      'ទា',
      'ក្ងាន',
      'ក្រួច',
      'អណ្ដើក/កន្ឋាយ',
      'ត្រី',
      'កង្កែប',
      'ពស់',
      'ជន្លេន',
      'ផ្សេងៗ',
    ],

    'ជីនិងថ្នាំ': ['ទាំងអស់', 'ជី', 'ថ្នាំ', 'វីតាមីន', 'ចំណីសត្វ', 'ផ្សេងៗ'],

    'បន្លែផ្លែឈើ': [
      'ទាំងអស់',
      'បន្លែ',
      'ផ្លែឈើ',
      'គ្រឿងទេស',
      'អាហារផ្អាប់',
      'ស៊ុត',
      'ផ្សេងៗ',
    ],

    'ត្រីសាច់': [
      'ទាំងអស់',
      'ត្រី',
      'សាច់',
      'កង្កែប',
      'អណ្ដើក',
      'ពស់',
      'ក្ដាម',
      'ផ្សេងៗ',
    ],

    'សេវាកម្ម': [
      'ទាំងអស់',
      'សេវាកម្មសត្វ',
      'ដំណាំ',
      'ម៉ាស៊ីន',
      'គ្រឿងចក្រ',
      'ទឹក/ភ្លើង',
      'ហិរញ្ញវត្ថុ',
      'ច្បាប់',
      'ផ្សេងៗ',
    ],
    'ផ្សេងៗ': [
      'ទាំងអស់',
      'ដីកសិកម្ម',
      'កសិដ្ឋាន',
      'តំណាងចែកចាយ/ហ្វ្រែនឆាយ',
      'ផលិតផលឌីជីថល',
      'សៀវភៅកសិកម្ម',
      'ផ្សេងៗ',
    ],
  };

  String _imageMimeType(XFile image) {
    final mimeType = image.mimeType?.toLowerCase();
    if (mimeType == 'image/png' ||
        mimeType == 'image/webp' ||
        mimeType == 'image/jpeg') {
      return mimeType!;
    }
    final name = image.name.toLowerCase();
    if (name.endsWith('.png')) return 'image/png';
    if (name.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  Future<List<String>> _buildAiImageInputs() async {
    const maxImages = 3;
    const maxImageBytes = 2500000;
    const maxTotalBytes = 6000000;
    final imageInputs = <String>[];
    var totalBytes = 0;
    for (final image in selectedImages.take(maxImages)) {
      final bytes = await image.readAsBytes();
      if (bytes.isEmpty || bytes.length > maxImageBytes) continue;
      if (totalBytes + bytes.length > maxTotalBytes) break;
      totalBytes += bytes.length;
      imageInputs.add(
        'data:${_imageMimeType(image)};base64,${base64Encode(bytes)}',
      );
    }
    return imageInputs;
  }

  Future<void> _generateWithSesanAi() async {
    final productName = nameController.text.trim();
    final notes = descriptionController.text.trim();
    if (selectedImages.isEmpty) {
      Get.snackbar(
        _t('សូមជ្រើសរូបទំនិញជាមុន', 'Add a product photo first'),
        _t(
          'Sesan AI ត្រូវវិភាគរូបទំនិញជាមុន ហើយការប្រើម្តងកាត់ 3 Credits។',
          'Sesan AI must inspect a product photo first. Each use costs 3 Credits.',
        ),
        backgroundColor: Colors.orange.shade700,
        colorText: Colors.white,
      );
      return;
    }
    setState(() => _isAiGenerating = true);
    try {
      final imageInputs = await _buildAiImageInputs();
      if (imageInputs.isEmpty) {
        throw Exception(
          _t(
            'រូបធំពេកសម្រាប់ Sesan AI។ សូមជ្រើសរូបតូចជាងនេះ។',
            'The photos are too large for Sesan AI. Choose smaller photos.',
          ),
        );
      }
      final callable = FirebaseFunctions.instanceFor(
        region: 'asia-southeast1',
      ).httpsCallable('generateProductAiContent');
      final response = await callable.call(<String, dynamic>{
        'productName': productName,
        'notes': notes,
        'locale': Localizations.localeOf(context).languageCode,
        'images': imageInputs,
      });
      final data = Map<String, dynamic>.from(response.data as Map);
      _aiTitleKm = (data['title_km'] ?? '').toString().trim();
      _aiTitleEn = (data['title_en'] ?? '').toString().trim();
      _aiDescriptionKm = (data['description_km'] ?? '').toString().trim();
      _aiDescriptionEn = (data['description_en'] ?? '').toString().trim();
      final suggestedCategory = (data['category'] ?? '').toString();
      final suggestedStockUnit = (data['stock_unit'] ?? '').toString().trim();
      if (!mounted) return;
      final isEnglish = Localizations.localeOf(context).languageCode == 'en';
      setState(() {
        nameController.text = isEnglish ? _aiTitleEn! : _aiTitleKm!;
        descriptionController.text = isEnglish
            ? _aiDescriptionEn!
            : _aiDescriptionKm!;
        if (categories.contains(suggestedCategory)) {
          selectedCategory = suggestedCategory;
          selectedSubCategory = null;
          selectedSubSubCategory = null;
        }
        if (suggestedStockUnit.isNotEmpty)
          stockUnitController.text = suggestedStockUnit;
      });
      final remainingCredits = int.tryParse(
        (data['remainingCredits'] ?? '').toString(),
      );
      Get.snackbar(
        notes.isNotEmpty
            ? _t('Sesan AI បានកែសម្រួលរួច', 'Sesan AI improvement is ready')
            : _t('Sesan AI បានរៀបចំរួច', 'Sesan AI draft is ready'),
        remainingCredits == null
            ? _t(
                'បានប្រើ 3 Credits។ សូមពិនិត្យមុនផុស។',
                '3 Credits used. Review before publishing.',
              )
            : _t(
                'បានប្រើ 3 Credits · នៅសល់ $remainingCredits Credits។ សូមពិនិត្យមុនផុស។',
                '3 Credits used · $remainingCredits Credits left. Review before publishing.',
              ),
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      Get.snackbar(
        _t('មិនអាចប្រើ Sesan AI បាន', 'Could not use Sesan AI'),
        error.message ?? _t('សូមព្យាយាមម្ដងទៀត។', 'Please try again.'),
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
    } catch (error) {
      if (!mounted) return;
      Get.snackbar(
        _t('មានបញ្ហា', 'Something went wrong'),
        error.toString(),
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
    } finally {
      if (mounted) setState(() => _isAiGenerating = false);
    }
  }

  Future<void> _prefillSellerContact() async {
    if (widget.productId != null || widget.initialData != null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final uid =
          FirebaseAuth.instance.currentUser?.uid ?? prefs.getString('user_uid');
      if (uid == null || uid.isEmpty) return;

      Map<String, dynamic>? latestProduct;
      try {
        final snapshot = await FirebaseFirestore.instance
            .collection('products')
            .where('seller_id', isEqualTo: uid)
            .orderBy('created_at', descending: true)
            .limit(1)
            .get();
        if (snapshot.docs.isNotEmpty)
          latestProduct = snapshot.docs.first.data();
      } catch (_) {
        final snapshot = await FirebaseFirestore.instance
            .collection('products')
            .where('seller_id', isEqualTo: uid)
            .limit(50)
            .get();
        if (snapshot.docs.isNotEmpty) {
          final docs = snapshot.docs.toList()
            ..sort((a, b) {
              final aTime = a.data()['created_at'];
              final bTime = b.data()['created_at'];
              final aMs = aTime is Timestamp ? aTime.millisecondsSinceEpoch : 0;
              final bMs = bTime is Timestamp ? bTime.millisecondsSinceEpoch : 0;
              return bMs.compareTo(aMs);
            });
          latestProduct = docs.first.data();
        }
      }

      final userSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final profile = userSnapshot.data() ?? <String, dynamic>{};

      String firstText(
        Map<String, dynamic>? primary,
        List<String> primaryKeys,
        Map<String, dynamic> fallback,
        List<String> fallbackKeys,
      ) {
        for (final key in primaryKeys) {
          final value = primary?[key]?.toString().trim() ?? '';
          if (value.isNotEmpty) return value;
        }
        for (final key in fallbackKeys) {
          final value = fallback[key]?.toString().trim() ?? '';
          if (value.isNotEmpty) return value;
        }
        return '';
      }

      final phone1 = firstText(
        latestProduct,
        const ['phone1', 'seller_phone'],
        profile,
        const ['phone1', 'phone', 'seller_phone'],
      );
      final phone2 = firstText(
        latestProduct,
        const ['phone2'],
        profile,
        const ['phone2'],
      );
      final location = firstText(
        latestProduct,
        const ['location'],
        profile,
        const ['location', 'address'],
      );
      final latValue = latestProduct?['lat'] ?? profile['lat'];
      final lngValue = latestProduct?['lng'] ?? profile['lng'];

      if (!mounted) return;
      setState(() {
        if (phone1Controller.text.trim().isEmpty && phone1.isNotEmpty) {
          phone1Controller.text = phone1;
        }
        if (phone2Controller.text.trim().isEmpty && phone2.isNotEmpty) {
          phone2Controller.text = phone2;
        }
        if (locationController.text.trim().isEmpty && location.isNotEmpty) {
          locationController.text = location;
        }
        if (selectedLat == null && latValue is num)
          selectedLat = latValue.toDouble();
        if (selectedLng == null && lngValue is num)
          selectedLng = lngValue.toDouble();
      });
    } catch (error) {
      debugPrint('Seller contact prefill failed: $error');
    }
  }

  @override
  void initState() {
    super.initState();
    CambodiaLocationService.load();
    if (widget.initialData == null && widget.productId == null) {
      _prefillSellerContact();
    }
    if (widget.initialData != null) {
      nameController.text = widget.initialData!['product_name'] ?? '';
      descriptionController.text = widget.initialData!['description'] ?? '';
      priceController.text = widget.initialData!['price']?.toString() ?? '';
      stockQuantityController.text =
          widget.initialData!['stock_quantity']?.toString() ?? '';
      stockUnitController.text =
          widget.initialData!['stock_unit']?.toString() ?? '';
      phone1Controller.text = widget.initialData!['phone1'] ?? '';
      phone2Controller.text = widget.initialData!['phone2'] ?? '';
      locationController.text = widget.initialData!['location'] ?? '';
      selectedCategory = widget.initialData!['category'];
      selectedCurrency = widget.initialData!['currency'] ?? '\$';
      _shippingIncluded = widget.initialData!['shipping_included'] as bool?;
    }
  }

  @override
  void dispose() {
    _videoPreviewController?.dispose();

    nameController.dispose();
    descriptionController.dispose();
    priceController.dispose();
    stockQuantityController.dispose();
    stockUnitController.dispose();
    phone1Controller.dispose();
    phone2Controller.dispose();
    locationController.dispose();

    super.dispose();
  }

  Future<void> _cropImage(int index) async {
    if (index < 0 || index >= selectedImages.length) return;

    try {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: selectedImages[index].path,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'កាត់តរូបភាព',
            toolbarColor: Colors.green,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
          ),
          IOSUiSettings(
            title: 'កាត់តរូបភាព',
            aspectRatioLockEnabled: false,
            resetAspectRatioEnabled: true,
          ),
        ],
      );

      if (croppedFile == null || !mounted) return;

      setState(() {
        selectedImages[index] = XFile(croppedFile.path);
      });
    } catch (e) {
      debugPrint('Crop image error: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('មិនអាចកាត់តរូបភាពបាន៖ $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _previewVideo() async {
    if (selectedVideo == null) return;

    try {
      await _videoPreviewController?.dispose();

      final controller = VideoPlayerController.file(File(selectedVideo!.path));

      _videoPreviewController = controller;
      _isVideoPreviewReady = false;

      await controller.initialize();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _isVideoPreviewReady = true;
      });

      await controller.play();

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              return AlertDialog(
                contentPadding: EdgeInsets.zero,
                content: Container(
                  width: MediaQuery.of(context).size.width * 0.9,
                  height: MediaQuery.of(context).size.height * 0.5,
                  color: Colors.black,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (_isVideoPreviewReady)
                        Center(
                          child: AspectRatio(
                            aspectRatio: controller.value.aspectRatio,
                            child: VideoPlayer(controller),
                          ),
                        )
                      else
                        const CircularProgressIndicator(color: Colors.white),

                      Positioned(
                        bottom: 16,
                        child: IconButton(
                          iconSize: 48,
                          color: Colors.white,
                          icon: Icon(
                            controller.value.isPlaying
                                ? Icons.pause_circle_filled
                                : Icons.play_circle_fill,
                          ),
                          onPressed: () async {
                            if (controller.value.isPlaying) {
                              await controller.pause();
                            } else {
                              await controller.play();
                            }

                            setDialogState(() {});
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () async {
                      await controller.pause();

                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext);
                      }
                    },
                    child: const Text('បិទ'),
                  ),
                ],
              );
            },
          );
        },
      );
    } catch (e) {
      debugPrint('Preview video error: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('មិនអាចបើកវីដេអូបាន៖ $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _fillLocationFromMap(LatLng point) async {
    if (_locationChosenManually || !mounted) return;
    try {
      final placemarks = await placemarkFromCoordinates(
        point.latitude,
        point.longitude,
      );
      if (!mounted || _locationChosenManually) return;
      final parts = <String>[];
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        for (final value in [
          place.administrativeArea,
          place.subAdministrativeArea,
          place.locality,
          place.subLocality,
        ]) {
          final clean = value?.trim() ?? '';
          if (clean.isNotEmpty && !parts.contains(clean)) parts.add(clean);
        }
      }
      setState(
        () => locationController.text = parts.isNotEmpty
            ? parts.join(', ')
            : '${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}',
      );
    } catch (_) {}
  }

  Future<void> pickManyImages() async {
    // 🎯 កែសម្រួល Line នេះ៖ បន្ថែម maxWidth, maxHeight, imageQuality
    final List<XFile> images = await _picker.pickMultiImage(
      maxWidth: 1440, // កម្រិតច្បាស់សមល្មម
      maxHeight: 1440, // កម្រិតច្បាស់សមល្មម
      imageQuality: 85, // បន្ថយគុណភាពបន្តិច ដើម្បីឱ្យវារុញមកលឿន
    );

    if (images.isNotEmpty) {
      // ... កូដផ្សេងៗទៀតរបស់មេ ទុកដដែល ...
      List<XFile> allPicked = [...selectedImages, ...images];

      if (allPicked.length > 10) {
        // 🎯 កាត់យកត្រឹមតែ ១០ សន្លឹកដំបូងគត់
        setState(() {
          selectedImages = allPicked.sublist(0, 10);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('យើងកាត់យកត្រឹម ១០ សន្លឹកដំបូងជូនមេ!')),
        );
      } else {
        setState(() {
          selectedImages = allPicked;
        });
      }
    }
  }

  Future<void> pickVideo() async {
    // 🎯 ប្រើឈ្មោះ pickVideo ឱ្យដូចកូដចាស់មេ
    final XFile? video = await _picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(seconds: 60), // កែជា ៦០ វិនាទីតាមមេចង់បាន
    );

    if (video != null) {
      // 🎯 ឆែកឱ្យច្បាស់ ១០០% បើលើស ៦០ វិនាទី គឺមិនយកដាច់ខាត
      final info = await VideoCompress.getMediaInfo(video.path);
      if (info.duration != null && info.duration! > 61000) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('វីដេអូមិនអាចលើសពី ៦០ វិនាទីឡើយ!')),
        );
        return;
      }
      setState(() => selectedVideo = video);
    }
  }

  // --- មុខងារបង្រួមរូបភាព (កែសម្រួលឱ្យកាន់តែសុវត្ថិភាព និងច្បាស់ល្អ) ---
  Future<File?> _compressImage(File file) async {
    try {
      final filePath = file.absolute.path;

      // 🎯 រកចំណុច (.) ចុងក្រោយគេបង្អស់ ដើម្បីកាត់ឈ្មោះ File ឱ្យត្រូវគ្រប់ប្រភេទ (png, jpg, heic)
      final lastIndex = filePath.lastIndexOf('.');

      // បង្កើត Path ថ្មីសម្រាប់រក្សាទុក File ដែលបង្រួមរួច
      final outPath = "${filePath.substring(0, lastIndex)}_compressed.jpg";

      // ចាប់ផ្ដើមបង្រួមរូបភាព
      var result = await FlutterImageCompress.compressAndGetFile(
        filePath,
        outPath,
        quality: 70, // បង្រួមសល់ ៧០% (ទំហំស្រាលខ្លាំង តែនៅតែច្បាស់ភ្នែក)
        minWidth: 1024, // កម្រិតទទឹងសមល្មមសម្រាប់បង្ហាញលើ App
        minHeight: 1024, // កម្រិតកម្ពស់សមល្មម
        format: CompressFormat
            .jpeg, // 🎯 បង្ខំឱ្យទៅជា JPEG ដើម្បីឱ្យ Firebase ងាយអាន
      );

      if (result == null) return null;

      return File(result.path);
    } catch (e) {
      // បើមានបញ្ហាពេលបង្រួម ឱ្យវាប្រើ File ដើមសិន ដើម្បីកុំឱ្យគាំងការបង្ហោះ
      return file;
    }
  }

  Future<File?> _compressVideo(File file) async {
    try {
      print("--- ចាប់ផ្ដើមបង្រួមវីដេអូ ---");
      print("ទំហំដើម៖ ${file.lengthSync() / (1024 * 1024)} MB");

      final info = await VideoCompress.compressVideo(
        file.path,
        quality: VideoQuality.MediumQuality, // ប្ដូរពី LowQuality
        deleteOrigin: false,
        includeAudio: true,
      );

      if (info != null && info.file != null) {
        print(
          "បង្រួមរួចរាល់! ទំហំថ្មី៖ ${info.file!.lengthSync() / (1024 * 1024)} MB",
        );
        return info.file;
      }
    } catch (e) {
      print("កំហុសពេលបង្រួម៖ $e");
      VideoCompress.cancelCompression();
    }
    return null;
  }

  // --- នេះជាមុខងារ _uploadToStorage ដែលកែសម្រួលរួច (ផាសជួសកន្លែងចាស់) ---
  Future<String> _uploadToStorage(File file, String folder) async {
    File fileToUpload = file;

    // បើជារូបភាព ឱ្យវាបង្រួមសិន
    if (folder.contains('images')) {
      File? compressed = await _compressImage(file);
      if (compressed != null) {
        fileToUpload = compressed;
      }
    } else if (folder.contains('videos')) {
      File? compressed = await _compressVideo(file);

      if (compressed != null) {
        // 🎯 ឆែកមើល៖ បើ File ដែលបង្រួមហើយ បែរជាធំជាង File ដើម ឱ្យយក File ដើមវិញ
        if (compressed.lengthSync() > file.lengthSync()) {
          fileToUpload = file;
          print("យក File ដើមវិញ ព្រោះការបង្រួមធ្វើឱ្យឡើងទំហំ");
        } else {
          fileToUpload = compressed;
          print("យក File ដែលបង្រួមរួចទៅ Upload");
        }

        // ឆែកប្រវែងវីដេអូក្រោម ៦០ វិនាទី
        final info = await VideoCompress.getMediaInfo(fileToUpload.path);
        if (info.duration != null && info.duration! > 60000) {
          throw "វីដេអូវែងពេក! សូមជ្រើសរើសវីដេអូក្រោម ៦០ វិនាទី។";
        }
      }
    }

    String fileExtension = fileToUpload.path.split('.').last;
    String fileName =
        "${DateTime.now().millisecondsSinceEpoch}_${fileToUpload.path.split('/').last}";
    Reference ref = FirebaseStorage.instance
        .ref()
        .child(folder)
        .child(fileName);

    SettableMetadata metadata = SettableMetadata(
      contentType: folder.contains('videos')
          ? 'video/$fileExtension'
          : 'image/$fileExtension',
    );

    UploadTask uploadTask = ref.putFile(fileToUpload, metadata);
    TaskSnapshot snapshot = await uploadTask;

    if (folder.contains('videos')) await VideoCompress.deleteAllCache();

    return await snapshot.ref.getDownloadURL();
  }

  // --- ផាសជំនួសមុខងារ _uploadProduct ចាស់ដោយកូដខាងក្រោមនេះ ---

  // បន្ថែមមុខងារនេះនៅខាងក្រោម _uploadProduct (ក្រៅសញ្ញាដង្កៀប)
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_t('បញ្ហាបង្ហោះ', 'Upload problem')),
        content: Text(_t('មិនអាចបង្ហោះបានទេ ដោយសារ៖ $message', 'Unable to upload: $message')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_t('យល់ព្រម', 'OK')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.productId != null ? _t('កែប្រែទំនិញ', 'Edit product') : _t('បន្ថែមទំនិញថ្មី', 'Add product'),
        ),
        backgroundColor: Colors.green,
        // 🎯 ដាក់ក្នុង actions: [] របស់ AppBar ក្នុងទំព័រ Add Product
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12, top: 10, bottom: 10),
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => AuctionAddScreen()),
                ); // 🎯 ដាក់ Navigator ទៅកាន់ទំព័រ Request Exhibition របស់មេនៅទីនេះ
              },
              borderRadius: BorderRadius.circular(15),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  // ✨ ពណ៌មាសដេញ (Gold Gradient) ឱ្យមើលទៅមានតម្លៃ
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.stars_rounded, color: Colors.black, size: 18),
                    const SizedBox(width: 4),
                    Text(
                      _t('ដាក់ដេញថ្លៃ', 'Add auction'),
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                        fontFamily: 'Siemreap',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent, // ឲ្យកូន Widget នៅតែដំណើរការ
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              _buildMediaButton(
                onTap: () {
                  if (selectedImages.length < 10) {
                    pickManyImages();
                  }
                },
                icon: Icons.collections,
                label: selectedImages.length >= 10
                    ? _t("រូបភាពគ្រប់ចំនួនហើយ (១០/១០)", "Photo limit reached (10/10)")
                    : _t("រើសរូបភាព (${selectedImages.length}/10)", "Choose photos (${selectedImages.length}/10)"),
                // 🎯 កែពណ៌ឱ្យទៅជាប្រផេះ បើគ្រប់ ១០ សន្លឹក
                color: selectedImages.length >= 10
                    ? Colors.grey.shade300
                    : Colors.blue.shade50,
                textColor: selectedImages.length >= 10
                    ? Colors.grey
                    : Colors.blue,
              ),
              const SizedBox(height: 10),
              // 🎯 បង្ហាញរូបភាព Preview ជាមួយនឹងប៊ូតុងលុប (Cancel)
              if (selectedImages.isNotEmpty)
                SizedBox(
                  height: 110, // ថែមទំហំបន្តិចដើម្បីកុំឱ្យដាច់ប៊ូតុងលុប
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: selectedImages.length,
                    itemBuilder: (context, index) => Padding(
                      padding: const EdgeInsets.only(right: 12, top: 10),
                      child: Stack(
                        clipBehavior: Clip.none, // ឱ្យប៊ូតុងលុបអាចលយចេញក្រៅបាន
                        children: [
                          // ១. បង្ហាញរូបថត
                          GestureDetector(
                            onTap: () => _cropImage(index),
                            child: Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.file(
                                    File(selectedImages[index].path),
                                    width: 90,
                                    height: 90,
                                    fit: BoxFit.cover,
                                  ),
                                ),

                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 3,
                                    ),
                                    decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.only(
                                        topRight: Radius.circular(8),
                                        bottomLeft: Radius.circular(12),
                                      ),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.crop,
                                          color: Colors.white,
                                          size: 13,
                                        ),
                                        SizedBox(width: 2),
                                        Text(
                                          'Crop',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 9,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // ២. ប៊ូតុង Cancel (លុបរូប) - ដាក់នៅខាងស្តាំដៃលើរូប
                          Positioned(
                            top: -8,
                            right: -8,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  selectedImages.removeAt(
                                    index,
                                  ); // 🎯 លុបរូបចេញពី List ភ្លាម
                                });
                              },
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.all(4),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 15),

              Row(
                children: [
                  Expanded(
                    child: _buildMediaButton(
                      onTap: pickVideo,
                      icon: Icons.video_library,
                      label: selectedVideo == null
                          ? _t('រើសវីដេអូបង្ហាញទំនិញ', 'Choose product video')
                          : _t('រើសវីដេអូរួចរាល់ ✅', 'Video selected ✅'),
                      color: Colors.orange.shade50,
                      textColor: Colors.orange,
                    ),
                  ),

                  if (selectedVideo != null) ...[
                    const SizedBox(width: 8),

                    IconButton(
                      onPressed: _previewVideo,
                      tooltip: _t('មើលវីដេអូ', 'Preview video'),
                      icon: const Icon(
                        Icons.play_circle_fill,
                        color: Colors.green,
                        size: 40,
                      ),
                    ),

                    IconButton(
                      tooltip: _t('លុបវីដេអូ', 'Remove video'),
                      onPressed: () async {
                        await _videoPreviewController?.pause();
                        await _videoPreviewController?.dispose();

                        if (!mounted) return;

                        setState(() {
                          selectedVideo = null;
                          _videoPreviewController = null;
                          _isVideoPreviewReady = false;
                        });
                      },
                      icon: const Icon(
                        Icons.close,
                        color: Colors.red,
                        size: 30,
                      ),
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: _isAiGenerating ? null : _generateWithSesanAi,
                  icon: _isAiGenerating
                      ? const SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(strokeWidth: 1.8),
                        )
                      : const Icon(Icons.auto_awesome, size: 15),
                  label: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: descriptionController,
                    builder: (context, value, _) => Text(
                      _isAiGenerating
                          ? _t('AI កំពុងរៀបចំ...', 'AI is working...')
                          : value.text.trim().isNotEmpty
                          ? _t('AI កែសម្រួល', 'AI Improve')
                          : _t('AI ជួយសរសេរ', 'AI Write'),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.deepPurple,
                    side: BorderSide(
                      color: Colors.deepPurple.withOpacity(0.75),
                    ),
                    minimumSize: const Size(0, 32),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _buildTextField(
                _t('ឈ្មោះទំនិញ *', 'Product name *'),
                Icons.shopping_bag,
                nameController,
              ),
              const SizedBox(height: 10),
              _buildCategoryDropdown(),
              const SizedBox(height: 10),
              _buildPriceSection(),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      _t('ចំនួនស្តុក *', 'Stock quantity *'),
                      Icons.inventory_2_outlined,
                      stockQuantityController,
                      isNumber: true,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: _buildStockUnitField()),
                ],
              ),
              const SizedBox(height: 10),
              _buildTextField(
                _t('បរិយាយទំនិញ', 'Product description'),
                Icons.description,
                descriptionController,
                maxLines: 3,
              ),
              const SizedBox(height: 10),
              _buildPhoneSection(),
              const SizedBox(height: 10),

              /// ROW ទីតាំង និង MAP
              Row(
                children: [
                  /// =========================
                  /// LOCATION PICKER (រើសខេត្ត/ស្រុក/ឃុំ)
                  /// =========================
                  /// LOCATION PICKER (រៀបឱ្យស៊ីជាមួយ TextField ផ្សេងៗ)
                  /// =========================
                  Expanded(
                    flex: 3,
                    child: InkWell(
                      onTap: () {
                        showLocationPicker(
                          context,
                          onSelected: (location) {
                            setState(() {
                              _locationChosenManually = true;
                              locationController.text = location.toString();
                            });
                          },
                        );
                      },
                      borderRadius: BorderRadius.circular(
                        10,
                      ), // កែមក ១០ ឱ្យស្មើ TextField លើៗ
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal:
                              12, // សារ៉េឱ្យស្មើ PrefixIcon របស់ TextField
                          vertical: 15,
                        ),
                        decoration: BoxDecoration(
                          // ✅ ១. លុប color: Colors.white ចោល (ឱ្យវាយកពណ៌តាម Theme App)
                          borderRadius: BorderRadius.circular(10),

                          // ✅ ២. សារ៉េពណ៌ Border ឱ្យស្រាលបំផុត (ដូច TextField ដើម)
                          border: Border.all(color: Colors.grey.shade400),

                          // ✅ ៣. បន្ថែមស្រមោលស្រាលៗ ដើម្បីឱ្យវាមាន "រង្វង់" និង "ជម្រៅ" ដូចគេ
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.location_city,
                              color: Colors
                                  .green, // ប្រើពណ៌បៃតងឱ្យស៊ីជាមួយ Icon ក្នុង TextField ផ្សេងទៀត
                              size: 24,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                locationController.text.isEmpty
                                    ? _t("ជ្រើសទីតាំង *", "Choose location *")
                                    : locationController.text,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: locationController.text.isEmpty
                                      ? Colors
                                            .grey
                                            .shade600 // ពណ៌អក្សរ Hint
                                      : Colors.black87,
                                  fontFamily: 'Siemreap',
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 10),

                  /// =========================
                  /// MAP PICKER BUTTON (Coming Soon)
                  /// =========================
                  Expanded(
                    flex: 1,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        InkWell(
                          onTap: () async {
                            final result = await Navigator.push<LatLng>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => MapPickerScreen(
                                  initialLat: selectedLat,
                                  initialLng: selectedLng,
                                ),
                              ),
                            );
                            if (result == null || !mounted) return;
                            setState(() {
                              selectedLat = result.latitude;
                              selectedLng = result.longitude;
                            });
                            await _fillLocationFromMap(result);
                          },
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: selectedLat != null && selectedLng != null
                                  ? Colors.green.withValues(alpha: 0.12)
                                  : Colors.green.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color:
                                    selectedLat != null && selectedLng != null
                                    ? Colors.green
                                    : Colors.green.shade300,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  selectedLat != null && selectedLng != null
                                      ? Icons.location_on
                                      : Icons.map_outlined,
                                  color: Colors.green.shade700,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  selectedLat != null && selectedLng != null
                                      ? _t('បាន Pin', 'Pinned')
                                      : 'Maps',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.green.shade800,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Siemreap',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (selectedLat != null && selectedLng != null)
                          Positioned(
                            top: -9,
                            right: -9,
                            child: Material(
                              color: Colors.red,
                              shape: const CircleBorder(),
                              elevation: 2,
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: () {
                                  setState(() {
                                    selectedLat = null;
                                    selectedLng = null;
                                  });
                                },
                                child: const Padding(
                                  padding: EdgeInsets.all(5),
                                  child: Icon(
                                    Icons.close,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              // ចប់ផ្នែករើសទីតាំង
              const SizedBox(height: 25),
              const SizedBox(height: 25),
              ElevatedButton(
                onPressed: () async {
                  // 🎯 ថែម async នៅត្រង់នេះ
                  // ១. ឆែកលក្ខខណ្ឌចាំបាច់ (Validation)
                  if (selectedImages.isEmpty ||
                      selectedCategory == null ||
                      nameController.text.isEmpty ||
                      priceController.text.isEmpty ||
                      stockQuantityController.text.isEmpty ||
                      stockUnitController.text.trim().isEmpty ||
                      int.tryParse(stockQuantityController.text.trim()) ==
                          null ||
                      int.parse(stockQuantityController.text.trim()) < 0 ||
                      phone1Controller.text.isEmpty ||
                      locationController.text.isEmpty) {
                    Get.snackbar(
                      _t('ខ្វះព័ត៌មាន', 'Missing information'),
                      _t('សូមបំពេញព័ត៌មាន និងដាក់រូបថតឱ្យគ្រប់សិន!', 'Please complete the required information and add a product photo.'),
                      backgroundColor: Colors.redAccent,
                      colorText: Colors.white,
                    );
                    return;
                  }
                  if (_shippingIncluded == null) {
                    Get.snackbar(
                      _t('ខ្វះព័ត៌មាន', 'Missing information'),
                      _t('សូមជ្រើសរើសថាតើតម្លៃនេះបូកថ្លៃផ្ញើរួចឬនៅ?', 'Please choose whether shipping is included in the price.'),
                      backgroundColor: Colors.redAccent,
                      colorText: Colors.white,
                    );
                    return;
                  }

                  // 🎯 ២. ទាញព័ត៌មាន User (នេះជាកន្លែងដែលបាត់!)
                  final prefs = await SharedPreferences.getInstance();
                  final currentUser = FirebaseAuth.instance.currentUser;

                  // ព្យាយាមយកពី Firebase បើអត់មានទើបយកពី SharedPreferences
                  String uId =
                      currentUser?.uid ??
                      prefs.getString('user_uid') ??
                      "UNKNOWN";
                  String uName =
                      currentUser?.displayName ??
                      prefs.getString('user_name') ??
                      "អ្នកប្រើប្រាស់ Sesan";
                  String uPhoto =
                      currentUser?.photoURL ??
                      prefs.getString('user_photo') ??
                      "";

                  // ៣. រៀបចំទិន្នន័យ (បន្ថែម seller_id, name, photo ចូល)
                  Map<String, dynamic> dataFromForm = {
                    'product_name': nameController.text.trim(),
                    'description': descriptionController.text.trim(),
                    if (_aiTitleKm?.isNotEmpty == true)
                      'product_name_km': _aiTitleKm,
                    if (_aiTitleEn?.isNotEmpty == true)
                      'product_name_en': _aiTitleEn,
                    if (_aiDescriptionKm?.isNotEmpty == true)
                      'description_km': _aiDescriptionKm,
                    if (_aiDescriptionEn?.isNotEmpty == true)
                      'description_en': _aiDescriptionEn,
                    'price': priceController.text.trim().replaceAll(',', ''),
                    'track_stock': true,
                    'stock_quantity': int.parse(
                      stockQuantityController.text.trim(),
                    ),
                    'stock_unit': stockUnitController.text.trim(),
                    'sold_quantity': 0,
                    'is_available':
                        int.parse(stockQuantityController.text.trim()) > 0,
                    'phone1': phone1Controller.text.trim(),
                    'phone2': phone2Controller.text.trim(),
                    'location': locationController.text.trim(),
                    'category': selectedCategory,
                    'sub_category':
                        selectedSubCategory ?? '', // ✅ បន្ថែមបន្ទាត់នេះ
                    'sub_sub_category':
                        selectedSubSubCategory ??
                        'ទាំងអស់', // ✅ បន្ថែមបន្ទាត់នេះ
                    'currency': selectedCurrency,
                    'lat': selectedLat,
                    'lng': selectedLng,
                    // 🎯 បន្ថែម ៣ ជួរនេះដើម្បីបាត់ UNKNOWN
                    'seller_id': uId,
                    'seller_name': uName,
                    'seller_photo': uPhoto,
                    'shipping_included':
                        _shippingIncluded, // true = បូករួច, false = មិនទាន់បូក
                    'created_at':
                        FieldValue.serverTimestamp(), // ថែមថ្ងៃខែផុសផងមេ
                  };

                  // ៤. បញ្ជាឱ្យបង្ហោះក្រោយខ្នង (Background Upload)
                  uploadController.startBackgroundUpload(
                    productId: widget.productId,
                    formData: dataFromForm,
                    selectedImages: List.from(selectedImages),
                    selectedVideo: selectedVideo,
                  );

                  // ៥. នាំផ្លូវទៅ Home និងបង្ហាញសារ
                  Get.offAllNamed('/home');
                  Get.snackbar(
                    _t('🚀 កំពុងបង្ហោះ...', '🚀 Uploading...'),
                    _t('ទំនិញរបស់អ្នកកំពុងបង្ហោះហើយ!', 'Your product is being uploaded!'),
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: Colors.black54,
                    colorText: Colors.white,
                  );
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: Colors.green,
                ),
                child: Text(
                  _t('រក្សាទុកការផុស', 'Save product'),
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Widgets ជំនួយសម្រាប់ UI ---
  Widget _buildMediaButton({
    required VoidCallback onTap,
    required IconData icon,
    required String label,
    required Color color,
    required Color textColor,
  }) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: textColor,
        minimumSize: const Size(double.infinity, 50),
        elevation: 0,
      ),
    );
  }

  List<String> _stockUnitsForCategory() {
    switch (selectedCategory) {
      case 'ពូជដំណាំ':
        return ['ដើម', 'គ្រាប់', 'គីឡូក្រាម', 'បាច់', 'កញ្ចប់', 'បាវ'];
      case 'ពូជសត្វចិញ្ចឹម':
        return ['ក្បាល', 'កូន', 'គូ', 'ហ្វូង', 'គីឡូក្រាម'];
      case 'បន្លែផ្លែឈើ':
        return ['គីឡូក្រាម', 'តោន', 'បាវ', 'កេស', 'កញ្ចប់', 'បាច់'];
      case 'ត្រីសាច់':
        return [
          'គីឡូក្រាម',
          'ក្បាល',
          'កូន',
          'គូ',
          'ខាំ',
          'ស្រះ',
          'អាង',
          'កញ្ចប់',
          'កេស',
        ];
      case 'ជីនិងថ្នាំ':
        return [
          'គីឡូក្រាម',
          'លីត្រ',
          'ដប',
          'ប៊ីដុង',
          'កាន',
          'កញ្ចប់',
          'បាវ',
          'កេស',
        ];
      case 'គ្រឿងចក្រ':
        return ['គ្រឿង', 'ឈុត', 'ដើម', 'ម៉ាស៊ីន', 'ដុំ', 'ទូកុងតឺន័រ'];
      case 'សម្ភារៈកសិកម្ម':
        return [
          'គ្រឿង',
          'ដើម',
          'គ្រាប់',
          'ដុំ',
          'កេស',
          'ឡូ',
          'ឈុត',
          'ម៉ែត្រ',
          'គីឡូក្រាម',
        ];
      case 'សេវាកម្ម':
        return ['លើក', 'ថ្ងៃ', 'ម៉ោង', 'គម្រោង'];
      default:
        return [
          'ដុំ',
          'គ្រឿង',
          'ដើម',
          'គ្រាប់',
          'គីឡូក្រាម',
          'លីត្រ',
          'កញ្ចប់',
          'បាវ',
          'កេស',
          'ឡូ',
          'ឈុត',
        ];
    }
  }

  Widget _buildStockUnitField() {
    final units = _stockUnitsForCategory();
    return TextField(
      controller: stockUnitController,
      decoration: InputDecoration(
        labelText: _t('ឯកតាស្តុក *', 'Stock unit *'),
        hintText: _t('ជ្រើសរើស ឬវាយដោយដៃ', 'Select or type'),
        prefixIcon: const Icon(Icons.straighten, color: Colors.green),
        suffixIcon: PopupMenuButton<String>(
          tooltip: _t('ជ្រើសរើសឯកតា', 'Choose unit'),
          icon: const Icon(Icons.arrow_drop_down),
          onSelected: (unit) => setState(() => stockUnitController.text = unit),
          itemBuilder: (context) => units
              .map(
                (unit) => PopupMenuItem<String>(
                  value: unit,
                  child: Text(
                    unit,
                    style: const TextStyle(fontFamily: 'Siemreap'),
                  ),
                ),
              )
              .toList(),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    IconData icon,
    TextEditingController controller, {
    int minLines = 1,
    int? maxLines = 1,
    bool isNumber = false,
  }) {
    final isMultiline =
        !isNumber && (maxLines == null || maxLines > 1 || minLines > 1);
    return TextField(
      controller: controller,
      keyboardType: isNumber
          ? TextInputType.number
          : (isMultiline ? TextInputType.multiline : TextInputType.text),
      textInputAction: isMultiline
          ? TextInputAction.newline
          : TextInputAction.next,
      inputFormatters: isNumber
          ? [FilteringTextInputFormatter.digitsOnly]
          : null,
      minLines: minLines,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.green),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    return Column(
      children: [
        // Category មេ
        DropdownButtonFormField<String>(
          value: selectedCategory,
          decoration: InputDecoration(
            labelText: _t('ប្រភេទលក់ *', 'Category *'),
            prefixIcon: const Icon(Icons.category, color: Colors.green),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
          items: categories
              .map(
                (c) => DropdownMenuItem(value: c, child: Text(_optionLabel(c))),
              )
              .toList(),
          onChanged: (val) {
            setState(() {
              selectedCategory = val;
              selectedSubCategory = null;
              selectedSubSubCategory = null; // ✅ Reset ទាំងអស់
            });
          },
        ),

        // ✅ Sub Category Dropdown
        if (selectedCategory != null &&
            subCategories.containsKey(selectedCategory))
          _buildSubCategoryDropdown(),

        // ✅ Sub-Sub Category Dropdown (សម្រាប់តែ "សម្ភារៈកសិកម្ម")
        if (selectedCategory == 'សម្ភារៈកសិកម្ម' &&
            selectedSubCategory != null &&
            selectedSubCategory != 'ទាំងអស់')
          _buildSubSubCategoryDropdown(),
      ],
    );
  }

  // ✅ Sub Category Dropdown
  Widget _buildSubCategoryDropdown() {
    final subData = subCategories[selectedCategory];
    List<String> subList;

    if (subData is Map) {
      subList = subData.keys.cast<String>().toList();
    } else if (subData is List) {
      subList = subData.cast<String>();
    } else {
      return const SizedBox.shrink();
    }

    if (subList.isEmpty ||
        (subList.length == 1 && subList.first == 'ទាំងអស់')) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: DropdownButtonFormField<String>(
        value: selectedSubCategory,
        decoration: InputDecoration(
          labelText: _t('ប្រភេទរង (ស្រេចចិត្ត)', 'Subcategory (optional)'),
          prefixIcon: const Icon(
            Icons.subdirectory_arrow_right,
            color: Colors.orange,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
        items: subList
            .map(
              (sub) =>
                  DropdownMenuItem(value: sub, child: Text(_optionLabel(sub))),
            )
            .toList(),
        onChanged: (val) {
          setState(() {
            selectedSubCategory = val;
            selectedSubSubCategory = null; // ✅ Reset Sub-Sub
          });
        },
      ),
    );
  }

  // ✅ Sub-Sub Category Dropdown (សម្រាប់តែ "សម្ភារៈកសិកម្ម")
  Widget _buildSubSubCategoryDropdown() {
    final subData = subCategories[selectedCategory];
    if (subData is! Map) return const SizedBox.shrink();

    final subSubList = subData[selectedSubCategory] as List<String>?;
    if (subSubList == null ||
        subSubList.isEmpty ||
        (subSubList.length == 1 && subSubList.first == 'ទាំងអស់')) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: DropdownButtonFormField<String>(
        value: selectedSubSubCategory,
        decoration: InputDecoration(
          labelText: _t('លក្ខខណ្ឌ (ស្រេចចិត្ត)', 'Condition (optional)'),
          prefixIcon: const Icon(
            Icons.subdirectory_arrow_right,
            color: Colors.red,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
        items: subSubList
            .map(
              (sub) =>
                  DropdownMenuItem(value: sub, child: Text(_optionLabel(sub))),
            )
            .toList(),
        onChanged: (val) {
          setState(() => selectedSubSubCategory = val);
        },
      ),
    );
  }

  // ក្នុង _buildPriceSection បងដក Dropdown ចេញ ហើយប្រើតែសញ្ញារៀល
  Widget _buildPriceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ប្រអប់តម្លៃដូចដើម
        TextField(
          controller: priceController,
          keyboardType: TextInputType.number,
          onChanged: (value) {
            final cleanNumber = value.replaceAll(RegExp(r'[^0-9]'), '');
            if (cleanNumber.isEmpty) {
              if (value.isNotEmpty) {
                priceController.clear();
              }
              return;
            }
            final amount = int.tryParse(cleanNumber);
            if (amount == null) return;
            final formatted = formatter.format(amount);
            priceController.value = TextEditingValue(
              text: formatted,
              selection: TextSelection.collapsed(offset: formatted.length),
            );
          },
          decoration: InputDecoration(
            labelText: _t('តម្លៃ (៛) *', 'Price (KHR) *'),
            prefixIcon: const Icon(Icons.money, color: Colors.green),
            suffixText: "៛",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),

        const SizedBox(height: 12),

        // ជម្រើសថ្លៃផ្ញើ (ជ្រើសយកមួយ)
        Row(
          children: [
            Expanded(
              child: RadioListTile<bool?>(
                title: Text(
                  _t('បានបូកទាំងថ្លៃផ្ញើ', 'Shipping included'),
                  style: TextStyle(fontSize: 11, fontFamily: 'Siemreap'),
                ),
                value: true,
                groupValue: _shippingIncluded,
                onChanged: (val) {
                  setState(() => _shippingIncluded = val);
                },
                contentPadding: EdgeInsets.zero,
                dense: true,
                activeColor: Colors.green,
              ),
            ),
            Expanded(
              child: RadioListTile<bool?>(
                title: Text(
                  _t('មិនទាន់បូកថ្លៃផ្ញើ', 'Shipping not included'),
                  style: TextStyle(fontSize: 11, fontFamily: 'Siemreap'),
                ),
                value: false,
                groupValue: _shippingIncluded,
                onChanged: (val) {
                  setState(() => _shippingIncluded = val);
                },
                contentPadding: EdgeInsets.zero,
                dense: true,
                activeColor: Colors.green,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPhoneSection() {
    return Row(
      children: [
        Expanded(
          child: _buildTextField(_t('លេខទី១ *', 'Phone 1 *'), Icons.phone, phone1Controller),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildTextField(
            _t('លេខទី២', 'Phone 2'),
            Icons.phone_android,
            phone2Controller,
          ),
        ),
      ],
    );
  }
}
