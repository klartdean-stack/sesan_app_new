import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'localized_text.dart';
import 'product_detail.dart';

/// Android V51-style discovery grid used by ProductListV51Screen.
/// It intentionally keeps discovery read-only; product detail owns cart/actions.
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
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _products = const [];

  bool get _hasLocation =>
      (widget.filterProvince?.isNotEmpty ?? false) ||
      (widget.filterDistrict?.isNotEmpty ?? false) ||
      (widget.filterCommune?.isNotEmpty ?? false);

  @override
  void initState() {
    super.initState();
    _load();
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
                  child: image.isEmpty
                      ? Container(color: Colors.grey.shade100, child: const Center(child: Icon(Icons.image_outlined)))
                      : CachedNetworkImage(
                          imageUrl: image,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(color: Colors.grey.shade100),
                          errorWidget: (_, __, ___) => const Center(child: Icon(Icons.broken_image_outlined)),
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
