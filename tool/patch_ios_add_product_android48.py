from pathlib import Path

path = Path('lib/add_product.dart')
text = path.read_text(encoding='utf-8')

# Imports and localization helper.
if "package:cloud_functions/cloud_functions.dart" not in text:
    text = text.replace(
        "import 'package:cloud_firestore/cloud_firestore.dart';\n",
        "import 'package:cloud_firestore/cloud_firestore.dart';\nimport 'package:cloud_functions/cloud_functions.dart';\n",
        1,
    )
if "import 'dart:convert';" not in text:
    text = text.replace("import 'dart:io';\n", "import 'dart:convert';\nimport 'dart:io';\n", 1)
if "import 'category_localization.dart';" not in text:
    text = text.replace(
        "import 'package:video_player/video_player.dart';\n",
        "import 'package:video_player/video_player.dart';\nimport 'category_localization.dart';\n",
        1,
    )

class_marker = "class _AddProductPageState extends State<AddProductPage> {\n"
if "String _t(String km, String en)" not in text:
    helper = '''class _AddProductPageState extends State<AddProductPage> {\n  String _t(String km, String en) =>\n      Localizations.localeOf(context).languageCode == 'en' ? en : km;\n\n  String _optionLabel(String value) => localizedCategoryLabel(context, value);\n'''
    text = text.replace(class_marker, helper, 1)

# Stock controllers and AI state.
if 'stockQuantityController' not in text:
    text = text.replace(
        "  final TextEditingController priceController = TextEditingController();\n",
        "  final TextEditingController priceController = TextEditingController();\n"
        "  final TextEditingController stockQuantityController = TextEditingController();\n"
        "  final TextEditingController stockUnitController = TextEditingController();\n",
        1,
    )
if '_isAiGenerating' not in text:
    text = text.replace(
        "  bool? _shippingIncluded; // true = បូកថ្លៃផ្ញើ, false = មិនទាន់បូក\n",
        "  bool? _shippingIncluded; // true = បូកថ្លៃផ្ញើ, false = មិនទាន់បូក\n"
        "  bool _isAiGenerating = false;\n"
        "  String? _aiTitleKm;\n"
        "  String? _aiTitleEn;\n"
        "  String? _aiDescriptionKm;\n"
        "  String? _aiDescriptionEn;\n",
        1,
    )

# AI product-writing helpers.
if 'Future<void> _generateWithSesanAi()' not in text:
    marker = "  @override\n  void initState() {\n"
    methods = r'''  String _imageMimeType(XFile image) {
    final mimeType = image.mimeType?.toLowerCase();
    if (mimeType == 'image/png' || mimeType == 'image/webp' || mimeType == 'image/jpeg') {
      return mimeType!;
    }
    final name = image.name.toLowerCase();
    if (name.endsWith('.png')) return 'image/png';
    if (name.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  Future<List<String>> _buildAiImageInputs() async {
    const maxImages = 3;
    const maxImageBytes = 2500000;
    const maxTotalBytes = 6000000;
    final imageInputs = <String>[];
    var totalBytes = 0;
    for (final image in selectedImages.take(maxImages)) {
      final bytes = await image.readAsBytes();
      if (bytes.isEmpty || bytes.length > maxImageBytes) continue;
      if (totalBytes + bytes.length > maxTotalBytes) break;
      totalBytes += bytes.length;
      imageInputs.add('data:${_imageMimeType(image)};base64,${base64Encode(bytes)}');
    }
    return imageInputs;
  }

  Future<void> _generateWithSesanAi() async {
    final productName = nameController.text.trim();
    final notes = descriptionController.text.trim();
    if (selectedImages.isEmpty) {
      Get.snackbar(
        _t('សូមជ្រើសរូបទំនិញជាមុន', 'Add a product photo first'),
        _t('Sesan AI ត្រូវវិភាគរូបទំនិញជាមុន ហើយការប្រើម្តងកាត់ 3 Credits។',
            'Sesan AI must inspect a product photo first. Each use costs 3 Credits.'),
        backgroundColor: Colors.orange.shade700,
        colorText: Colors.white,
      );
      return;
    }
    setState(() => _isAiGenerating = true);
    try {
      final imageInputs = await _buildAiImageInputs();
      if (imageInputs.isEmpty) {
        throw Exception(_t('រូបធំពេកសម្រាប់ Sesan AI។ សូមជ្រើសរូបតូចជាងនេះ។',
            'The photos are too large for Sesan AI. Choose smaller photos.'));
      }
      final callable = FirebaseFunctions.instanceFor(region: 'asia-southeast1')
          .httpsCallable('generateProductAiContent');
      final response = await callable.call(<String, dynamic>{
        'productName': productName,
        'notes': notes,
        'locale': Localizations.localeOf(context).languageCode,
        'images': imageInputs,
      });
      final data = Map<String, dynamic>.from(response.data as Map);
      _aiTitleKm = (data['title_km'] ?? '').toString().trim();
      _aiTitleEn = (data['title_en'] ?? '').toString().trim();
      _aiDescriptionKm = (data['description_km'] ?? '').toString().trim();
      _aiDescriptionEn = (data['description_en'] ?? '').toString().trim();
      final suggestedCategory = (data['category'] ?? '').toString();
      final suggestedStockUnit = (data['stock_unit'] ?? '').toString().trim();
      if (!mounted) return;
      final isEnglish = Localizations.localeOf(context).languageCode == 'en';
      setState(() {
        nameController.text = isEnglish ? _aiTitleEn! : _aiTitleKm!;
        descriptionController.text = isEnglish ? _aiDescriptionEn! : _aiDescriptionKm!;
        if (categories.contains(suggestedCategory)) {
          selectedCategory = suggestedCategory;
          selectedSubCategory = null;
          selectedSubSubCategory = null;
        }
        if (suggestedStockUnit.isNotEmpty) stockUnitController.text = suggestedStockUnit;
      });
      final remainingCredits = int.tryParse((data['remainingCredits'] ?? '').toString());
      Get.snackbar(
        notes.isNotEmpty
            ? _t('Sesan AI បានកែសម្រួលរួច', 'Sesan AI improvement is ready')
            : _t('Sesan AI បានរៀបចំរួច', 'Sesan AI draft is ready'),
        remainingCredits == null
            ? _t('បានប្រើ 3 Credits។ សូមពិនិត្យមុនផុស។', '3 Credits used. Review before publishing.')
            : _t('បានប្រើ 3 Credits · នៅសល់ $remainingCredits Credits។ សូមពិនិត្យមុនផុស។',
                '3 Credits used · $remainingCredits Credits left. Review before publishing.'),
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      Get.snackbar(_t('មិនអាចប្រើ Sesan AI បាន', 'Could not use Sesan AI'),
          error.message ?? _t('សូមព្យាយាមម្ដងទៀត។', 'Please try again.'),
          backgroundColor: Colors.redAccent, colorText: Colors.white);
    } catch (error) {
      if (!mounted) return;
      Get.snackbar(_t('មានបញ្ហា', 'Something went wrong'), error.toString(),
          backgroundColor: Colors.redAccent, colorText: Colors.white);
    } finally {
      if (mounted) setState(() => _isAiGenerating = false);
    }
  }

'''
    if marker not in text:
        raise SystemExit('initState marker not found')
    text = text.replace(marker, methods + marker, 1)

# Restore stock when editing.
if "widget.initialData!['stock_quantity']" not in text:
    text = text.replace(
        "      priceController.text = widget.initialData!['price']?.toString() ?? '';\n",
        "      priceController.text = widget.initialData!['price']?.toString() ?? '';\n"
        "      stockQuantityController.text = widget.initialData!['stock_quantity']?.toString() ?? '';\n"
        "      stockUnitController.text = widget.initialData!['stock_unit']?.toString() ?? '';\n",
        1,
    )

# Dispose added controllers.
if '    stockQuantityController.dispose();' not in text:
    text = text.replace(
        "    priceController.dispose();\n",
        "    priceController.dispose();\n    stockQuantityController.dispose();\n    stockUnitController.dispose();\n",
        1,
    )

# AI button before product name.
if "AI ជួយសរសេរ" not in text:
    marker = "            const SizedBox(height: 20),\n            _buildTextField('ឈ្មោះទំនិញ *', Icons.shopping_bag, nameController),\n"
    button = '''            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: _isAiGenerating ? null : _generateWithSesanAi,
                icon: _isAiGenerating
                    ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 1.8))
                    : const Icon(Icons.auto_awesome, size: 15),
                label: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: descriptionController,
                  builder: (context, value, _) => Text(
                    _isAiGenerating
                        ? _t('AI កំពុងរៀបចំ...', 'AI is working...')
                        : value.text.trim().isNotEmpty
                            ? _t('AI កែសម្រួល', 'AI Improve')
                            : _t('AI ជួយសរសេរ', 'AI Write'),
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.deepPurple,
                  side: BorderSide(color: Colors.deepPurple.withOpacity(0.75)),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
            const SizedBox(height: 10),
            _buildTextField(_t('ឈ្មោះទំនិញ *', 'Product name *'), Icons.shopping_bag, nameController),
'''
    if marker not in text:
        raise SystemExit('product name UI marker not found')
    text = text.replace(marker, button, 1)

# Stock quantity + unit UI after price.
if "_t('ចំនួនស្តុក *', 'Stock quantity *')" not in text:
    marker = "            _buildPriceSection(),\n            const SizedBox(height: 10),\n            _buildTextField(\n              'បរិយាយទំនិញ',\n"
    replacement = """            _buildPriceSection(),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    _t('ចំនួនស្តុក *', 'Stock quantity *'),
                    Icons.inventory_2_outlined,
                    stockQuantityController,
                    isNumber: true,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: _buildStockUnitField()),
              ],
            ),
            const SizedBox(height: 10),
            _buildTextField(
              _t('បរិយាយទំនិញ', 'Product description'),
"""
    if marker not in text:
        raise SystemExit('price/description UI marker not found')
    text = text.replace(marker, replacement, 1)

# Validation includes stock.
if 'stockQuantityController.text.isEmpty' not in text:
    text = text.replace(
        "                    priceController.text.isEmpty ||\n                    phone1Controller.text.isEmpty ||",
        "                    priceController.text.isEmpty ||\n"
        "                    stockQuantityController.text.isEmpty ||\n"
        "                    stockUnitController.text.trim().isEmpty ||\n"
        "                    int.tryParse(stockQuantityController.text.trim()) == null ||\n"
        "                    int.parse(stockQuantityController.text.trim()) < 0 ||\n"
        "                    phone1Controller.text.isEmpty ||",
        1,
    )

# Save stock + bilingual AI fields.
if "'track_stock': true" not in text:
    text = text.replace(
        "                  'description': descriptionController.text.trim(),\n                  'price': priceController.text.trim(),\n",
        "                  'description': descriptionController.text.trim(),\n"
        "                  if (_aiTitleKm?.isNotEmpty == true) 'product_name_km': _aiTitleKm,\n"
        "                  if (_aiTitleEn?.isNotEmpty == true) 'product_name_en': _aiTitleEn,\n"
        "                  if (_aiDescriptionKm?.isNotEmpty == true) 'description_km': _aiDescriptionKm,\n"
        "                  if (_aiDescriptionEn?.isNotEmpty == true) 'description_en': _aiDescriptionEn,\n"
        "                  'price': priceController.text.trim(),\n"
        "                  'track_stock': true,\n"
        "                  'stock_quantity': int.parse(stockQuantityController.text.trim()),\n"
        "                  'stock_unit': stockUnitController.text.trim(),\n"
        "                  'sold_quantity': 0,\n"
        "                  'is_available': int.parse(stockQuantityController.text.trim()) > 0,\n",
        1,
    )

# Stock unit chooser and extended text field behavior.
if 'List<String> _stockUnitsForCategory()' not in text:
    marker = "  Widget _buildTextField(\n"
    helpers = '''  List<String> _stockUnitsForCategory() {
    switch (selectedCategory) {
      case 'ពូជដំណាំ': return ['ដើម', 'គ្រាប់', 'គីឡូក្រាម', 'បាច់', 'កញ្ចប់', 'បាវ'];
      case 'ពូជសត្វចិញ្ចឹម': return ['ក្បាល', 'កូន', 'គូ', 'ហ្វូង', 'គីឡូក្រាម'];
      case 'បន្លែផ្លែឈើ': return ['គីឡូក្រាម', 'តោន', 'បាវ', 'កេស', 'កញ្ចប់', 'បាច់'];
      case 'ត្រីសាច់': return ['គីឡូក្រាម', 'ក្បាល', 'កូន', 'គូ', 'ខាំ', 'ស្រះ', 'អាង', 'កញ្ចប់', 'កេស'];
      case 'ជីនិងថ្នាំ': return ['គីឡូក្រាម', 'លីត្រ', 'ដប', 'ប៊ីដុង', 'កាន', 'កញ្ចប់', 'បាវ', 'កេស'];
      case 'គ្រឿងចក្រ': return ['គ្រឿង', 'ឈុត', 'ដើម', 'ម៉ាស៊ីន', 'ដុំ', 'ទូកុងតឺន័រ'];
      case 'សម្ភារៈកសិកម្ម': return ['គ្រឿង', 'ដើម', 'គ្រាប់', 'ដុំ', 'កេស', 'ឡូ', 'ឈុត', 'ម៉ែត្រ', 'គីឡូក្រាម'];
      case 'សេវាកម្ម': return ['លើក', 'ថ្ងៃ', 'ម៉ោង', 'គម្រោង'];
      default: return ['ដុំ', 'គ្រឿង', 'ដើម', 'គ្រាប់', 'គីឡូក្រាម', 'លីត្រ', 'កញ្ចប់', 'បាវ', 'កេស', 'ឡូ', 'ឈុត'];
    }
  }

  Widget _buildStockUnitField() {
    final units = _stockUnitsForCategory();
    return TextField(
      controller: stockUnitController,
      decoration: InputDecoration(
        labelText: _t('ឯកតាស្តុក *', 'Stock unit *'),
        hintText: _t('ជ្រើសរើស ឬវាយដោយដៃ', 'Select or type'),
        prefixIcon: const Icon(Icons.straighten, color: Colors.green),
        suffixIcon: PopupMenuButton<String>(
          tooltip: _t('ជ្រើសរើសឯកតា', 'Choose unit'),
          icon: const Icon(Icons.arrow_drop_down),
          onSelected: (unit) => setState(() => stockUnitController.text = unit),
          itemBuilder: (context) => units.map((unit) => PopupMenuItem<String>(
            value: unit,
            child: Text(unit, style: const TextStyle(fontFamily: 'Siemreap')),
          )).toList(),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

'''
    if marker not in text:
        raise SystemExit('text field helper marker not found')
    text = text.replace(marker, helpers + marker, 1)

# Expand _buildTextField to support numeric stock input and multiline text.
old_sig = '''  Widget _buildTextField(
      String label,
      IconData icon,
      TextEditingController controller, {
        int maxLines = 1,
      }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
'''
if old_sig in text:
    new_sig = '''  Widget _buildTextField(
      String label,
      IconData icon,
      TextEditingController controller, {
        int minLines = 1,
        int? maxLines = 1,
        bool isNumber = false,
      }) {
    final isMultiline = !isNumber && (maxLines == null || maxLines > 1 || minLines > 1);
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : (isMultiline ? TextInputType.multiline : TextInputType.text),
      textInputAction: isMultiline ? TextInputAction.newline : TextInputAction.next,
      inputFormatters: isNumber ? [FilteringTextInputFormatter.digitsOnly] : null,
      minLines: minLines,
      maxLines: maxLines,
'''
    text = text.replace(old_sig, new_sig, 1)

# Localize category labels without changing stored Khmer values.
text = text.replace(
    ".map((c) => DropdownMenuItem(value: c, child: Text(c)))",
    ".map((c) => DropdownMenuItem(value: c, child: Text(_optionLabel(c))))",
)
text = text.replace(
    "DropdownMenuItem(value: sub, child: Text(sub))",
    "DropdownMenuItem(value: sub, child: Text(_optionLabel(sub)))",
)

path.write_text(text, encoding='utf-8')
