import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:my_app/order_history_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'receipt_screen.dart';
import 'package:intl/intl.dart';
import 'order_tracking_screen.dart';
import 'marketplace_analytics_service.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});
  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  String _t(String km, String en) =>
      Localizations.localeOf(context).languageCode == 'en' ? en : km;
  @override
  bool get wantKeepAlive => true;
  bool _isProcessingCheckout = false;
  bool _isAnyFieldFocused = false;
  bool _isLoadingUserId = true;
  final NumberFormat currencyFormat = NumberFormat('#,###', 'en_US');
  String? _currentUserId;
  final Map<String, TextEditingController> _qtyControllers = {};
  final Map<String, FocusNode> _qtyFocusNodes = {};
  final Map<String, int> _localQuantities = {};
  final Map<String, Timer> _debounceTimers = {};
  static const _debounceMs = 500;
  List<QueryDocumentSnapshot>? _cachedDocs;
  double _cachedTotal = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadUserId();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final controller in _qtyControllers.values) controller.dispose();
    for (final node in _qtyFocusNodes.values) node.dispose();
    for (final timer in _debounceTimers.values) timer.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {}

  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _currentUserId = prefs.getString('user_uid');
      _isLoadingUserId = false;
    });
  }

  void _updateQuantity(String docId, int newQty, {int maxQty = 999}) {
    if (newQty < 1) newQty = 1;
    if (newQty > maxQty) newQty = maxQty;
    if (newQty > 999) newQty = 999;
    setState(() => _localQuantities[docId] = newQty);
    _debounceTimers[docId]?.cancel();
    _debounceTimers[docId] = Timer(
      const Duration(milliseconds: _debounceMs),
      () => FirebaseFirestore.instance
          .collection('carts')
          .doc(docId)
          .update({'quantity': newQty})
          .catchError((e) => debugPrint('Firestore update failed: $e')),
    );
  }

  Future<void> _flushPendingUpdates() async {
    final futures = <Future>[];
    for (final entry in _debounceTimers.entries) {
      entry.value.cancel();
      final qty = _localQuantities[entry.key];
      if (qty != null) {
        futures.add(FirebaseFirestore.instance
            .collection('carts')
            .doc(entry.key)
            .update({'quantity': qty}));
      }
    }
    _debounceTimers.clear();
    if (futures.isNotEmpty) await Future.wait(futures);
  }

  int _getQuantity(QueryDocumentSnapshot item) =>
      _localQuantities[item.id] ??
      int.tryParse(item['quantity']?.toString() ?? '1') ??
      1;

  double _calculateTotal(List<QueryDocumentSnapshot> docs) {
    return docs.fold<double>(0.0, (sum, doc) {
      final price =
          double.tryParse(doc['price'].toString().replaceAll(',', '')) ?? 0.0;
      return sum + price * _getQuantity(doc);
    });
  }

  void _dismissKeyboard() => FocusScope.of(context).unfocus();

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return GestureDetector(
      onTap: _dismissKeyboard,
      behavior: HitTestBehavior.translucent,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F7),
        appBar: AppBar(
          title: Text('កន្ត្រករបស់ខ្ញុំ'.tr,
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          backgroundColor: Colors.green,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.history_rounded, size: 28, color: Colors.white),
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const OrderHistoryScreen())),
            ),
            IconButton(
              icon: const Icon(Icons.local_shipping_rounded, color: Colors.white),
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const OrderTrackingScreen())),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Column(children: [
          _buildOrderTracking(),
          Expanded(
            child: _isLoadingUserId
                ? const Center(child: CircularProgressIndicator(color: Colors.green))
                : _currentUserId == null
                    ? Center(child: Text('មិនអាចទាញព័ត៌មានអ្នកប្រើបាន'.tr))
                    : StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('carts')
                            .where('customer_id', isEqualTo: _currentUserId)
                            .orderBy('created_at', descending: true)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting &&
                              _cachedDocs != null) {
                            return _buildCartContent(_cachedDocs!, _cachedTotal);
                          }
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator(color: Colors.green));
                          }
                          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                            _cachedDocs = null;
                            _cachedTotal = 0.0;
                            _localQuantities.clear();
                            for (final timer in _debounceTimers.values) timer.cancel();
                            _debounceTimers.clear();
                            return _buildEmptyCart();
                          }
                          final docs = snapshot.data!.docs;
                          for (final doc in docs) {
                            _localQuantities.putIfAbsent(doc.id,
                                () => int.tryParse(doc['quantity']?.toString() ?? '1') ?? 1);
                          }
                          _localQuantities.removeWhere((id, _) => !docs.any((d) => d.id == id));
                          _debounceTimers.removeWhere((id, timer) {
                            final remove = !docs.any((d) => d.id == id);
                            if (remove) timer.cancel();
                            return remove;
                          });
                          final total = _calculateTotal(docs);
                          _cachedDocs = docs;
                          _cachedTotal = total;
                          return _buildCartContent(docs, total);
                        },
                      ),
          ),
        ]),
      ),
    );
  }

  Widget _buildCartContent(List<QueryDocumentSnapshot> docs, double total) => Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(10),
              itemCount: docs.length,
              itemBuilder: (_, i) => _buildModernCartItem(docs[i]),
            ),
          ),
          if (!_isAnyFieldFocused) _buildCheckoutButton(total, docs),
        ],
      );

  Widget _buildModernCartItem(QueryDocumentSnapshot item) {
    final data = item.data() as Map<String, dynamic>;
    final tracksStock = data['track_stock'] == true;
    final stockQuantity = data['stock_quantity'] is num
        ? (data['stock_quantity'] as num).toInt()
        : int.tryParse(data['stock_quantity']?.toString() ?? '') ?? 0;
    final rawUnit = data['stock_unit']?.toString().trim() ?? '';
    final stockUnit = ['item', 'items', 'item(s)'].contains(rawUnit.toLowerCase()) ? '' : rawUnit;
    final int maxQty = tracksStock ? stockQuantity.clamp(1, 999).toInt() : 999;
    int qty = _getQuantity(item);
    if (qty < 1) qty = 1;
    if (qty > maxQty) qty = maxQty;
    final price = double.tryParse(item['price'].toString().replaceAll(',', '')) ?? 0.0;
    final controller = _qtyControllers.putIfAbsent(
        item.id, () => TextEditingController(text: '$qty'));
    final focusNode = _qtyFocusNodes.putIfAbsent(item.id, () => FocusNode());
    if (!focusNode.hasListeners) {
      focusNode.addListener(() {
        if (mounted) {
          setState(() => _isAnyFieldFocused = _qtyFocusNodes.values.any((n) => n.hasFocus));
        }
      });
    }
    if (!focusNode.hasFocus && controller.text != '$qty') controller.text = '$qty';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: (item['image_url'] ?? '').toString().isNotEmpty
              ? Image.network(item['image_url'], width: 55, height: 55, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                      width: 55, height: 55, color: Colors.grey[300],
                      child: const Icon(Icons.image_not_supported, size: 25, color: Colors.grey)))
              : Container(width: 55, height: 55, color: Colors.grey[300],
                  child: const Icon(Icons.image, size: 25, color: Colors.grey)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item['product_name'] ?? _t('គ្មានឈ្មោះ', 'Unnamed product'),
                style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('${currencyFormat.format(price)} ៛',
                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            if (tracksStock)
              Text(
                stockQuantity <= 0
                    ? 'អស់ពីស្តុក'.tr
                    : '${'នៅសល់'.tr}: $stockQuantity${stockUnit.isEmpty ? '' : ' $stockUnit'}',
                style: TextStyle(fontSize: 11,
                    color: stockQuantity <= 0 ? Colors.red : Colors.green),
              ),
            const SizedBox(height: 8),
            Row(children: [
              _qtyBtn(Icons.remove, () => _updateQuantity(item.id, qty - 1, maxQty: maxQty)),
              Container(
                width: 60,
                height: 35,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(3),
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  decoration: InputDecoration(
                    contentPadding: EdgeInsets.zero,
                    counterText: '',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(5)),
                  ),
                  onSubmitted: (value) {
                    _validateAndUpdateQty(item.id, value, controller, maxQty: maxQty);
                    _dismissKeyboard();
                  },
                  onTapOutside: (_) {
                    _validateAndUpdateQty(item.id, controller.text, controller, maxQty: maxQty);
                    _dismissKeyboard();
                  },
                  onEditingComplete: () =>
                      _validateAndUpdateQty(item.id, controller.text, controller, maxQty: maxQty),
                ),
              ),
              _qtyBtn(Icons.add, () => _updateQuantity(item.id, qty + 1, maxQty: maxQty)),
            ]),
          ]),
        ),
        Column(children: [
          Text('${currencyFormat.format(price * qty)} ៛',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.grey),
            onPressed: () {
              _qtyControllers[item.id]?.dispose();
              _qtyControllers.remove(item.id);
              _qtyFocusNodes[item.id]?.dispose();
              _qtyFocusNodes.remove(item.id);
              _debounceTimers[item.id]?.cancel();
              _debounceTimers.remove(item.id);
              _localQuantities.remove(item.id);
              item.reference.delete();
            },
          ),
        ]),
      ]),
    );
  }

  void _validateAndUpdateQty(String id, String value,
      TextEditingController controller, {int maxQty = 999}) {
    int qty = int.tryParse(value) ?? 1;
    if (qty < 1) qty = 1;
    if (qty > maxQty) qty = maxQty;
    controller.text = '$qty';
    _updateQuantity(id, qty, maxQty: maxQty);
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap) => InkWell(
        onTap: () {
          _dismissKeyboard();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Icon(icon, size: 16),
        ),
      );

  Widget _buildCheckoutButton(double total, List<QueryDocumentSnapshot> docs) => Container(
        padding: const EdgeInsets.all(20),
        color: Colors.white,
        child: SafeArea(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _isProcessingCheckout ? Colors.grey : Colors.green,
              minimumSize: const Size(double.infinity, 55),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: _isProcessingCheckout
                ? null
                : () async {
                    setState(() => _isProcessingCheckout = true);
                    try {
                      final sellerIds = docs
                          .map((d) => ((d.data() as Map<String, dynamic>)['seller_id'] ?? '').toString())
                          .where((e) => e.isNotEmpty)
                          .toSet()
                          .toList();
                      final productIds = docs
                          .map((d) => ((d.data() as Map<String, dynamic>)['product_id'] ?? '').toString())
                          .where((e) => e.isNotEmpty)
                          .toList();
                      await MarketplaceAnalyticsService.logEvent(
                        type: 'checkout_started',
                        buyerId: _currentUserId ?? FirebaseAuth.instance.currentUser?.uid ?? '',
                        sellerId: sellerIds.length == 1
                            ? sellerIds.first
                            : (sellerIds.isEmpty ? '' : 'multiple'),
                        productId: productIds.isEmpty ? '' : productIds.first,
                        sellerIds: sellerIds,
                        productIds: productIds,
                        source: 'cart',
                        totalAmount: total,
                      );
                      await _flushPendingUpdates();
                      if (!mounted) return;
                      Navigator.push(context,
                          MaterialPageRoute(builder: (_) => ReceiptScreen(cartDocs: docs)));
                    } finally {
                      if (mounted) setState(() => _isProcessingCheckout = false);
                    }
                  },
            child: _isProcessingCheckout
                ? const SizedBox(width: 22, height: 22,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                : FittedBox(
                    child: Text(
                      '${'បន្តទៅការទូទាត់'.tr} (${currencyFormat.format(total)} ៛)',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
          ),
        ),
      );

  Widget _buildEmptyCart() => Center(child: Text('មិនទាន់មានទំនិញក្នុងកន្ត្រកទេ'.tr));
  Widget _buildOrderTracking() => const SizedBox();
}
