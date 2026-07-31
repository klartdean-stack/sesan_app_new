import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:my_app/order_history_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'receipt_screen.dart';
import 'package:intl/intl.dart';
import 'order_tracking_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {

  @override
  bool get wantKeepAlive => true;
  bool _isProcessingCheckout = false;
  bool _isAnyFieldFocused = false;
  final NumberFormat currencyFormat = NumberFormat("#,###", "en_US");
  String? _currentUserId;
  bool _isLoadingUserId = true;

  final Map<String, TextEditingController> _qtyControllers = {};
  final Map<String, FocusNode> _qtyFocusNodes = {};

  // 🎯 Local optimistic quantities
  final Map<String, int> _localQuantities = {};

  // 🎯 Debounce timers for Firestore writes
  final Map<String, Timer> _debounceTimers = {};
  static const _debounceMs = 500; // 500ms debounce

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
    for (var controller in _qtyControllers.values) {
      controller.dispose();
    }
    for (var node in _qtyFocusNodes.values) {
      node.dispose();
    }
    for (var timer in _debounceTimers.values) {
      timer.cancel();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {}

  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _currentUserId = prefs.getString('user_uid');
        _isLoadingUserId = false;
      });
    }
  }

  // 🎯 Hybrid: Local optimistic + debounced Firestore
  void _updateQuantity(String docId, int newQty) {
    if (newQty < 1) newQty = 1;
    if (newQty > 999) newQty = 999;

    // 1. Update local immediately (optimistic)
    setState(() {
      _localQuantities[docId] = newQty;
    });

    // 2. Cancel previous timer for this doc
    _debounceTimers[docId]?.cancel();

    // 3. Debounce Firestore write
    _debounceTimers[docId] = Timer(
      const Duration(milliseconds: _debounceMs),
      () {
        FirebaseFirestore.instance.collection('carts').doc(docId).update({
          'quantity': newQty,
        }).catchError((e) {
          // On error: revert to last known Firestore value
          debugPrint("Firestore update failed: \$e");
        });
      },
    );
  }

  // 🎯 Force immediate Firestore write (for checkout)
  Future<void> _flushPendingUpdates() async {
    final futures = <Future>[];
    for (var entry in _debounceTimers.entries) {
      entry.value.cancel();
      final docId = entry.key;
      final qty = _localQuantities[docId];
      if (qty != null) {
        futures.add(
          FirebaseFirestore.instance.collection('carts').doc(docId).update({
            'quantity': qty,
          }),
        );
      }
    }
    _debounceTimers.clear();
    if (futures.isNotEmpty) {
      await Future.wait(futures);
    }
  }

  int _getQuantity(QueryDocumentSnapshot item) {
    if (_localQuantities.containsKey(item.id)) {
      return _localQuantities[item.id]!;
    }
    return int.tryParse(item['quantity']?.toString() ?? '1') ?? 1;
  }

  double _calculateTotal(List<QueryDocumentSnapshot> docs) {
    return docs.fold(0.0, (sum, doc) {
      double price = double.tryParse(
              doc['price'].toString().replaceAll(',', '')) ??
          0;
      int qty = _getQuantity(doc);
      return sum + (price * qty);
    });
  }

  void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
  }@override
  Widget build(BuildContext context) {
    super.build(context);

    return GestureDetector(
      onTap: _dismissKeyboard,
      behavior: HitTestBehavior.translucent,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F7),
        appBar: AppBar(
          title: const Text(
            "កន្ត្រករបស់ខ្ញុំ",
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
          backgroundColor: Colors.green,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(
                Icons.history_rounded,
                size: 28,
                color: Colors.white,
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const OrderHistoryScreen(),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.local_shipping_rounded, color: Colors.white),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const OrderTrackingScreen(),
                  ),
                );
              },
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Column(
          children: [
            _buildOrderTracking(),
            Expanded(
              child: _isLoadingUserId
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.green),
                    )
                  : _currentUserId == null
                      ? const Center(
                          child: Text(
                            "មិនអាចទាញព័ត៌មានអ្នកប្រើបាន",
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('carts')
                              .where('customer_id', isEqualTo: _currentUserId)
                              .orderBy('created_at', descending: true)
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                    ConnectionState.waiting &&
                                _cachedDocs != null) {
                              return _buildCartContent(_cachedDocs!, _cachedTotal);
                            }

                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(
                                    color: Colors.green),
                              );
                            }

                            if (!snapshot.hasData ||
                                snapshot.data!.docs.isEmpty) {
                              _cachedDocs = null;
                              _cachedTotal = 0.0;
                              _localQuantities.clear();
                              _debounceTimers.forEach((_, t) => t.cancel());
                              _debounceTimers.clear();
                              return _buildEmptyCart();
                            }

                            var docs = snapshot.data!.docs;

                            for (var doc in docs) {
                              if (!_localQuantities.containsKey(doc.id)) {
                                int firestoreQty = int.tryParse(
                                        doc['quantity']?.toString() ?? '1') ??1;
                                _localQuantities[doc.id] = firestoreQty;
                              }
                            }

                            _localQuantities.removeWhere(
                                (id, _) => !docs.any((d) => d.id == id));
                            _debounceTimers.removeWhere(
                                (id, _) => !docs.any((d) => d.id == id));

                            double total = _calculateTotal(docs);

                            _cachedDocs = docs;
                            _cachedTotal = total;

                            return _buildCartContent(docs, total);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartContent(List<QueryDocumentSnapshot> docs, double total) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: docs.length,
            itemBuilder: (context, index) => _buildModernCartItem(docs[index]),
          ),
        ),
        if (!_isAnyFieldFocused) _buildCheckoutButton(total, docs),
      ],
    );
  }

  Widget _buildModernCartItem(QueryDocumentSnapshot item) {
    int qty = _getQuantity(item);
    double price =
        double.tryParse(item['price'].toString().replaceAll(',', '')) ?? 0;

    final controller = _qtyControllers.putIfAbsent(
      item.id,
      () => TextEditingController(text: "$qty"),
    );

    final focusNode = _qtyFocusNodes.putIfAbsent(
      item.id,
      () => FocusNode(),
    );
    if (!focusNode.hasListeners) {
      focusNode.addListener(() {
        if (mounted) {
          setState(() {
            _isAnyFieldFocused = _qtyFocusNodes.values.any((n) => n.hasFocus);
          });
        }
      });
    }
    if (!focusNode.hasFocus && controller.text != "$qty") {
      controller.text = "$qty";
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: item['image_url'] != null && item['image_url'] != ""
                ? Image.network(
                    item['image_url'],
                    width: 55,
                    height: 55,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 55,
                      height: 55,
                      color: Colors.grey[300],
                      child: const Icon(
                        Icons.image_not_supported,
                        size: 25,
                        color: Colors.grey,
                      ),
                    ),
                  )
                : Container(
                    width: 55,
                    height: 55,
                    color: Colors.grey[300],
                    child: const Icon(
                      Icons.image,
                      size: 25,
                      color: Colors.grey,
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['product_name'] ?? 'គ្មានឈ្មោះ',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  "${currencyFormat.format(price)} ៛",
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _qtyBtn(
                      Icons.remove,
                      () => _updateQuantity(item.id, qty - 1),
                    ),
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
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: InputDecoration(
                          contentPadding: EdgeInsets.zero,
                          counterText: "",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                        onSubmitted: (value) {
                          _validateAndUpdateQty(item.id, value, controller);
                          _dismissKeyboard();
                        },
                        onTapOutside: (_) {
                          _validateAndUpdateQty(
                              item.id, controller.text, controller);
                          _dismissKeyboard();
                        },
                        onEditingComplete: () {
                          _validateAndUpdateQty(
                              item.id, controller.text, controller);
                        },
                      ),
                    ),
                    _qtyBtn(Icons.add, () => _updateQuantity(item.id, qty + 1)),
                  ],
                ),
              ],
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "${currencyFormat.format(price * qty)} ៛",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
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
            ],
          ),
        ],
      ),
    );
  }

  void _validateAndUpdateQty(
      String docId, String value, TextEditingController controller) {
    if (value.isEmpty || value == "0") {
      controller.text = "1";
      _updateQuantity(docId, 1);
    } else {
      int? newQty = int.tryParse(value);
      if (newQty != null) {
        if (newQty > 999) newQty = 999;
        if (newQty < 1) newQty = 1;
        controller.text = "$newQty";
        _updateQuantity(docId, newQty);
      }
    }
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: () {_dismissKeyboard();
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
  }

  Widget _buildCheckoutButton(double total, List<QueryDocumentSnapshot> docs) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _isProcessingCheckout ? Colors.grey : Colors.green,
            minimumSize: const Size(double.infinity, 55),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
          // បិទការចុចបើកំពុងដំណើរការ
          onPressed: _isProcessingCheckout
              ? null
              : () async {
            setState(() => _isProcessingCheckout = true);
            _dismissKeyboard();
            await _flushPendingUpdates();
            if (mounted) {
              setState(() => _isProcessingCheckout = false);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ReceiptScreen(cartDocs: docs),
                ),
              );
            }
          },
          child: _isProcessingCheckout
              ? const SizedBox(
            height: 24,
            width: 24,
            child: CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2.5,
            ),
          )
              : Text(
            "បន្តទៅការទូទាត់ (${currencyFormat.format(total)} ៛)",
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyCart() {
    return const Center(
      child: Text(
        "មិនទាន់មានទំនិញក្នុងកន្ត្រកទេ",
        style: TextStyle(color: Colors.grey),
      ),
    );
  }

  Widget _buildOrderTracking() {
    return const SizedBox();
  }
}