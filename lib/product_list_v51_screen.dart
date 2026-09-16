import 'package:flutter/material.dart';
import 'package:my_app/qr_scanner_screen.dart';
import 'category_localization.dart';
import 'localized_text.dart';
import 'location_picker.dart';
import 'product_grid_v51.dart';
import 'product_search_v51.dart';

class ProductListV51Screen extends StatefulWidget {
  const ProductListV51Screen({super.key, required this.category});

  final String category;

  @override
  State<ProductListV51Screen> createState() => _ProductListV51ScreenState();
}

class _ProductListV51ScreenState extends State<ProductListV51Screen> {
  final TextEditingController _searchController = TextEditingController();
  ProductSearchV51Controller? _ai;
  String _search = '';
  String? _province;
  String? _district;
  String? _commune;

  ProductSearchV51Controller get _searchAi =>
      _ai ??= ProductSearchV51Controller(context);

  bool get _hasLocation =>
      [_province, _district, _commune].any((value) => value?.isNotEmpty == true);

  String get _locationLabel => [_province, _district, _commune]
      .whereType<String>()
      .where((value) => value.isNotEmpty)
      .join(' › ');

  Future<void> _applyAi(String value) async {
    if (!mounted || value.trim().isEmpty) return;
    final primary = value.split('|').first.trim();
    _searchController.text = primary;
    _searchController.selection =
        TextSelection.collapsed(offset: primary.length);
    setState(() => _search = value.toLowerCase());
  }

  Future<void> _imageSearch() async {
    final result = await _searchAi.searchByImage();
    if (result != null) await _applyAi(result);
    if (mounted) setState(() {});
  }

  Future<void> _voiceSearch() async {
    final ai = _searchAi;
    if (ai.recording) {
      await ai.finishVoice(onResult: _applyAi);
    } else {
      await ai.startVoice(onResult: _applyAi);
    }
    if (mounted) setState(() {});
  }

  Future<void> _pickLocation() async {
    await CambodiaLocationService.load();
    if (!mounted) return;

    String? province = _province;
    String? district = _district;
    String? commune = _commune;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final provinces = CambodiaLocationService.getProvinces();
          final districts = province == null
              ? <String>[]
              : CambodiaLocationService.getDistricts(province!);
          final communes = province == null || district == null
              ? <String>[]
              : CambodiaLocationService.getCommunes(province!, district!);

          Widget buildField(
            String label,
            String? value,
            List<String> items,
            ValueChanged<String?> changed,
            bool enabled,
          ) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: DropdownButtonFormField<String>(
                initialValue: value,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: label,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: items
                    .map(
                      (item) => DropdownMenuItem<String>(
                        value: item,
                        child: Text(item),
                      ),
                    )
                    .toList(),
                onChanged: enabled ? changed : null,
              ),
            );
          }

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    appText(
                      context,
                      km: 'ចម្រុះតាមទីតាំង',
                      en: 'Filter by location',
                    ),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 18),
                  buildField(
                    appText(context, km: 'ខេត្ត/រាជធានី', en: 'Province / City'),
                    province,
                    provinces,
                    (value) => setSheetState(() {
                      province = value;
                      district = null;
                      commune = null;
                    }),
                    true,
                  ),
                  buildField(
                    appText(context, km: 'ស្រុក/ខណ្ឌ', en: 'District'),
                    district,
                    districts,
                    (value) => setSheetState(() {
                      district = value;
                      commune = null;
                    }),
                    province != null,
                  ),
                  buildField(
                    appText(context, km: 'ឃុំ/សង្កាត់', en: 'Commune'),
                    commune,
                    communes,
                    (value) => setSheetState(() => commune = value),
                    district != null,
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _province = null;
                              _district = null;
                              _commune = null;
                            });
                            Navigator.pop(sheetContext);
                          },
                          child: Text(appText(context, km: 'ទាំងអស់', en: 'All')),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: province == null
                              ? null
                              : () {
                                  setState(() {
                                    _province = province;
                                    _district = district;
                                    _commune = commune;
                                  });
                                  Navigator.pop(sheetContext);
                                },
                          child: Text(
                            appText(context, km: 'អនុវត្ត', en: 'Apply'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ai = _ai;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        title: Text(localizedCategoryLabel(context, widget.category)),
        actions: [
          IconButton(
            onPressed: _pickLocation,
            icon: Icon(
              _hasLocation ? Icons.filter_alt : Icons.filter_alt_outlined,
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(_hasLocation ? 88 : 60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(15, 0, 15, 10),
            child: Column(
              children: [
                Container(
                  height: 45,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) =>
                        setState(() => _search = value.trim().toLowerCase()),
                    decoration: InputDecoration(
                      hintText: appText(
                        context,
                        km: 'ស្វែងរកទំនិញក្នុងប្រភេទនេះ...',
                        en: 'Search products in this category...',
                      ),
                      prefixIcon: const Icon(Icons.search),
                      suffixIconConstraints:
                          const BoxConstraints.tightFor(width: 96),
                      suffixIcon: Row(
                        children: [
                          SizedBox(
                            width: 32,
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              onPressed: ai?.busy == true ? null : _imageSearch,
                              icon: const Icon(
                                Icons.image_search,
                                color: Colors.purple,
                                size: 21,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 32,
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              onPressed: ai?.busy == true ? null : _voiceSearch,
                              icon: Icon(
                                ai?.recording == true
                                    ? Icons.stop_circle
                                    : Icons.mic,
                                color: ai?.recording == true
                                    ? Colors.red
                                    : Colors.green,
                                size: 21,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 32,
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const QrScannerScreen(),
                                ),
                              ),
                              icon: const Icon(
                                Icons.qr_code_scanner,
                                color: Colors.blue,
                                size: 21,
                              ),
                            ),
                          ),
                        ],
                      ),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                if (_hasLocation) ...[
                  const SizedBox(height: 7),
                  InkWell(
                    onTap: _pickLocation,
                    child: Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          color: Colors.white,
                          size: 15,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            _locationLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      body: ProductGridV51(
        category: widget.category,
        searchQuery: _search,
        filterProvince: _province,
        filterDistrict: _district,
        filterCommune: _commune,
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _ai?.dispose();
    super.dispose();
  }
}
