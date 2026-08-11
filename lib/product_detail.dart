import 'dart:async';
import 'dart:io';
import 'package:app_links/app_links.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:get/get.dart'
    show Get, ExtensionSnackbar, GetNavigation, ExtensionDialog, SnackPosition;
import 'package:intl/intl.dart';
import 'package:my_app/comment_section.dart';
import 'package:my_app/seller_profile_screen.dart';
import 'package:my_app/share_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'video_player_screen.dart';
import 'related_products_widget.dart';
import 'chat_screen.dart';
import 'cart_screen.dart';
import 'package:flutter/services.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:video_player/video_player.dart';
import 'l10n/app_localizations.dart';



// ✅ កែពី StatelessWidget ទៅជា StatefulWidget
class ProductDetailScreen extends StatefulWidget {
  final Map<String, dynamic> product;
  const ProductDetailScreen({super.key, required this.product});


  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}


class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _currentPage = 0; // 🎯 បន្ថែមសម្រាប់រាប់លេខរូបភាព
  int _tempQty = 1; // 🎯 ប្តូរពី static មកជា variable ធម្មតាវិញ
  bool isSaved = false; // ស្ថានភាពដំបូង
  String? _currentUserId;
  double _myRating = 0.0;
  bool _isSubmittingRating = false;
  int _quantity = 1;
  bool _wasPaused = false; // ✅ បន្ថែម


  // ១. ប្រកាស variable នេះនៅខាងលើក្នុង Class _ProductDetailScreenState
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;


  @override
  void initState() {
    super.initState();
    _loadUid();
    _initVideo();

    // ✅ ប្តូរពី FirebaseDynamicLinks មកប្រើ AppLinks ឱ្យដូច main.dart
    _appLinks = AppLinks();
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      debugPrint("ទទួល បាន Link ថ្មីក្នុង Detail: $uri");


      final segments = uri.pathSegments;
      if (segments.contains('product')) {
        final String newProductId = segments.last;


        // បើ ID ថ្មីខុសពី ID ចាស់ដែលកំពុងមើល ទើប Refresh
        if (newProductId != widget.product['id']) {
          _refreshProductData(newProductId);
        }
      }
    });
  }
  void _initVideo() {
    final videoUrl = widget.product['video_url'];
    if (videoUrl != null && videoUrl.toString().isNotEmpty) {
      _videoController = VideoPlayerController.networkUrl(Uri.parse(videoUrl))
        ..initialize().then((_) {
          if (mounted) setState(() => _isVideoInitialized = true);
        });
    }
  }

  // ២. បង្កើតមុខងារ Refresh ទិន្នន័យ (ដាក់ក្នុង Class ដដែល)
  Future<void> _refreshProductData(String productId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('products')
          .doc(productId)
          .get();


      if (doc.exists) {
        var newData = doc.data() as Map<String, dynamic>;
        newData['id'] = productId;


        // ប្តូរទៅទំព័រ Detail ថ្មីជាមួយទិន្នន័យថ្មី
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => ProductDetailScreen(product: newData),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Refresh product error: $e");
    }
  }

  @override
  void dispose() {
    _videoController?.pause();
    _videoController?.dispose();
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final bool isCurrent = ModalRoute.of(context)?.isCurrent ?? false;

    if (!isCurrent && !_wasPaused) {
      if (_videoController != null &&
          _isVideoInitialized &&
          _videoController!.value.isPlaying) {
        _videoController!.pause();
        _wasPaused = true;
        setState(() {});
      }
    }

    if (isCurrent && _wasPaused) {
      _wasPaused = false;
    }
  }


  // ── Screenshot Controller ────────────────────────────────────────
  final ScreenshotController _screenshotController = ScreenshotController();


  // ── ២. Function បង្កើត Watermark (ជាប់ Logo និង QR ច្បាស់) ──────────────────
  Widget _buildWatermarkImage(
      String imageUrl,
      String sellerName,
      String sellerPhone,
      String productId,
      ) {
    return Container(
      width: 500, // កំណត់ទំហំឱ្យច្បាស់ដើម្បីកុំឱ្យបាត់ Logo
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // រូបភាពទំនិញ
          CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.cover,
            width: 500,
            height: 500,
          ),
          // ផ្នែកខាងក្រោម (Watermark)
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              children: [
                // QR Code
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: // ✅ កូដថ្មី (ត្រូវទិសសម្រាប់ Sesan App)
                  QrImageView(
                    data: "product_id_${productId}",
                    size: 180.0,
                  ),
                ),
                const SizedBox(width: 16),
                // ព័ត៌មានអ្នកលក់
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "រក្សាសិទ្ធិដោយ៖ $sellerName",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.black,
                          fontFamily: 'Siemreap',
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "ទំនាក់ទំនង៖ $sellerPhone",
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                          fontFamily: 'Siemreap',
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        "ស្កេនដើម្បីមើលក្នុង Sesan App",
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
                          fontStyle: FontStyle.italic,
                          fontFamily: 'Siemreap',
                        ),
                      ),
                    ],
                  ),
                ),
                // Logo Sesan (ប្រើ Image.asset ផ្ទាល់ដើម្បីឱ្យជាប់រហូត)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    'assets/sesan_icon.jpg',
                    width: 45,
                    height: 45,
                    fit: BoxFit.cover,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  Future<void> _processWatermarkAction(
      String imageUrl, {
        bool isShare = false,
        String? shareText,
      }) async {
    try {
      Get.dialog(
        const Center(child: CircularProgressIndicator(color: Colors.white)),
        barrierDismissible: false,
      );

      final image = await _screenshotController.captureFromWidget(
        _buildWatermarkImage(
          imageUrl,
          widget.product['seller_name'] ?? 'អាជីវករ សេសាន',
          widget.product['phone1'] ?? '088XXXXXXX',
          widget.product['id'] ?? '',
        ),
        delay: const Duration(milliseconds: 1500),
        pixelRatio: 6.0,
      );

      Get.back();

      final tempDir = await getTemporaryDirectory();

      // ✅ រក្សាទុកជា PNG ដំបូង
      final pngFile = File(
        '${tempDir.path}/sesan_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await pngFile.writeAsBytes(image);

      // ✅ បង្ហាប់ជា JPEG គុណភាព 100 (មិនបាត់បង់គុណភាព)
      final jpgFile = File(
        '${tempDir.path}/sesan_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await FlutterImageCompress.compressAndGetFile(
        pngFile.path,
        jpgFile.path,
        quality: 100, // ✅ គុណភាពខ្ពស់បំផុត
        format: CompressFormat.jpeg,
      );

      if (isShare) {
        await Share.shareXFiles(
          [XFile(jpgFile.path)],
          text: shareText ?? 'Sesan App',
        );
      } else {
        // ✅ រក្សាទុកជា JPEG គុណភាពខ្ពស់
        await Gal.putImage(jpgFile.path);
        Get.snackbar(
          "ជោគជ័យ!",
          "បានរក្សាទុកក្នុង Gallery រួចរាល់! ✅",
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.green,
          colorText: Colors.white,
          margin: const EdgeInsets.all(15),
          icon: const Icon(Icons.check_circle, color: Colors.white),
        );
      }
    } catch (e) {
      Get.back();
      debugPrint("Error: $e");
      Get.snackbar(
        "កំហុស",
        "មិនអាចរក្សាទុកបាន: $e",
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }
  // ── Save Product with Watermark ──────────────────────────────────
  Future<void> _saveProductWithWatermark() async {
    try {
      // ១. ទាញរូបភាពទុកមុន (បាត់ Error displayImages)
      List<String> images = [];
      if (widget.product['image_urls'] != null) {
        images = List<String>.from(widget.product['image_urls']);
      } else if (widget.product['image_url'] != null) {
        images = [widget.product['image_url']];
      }
      if (images.isEmpty) return;


      // ២. បង្ហាញ Loading តូចមួយ (មិនឱ្យជាន់ UI របស់ Watermark)
      Get.rawSnackbar(
        message: "កំពុងរៀបចំរូបភាព...",
        showProgressIndicator: true,
        duration: const Duration(seconds: 2),
      );


      // ៣. ថតរូប Screenshot (បញ្ជូនទិន្នន័យ ID ឱ្យគ្រប់ដើម្បីបាត់ Error positional args)
      final image = await _screenshotController.captureFromWidget(
        _buildWatermarkImage(
          images[0], // រូបភាពទី១
          widget.product['seller_name'] ?? 'អាជីវករ​ សេសាន', // ឈ្មោះអ្នកលក់
          widget.product['phone1'] ?? '088XXXXXXX', // លេខទូរស័ព្ទ
          widget.product['id'] ?? '', // ID ផលិតផល
        ),
        delay: const Duration(milliseconds: 500),
      );


      // ៤. រក្សាទុក និង Share
      final tempDir = await getTemporaryDirectory();
      final file = File(
        '${tempDir.path}/sesan_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(image);


      // ✅ Save ចូល Gallery (ដោះស្រាយបញ្ហា Save អត់ចូល)
      await Gal.putImage(file.path);
      // ✅ បើកផ្ទាំង Share
      await Share.shareXFiles([XFile(file.path)], text: 'Sesan App');
    } catch (e) {
      debugPrint("Error: $e");
      // _showSnack('❌ កំហុស: $e', Colors.red);
      // 🎯 កូដសម្រាប់បង្ហាញសារ "បានរក្សាទុក" ឱ្យលោតពីលើចុះមក
      Get.snackbar(
        "ជោគជ័យ!", // ចំណងជើង
        "បានរក្សាទុកក្នុង Gallery រួចរាល់! ✅", // សារបង្ហាញ
        snackPosition: SnackPosition.TOP, // ឱ្យលោតពីខាងលើ
        backgroundColor: Colors.green.withOpacity(0.9),
        colorText: Colors.white,
        margin: const EdgeInsets.all(15),
        borderRadius: 15,
        duration: const Duration(seconds: 3),
        icon: const Icon(Icons.check_circle, color: Colors.white),
      );
    }
  }
  Future<void> _shareProductWithWatermark() async {
    // 1. ទាញរូបភាពទីមួយ
    String firstImage = "";
    if (widget.product['image_urls'] != null &&
        widget.product['image_urls'] is List &&
        (widget.product['image_urls'] as List).isNotEmpty) {
      firstImage = (widget.product['image_urls'] as List).first.toString();
    } else if (widget.product['image_url'] != null &&
        widget.product['image_url'].toString().isNotEmpty) {
      firstImage = widget.product['image_url'].toString();
    }

    // 2. ទាញទិន្នន័យផលិតផល
    final String productId = widget.product['id'] ?? '';
    final String productName = widget.product['product_name'] ?? 'ទំនិញថ្មី';

    String priceString = (widget.product['price'] ?? '0').toString().replaceAll(',', '');
    double priceValue = double.tryParse(priceString) ?? 0;
    String price = NumberFormat('#,###').format(priceValue);
    String currency = widget.product['currency']?.toString() ?? '៛';
    String location = widget.product['location'] ?? 'ភ្នំពេញ';

    // 3. Link សម្រាប់ចែករំលែក
    final String webLink = "https://sesanshop.com/product/$productId";

    // 4. Link ទាញយក App
    final String iosAppStoreLink = "https://apps.apple.com/app/sesan-agri/idYOUR_APP_STORE_ID";
    final String androidPlayStoreLink = "https://play.google.com/store/apps/details?id=com.sesan.app";

    // 5. បង្កើតសារចែករំលែក (ប្រើតែ Web Link ដើម្បីឲ្យចុចបានគ្រប់កម្មវិធី)
    final String shareMessage = '''
🛍️ $productName
💰 តម្លៃ៖ $price $currency
📍 $location

🔗 មើលទំនិញ៖
$webLink

📲 ទាញយក App Sesan៖
iOS: $iosAppStoreLink
Android: $androidPlayStoreLink
''';

    // 6. បើគ្មានរូប ចែករំលែកតែ Link
    if (firstImage.isEmpty) {
      await Share.share(shareMessage);
      return;
    }

    // 7. មានរូប ចែករំលែកជាមួយ Watermark
    await _processWatermarkAction(
      firstImage,
      isShare: true,
      shareText: shareMessage,
    );
  }

  void _showSaveOption(BuildContext context) {
    String firstImage = "";
    if (widget.product['image_urls'] != null &&
        widget.product['image_urls'].isNotEmpty) {
      firstImage = widget.product['image_urls'][0];
    } else {
      firstImage = widget.product['image_url'] ?? "";
    }


    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  "ចែករំលែកទំនិញ",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    fontFamily: 'Siemreap',
                  ),
                ),
                const SizedBox(height: 20),


                // ✅ Share Link (ឥឡូវភ្ជាប់រូប Watermark)
                _buildOptionTile(
                  icon: Icons.link,
                  color: Colors.blue[700]!,
                  title: "ចែករំលែក Link ទំនិញ",
                  subtitle: "ផ្ញើរូបភាពមាន QR Code និង Link",
                  onTap: () {
                    Navigator.pop(context);
                    _shareProductWithWatermark(); // ✅ ហៅ method ថ្មី
                  },
                ),
                const SizedBox(height: 12),


                // ✅ Save រូបភាព (ទុកដដែល)
                _buildOptionTile(
                  icon: Icons.download,
                  color: Colors.green,
                  title: "រក្សាទុករូបភាព (Watermark)",
                  subtitle: "រក្សាទុកក្នុង Gallery",
                  onTap: () {
                    Navigator.pop(context);
                    _processWatermarkAction(firstImage, isShare: false);
                  },
                ),


                // ❌ លុប Share រូបភាព Watermark ចេញ
                const SizedBox(height: 15),
              ],
            ),
          ),
        ),
      ),
    );
  }


  // ── ៥. ប៊ូតុងក្នុងអេក្រង់មើលរូបភាពធំ (Viewer) ឱ្យដើរតាម Index ──────────────────
  void _openImageViewer(
      BuildContext context,
      List<String> urls,
      int initialIndex,
      ) {
    int currentIndex = initialIndex;


    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StatefulBuilder(
          builder: (context, setState) => Scaffold(
            backgroundColor: Colors.black,
            extendBodyBehindAppBar: true,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.download, color: Colors.white),
                  onPressed: () => _processWatermarkAction(
                    urls[currentIndex],
                    isShare: false,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.share, color: Colors.white),
                  onPressed: () => _processWatermarkAction(
                    urls[currentIndex],
                    isShare: true,
                  ),
                ),
              ],
            ),
            body: PhotoViewGallery.builder(
              itemCount: urls.length,
              pageController: PageController(initialPage: initialIndex),
              onPageChanged: (index) => setState(() => currentIndex = index),
              builder: (context, index) => PhotoViewGalleryPageOptions(
                imageProvider: CachedNetworkImageProvider(urls[index]),
                minScale: PhotoViewComputedScale.contained,
              ),
            ),
          ),
        ),
      ),
    );
  }


  // ── Build Option Tile ────────────────────────────────────────────
  Widget _buildOptionTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 24),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontFamily: 'Siemreap',
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey[500],
          fontFamily: 'Siemreap',
        ),
      ),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onTap: onTap,
    );
  }


  // ── Share Original Image ─────────────────────────────────────────
  Future<void> _shareOriginalImage() async {
    try {
      List<String> images = [];
      if (widget.product['image_urls'] != null &&
          widget.product['image_urls'] is List) {
        images = List<String>.from(widget.product['image_urls']);
      } else if (widget.product['image_url'] != null) {
        images = [widget.product['image_url']];
      }


      if (images.isEmpty) return;


      Get.dialog(
        const Center(child: CircularProgressIndicator()),
        barrierDismissible: false,
      );


      // Download image
      final response = await Dio().get(
        images[0],
        options: Options(responseType: ResponseType.bytes),
      );


      // Save to temp file
      final tempDir = await getTemporaryDirectory();
      final file = File(
        '${tempDir.path}/sesan_original_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await file.writeAsBytes(response.data);


      Get.back();


      // Share
      await Share.shareXFiles([
        XFile(file.path),
      ], text: '${widget.product['product_name'] ?? 'Sesan Product'}');
    } catch (e) {
      Get.back();
      _showSnack('❌ កំហុស: $e', Colors.red);
    }
  }


  // ── Load User ID និង Rating របស់គណនីនេះ ─────────────────────────
  Future<void> _loadUid() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final firebaseUid = FirebaseAuth.instance.currentUser?.uid;
      final savedUid = prefs.getString('user_uid');
      final uid = (firebaseUid != null && firebaseUid.isNotEmpty)
          ? firebaseUid
          : savedUid;

      if (!mounted) return;

      setState(() {
        _currentUserId = uid;
      });

      if (uid == null || uid.isEmpty) return;

      final productId = widget.product['id']?.toString() ?? '';
      if (productId.isEmpty) return;

      final ratingDoc = await FirebaseFirestore.instance
          .collection('products')
          .doc(productId)
          .collection('ratings')
          .doc(uid)
          .get();

      if (!mounted || !ratingDoc.exists) return;

      final data = ratingDoc.data();
      setState(() {
        _myRating = (data?['rating'] as num?)?.toDouble() ?? 0.0;
      });
    } catch (e) {
      debugPrint("Error loading UID/rating: $e");
    }
  }


  // ── Submit Rating: User ម្នាក់ = Rating មួយ ─────────────────────
  Future<void> _submitRating(double rating) async {
    final l10n = AppLocalizations.of(context);
    if (_isSubmittingRating) return;

    if (rating < 1 || rating > 5) {
      _showSnack(l10n.chooseRating, Colors.orange);
      return;
    }

    final uid = _currentUserId ?? FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      _showSnack(l10n.loginBeforeRating, Colors.orange);
      return;
    }

    final productId = widget.product['id']?.toString() ?? '';
    if (productId.isEmpty) {
      _showSnack(l10n.productIdNotFound, Colors.red);
      return;
    }

    setState(() {
      _isSubmittingRating = true;
    });

    try {
      final firestore = FirebaseFirestore.instance;
      final productRef = firestore.collection('products').doc(productId);
      final ratingRef = productRef.collection('ratings').doc(uid);

      await firestore.runTransaction((transaction) async {
        final productSnapshot = await transaction.get(productRef);
        if (!productSnapshot.exists) {
          throw Exception('Product មិនមានក្នុង Firestore');
        }

        final ratingSnapshot = await transaction.get(ratingRef);
        final productData = productSnapshot.data() ?? <String, dynamic>{};

        final oldAverage =
            (productData['avgRating'] as num?)?.toDouble() ?? 0.0;
        final oldCount =
            (productData['totalReviews'] as num?)?.toInt() ?? 0;

        double newAverage;
        int newCount;

        if (ratingSnapshot.exists) {
          // User ធ្លាប់ Rate រួច៖ កែពិន្ទុចាស់ មិនបន្ថែមចំនួន Review
          final oldUserRating =
              (ratingSnapshot.data()?['rating'] as num?)?.toDouble() ?? 0.0;

          newCount = oldCount > 0 ? oldCount : 1;
          final oldTotalScore = oldAverage * newCount;
          newAverage =
              (oldTotalScore - oldUserRating + rating) / newCount;

          transaction.set(
            ratingRef,
            {
              'userId': uid,
              'rating': rating,
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
        } else {
          // User ថ្មី៖ បន្ថែម Review ១ និងគណនា Average ថ្មី
          newCount = oldCount + 1;
          final oldTotalScore = oldAverage * oldCount;
          newAverage = (oldTotalScore + rating) / newCount;

          transaction.set(ratingRef, {
            'userId': uid,
            'productId': productId,
            'rating': rating,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        // ការពារតម្លៃលើស 5 ឬក្រោម 0 ដោយសារ data ចាស់មិនត្រឹមត្រូវ
        newAverage = newAverage.clamp(0.0, 5.0).toDouble();

        transaction.update(productRef, {
          'avgRating': newAverage,
          'totalReviews': newCount,
          'lastRatedAt': FieldValue.serverTimestamp(),
        });
      });

      if (!mounted) return;

      setState(() {
        _myRating = rating;
      });

      _showSnack(l10n.ratingThanks, Colors.green);
    } catch (e) {
      debugPrint("Error submitting rating: $e");
      if (mounted) {
        _showSnack(l10n.ratingFailed(e.toString()), Colors.red);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmittingRating = false;
        });
      }
    }
  }


  // ── Share Current Image from Viewer ──────────────────────────────
  Future<void> _shareCurrentImage(String url) async {
    try {
      Get.dialog(
        const Center(child: CircularProgressIndicator()),
        barrierDismissible: false,
      );


      final response = await Dio().get(
        url,
        options: Options(responseType: ResponseType.bytes),
      );


      final tempDir = await getTemporaryDirectory();
      final file = File(
        '${tempDir.path}/sesan_viewer_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await file.writeAsBytes(response.data);


      Get.back();


      await Share.shareXFiles([
        XFile(file.path),
      ], text: 'Sesan Store - មើលផលិតផលនេះក្នុង App');
    } catch (e) {
      Get.back();
      _showSnack('❌ កំហុស: $e', Colors.red);
    }
  }


  // ── Show Snack Bar ───────────────────────────────────────────────
  void _showSnack(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontFamily: 'Siemreap')),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bool isAddToCartDisabled =
        widget.product['is_locked'] == true ||
            widget.product['shipping_included'] == false;
    // ក្នុង build() មុន return Scaffold...
    List<String> displayImages = [];
    if (widget.product['image_urls'] != null && widget.product['image_urls'] is List) {
      displayImages = List<String>.from(widget.product['image_urls']);
    } else if (widget.product['image_url'] != null && widget.product['image_url'] != "") {
      displayImages = [widget.product['image_url']];
    }

    final bool hasVideo = widget.product['video_url'] != null &&
        widget.product['video_url'].toString().isNotEmpty;
    final int imageCount = displayImages.length;
    final int totalSlides = imageCount + (hasVideo ? 1 : 0);


    final NumberFormat currencyFormat = NumberFormat("#,###", "en_US");


    for (var url in displayImages) {
      precacheImage(CachedNetworkImageProvider(url), context);
    }


    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios,
            color: Colors.white,
          ), // ប្រើ arrow_back_ios មើលទៅ Premium ជាង
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Text(
          widget.product['product_name'] ?? l10n.productDetails,
          style: const TextStyle(color: Colors.white), // ✅ បន្ថែម
        ),
        backgroundColor: Colors.blue,
        actions: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('bookmarks')
            // ❌ ចាស់
                .where(
              'userId',
              isEqualTo: FirebaseAuth.instance.currentUser?.uid,
            )
            // ✅ ថ្មី — ប្រើ _currentUserId ពី initState
                .where('userId', isEqualTo: _currentUserId)
            // កែពី widget.productId មកជា widget.product['id']
                .where('productId', isEqualTo: widget.product['id'])
                .snapshots(),
            builder: (context, snapshot) {
              bool alreadySaved =
                  snapshot.hasData && snapshot.data!.docs.isNotEmpty;


              return IconButton(
                icon: Icon(
                  alreadySaved ? Icons.bookmark : Icons.bookmark_border,
                  color: alreadySaved ? Colors.yellowAccent : Colors.white,
                  size: 28,
                ),
                onPressed: () => _toggleSave(alreadySaved, context),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () =>
                _showSaveOption(context), // ✅ ហៅ BottomSheet ដែលមានជម្រើសច្រើន
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ១. រូបភាពស្លាយ
                  // ១. រូបភាពស្លាយ (Square 1:1)
                  Stack(
                    children: [
                      AspectRatio(
                        aspectRatio: 1 / 1,
                        child: PageView.builder(
                          itemCount: totalSlides,
                          onPageChanged: (index) {
                            setState(() => _currentPage = index);
                            // ឈប់វីដេអូពេលចេញពីសន្លឹកវីដេអូ
                            if (_videoController != null && _isVideoInitialized && _videoController!.value.isPlaying) {
                              // បើសន្លឹកបច្ចុប្បន្នមិនមែនជាវីដេអូ → ឈប់
                              if (index != imageCount) {
                                _videoController!.pause();
                                setState(() {});
                              }
                            }
                          },
                          itemBuilder: (context, index) {
                            // បើជាសន្លឹកវីដេអូ
                            if (hasVideo && index == imageCount) {
                              final isPlaying = _videoController?.value.isPlaying ?? false;
                              return GestureDetector(
                                onTap: () {
                                  if (_videoController == null || !_isVideoInitialized) return;
                                  setState(() {
                                    if (_videoController!.value.isPlaying) {
                                      _videoController!.pause();
                                    } else {
                                      _videoController!.play();
                                    }
                                  });
                                },
                                child: Container(
                                  color: Colors.black,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      // វីដេអូ / រង់ចាំផ្ទុក
                                      if (_videoController != null && _isVideoInitialized)
                                        AspectRatio(
                                          aspectRatio: _videoController!.value.aspectRatio,
                                          child: VideoPlayer(_videoController!),
                                        )
                                      else
                                        const Center(
                                          child: CircularProgressIndicator(color: Colors.white),
                                        ),

                                      // ប៊ូតុង Play/Pause (បង្ហាញលុះត្រាតែបានផ្ទុករួច)
                                      if (_isVideoInitialized)
                                        IgnorePointer(
                                          // ឲ្យការចុចឆ្លងទៅ GestureDetector ខាងលើ
                                          ignoring: true,
                                          child: AnimatedOpacity(
                                            duration: const Duration(milliseconds: 300),
                                            opacity: isPlaying ? 0.0 : 1.0,
                                            child: Container(
                                              width: 64,
                                              height: 64,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: Colors.black.withOpacity(0.5),
                                              ),
                                              child: Icon(
                                                isPlaying ? Icons.pause : Icons.play_arrow_rounded,
                                                color: Colors.white,
                                                size: 48,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            }

                            // រូបភាពធម្មតា
                            return GestureDetector(
                              onLongPress: () => _showSaveOption(context),
                              onTap: () {
                                if (displayImages.isNotEmpty) {
                                  _openImageViewer(context, displayImages, index);
                                }
                              },
                              child: CachedNetworkImage(
                                imageUrl: displayImages[index],
                                fit: BoxFit.cover,
                                maxWidthDiskCache: 1000,
                                placeholder: (context, url) => Container(color: Colors.grey[200]),
                                errorWidget: (context, url, error) => const Icon(
                                  Icons.broken_image, size: 50, color: Colors.grey,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      // លេខរាប់រូបភាព និងវីដេអូ
                      if (totalSlides > 1)
                        Positioned(
                          bottom: 15,
                          right: 15,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              "${_currentPage + 1} / $totalSlides", // ✅ ប្រើ totalSlides
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  // ... កូដផ្នែកខាងក្រោមរបស់មេ
                  Padding(
                    padding: const EdgeInsets.all(15.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "${widget.product['price'] ?? '0'} ${widget.product['currency'] ?? '៛'}",
                          style: const TextStyle(
                            fontSize: 28,
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        // ✅ បន្ថែមការបញ្ជាក់ថ្លៃដឹក (បើមាន field shipping_included)
                        if (widget.product['shipping_included'] != null) ...[
                          const SizedBox(height: 4),
                          Container(
                            // ❌ remove margin horizontal — already inside Padding(15)
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: widget.product['shipping_included'] == true
                                  ? Colors.green.shade50
                                  : Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color:
                                (widget.product['shipping_included'] == true
                                    ? Colors.green.shade700
                                    : Colors.orange.shade700)
                                    .withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize
                                  .min, // shrink-wrap instead of stretching
                              children: [
                                Icon(
                                  widget.product['shipping_included'] == true
                                      ? Icons.check_circle_outline
                                      : Icons.local_shipping_outlined,
                                  color:
                                  widget.product['shipping_included'] == true
                                      ? Colors.green.shade700
                                      : Colors.orange.shade700,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    widget.product['shipping_included'] == true
                                        ? l10n.shippingIncluded
                                        : l10n.shippingNotIncluded,
                                    style: TextStyle(
                                      color:
                                      widget.product['shipping_included'] ==
                                          true
                                          ? Colors.green.shade700
                                          : Colors.orange.shade700,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w500,
                                      fontFamily: 'Siemreap',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        Text(
                          widget.product['product_name'] ?? l10n.unnamedProduct,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),


                        // ✅ បន្ថែមពីទីនេះ - បង្ហាញ Category និង Sub Category
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            // Category មេ
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.green.withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                widget.product['category'] ?? 'ផ្សេងៗ',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.green,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'Siemreap',
                                ),
                              ),
                            ),


                            // Sub Category (បង្ហាញតែពេលមាន និងមិនមែន "ទាំងអស់")
                            if (widget.product['sub_category'] != null &&
                                widget.product['sub_category']
                                    .toString()
                                    .isNotEmpty &&
                                widget.product['sub_category'] != 'ទាំងអស់') ...[
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.arrow_forward_ios,
                                size: 10,
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.orange.withOpacity(0.3),
                                  ),
                                ),
                                child: Text(
                                  widget.product['sub_category'] ?? '',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.orange,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'Siemreap',
                                  ),
                                ),
                              ),
                            ],


                            // Sub-Sub Category (បង្ហាញតែពេលមាន និងមិនមែន "ទាំងអស់")
                            if (widget.product['sub_sub_category'] != null &&
                                widget.product['sub_sub_category']
                                    .toString()
                                    .isNotEmpty &&
                                widget.product['sub_sub_category'] !=
                                    'ទាំងអស់') ...[
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.arrow_forward_ios,
                                size: 10,
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.red.withOpacity(0.3),
                                  ),
                                ),
                                child: Text(
                                  widget.product['sub_sub_category'] ?? '',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.red,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'Siemreap',
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),


                        // ✅ Average រួម + Rating ផ្ទាល់របស់គណនីនេះ
                        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                          stream: FirebaseFirestore.instance
                              .collection('products')
                              .doc(widget.product['id'])
                              .snapshots(),
                          builder: (context, productSnapshot) {
                            double avgRating =
                                (widget.product['avgRating'] as num?)
                                    ?.toDouble() ??
                                    0.0;
                            int totalReviews =
                                (widget.product['totalReviews'] as num?)
                                    ?.toInt() ??
                                    0;

                            if (productSnapshot.hasData &&
                                productSnapshot.data!.exists) {
                              final data = productSnapshot.data!.data();
                              avgRating =
                                  (data?['avgRating'] as num?)?.toDouble() ??
                                      0.0;
                              totalReviews =
                                  (data?['totalReviews'] as num?)?.toInt() ?? 0;
                            }

                            final uid = _currentUserId;

                            Widget buildRating(double myRating) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      RatingBarIndicator(
                                        rating: avgRating,
                                        itemBuilder: (context, _) => const Icon(
                                          Icons.star,
                                          color: Colors.amber,
                                        ),
                                        itemCount: 5,
                                        itemSize: 22,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${avgRating.toStringAsFixed(1)} '
                                            '${l10n.reviewCount(totalReviews)}',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    myRating > 0
                                        ? l10n.yourRating(myRating.toStringAsFixed(1))
                                        : l10n.tapStarsToRate,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: myRating > 0
                                          ? Colors.green.shade700
                                          : Colors.grey.shade600,
                                      fontFamily: 'Siemreap',
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  IgnorePointer(
                                    ignoring: _isSubmittingRating,
                                    child: Opacity(
                                      opacity: _isSubmittingRating ? 0.5 : 1.0,
                                      child: RatingBar.builder(
                                        initialRating: myRating,
                                        minRating: 1,
                                        direction: Axis.horizontal,
                                        allowHalfRating: true,
                                        itemCount: 5,
                                        itemSize: 30,
                                        itemPadding: const EdgeInsets.symmetric(
                                          horizontal: 3,
                                        ),
                                        itemBuilder: (context, _) => const Icon(
                                          Icons.star,
                                          color: Colors.amber,
                                        ),
                                        onRatingUpdate: _submitRating,
                                      ),
                                    ),
                                  ),
                                  if (_isSubmittingRating)
                                    const Padding(
                                      padding: EdgeInsets.only(top: 6),
                                      child: SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            }

                            if (uid == null || uid.isEmpty) {
                              return buildRating(0.0);
                            }

                            return StreamBuilder<
                                DocumentSnapshot<Map<String, dynamic>>>(
                              stream: FirebaseFirestore.instance
                                  .collection('products')
                                  .doc(widget.product['id'])
                                  .collection('ratings')
                                  .doc(uid)
                                  .snapshots(),
                              builder: (context, ratingSnapshot) {
                                double myRating = _myRating;

                                if (ratingSnapshot.hasData &&
                                    ratingSnapshot.data!.exists) {
                                  myRating = (ratingSnapshot.data!
                                      .data()?['rating'] as num?)
                                      ?.toDouble() ??
                                      0.0;
                                }

                                return buildRating(myRating);
                              },
                            );
                          },
                        ),


                        const Divider(
                          height: 30,
                        ), // ៤. ចំនួនកម្ម៉ង់ និង តម្លៃសរុប
                        Text(
                          l10n.chooseQuantity,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        // --- ផ្នែកជ្រើសរើសចំនួន និង តម្លៃសរុប (កូដដែលកែរួច) ---
                        StatefulBuilder(
                          builder: (context, setState) {
                            double unitPrice =
                                double.tryParse(
                                  widget.product['price'].toString().replaceAll(
                                    ',',
                                    '',
                                  ),
                                ) ??
                                    0;
                            double totalPrice = unitPrice * _tempQty;


                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    _qtyActionBtn(Icons.remove, () {
                                      if (_tempQty > 1)
                                        setState(() => _tempQty--);
                                    }),
                                    Container(
                                      width: 80, // កែទំហំឱ្យល្មម
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                      ),
                                      child: TextField(
                                        keyboardType: TextInputType.number,
                                        textAlign: TextAlign.center,
                                        // ✅ កំណត់ឱ្យវាយបានត្រឹម 3 ខ្ទង់ (999)
                                        inputFormatters: [
                                          LengthLimitingTextInputFormatter(3),
                                          FilteringTextInputFormatter.digitsOnly,
                                        ],
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                        decoration: InputDecoration(
                                          contentPadding:
                                          const EdgeInsets.symmetric(
                                            vertical: 8,
                                          ),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          counterText:
                                          "", // បិទអក្សររាប់ខ្ទង់ខាងក្រោម
                                        ),
                                        controller:
                                        TextEditingController(
                                          text: "$_tempQty",
                                        )
                                          ..selection =
                                          TextSelection.collapsed(
                                            offset: "$_tempQty".length,
                                          ),
                                        onChanged: (value) {
                                          int? val = int.tryParse(value);
                                          if (val != null) {
                                            if (val > 999) {
                                              setState(() => _tempQty = 999);
                                            } else if (val > 0) {
                                              setState(() => _tempQty = val);
                                            }
                                          }
                                        },
                                      ),
                                    ),
                                    _qtyActionBtn(Icons.add, () {
                                      // ✅ ចុចបូកបានត្រឹម 999
                                      if (_tempQty < 999)
                                        setState(() => _tempQty++);
                                    }),
                                    const SizedBox(width: 10),
                                    Text(
                                      l10n.quantity,
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontFamily: 'Siemreap',
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 15),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: Colors.blue.withOpacity(0.2),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        l10n.totalPrice,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                          fontFamily: 'Siemreap',
                                        ),
                                      ),
                                      const SizedBox(
                                        width: 10,
                                      ), // បន្ថែមចន្លោះតិចតួច
                                      // ✅ ប្រើ Expanded ការពារការបែក UI (Overflow) ពេលតម្លៃឡើងកោដិ
                                      Expanded(
                                        child: Text(
                                          "${currencyFormat.format(totalPrice)} ${widget.product['currency'] ?? '៛'}",
                                          textAlign: TextAlign.right,
                                          style: const TextStyle(
                                            fontSize: 20,
                                            color: Colors.blue,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          overflow: TextOverflow
                                              .ellipsis, // បើវែងពេកវាចេញ ...
                                          maxLines: 1,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        ),


                        const Divider(height: 30),
                        Text(
                          l10n.descriptionLabel,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          widget.product['description'] ?? l10n.noDescription,
                          style: const TextStyle(fontSize: 16),
                        ),


                        // --- ផ្នែកព័ត៌មានអ្នកលក់ (Update ថ្មី អាចចុចចូលមើល Profile បាន) ---
                        Container(
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: Colors.green.withOpacity(0.2),
                            ),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.storefront,
                                        color: Colors.green,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        l10n.sellerInformation,
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green.shade800,
                                        ),
                                      ),
                                    ],
                                  ),
                                  // 🎯 ប៊ូតុង "ចូលមើលហាង"
                                  TextButton.icon(
                                    onPressed: () {
                                      // ហៅទៅកាន់អេក្រង់ SellerProfileScreen ដែលមេបានបង្កើត
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              SellerProfileScreen(
                                                sellerId:
                                                widget.product['seller_id'] ??
                                                    '',
                                                sellerName:
                                                widget
                                                    .product['seller_name'] ??
                                                    l10n.seller,
                                              ),
                                        ),
                                      );
                                    },
                                    icon: const Icon(
                                      Icons.arrow_forward,
                                      size: 16,
                                    ),
                                    label: Text(l10n.viewShop),
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.blue,
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 20),
                              // 🎯 ចុចលើ Profile ក៏អាចចូលទៅមើលបានដែរ
                              InkWell(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => SellerProfileScreen(
                                        sellerId:
                                        widget.product['seller_id'] ?? '',
                                        sellerName:
                                        widget.product['seller_name'] ??
                                            l10n.seller,
                                      ),
                                    ),
                                  );
                                },
                                child: ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: CircleAvatar(
                                    radius: 25,
                                    backgroundColor: Colors.green.shade100,
                                    backgroundImage:
                                    (widget.product['seller_photo'] != null &&
                                        widget.product['seller_photo'] != '')
                                        ? NetworkImage(
                                      widget.product['seller_photo'],
                                    )
                                        : null,
                                    child:
                                    (widget.product['seller_photo'] == null ||
                                        widget.product['seller_photo'] == '')
                                        ? const Icon(
                                      Icons.person,
                                      color: Colors.green,
                                      size: 30,
                                    )
                                        : null,
                                  ),
                                  title: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          widget.product['seller_name'] ?? l10n.unknownName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      // ✅ Verified Badge
                                      if (widget.product['shop_tier'] != null &&
                                          (widget.product['shop_tier'] == 'basic' ||
                                              widget.product['shop_tier'] == 'premium'))
                                        Container(
                                          margin: const EdgeInsets.only(left: 8),
                                          padding: const EdgeInsets.all(2),
                                          decoration: BoxDecoration(
                                            color: widget.product['shop_tier'] == 'premium'
                                                ? Colors.amber.withOpacity(0.8)
                                                : Colors.blueAccent.withOpacity(0.8),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            widget.product['shop_tier'] == 'premium'
                                                ? Icons.diamond_rounded
                                                : Icons.verified_user_rounded,
                                            color: Colors.white,
                                            size: 14,
                                          ),
                                        ),
                                    ],
                                  ),
                                  subtitle: Text(
                                    widget.product['updated_at'] != null
                                        ? l10n.postedAt(DateFormat('dd-MM-yyyy HH:mm').format((widget.product['updated_at'] as Timestamp).toDate()))
                                        : l10n.farmerOrSeller,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  trailing: const Icon(
                                    Icons.chevron_right,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                              // ... កូដផ្នែកលេខទូរស័ព្ទ និងទីតាំងរបស់មេទុកដដែល
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(
                                  Icons.phone,
                                  color: Colors.orange,
                                ),
                                title: Text(
                                  widget.product['phone1'] ?? l10n.noPhone,
                                ),
                                trailing: IconButton(
                                  icon: const Icon(
                                    Icons.call,
                                    color: Colors.green,
                                  ),
                                  onPressed: () async {
                                    final url = Uri.parse(
                                      "tel:${widget.product['phone1']}",
                                    );
                                    if (await canLaunchUrl(url))
                                      await launchUrl(url);
                                  },
                                ),
                              ),
                              if (widget.product['phone2'] != null &&
                                  widget.product['phone2'].toString().isNotEmpty)
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(
                                    Icons.phone_android,
                                    color: Colors.orange,
                                  ),
                                  title: Text(
                                    widget.product['phone2'].toString(),
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(
                                      Icons.call,
                                      color: Colors.green,
                                    ),
                                    onPressed: () async {
                                      final url = Uri.parse(
                                        "tel:${widget.product['phone2']}",
                                      );
                                      if (await canLaunchUrl(url))
                                        await launchUrl(url);
                                    },
                                  ),
                                ),
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(
                                  Icons.location_on,
                                  color: Colors.red,
                                ),
                                title: Text(
                                  widget.product['location'] ?? l10n.noLocation,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // 🎯 ដាក់ចូលក្នុងជួរ 598 (ចន្លោះ ListTile ទីតាំង និង RelatedProducts)
                        const SizedBox(height: 20),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            l10n.comments,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),


                        // ហៅ Widget Comment មកបង្ហាញតែ ១ ដូចដែលមេចង់បាន
                        // កុំឱ្យវាហៅ CommentSection បើអត់មាន ID ពិតប្រាកដ
                        if (widget.product['id'] != null &&
                            widget.product['id'].toString().isNotEmpty)
                          CommentSection(
                            productId: widget.product['id'],
                            sellerId: widget.product['seller_id'] ?? '',
                            currentUserId: _currentUserId, // ✅ បន្ថែមអង្គនេះ
                          )
                        else
                          Center(child: Text(l10n.noProductData)),
                        const SizedBox(height: 30),
                        // ៦. Related Products
                        RelatedProductsWidget(
                          category: widget.product['category'] ?? '',
                          currentProductId: widget.product['id'] ?? '',
                        ),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),


      // ៧. Bottom Bar
      bottomNavigationBar: Container(
        height: 80,
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.grey.shade300, blurRadius: 5)],
        ),
        child: Row(
          children: [
            _actionIcon(Icons.chat, Colors.orange, () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatScreen(
                    productId: widget.product['id'] ?? '',
                    productName: widget.product['product_name'] ?? '',
                    seller_id: widget.product['seller_id'] ?? '',
                    receiver_id: '',
                  ),
                ),
              );
            }),
            const SizedBox(width: 15),


            // 🎯 ឆែកមើលស្ថានភាព Lock
            // បើជាប់ Lock ឱ្យប៊ូតុងទៅជាពណ៌ប្រផេះ ហើយចុចលែងកើត
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isAddToCartDisabled
                      ? Colors.grey
                      : Colors.blue,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 50),
                ),
                onPressed: isAddToCartDisabled
                    ? null
                    : () => _addToCart(widget.product),
                child: Text(
                  l10n.addToCart,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isAddToCartDisabled
                      ? Colors.grey[400]
                      : Colors.red,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 50),
                ),
                onPressed: isAddToCartDisabled
                    ? null
                    : () async {
                  await _addToCart(widget.product);
                  if (context.mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CartScreen(),
                      ),
                    );
                  }
                },
                child: Text(
                  l10n.buyNow,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),

      ),
    );
  }


  Future<void> _toggleSave(bool alreadySaved, BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final String? savedUid = prefs.getString('user_uid');


    if (savedUid == null || savedUid.isEmpty) {
      Get.snackbar("ចូលប្រើប្រាស់", "សូមមេ Login សិន ទើបអាច Save បាន!");
      return;
    }


    final bookmarkRef = FirebaseFirestore.instance.collection('bookmarks');


    if (alreadySaved) {
      var docs = await bookmarkRef
          .where('userId', isEqualTo: savedUid)
          .where('productId', isEqualTo: widget.product['id'])
          .get();
      for (var doc in docs.docs) {
        await doc.reference.delete();
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("បានលុបចេញពីបញ្ជីរក្សាទុក")));
    } else {
      // ✅ រក្សាទុកទិន្នន័យសំខាន់ៗទាំងអស់
      await bookmarkRef.add({
        'userId': savedUid,
        'productId': widget.product['id'] ?? '',
        'product_name': widget.product['product_name'] ?? 'គ្មានឈ្មោះ',
        'price': widget.product['price'] ?? '0',
        'currency': widget.product['currency'] ?? '៛',
        'location': widget.product['location'] ?? '',
        'description': widget.product['description'] ?? '',
        'category': widget.product['category'] ?? '',
        'sub_category': widget.product['sub_category'] ?? '',
        'sub_sub_category': widget.product['sub_sub_category'] ?? '',
        'seller_id': widget.product['seller_id'] ?? '',
        'seller_name': widget.product['seller_name'] ?? 'មិនស្គាល់',
        'seller_photo': widget.product['seller_photo'] ?? '',
        'seller_phone':
        widget.product['phone1'] ?? widget.product['seller_phone'] ?? '',
        'image_urls': widget.product['image_urls'] ?? [],
        'image_url': widget.product['image_url'] ?? '',
        'is_locked': widget.product['is_locked'] ?? false,
        'is_available': widget.product['is_available'] ?? true,
        'created_at':
        widget.product['created_at'] ?? FieldValue.serverTimestamp(),
        'avgRating': widget.product['avgRating'] ?? 0.0,
        'totalReviews': widget.product['totalReviews'] ?? 0,
        'savedAt': FieldValue.serverTimestamp(),
      });


      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("រក្សាទុកជោគជ័យ! ✅")));
    }
  }


  Widget _qtyActionBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.blue, size: 20),
      ),
    );
  }


  Widget _actionIcon(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color),
      ),
    );
  }


  // ២. កូដ addToCart ដែលកែសម្រួលរួច
  Future<void> _addToCart(Map<String, dynamic> product) async {
    final String finalImageUrl =
        product['image_url'] ??
            (product['image_urls'] != null &&
                (product['image_urls'] as List).isNotEmpty
                ? product['image_urls'][0]
                : "");
    // លុប context ចេញពីក្នុងនេះ
    try {
      final prefs = await SharedPreferences.getInstance();
      String? userId = prefs.getString('user_uid');
      if (userId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("សូមចូលប្រើប្រាស់កម្មវិធីសិន!")),
        );
        return;
      }


      await FirebaseFirestore.instance.collection('carts').add({
        'customer_id': userId,
        // កែត្រង់នេះ៖ បើ .id ក្រហម ប្រើ ['id'] ឬ ['product_id'] ជំនួស
        'product_id': widget.product['id'] ?? '',
        'product_name': widget.product['product_name'] ?? 'គ្មានឈ្មោះ',
        'price': widget.product['price'] ?? 0,
        'image_url': finalImageUrl,
        // កែពី _quantity ទៅជា _tempQty
        'quantity': _tempQty,
        'created_at': FieldValue.serverTimestamp(),
        'seller_id': widget.product['seller_id'] ?? 'UNKNOWN_ID',
        'seller_name': widget.product['seller_name'] ?? 'អាជីវករ សេសាន',
        'seller_phone': widget.product['seller_phone'] ?? '',
        'seller_photo': widget.product['seller_photo'] ?? '',
      });


      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✅ បន្ថែមទៅកន្ត្រករួចរាល់!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint("Error: $e");
    }
  }
}



