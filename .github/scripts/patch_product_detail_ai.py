from pathlib import Path

p = Path('lib/product_detail.dart')
s = p.read_text(encoding='utf-8')
original = s

def once(old, new, label):
    global s
    if new in s:
        print(f'{label}: already applied')
        return
    count = s.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected exactly 1 anchor, found {count}')
    s = s.replace(old, new, 1)
    print(f'{label}: applied')

once("import 'package:cloud_firestore/cloud_firestore.dart';\n", "import 'package:cloud_firestore/cloud_firestore.dart';\nimport 'package:cloud_functions/cloud_functions.dart';\n", 'cloud_functions import')
once("import 'product_detail_marketplace_actions.dart';\n", "import 'product_detail_marketplace_actions.dart';\nimport 'sesan_ai_assistant_screen.dart';\n", 'AI assistant import')
once("class _ProductDetailScreenState extends State<ProductDetailScreen> {\n  int _currentPage", "class _ProductDetailScreenState extends State<ProductDetailScreen> {\n  String _maskSellerPhone(dynamic value) {\n    final phone = (value ?? '').toString().trim().replaceAll(RegExp(r'\\s+'), '');\n    if (phone.isEmpty) return '';\n    if (phone.length <= 3) return 'XXX';\n    return '${phone.substring(0, phone.length - 3)}XXX';\n  }\n\n  int _currentPage", 'phone mask helper')
once("  bool _wasPaused = false; // ✅ បន្ថែម\n", "  bool _wasPaused = false; // ✅ បន្ថែម\n  bool _showTranslatedProduct = false;\n  bool _isTranslatingProduct = false;\n  String? _translatedProductName;\n  String? _translatedDescription;\n", 'translation state')

methods = r"""
  String _shownProductName(String fallback) {
    if (_showTranslatedProduct && (_translatedProductName?.trim().isNotEmpty ?? false)) return _translatedProductName!.trim();
    final value = (widget.product['product_name'] ?? '').toString().trim();
    return value.isEmpty ? fallback : value;
  }

  String _shownProductDescription(String fallback) {
    if (_showTranslatedProduct && (_translatedDescription?.trim().isNotEmpty ?? false)) return _translatedDescription!.trim();
    final value = (widget.product['description'] ?? '').toString().trim();
    return value.isEmpty ? fallback : value;
  }

  String _firstProductImage() {
    final images = widget.product['image_urls'];
    if (images is List && images.isNotEmpty) return images.first.toString();
    return (widget.product['image_url'] ?? '').toString();
  }

  Future<void> _toggleProductTranslation() async {
    if (_showTranslatedProduct) { setState(() => _showTranslatedProduct = false); return; }
    if (_translatedProductName != null || _translatedDescription != null) { setState(() => _showTranslatedProduct = true); return; }
    if (_isTranslatingProduct) return;
    setState(() => _isTranslatingProduct = true);
    final locale = Localizations.localeOf(context).languageCode == 'en' ? 'en' : 'km';
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'asia-southeast1').httpsCallable('generateProductAiContent');
      final result = await callable.call(<String, dynamic>{
        'productName': (widget.product['product_name'] ?? '').toString(),
        'notes': (widget.product['description'] ?? '').toString(),
        'locale': locale,
        'images': const <String>[],
      });
      final data = Map<String, dynamic>.from(result.data as Map);
      if (!mounted) return;
      setState(() {
        _translatedProductName = (data[locale == 'en' ? 'title_en' : 'title_km'] ?? '').toString();
        _translatedDescription = (data[locale == 'en' ? 'description_en' : 'description_km'] ?? '').toString();
        _showTranslatedProduct = true;
      });
    } catch (error) {
      debugPrint('Product translation error: $error');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
        Localizations.localeOf(context).languageCode == 'en'
          ? 'Could not translate this product. Please try again.'
          : 'មិនអាចបកប្រែទំនិញនេះបានទេ សូមសាកម្ដងទៀត។')));
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
    final seller = (widget.product['seller_name'] ?? widget.product['shop_name'] ?? widget.product['seller_id'] ?? '').toString();
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
    Navigator.push(context, MaterialPageRoute(builder: (_) => SesanAiAssistantScreen(
      initialPrompt: prompt, initialRole: 'agriculture', initialImageUrl: _firstProductImage())));
  }

"""
once("  // ── Screenshot Controller", methods + "  // ── Screenshot Controller", 'AI/translate methods')
once('"ទំនាក់ទំនង៖ $sellerPhone",', '"ទំនាក់ទំនង៖ ${_maskSellerPhone(sellerPhone)}",', 'watermark phone masking')

old_title = """                        Text(
                          widget.product['product_name'] ?? 'គ្មានឈ្មោះ',
                          style: const TextStyle(
                            fontSize: 22,"""
new_title = """                        Text(
                          _shownProductName('គ្មានឈ្មោះ'),
                          style: const TextStyle(
                            fontSize: 22,"""
once(old_title, new_title, 'translated product title')

old_desc = """                        Text(
                          widget.product['description'] ?? 'មិនមានការពិពណ៌នា...',
                          style: const TextStyle(fontSize: 16),
                        ),"""
new_desc = """                        Text(
                          _shownProductDescription('មិនមានការពិពណ៌នា...'),
                          style: const TextStyle(fontSize: 16),
                        ),"""
once(old_desc, new_desc, 'translated product description')

translate_ui = r"""
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: OutlinedButton.icon(
                            onPressed: _isTranslatingProduct ? null : _toggleProductTranslation,
                            icon: _isTranslatingProduct
                                ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2))
                                : Icon(_showTranslatedProduct ? Icons.undo_rounded : Icons.translate_rounded),
                            label: Text(_showTranslatedProduct
                                ? (Localizations.localeOf(context).languageCode == 'en' ? 'Original' : 'អត្ថបទដើម')
                                : (Localizations.localeOf(context).languageCode == 'en' ? 'Translate Product' : 'បកប្រែទំនិញ')),
                          ),
                        ),
"""
once("                        // ✅ បន្ថែមពីទីនេះ - បង្ហាញ Category និង Sub Category\n", translate_ui + "\n                        // ✅ បន្ថែមពីទីនេះ - បង្ហាញ Category និង Sub Category\n", 'translate UI')

ask_ai_ui = r"""
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _openProductAssistant,
                            icon: const Icon(Icons.auto_awesome_rounded),
                            label: Text(Localizations.localeOf(context).languageCode == 'en'
                                ? 'Ask Sesan AI about this product'
                                : 'សួរ Sesan AI អំពីទំនិញនេះ'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.green.shade700,
                              side: BorderSide(color: Colors.green.shade300),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
"""
once("\n\n                        // --- ផ្នែកព័ត៌មានអ្នកលក់", "\n" + ask_ai_ui + "\n                        // --- ផ្នែកព័ត៌មានអ្នកលក់", 'Ask AI UI')

if s == original:
    print('No changes needed')
else:
    p.write_text(s, encoding='utf-8')
    print('Product Detail parity patch complete')
