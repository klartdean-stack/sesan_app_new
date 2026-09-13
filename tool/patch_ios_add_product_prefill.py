from pathlib import Path

path = Path('lib/add_product.dart')
text = path.read_text(encoding='utf-8')

if 'Future<void> _prefillSellerContact()' not in text:
    marker = "  @override\n  void initState() {\n"
    method = r'''  Future<void> _prefillSellerContact() async {
    if (widget.productId != null || widget.initialData != null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = FirebaseAuth.instance.currentUser?.uid ??
          prefs.getString('user_uid');
      if (uid == null || uid.isEmpty) return;

      Map<String, dynamic>? latestProduct;
      try {
        final snapshot = await FirebaseFirestore.instance
            .collection('products')
            .where('seller_id', isEqualTo: uid)
            .orderBy('created_at', descending: true)
            .limit(1)
            .get();
        if (snapshot.docs.isNotEmpty) latestProduct = snapshot.docs.first.data();
      } catch (_) {
        final snapshot = await FirebaseFirestore.instance
            .collection('products')
            .where('seller_id', isEqualTo: uid)
            .limit(50)
            .get();
        if (snapshot.docs.isNotEmpty) {
          final docs = snapshot.docs.toList()
            ..sort((a, b) {
              final aTime = a.data()['created_at'];
              final bTime = b.data()['created_at'];
              final aMs = aTime is Timestamp ? aTime.millisecondsSinceEpoch : 0;
              final bMs = bTime is Timestamp ? bTime.millisecondsSinceEpoch : 0;
              return bMs.compareTo(aMs);
            });
          latestProduct = docs.first.data();
        }
      }

      final userSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final profile = userSnapshot.data() ?? <String, dynamic>{};

      String firstText(
        Map<String, dynamic>? primary,
        List<String> primaryKeys,
        Map<String, dynamic> fallback,
        List<String> fallbackKeys,
      ) {
        for (final key in primaryKeys) {
          final value = primary?[key]?.toString().trim() ?? '';
          if (value.isNotEmpty) return value;
        }
        for (final key in fallbackKeys) {
          final value = fallback[key]?.toString().trim() ?? '';
          if (value.isNotEmpty) return value;
        }
        return '';
      }

      final phone1 = firstText(
        latestProduct,
        const ['phone1', 'seller_phone'],
        profile,
        const ['phone1', 'phone', 'seller_phone'],
      );
      final phone2 = firstText(
        latestProduct,
        const ['phone2'],
        profile,
        const ['phone2'],
      );
      final location = firstText(
        latestProduct,
        const ['location'],
        profile,
        const ['location', 'address'],
      );
      final latValue = latestProduct?['lat'] ?? profile['lat'];
      final lngValue = latestProduct?['lng'] ?? profile['lng'];

      if (!mounted) return;
      setState(() {
        if (phone1Controller.text.trim().isEmpty && phone1.isNotEmpty) {
          phone1Controller.text = phone1;
        }
        if (phone2Controller.text.trim().isEmpty && phone2.isNotEmpty) {
          phone2Controller.text = phone2;
        }
        if (locationController.text.trim().isEmpty && location.isNotEmpty) {
          locationController.text = location;
        }
        if (selectedLat == null && latValue is num) selectedLat = latValue.toDouble();
        if (selectedLng == null && lngValue is num) selectedLng = lngValue.toDouble();
      });
    } catch (error) {
      debugPrint('Seller contact prefill failed: $error');
    }
  }

'''
    if marker not in text:
        raise SystemExit('initState marker not found')
    text = text.replace(marker, method + marker, 1)

if '_prefillSellerContact();' not in text:
    marker = "    CambodiaLocationService.load();\n"
    replacement = "    CambodiaLocationService.load();\n    if (widget.initialData == null && widget.productId == null) {\n      _prefillSellerContact();\n    }\n"
    if marker not in text:
        raise SystemExit('location load marker not found')
    text = text.replace(marker, replacement, 1)

path.write_text(text, encoding='utf-8')
