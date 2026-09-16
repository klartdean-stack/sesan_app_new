from pathlib import Path

p = Path('lib/product_list.dart')
s = p.read_text(encoding='utf-8')

# Dependencies used by Android V51 stock/cart controls.
if "import 'package:intl/intl.dart';" not in s:
    s = s.replace("import 'package:cached_network_image/cached_network_image.dart';", "import 'package:cached_network_image/cached_network_image.dart';\nimport 'package:intl/intl.dart';", 1)
if "import 'marketplace_analytics_service.dart';" not in s:
    s = s.replace("import 'localized_text.dart';", "import 'localized_text.dart';\nimport 'marketplace_analytics_service.dart';", 1)

# Live cart and stock state.
if '_cartSubscription' not in s:
    s = s.replace(
        "  String? _currentUserId;\n",
        "  String? _currentUserId;\n  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _cartSubscription;\n  final Set<String> _cartProductIds = <String>{};\n  final Set<String> _cartAddingIds = <String>{};\n  final Map<String, int> _stockQuantityOverrides = <String, int>{};\n  final Set<String> _stockUpdatingIds = <String>{};\n",
        1,
    )

# Start live cart listener after user id is known.
if '    _listenToCart();' not in s:
    marker = '    // ✅ Clear តែពេលចូលមកដំបូង'
    if marker not in s:
        raise SystemExit('init clear marker not found')
    s = s.replace(marker, '    _listenToCart();\n\n' + marker, 1)

# Live cart listener.
if '  void _listenToCart() {' not in s:
    marker = '  void _onScroll() {'
    listener = r'''  void _listenToCart() {
    _cartSubscription?.cancel();
    final uid = _currentUserId;
    if (uid == null || uid.isEmpty) return;

    _cartSubscription = FirebaseFirestore.instance
        .collection('carts')
        .where('customer_id', isEqualTo: uid)
        .snapshots()
        .listen((snapshot) {
      final ids = snapshot.docs
          .map((doc) => (doc.data()['product_id'] ?? '').toString())
          .where((id) => id.isNotEmpty)
          .toSet();
      if (!mounted) return;
      setState(() {
        _cartProductIds
          ..clear()
          ..addAll(ids);
        _cartAddingIds.removeWhere(ids.contains);
      });
    }, onError: (error) {
      debugPrint('Cart state listener error: $error');
    });
  }

'''
    if marker not in s:
        raise SystemExit('onScroll marker not found')
    s = s.replace(marker, listener + marker, 1)

# Stock helpers before Product Card.
if '  int _stockQuantityValue(dynamic value) {' not in s:
    marker = '  // ── PRODUCT CARD'
    if marker not in s:
        raise SystemExit('Product card marker not found')
    helpers = r'''  int _stockQuantityValue(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString().replaceAll(',', '').trim() ?? '') ?? 0;
  }

  Future<void> _changeProductStock(
    String productId,
    Map<String, dynamic> data,
    int delta,
  ) async {
    if (_stockUpdatingIds.contains(productId)) return;
    final previous = _stockQuantityOverrides[productId] ??
        _stockQuantityValue(data['stock_quantity']);
    final optimistic = (previous + delta).clamp(0, 999999999).toInt();
    setState(() {
      _stockQuantityOverrides[productId] = optimistic;
      _stockUpdatingIds.add(productId);
    });

    final ref = FirebaseFirestore.instance.collection('products').doc(productId);
    try {
      final newQuantity = await FirebaseFirestore.instance.runTransaction<int>((transaction) async {
        final snapshot = await transaction.get(ref);
        final latest = snapshot.data() ?? <String, dynamic>{};
        final current = _stockQuantityValue(latest['stock_quantity']);
        final next = (current + delta).clamp(0, 999999999).toInt();
        transaction.update(ref, {
          'track_stock': true,
          'stock_quantity': next,
          'is_available': next > 0,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return next;
      });
      if (!mounted) return;
      setState(() {
        _stockQuantityOverrides[productId] = newQuantity;
        _stockUpdatingIds.remove(productId);
        data['track_stock'] = true;
        data['stock_quantity'] = newQuantity;
        data['is_available'] = newQuantity > 0;
      });
    } catch (e) {
      debugPrint('Change product stock error: $e');
      if (!mounted) return;
      setState(() {
        _stockQuantityOverrides[productId] = previous;
        _stockUpdatingIds.remove(productId);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(appText(context, km: 'មិនអាចកែចំនួនស្តុកបានទេ', en: 'Could not update stock quantity.')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _applyBulkStockChange(
    String productId,
    Map<String, dynamic> data,
    String mode,
    int amount,
  ) async {
    if (_stockUpdatingIds.contains(productId)) return;
    final previous = _stockQuantityOverrides[productId] ??
        _stockQuantityValue(data['stock_quantity']);
    final optimistic = mode == 'add'
        ? previous + amount
        : mode == 'deduct'
            ? (previous - amount).clamp(0, previous).toInt()
            : amount;
    setState(() {
      _stockQuantityOverrides[productId] = optimistic;
      _stockUpdatingIds.add(productId);
    });

    final ref = FirebaseFirestore.instance.collection('products').doc(productId);
    try {
      final newQuantity = await FirebaseFirestore.instance.runTransaction<int>((transaction) async {
        final snapshot = await transaction.get(ref);
        final latest = snapshot.data() ?? <String, dynamic>{};
        final current = _stockQuantityValue(latest['stock_quantity']);
        late final int next;
        if (mode == 'add') {
          next = current + amount;
        } else if (mode == 'deduct') {
          if (amount > current) throw StateError('insufficient_stock');
          next = current - amount;
        } else {
          next = amount;
        }
        transaction.update(ref, {
          'track_stock': true,
          'stock_quantity': next,
          'is_available': next > 0,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return next;
      });
      if (!mounted) return;
      setState(() {
        _stockQuantityOverrides[productId] = newQuantity;
        _stockUpdatingIds.remove(productId);
        data['track_stock'] = true;
        data['stock_quantity'] = newQuantity;
        data['is_available'] = newQuantity > 0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(appText(context, km: 'បានកែចំនួនស្តុករួចរាល់', en: 'Stock updated')),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final insufficient = e.toString().contains('insufficient_stock');
      setState(() {
        _stockQuantityOverrides[productId] = previous;
        _stockUpdatingIds.remove(productId);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(insufficient
              ? appText(context, km: 'មិនអាចកាត់លើសចំនួនស្តុកបានទេ', en: 'Cannot deduct more than the available stock.')
              : appText(context, km: 'មិនអាចកែចំនួនស្តុកបានទេ', en: 'Could not update stock quantity.')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showBulkStockDialog(
    String productId,
    Map<String, dynamic> data,
  ) async {
    final current = _stockQuantityOverrides[productId] ??
        _stockQuantityValue(data['stock_quantity']);
    final amountController = TextEditingController();
    var mode = 'deduct';
    var amount = 0;
    String? errorText;
    final formatter = NumberFormat('#,###');

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final preview = mode == 'add'
              ? current + amount
              : mode == 'deduct'
                  ? (current - amount).clamp(0, current)
                  : amount;
          return AlertDialog(
            title: Text(appText(context, km: 'កែចំនួនស្តុក', en: 'Adjust stock'), style: const TextStyle(fontFamily: 'Siemreap')),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${appText(context, km: 'ស្តុកបច្ចុប្បន្ន', en: 'Current stock')}: ${formatter.format(current)}',
                    style: const TextStyle(fontFamily: 'Siemreap', fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      ChoiceChip(label: Text(appText(context, km: 'កាត់', en: 'Deduct')), selected: mode == 'deduct', onSelected: (_) => setDialogState(() { mode = 'deduct'; errorText = null; })),
                      ChoiceChip(label: Text(appText(context, km: 'បន្ថែម', en: 'Add')), selected: mode == 'add', onSelected: (_) => setDialogState(() { mode = 'add'; errorText = null; })),
                      ChoiceChip(label: Text(appText(context, km: 'កំណត់សល់', en: 'Set remaining')), selected: mode == 'set', onSelected: (_) => setDialogState(() { mode = 'set'; errorText = null; })),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountController,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    onChanged: (value) => setDialogState(() {
                      amount = int.tryParse(value.trim()) ?? 0;
                      errorText = null;
                    }),
                    decoration: InputDecoration(
                      labelText: appText(context, km: 'បញ្ចូលចំនួន', en: 'Enter quantity'),
                      errorText: errorText,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(10)),
                    child: Text(
                      mode == 'deduct'
                          ? '${formatter.format(current)} − ${formatter.format(amount)} = ${formatter.format(preview)}'
                          : mode == 'add'
                              ? '${formatter.format(current)} + ${formatter.format(amount)} = ${formatter.format(preview)}'
                              : '${appText(context, km: 'ស្តុកថ្មី', en: 'New stock')}: ${formatter.format(preview)}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(appText(context, km: 'បោះបង់', en: 'Cancel'))),
              ElevatedButton(
                onPressed: amountController.text.trim().isEmpty
                    ? null
                    : () {
                        if (mode == 'deduct' && amount > current) {
                          setDialogState(() => errorText = appText(context, km: 'ចំនួនលើសស្តុកបច្ចុប្បន្ន', en: 'Amount exceeds current stock'));
                          return;
                        }
                        Navigator.pop(dialogContext, {'mode': mode, 'amount': amount});
                      },
                child: Text(appText(context, km: 'រក្សាទុក', en: 'Save')),
              ),
            ],
          );
        },
      ),
    );
    if (result == null) return;
    await _applyBulkStockChange(productId, data, result['mode'] as String, result['amount'] as int);
  }

  Future<void> _setInitialProductStock(
    String productId,
    Map<String, dynamic> data,
  ) async {
    final quantityController = TextEditingController();
    final unitController = TextEditingController(text: (data['stock_unit'] ?? '').toString());
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(appText(context, km: 'កំណត់ស្តុក', en: 'Set stock'), style: const TextStyle(fontFamily: 'Siemreap')),
        content: Row(
          children: [
            Expanded(child: TextField(controller: quantityController, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: appText(context, km: 'ចំនួន', en: 'Quantity')))),
            const SizedBox(width: 10),
            Expanded(child: TextField(controller: unitController, decoration: InputDecoration(labelText: appText(context, km: 'ឯកតា', en: 'Unit'), hintText: appText(context, km: 'ដើម/គីឡូ', en: 'item/kg')))),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(appText(context, km: 'បោះបង់', en: 'Cancel'))),
          ElevatedButton(
            onPressed: () {
              final quantity = int.tryParse(quantityController.text.trim());
              if (quantity == null || quantity < 0) return;
              Navigator.pop(dialogContext, {'quantity': quantity, 'unit': unitController.text.trim()});
            },
            child: Text(appText(context, km: 'រក្សាទុក', en: 'Save')),
          ),
        ],
      ),
    );
    if (result == null) return;
    final quantity = result['quantity'] as int;
    final unit = result['unit'] as String;
    try {
      await FirebaseFirestore.instance.collection('products').doc(productId).update({
        'track_stock': true,
        'stock_quantity': quantity,
        'stock_unit': unit,
        'is_available': quantity > 0,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      setState(() {
        _stockQuantityOverrides[productId] = quantity;
        data['track_stock'] = true;
        data['stock_quantity'] = quantity;
        data['stock_unit'] = unit;
        data['is_available'] = quantity > 0;
      });
    } catch (e) {
      debugPrint('Set initial stock error: $e');
    }
  }

  Widget _buildInlineStockControl(String productId, Map<String, dynamic> data) {
    final tracksStock = _stockQuantityOverrides.containsKey(productId) ||
        data['track_stock'] == true ||
        data['stock_quantity'] != null;
    if (!tracksStock) {
      return SizedBox(
        width: double.infinity,
        height: 30,
        child: OutlinedButton.icon(
          onPressed: () => _setInitialProductStock(productId, data),
          icon: const Icon(Icons.inventory_2_outlined, size: 15),
          label: Text(appText(context, km: 'កំណត់ស្តុក', en: 'Set stock'), style: const TextStyle(fontFamily: 'Siemreap', fontSize: 10)),
          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 6), foregroundColor: Colors.green.shade700, side: BorderSide(color: Colors.green.shade200)),
        ),
      );
    }
    final quantity = _stockQuantityOverrides[productId] ?? _stockQuantityValue(data['stock_quantity']);
    final isUpdating = _stockUpdatingIds.contains(productId);
    Widget stockButton(IconData icon, VoidCallback? onPressed) => GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: onPressed == null ? Colors.grey.shade100 : Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 17, color: onPressed == null ? Colors.grey : Colors.green.shade700),
      ),
    );
    return Row(
      children: [
        stockButton(Icons.remove, quantity > 0 && !isUpdating ? () => _changeProductStock(productId, data, -1) : null),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: isUpdating ? null : () => _showBulkStockDialog(productId, data),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(child: Text('${appText(context, km: 'ស្តុក', en: 'Stock')}: ${NumberFormat('#,###').format(quantity)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: 'Siemreap', fontSize: 10, fontWeight: FontWeight.bold, color: quantity == 0 ? Colors.red : Colors.black87))),
                  const SizedBox(width: 3),
                  const Icon(Icons.edit_outlined, size: 12, color: Colors.grey),
                ],
              ),
            ),
          ),
        ),
        stockButton(Icons.add, isUpdating ? null : () => _changeProductStock(productId, data, 1)),
      ],
    );
  }

'''
    s = s.replace(marker, helpers + marker, 1)

# Product card live cart button needs document id.
s = s.replace(
    '''_buildCartButton(
                                  data,
                                  currentLockStatus,
                                  shippingIncluded,
                                )''',
    '''_buildCartButton(
                                  data,
                                  docId,
                                  currentLockStatus,
                                  shippingIncluded,
                                )''',
    1,
)

# Add inline stock control below the price/cart row for sale posts in Manage Posts.
if '_buildInlineStockControl(docId, data)' not in s:
    needle = '''                          ),
                        ],
                      ),
                    ),

                  ],'''
    replacement = '''                          ),
                        ],
                      ),
                      if (widget.category == 'ទំនិញរបស់ខ្ញុំ' && postType == 'sale') ...[
                        const SizedBox(height: 6),
                        _buildInlineStockControl(docId, data),
                      ],
                    ),

                  ],'''
    if needle not in s:
        raise SystemExit('Product card row insertion point not found')
    s = s.replace(needle, replacement, 1)

# Replace legacy cart button block.
cart_start = s.index('  // ── CART BUTTON')
cart_end = s.index('  // ── LOCK SWITCH', cart_start)
cart_block = r'''  // ── CART BUTTON ─────────────────────────────────────────
  Widget _buildCartButton(
    Map<String, dynamic> data,
    String docId,
    bool isLocked,
    bool? shippingIncluded,
  ) {
    final disabled = isLocked || data['shop_closed'] == true || shippingIncluded == false;
    final alreadyInCart = _cartProductIds.contains(docId);
    final isAdding = _cartAddingIds.contains(docId);
    return GestureDetector(
      onTap: isAdding
          ? null
          : alreadyInCart
              ? () => _removeFromCart(docId)
              : disabled
                  ? null
                  : () => _fastAddToCart(data, docId),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: alreadyInCart
              ? Colors.green.shade100
              : disabled
                  ? Colors.grey[200]
                  : Colors.green[50],
          borderRadius: BorderRadius.circular(8),
        ),
        child: isAdding
            ? const SizedBox(
                width: 22,
                height: 22,
                child: Padding(
                  padding: EdgeInsets.all(3),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : Icon(
                alreadyInCart ? Icons.check_circle : Icons.add_shopping_cart,
                color: alreadyInCart
                    ? Colors.green.shade700
                    : disabled
                        ? Colors.grey
                        : Colors.green,
                size: 22,
              ),
      ),
    );
  }


'''
s = s[:cart_start] + cart_block + s[cart_end:]

# Replace legacy add-to-cart section with duplicate-safe add/remove.
add_start = s.index('  // ── ADD TO CART')
add_end = s.index('  // ── FORMAT TIME AGO', add_start)
add_block = r'''  // ── ADD TO CART ─────────────────────────────────────────
  Future<void> _fastAddToCart(
    Map<String, dynamic> product,
    String productId,
  ) async {
    if (_currentUserId == null || productId.isEmpty) return;
    if (_cartProductIds.contains(productId) || _cartAddingIds.contains(productId)) return;
    if (mounted) setState(() => _cartAddingIds.add(productId));

    final urls = product['image_urls'] ?? product['imageUrls'];
    final String finalImageUrl = product['image_url']?.toString() ??
        (urls is List && urls.isNotEmpty ? urls.first.toString() : '');
    try {
      final existing = await FirebaseFirestore.instance
          .collection('carts')
          .where('customer_id', isEqualTo: _currentUserId)
          .get();
      final alreadyExists = existing.docs.any(
        (doc) => (doc.data()['product_id'] ?? '').toString() == productId,
      );
      if (alreadyExists) {
        if (mounted) {
          setState(() {
            _cartProductIds.add(productId);
            _cartAddingIds.remove(productId);
          });
        }
        return;
      }

      await FirebaseFirestore.instance.collection('carts').add({
        'product_id': productId,
        'product_name': product['product_name'] ?? 'គ្មានឈ្មោះ',
        'price': product['price'] ?? 0,
        'currency': product['currency'] ?? '៛',
        'image_url': finalImageUrl,
        'quantity': 1,
        'customer_id': _currentUserId,
        'created_at': FieldValue.serverTimestamp(),
        'seller_id': product['seller_id'] ?? '',
        'seller_name': product['seller_name'] ?? 'អាជីវករ សេសាន',
        'seller_phone': product['seller_phone'] ?? product['phone1'] ?? '',
        'seller_photo': product['seller_photo'] ?? '',
      });
      if (mounted) {
        setState(() {
          _cartProductIds.add(productId);
          _cartAddingIds.remove(productId);
        });
      }
      await MarketplaceAnalyticsService.logEvent(
        type: 'add_to_cart',
        buyerId: _currentUserId ?? FirebaseAuth.instance.currentUser?.uid ?? '',
        sellerId: (product['seller_id'] ?? '').toString(),
        productId: productId,
        source: 'product_card',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(appText(context, km: '✅ បន្ថែមទៅកន្ត្រករួចរាល់!', en: '✅ Added to cart!')),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _cartAddingIds.remove(productId));
      debugPrint('Add to Cart Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${appText(context, km: '❌ បរាជ័យ', en: '❌ Failed')}: $e')),
        );
      }
    }
  }

  Future<void> _removeFromCart(String productId) async {
    final uid = _currentUserId;
    if (uid == null || uid.isEmpty || productId.isEmpty || _cartAddingIds.contains(productId)) return;
    if (mounted) setState(() => _cartAddingIds.add(productId));
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('carts')
          .where('customer_id', isEqualTo: uid)
          .get();
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
        setState(() {
          _cartProductIds.remove(productId);
          _cartAddingIds.remove(productId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(appText(context, km: '↩️ បានដកចេញពីកន្ត្រក', en: '↩️ Removed from cart')),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _cartAddingIds.remove(productId));
      debugPrint('Remove from cart error: $e');
    }
  }


'''
s = s[:add_start] + add_block + s[add_end:]

# Cancel listener on dispose.
if '    _cartSubscription?.cancel();' not in s[s.rfind('  @override\n  void dispose()'):]:
    s = s.replace(
        '''  @override
  void dispose() {
    _scrollController.dispose();''',
        '''  @override
  void dispose() {
    _cartSubscription?.cancel();
    _scrollController.dispose();''',
        1,
    )

required = [
    "import 'package:intl/intl.dart';",
    "import 'marketplace_analytics_service.dart';",
    '_cartSubscription',
    '_cartProductIds',
    '_stockQuantityOverrides',
    'void _listenToCart()',
    'Future<void> _showBulkStockDialog(',
    'Widget _buildInlineStockControl(',
    '_buildInlineStockControl(docId, data)',
    'alreadyInCart ? Icons.check_circle',
    'Future<void> _removeFromCart(String productId)',
    "type: 'add_to_cart'",
    '_cartSubscription?.cancel();',
]
for token in required:
    if token not in s:
        raise SystemExit(f'Missing stock/cart parity token: {token}')

p.write_text(s, encoding='utf-8')
