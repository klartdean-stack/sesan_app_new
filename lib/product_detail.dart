import 'dart:async';
import 'dart:io';
import 'package:app_links/app_links.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'category_localization.dart';
import 'package:gal/gal.dart';
import 'package:get/get.dart'
    show
        Get,
        Trans,
        ExtensionSnackbar,
        GetNavigation,
        ExtensionDialog,
        SnackPosition;
import 'package:intl/intl.dart';
import 'package:my_app/comment_section.dart';
import 'package:my_app/seller_profile_screen.dart';
import 'package:my_app/share_service.dart';
import 'localized_text.dart';
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
import 'sesan_ai_assistant_screen.dart';

// ✅ កែពី StatelessWidget ទៅជា StatefulWidget
class ProductDetailScreen extends StatefulWidget {
  final Map<String, dynamic> product;
  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  String _maskSellerPhone(dynamic value) {
    final phone = (value ?? '').toString().trim();
    if (phone.isEmpty) return '';
    final digits = phone.replaceAll(RegExp(r'\s+'), '');
    if (digits.length <= 4) return '••••';
    return '${digits.substring(0, digits.length - 4)}••••';
  }
  int _currentPage = 0; // 🎯 បន្ថែមសម្រាប់រាប់លេខរូបភាព
  int _tempQty = 1; // 🎯 ប្តូរពី static មកជា variable ធម្មតាវិញ
  bool isSaved = false; // ស្ថានភាពដំបូង
  String? _currentUserId;
  double _myRating = 0.0;
  bool _isSubmittingRating = false;
  int _quantity = 1;
  bool _wasPaused = false; // ✅ បន្ថែម
  bool _showTranslatedProduct = false;
  bool _isTranslatingProduct = false;
  String? _translatedProductName;
  String? _translatedDescription;
  final PageController _webGalleryController = PageController();
  final ScrollController _webCommentsController = ScrollController();

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
        }).catchError((error) {
          debugPrint('Product video initialization error: $error');
        });
    }
  }

  Future<void> _toggleVideoPlayback() async {
    final controller = _videoController;
    if (controller == null || !_isVideoInitialized) return;

    try {
      if (controller.value.isPlaying) {
        await controller.pause();
      } else {
        final duration = controller.value.duration;
        final position = controller.value.position;
        if (duration > Duration.zero && position >= duration) {
          await controller.seekTo(Duration.zero);
        }
        await controller.play();
      }
      if (mounted) setState(() {});
    } catch (error) {
      debugPrint('Product video playback error: $error');
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
    _webGalleryController.dispose();
    _webCommentsController.dispose();
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

  String _shownProductName(String fallback) {
    if (_showTranslatedProduct &&
        (_translatedProductName?.trim().isNotEmpty ?? false)) {
      return _translatedProductName!.trim();
    }
    final value = (widget.product['product_name'] ?? '').toString().trim();
    return value.isEmpty ? fallback : value;
  }

  String _shownProductDescription(String fallback) {
    if (_showTranslatedProduct &&
        (_translatedDescription?.trim().isNotEmpty ?? false)) {
      return _translatedDescription!.trim();
    }
    final value = (widget.product['description'] ?? '').toString().trim();
    return value.isEmpty ? fallback : value;
  }

  String _firstProductImage() {
    final images = widget.product['image_urls'];
    if (images is List && images.isNotEmpty) {
      return images.first.toString();
    }
    return (widget.product['image_url'] ?? '').toString();
  }

  Future<void> _toggleProductTranslation() async {
    if (_showTranslatedProduct) {
      setState(() => _showTranslatedProduct = false);
      return;
    }
    if (_translatedProductName != null || _translatedDescription != null) {
      setState(() => _showTranslatedProduct = true);
      return;
    }
    if (_isTranslatingProduct) return;

    setState(() => _isTranslatingProduct = true);
    final locale =
        Localizations.localeOf(context).languageCode == 'en' ? 'en' : 'km';
    try {
      final callable = FirebaseFunctions.instanceFor(
        region: 'asia-southeast1',
      ).httpsCallable('generateProductAiContent');
      final result = await callable.call(<String, dynamic>{
        'productName': (widget.product['product_name'] ?? '').toString(),
        'notes': (widget.product['description'] ?? '').toString(),
        'locale': locale,
        'images': const <String>[],
      });
      final data = Map<String, dynamic>.from(result.data as Map);
      if (!mounted) return;
      setState(() {
        _translatedProductName =
            (data[locale == 'en' ? 'title_en' : 'title_km'] ?? '').toString();
        _translatedDescription =
            (data[locale == 'en' ? 'description_en' : 'description_km'] ?? '')
                .toString();
        _showTranslatedProduct = true;
      });
    } catch (error) {
      debugPrint('Product translation error: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              Localizations.localeOf(context).languageCode == 'en'
                  ? 'Could not translate this product. Please try again.'
                  : 'មិនអាចបកប្រែទំនិញនេះបានទេ សូមសាកម្ដងទៀត។',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isTranslatingProduct = false);
    }
  }

  void _openProductAssistant() {
    final english = Localizations.localeOf(context).languageCode == 'en';
    final productId = (widget.product['id'] ?? '').toString();
    final name = (widget.product['product_name'] ?? '').toString();
    final description = (widget.product['description'] ?? '').toString();
    final price = (widget.product['price'] ?? '').toString();
    final currency = (widget.product['currency'] ?? '៛').toString();
    final category = (widget.product['category'] ?? '').toString();
    final seller = (widget.product['seller_name'] ??
            widget.product['shop_name'] ??
            widget.product['seller_id'] ??
            '')
        .toString();

    final prompt = english
        ? '''I am considering buying this product on Sesan App.
Product ID: $productId
Product: $name
Description: $description
Price: $price $currency
Category: $category
Seller/Shop: $seller

Please inspect the attached product image and the information above. Explain its likely uses, what I should verify with the seller, and important cautions before buying. Do not invent missing details.'''
        : '''ខ្ញុំកំពុងពិចារណាទិញទំនិញនេះនៅក្នុង Sesan App។
Product ID៖ $productId
ឈ្មោះទំនិញ៖ $name
បរិយាយ៖ $description
តម្លៃ៖ $price $currency
ប្រភេទ៖ $category
អ្នកលក់/ហាង៖ $seller

សូមពិនិត្យរូបទំនិញដែលបានភ្ជាប់ និងព័ត៌មានខាងលើ។ ជួយពន្យល់ការប្រើប្រាស់ ចំណុចដែលគួរសួរបញ្ជាក់ពីអ្នកលក់ និងអ្វីត្រូវប្រុងប្រយ័ត្នមុនទិញ។ កុំបង្កើតព័ត៌មានដែលមិនមាន។''';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SesanAiAssistantScreen(
          initialPrompt: prompt,
          initialRole: 'agriculture',
          initialImageUrl: _firstProductImage(),
        ),
      ),
    );
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
      width: 500,
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.cover,
            width: 500,
            height: 500,
          ),
          Container(
            height: 194,
            padding: const EdgeInsets.all(12),
            color: Colors.white,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 170,
                  height: 170,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: QrImageView(
                        data: 'product_id_$productId',
                        size: 162,
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(7),
                          child: Image.asset(
                            'assets/sesan_icon.jpg',
                            width: 34,
                            height: 34,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(height: 7),
                        SizedBox(
                          width: double.infinity,
                          height: 28,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              appText(
                                context,
                                km: 'រក្សាសិទ្ធិដោយ៖ $sellerName',
                                en: 'Seller: $sellerName',
                              ),
                              maxLines: 1,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                height: 1.1,
                                color: Colors.black,
                                fontFamily: 'Siemreap',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 3),
                        SizedBox(
                          width: double.infinity,
                          height: 20,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              appText(
                                context,
                                km: 'ទំនាក់ទំនង៖ $sellerPhone',
                                en: 'Contact: $sellerPhone',
                              ),
                              maxLines: 1,
                              style: const TextStyle(
                                fontSize: 9,
                                height: 1.05,
                                color: Colors.black54,
                                fontFamily: 'Siemreap',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          appText(
                            context,
                            km: 'ស្កេនដើម្បីមើលក្នុង Sesan App',
                            en: 'Scan to view in Sesan App',
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 8,
                            height: 1.05,
                            color: Colors.grey,
                            fontStyle: FontStyle.italic,
                            fontFamily: 'Siemreap',
                          ),
                        ),
                      ],
                    ),
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
        targetSize: const Size(500, 694),
        pixelRatio: kIsWeb ? 3.0 : 6.0,
      );

      Get.back();

      final fileName =
          'sesan_${DateTime.now().millisecondsSinceEpoch}.png';

      if (kIsWeb) {
        final webFile = XFile.fromData(
          image,
          mimeType: 'image/png',
          name: fileName,
        );
        await Share.shareXFiles(
          [webFile],
          text: isShare ? (shareText ?? 'Sesan App') : null,
        );
        if (!isShare) {
          Get.snackbar(
            'product_success_title'.tr,
            'product_image_saved_gallery'.tr,
            snackPosition: SnackPosition.TOP,
            backgroundColor: Colors.green,
            colorText: Colors.white,
          );
        }
        return;
      }

      final tempDir = await getTemporaryDirectory();
      final pngFile = File('${tempDir.path}/$fileName');
      await pngFile.writeAsBytes(image);

      final jpgFile = File(
        '${tempDir.path}/sesan_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      final compressed = await FlutterImageCompress.compressAndGetFile(
        pngFile.path,
        jpgFile.path,
        quality: 100,
        format: CompressFormat.jpeg,
      );
      final shareFile = compressed == null ? pngFile : File(compressed.path);

      if (isShare) {
        await Share.shareXFiles(
          [XFile(shareFile.path)],
          text: shareText ?? 'Sesan App',
        );
      } else {
        await Gal.putImage(shareFile.path);
        Get.snackbar(
          'product_success_title'.tr,
          'product_image_saved_gallery'.tr,
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
        'product_error_title'.tr,
        AppLocalizations.of(context).errorMessage(e.toString()),
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> _saveProductWithWatermark() async {
    try {
      List<String> images = [];
      if (widget.product['image_urls'] != null) {
        images = List<String>.from(widget.product['image_urls']);
      } else if (widget.product['image_url'] != null) {
        images = [widget.product['image_url']];
      }
      if (images.isEmpty) return;

      Get.rawSnackbar(
        message: 'product_preparing_image'.tr,
        showProgressIndicator: true,
        duration: const Duration(seconds: 2),
      );

      final image = await _screenshotController.captureFromWidget(
        _buildWatermarkImage(
          images[0],
          widget.product['seller_name'] ?? 'អាជីវករ​ សេសាន',
          widget.product['phone1'] ?? '088XXXXXXX',
          widget.product['id'] ?? '',
        ),
        delay: const Duration(milliseconds: 500),
        targetSize: const Size(500, 694),
        pixelRatio: kIsWeb ? 3.0 : 6.0,
      );

      final tempDir = await getTemporaryDirectory();
      final file = File(
        '${tempDir.path}/sesan_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(image);
      await Gal.putImage(file.path);
      await Share.shareXFiles([XFile(file.path)], text: 'Sesan App');
    } catch (e) {
      debugPrint("Error: $e");
      Get.snackbar(
        'product_success_title'.tr,
        'product_image_saved_gallery'.tr,
        snackPosition: SnackPosition.TOP,
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
    String firstImage = "";
    if (widget.product['image_urls'] != null &&
        widget.product['image_urls'] is List &&
        (widget.product['image_urls'] as List).isNotEmpty) {
      firstImage = (widget.product['image_urls'] as List).first.toString();
    } else if (widget.product['image_url'] != null &&
        widget.product['image_url'].toString().isNotEmpty) {
      firstImage = widget.product['image_url'].toString();
    }

    final String productId = widget.product['id'] ?? '';
    final String productName = widget.product['product_name'] ?? 'ទំនិញថ្មី';

    String priceString = (widget.product['price'] ?? '0').toString().replaceAll(
      ',',
      '',
    );
    double priceValue = double.tryParse(priceString) ?? 0;
    String price = NumberFormat('#,###').format(priceValue);
    String currency = widget.product['currency']?.toString() ?? '៛';
    String location = widget.product['location'] ?? 'ភ្នំពេញ';

    final String webLink = "https://sesanshop.com/product/$productId";
    final String iosAppStoreLink =
        "https://apps.apple.com/app/sesan-agri/idYOUR_APP_STORE_ID";
    final String androidPlayStoreLink =
        "https://play.google.com/store/apps/details?id=com.sesan.app";

    final String shareMessage = appText(
      context,
      km:
          '''
🛍️ $productName
💰 តម្លៃ៖ $price $currency
📍 $location

🔗 មើលទំនិញ៖
$webLink

📲 ទាញយក App Sesan៖
iOS: $iosAppStoreLink
Android: $androidPlayStoreLink
''',
      en:
          '''
🛍️ $productName
💰 Price: $price $currency
📍 $location

🔗 View product:
$webLink

📲 Download Sesan App:
iOS: $iosAppStoreLink
Android: $androidPlayStoreLink
''',
    );

    if (firstImage.isEmpty) {
      await Share.share(shareMessage);
      return;
    }

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
                Text(
                  appText(
                    context,
                    km: 'ចែករំលែកទំនិញ',
                    en: 'Share product',
                  ),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    fontFamily: 'Siemreap',
                  ),
                ),
                const SizedBox(height: 20),
                _buildOptionTile(
                  icon: Icons.link,
                  color: Colors.blue[700]!,
                  title: 'product_share_link'.tr,
                  subtitle: 'product_share_qr_link'.tr,
                  onTap: () {
                    Navigator.pop(context);
                    _shareProductWithWatermark();
                  },
                ),
                const SizedBox(height: 12),
                _buildOptionTile(
                  icon: Icons.download,
                  color: Colors.green,
                  title: 'product_save_watermark'.tr,
                  subtitle: 'product_save_gallery'.tr,
                  onTap: () {
                    Navigator.pop(context);
                    _processWatermarkAction(firstImage, isShare: false);
                  },
                ),
                const SizedBox(height: 15),
              ],
            ),
          ),
        ),
      ),
    );
  }

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

      final response = await Dio().get(
        images[0],
        options: Options(responseType: ResponseType.bytes),
      );

      final tempDir = await getTemporaryDirectory();
      final file = File(
        '${tempDir.path}/sesan_original_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await file.writeAsBytes(response.data);

      Get.back();

      await Share.shareXFiles([
        XFile(file.path),
      ], text: '${widget.product['product_name'] ?? 'Sesan Product'}');
    } catch (e) {
      Get.back();
      _showSnack('❌ កំហុស: $e', Colors.red);
    }
  }

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
        final oldCount = (productData['totalReviews'] as num?)?.toInt() ?? 0;

        double newAverage;
        int newCount;

        if (ratingSnapshot.exists) {
          final oldUserRating =
              (ratingSnapshot.data()?['rating'] as num?)?.toDouble() ?? 0.0;

          newCount = oldCount > 0 ? oldCount : 1;
          final oldTotalScore = oldAverage * newCount;
          newAverage = (oldTotalScore - oldUserRating + rating) / newCount;

          transaction.set(ratingRef, {
            'userId': uid,
            'rating': rating,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        } else {
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
      ], text: 'Sesan Store - ${'product_view_in_app'.tr}');
    } catch (e) {
      Get.back();
      _showSnack('❌ កំហុស: $e', Colors.red);
    }
  }

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

  Widget _buildWebGalleryExtras({
    required BuildContext context,
    required List<String> images,
    required bool hasVideo,
  }) {
    final sellerId = (widget.product['seller_id'] ?? '').toString();
    final sellerName =
        (widget.product['seller_name'] ?? 'Unknown seller').toString();
    final sellerPhoto = (widget.product['seller_photo'] ?? '').toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (images.length + (hasVideo ? 1 : 0) > 1) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 72,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              itemCount: images.length + (hasVideo ? 1 : 0),
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final selected = index == _currentPage;
                final isVideo = hasVideo && index == images.length;
                return InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => _webGalleryController.animateToPage(
                    index,
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                  ),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 72,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected ? Colors.blue : Colors.grey.shade300,
                        width: selected ? 2.5 : 1,
                      ),
                    ),
                    child: isVideo
                        ? const Icon(
                            Icons.play_circle_fill_rounded,
                            color: Colors.redAccent,
                            size: 34,
                          )
                        : CachedNetworkImage(
                            imageUrl: images[index],
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) =>
                                const Icon(Icons.broken_image_outlined),
                          ),
                  ),
                );
              },
            ),
          ),
        ],
        const SizedBox(height: 14),
        Card(
          elevation: 0,
          color: const Color(0xFFF4FAF1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: Colors.green.shade200),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: sellerId.isEmpty
                ? null
                : () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SellerProfileScreen(
                          sellerId: sellerId,
                          sellerName: sellerName,
                        ),
                      ),
                    ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 25,
                    backgroundColor: Colors.green.shade100,
                    backgroundImage:
                        sellerPhoto.isNotEmpty ? NetworkImage(sellerPhoto) : null,
                    child: sellerPhoto.isEmpty
                        ? const Icon(Icons.storefront, color: Colors.green)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          appText(
                            context,
                            km: 'ព័ត៌មានអ្នកលក់',
                            en: 'Seller information',
                          ),
                          style: TextStyle(
                            color: Colors.green.shade700,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          sellerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    appText(context, km: 'មើលហាង', en: 'View shop'),
                    style: const TextStyle(color: Colors.blue, fontSize: 12),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F9FC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE1E6ED)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.verified_user_outlined,
                    color: Colors.blue,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    appText(
                      context,
                      km: 'សុវត្ថិភាពអ្នកទិញ',
                      en: 'Buyer protection',
                    ),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                appText(
                  context,
                  km: '✓ ពិនិត្យព័ត៌មានអ្នកលក់មុនទិញ',
                  en: '✓ Check seller information before buying',
                ),
                style: const TextStyle(fontSize: 12.5),
              ),
              const SizedBox(height: 6),
              Text(
                appText(
                  context,
                  km: '✓ អាចដាក់បណ្ដឹងតាម Sesan',
                  en: '✓ Report an issue through Sesan',
                ),
                style: const TextStyle(fontSize: 12.5),
              ),
            ],
          ),
        ),
        if (widget.product['id'] != null &&
            widget.product['id'].toString().isNotEmpty) ...[
          const SizedBox(height: 14),
          Container(
            height: 420,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE1E6ED)),
            ),
            child: Scrollbar(
              controller: _webCommentsController,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _webCommentsController,
                padding: const EdgeInsets.only(bottom: 12),
                child: CommentSection(
                  productId: widget.product['id'],
                  sellerId: widget.product['seller_id'] ?? '',
                  currentUserId: _currentUserId,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bool tracksStock = widget.product['track_stock'] == true;
    final int stockQuantity = widget.product['stock_quantity'] is num
        ? (widget.product['stock_quantity'] as num).toInt()
        : int.tryParse(widget.product['stock_quantity']?.toString() ?? '') ?? 0;
    final rawStockUnit =
        widget.product['stock_unit']?.toString().trim() ?? '';
    final String stockUnit =
        rawStockUnit.toLowerCase() == 'item' ||
                rawStockUnit.toLowerCase() == 'items' ||
                rawStockUnit.toLowerCase() == 'item(s)'
            ? ''
            : rawStockUnit;
    final bool isOutOfStock = tracksStock && stockQuantity <= 0;
    final bool isAddToCartDisabled =
        widget.product['is_locked'] == true ||
        widget.product['shipping_included'] == false ||
        isOutOfStock;
    List<String> displayImages = [];
    if (widget.product['image_urls'] != null &&
        widget.product['image_urls'] is List) {
      displayImages = List<String>.from(widget.product['image_urls']);
    } else if (widget.product['image_url'] != null &&
        widget.product['image_url'] != "") {
      displayImages = [widget.product['image_url']];
    }

    final bool hasVideo =
        widget.product['video_url'] != null &&
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
          ),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Text(
          _shownProductName(l10n.productDetails),
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.blue,
        actions: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('bookmarks')
                .where('userId', isEqualTo: _currentUserId)
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
            onPressed: () => _showSaveOption(context),
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: SingleChildScrollView(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isDesktop = constraints.maxWidth >= 900;
                  final galleryWidth = isDesktop
                      ? 520.0
                      : constraints.maxWidth;
                  final detailsWidth = isDesktop
                      ? constraints.maxWidth - galleryWidth - 20
                      : constraints.maxWidth;

                  return Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.start,
                    spacing: 20,
                    runSpacing: 20,
                    children: [
                      SizedBox(
                        width: galleryWidth,
                        child: Column(
                          children: [
                            Stack(
                    children: [
                      AspectRatio(
                        aspectRatio: 1 / 1,
                        child: PageView.builder(
                          controller: _webGalleryController,
                          itemCount: totalSlides,
                          onPageChanged: (index) {
                            setState(() => _currentPage = index);
                            if (_videoController != null &&
                                _isVideoInitialized &&
                                _videoController!.value.isPlaying) {
                              if (index != imageCount) {
                                _videoController!.pause();
                                setState(() {});
                              }
                            }
                          },
                          itemBuilder: (context, index) {
                            if (hasVideo && index == imageCount) {
                              final isPlaying =
                                  _videoController?.value.isPlaying ?? false;
                              return GestureDetector(
                                onTap: _toggleVideoPlayback,
                                child: Container(
                                  color: Colors.black,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      if (_videoController != null &&
                                          _isVideoInitialized)
                                        AspectRatio(
                                          aspectRatio: _videoController!
                                              .value
                                              .aspectRatio,
                                          child: VideoPlayer(_videoController!),
                                        )
                                      else
                                        const Center(
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                          ),
                                        ),
                                      if (_isVideoInitialized)
                                        Positioned.fill(
                                          child: GestureDetector(
                                            behavior: HitTestBehavior.opaque,
                                            onTap: _toggleVideoPlayback,
                                            child: Center(
                                              child: AnimatedOpacity(
                                                duration: const Duration(
                                                  milliseconds: 250,
                                                ),
                                                opacity: isPlaying ? 0.0 : 1.0,
                                                child: Container(
                                                  width: 64,
                                                  height: 64,
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: Colors.black
                                                        .withOpacity(0.55),
                                                  ),
                                                  child: const Icon(
                                                    Icons.play_arrow_rounded,
                                                    color: Colors.white,
                                                    size: 48,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            }

                            return GestureDetector(
                              onLongPress: () => _showSaveOption(context),
                              onTap: () {
                                if (displayImages.isNotEmpty) {
                                  _openImageViewer(
                                    context,
                                    displayImages,
                                    index,
                                  );
                                }
                              },
                              child: CachedNetworkImage(
                                imageUrl: displayImages[index],
                                fit: BoxFit.cover,
                                maxWidthDiskCache: 1000,
                                placeholder: (context, url) =>
                                    Container(color: Colors.grey[200]),
                                errorWidget: (context, url, error) =>
                                    const Icon(
                                      Icons.broken_image,
                                      size: 50,
                                      color: Colors.grey,
                                    ),
                              ),
                            );
                          },
                        ),
                      ),
                      if (isDesktop && totalSlides > 1)
                        Positioned(
                          left: 14,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: Material(
                              color: Colors.black.withOpacity(0.48),
                              shape: const CircleBorder(),
                              child: IconButton(
                                tooltip: appText(
                                  context,
                                  km: 'រូបមុន',
                                  en: 'Previous',
                                ),
                                icon: const Icon(
                                  Icons.chevron_left_rounded,
                                  color: Colors.white,
                                  size: 34,
                                ),
                                onPressed: () {
                                  final previous =
                                      (_currentPage - 1 + totalSlides) %
                                          totalSlides;
                                  _webGalleryController.animateToPage(
                                    previous,
                                    duration:
                                        const Duration(milliseconds: 260),
                                    curve: Curves.easeOut,
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      if (isDesktop && totalSlides > 1)
                        Positioned(
                          right: 14,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: Material(
                              color: Colors.black.withOpacity(0.48),
                              shape: const CircleBorder(),
                              child: IconButton(
                                tooltip: appText(
                                  context,
                                  km: 'រូបបន្ទាប់',
                                  en: 'Next',
                                ),
                                icon: const Icon(
                                  Icons.chevron_right_rounded,
                                  color: Colors.white,
                                  size: 34,
                                ),
                                onPressed: () {
                                  final next =
                                      (_currentPage + 1) % totalSlides;
                                  _webGalleryController.animateToPage(
                                    next,
                                    duration:
                                        const Duration(milliseconds: 260),
                                    curve: Curves.easeOut,
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      if (totalSlides > 1)
                        Positioned(
                          bottom: 15,
                          right: 15,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              "${_currentPage + 1} / $totalSlides",
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
                            if (!isDesktop && totalSlides > 1)
                              SizedBox(
                                height: 62,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 7,
                                  ),
                                  itemCount: totalSlides,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(width: 7),
                                  itemBuilder: (context, index) {
                                    final selected = _currentPage == index;
                                    final isVideoThumbnail =
                                        hasVideo && index == imageCount;
                                    return InkWell(
                                      onTap: () {
                                        _webGalleryController.animateToPage(
                                          index,
                                          duration: const Duration(
                                            milliseconds: 250,
                                          ),
                                          curve: Curves.easeOut,
                                        );
                                      },
                                      borderRadius: BorderRadius.circular(8),
                                      child: AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 180),
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: isVideoThumbnail
                                              ? Colors.black
                                              : Colors.grey.shade100,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                            color: selected
                                                ? Colors.blue
                                                : Colors.grey.shade300,
                                            width: selected ? 2.5 : 1,
                                          ),
                                        ),
                                        clipBehavior: Clip.antiAlias,
                                        child: isVideoThumbnail
                                            ? const Icon(
                                                Icons.play_arrow_rounded,
                                                color: Colors.white,
                                                size: 28,
                                              )
                                            : CachedNetworkImage(
                                                imageUrl:
                                                    displayImages[index],
                                                fit: BoxFit.cover,
                                                memCacheWidth: 144,
                                                placeholder: (_, __) =>
                                                    Container(
                                                  color: Colors.grey.shade200,
                                                ),
                                                errorWidget: (_, __, ___) =>
                                                    const Icon(
                                                  Icons.broken_image_outlined,
                                                  color: Colors.grey,
                                                  size: 20,
                                                ),
                                              ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            if (isDesktop)
                              _buildWebGalleryExtras(
                                context: context,
                                images: displayImages,
                                hasVideo: hasVideo,
                              ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: detailsWidth,
                        child: Padding(
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
                        if (widget.product['shipping_included'] != null) ...[
                          const SizedBox(height: 4),
                          Container(
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
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  widget.product['shipping_included'] == true
                                      ? Icons.check_circle_outline
                                      : Icons.local_shipping_outlined,
                                  color:
                                      widget.product['shipping_included'] ==
                                          true
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
                          _shownProductName(l10n.unnamedProduct),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
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
                                localizedCategoryLabel(
                                  context,
                                  (widget.product['category'] ?? 'ផ្សេងៗ')
                                      .toString(),
                                ),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.green,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'Siemreap',
                                ),
                              ),
                            ),
                            if (widget.product['sub_category'] != null &&
                                widget.product['sub_category']
                                    .toString()
                                    .isNotEmpty &&
                                widget.product['sub_category'] !=
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
                                  color: Colors.orange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.orange.withOpacity(0.3),
                                  ),
                                ),
                                child: Text(
                                  localizedCategoryLabel(
                                    context,
                                    (widget.product['sub_category'] ?? '')
                                        .toString(),
                                  ),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.orange,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'Siemreap',
                                  ),
                                ),
                              ),
                            ],
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
                                  localizedCategoryLabel(
                                    context,
                                    (widget.product['sub_sub_category'] ?? '')
                                        .toString(),
                                  ),
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
                                        ? l10n.yourRating(
                                            myRating.toStringAsFixed(1),
                                          )
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
                              DocumentSnapshot<Map<String, dynamic>>
                            >(
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
                                  myRating =
                                      (ratingSnapshot.data!.data()?['rating']
                                              as num?)
                                          ?.toDouble() ??
                                      0.0;
                                }

                                return buildRating(myRating);
                              },
                            );
                          },
                        ),
                        const Divider(height: 30),
                        Text(
                          l10n.chooseQuantity,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
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
                                      width: 80,
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                      ),
                                      child: TextField(
                                        keyboardType: TextInputType.number,
                                        textAlign: TextAlign.center,
                                        inputFormatters: [
                                          LengthLimitingTextInputFormatter(3),
                                          FilteringTextInputFormatter
                                              .digitsOnly,
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
                                          counterText: "",
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
                                            final maxQty = tracksStock
                                                ? stockQuantity.clamp(1, 999).toInt()
                                                : 999;
                                            if (val > maxQty) {
                                              setState(() => _tempQty = maxQty);
                                            } else if (val > 0) {
                                              setState(() => _tempQty = val);
                                            }
                                          }
                                        },
                                      ),
                                    ),
                                    _qtyActionBtn(Icons.add, () {
                                      final maxQty = tracksStock
                                          ? stockQuantity.clamp(1, 999).toInt()
                                          : 999;
                                      if (_tempQty < maxQty) {
                                        setState(() => _tempQty++);
                                      }
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
                                if (tracksStock) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    isOutOfStock
                                        ? (Localizations.localeOf(context).languageCode == 'en'
                                            ? 'Out of stock'
                                            : 'អស់ពីស្តុក')
                                        : (Localizations.localeOf(context).languageCode == 'en'
                                            ? 'Available: $stockQuantity${stockUnit.isEmpty ? '' : ' $stockUnit'}'
                                            : 'នៅសល់៖ $stockQuantity${stockUnit.isEmpty ? '' : ' $stockUnit'}'),
                                    style: TextStyle(
                                      color: isOutOfStock ? Colors.red : Colors.green.shade700,
                                      fontWeight: FontWeight.w600,
                                      fontFamily: 'Siemreap',
                                    ),
                                  ),
                                ],
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
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          "${currencyFormat.format(totalPrice)} ${widget.product['currency'] ?? '៛'}",
                                          textAlign: TextAlign.right,
                                          style: const TextStyle(
                                            fontSize: 20,
                                            color: Colors.blue,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          overflow: TextOverflow.ellipsis,
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
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                l10n.descriptionLabel,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: _isTranslatingProduct
                                  ? null
                                  : _toggleProductTranslation,
                              icon: _isTranslatingProduct
                                  ? const SizedBox(
                                      width: 15,
                                      height: 15,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Icon(
                                      _showTranslatedProduct
                                          ? Icons.restore
                                          : Icons.translate,
                                      size: 18,
                                    ),
                              label: Text(
                                _showTranslatedProduct
                                    ? (Localizations.localeOf(context)
                                                .languageCode ==
                                            'en'
                                        ? 'Original'
                                        : 'អត្ថបទដើម')
                                    : (Localizations.localeOf(context)
                                                .languageCode ==
                                            'en'
                                        ? 'Translate'
                                        : 'បកប្រែ'),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontFamily: 'Siemreap',
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          _shownProductDescription(l10n.noDescription),
                          style: const TextStyle(
                            fontSize: 16,
                            fontFamily: 'Siemreap',
                          ),
                        ),
                        const SizedBox(height: 7),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _openProductAssistant,
                              borderRadius: BorderRadius.circular(18),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.purple.withOpacity(0.06),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: Colors.purple.withOpacity(0.22),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.auto_awesome,
                                      color: Colors.purple,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      Localizations.localeOf(context)
                                                  .languageCode ==
                                              'en'
                                          ? 'Ask Sesan AI'
                                          : 'សួរ Sesan AI',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.purple,
                                        fontFamily: 'Siemreap',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
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
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.storefront,
                                          color: Colors.green,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            l10n.sellerInformation,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.green.shade800,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  TextButton.icon(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              SellerProfileScreen(
                                                sellerId:
                                                    widget.product['seller_id'] ??
                                                    '',
                                                sellerName:
                                                    widget.product['seller_name'] ??
                                                    l10n.seller,
                                              ),
                                        ),
                                      );
                                    },
                                    icon: const Icon(
                                      Icons.arrow_forward,
                                      size: 14,
                                    ),
                                    label: Text(
                                      l10n.viewShop,
                                      maxLines: 1,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.blue,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 6,
                                      ),
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 20),
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
                                        (widget.product['seller_photo'] !=
                                                null &&
                                            widget.product['seller_photo'] !=
                                                '')
                                        ? NetworkImage(
                                            widget.product['seller_photo'],
                                          )
                                        : null,
                                    child:
                                        (widget.product['seller_photo'] ==
                                                null ||
                                            widget.product['seller_photo'] ==
                                                '')
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
                                          widget.product['seller_name'] ??
                                              l10n.unknownName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (widget.product['shop_tier'] != null &&
                                          (widget.product['shop_tier'] ==
                                                  'basic' ||
                                              widget.product['shop_tier'] ==
                                                  'premium'))
                                        Container(
                                          margin: const EdgeInsets.only(
                                            left: 8,
                                          ),
                                          padding: const EdgeInsets.all(2),
                                          decoration: BoxDecoration(
                                            color:
                                                widget.product['shop_tier'] ==
                                                    'premium'
                                                ? Colors.amber.withOpacity(0.8)
                                                : Colors.blueAccent.withOpacity(
                                                    0.8,
                                                  ),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            widget.product['shop_tier'] ==
                                                    'premium'
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
                                        ? l10n.postedAt(
                                            DateFormat(
                                              'dd-MM-yyyy HH:mm',
                                            ).format(
                                              (widget.product['updated_at']
                                                      as Timestamp)
                                                  .toDate(),
                                            ),
                                          )
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
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(
                                  Icons.phone,
                                  color: Colors.orange,
                                ),
                                title: Text(
                                  _maskSellerPhone(widget.product['phone1']).isEmpty
                                      ? l10n.noPhone
                                      : _maskSellerPhone(widget.product['phone1']),
                                ),
                                subtitle: Text(
                                  appText(
                                    context,
                                    km: 'សូមឆាត ឬទិញតាមកន្ត្រកក្នុង Sesan',
                                    en: 'Chat or order through the Sesan cart',
                                  ),
                                  style: const TextStyle(fontSize: 11, fontFamily: 'Siemreap'),
                                ),
                              ),
                              if (widget.product['phone2'] != null &&
                                  widget.product['phone2']
                                      .toString()
                                      .isNotEmpty)
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(
                                    Icons.phone_android,
                                    color: Colors.orange,
                                  ),
                                  title: Text(
                                    _maskSellerPhone(widget.product['phone2']),
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
                        if (!isDesktop) ...[
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
                          if (widget.product['id'] != null &&
                              widget.product['id'].toString().isNotEmpty)
                            CommentSection(
                              productId: widget.product['id'],
                              sellerId: widget.product['seller_id'] ?? '',
                              currentUserId: _currentUserId,
                            )
                          else
                            Center(child: Text(l10n.noProductData)),
                          const SizedBox(height: 30),
                        ],
                        RelatedProductsWidget(
                          category: widget.product['category'] ?? '',
                          currentProductId: widget.product['id'] ?? '',
                        ),
                        const SizedBox(height: 100),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            ),
          ),
        ),
      ),

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
                        final added = await _addToCart(widget.product);
                        if (added && context.mounted) {
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
      Get.snackbar(
        AppLocalizations.of(context).loginRequired,
        AppLocalizations.of(context).loginRequiredMessage,
      );
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
      ).showSnackBar(
        SnackBar(content: Text('product_removed_saved'.tr)),
      );
    } else {
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
      ).showSnackBar(
        SnackBar(content: Text('product_saved_success'.tr)),
      );
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

  Future<bool> _addToCart(Map<String, dynamic> product) async {
    final String finalImageUrl =
        product['image_url'] ??
        (product['image_urls'] != null &&
                (product['image_urls'] as List).isNotEmpty
            ? product['image_urls'][0]
            : "");
    final tracksStock = product['track_stock'] == true;
    final stock = product['stock_quantity'] is num
        ? (product['stock_quantity'] as num).toInt()
        : int.tryParse(product['stock_quantity']?.toString() ?? '') ?? 0;
    if (tracksStock && (stock <= 0 || _tempQty > stock)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(stock <= 0
              ? (Localizations.localeOf(context).languageCode == 'en' ? 'This product is out of stock.' : 'ទំនិញនេះអស់ពីស្តុកហើយ។')
              : (Localizations.localeOf(context).languageCode == 'en' ? 'Only $stock item(s) remain.' : 'ទំនិញនៅសល់តែ $stock ប៉ុណ្ណោះ។')),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      String? userId = prefs.getString('user_uid');
      if (userId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).loginRequiredMessage)),
        );
        return false;
      }

      await FirebaseFirestore.instance.collection('carts').add({
        'customer_id': userId,
        'product_id': widget.product['id'] ?? '',
        'product_name': widget.product['product_name'] ?? 'គ្មានឈ្មោះ',
        'price': widget.product['price'] ?? 0,
        'image_url': finalImageUrl,
        'quantity': _tempQty,
        'track_stock': tracksStock,
        if (tracksStock) 'stock_quantity': stock,
        if (tracksStock) 'stock_unit': product['stock_unit'] ?? 'item',
        'created_at': FieldValue.serverTimestamp(),
        'seller_id': widget.product['seller_id'] ?? 'UNKNOWN_ID',
        'seller_name': widget.product['seller_name'] ?? 'អាជីវករ សេសាន',
        'seller_phone': widget.product['seller_phone'] ?? '',
        'seller_photo': widget.product['seller_photo'] ?? '',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('product_added_cart_success'.tr),
            backgroundColor: Colors.green,
          ),
        );
      }
      return true;
    } catch (e) {
      debugPrint("Error: $e");
      return false;
    }
  }
}
