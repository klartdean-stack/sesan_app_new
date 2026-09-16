import 'dart:io';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'category_localization.dart';
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
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'localized_text.dart';

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
  String? _filterMainCategory;
  String? _filterSubCategory;
  String? _filterSubSubCategory;
  String? _cachedCurrentUid;
  bool _isCheckingFollow = false;
  final ValueNotifier<bool> _showSellerPhoneNotifier = ValueNotifier<bool>(false);
  Timer? _phoneHideTimer;
  late final Future<String> _sellerPhoneFuture;
  StreamSubscription<QuerySnapshot>? _cartSubscription;
  final Set<String> _cartProductIds = <String>{};
  final Set<String> _cartBusyIds = <String>{};
  final ValueNotifier<int> _cartRevision = ValueNotifier<int>(0);
  final ScreenshotController _screenshotController = ScreenshotController();

  void _notifyCartChanged() {
    _cartRevision.value++;
  }

  String _maskSellerPhone(String phone) {
    final value = phone.trim().replaceAll(RegExp(r'\s+'), '');
    if (value.isEmpty) return '';
    if (value.length <= 3) return 'XXX';
    return '${value.substring(0, value.length - 3)}XXX';
  }

  @override
  void initState() {
    super.initState();
    _sellerPhoneFuture = _getSellerPhoneFromProducts(widget.sellerId);
    _loadUserId();
  }

  @override
  void dispose() {
    _phoneHideTimer?.cancel();
    _cartSubscription?.cancel();
    _cartRevision.dispose();
    _showSellerPhoneNotifier.dispose();
    super.dispose();
  }

  Future<void> _recordMarketplaceEvent(String type) async {
    try {
      final buyerId = _currentUserId ?? FirebaseAuth.instance.currentUser?.uid ?? '';
      await FirebaseFirestore.instance.collection('marketplace_events').add({
        'type': type,
        'buyerId': buyerId,
        'sellerId': widget.sellerId,
        'productId': '',
        'source': 'seller_shop',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Marketplace analytics error: $e');
    }
  }

  void _revealSellerPhoneTemporarily() {
    _phoneHideTimer?.cancel();
    _showSellerPhoneNotifier.value = true;
    _recordMarketplaceEvent('phone_reveal');
    _phoneHideTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) _showSellerPhoneNotifier.value = false;
    });
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
          _listenToCart();
        }
        _recordProfileView();
      }
    } catch (e) {
      debugPrint('Error loading UID: $e');
    }
  }

  String _formatJoinDateKhmer(DateTime date) {
    final khmerMonths = ['មករា', 'កុម្ភៈ', 'មីនា', 'មេសា', 'ឧសភា', 'មិថុនា', 'កក្កដា', 'សីហា', 'កញ្ញា', 'តុលា', 'វិច្ឆិកា', 'ធ្នូ'];
    final khmerNumbers = ['០', '១', '២', '៣', '៤', '៥', '៦', '៧', '៨', '៩'];
    String day = date.day.toString().split('').map((d) => khmerNumbers[int.parse(d)]).join('');
    String month = khmerMonths[date.month - 1];
    String year = date.year.toString().split('').map((y) => khmerNumbers[int.parse(y)]).join('');
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
    'ពូជសត្វចិញ្ចឹម': ['ទាំងអស់', 'គោ', 'ក្របី', 'ជ្រូក', 'ចៀម', 'ពពែ', 'មាន់', 'ទា', 'ក្ងាន', 'ក្រួច', 'អណ្ដើក/កន្ឋាយ', 'ត្រី', 'កង្កែប', 'ពស់', 'ជន្លេន', 'ផ្សេងៗ'],
    'ជីនិងថ្នាំ': ['ទាំងអស់', 'ជី', 'ថ្នាំ', 'វីតាមីន', 'ចំណីសត្វ', 'ផ្សេងៗ'],
    'បន្លែផ្លែឈើ': ['ទាំងអស់', 'បន្លែ', 'ផ្លែឈើ', 'គ្រឿងទេស', 'អាហារផ្អាប់', 'ស៊ុត', 'ផ្សេងៗ'],
    'ត្រីសាច់': ['ទាំងអស់', 'ត្រី', 'សាច់', 'កង្កែប', 'អណ្ដើក', 'ពស់', 'ក្ដាម', 'ផ្សេងៗ'],
    'សេវាកម្ម': ['ទាំងអស់', 'សេវាកម្មសត្វ', 'ដំណាំ', 'ម៉ាស៊ីន', 'គ្រឿងចក្រ', 'ទឹក/ភ្លើង', 'ហិរញ្ញវត្ថុ', 'ច្បាប់', 'ផ្សេងៗ'],
    'ផ្សេងៗ': ['ទាំងអស់', 'ដីកសិកម្ម', 'កសិដ្ឋាន', 'តំណាងចែកចាយ/ហ្វ្រែនឆាយ', 'ផលិតផលឌីជីថល', 'សៀវភៅកសិកម្ម', 'ផ្សេងៗ'],
  };

  Future<void> _checkIfFollowing() async {
    if (_currentUserId == null || _isCheckingFollow) return;
    _isCheckingFollow = true;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(widget.sellerId).collection('followers').doc(_currentUserId).get();
      if (mounted) setState(() => _isFollowing = doc.exists);
    } catch (e) {
      debugPrint('Error checking follow: $e');
    } finally {
      _isCheckingFollow = false;
    }
  }

  Future<void> _recordProfileView() async {
    if (_currentUserId == null || _currentUserId == widget.sellerId) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(widget.sellerId).collection('profile_visitors').doc(_currentUserId).set({'visited_at': FieldValue.serverTimestamp()}, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Record view error: $e');
    }
  }

  Future<String> _getSellerPhoneFromProducts(String sellerId) async {
    try {
      final querySnapshot = await FirebaseFirestore.instance.collection('products').where('seller_id', isEqualTo: sellerId).orderBy('created_at', descending: true).limit(1).get();
      if (querySnapshot.docs.isNotEmpty) {
        final productData = querySnapshot.docs.first.data();
        String phone1 = productData['phone1']?.toString() ?? '';
        if (phone1.isEmpty) phone1 = productData['seller_phone']?.toString() ?? '';
        return phone1;
      }
    } catch (e) {
      debugPrint('Error fetching seller phone from products: $e');
    }
    return '';
  }

  Future<void> _toggleFollow() async {
    if (_currentUserId == null || _isLoadingFollow) return;
    if (_currentUserId == widget.sellerId) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(appText(context, km: 'អ្នកមិនអាចតាមដានខ្លួនឯងបានទេ', en: 'You cannot follow yourself.'))));
      return;
    }
    final previousState = _isFollowing;
    setState(() {
      _isLoadingFollow = true;
      _isFollowing = !_isFollowing;
    });
    try {
      final batch = FirebaseFirestore.instance.batch();
      final followerRef = FirebaseFirestore.instance.collection('users').doc(widget.sellerId).collection('followers').doc(_currentUserId);
      final followingRef = FirebaseFirestore.instance.collection('users').doc(_currentUserId!).collection('following').doc(widget.sellerId);
      final sellerRef = FirebaseFirestore.instance.collection('users').doc(widget.sellerId);
      if (previousState) {
        batch.delete(followerRef);
        batch.delete(followingRef);
        batch.update(sellerRef, {'followers_count': FieldValue.increment(-1)});
      } else {
        batch.set(followerRef, {'user_id': _currentUserId, 'followed_at': FieldValue.serverTimestamp()});
        batch.set(followingRef, {'seller_id': widget.sellerId, 'followed_at': FieldValue.serverTimestamp()});
        batch.update(sellerRef, {'followers_count': FieldValue.increment(1)});
      }
      await batch.commit();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_isFollowing ? appText(context, km: '✅ បានតាមដានហាងនេះ', en: '✅ Shop followed.') : appText(context, km: '❌ ឈប់តាមដាន', en: 'Shop unfollowed.')), backgroundColor: _isFollowing ? Colors.green : Colors.grey, duration: const Duration(seconds: 1)));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isFollowing = previousState);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${appText(context, km: '❌ បរាជ័យ', en: '❌ Failed')}: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoadingFollow = false);
    }
  }

  void _listenToCart() {
    _cartSubscription?.cancel();
    final uid = _currentUserId;
    if (uid == null || uid.isEmpty) return;
    _cartSubscription = FirebaseFirestore.instance.collection('carts').where('customer_id', isEqualTo: uid).snapshots().listen((snapshot) {
      final ids = snapshot.docs.map((doc) => (doc.data()['product_id'] ?? '').toString()).where((id) => id.isNotEmpty).toSet();
      if (!mounted) return;
      _cartProductIds..clear()..addAll(ids);
      _cartBusyIds.removeWhere((id) => !ids.contains(id));
      _notifyCartChanged();
    }, onError: (error) => debugPrint('Seller cart listener error: $error'));
  }

  Future<void> _removeSellerProductFromCart(String productId) async {
    final uid = _currentUserId;
    if (uid == null || uid.isEmpty || productId.isEmpty || _cartBusyIds.contains(productId)) return;
    _cartBusyIds.add(productId);
    _notifyCartChanged();
    try {
      final snapshot = await FirebaseFirestore.instance.collection('carts').where('customer_id', isEqualTo: uid).get();
      final batch = FirebaseFirestore.instance.batch();
      var found = false;
      for (final doc in snapshot.docs) {
        if ((doc.data()['product_id'] ?? '').toString() == productId) {
          batch.delete(doc.reference);
          found = true;
        }
      }
      if (found) await batch.commit();
      if (mounted) {
        _cartProductIds.remove(productId);
        _cartBusyIds.remove(productId);
        _notifyCartChanged();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(appText(context, km: '↩️ បានដកចេញពីកន្ត្រក', en: '↩️ Removed from cart')), duration: const Duration(seconds: 1)));
      }
    } catch (e) {
      if (mounted) {
        _cartBusyIds.remove(productId);
        _notifyCartChanged();
      }
      debugPrint('Seller remove cart error: $e');
    }
  }

  String _formatTimeAgo(dynamic timestamp) {
    if (timestamp == null) return appText(context, km: 'មុននេះបន្តិច', en: 'Just now');
    DateTime date;
    if (timestamp is Timestamp) {
      date = timestamp.toDate();
    } else if (timestamp is DateTime) {
      date = timestamp;
    } else {
      return appText(context, km: 'មុននេះបន្តិច', en: 'Just now');
    }
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return appText(context, km: 'មុននេះបន្តិច', en: 'Just now');
    if (diff.inMinutes < 60) return appText(context, km: '${diff.inMinutes} នាទីមុន', en: '${diff.inMinutes} minutes ago');
    if (diff.inHours < 24) return appText(context, km: '${diff.inHours} ម៉ោងមុន', en: '${diff.inHours} hours ago');
    if (diff.inDays < 7) return appText(context, km: '${diff.inDays} ថ្ងៃមុន', en: '${diff.inDays} days ago');
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _fastAddToCart(Map<String, dynamic> product) async {
    if (_currentUserId == null) return;
    final productId = (product['id'] ?? '').toString();
    if (productId.isEmpty || _cartProductIds.contains(productId) || _cartBusyIds.contains(productId)) return;
    _cartBusyIds.add(productId);
    _notifyCartChanged();
    final finalImageUrl = product['image_url'] ?? ((product['image_urls'] is List && (product['image_urls'] as List).isNotEmpty) ? product['image_urls'][0] : '');
    try {
      final existing = await FirebaseFirestore.instance.collection('carts').where('customer_id', isEqualTo: _currentUserId).get();
      if (existing.docs.any((doc) => (doc.data()['product_id'] ?? '').toString() == productId)) {
        if (mounted) {
          _cartProductIds.add(productId);
          _cartBusyIds.remove(productId);
          _notifyCartChanged();
        }
        return;
      }
      final sellerDoc = await FirebaseFirestore.instance.collection('users').doc(widget.sellerId).get();
      final sellerData = sellerDoc.exists ? sellerDoc.data() : null;
      await FirebaseFirestore.instance.collection('carts').add({
        'product_id': productId,
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
        _cartProductIds.add(productId);
        _cartBusyIds.remove(productId);
        _notifyCartChanged();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(appText(context, km: '✅ បន្ថែមទៅកន្ត្រករួចរាល់!', en: '✅ Added to cart.')), backgroundColor: Colors.green, duration: const Duration(seconds: 1)));
      }
    } catch (e) {
      if (mounted) {
        _cartBusyIds.remove(productId);
        _notifyCartChanged();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${appText(context, km: '❌ បរាជ័យ', en: '❌ Failed')}: $e')));
      }
      debugPrint('Add to Cart Error: $e');
    }
  }

  Future<String> _getCurrentUid() async {
    if (_cachedCurrentUid != null) return _cachedCurrentUid!;
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(appText(context, km: 'សូមចូលប្រើប្រាស់មុននឹងបន្ថែមទៅឆាត', en: 'Please sign in before adding this to chat.')), backgroundColor: Colors.red));
      return;
    }
    final finalImageUrl = product['image_url'] ?? ((product['image_urls'] is List && (product['image_urls'] as List).isNotEmpty) ? product['image_urls'][0] : '');
    final roomId = _currentUserId!.compareTo(widget.sellerId) <= 0 ? '${_currentUserId}_${widget.sellerId}' : '${widget.sellerId}_$_currentUserId';
    String customerName = appText(context, km: 'អ្នកទិញ', en: 'Buyer');
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(_currentUserId).get();
      if (userDoc.exists) customerName = userDoc.data()?['name'] ?? appText(context, km: 'អ្នកទិញ', en: 'Buyer');
    } catch (_) {}
    try {
      await FirebaseFirestore.instance.collection('chat_items').add({
        'product_id': product['id'] ?? '',
        'product_name': product['product_name'] ?? appText(context, km: 'គ្មានឈ្មោះ', en: 'Unnamed product'),
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(appText(context, km: '✅ បានបន្ថែម "${product['product_name'] ?? 'ទំនិញ'}" ចូលការជជែក!', en: '✅ "${product['product_name'] ?? 'Product'}" added to chat!')), backgroundColor: Colors.orange, duration: const Duration(seconds: 1)));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${appText(context, km: '❌ បរាជ័យ', en: '❌ Failed')}: $e')));
    }
  }

  Future<void> _setShopClosed(bool shouldClose) async {
    try {
      final userRef = FirebaseFirestore.instance.collection('users').doc(widget.sellerId);
      final products = await FirebaseFirestore.instance.collection('products').where('seller_id', isEqualTo: widget.sellerId).get();
      final batch = FirebaseFirestore.instance.batch();
      batch.set(userRef, {'shop_closed': shouldClose, 'shop_status_updated_at': FieldValue.serverTimestamp()}, SetOptions(merge: true));
      for (final doc in products.docs) batch.update(doc.reference, {'shop_closed': shouldClose});
      await batch.commit();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(shouldClose ? appText(context, km: 'ហាងបានបិទបណ្ដោះអាសន្ន', en: 'Shop temporarily closed') : appText(context, km: 'ហាងបានបើកលក់វិញ', en: 'Shop is open again')), backgroundColor: shouldClose ? Colors.grey.shade800 : Colors.green));
    } catch (e) {
      debugPrint('Change shop status error: $e');
    }
  }

  Future<void> _confirmShopStatusChange(bool shouldOpen) async {
    final shouldClose = !shouldOpen;
    if (!shouldClose) {
      await _setShopClosed(false);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(appText(context, km: 'បិទហាងបណ្ដោះអាសន្ន?', en: 'Close shop temporarily?'), style: const TextStyle(fontFamily: 'Siemreap')),
        content: Text(appText(context, km: 'អតិថិជននៅតែអាចមើលទំនិញ និងឆាតបាន ប៉ុន្តែមិនអាចទិញតាមកន្ត្រកបានទេ។', en: 'Customers can still view products and chat, but cannot buy through the cart.'), style: const TextStyle(fontFamily: 'Siemreap')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(appText(context, km: 'បោះបង់', en: 'Cancel'))),
          ElevatedButton(onPressed: () => Navigator.pop(dialogContext, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade800, foregroundColor: Colors.white), child: Text(appText(context, km: 'បិទហាង', en: 'Close shop'))),
        ],
      ),
    );
    if (confirmed == true) await _setShopClosed(true);
  }

  Future<void> _toggleSingleProductLock(Map<String, dynamic> product) async {
    final currentLock = product['is_locked'] == true;
    final productId = (product['id'] ?? '').toString();
    if (productId.isEmpty) return;
    try {
      await FirebaseFirestore.instance.collection('products').doc(productId).update({'is_locked': !currentLock});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(!currentLock ? appText(context, km: '🔒 បានចាក់សោទំនិញ', en: '🔒 Product locked') : appText(context, km: '🔓 បានបើកសោទំនិញ', en: '🔓 Product unlocked')), backgroundColor: !currentLock ? Colors.orange : Colors.green, duration: const Duration(seconds: 1)));
    } catch (e) {
      debugPrint('Toggle single product lock error: $e');
    }
  }

  Future<Map<String, List<int>>> _fetchMonthlyStats() async {
    final currentYear = DateTime.now().year;
    final startOfYear = DateTime(currentYear, 1, 1);
    final endOfYear = DateTime(currentYear + 1, 1, 1);
    final sellerId = widget.sellerId;
    final result = <String, List<int>>{
      'visitors': List.filled(12, 0),
      'ratings': List.filled(12, 0),
      'followers': List.filled(12, 0),
      'products': List.filled(12, 0),
    };
    try {
      final visitorsSnap = await FirebaseFirestore.instance.collection('users').doc(sellerId).collection('profile_visitors').where('visited_at', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfYear)).where('visited_at', isLessThan: Timestamp.fromDate(endOfYear)).get();
      for (final doc in visitorsSnap.docs) {
        final ts = doc.data()['visited_at'] as Timestamp?;
        if (ts != null) result['visitors']![ts.toDate().month - 1]++;
      }
      final productsSnap = await FirebaseFirestore.instance.collection('products').where('seller_id', isEqualTo: sellerId).where('created_at', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfYear)).where('created_at', isLessThan: Timestamp.fromDate(endOfYear)).get();
      for (final doc in productsSnap.docs) {
        final data = doc.data();
        final ts = data['created_at'] as Timestamp?;
        if (ts != null && (data['avgRating'] ?? 0).toDouble() > 0) result['ratings']![ts.toDate().month - 1]++;
      }
      final followersSnap = await FirebaseFirestore.instance.collection('users').doc(sellerId).collection('followers').where('followed_at', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfYear)).where('followed_at', isLessThan: Timestamp.fromDate(endOfYear)).get();
      for (final doc in followersSnap.docs) {
        final ts = doc.data()['followed_at'] as Timestamp?;
        if (ts != null) result['followers']![ts.toDate().month - 1]++;
      }
      for (final doc in productsSnap.docs) {
        final ts = doc.data()['created_at'] as Timestamp?;
        if (ts != null) result['products']![ts.toDate().month - 1]++;
      }
    } catch (e) {
      debugPrint('Error fetching monthly stats: $e');
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
      final doc = await FirebaseFirestore.instance.collection('users').doc(widget.sellerId).get();
      if (doc.exists) {
        final data = doc.data()!;
        coverUrl = data['coverUrl'] ?? '';
        photoUrl = data['photoUrl'] ?? '';
        shopName = data['name'] ?? widget.sellerName;
        sesanId = data['sesan_id']?.toString() ?? '';
        phone = data['phone'] ?? '';
      }
      final productsSnap = await FirebaseFirestore.instance.collection('products').where('seller_id', isEqualTo: widget.sellerId).get();
      productCount = productsSnap.docs.length;
    } catch (e) {
      debugPrint('Error fetching shop data: $e');
    }
    final sellerShopUrl = 'https://sesanshop.com/shop/${widget.sellerId}';
    final englishShareMessage = '''
 🛍️ Discover a great shop on Sesan App!
 🏪 $shopName
 🔗 View this shop in the app: $sellerShopUrl
 📲 Don't have the app yet? Download it here:
 Android: https://play.google.com/store/apps/details?id=com.sesan.app
 iOS: https://apps.apple.com/kh/app/sesan-app/id6789862316''';
    final shareMessage = Localizations.localeOf(context).languageCode == 'en'
        ? englishShareMessage
        : '''
 🛍️ រកឃើញហាងល្អៗនៅក្នុង Sesan App!
 🏪 $shopName ${sesanId.isNotEmpty ? '🆔 Sesan ID: $sesanId\n' : ''}
 🔗 មើលហាងក្នុង App៖ https://sesanshop.com/shop/${widget.sellerId}
 📲 មិនទាន់មាន App? ទាញយកទីនេះ៖
 Android: https://play.google.com/store/apps/details?id=com.sesan.app
 iOS: https://apps.apple.com/kh/app/sesan-app/id6789862316''';
    try {
      if (mounted) Get.dialog(const Center(child: CircularProgressIndicator(color: Colors.white)), barrierDismissible: false);
      final image = await _screenshotController.captureFromWidget(_buildShopWatermarkWidget(coverUrl: coverUrl, photoUrl: photoUrl, shopName: shopName, sesanId: sesanId, sellerId: widget.sellerId, phone: phone, productCount: productCount), delay: const Duration(milliseconds: 1500), pixelRatio: 2.0);
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/sesan_shop_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(image);
      if (mounted) Get.back();
      await Share.shareXFiles([XFile(file.path)], text: shareMessage, subject: shopName);
    } catch (e) {
      if (mounted) Get.back();
      await Share.share(shareMessage);
    }
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          child: Column(children: [
            Padding(padding: const EdgeInsets.all(16), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(appText(context, km: 'តម្រៀបទំនិញ', en: 'Filter products'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), TextButton(onPressed: () { setState(() { _filterMainCategory = null; _filterSubCategory = null; _filterSubSubCategory = null; }); setSheetState(() {}); Navigator.pop(ctx); }, child: Text(appText(context, km: 'លុបតម្រៀប', en: 'Clear')))])),
            const Divider(),
            Expanded(child: ListView(padding: const EdgeInsets.all(16), children: [
              Text(appText(context, km: 'ប្រភេទមេ', en: 'Main category'), style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, children: _subCategories.keys.map((cat) { final selected = _filterMainCategory == cat; return ChoiceChip(label: Text(localizedCategoryLabel(context, cat)), selected: selected, selectedColor: Colors.green[100], onSelected: (val) { setSheetState(() { _filterMainCategory = val ? cat : null; _filterSubCategory = null; _filterSubSubCategory = null; }); setState(() {}); }); }).toList()),
              if (_filterMainCategory != null) ...[const SizedBox(height: 20), Text(appText(context, km: 'ប្រភេទរង', en: 'Subcategory'), style: const TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 8), _buildSubCategorySelector(setSheetState)],
              if (_filterSubCategory != null && _hasSubSubCategories()) ...[const SizedBox(height: 20), Text(appText(context, km: 'ប្រភេទរងបន្ត', en: 'More specific category'), style: const TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 8), _buildSubSubCategorySelector(setSheetState)],
              const SizedBox(height: 40),
              ElevatedButton(onPressed: () => Navigator.pop(ctx), style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700], minimumSize: const Size(double.infinity, 50)), child: Text(appText(context, km: 'អនុវត្ត', en: 'Apply'))),
            ])),
          ]),
        ),
      ),
    );
  }

  void _showFollowersList() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(widget.sellerId).collection('followers').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) return Center(child: Text(appText(context, km: 'មិនមានអ្នកតាមដាន', en: 'No followers')));
          return ListView.builder(itemCount: docs.length, itemBuilder: (context, index) {
            final followerData = docs[index].data() as Map<String, dynamic>;
            final followerUserId = followerData['user_id'] ?? '';
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('users').doc(followerUserId).get(),
              builder: (context, userSnapshot) {
                String name = followerUserId;
                String photoUrl = '';
                if (userSnapshot.hasData && userSnapshot.data!.exists) {
                  final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                  name = userData['name'] ?? followerUserId;
                  photoUrl = userData['photoUrl'] ?? '';
                }
                return ListTile(leading: CircleAvatar(radius: 22, backgroundColor: Colors.green.shade100, backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null, child: photoUrl.isEmpty ? Icon(Icons.person, color: Colors.green[700]) : null), title: Text(name, style: const TextStyle(fontFamily: 'Siemreap', fontWeight: FontWeight.bold)), subtitle: Text(followerUserId, style: const TextStyle(fontSize: 11, color: Colors.grey)));
              },
            );
          });
        },
      ),
    );
  }

  void _editShopEvent(String currentText) {
    final controller = TextEditingController(text: currentText);
    showDialog(context: context, builder: (ctx) => AlertDialog(title: Text(appText(context, km: 'កែប្រែប្រកាស', en: 'Edit announcement')), content: TextField(controller: controller, maxLines: 3), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(appText(context, km: 'បោះបង់', en: 'Cancel'))), ElevatedButton(onPressed: () async { await FirebaseFirestore.instance.collection('users').doc(_cachedCurrentUid).update({'shop_event_text': controller.text.trim()}); if (ctx.mounted) Navigator.pop(ctx); }, child: Text(appText(context, km: 'រក្សាទុក', en: 'Save')))]));
  }

  Stream<QuerySnapshot> _getFilteredStream() {
    Query query = FirebaseFirestore.instance.collection('products').where('seller_id', isEqualTo: widget.sellerId);
    if (_filterMainCategory != null) query = query.where('category', isEqualTo: _filterMainCategory);
    if (_filterSubCategory != null && _filterSubCategory != 'ទាំងអស់') query = query.where('sub_category', isEqualTo: _filterSubCategory);
    if (_filterSubSubCategory != null && _filterSubSubCategory != 'ទាំងអស់') query = query.where('sub_sub_category', isEqualTo: _filterSubSubCategory);
    return query.orderBy('created_at', descending: true).snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: CustomScrollView(slivers: [
        _buildSliverAppBar(context),
        SliverToBoxAdapter(child: _buildSellerInfoCard(context)),
        SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(16, 20, 16, 8), child: Row(children: [
          Container(width: 4, height: 24, decoration: BoxDecoration(color: Colors.green[700], borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Expanded(child: Text(appText(context, km: 'ទំនិញដាក់លក់', en: 'Products for sale'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87))),
          IconButton(icon: Icon(Icons.filter_list_rounded, color: _filterMainCategory != null ? Colors.green[700] : Colors.grey[600]), onPressed: _showFilterSheet),
          const SizedBox(width: 4),
          Flexible(child: StreamBuilder<QuerySnapshot>(stream: FirebaseFirestore.instance.collection('products').where('seller_id', isEqualTo: widget.sellerId).snapshots(), builder: (context, snapshot) { final count = snapshot.hasData ? snapshot.data!.docs.length : 0; return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(20)), child: Text(appText(context, km: '$count ទំនិញ', en: '$count products'), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Colors.green[700], fontWeight: FontWeight.w600))); })),
        ]))),
        _buildProductsGrid(context),
      ]),
    );
  }

  Widget _buildSubCategorySelector(StateSetter setSheetState) {
    final subData = _subCategories[_filterMainCategory!];
    if (subData is List) {
      return Wrap(spacing: 8, children: subData.map((sub) { final selected = _filterSubCategory == sub; return ChoiceChip(label: Text(localizedCategoryLabel(context, sub.toString())), selected: selected, selectedColor: Colors.orange[100], onSelected: (val) { setSheetState(() { _filterSubCategory = val ? sub.toString() : null; _filterSubSubCategory = null; }); setState(() {}); }); }).toList());
    } else if (subData is Map) {
      return Wrap(spacing: 8, children: (subData as Map<String, dynamic>).keys.map((sub) { final selected = _filterSubCategory == sub; return ChoiceChip(label: Text(localizedCategoryLabel(context, sub)), selected: selected, selectedColor: Colors.orange[100], onSelected: (val) { setSheetState(() { _filterSubCategory = val ? sub : null; _filterSubSubCategory = null; }); setState(() {}); }); }).toList());
    }
    return const SizedBox.shrink();
  }

  Widget _buildSubSubCategorySelector(StateSetter setSheetState) {
    final subData = _subCategories[_filterMainCategory!];
    List<String> subSubList = [];
    if (subData is Map) {
      final dynamic subMap = subData[_filterSubCategory];
      if (subMap is List) subSubList = List<String>.from(subMap);
    }
    if (subSubList.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 8, children: subSubList.map((ssub) { final selected = _filterSubSubCategory == ssub; return ChoiceChip(label: Text(localizedCategoryLabel(context, ssub)), selected: selected, selectedColor: Colors.red[100], onSelected: (val) { setSheetState(() => _filterSubSubCategory = val ? ssub : null); setState(() {}); }); }).toList());
  }

  bool _hasSubSubCategories() {
    final subData = _subCategories[_filterMainCategory!];
    if (subData is Map) {
      final dynamic subMap = subData[_filterSubCategory];
      return subMap is List && subMap.isNotEmpty;
    }
    return false;
  }

  Widget _buildShopWatermarkWidget({required String coverUrl, required String photoUrl, required String shopName, required String sesanId, required String sellerId, required String phone, required int productCount}) {
    return Container(
      width: 500,
      color: Colors.white,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Stack(clipBehavior: Clip.none, children: [
          Container(height: 140, width: double.infinity, decoration: BoxDecoration(color: Colors.green[100], image: coverUrl.isNotEmpty ? DecorationImage(image: NetworkImage(coverUrl), fit: BoxFit.cover) : null), child: coverUrl.isEmpty ? const Icon(Icons.store, size: 60, color: Colors.green) : null),
          Positioned(bottom: -30, left: 16, child: Container(width: 70, height: 70, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3), image: photoUrl.isNotEmpty ? DecorationImage(image: NetworkImage(photoUrl), fit: BoxFit.cover) : null, color: Colors.grey[300]), child: photoUrl.isEmpty ? const Icon(Icons.person, size: 35, color: Colors.grey) : null)),
        ]),
        const SizedBox(height: 40),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(shopName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87, fontFamily: 'Siemreap')),
          if (sesanId.isNotEmpty) ...[const SizedBox(height: 4), Text('Sesan ID: $sesanId', style: TextStyle(fontSize: 13, color: Colors.blue[700], fontWeight: FontWeight.w600))],
          if (phone.isNotEmpty) ...[const SizedBox(height: 4), Text('📞 ${_maskSellerPhone(phone)}', style: const TextStyle(fontSize: 13, color: Colors.black54))],
          const SizedBox(height: 4),
          Text(appText(context, km: '$productCount ទំនិញ • កំពុងលក់', en: '$productCount products • For sale'), style: const TextStyle(fontSize: 13, color: Colors.black54)),
          const SizedBox(height: 4),
          Text('📅 ${DateFormat('dd/MM/yyyy').format(DateTime.now())}', style: const TextStyle(fontSize: 12, color: Colors.black54, fontFamily: 'Siemreap')),
        ])),
        const SizedBox(height: 16),
        Container(padding: const EdgeInsets.all(16), margin: const EdgeInsets.symmetric(horizontal: 16), decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(12)), child: Row(children: [QrImageView(data: 'shop_id_$sellerId', size: 80), const SizedBox(width: 16), Expanded(child: Text(appText(context, km: 'ស្កេនដើម្បីមើលហាងនេះក្នុង Sesan App', en: 'Scan to view this shop in Sesan App'), style: TextStyle(fontSize: 13, color: Colors.grey[600], fontFamily: 'Siemreap'))), ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.asset('assets/sesan_icon.jpg', width: 45, height: 45, fit: BoxFit.cover))])),
        const SizedBox(height: 20),
      ]),
    );
  }

  Widget _buildSliverAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 175,
      pinned: true,
      backgroundColor: Colors.green[700],
      leading: Container(margin: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), shape: BoxShape.circle), child: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context))),
      actions: [
        if (_cachedCurrentUid == widget.sellerId) IconButton(icon: const CircleAvatar(backgroundColor: Colors.black26, child: Icon(Icons.edit, color: Colors.white, size: 20)), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditShopScreen()))),
        IconButton(icon: const Icon(Icons.share, color: Colors.white), onPressed: _shareShopWithWatermark),
      ],
      centerTitle: true,
      title: Text(widget.sellerName, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Siemreap', shadows: [Shadow(color: Colors.black45, blurRadius: 6, offset: Offset(0, 2))])),
      flexibleSpace: FlexibleSpaceBar(background: StreamBuilder<DocumentSnapshot>(stream: FirebaseFirestore.instance.collection('users').doc(widget.sellerId).snapshots(), builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) return _buildDefaultCover();
        final userData = snapshot.data!.data() as Map<String, dynamic>?;
        final coverUrl = userData?['coverUrl'] ?? '';
        final photoUrl = userData?['photoUrl'] ?? '';
        return Stack(fit: StackFit.expand, children: [
          coverUrl.isNotEmpty ? CachedNetworkImage(imageUrl: coverUrl, fit: BoxFit.cover, placeholder: (_, __) => _buildShimmerCover(), errorWidget: (_, __, ___) => _buildDefaultCover()) : _buildDefaultCover(),
          Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black.withOpacity(0.4), Colors.black.withOpacity(0.6)]))),
          Positioned(bottom: 10, left: 0, right: 0, child: Center(child: Hero(tag: 'seller_avatar_${widget.sellerId}', child: Container(width: 64, height: 64, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 6, spreadRadius: 1)]), child: ClipOval(child: photoUrl.isNotEmpty ? CachedNetworkImage(imageUrl: photoUrl, fit: BoxFit.cover, placeholder: (_, __) => Container(color: Colors.grey[300], child: const Icon(Icons.person, size: 32)), errorWidget: (_, __, ___) => Container(color: Colors.grey[300], child: const Icon(Icons.person, size: 32))) : Container(color: Colors.grey[300], child: const Icon(Icons.person, size: 32))))))),
        ]);
      })),
    );
  }

  Future<void> _openShopDirections(double latitude, double longitude) async {
    final url = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication) && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(appText(context, km: 'មិនអាចបើក Google Maps បានទេ', en: 'Could not open Google Maps.'))));
    }
  }

  Widget _buildShopMapPreview(double latitude, double longitude) {
    final location = LatLng(latitude, longitude);
    return Padding(padding: const EdgeInsets.only(top: 4, bottom: 10), child: GestureDetector(onTap: () => _openShopDirections(latitude, longitude), child: AspectRatio(aspectRatio: 4, child: ClipRRect(borderRadius: BorderRadius.circular(12), child: Stack(fit: StackFit.expand, children: [
      AbsorbPointer(child: GoogleMap(initialCameraPosition: CameraPosition(target: location, zoom: 15.5), markers: {Marker(markerId: const MarkerId('shop_location'), position: location)}, zoomControlsEnabled: false, myLocationButtonEnabled: false, mapToolbarEnabled: false, compassEnabled: false, scrollGesturesEnabled: false, zoomGesturesEnabled: false, rotateGesturesEnabled: false, tiltGesturesEnabled: false, liteModeEnabled: true)),
      Container(color: Colors.black.withOpacity(0.05)),
      Center(child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7), decoration: BoxDecoration(color: Colors.white.withOpacity(0.94), borderRadius: BorderRadius.circular(20), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 5)]), child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.directions, color: Colors.green, size: 18), const SizedBox(width: 6), Text(appText(context, km: 'ទៅកាន់ហាង', en: 'Directions to shop'), style: const TextStyle(fontFamily: 'Siemreap', fontSize: 11, fontWeight: FontWeight.bold))]))),
    ])))));
  }

  Widget _buildSellerInfoCard(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(widget.sellerId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) return const SizedBox.shrink();
        final userData = snapshot.data!.data() as Map<String, dynamic>?;
        final shopTier = userData?['shop_tier'] as String?;
        final followers = (userData?['followers_count'] ?? 0).toString();
        final shopAddress = userData?['address'] ?? appText(context, km: 'មិនទាន់មានទីតាំង', en: 'Location not provided');
        final shopLatitude = (userData?['shop_latitude'] as num?)?.toDouble();
        final shopLongitude = (userData?['shop_longitude'] as num?)?.toDouble();
        final shopClosed = userData?['shop_closed'] == true;
        final canShowShopMap = (shopTier == 'basic' || shopTier == 'premium') && shopLatitude != null && shopLongitude != null;
        String joinDate = appText(context, km: 'ថ្មីៗនេះ', en: 'Recently');
        if (userData?['createdAt'] != null) {
          final createdAt = userData?['createdAt'];
          DateTime date;
          if (createdAt is Timestamp) date = createdAt.toDate(); else if (createdAt is DateTime) date = createdAt; else if (createdAt is String) date = DateTime.tryParse(createdAt) ?? DateTime.now(); else date = DateTime.now();
          joinDate = DateFormat('dd/MM/yyyy').format(date);
        }
        return Container(
          margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 3))]),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              StreamBuilder<QuerySnapshot>(stream: FirebaseFirestore.instance.collection('products').where('seller_id', isEqualTo: widget.sellerId).snapshots(), builder: (context, productSnapshot) { String rating = '0.0'; if (productSnapshot.hasData && productSnapshot.data!.docs.isNotEmpty) { double totalRating = 0; int ratedProducts = 0; for (final doc in productSnapshot.data!.docs) { final data = doc.data() as Map<String, dynamic>; final avg = (data['avgRating'] ?? 0).toDouble(); final reviews = (data['totalReviews'] ?? 0).toInt(); if (reviews > 0) { totalRating += avg; ratedProducts++; } } if (ratedProducts > 0) rating = (totalRating / ratedProducts).toStringAsFixed(1); } return _buildStatItem(Icons.star, rating, appText(context, km: 'ការវាយតម្លៃ', en: 'Rating')); }),
              _buildDivider(),
              Column(mainAxisSize: MainAxisSize.min, children: [GestureDetector(onTap: shopTier != null && shopTier != 'free' ? _showFollowersList : null, child: _buildStatItem(Icons.people, followers, appText(context, km: 'អ្នកតាមដាន', en: 'Followers'))), if (_currentUserId != widget.sellerId) ...[const SizedBox(height: 4), _FollowButton(sellerId: widget.sellerId, currentUserId: _currentUserId, compact: true)]]),
              _buildDivider(),
              _buildStatItem(Icons.access_time, joinDate, appText(context, km: 'ថ្ងៃចូលរួម', en: 'Joined')),
            ]),
            const SizedBox(height: 8),
            if (shopTier != null && shopTier != 'free') ...[
              const SizedBox(height: 10),
              Row(children: [Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: shopTier == 'premium' ? Colors.amber : Colors.blueAccent, borderRadius: BorderRadius.circular(9)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(shopTier == 'premium' ? Icons.diamond : Icons.verified_user, color: Colors.white, size: 14), const SizedBox(width: 4), Text(shopTier == 'premium' ? appText(context, km: 'បានផ្ទៀងផ្ទាត់កម្រិតមាស', en: 'Gold Verified') : appText(context, km: 'បានផ្ទៀងផ្ទាត់កម្រិតខៀវ', en: 'Blue Verified'), style: const TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'Siemreap', fontWeight: FontWeight.bold))])), const SizedBox(width: 10), StreamBuilder<QuerySnapshot>(stream: FirebaseFirestore.instance.collection('users').doc(widget.sellerId).collection('profile_visitors').snapshots(), builder: (context, visitorSnapshot) { final views = visitorSnapshot.hasData ? visitorSnapshot.data!.docs.length : 0; return Row(children: [const Icon(Icons.visibility, size: 14, color: Colors.grey), const SizedBox(width: 4), Text('$views', style: const TextStyle(fontSize: 12, color: Colors.grey))]); })]),
            ],
            if (_cachedCurrentUid == widget.sellerId && shopTier == 'premium') FutureBuilder<Map<String, List<int>>>(future: _fetchMonthlyStats(), builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final data = snapshot.data!;
              final months = Localizations.localeOf(context).languageCode == 'en' ? ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'] : ['មករា','កុម្ភៈ','មីនា','មេសា','ឧសភា','មិថុនា','កក្កដា','សីហា','កញ្ញា','តុលា','វិច្ឆិកា','ធ្នូ'];
              final lineConfig = <String, Map<String, dynamic>>{
                'visitors': {'color': Colors.blueAccent, 'label': appText(context, km: 'អ្នកចូលមើល', en: 'Visitors')},
                'ratings': {'color': Colors.amber, 'label': appText(context, km: 'ការវាយតម្លៃ', en: 'Ratings')},
                'followers': {'color': Colors.green, 'label': appText(context, km: 'អ្នកតាមដាន', en: 'Followers')},
                'products': {'color': Colors.purpleAccent, 'label': appText(context, km: 'ទំនិញ', en: 'Products')},
              };
              double maxY = 0;
              for (final values in data.values) { final maxVal = values.reduce((a, b) => a > b ? a : b).toDouble(); if (maxVal > maxY) maxY = maxVal; }
              maxY = (maxY + 1).ceilToDouble();
              final lineBars = <LineChartBarData>[];
              data.forEach((key, values) { lineBars.add(LineChartBarData(spots: List.generate(12, (i) => FlSpot(i.toDouble(), values[i].toDouble())), isCurved: true, color: lineConfig[key]!['color'] as Color, barWidth: 3, dotData: FlDotData(show: true, getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(radius: 4, color: lineConfig[key]!['color'] as Color, strokeWidth: 2, strokeColor: Colors.white)), belowBarData: BarAreaData(show: true, color: (lineConfig[key]!['color'] as Color).withOpacity(0.1)))); });
              return Container(margin: const EdgeInsets.only(top: 12), padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(9), border: Border.all(color: Colors.grey.shade200)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(appText(context, km: '📊 ស្ថិតិប្រចាំឆ្នាំ', en: '📊 Annual statistics'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, fontFamily: 'Siemreap')), const SizedBox(height: 12), SizedBox(height: 200, child: LineChart(LineChartData(minY: 0, maxY: maxY, gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => FlLine(color: Colors.grey.shade200, strokeWidth: 1)), titlesData: FlTitlesData(leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30, getTitlesWidget: (value, meta) => value == value.roundToDouble() ? Text('${value.toInt()}', style: const TextStyle(fontSize: 10, color: Colors.grey)) : const Text(''))), bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (value, meta) { final idx = value.toInt(); return idx >= 0 && idx < 12 ? Padding(padding: const EdgeInsets.only(top: 8), child: Text(months[idx], style: const TextStyle(fontSize: 8, color: Colors.grey))) : const Text(''); })), topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false))), borderData: FlBorderData(show: false), lineBarsData: lineBars))), const SizedBox(height: 10), Wrap(spacing: 16, runSpacing: 6, children: lineConfig.entries.map((entry) => Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 12, height: 12, decoration: BoxDecoration(color: entry.value['color'] as Color, shape: BoxShape.circle)), const SizedBox(width: 4), Text(entry.value['label'] as String, style: const TextStyle(fontSize: 11, color: Colors.grey))])).toList())]));
            }),
            FutureBuilder<DocumentSnapshot>(future: FirebaseFirestore.instance.collection('users').doc(widget.sellerId).get(), builder: (context, snapshot) {
              if (!snapshot.hasData || !snapshot.data!.exists) return const SizedBox.shrink();
              final userData = snapshot.data!.data() as Map<String, dynamic>?;
              final sesanId = userData?['sesan_id']?.toString() ?? '';
              if (sesanId.isEmpty) return const SizedBox.shrink();
              return Column(children: [const SizedBox(height: 7), Container(padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10), decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blue[200]!)), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.badge, color: Colors.blue[700], size: 17), const SizedBox(width: 6), Text('Sesan ID: ', style: TextStyle(color: Colors.blue[700], fontWeight: FontWeight.bold, fontSize: 12)), Text(sesanId, style: TextStyle(color: Colors.blue[900], fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1)), const SizedBox(width: 8), GestureDetector(onTap: () { Clipboard.setData(ClipboardData(text: sesanId)); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(appText(context, km: '✅ បានចម្លង Sesan ID: $sesanId', en: '✅ Sesan ID copied: $sesanId')), backgroundColor: Colors.blue, duration: const Duration(seconds: 1))); }, child: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: Colors.blue[100], borderRadius: BorderRadius.circular(6)), child: Icon(Icons.copy, color: Colors.blue[700], size: 14)))])), const SizedBox(height: 8)]);
            }),
            FutureBuilder<String>(future: _sellerPhoneFuture, builder: (context, phoneSnapshot) {
              final phone = phoneSnapshot.data ?? '';
              return Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [
                Expanded(flex: 4, child: ElevatedButton.icon(onPressed: () async { await _recordMarketplaceEvent('chat_seller'); if (!context.mounted) return; Navigator.push(context, MaterialPageRoute(builder: (context) => ChatScreen(seller_id: widget.sellerId, receiver_id: widget.sellerId, productName: appText(context, km: 'ហាងរបស់ ${widget.sellerName}', en: "${widget.sellerName}'s shop"), productId: 'general'))); }, icon: const Icon(Icons.chat_bubble_outline, size: 15), label: Text(appText(context, km: 'ឆាត', en: 'Chat'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, fontFamily: 'Siemreap')), style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700], foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8), minimumSize: const Size(0, 40), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))))),
                if (phone.isNotEmpty) ...[const SizedBox(width: 6), Expanded(flex: 6, child: Container(height: 40, padding: const EdgeInsets.symmetric(horizontal: 7), decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(10)), child: ValueListenableBuilder<bool>(valueListenable: _showSellerPhoneNotifier, builder: (context, showPhone, _) => Row(children: [Icon(Icons.phone, color: Colors.green[700], size: 14), const SizedBox(width: 4), Expanded(child: AnimatedSwitcher(duration: const Duration(milliseconds: 220), child: Text(showPhone ? phone : _maskSellerPhone(phone), key: ValueKey<bool>(showPhone), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.green[800], fontWeight: FontWeight.bold, fontSize: 11)))), IconButton(onPressed: showPhone ? () { _phoneHideTimer?.cancel(); _showSellerPhoneNotifier.value = false; } : _revealSellerPhoneTemporarily, icon: Icon(showPhone ? Icons.visibility_off : Icons.visibility, size: 15), tooltip: showPhone ? appText(context, km: 'លាក់លេខ', en: 'Hide') : appText(context, km: 'បង្ហាញលេខ', en: 'Show number'), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 28, minHeight: 28), visualDensity: VisualDensity.compact)]))))],
              ]));
            }),
            Padding(padding: const EdgeInsets.only(top: 0, bottom: 8), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.location_on, color: Colors.redAccent, size: 16), const SizedBox(width: 4), Flexible(child: Text(shopAddress, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey[700], fontFamily: 'Siemreap')))])),
            if (canShowShopMap) _buildShopMapPreview(shopLatitude!, shopLongitude!),
            if (_cachedCurrentUid == widget.sellerId) Container(margin: const EdgeInsets.only(top: 4, bottom: 10), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9), decoration: BoxDecoration(color: shopClosed ? Colors.grey.shade100 : Colors.green.shade50, borderRadius: BorderRadius.circular(12)), child: Row(children: [Icon(shopClosed ? Icons.store_mall_directory_outlined : Icons.store, color: shopClosed ? Colors.grey.shade700 : Colors.green.shade700), const SizedBox(width: 10), Expanded(child: Text(shopClosed ? appText(context, km: 'ហាងបិទបណ្ដោះអាសន្ន', en: 'Shop temporarily closed') : appText(context, km: 'ហាងកំពុងបើកលក់', en: 'Shop is open'), style: const TextStyle(fontFamily: 'Siemreap', fontSize: 12, fontWeight: FontWeight.bold))), Transform.scale(scale: 0.86, child: Switch.adaptive(value: !shopClosed, activeThumbColor: Colors.white, activeTrackColor: Colors.green.shade700, inactiveThumbColor: Colors.white, inactiveTrackColor: Colors.grey.shade600, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap, onChanged: _confirmShopStatusChange))])) else if (shopClosed) Container(width: double.infinity, margin: const EdgeInsets.only(top: 4, bottom: 10), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(12)), child: Text(appText(context, km: 'ហាងនេះបិទបណ្ដោះអាសន្ន — អាចមើល និងឆាតបាន', en: 'This shop is temporarily closed — browsing and chat remain available.'), textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'Siemreap', fontSize: 11, fontWeight: FontWeight.w600))),
            if (shopTier == 'premium') ...[const SizedBox(height: 12), StreamBuilder<DocumentSnapshot>(stream: FirebaseFirestore.instance.collection('users').doc(widget.sellerId).snapshots(), builder: (context, shopSnapshot) { if (!shopSnapshot.hasData) return const SizedBox.shrink(); final shopData = shopSnapshot.data!.data() as Map<String, dynamic>?; final eventText = shopData?['shop_event_text'] ?? ''; final isOwner = _cachedCurrentUid == widget.sellerId; return Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.amber.shade200)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(Icons.campaign, color: Colors.amber.shade700, size: 18), const SizedBox(width: 8), Expanded(child: Text(appText(context, km: 'ប្រកាសពិសេស', en: 'Special announcement'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Siemreap', fontSize: 12))), if (isOwner) IconButton(icon: const Icon(Icons.edit, size: 16), onPressed: () => _editShopEvent(eventText))]), if (eventText.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(eventText, style: const TextStyle(fontFamily: 'Siemreap', fontSize: 14)))])); })],
            if (_cachedCurrentUid == widget.sellerId) ...[const SizedBox(height: 12), SizedBox(width: double.infinity, child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.amber[700], foregroundColor: Colors.black87, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ShopUpgradeScreen())), icon: const Icon(Icons.verified_user, size: 11), label: Text(appText(context, km: 'ដំឡើងឋានៈហាង', en: 'Upgrade shop'), style: const TextStyle(fontFamily: 'Siemreap', fontWeight: FontWeight.bold, fontSize: 11))))],
          ]),
        );
      },
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) => Column(children: [Icon(icon, color: Colors.green[700], size: 20), const SizedBox(height: 3), Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)), const SizedBox(height: 2), Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600]))]);
  Widget _buildDivider() => Container(height: 30, width: 1, color: Colors.grey[200]);

  Widget _buildProductsGrid(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _getFilteredStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return SliverToBoxAdapter(child: _buildShimmerGrid());
        if (snapshot.hasError) return SliverToBoxAdapter(child: Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(children: [Icon(Icons.error_outline, color: Colors.red[300], size: 64), const SizedBox(height: 16), Text(appText(context, km: 'មិនអាចផ្ទុកទំនិញបាន', en: 'Could not load products.'), style: TextStyle(color: Colors.red[300], fontSize: 16)), const SizedBox(height: 8), ElevatedButton(onPressed: () => setState(() {}), child: Text(appText(context, km: 'ព្យាយាមម្តងទៀត', en: 'Try again')))]))));
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return SliverToBoxAdapter(child: Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(children: [Icon(Icons.inventory_2_outlined, color: Colors.grey[300], size: 80), const SizedBox(height: 16), Text(appText(context, km: 'មិនទាន់មានទំនិញលក់នៅឡើយ', en: 'No products for sale yet.'), style: TextStyle(color: Colors.grey[400], fontSize: 16))]))));
        final products = snapshot.data!.docs;
        return SliverPadding(
          padding: const EdgeInsets.all(12),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: MediaQuery.of(context).size.width > 1200 ? 6 : MediaQuery.of(context).size.width > 900 ? 5 : MediaQuery.of(context).size.width > 700 ? 4 : MediaQuery.of(context).size.width > 500 ? 3 : 2,
              childAspectRatio: MediaQuery.of(context).size.width > 700 ? 0.80 : 0.65,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            delegate: SliverChildBuilderDelegate((context, index) {
              final data = products[index].data() as Map<String, dynamic>;
              data['id'] = products[index].id;
              String imageUrl = '';
              if (data['image_urls'] is List && (data['image_urls'] as List).isNotEmpty) imageUrl = data['image_urls'][0].toString(); else if (data['image_url'] != null) imageUrl = data['image_url'].toString();
              final productName = data['product_name'] ?? appText(context, km: 'គ្មានឈ្មោះ', en: 'Unnamed product');
              final location = (data['location'] ?? appText(context, km: 'ភ្នំពេញ', en: 'Phnom Penh')).toString();
              final timestamp = data['created_at'];
              final isLocked = data['is_locked'] == true;
              final shippingIncluded = data['shipping_included'];
              final isCartDisabled = isLocked || data['shop_closed'] == true || shippingIncluded == false;
              final priceValue = double.tryParse((data['price'] ?? '0').toString().replaceAll(',', '')) ?? 0;
              final formattedPrice = NumberFormat('#,###').format(priceValue);
              final currency = (data['currency'] ?? '៛').toString();
              final isAvailable = data['is_available'] ?? true;
              final productId = products[index].id;
              return GestureDetector(
                onTap: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('last_product_id', products[index].id);
                  await prefs.setString('current_seller_id', widget.sellerId);
                  final productData = products[index].data() as Map<String, dynamic>;
                  productData['id'] = products[index].id;
                  if (!context.mounted) return;
                  Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailScreen(product: productData)));
                },
                child: Container(
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))]),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(flex: 3, child: Stack(children: [
                      ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(16)), child: imageUrl.isNotEmpty ? CachedNetworkImage(imageUrl: imageUrl, fit: BoxFit.cover, width: double.infinity, placeholder: (_, __) => Container(color: Colors.grey[100], child: const Center(child: CircularProgressIndicator(strokeWidth: 2))), errorWidget: (_, __, ___) => Container(color: Colors.grey[100], child: Icon(Icons.image_not_supported, color: Colors.grey[400], size: 40))) : Container(color: Colors.grey[100], child: Icon(Icons.image_not_supported, color: Colors.grey[400], size: 40))),
                      if ((data['video_url'] ?? '').toString().isNotEmpty) Positioned(bottom: 4, right: 4, child: Container(decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle), padding: const EdgeInsets.all(4), child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 16))),
                      if (!isAvailable) Positioned(top: 8, left: 8, child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(8)), child: Text(appText(context, km: 'ដាច់ស្តុក', en: 'Out of stock'), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)))),
                      if (data['discount'] != null) Positioned(top: 8, right: 8, child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(8)), child: Text('-${data['discount']}%', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)))),
                      if (_cachedCurrentUid == widget.sellerId) Positioned(top: 5, right: 5, child: Transform.scale(scale: 0.86, child: Switch.adaptive(value: !isLocked, activeThumbColor: Colors.white, activeTrackColor: Colors.green.shade700, inactiveThumbColor: Colors.white, inactiveTrackColor: Colors.grey.shade700, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap, onChanged: (cartEnabled) async { await FirebaseFirestore.instance.collection('products').doc(productId).update({'is_locked': !cartEnabled}); if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(cartEnabled ? appText(context, km: 'បានបើកលក់តាមកន្ត្រក', en: 'Cart sales enabled') : appText(context, km: 'បានបិទលក់តាមកន្ត្រក', en: 'Cart sales disabled')), backgroundColor: cartEnabled ? Colors.green : Colors.grey.shade800, duration: const Duration(seconds: 1))); }))),
                    ])),
                    Expanded(flex: 2, child: Padding(padding: const EdgeInsets.all(8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.start, children: [
                      Flexible(child: Text(productName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, height: 1.2, fontFamily: 'Siemreap'))),
                      const SizedBox(height: 2),
                      Flexible(child: Row(children: [const Icon(Icons.access_time, size: 9, color: Colors.grey), const SizedBox(width: 2), Flexible(child: Text(_formatTimeAgo(timestamp), style: const TextStyle(fontSize: 8, color: Colors.grey, fontFamily: 'Siemreap'), maxLines: 1, overflow: TextOverflow.ellipsis)), const Text(' • ', style: TextStyle(fontSize: 8, color: Colors.grey)), Expanded(child: Text(location, style: const TextStyle(fontSize: 8, color: Colors.grey, fontFamily: 'Siemreap'), maxLines: 1, overflow: TextOverflow.ellipsis))])),
                      const SizedBox(height: 2),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Flexible(child: Text('$formattedPrice $currency', style: TextStyle(color: Colors.red[700], fontWeight: FontWeight.bold, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)),
                        GestureDetector(onTap: _currentUserId == null ? null : () => _addToChat(data), child: Container(padding: const EdgeInsets.all(3), decoration: BoxDecoration(color: _currentUserId == null ? Colors.grey[200] : Colors.orange[50], borderRadius: BorderRadius.circular(6)), child: Icon(Icons.chat_bubble_outline, color: _currentUserId == null ? Colors.grey : Colors.orange, size: 16))),
                        ValueListenableBuilder<int>(valueListenable: _cartRevision, builder: (context, _, __) { final alreadyInCart = _cartProductIds.contains(productId); final cartBusy = _cartBusyIds.contains(productId); return GestureDetector(onTap: cartBusy ? null : alreadyInCart ? () => _removeSellerProductFromCart(productId) : isCartDisabled ? null : () => _fastAddToCart(data), child: AnimatedContainer(duration: const Duration(milliseconds: 180), padding: const EdgeInsets.all(3), decoration: BoxDecoration(color: alreadyInCart ? Colors.green.shade100 : isCartDisabled ? Colors.grey[200] : Colors.green[50], borderRadius: BorderRadius.circular(6)), child: cartBusy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(alreadyInCart ? Icons.check_circle : Icons.add_shopping_cart, color: alreadyInCart ? Colors.green.shade700 : isCartDisabled ? Colors.grey : Colors.green, size: 16))); }),
                      ]),
                    ]))),
                  ]),
                ),
              );
            }, childCount: products.length),
          ),
        );
      },
    );
  }

  Widget _buildDefaultCover() => Container(color: Colors.green[700], child: Center(child: Icon(Icons.store, size: 80, color: Colors.white.withOpacity(0.3))));
  Widget _buildShimmerCover() => Shimmer.fromColors(baseColor: Colors.grey[300]!, highlightColor: Colors.grey[100]!, child: Container(color: Colors.white));
  Widget _buildShimmerGrid() => Padding(padding: const EdgeInsets.all(12), child: GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: MediaQuery.of(context).size.width > 700 ? 4 : 2, childAspectRatio: MediaQuery.of(context).size.width > 700 ? 0.80 : 0.65, crossAxisSpacing: 12, mainAxisSpacing: 12), itemCount: 4, itemBuilder: (_, __) => Shimmer.fromColors(baseColor: Colors.grey[300]!, highlightColor: Colors.grey[100]!, child: Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16))))));
}

class _FollowButton extends StatefulWidget {
  final String sellerId;
  final String? currentUserId;
  final bool compact;
  const _FollowButton({required this.sellerId, required this.currentUserId, this.compact = false});
  @override State<_FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends State<_FollowButton> {
  bool _isFollowing = false;
  bool _isLoading = false;
  @override void initState() { super.initState(); _checkIfFollowing(); }
  Future<void> _checkIfFollowing() async {
    if (widget.currentUserId == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(widget.sellerId).collection('followers').doc(widget.currentUserId).get();
      if (mounted) setState(() => _isFollowing = doc.exists);
    } catch (e) {
      debugPrint('Error checking follow: $e');
    }
  }
  Future<void> _toggleFollow() async {
    if (widget.currentUserId == null || _isLoading || widget.currentUserId == widget.sellerId) return;
    final previousState = _isFollowing;
    setState(() { _isLoading = true; _isFollowing = !_isFollowing; });
    try {
      final batch = FirebaseFirestore.instance.batch();
      final followerRef = FirebaseFirestore.instance.collection('users').doc(widget.sellerId).collection('followers').doc(widget.currentUserId);
      final followingRef = FirebaseFirestore.instance.collection('users').doc(widget.currentUserId!).collection('following').doc(widget.sellerId);
      final sellerRef = FirebaseFirestore.instance.collection('users').doc(widget.sellerId);
      if (previousState) {
        batch.delete(followerRef); batch.delete(followingRef); batch.update(sellerRef, {'followers_count': FieldValue.increment(-1)});
      } else {
        batch.set(followerRef, {'user_id': widget.currentUserId, 'followed_at': FieldValue.serverTimestamp()});
        batch.set(followingRef, {'seller_id': widget.sellerId, 'followed_at': FieldValue.serverTimestamp()});
        batch.update(sellerRef, {'followers_count': FieldValue.increment(1)});
      }
      await batch.commit();
    } catch (_) {
      if (mounted) setState(() => _isFollowing = previousState);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  @override Widget build(BuildContext context) => Container(decoration: widget.compact ? null : BoxDecoration(color: _isFollowing ? Colors.green[700] : Colors.green[50], borderRadius: BorderRadius.circular(12)), child: IconButton(onPressed: _isLoading ? null : _toggleFollow, icon: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(_isFollowing ? Icons.check : Icons.person_add, color: widget.compact ? Colors.green[700] : (_isFollowing ? Colors.white : Colors.green[700])), iconSize: widget.compact ? 16 : 24, constraints: BoxConstraints(minWidth: widget.compact ? 30 : 48, minHeight: widget.compact ? 30 : 48), padding: EdgeInsets.all(widget.compact ? 5 : 14), visualDensity: widget.compact ? VisualDensity.compact : VisualDensity.standard));
}
