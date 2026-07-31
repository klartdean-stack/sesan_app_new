import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_navigation/src/extension_navigation.dart';
import 'package:intl/intl.dart';
import 'package:my_app/edit_shopscreen.dart';
import 'package:my_app/share_service.dart';
import 'package:my_app/shop_upgrade_screen.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'product_detail.dart';
import 'chat_screen.dart';
import 'package:fl_chart/fl_chart.dart';

class SellerProfileScreen extends StatefulWidget {
  final String sellerId;
  final String sellerName;

  const SellerProfileScreen({
    super.key,
    required this.sellerId,
    required this.sellerName,
  });

  @override
  State<SellerProfileScreen> createState() => _SellerProfileScreenState();
}

class _SellerProfileScreenState extends State<SellerProfileScreen> {
  String? _currentUserId;
  bool _isFollowing = false;
  bool _isLoadingFollow = false;
  String? _filterMainCategory; // ប្រភេទមេ
  String? _filterSubCategory; // ប្រភេទរង
  String? _filterSubSubCategory; // ប្រភេទរងបន្ត

  // ✅ Cache សម្រាប់ _getCurrentUid
  String? _cachedCurrentUid;
  bool _isCheckingFollow = false;
  final ScreenshotController _screenshotController = ScreenshotController();

  @override
  void initState() {
    super.initState();
    _loadUserId();
  }

  Future<void> _loadUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? uid = prefs.getString('user_uid');
      if (uid == null || uid.isEmpty) {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          uid = user.uid;
          await prefs.setString('user_uid', uid);
        }
      }
      if (mounted) {
        setState(() {
          _currentUserId = uid;
          _cachedCurrentUid = uid;
        });
        if (uid != null && uid.isNotEmpty) {
          _checkIfFollowing();
        }
        // ✅ កត់ត្រាអ្នកចូលមើលនៅទីនេះ (បន្ទាប់ពី uid មានសុវត្ថិភាព)
        _recordProfileView();
      }
    } catch (e) {
      debugPrint("Error loading UID: $e");
    }
  }

  String _formatJoinDateKhmer(DateTime date) {
    final khmerMonths = [
      'មករា',
      'កុម្ភៈ',
      'មីនា',
      'មេសា',
      'ឧសភា',
      'មិថុនា',
      'កក្កដា',
      'សីហា',
      'កញ្ញា',
      'តុលា',
      'វិច្ឆិកា',
      'ធ្នូ',
    ];
    final khmerNumbers = ['០', '១', '២', '៣', '៤', '៥', '៦', '៧', '៨', '៩'];

    String day = date.day
        .toString()
        .split('')
        .map((d) => khmerNumbers[int.parse(d)])
        .join('');
    String month = khmerMonths[date.month - 1];
    String year = date.year
        .toString()
        .split('')
        .map((y) => khmerNumbers[int.parse(y)])
        .join('');

    return '$day $month $year';
  }

  final Map<String, dynamic> _subCategories = {
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
  Future<void> _checkIfFollowing() async {
    if (_currentUserId == null || _isCheckingFollow) return;
    _isCheckingFollow = true;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.sellerId)
          .collection('followers')
          .doc(_currentUserId)
          .get();

      if (mounted) {
        setState(() {
          _isFollowing = doc.exists;
        });
      }
    } catch (e) {
      debugPrint("Error checking follow: $e");
    } finally {
      _isCheckingFollow = false;
    }
  }

  Future<void> _recordProfileView() async {
    if (_currentUserId == null || _currentUserId == widget.sellerId) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.sellerId)
          .collection('profile_visitors')
          .doc(_currentUserId)
          .set({
        'visited_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Record view error: $e");
    }
  }

  Future<String> _getSellerPhoneFromProducts(String sellerId) async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('products')
          .where('seller_id', isEqualTo: sellerId)
          .orderBy('created_at', descending: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        var productData =
        querySnapshot.docs.first.data() as Map<String, dynamic>;
        String phone1 = productData['phone1']?.toString() ?? '';
        if (phone1.isEmpty) {
          phone1 = productData['seller_phone']?.toString() ?? '';
        }
        return phone1;
      }
    } catch (e) {
      debugPrint("Error fetching seller phone from products: $e");
    }
    return '';
  }

  Future<void> _toggleFollow() async {
    if (_currentUserId == null || _isLoadingFollow) return;
    if (_currentUserId == widget.sellerId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('អ្នកមិនអាចតាមដានខ្លួនឯងបានទេ')),
      );
      return;
    }

    final bool previousState = _isFollowing;
    setState(() {
      _isLoadingFollow = true;
      _isFollowing = !_isFollowing;
    });

    try {
      final batch = FirebaseFirestore.instance.batch();
      final followerRef = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.sellerId)
          .collection('followers')
          .doc(_currentUserId);

      final followingRef = FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUserId!)
          .collection('following')
          .doc(widget.sellerId);

      final sellerRef = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.sellerId);

      if (previousState) {
        batch.delete(followerRef);
        batch.delete(followingRef);
        batch.update(sellerRef, {'followers_count': FieldValue.increment(-1)});
      } else {
        batch.set(followerRef, {
          'user_id': _currentUserId,
          'followed_at': FieldValue.serverTimestamp(),
        });
        batch.set(followingRef, {
          'seller_id': widget.sellerId,
          'followed_at': FieldValue.serverTimestamp(),
        });
        batch.update(sellerRef, {'followers_count': FieldValue.increment(1)});
      }

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isFollowing ? '✅ បានតាមដានហាងនេះ' : '❌ ឈប់តាមដាន'),
            backgroundColor: _isFollowing ? Colors.green : Colors.grey,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      debugPrint('Toggle Follow Error: $e');
      if (mounted) {
        setState(() => _isFollowing = previousState);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('❌ បរាជ័យ: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoadingFollow = false);
    }
  }

  String _formatTimeAgo(dynamic timestamp) {
    if (timestamp == null) return "មុននេះបន្តិច";
    DateTime date;
    if (timestamp is Timestamp) {
      date = timestamp.toDate();
    } else if (timestamp is DateTime) {
      date = timestamp;
    } else {
      return "មុននេះបន្តិច";
    }
    final Duration diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return "មុននេះបន្តិច";
    if (diff.inMinutes < 60) return "${diff.inMinutes} នាទីមុន";
    if (diff.inHours < 24) return "${diff.inHours} ម៉ោងមុន";
    if (diff.inDays < 7) return "${diff.inDays} ថ្ងៃមុន";
    return "${date.day}/${date.month}/${date.year}";
  }

  Future<void> _fastAddToCart(Map<String, dynamic> product) async {
    if (_currentUserId == null) return;
    final String finalImageUrl =
        product['image_url'] ??
            (product['image_urls'] != null &&
                (product['image_urls'] as List).isNotEmpty
                ? product['image_urls'][0]
                : "");

    try {
      DocumentSnapshot sellerDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.sellerId)
          .get();
      Map<String, dynamic>? sellerData = sellerDoc.exists
          ? sellerDoc.data() as Map<String, dynamic>?
          : null;

      await FirebaseFirestore.instance.collection('carts').add({
        'product_id': product['id'] ?? '',
        'product_name': product['product_name'] ?? 'គ្មានឈ្មោះ',
        'price': product['price'] ?? 0,
        'currency': product['currency'] ?? '៛',
        'image_url': finalImageUrl,
        'quantity': 1,
        'customer_id': _currentUserId,
        'created_at': FieldValue.serverTimestamp(),
        'seller_id': widget.sellerId,
        'seller_name': sellerData?['name'] ?? widget.sellerName,
        'seller_phone': sellerData?['phone'] ?? '',
        'seller_photo': sellerData?['photoUrl'] ?? '',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✅ បន្ថែមទៅកន្ត្រករួចរាល់!"),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      debugPrint("Add to Cart Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("❌ បរាជ័យ: $e")));
      }
    }
  }

  Future<String> _getCurrentUid() async {
    if (_cachedCurrentUid != null) {
      return _cachedCurrentUid!;
    }
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getString('user_uid') ?? '';
    if (mounted) {
      setState(() {
        _cachedCurrentUid = uid;
        _currentUserId = uid;
      });
    }
    return uid;
  }

  Future<void> _addToChat(Map<String, dynamic> product) async {
    if (_currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('សូមចូលប្រើប្រាស់មុននឹងបន្ថែមទៅឆាត'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    final String finalImageUrl =
        product['image_url'] ??
            (product['image_urls'] != null &&
                (product['image_urls'] as List).isNotEmpty
                ? product['image_urls'][0]
                : "");

    String roomId = _currentUserId!.compareTo(widget.sellerId) <= 0
        ? '${_currentUserId}_${widget.sellerId}'
        : '${widget.sellerId}_$_currentUserId';

    String customerName = 'អ្នកទិញ';
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUserId)
          .get();
      if (userDoc.exists) {
        customerName = userDoc.data()?['name'] ?? 'អ្នកទិញ';
      }
    } catch (_) {}

    try {
      await FirebaseFirestore.instance.collection('chat_items').add({
        'product_id': product['id'] ?? '',
        'product_name': product['product_name'] ?? 'គ្មានឈ្មោះ',
        'price': product['price'] ?? 0,
        'currency': product['currency'] ?? '៛',
        'image_url': finalImageUrl,
        'customer_id': _currentUserId,
        'customer_name': customerName,
        'seller_id': widget.sellerId,
        'chat_room_id': roomId,
        'created_at': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ បានបោះ "${product['product_name'] ?? 'ទំនិញ'}" ចូលឆាត!',
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      debugPrint("Add to Chat Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("❌ បរាជ័យ: $e")));
      }
    }
  }

  Future<void> _toggleAllProductsLock(bool shouldLock) async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      final products = await FirebaseFirestore.instance
          .collection('products')
          .where('seller_id', isEqualTo: widget.sellerId)
          .get();

      for (var doc in products.docs) {
        batch.update(doc.reference, {'is_locked': shouldLock});
      }
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              shouldLock
                  ? "🔒 បានចាក់សោរទំនិញទាំងអស់"
                  : "🔓 បានបើកសោរទំនិញទាំងអស់",
            ),
            backgroundColor: shouldLock ? Colors.orange : Colors.green,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      debugPrint("Master Lock Error: $e");
    }
  }

  Future<void> _toggleSingleProductLock(Map<String, dynamic> product) async {
    final bool currentLock = product['is_locked'] == true;
    final String productId = product['id'] ?? '';

    if (productId.isEmpty) return;

    try {
      await FirebaseFirestore.instance
          .collection('products')
          .doc(productId)
          .update({'is_locked': !currentLock});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              !currentLock ? '🔒 បានចាក់សោរទំនិញ' : '🔓 បានបើកសោរទំនិញ',
            ),
            backgroundColor: !currentLock ? Colors.orange : Colors.green,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      debugPrint("Toggle single product lock error: $e");
    }
  }

  Future<Map<String, List<int>>> _fetchMonthlyStats() async {
    final currentYear = DateTime.now().year;
    final startOfYear = DateTime(currentYear, 1, 1);
    final endOfYear = DateTime(currentYear + 1, 1, 1);
    final sellerId = widget.sellerId;

    Map<String, List<int>> result = {
      'visitors': List.filled(12, 0),
      'ratings': List.filled(12, 0),
      'followers': List.filled(12, 0),
      'products': List.filled(12, 0),
    };

    try {
      // 1. អ្នកចូលមើល (Visitors)
      final visitorsSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(sellerId)
          .collection('profile_visitors')
          .where(
        'visited_at',
        isGreaterThanOrEqualTo: Timestamp.fromDate(startOfYear),
      )
          .where('visited_at', isLessThan: Timestamp.fromDate(endOfYear))
          .get();
      for (var doc in visitorsSnap.docs) {
        final ts = doc.data()['visited_at'] as Timestamp?;
        if (ts != null) result['visitors']![ts.toDate().month - 1]++;
      }

      // 2. Rating ជាមធ្យម (គិតតែផលិតផលដែលមាន rating ក្នុងខែនោះ)
      // យើងប្រើ avgRating ដែលមានស្រាប់ ប៉ុន្តែដើម្បីឲ្យត្រឹមត្រូវតាមខែ យើងអាចទាញពី products
      // សម្រាប់ភាពសាមញ្ញ យើងនឹងប្រើ field ដែលមានស្រាប់ (អាចកែបានពេលក្រោយ)
      final productsSnap = await FirebaseFirestore.instance
          .collection('products')
          .where('seller_id', isEqualTo: sellerId)
          .where(
        'created_at',
        isGreaterThanOrEqualTo: Timestamp.fromDate(startOfYear),
      )
          .where('created_at', isLessThan: Timestamp.fromDate(endOfYear))
          .get();
      for (var doc in productsSnap.docs) {
        final data = doc.data();
        final ts = data['created_at'] as Timestamp?;
        if (ts != null) {
          final month = ts.toDate().month;
          // រាប់ចំនួនផលិតផលដែលមាន rating
          final avgRating = (data['avgRating'] ?? 0).toDouble();
          if (avgRating > 0) {
            // គ្រាន់តែបូក rating ចូល រួចយកមធ្យមនៅពេលបង្ហាញ
            result['ratings']![month - 1] += 1;
          }
        }
      }

      // 3. អ្នក Follow ថ្មី (Followers)
      final followersSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(sellerId)
          .collection('followers')
          .where(
        'followed_at',
        isGreaterThanOrEqualTo: Timestamp.fromDate(startOfYear),
      )
          .where('followed_at', isLessThan: Timestamp.fromDate(endOfYear))
          .get();
      for (var doc in followersSnap.docs) {
        final ts = doc.data()['followed_at'] as Timestamp?;
        if (ts != null) result['followers']![ts.toDate().month - 1]++;
      }

      // 4. ទំនិញផុសថ្មី (Products)
      for (var doc in productsSnap.docs) {
        final ts = doc.data()['created_at'] as Timestamp?;
        if (ts != null) result['products']![ts.toDate().month - 1]++;
      }
    } catch (e) {
      debugPrint("Error fetching monthly stats: $e");
    }

    return result;
  }

  Future<void> _shareShopWithWatermark() async {
    String coverUrl = '';
    String photoUrl = '';
    String shopName = widget.sellerName;
    String sesanId = '';
    String phone = '';
    int productCount = 0;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.sellerId)
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        coverUrl = data['coverUrl'] ?? '';
        photoUrl = data['photoUrl'] ?? '';
        shopName = data['name'] ?? widget.sellerName;
        sesanId = data['sesan_id']?.toString() ?? '';
        phone = data['phone'] ?? '';
      }

      final productsSnap = await FirebaseFirestore.instance
          .collection('products')
          .where('seller_id', isEqualTo: widget.sellerId)
          .get();
      productCount = productsSnap.docs.length;
    } catch (e) {
      debugPrint("❌ Error fetching shop data: $e");
    }

    final String shareMessage =
    '''
 🛍️ រកឃើញហាងល្អៗនៅក្នុង Sesan App!
 🏪 $shopName ${sesanId.isNotEmpty ? '🆔 Sesan ID: $sesanId\n' : ''}
 🔗 មើលហាងក្នុង App៖ https://sesanshop.com/shop/${widget.sellerId}
 📲 មិនទាន់មាន App? ទាញយកទីនេះ៖
 Android: https://play.google.com/store/apps/details?id=com.sesan.app
 iOS: https://apps.apple.com/app/sesan-app/idXXXXXXXXXX''';

    try {
      if (mounted) {
        Get.dialog(
          const Center(child: CircularProgressIndicator(color: Colors.white)),
          barrierDismissible: false,
        );
      }

      final image = await _screenshotController.captureFromWidget(
        _buildShopWatermarkWidget(
          coverUrl: coverUrl,
          photoUrl: photoUrl,
          shopName: shopName,
          sesanId: sesanId,
          sellerId: widget.sellerId,
          phone: phone,
          productCount: productCount,
        ),
        delay: const Duration(milliseconds: 1500),
        pixelRatio: 2.0,
      );

      final tempDir = await getTemporaryDirectory();
      final file = File(
        '${tempDir.path}/sesan_shop_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(image);

      if (mounted) Get.back();

      await Share.shareXFiles(
        [XFile(file.path)],
        text: shareMessage,
        subject: shopName,
      );
    } catch (e) {
      if (mounted) Get.back();
      debugPrint("❌ Shop Watermark Share Error: $e");
      await Share.share(shareMessage);
    }
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.75,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'តម្រៀបទំនិញ',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _filterMainCategory = null;
                            _filterSubCategory = null;
                            _filterSubSubCategory = null;
                          });
                          setSheetState(() {});
                          Navigator.pop(ctx);
                        },
                        child: const Text('លុបតម្រៀប'),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      const Text(
                        'ប្រភេទមេ',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: _subCategories.keys.map((cat) {
                          final selected = _filterMainCategory == cat;
                          return ChoiceChip(
                            label: Text(cat),
                            selected: selected,
                            selectedColor: Colors.green[100],
                            onSelected: (bool val) {
                              setSheetState(() {
                                _filterMainCategory = val ? cat : null;
                                _filterSubCategory = null;
                                _filterSubSubCategory = null;
                              });
                              setState(() {});
                            },
                          );
                        }).toList(),
                      ),
                      if (_filterMainCategory != null) ...[
                        const SizedBox(height: 20),
                        const Text(
                          'ប្រភេទរង',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        _buildSubCategorySelector(setSheetState),
                      ],
                      if (_filterSubCategory != null &&
                          _hasSubSubCategories()) ...[
                        const SizedBox(height: 20),
                        const Text(
                          'ប្រភេទរងបន្ត',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        _buildSubSubCategorySelector(setSheetState),
                      ],
                      const SizedBox(height: 40),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[700],
                          minimumSize: const Size(double.infinity, 50),
                        ),
                        child: const Text('អនុវត្ត'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showFollowersList() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(widget.sellerId)
            .collection('followers')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;
          if (docs.isEmpty)
            return const Center(child: Text('មិនមានអ្នកតាមដាន'));

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final followerData = docs[index].data() as Map<String, dynamic>;
              final String followerUserId = followerData['user_id'] ?? '';

              // ទាញព័ត៌មានអ្នកប្រើពី users collection
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(followerUserId)
                    .get(),
                builder: (context, userSnapshot) {
                  String name = followerUserId; // fallback
                  String photoUrl = '';
                  if (userSnapshot.hasData && userSnapshot.data!.exists) {
                    final userData =
                    userSnapshot.data!.data() as Map<String, dynamic>;
                    name = userData['name'] ?? followerUserId;
                    photoUrl = userData['photoUrl'] ?? '';
                  }
                  return ListTile(
                    leading: CircleAvatar(
                      radius: 22,
                      backgroundColor: Colors.green.shade100,
                      backgroundImage: photoUrl.isNotEmpty
                          ? NetworkImage(photoUrl)
                          : null,
                      child: photoUrl.isEmpty
                          ? Icon(Icons.person, color: Colors.green[700])
                          : null,
                    ),
                    title: Text(
                      name,
                      style: const TextStyle(
                        fontFamily: 'Siemreap',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      followerUserId,
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  void _editShopEvent(String currentText) {
    final controller = TextEditingController(text: currentText);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('កែប្រែប្រកាស'),
        content: TextField(controller: controller, maxLines: 3),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('បោះបង់'),
          ),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(_cachedCurrentUid)
                  .update({'shop_event_text': controller.text.trim()});
              Navigator.pop(ctx);
            },
            child: const Text('រក្សាទុក'),
          ),
        ],
      ),
    );
  }

  Stream<QuerySnapshot> _getFilteredStream() {
    var query = FirebaseFirestore.instance
        .collection('products')
        .where('seller_id', isEqualTo: widget.sellerId);

    if (_filterMainCategory != null) {
      query = query.where('category', isEqualTo: _filterMainCategory);
    }
    if (_filterSubCategory != null && _filterSubCategory != 'ទាំងអស់') {
      query = query.where('sub_category', isEqualTo: _filterSubCategory);
    }
    if (_filterSubSubCategory != null && _filterSubSubCategory != 'ទាំងអស់') {
      query = query.where('sub_sub_category', isEqualTo: _filterSubSubCategory);
    }
    return query.orderBy('created_at', descending: true).snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(context),
          SliverToBoxAdapter(child: _buildSellerInfoCard(context)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Colors.green[700],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'ទំនិញដាក់លក់',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                      Icons.filter_list_rounded,
                      color: (_filterMainCategory != null)
                          ? Colors.green[700]
                          : Colors.grey[600],
                    ),
                    onPressed: _showFilterSheet,
                  ),
                  const SizedBox(width: 4),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('products')
                        .where('seller_id', isEqualTo: widget.sellerId)
                        .snapshots(),
                    builder: (context, snapshot) {
                      int count = snapshot.hasData
                          ? snapshot.data!.docs.length
                          : 0;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$count ទំនិញ',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green[700],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          _buildProductsGrid(context),
        ],
      ),
    );
  }

  Widget _buildSubCategorySelector(StateSetter setSheetState) {
    final main = _filterMainCategory!;
    final subData = _subCategories[main];

    if (subData is List) {
      return Wrap(
        spacing: 8,
        children: (subData as List).map((sub) {
          final selected = _filterSubCategory == sub;
          return ChoiceChip(
            label: Text(sub),
            selected: selected,
            selectedColor: Colors.orange[100],
            onSelected: (val) {
              setSheetState(() {
                _filterSubCategory = val ? sub : null;
                _filterSubSubCategory = null;
              });
              setState(() {});
            },
          );
        }).toList(),
      );
    } else if (subData is Map) {
      return Wrap(
        spacing: 8,
        children: (subData as Map<String, dynamic>).keys.map((sub) {
          final selected = _filterSubCategory == sub;
          return ChoiceChip(
            label: Text(sub),
            selected: selected,
            selectedColor: Colors.orange[100],
            onSelected: (val) {
              setSheetState(() {
                _filterSubCategory = val ? sub : null;
                _filterSubSubCategory = null;
              });
              setState(() {});
            },
          );
        }).toList(),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildSubSubCategorySelector(StateSetter setSheetState) {
    final main = _filterMainCategory!;
    final subData = _subCategories[main];
    List<String> subSubList = [];

    if (subData is Map) {
      final dynamic subMap = subData[_filterSubCategory];
      if (subMap is List) {
        subSubList = List<String>.from(subMap);
      }
    }

    if (subSubList.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      children: subSubList.map((ssub) {
        final selected = _filterSubSubCategory == ssub;
        return ChoiceChip(
          label: Text(ssub),
          selected: selected,
          selectedColor: Colors.red[100],
          onSelected: (val) {
            setSheetState(() {
              _filterSubSubCategory = val ? ssub : null;
            });
            setState(() {});
          },
        );
      }).toList(),
    );
  }

  bool _hasSubSubCategories() {
    final main = _filterMainCategory!;
    final subData = _subCategories[main];
    if (subData is Map) {
      final dynamic subMap = subData[_filterSubCategory];
      return subMap is List && subMap.isNotEmpty;
    }
    return false;
  }

  Widget _buildShopWatermarkWidget({
    required String coverUrl,
    required String photoUrl,
    required String shopName,
    required String sesanId,
    required String sellerId,
    required String phone,
    required int productCount,
  }) {
    return Container(
      width: 500,
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                height: 140,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.green[100],
                  image: coverUrl.isNotEmpty
                      ? DecorationImage(
                    image: NetworkImage(coverUrl),
                    fit: BoxFit.cover,
                  )
                      : null,
                ),
                child: coverUrl.isEmpty
                    ? const Icon(Icons.store, size: 60, color: Colors.green)
                    : null,
              ),
              Positioned(
                bottom: -30,
                left: 16,
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    image: photoUrl.isNotEmpty
                        ? DecorationImage(
                      image: NetworkImage(photoUrl),
                      fit: BoxFit.cover,
                    )
                        : null,
                    color: Colors.grey[300],
                  ),
                  child: photoUrl.isEmpty
                      ? const Icon(Icons.person, size: 35, color: Colors.grey)
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  shopName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    fontFamily: 'Siemreap',
                  ),
                ),
                if (sesanId.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Sesan ID: $sesanId',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.blue[700],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (phone.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    '📞 $phone',
                    style: const TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  '$productCount ទំនិញ • កំពុងលក់',
                  style: const TextStyle(fontSize: 13, color: Colors.black54),
                ),
                const SizedBox(height: 4),
                Text(
                  '📅 ${DateFormat('dd/MM/yyyy').format(DateTime.now())}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                    fontFamily: 'Siemreap',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                QrImageView(data: 'shop_id_$sellerId', size: 80.0),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'ស្កេនដើម្បីមើលហាងនេះក្នុង Sesan App',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                      fontFamily: 'Siemreap',
                    ),
                  ),
                ),
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
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 240,
      pinned: true,
      floating: false,
      backgroundColor: Colors.green[700],
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.3),
          shape: BoxShape.circle,
        ),
        child: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      actions: [
        if (_cachedCurrentUid == widget.sellerId)
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('products')
                .where('seller_id', isEqualTo: widget.sellerId)
                .limit(1)
                .snapshots(),
            builder: (context, snapshot) {
              bool isLocked = false;
              if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                final data =
                snapshot.data!.docs.first.data() as Map<String, dynamic>;
                isLocked = data['is_locked'] == true;
              }
              return Container(
                margin: const EdgeInsets.only(right: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isLocked ? '🔒' : '🛒',
                      style: const TextStyle(fontSize: 12),
                    ),
                    Switch(
                      value: isLocked,
                      activeColor: Colors.orange,
                      activeTrackColor: Colors.orange.withOpacity(0.5),
                      inactiveThumbColor: Colors.green,
                      inactiveTrackColor: Colors.green.withOpacity(0.3),
                      onChanged: (val) => _toggleAllProductsLock(val),
                    ),
                  ],
                ),
              );
            },
          ),
        if (_cachedCurrentUid == widget.sellerId)
          IconButton(
            icon: const CircleAvatar(
              backgroundColor: Colors.black26,
              child: Icon(Icons.edit, color: Colors.white, size: 20),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const EditShopScreen()),
              );
            },
          ),
        IconButton(
          icon: const Icon(Icons.share, color: Colors.white),
          onPressed: () => _shareShopWithWatermark(),
        ),
      ],
      centerTitle: true,
      title: Text(
        widget.sellerName,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          fontFamily: 'Siemreap',
          shadows: [
            Shadow(color: Colors.black45, blurRadius: 6, offset: Offset(0, 2)),
          ],
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(widget.sellerId)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || !snapshot.data!.exists) {
              return _buildDefaultCover();
            }
            var userData = snapshot.data!.data() as Map<String, dynamic>?;
            String coverUrl = userData?['coverUrl'] ?? '';
            String photoUrl = userData?['photoUrl'] ?? '';

            return Stack(
              fit: StackFit.expand,
              children: [
                coverUrl.isNotEmpty
                    ? CachedNetworkImage(
                  imageUrl: coverUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => _buildShimmerCover(),
                  errorWidget: (context, url, error) =>
                      _buildDefaultCover(),
                )
                    : _buildDefaultCover(),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.4),
                        Colors.black.withOpacity(0.6),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 25,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Hero(
                      tag: 'seller_avatar_${widget.sellerId}',
                      child: Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: photoUrl.isNotEmpty
                              ? CachedNetworkImage(
                            imageUrl: photoUrl,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: Colors.grey[300],
                              child: const Icon(Icons.person, size: 45),
                            ),
                            errorWidget: (context, url, error) =>
                                Container(
                                  color: Colors.grey[300],
                                  child: const Icon(
                                    Icons.person,
                                    size: 45,
                                  ),
                                ),
                          )
                              : Container(
                            color: Colors.grey[300],
                            child: const Icon(Icons.person, size: 45),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSellerInfoCard(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.sellerId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists)
          return const SizedBox.shrink();
        var userData = snapshot.data!.data() as Map<String, dynamic>?;

        // ✅ ប្រកាស shopTier ត្រង់នេះ មុនពេលប្រើ
        final String? shopTier =
        userData?['shop_tier']; // null, 'basic', 'premium'

        String followers = (userData?['followers_count'] ?? 0).toString();
        String shopAddress = userData?['address'] ?? 'មិនទាន់មានទីតាំង';
        String joinDate = 'ថ្មីៗនេះ';
        if (userData?['createdAt'] != null) {
          dynamic createdAt = userData?['createdAt'];
          DateTime date;
          if (createdAt is Timestamp) {
            date = createdAt.toDate();
          } else if (createdAt is DateTime) {
            date = createdAt;
          } else if (createdAt is String) {
            date = DateTime.tryParse(createdAt) ?? DateTime.now();
          } else {
            date = DateTime.now();
          }
          joinDate = DateFormat('dd/MM/yyyy').format(date);
        }

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('products')
                        .where('seller_id', isEqualTo: widget.sellerId)
                        .snapshots(),
                    builder: (context, productSnapshot) {
                      String rating = '0.0';
                      if (productSnapshot.hasData &&
                          productSnapshot.data!.docs.isNotEmpty) {
                        double totalRating = 0;
                        int ratedProducts = 0;
                        for (var doc in productSnapshot.data!.docs) {
                          final data = doc.data() as Map<String, dynamic>;
                          final avg = (data['avgRating'] ?? 0).toDouble();
                          final reviews = (data['totalReviews'] ?? 0).toInt();
                          if (reviews > 0) {
                            totalRating += avg;
                            ratedProducts++;
                          }
                        }
                        if (ratedProducts > 0)
                          rating = (totalRating / ratedProducts)
                              .toStringAsFixed(1);
                      }
                      return _buildStatItem(Icons.star, rating, 'រង្វាស់');
                    },
                  ),
                  _buildDivider(),
                  // 👉 ប្តូរមកប្រើ GestureDetector ដើម្បីអាចចុចមើលអ្នក Follow (បើមានសិទ្ធិ)
                  GestureDetector(
                    onTap: (shopTier != null && shopTier != 'free')
                        ? () => _showFollowersList()
                        : null,
                    child: _buildStatItem(
                      Icons.people,
                      followers,
                      'អ្នកតាមដាន',
                    ),
                  ),
                  _buildDivider(),
                  _buildStatItem(Icons.access_time, joinDate, 'ថ្ងៃចូលរួម'),
                ],
              ),
              const SizedBox(height: 16),

              // ── ផ្លាក Blue / Gold + ចំនួនអ្នកចូលមើល ──
              if (shopTier != null && shopTier != 'free') ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: shopTier == 'premium'
                            ? Colors.amber
                            : Colors.blueAccent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            shopTier == 'premium'
                                ? Icons.diamond
                                : Icons.verified_user,
                            color: Colors.white,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            shopTier == 'premium'
                                ? 'Gold Verified'
                                : 'Blue Verified',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontFamily: 'Siemreap',
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    // ចំនួនអ្នកចូលមើល
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(widget.sellerId)
                          .collection('profile_visitors')
                          .snapshots(),
                      builder: (context, visitorSnapshot) {
                        int views = visitorSnapshot.hasData
                            ? visitorSnapshot.data!.docs.length
                            : 0;
                        return Row(
                          children: [
                            const Icon(
                              Icons.visibility,
                              size: 14,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$views',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ],
              // ── ក្រាប 4 ខ្សែសម្រាប់ម្ចាស់ហាង Gold Verified ──
              if (_cachedCurrentUid == widget.sellerId && shopTier == 'premium')
                FutureBuilder<Map<String, List<int>>>(
                  future: _fetchMonthlyStats(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData)
                      return const Center(child: CircularProgressIndicator());
                    final data = snapshot.data!;
                    final monthsKhmer = [
                      'មករា',
                      'កុម្ភៈ',
                      'មីនា',
                      'មេសា',
                      'ឧសភា',
                      'មិថុនា',
                      'កក្កដា',
                      'សីហា',
                      'កញ្ញា',
                      'តុលា',
                      'វិច្ឆិកា',
                      'ធ្នូ',
                    ];

                    // ពណ៌ និងស្លាកសម្រាប់ខ្សែនីមួយៗ
                    const lineConfig = {
                      'visitors': {
                        'color': Colors.blueAccent,
                        'label': 'អ្នកចូលមើល',
                      },
                      'ratings': {'color': Colors.amber, 'label': 'Rating'},
                      'followers': {
                        'color': Colors.green,
                        'label': 'អ្នក Follow',
                      },
                      'products': {
                        'color': Colors.purpleAccent,
                        'label': 'ទំនិញ',
                      },
                    };

                    // កំណត់តម្លៃអតិបរមា Y-axis ដើម្បីឲ្យក្រាបមើលទៅល្អ
                    double maxY = 0;
                    data.forEach((key, values) {
                      final maxVal = values
                          .reduce((a, b) => a > b ? a : b)
                          .toDouble();
                      if (maxVal > maxY) maxY = maxVal;
                    });
                    maxY = (maxY + 1)
                        .ceilToDouble(); // បូកបន្តិចកុំឲ្យជាប់កំពូល

                    List<LineChartBarData> lineBars = [];
                    data.forEach((key, values) {
                      final spots = List.generate(
                        12,
                            (i) => FlSpot(i.toDouble(), values[i].toDouble()),
                      );
                      lineBars.add(
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          color: lineConfig[key]!['color'] as Color,
                          barWidth: 3,
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, percent, bar, index) =>
                                FlDotCirclePainter(
                                  radius: 4,
                                  color: lineConfig[key]!['color'] as Color,
                                  strokeWidth: 2,
                                  strokeColor: Colors.white,
                                ),
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            color: (lineConfig[key]!['color'] as Color)
                                .withOpacity(0.1),
                          ),
                        ),
                      );
                    });

                    return Container(
                      margin: const EdgeInsets.only(top: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '📊 ស្ថិតិប្រចាំឆ្នាំ',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              fontFamily: 'Siemreap',
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 200,
                            child: LineChart(
                              LineChartData(
                                gridData: FlGridData(
                                  show: true,
                                  drawVerticalLine: false,
                                  getDrawingHorizontalLine: (value) => FlLine(
                                    color: Colors.grey.shade200,
                                    strokeWidth: 1,
                                  ),
                                ),
                                titlesData: FlTitlesData(
                                  leftTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 30,
                                      getTitlesWidget: (value, meta) {
                                        if (value == value.roundToDouble()) {
                                          return Text(
                                            '${value.toInt()}',
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: Colors.grey,
                                            ),
                                          );
                                        }
                                        return const Text('');
                                      },
                                    ),
                                  ),
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      getTitlesWidget: (value, meta) {
                                        final idx = value.toInt();
                                        if (idx >= 0 && idx < 12) {
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                              top: 8,
                                            ),
                                            child: Text(
                                              monthsKhmer[idx],
                                              style: const TextStyle(
                                                fontSize: 8,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          );
                                        }
                                        return const Text('');
                                      },
                                    ),
                                  ),
                                  topTitles: AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                  rightTitles: AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                ),
                                borderData: FlBorderData(show: false),
                                lineBarsData: lineBars,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          // រឿងព្រេង (Legend)
                          Wrap(
                            spacing: 16,
                            runSpacing: 6,
                            children: lineConfig.entries.map((entry) {
                              return Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: entry.value['color'] as Color,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    entry.value['label'] as String,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    );
                  },
                ),

              // បង្ហាញ Sesan ID (ដដែល)
              FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(widget.sellerId)
                    .get(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || !snapshot.data!.exists)
                    return const SizedBox.shrink();
                  var userData = snapshot.data!.data() as Map<String, dynamic>?;
                  String sesanId = userData?['sesan_id']?.toString() ?? '';
                  if (sesanId.isEmpty) return const SizedBox.shrink();
                  return Column(
                    children: [
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 16,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue[200]!),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.badge,
                              color: Colors.blue[700],
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Sesan ID: ',
                              style: TextStyle(
                                color: Colors.blue[700],
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              sesanId,
                              style: TextStyle(
                                color: Colors.blue[900],
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () {
                                Clipboard.setData(ClipboardData(text: sesanId));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      '✅ បានចម្លង Sesan ID: $sesanId',
                                    ),
                                    backgroundColor: Colors.blue,
                                    duration: const Duration(seconds: 1),
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.blue[100],
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(
                                  Icons.copy,
                                  color: Colors.blue[700],
                                  size: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  );
                },
              ),

              // បង្ហាញលេខទូរស័ព្ទ
              FutureBuilder<String>(
                future: _getSellerPhoneFromProducts(widget.sellerId),
                builder: (context, phoneSnapshot) {
                  String phone = phoneSnapshot.data ?? '';
                  if (phone.isEmpty) return const SizedBox.shrink();
                  return Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.phone,
                              color: Colors.green[700],
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              phone,
                              style: TextStyle(
                                color: Colors.green[700],
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  );
                },
              ),

              // ទីតាំង
              Padding(
                padding: const EdgeInsets.only(top: 2.0, bottom: 14.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.location_on,
                      color: Colors.redAccent,
                      size: 18,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      shopAddress,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700],
                        fontFamily: 'Siemreap',
                      ),
                    ),
                  ],
                ),
              ),

              // ── កន្លែងប្រកាស Event (សម្រាប់ Premium) ──
              if (shopTier == 'premium') ...[
                const SizedBox(height: 12),
                StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(widget.sellerId)
                      .snapshots(),
                  builder: (context, shopSnapshot) {
                    if (!shopSnapshot.hasData) return const SizedBox.shrink();
                    final shopData =
                    shopSnapshot.data!.data() as Map<String, dynamic>?;
                    final String eventText = shopData?['shop_event_text'] ?? '';
                    final bool isOwner = _cachedCurrentUid == widget.sellerId;
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.campaign,
                                color: Colors.amber.shade700,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'ប្រកាសពិសេស',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Siemreap',
                                  fontSize: 14,
                                ),
                              ),
                              const Spacer(),
                              if (isOwner)
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 16),
                                  onPressed: () => _editShopEvent(eventText),
                                ),
                            ],
                          ),
                          if (eventText.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                eventText,
                                style: const TextStyle(
                                  fontFamily: 'Siemreap',
                                  fontSize: 14,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ],

              // ប៊ូតុងឆាត និងតាមដាន
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatScreen(
                              seller_id: widget.sellerId,
                              receiver_id: widget.sellerId,
                              productName: 'ហាងរបស់ ${widget.sellerName}',
                              productId: 'general',
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.chat_bubble_outline),
                      label: const Text('ឆាតឥឡូវនេះ'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[700],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  if (_currentUserId != widget.sellerId) ...[
                    const SizedBox(width: 12),
                    _FollowButton(
                      sellerId: widget.sellerId,
                      currentUserId: _currentUserId,
                    ),
                  ],
                ],
              ),
              // ប៊ូតុងដំឡើងហាង (បើជាម្ចាស់)
              if (_cachedCurrentUid == widget.sellerId) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber[700],
                      foregroundColor: Colors.black87,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ShopUpgradeScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.verified_user, size: 11),
                    label: const Text(
                      'ដំឡើងឋានៈហាង',
                      style: TextStyle(
                        fontFamily: 'Siemreap',
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.green[700], size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(height: 40, width: 1, color: Colors.grey[200]);
  }

  Widget _buildProductsGrid(BuildContext context) {
    // ✅ បន្ថែម Debug
    print('📱 Screen width: ${MediaQuery.of(context).size.width}');
    print(
      '📱 CrossAxisCount: ${MediaQuery.of(context).size.width > 700 ? 4 : 2}',
    );

    return StreamBuilder<QuerySnapshot>(
      stream: _getFilteredStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SliverToBoxAdapter(child: _buildShimmerGrid());
        }
        if (snapshot.hasError) {
          debugPrint("Error loading products: ${snapshot.error}");
          return SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red[300], size: 64),
                    const SizedBox(height: 16),
                    Text(
                      'មិនអាចផ្ទុកទំនិញបាន',
                      style: TextStyle(color: Colors.red[300], fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () => setState(() {}),
                      child: const Text('ព្យាយាមម្តងទៀត'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      color: Colors.grey[300],
                      size: 80,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'មិនទាន់មានទំនិញលក់នៅឡើយ',
                      style: TextStyle(color: Colors.grey[400], fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        var products = snapshot.data!.docs;
        return SliverPadding(
          padding: const EdgeInsets.all(12),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: MediaQuery.of(context).size.width > 1200
                  ? 6
                  : MediaQuery.of(context).size.width > 900
                  ? 5
                  : MediaQuery.of(context).size.width > 700
                  ? 4
                  : MediaQuery.of(context).size.width > 500
                  ? 3
                  : 2,
              childAspectRatio: MediaQuery.of(context).size.width > 700
                  ? 0.80
                  : 0.65,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            delegate: SliverChildBuilderDelegate((context, index) {
              var data = products[index].data() as Map<String, dynamic>;
              data['id'] = products[index].id;
              String imageUrl = '';
              if (data['image_urls'] != null &&
                  (data['image_urls'] as List).isNotEmpty) {
                imageUrl = data['image_urls'][0];
              } else if (data['image_url'] != null) {
                imageUrl = data['image_url'];
              }

              String productName = data['product_name'] ?? 'គ្មានឈ្មោះ';
              final String location = (data['location'] ?? 'ភ្នំពេញ')
                  .toString();
              final dynamic timestamp = data['created_at'];
              final bool isLocked = data['is_locked'] ?? false;
              final bool? shippingIncluded = data['shipping_included'];
              final bool isCartDisabled =
                  isLocked || (shippingIncluded == false);
              String priceString = data['price']?.toString() ?? '0';
              double priceValue =
                  double.tryParse(priceString.replaceAll(',', '')) ?? 0.0;
              String formattedPrice = NumberFormat('#,###').format(priceValue);
              String currency = data['currency']?.toString() ?? '៛';
              bool isAvailable = data['is_available'] ?? true;

              return GestureDetector(
                onTap: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('last_product_id', products[index].id);
                  await prefs.setString('current_seller_id', widget.sellerId);
                  var productData =
                  products[index].data() as Map<String, dynamic>;
                  productData['id'] = products[index].id;
                  if (!context.mounted) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          ProductDetailScreen(product: productData),
                    ),
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(16),
                              ),
                              child: imageUrl.isNotEmpty
                                  ? CachedNetworkImage(
                                imageUrl: imageUrl,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                placeholder: (context, url) => Container(
                                  color: Colors.grey[100],
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                                errorWidget: (context, url, error) =>
                                    Container(
                                      color: Colors.grey[100],
                                      child: Icon(
                                        Icons.image_not_supported,
                                        color: Colors.grey[400],
                                        size: 40,
                                      ),
                                    ),
                              )
                                  : Container(
                                color: Colors.grey[100],
                                child: Icon(
                                  Icons.image_not_supported,
                                  color: Colors.grey[400],
                                  size: 40,
                                ),
                              ),
                            ),

                            // ✅ Play Icon (បង្ហាញបើមានវីដេអូ)
                            if (data['video_url'] != null &&
                                data['video_url'].toString().isNotEmpty)
                              Positioned(
                                bottom: 4,
                                right: 4,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  padding: const EdgeInsets.all(4),
                                  child: const Icon(
                                    Icons.play_arrow_rounded,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),

                            if (!isAvailable)
                              Positioned(
                                top: 8,
                                left: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'ដាច់ស្តុក',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            if (data['discount'] != null)
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.orange,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '-${data['discount']}%',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            // ✅ Switch Lock/Unlock តូចសម្រាប់ទំនិញនីមួយៗ
                            if (_cachedCurrentUid == widget.sellerId)
                              Positioned(
                                top: 2,
                                right: 2,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 2,
                                    vertical: 0,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.4),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Transform.scale(
                                    scale: 0.65, // ✅ តូចជាងមុន
                                    child: Switch(
                                      value: isLocked,
                                      activeColor: Colors.orange,
                                      activeTrackColor: Colors.orange
                                          .withOpacity(0.6),
                                      inactiveThumbColor: Colors.green,
                                      inactiveTrackColor: Colors.green
                                          .withOpacity(0.4),
                                      materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                      onChanged: (val) async {
                                        final String productId =
                                            products[index].id;

                                        await FirebaseFirestore.instance
                                            .collection('products')
                                            .doc(productId)
                                            .update({'is_locked': val});

                                        if (mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                val
                                                    ? '🔒 បានចាក់សោរ'
                                                    : '🔓 បានបើកសោរ',
                                              ),
                                              backgroundColor: val
                                                  ? Colors.orange
                                                  : Colors.green,
                                              duration: const Duration(
                                                seconds: 1,
                                              ),
                                            ),
                                          );
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  productName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                    height: 1.2,
                                    fontFamily: 'Siemreap',
                                  ),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Flexible(
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.access_time,
                                      size: 9,
                                      color: Colors.grey,
                                    ),
                                    const SizedBox(width: 2),
                                    Flexible(
                                      child: Text(
                                        _formatTimeAgo(timestamp),
                                        style: const TextStyle(
                                          fontSize: 8,
                                          color: Colors.grey,
                                          fontFamily: 'Siemreap',
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const Text(
                                      " • ",
                                      style: TextStyle(
                                        fontSize: 8,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        location,
                                        style: const TextStyle(
                                          fontSize: 8,
                                          color: Colors.grey,
                                          fontFamily: 'Siemreap',
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                                children: [
                                  Flexible(
                                    child: Text(
                                      '$formattedPrice $currency',
                                      style: TextStyle(
                                        color: Colors.red[700],
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: (_currentUserId == null)
                                        ? null
                                        : () => _addToChat(data),
                                    child: Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: BoxDecoration(
                                        color: (_currentUserId == null)
                                            ? Colors.grey[200]
                                            : Colors.orange[50],
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Icon(
                                        Icons.chat_bubble_outline,
                                        color: (_currentUserId == null)
                                            ? Colors.grey
                                            : Colors.orange,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: isCartDisabled
                                        ? null
                                        : () => _fastAddToCart(data),
                                    child: Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: BoxDecoration(
                                        color: isCartDisabled
                                            ? Colors.grey[200]
                                            : Colors.green[50],
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Icon(
                                        Icons.add_shopping_cart,
                                        color: isCartDisabled
                                            ? Colors.grey
                                            : Colors.green,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }, childCount: products.length),
          ),
        );
      },
    );
  }

  Widget _buildDefaultCover() {
    return Container(
      color: Colors.green[700],
      child: Center(
        child: Icon(
          Icons.store,
          size: 80,
          color: Colors.white.withOpacity(0.3),
        ),
      ),
    );
  }

  Widget _buildShimmerCover() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(color: Colors.white),
    );
  }

  Widget _buildShimmerGrid() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: MediaQuery.of(context).size.width > 700
              ? 4
              : 2, // ✅ បន្ថែម
          childAspectRatio: MediaQuery.of(context).size.width > 700
              ? 0.80
              : 0.65, // ✅ បន្ថែម
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: 4,
        itemBuilder: (context, index) {
          return Shimmer.fromColors(
            baseColor: Colors.grey[300]!,
            highlightColor: Colors.grey[100]!,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FollowButton extends StatefulWidget {
  final String sellerId;
  final String? currentUserId;

  const _FollowButton({required this.sellerId, required this.currentUserId});

  @override
  State<_FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends State<_FollowButton> {
  bool _isFollowing = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkIfFollowing();
  }

  Future<void> _checkIfFollowing() async {
    if (widget.currentUserId == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.sellerId)
          .collection('followers')
          .doc(widget.currentUserId)
          .get();

      if (mounted) {
        setState(() => _isFollowing = doc.exists);
      }
    } catch (e) {
      debugPrint("Error checking follow: $e");
    }
  }

  Future<void> _toggleFollow() async {
    if (widget.currentUserId == null || _isLoading) return;
    if (widget.currentUserId == widget.sellerId) return;

    final bool previousState = _isFollowing;
    setState(() {
      _isLoading = true;
      _isFollowing = !_isFollowing;
    });

    try {
      final batch = FirebaseFirestore.instance.batch();
      final followerRef = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.sellerId)
          .collection('followers')
          .doc(widget.currentUserId);

      final followingRef = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.currentUserId!)
          .collection('following')
          .doc(widget.sellerId);

      final sellerRef = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.sellerId);

      if (previousState) {
        batch.delete(followerRef);
        batch.delete(followingRef);
        batch.update(sellerRef, {'followers_count': FieldValue.increment(-1)});
      } else {
        batch.set(followerRef, {
          'user_id': widget.currentUserId,
          'followed_at': FieldValue.serverTimestamp(),
        });
        batch.set(followingRef, {
          'seller_id': widget.sellerId,
          'followed_at': FieldValue.serverTimestamp(),
        });
        batch.update(sellerRef, {'followers_count': FieldValue.increment(1)});
      }

      await batch.commit();
    } catch (e) {
      if (mounted) {
        setState(() => _isFollowing = previousState);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _isFollowing ? Colors.green[700] : Colors.green[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        onPressed: _isLoading ? null : _toggleFollow,
        icon: _isLoading
            ? const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        )
            : Icon(
          _isFollowing ? Icons.check : Icons.person_add,
          color: _isFollowing ? Colors.white : Colors.green[700],
        ),
        padding: const EdgeInsets.all(14),
      ),
    );
  }
}


