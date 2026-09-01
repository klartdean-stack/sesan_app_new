import 'dart:async';
import 'dart:io';
import 'package:app_links/app_links.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'category_localization.dart';
import 'package:gal/gal.dart';
import 'package:get/get.dart'
    show Get, Trans, ExtensionSnackbar, GetNavigation, ExtensionDialog, SnackPosition;
import 'package:intl/intl.dart';
import 'package:my_app/comment_section.dart';
import 'package:my_app/seller_profile_screen.dart';
import 'localized_text.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'related_products_widget.dart';
import 'chat_screen.dart';
import 'cart_screen.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:video_player/video_player.dart';
import 'l10n/app_localizations.dart';
import 'sesan_ai_assistant_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  final Map<String, dynamic> product;
  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _currentPage = 0;
  int _tempQty = 1;
  String? _currentUserId;
  double _myRating = 0.0;
  bool _isSubmittingRating = false;
  bool _showTranslatedProduct = false;
  bool _isTranslatingProduct = false;
  String? _translatedProductName;
  String? _translatedDescription;
  final PageController _galleryController = PageController();
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;

  @override
  void initState() {
    super.initState();
    _loadUid();
    _initVideo();
    _appLinks = AppLinks();
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      final segments = uri.pathSegments;
      if (segments.contains('product')) {
        final newProductId = segments.last;
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
    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      if (controller.value.duration > Duration.zero &&
          controller.value.position >= controller.value.duration) {
        await controller.seekTo(Duration.zero);
      }
      await controller.play();
    }
    if (mounted) setState(() {});
  }

  Future<void> _refreshProductData(String productId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('products')
          .doc(productId)
          .get();
      if (doc.exists && mounted) {
        final newData = <String, dynamic>{...?doc.data(), 'id': productId};
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => ProductDetailScreen(product: newData)),
        );
      }
    } catch (e) {
      debugPrint('Refresh product error: $e');
    }
  }

  @override
  void dispose() {
    _videoController?.pause();
    _videoController?.dispose();
    _linkSubscription?.cancel();
    _galleryController.dispose();
    super.dispose();
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
    if (images is List && images.isNotEmpty) return images.first.toString();
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
        ? '''I am considering buying this product on Sesan App.\nProduct ID: $productId\nProduct: $name\nDescription: $description\nPrice: $price $currency\nCategory: $category\nSeller/Shop: $seller\n\nPlease inspect the attached product image and the information above. Explain its likely uses, what I should verify with the seller, and important cautions before buying. Do not invent missing details.'''
        : '''ខ្ញុំកំពុងពិចារណាទិញទំនិញនេះនៅក្នុង Sesan App។\nProduct ID៖ $productId\nឈ្មោះទំនិញ៖ $name\nបរិយាយ៖ $description\nតម្លៃ៖ $price $currency\nប្រភេទ៖ $category\nអ្នកលក់/ហាង៖ $seller\n\nសូមពិនិត្យរូបទំនិញដែលបានភ្ជាប់ និងព័ត៌មានខាងលើ។ ជួយពន្យល់ការប្រើប្រាស់ ចំណុចដែលគួរសួរបញ្ជាក់ពីអ្នកលក់ និងអ្វីត្រូវប្រុងប្រយ័ត្នមុនទិញ។ កុំបង្កើតព័ត៌មានដែលមិនមាន។''';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SesanAiAssistantScreen(
          initialPrompt: prompt,
          initialRole: 'agriculture',
          initialImageUrl: _firstProductImage(),
        ),
      ),
    );
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
      setState(() => _currentUserId = uid);
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
      setState(() {
        _myRating = (ratingDoc.data()?['rating'] as num?)?.toDouble() ?? 0.0;
      });
    } catch (e) {
      debugPrint('Error loading UID/rating: $e');
    }
  }

  Future<void> _submitRating(double rating) async {
    final l10n = AppLocalizations.of(context);
    if (_isSubmittingRating) return;
    final uid = _currentUserId ?? FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      _showSnack(l10n.loginBeforeRating, Colors.orange);
      return;
    }
    final productId = widget.product['id']?.toString() ?? '';
    if (productId.isEmpty) return;

    setState(() => _isSubmittingRating = true);
    try {
      final firestore = FirebaseFirestore.instance;
      final productRef = firestore.collection('products').doc(productId);
      final ratingRef = productRef.collection('ratings').doc(uid);
      await firestore.runTransaction((transaction) async {
        final productSnapshot = await transaction.get(productRef);
        if (!productSnapshot.exists) return;
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
          newAverage =
              ((oldAverage * newCount) - oldUserRating + rating) / newCount;
        } else {
          newCount = oldCount + 1;
          newAverage = ((oldAverage * oldCount) + rating) / newCount;
        }
        transaction.set(ratingRef, {
          'userId': uid,
          'productId': productId,
          'rating': rating,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        transaction.update(productRef, {
          'avgRating': newAverage.clamp(0.0, 5.0).toDouble(),
          'totalReviews': newCount,
          'lastRatedAt': FieldValue.serverTimestamp(),
        });
      });
      if (mounted) {
        setState(() => _myRating = rating);
        _showSnack(l10n.ratingThanks, Colors.green);
      }
    } catch (e) {
      if (mounted) _showSnack(l10n.ratingFailed(e.toString()), Colors.red);
    } finally {
      if (mounted) setState(() => _isSubmittingRating = false);
    }
  }

  void _showSnack(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  void _showShareOptions() {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.link, color: Colors.blue),
              title: Text('product_share_link'.tr),
              subtitle: Text('product_share_qr_link'.tr),
              onTap: () async {
                Navigator.pop(sheetContext);
                final id = (widget.product['id'] ?? '').toString();
                await Share.share('https://sesanshop.com/product/$id');
              },
            ),
            ListTile(
              leading: const Icon(Icons.image_outlined, color: Colors.green),
              title: Text('product_save_gallery'.tr),
              onTap: () async {
                Navigator.pop(sheetContext);
                final imageUrl = _firstProductImage();
                if (imageUrl.isEmpty) return;
                try {
                  final response = await Dio().get(
                    imageUrl,
                    options: Options(responseType: ResponseType.bytes),
                  );
                  final temp = await getTemporaryDirectory();
                  final file = File(
                    '${temp.path}/sesan_${DateTime.now().millisecondsSinceEpoch}.jpg',
                  );
                  await file.writeAsBytes(response.data);
                  await Gal.putImage(file.path);
                  Get.snackbar(
                    'product_success_title'.tr,
                    'product_image_saved_gallery'.tr,
                    snackPosition: SnackPosition.TOP,
                  );
                } catch (e) {
                  Get.snackbar(
                    'product_error_title'.tr,
                    e.toString(),
                    snackPosition: SnackPosition.TOP,
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleSave(bool alreadySaved) async {
    final prefs = await SharedPreferences.getInstance();
    final savedUid = prefs.getString('user_uid');
    if (savedUid == null || savedUid.isEmpty) {
      Get.snackbar(
        AppLocalizations.of(context).loginRequired,
        AppLocalizations.of(context).loginRequiredMessage,
      );
      return;
    }
    final bookmarkRef = FirebaseFirestore.instance.collection('bookmarks');
    if (alreadySaved) {
      final docs = await bookmarkRef
          .where('userId', isEqualTo: savedUid)
          .where('productId', isEqualTo: widget.product['id'])
          .get();
      for (final doc in docs.docs) {
        await doc.reference.delete();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('product_removed_saved'.tr)),
        );
      }
    } else {
      await bookmarkRef.add({
        'userId': savedUid,
        'productId': widget.product['id'] ?? '',
        'product_name': widget.product['product_name'] ?? '',
        'price': widget.product['price'] ?? '0',
        'currency': widget.product['currency'] ?? '៛',
        'location': widget.product['location'] ?? '',
        'description': widget.product['description'] ?? '',
        'category': widget.product['category'] ?? '',
        'seller_id': widget.product['seller_id'] ?? '',
        'seller_name': widget.product['seller_name'] ?? '',
        'seller_photo': widget.product['seller_photo'] ?? '',
        'image_urls': widget.product['image_urls'] ?? [],
        'image_url': widget.product['image_url'] ?? '',
        'savedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('product_saved_success'.tr)),
        );
      }
    }
  }

  Widget _qtyButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.blue),
      ),
    );
  }

  Future<bool> _addToCart() async {
    final product = widget.product;
    final tracksStock = product['track_stock'] == true;
    final stock = product['stock_quantity'] is num
        ? (product['stock_quantity'] as num).toInt()
        : int.tryParse(product['stock_quantity']?.toString() ?? '') ?? 0;
    if (tracksStock && (stock <= 0 || _tempQty > stock)) return false;
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_uid');
    if (userId == null || userId.isEmpty) return false;
    await FirebaseFirestore.instance.collection('carts').add({
      'customer_id': userId,
      'product_id': product['id'] ?? '',
      'product_name': product['product_name'] ?? '',
      'price': product['price'] ?? 0,
      'image_url': _firstProductImage(),
      'quantity': _tempQty,
      'track_stock': tracksStock,
      if (tracksStock) 'stock_quantity': stock,
      if (tracksStock) 'stock_unit': product['stock_unit'] ?? 'item',
      'created_at': FieldValue.serverTimestamp(),
      'seller_id': product['seller_id'] ?? '',
      'seller_name': product['seller_name'] ?? '',
      'seller_phone': product['seller_phone'] ?? '',
      'seller_photo': product['seller_photo'] ?? '',
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('product_added_cart_success'.tr)),
      );
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tracksStock = widget.product['track_stock'] == true;
    final stockQuantity = widget.product['stock_quantity'] is num
        ? (widget.product['stock_quantity'] as num).toInt()
        : int.tryParse(widget.product['stock_quantity']?.toString() ?? '') ?? 0;
    final isOutOfStock = tracksStock && stockQuantity <= 0;
    final isDisabled = widget.product['is_locked'] == true ||
        widget.product['shipping_included'] == false ||
        isOutOfStock;

    final images = <String>[];
    if (widget.product['image_urls'] is List) {
      images.addAll(List<String>.from(widget.product['image_urls']));
    } else if ((widget.product['image_url'] ?? '').toString().isNotEmpty) {
      images.add(widget.product['image_url'].toString());
    }
    final hasVideo = (widget.product['video_url'] ?? '').toString().isNotEmpty;
    final imageCount = images.length;
    final totalSlides = imageCount + (hasVideo ? 1 : 0);
    final unitPrice = double.tryParse(
          (widget.product['price'] ?? '0').toString().replaceAll(',', ''),
        ) ??
        0;
    final totalPrice = unitPrice * _tempQty;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        title: Text(_shownProductName(l10n.productDetails)),
        actions: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('bookmarks')
                .where('userId', isEqualTo: _currentUserId)
                .where('productId', isEqualTo: widget.product['id'])
                .snapshots(),
            builder: (_, snapshot) {
              final saved = snapshot.hasData && snapshot.data!.docs.isNotEmpty;
              return IconButton(
                onPressed: () => _toggleSave(saved),
                icon: Icon(saved ? Icons.bookmark : Icons.bookmark_border),
              );
            },
          ),
          IconButton(onPressed: _showShareOptions, icon: const Icon(Icons.share)),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (totalSlides > 0)
              AspectRatio(
                aspectRatio: 1,
                child: PageView.builder(
                  controller: _galleryController,
                  itemCount: totalSlides,
                  onPageChanged: (index) {
                    setState(() => _currentPage = index);
                    if (index != imageCount &&
                        (_videoController?.value.isPlaying ?? false)) {
                      _videoController?.pause();
                    }
                  },
                  itemBuilder: (_, index) {
                    if (hasVideo && index == imageCount) {
                      return GestureDetector(
                        onTap: _toggleVideoPlayback,
                        child: Container(
                          color: Colors.black,
                          alignment: Alignment.center,
                          child: _isVideoInitialized && _videoController != null
                              ? Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    AspectRatio(
                                      aspectRatio: _videoController!.value.aspectRatio,
                                      child: VideoPlayer(_videoController!),
                                    ),
                                    if (!_videoController!.value.isPlaying)
                                      const Icon(
                                        Icons.play_circle_fill,
                                        color: Colors.white,
                                        size: 72,
                                      ),
                                  ],
                                )
                              : const CircularProgressIndicator(color: Colors.white),
                        ),
                      );
                    }
                    return CachedNetworkImage(
                      imageUrl: images[index],
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) =>
                          const Icon(Icons.broken_image, size: 48),
                    );
                  },
                ),
              ),
            if (totalSlides > 1)
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('${_currentPage + 1} / $totalSlides'),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${widget.product['price'] ?? '0'} ${widget.product['currency'] ?? '៛'}',
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _shownProductName(l10n.unnamedProduct),
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [
                      Chip(
                        label: Text(
                          localizedCategoryLabel(
                            context,
                            (widget.product['category'] ?? 'ផ្សេងៗ').toString(),
                          ),
                        ),
                      ),
                      if ((widget.product['sub_category'] ?? '')
                          .toString()
                          .isNotEmpty)
                        Chip(
                          label: Text(
                            localizedCategoryLabel(
                              context,
                              widget.product['sub_category'].toString(),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('products')
                        .doc(widget.product['id'])
                        .snapshots(),
                    builder: (_, snap) {
                      var avg =
                          (widget.product['avgRating'] as num?)?.toDouble() ?? 0.0;
                      var count =
                          (widget.product['totalReviews'] as num?)?.toInt() ?? 0;
                      if (snap.hasData && snap.data!.exists) {
                        avg = (snap.data!.data()?['avgRating'] as num?)?.toDouble() ?? 0.0;
                        count = (snap.data!.data()?['totalReviews'] as num?)?.toInt() ?? 0;
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              RatingBarIndicator(
                                rating: avg,
                                itemBuilder: (_, __) =>
                                    const Icon(Icons.star, color: Colors.amber),
                                itemCount: 5,
                                itemSize: 22,
                              ),
                              const SizedBox(width: 8),
                              Text('${avg.toStringAsFixed(1)} ${l10n.reviewCount(count)}'),
                            ],
                          ),
                          RatingBar.builder(
                            initialRating: _myRating,
                            minRating: 1,
                            allowHalfRating: true,
                            itemCount: 5,
                            itemSize: 28,
                            itemBuilder: (_, __) =>
                                const Icon(Icons.star, color: Colors.amber),
                            onRatingUpdate:
                                _isSubmittingRating ? (_) {} : _submitRating,
                          ),
                        ],
                      );
                    },
                  ),
                  const Divider(height: 28),
                  Text(
                    l10n.chooseQuantity,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _qtyButton(Icons.remove, () {
                        if (_tempQty > 1) setState(() => _tempQty--);
                      }),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Text(
                          '$_tempQty',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                      _qtyButton(Icons.add, () {
                        final maxQty = tracksStock
                            ? stockQuantity.clamp(1, 999).toInt()
                            : 999;
                        if (_tempQty < maxQty) setState(() => _tempQty++);
                      }),
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
                              ? 'Available: $stockQuantity'
                              : 'នៅសល់៖ $stockQuantity'),
                      style: TextStyle(
                        color: isOutOfStock ? Colors.red : Colors.green.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(l10n.totalPrice),
                      const Spacer(),
                      Text(
                        '${NumberFormat('#,###').format(totalPrice)} ${widget.product['currency'] ?? '៛'}',
                        style: const TextStyle(
                          color: Colors.blue,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 30),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.descriptionLabel,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Icon(
                                _showTranslatedProduct
                                    ? Icons.restore
                                    : Icons.translate,
                              ),
                        label: Text(
                          _showTranslatedProduct
                              ? (Localizations.localeOf(context).languageCode == 'en'
                                  ? 'Original'
                                  : 'អត្ថបទដើម')
                              : (Localizations.localeOf(context).languageCode == 'en'
                                  ? 'Translate'
                                  : 'បកប្រែ'),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    _shownProductDescription(l10n.noDescription),
                    style: const TextStyle(fontSize: 16, fontFamily: 'Siemreap'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _openProductAssistant,
                    icon: const Icon(Icons.auto_awesome, color: Colors.purple),
                    label: Text(
                      Localizations.localeOf(context).languageCode == 'en'
                          ? 'Ask Sesan AI'
                          : 'សួរ Sesan AI',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundImage: (widget.product['seller_photo'] ?? '')
                                .toString()
                                .isNotEmpty
                            ? NetworkImage(widget.product['seller_photo'])
                            : null,
                        child: (widget.product['seller_photo'] ?? '')
                                .toString()
                                .isEmpty
                            ? const Icon(Icons.person)
                            : null,
                      ),
                      title: Text(
                        widget.product['seller_name'] ?? l10n.unknownName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(l10n.sellerInformation),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SellerProfileScreen(
                            sellerId: widget.product['seller_id'] ?? '',
                            sellerName:
                                widget.product['seller_name'] ?? l10n.seller,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if ((widget.product['id'] ?? '').toString().isNotEmpty)
                    CommentSection(
                      productId: widget.product['id'],
                      sellerId: widget.product['seller_id'] ?? '',
                      currentUserId: _currentUserId,
                    ),
                  const SizedBox(height: 24),
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
      bottomNavigationBar: SafeArea(
        child: Container(
          height: 70,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(
                      productId: widget.product['id'] ?? '',
                      productName: widget.product['product_name'] ?? '',
                      seller_id: widget.product['seller_id'] ?? '',
                      receiver_id: '',
                    ),
                  ),
                ),
                icon: const Icon(Icons.chat, color: Colors.orange),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: isDisabled ? null : _addToCart,
                  child: Text(l10n.addToCart),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: isDisabled
                      ? null
                      : () async {
                          final added = await _addToCart();
                          if (added && context.mounted) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const CartScreen()),
                            );
                          }
                        },
                  child: Text(l10n.buyNow),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
