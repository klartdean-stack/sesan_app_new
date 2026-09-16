import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'localized_text.dart';
import 'product_detail.dart';
import 'edit_product.dart';

/// Android V51-style discovery grid used by ProductListV51Screen.
/// Keeps Android V51 discovery plus owner management actions in one grid.
class ProductGridV51 extends StatefulWidget {
  const ProductGridV51({
    super.key,
    required this.category,
    this.searchQuery = '',
    this.filterProvince,
    this.filterDistrict,
    this.filterCommune,
  });

  final String category;
  final String searchQuery;
  final String? filterProvince;
  final String? filterDistrict;
  final String? filterCommune;

  @override
  State<ProductGridV51> createState() => _ProductGridV51State();
}

class _ProductGridV51State extends State<ProductGridV51> {
  bool _loading = true;
  String? _currentUserId;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _products = const [];

  bool get _hasLocation =>
      (widget.filterProvince?.isNotEmpty ?? false) ||
      (widget.filterDistrict?.isNotEmpty ?? false) ||
      (widget.filterCommune?.isNotEmpty ?? false);

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _load();
  }

  Future<void> _loadCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = FirebaseAuth.instance.currentUser?.uid ??
        prefs.getString('user_uid') ??
        prefs.getString('uid') ??
        prefs.getString('user_id');
    if (mounted) setState(() => _currentUserId = uid);
  }

  bool _isOwner(Map<String, dynamic> data) {
    final ownerId =
        (data['seller_id'] ?? data['userId'] ?? data['user_id'] ?? '').toString();
    return _currentUserId?.isNotEmpty == true && ownerId == _currentUserId;
  }

  Future<void> _toggleLock(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    Map<String, dynamic> data,
  ) async {
    await doc.reference.update({'is_locked': data['is_locked'] != true});
    await _load();
  }

  Future<void> _editStock(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    Map<String, dynamic> data,
  ) async {
    final quantity = TextEditingController(
      text: (data['stock_quantity'] ?? '').toString(),
    );
    final unit = TextEditingController(
      text: (data['stock_unit'] ?? '').toString(),
    );
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          appText(context, km: 'កែចំនួនស្តុក', en: 'Change stock'),
          style: const TextStyle(fontFamily: 'Siemreap'),
        ),
        content: Row(
          children: [
            Expanded(
              child: TextField(
                controller: quantity,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: appText(context, km: 'ចំនួន', en: 'Quantity'),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: unit,
                decoration: InputDecoration(
                  labelText: appText(context, km: 'ឯកតា', en: 'Unit'),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(appText(context, km: 'បោះបង់', en: 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(appText(context, km: 'រក្សាទុក', en: 'Save')),
          ),
        ],
      ),
    );
    if (saved != true) return;
    final value = int.tryParse(quantity.text.trim());
    if (value == null || value < 0 || unit.text.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              appText(
                context,
                km: 'សូមបញ្ចូលចំនួន និងឯកតាស្តុកត្រឹមត្រូវ',
                en: 'Enter a valid stock quantity and unit',
              ),
            ),
          ),
        );
      }
      return;
    }
    await doc.reference.update({
      'track_stock': true,
      'stock_quantity': value,
      'stock_unit': unit.text.trim(),
      'is_available': value > 0,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _load();
  }

  Future<void> _deleteProduct(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(appText(context, km: 'លុបទំនិញ?', en: 'Delete product?')),
        content: Text(
          appText(
            context,
            km: 'ទិន្នន័យនេះនឹងត្រូវលុបចេញពីបញ្ជីទំនិញ។',
            en: 'This product will be removed from the product list.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(appText(context, km: 'បោះបង់', en: 'Cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(appText(context, km: 'លុប', en: 'Delete')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await doc.reference.delete();
    await _load();
  }

  Future<void> _handleOwnerAction(
    String action,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    Map<String, dynamic> data,
  ) async {
    switch (action) {
      case 'edit':
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EditProductScreen(
              productId: doc.id,
              productData: data,
              isWanted: false,
              currentUserId: _currentUserId,
            ),
          ),
        );
        await _load();
        break;
      case 'stock':
        await _editStock(doc, data);
        break;
      case 'lock':
        await _toggleLock(doc, data);
        break;
      case 'delete':
        await _deleteProduct(doc);
        break;
    }
  }

  @override
  void didUpdateWidget(covariant ProductGridV51 oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.category != widget.category ||
        oldWidget.searchQuery != widget.searchQuery ||
        oldWidget.filterProvince != widget.filterProvince ||
        oldWidget.filterDistrict != widget.filterDistrict ||
        oldWidget.filterCommune != widget.filterCommune) {
      _load();
    }
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      Query<Map<String, dynamic>> query = FirebaseFirestore.instance.collection('products');
      final all = widget.category == 'ReadAll' || widget.category == 'ទាំងអស់';
      if (!all) query = query.where('category', isEqualTo: widget.category);
      query = query.orderBy('created_at', descending: true).limit(
        _hasLocation ? 500 : (widget.searchQuery.trim().isNotEmpty ? 200 : 100),
      );
      final snap = await query.get();
      if (mounted) setState(() => _products = snap.docs);
    } catch (e) {
      debugPrint('ProductGridV51 load error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _norm(dynamic value) => (value ?? '').toString().trim().toLowerCase();

  bool _matchesSearch(Map<String, dynamic> data) {
    final raw = widget.searchQuery.trim().toLowerCase();
    if (raw.isEmpty) return true;
    final terms = raw
        .split(RegExp(r'\s*\|\s*|\s+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet();
    if (terms.isEmpty) return true;

    final values = <String>[
      _norm(data['product_name']),
      _norm(data['productName']),
      _norm(data['category']),
      _norm(data['sub_category']),
      _norm(data['sub_sub_category']),
      _norm(data['description']),
      _norm(data['brand']),
      if (data['keywords'] is List) ...(data['keywords'] as List).map(_norm),
      if (data['tags'] is List) ...(data['tags'] as List).map(_norm),
    ];
    final haystack = values.join(' ');
    return terms.any(haystack.contains);
  }

  bool _matchesLocation(Map<String, dynamic> data) {
    if (!_hasLocation) return true;
    final location = <String>[
      _norm(data['location']),
      _norm(data['province']),
      _norm(data['district']),
      _norm(data['commune']),
      _norm(data['province_name']),
      _norm(data['district_name']),
      _norm(data['commune_name']),
    ].join(' ');

    bool has(String? value) => value == null || value.trim().isEmpty || location.contains(value.trim().toLowerCase());
    return has(widget.filterProvince) && has(widget.filterDistrict) && has(widget.filterCommune);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _products.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: Colors.green));
    }
    final visible = _products.where((doc) {
      final data = doc.data();
      return _matchesSearch(data) && _matchesLocation(data);
    }).toList();

    if (visible.isEmpty) {
      return Center(
        child: Text(
          appText(context, km: 'មិនមានទំនិញដែលអ្នករកទេ', en: 'No matching products found'),
          style: const TextStyle(fontFamily: 'Siemreap'),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      physics: const BouncingScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: MediaQuery.of(context).size.width > 800 ? 4 : 2,
        childAspectRatio: MediaQuery.of(context).size.width > 800 ? .75 : .68,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: visible.length,
      itemBuilder: (context, index) {
        final doc = visible[index];
        final data = Map<String, dynamic>.from(doc.data())..['id'] = doc.id;
        final name = (data['product_name'] ?? data['productName'] ?? '').toString();
        final price = (data['price'] ?? '0').toString();
        final location = (data['location'] ?? '').toString();
        final urls = data['image_urls'] ?? data['imageUrls'];
        final image = urls is List && urls.isNotEmpty
            ? urls.first.toString()
            : (data['image_url'] ?? data['imageUrl'] ?? '').toString();

        return InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ProductDetailScreen(product: data)),
          ),
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      image.isEmpty
                          ? Container(
                              color: Colors.grey.shade100,
                              child: const Center(
                                child: Icon(Icons.image_outlined),
                              ),
                            )
                          : CachedNetworkImage(
                              imageUrl: image,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              placeholder: (_, __) =>
                                  Container(color: Colors.grey.shade100),
                              errorWidget: (_, __, ___) => const Center(
                                child: Icon(Icons.broken_image_outlined),
                              ),
                            ),
                      if (_isOwner(data))
                        Positioned(
                          top: 5,
                          right: 5,
                          child: Material(
                            color: Colors.white.withValues(alpha: 0.92),
                            shape: const CircleBorder(),
                            child: PopupMenuButton<String>(
                              tooltip: appText(
                                context,
                                km: 'គ្រប់គ្រងទំនិញ',
                                en: 'Manage product',
                              ),
                              icon: const Icon(Icons.more_vert, size: 20),
                              onSelected: (action) =>
                                  _handleOwnerAction(action, doc, data),
                              itemBuilder: (_) => [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Text(
                                    appText(context, km: 'កែប្រែ', en: 'Edit'),
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'stock',
                                  child: Text(
                                    appText(
                                      context,
                                      km: 'កែចំនួនស្តុក',
                                      en: 'Change stock',
                                    ),
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'lock',
                                  child: Text(
                                    data['is_locked'] == true
                                        ? appText(
                                            context,
                                            km: 'បើកលក់វិញ',
                                            en: 'Unlock product',
                                          )
                                        : appText(
                                            context,
                                            km: 'ផ្អាកលក់',
                                            en: 'Lock product',
                                          ),
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text(
                                    appText(context, km: 'លុប', en: 'Delete'),
                                    style: const TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontFamily: 'Siemreap')),
                      const SizedBox(height: 4),
                      Text('$price ៛', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                      if (location.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Row(children: [
                          const Icon(Icons.location_on_outlined, size: 13, color: Colors.grey),
                          const SizedBox(width: 3),
                          Expanded(child: Text(location, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: Colors.grey))),
                        ]),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
