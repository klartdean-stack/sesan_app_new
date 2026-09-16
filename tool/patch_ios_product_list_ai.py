from pathlib import Path

p = Path('lib/product_list.dart')
s = p.read_text(encoding='utf-8')

# Android V51 Product List dependencies.
anchor = "import 'package:flutter/material.dart';"
imports = """import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
"""
if "import 'dart:async';" not in s:
    s = s.replace(anchor, imports + anchor)

# Local parity helpers used by Android V51.
for imp in [
    "import 'localized_text.dart';",
    "import 'category_localization.dart';",
    "import 'location_picker.dart';",
]:
    if imp not in s:
        s = s.replace("import 'edit_product.dart';", "import 'edit_product.dart';\n" + imp)

# Replace ProductList screen state only. ProductGridView is patched separately below.
start = s.index('class _ProductListScreenState extends State<ProductListScreen> {')
end = s.index('\nclass ProductGridView extends StatefulWidget', start)
state = r'''class _ProductListScreenState extends State<ProductListScreen> {
  String _currentSearch = "";
  final TextEditingController _searchController = TextEditingController();
  final ImagePicker _searchImagePicker = ImagePicker();
  final AudioRecorder _searchAudioRecorder = AudioRecorder();
  Timer? _voiceSearchTimer;
  bool _isSearchBusy = false;
  bool _isVoiceSearching = false;
  bool _voiceSheetOpen = false;
  String? _selectedProvince;
  String? _selectedDistrict;
  String? _selectedCommune;

  bool get _hasLocationFilter =>
      (_selectedProvince?.isNotEmpty ?? false) ||
      (_selectedDistrict?.isNotEmpty ?? false) ||
      (_selectedCommune?.isNotEmpty ?? false);

  String get _locationFilterLabel {
    final parts = <String>[
      if (_selectedProvince?.isNotEmpty ?? false) _selectedProvince!,
      if (_selectedDistrict?.isNotEmpty ?? false) _selectedDistrict!,
      if (_selectedCommune?.isNotEmpty ?? false) _selectedCommune!,
    ];
    return parts.join(' › ');
  }

  String _searchLabel(String km, String en) =>
      Localizations.localeOf(context).languageCode == 'en' ? en : km;

  void _showSearchMessage(String message, {Color color = Colors.red}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  bool _canUseAiSearch() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null && uid.isNotEmpty) return true;
    _showSearchMessage(_searchLabel(
      'សូមចូលគណនីជាមុន ដើម្បីស្វែងរកតាមរូប ឬសម្លេង',
      'Please sign in to search with a photo or voice',
    ));
    return false;
  }

  Future<Map<String, dynamic>> _callAiSearch({String? image, String? audio}) async {
    final callable = FirebaseFunctions.instanceFor(region: 'asia-southeast1')
        .httpsCallable('analyzeProductSearch');
    final response = await callable.call(<String, dynamic>{
      'locale': Localizations.localeOf(context).languageCode,
      if (image != null) 'image': image,
      if (audio != null) 'audio': audio,
    });
    return Map<String, dynamic>.from(response.data as Map);
  }

  void _applyAiSearch(Map<String, dynamic> data) {
    final query = (data['query'] ?? '').toString().trim();
    if (query.isEmpty) throw StateError('Empty AI search query');
    final keywords = (data['keywords'] as List?)
            ?.map((value) => value.toString().trim())
            .where((value) => value.isNotEmpty)
            .toList() ??
        const <String>[];
    final combinedQuery = <String>{query, ...keywords}.join(' | ');
    _searchController.text = query;
    _searchController.selection = TextSelection.collapsed(offset: query.length);
    setState(() => _currentSearch = combinedQuery);
    _showSearchMessage(
      _searchLabel('កំពុងស្វែងរក៖ $query', 'Searching for: $query'),
      color: Colors.green,
    );
  }

  String _pickedImageMime(XFile image) {
    final mime = image.mimeType?.toLowerCase();
    if (mime == 'image/png' || mime == 'image/webp') return mime!;
    return 'image/jpeg';
  }

  Future<void> _searchByImage() async {
    if (_isSearchBusy || !_canUseAiSearch()) return;
    final image = await _searchImagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 72,
    );
    if (image == null || !mounted) return;
    setState(() => _isSearchBusy = true);
    try {
      final bytes = await image.readAsBytes();
      if (bytes.isEmpty || bytes.length > 3300000) {
        throw StateError('Image is too large');
      }
      final input = 'data:${_pickedImageMime(image)};base64,${base64Encode(bytes)}';
      _applyAiSearch(await _callAiSearch(image: input));
    } on FirebaseFunctionsException catch (error) {
      _showSearchMessage(error.message ?? _searchLabel(
        'មិនអាចស្វែងរកតាមរូបបានទេ',
        'Could not search with this image',
      ));
    } catch (error) {
      debugPrint('AI image search error: $error');
      _showSearchMessage(_searchLabel(
        'រូបធំពេក ឬមិនអាចអានបាន',
        'The image is too large or could not be read',
      ));
    } finally {
      if (mounted) setState(() => _isSearchBusy = false);
    }
  }

  Future<void> _toggleVoiceSearch() async {
    if (_isSearchBusy || _isVoiceSearching || !_canUseAiSearch()) return;
    try {
      if (!await _searchAudioRecorder.hasPermission()) {
        _showSearchMessage(_searchLabel(
          'សូមអនុញ្ញាត Microphone ជាមុន',
          'Please allow microphone access first',
        ));
        return;
      }
      final String path;
      if (kIsWeb) {
        path = '';
      } else {
        final directory = await getTemporaryDirectory();
        path = '${directory.path}/sesan_category_search_${DateTime.now().millisecondsSinceEpoch}.m4a';
      }
      await _searchAudioRecorder.start(
        RecordConfig(
          encoder: kIsWeb ? AudioEncoder.wav : AudioEncoder.aacLc,
          bitRate: 48000,
          sampleRate: 22050,
          echoCancel: true,
          noiseSuppress: true,
          autoGain: true,
        ),
        path: path,
      );
      if (!mounted) return;
      setState(() => _isVoiceSearching = true);
      _voiceSearchTimer?.cancel();
      _voiceSearchTimer = Timer(const Duration(seconds: 5), _finishVoiceSearch);
      _voiceSheetOpen = true;
      showModalBottomSheet<void>(
        context: context,
        isDismissible: false,
        enableDrag: false,
        backgroundColor: Colors.transparent,
        builder: (_) => SafeArea(
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.mic_rounded, color: Colors.red, size: 44),
                const SizedBox(height: 14),
                Text(
                  _searchLabel('កំពុងស្តាប់...', 'Listening...'),
                  style: const TextStyle(
                    fontFamily: 'Siemreap',
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 14),
                const LinearProgressIndicator(minHeight: 4),
              ],
            ),
          ),
        ),
      ).whenComplete(() => _voiceSheetOpen = false);
    } catch (error) {
      debugPrint('Start voice search error: $error');
      _showSearchMessage(_searchLabel(
        'មិនអាចចាប់ផ្តើមថតសម្លេងបានទេ',
        'Could not start voice recording',
      ));
    }
  }

  Future<void> _finishVoiceSearch() async {
    if (!_isVoiceSearching) return;
    _voiceSearchTimer?.cancel();
    if (_voiceSheetOpen && mounted) {
      Navigator.of(context).pop();
      _voiceSheetOpen = false;
    }
    if (mounted) {
      setState(() {
        _isVoiceSearching = false;
        _isSearchBusy = true;
      });
    }
    try {
      final path = await _searchAudioRecorder.stop();
      if (path == null || path.isEmpty) throw StateError('Empty recording path');
      Uint8List? bytes;
      for (var attempt = 0; attempt < 4; attempt++) {
        await Future<void>.delayed(Duration(milliseconds: attempt == 0 ? 250 : 400));
        try {
          final candidate = await XFile(path).readAsBytes();
          if (candidate.isNotEmpty) {
            bytes = candidate;
            break;
          }
        } catch (_) {}
      }
      if (bytes == null || bytes.isEmpty || bytes.length > 7500000) {
        throw StateError('Recorded audio could not be read');
      }
      final mime = kIsWeb ? 'audio/wav' : 'audio/m4a';
      _applyAiSearch(await _callAiSearch(
        audio: 'data:$mime;base64,${base64Encode(bytes)}',
      ));
    } on FirebaseFunctionsException catch (error) {
      _showSearchMessage(error.message ?? _searchLabel(
        'មិនអាចយល់សម្លេងនេះបានទេ',
        'Could not understand this recording',
      ));
    } catch (error) {
      debugPrint('Voice search error: $error');
      _showSearchMessage(_searchLabel(
        'ការស្វែងរកតាមសម្លេងបរាជ័យ',
        'Voice search failed',
      ));
    } finally {
      if (mounted) setState(() => _isSearchBusy = false);
    }
  }

  Future<void> _showLocationFilter() async {
    await CambodiaLocationService.load();
    if (!mounted) return;
    String? province = _selectedProvince;
    String? district = _selectedDistrict;
    String? commune = _selectedCommune;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final provinces = CambodiaLocationService.getProvinces();
          final districts = province == null
              ? <String>[]
              : CambodiaLocationService.getDistricts(province!);
          final communes = province == null || district == null
              ? <String>[]
              : CambodiaLocationService.getCommunes(province!, district!);

          Widget selector({
            required String label,
            required String? value,
            required List<String> items,
            required bool enabled,
            required ValueChanged<String?> onChanged,
          }) {
            return DropdownButtonFormField<String>(
              value: value,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: label,
                border: const OutlineInputBorder(),
              ),
              items: items
                  .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                  .toList(),
              onChanged: enabled ? onChanged : null,
            );
          }

          return SafeArea(
            child: Container(
              padding: EdgeInsets.only(
                left: 18,
                right: 18,
                top: 18,
                bottom: 18 + MediaQuery.of(context).viewInsets.bottom,
              ),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAF8),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    appText(context, km: 'ចម្រុះតាមទីតាំង', en: 'Filter by location'),
                    style: const TextStyle(
                      fontFamily: 'Siemreap',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  selector(
                    label: appText(context, km: 'ខេត្ត/រាជធានី', en: 'Province / City'),
                    value: province,
                    items: provinces,
                    enabled: true,
                    onChanged: (value) => setSheetState(() {
                      province = value;
                      district = null;
                      commune = null;
                    }),
                  ),
                  const SizedBox(height: 10),
                  selector(
                    label: appText(context, km: 'ស្រុក/ខណ្ឌ', en: 'District'),
                    value: district,
                    items: districts,
                    enabled: province != null,
                    onChanged: (value) => setSheetState(() {
                      district = value;
                      commune = null;
                    }),
                  ),
                  const SizedBox(height: 10),
                  selector(
                    label: appText(context, km: 'ឃុំ/សង្កាត់', en: 'Commune'),
                    value: commune,
                    items: communes,
                    enabled: district != null,
                    onChanged: (value) => setSheetState(() => commune = value),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _selectedProvince = null;
                              _selectedDistrict = null;
                              _selectedCommune = null;
                            });
                            Navigator.pop(sheetContext);
                          },
                          child: Text(appText(context, km: 'ទាំងអស់', en: 'All locations')),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: province == null
                              ? null
                              : () {
                                  setState(() {
                                    _selectedProvince = province;
                                    _selectedDistrict = district;
                                    _selectedCommune = commune;
                                  });
                                  Navigator.pop(sheetContext);
                                },
                          child: Text(appText(context, km: 'អនុវត្ត', en: 'Apply')),
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
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.category == 'ទំនិញរបស់ខ្ញុំ'
              ? appText(context, km: 'គ្រប់គ្រងការបង្ហោះ', en: 'Manage posts')
              : localizedCategoryLabel(context, widget.category),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontFamily: 'Siemreap',
          ),
        ),
        backgroundColor: Colors.green[700],
        centerTitle: true,
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                onPressed: _showLocationFilter,
                icon: Icon(
                  _hasLocationFilter ? Icons.filter_alt : Icons.filter_alt_outlined,
                  color: Colors.white,
                ),
              ),
              if (_hasLocationFilter)
                const Positioned(
                  right: 8,
                  top: 8,
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: Colors.amber, shape: BoxShape.circle),
                    child: SizedBox(width: 8, height: 8),
                  ),
                ),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(_hasLocationFilter ? 88 : 60),
          child: Padding(
            padding: const EdgeInsets.only(left: 15, right: 15, bottom: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                        setState(() => _currentSearch = value.trim().toLowerCase()),
                    decoration: InputDecoration(
                      hintText: appText(
                        context,
                        km: 'ស្វែងរកទំនិញក្នុងប្រភេទនេះ...',
                        en: 'Search products in this category...',
                      ),
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      suffixIconConstraints: const BoxConstraints.tightFor(width: 94, height: 45),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 30,
                            child: InkResponse(
                              onTap: _isSearchBusy ? null : _searchByImage,
                              child: _isSearchBusy
                                  ? const Padding(
                                      padding: EdgeInsets.all(7),
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.image_search_rounded, color: Colors.purple, size: 21),
                            ),
                          ),
                          SizedBox(
                            width: 30,
                            child: InkResponse(
                              onTap: _isSearchBusy ? null : _toggleVoiceSearch,
                              child: Icon(
                                _isVoiceSearching ? Icons.stop_circle_rounded : Icons.mic_rounded,
                                color: _isVoiceSearching ? Colors.red : Colors.green,
                                size: 21,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 30,
                            child: InkResponse(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const QrScannerScreen()),
                              ),
                              child: const Icon(Icons.qr_code_scanner, color: Colors.blue, size: 21),
                            ),
                          ),
                        ],
                      ),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                if (_hasLocationFilter) ...[
                  const SizedBox(height: 7),
                  Text(
                    _locationFilterLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'Siemreap',
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      body: ProductGridView(
        category: widget.category,
        searchQuery: _currentSearch,
        filterProvince: _selectedProvince,
        filterDistrict: _selectedDistrict,
        filterCommune: _selectedCommune,
      ),
    );
  }

  @override
  void dispose() {
    _voiceSearchTimer?.cancel();
    _searchController.dispose();
    _searchAudioRecorder.dispose();
    super.dispose();
  }
}
'''
s = s[:start] + state + s[end:]

# Location fields on ProductGridView.
s = s.replace(
    "final bool isAuction; // 🎯 ១. ត្រូវប្រកាស Variable នេះនៅទីនេះ!",
    "final bool isAuction; // 🎯 ១. ត្រូវប្រកាស Variable នេះនៅទីនេះ!\n  final String? filterProvince;\n  final String? filterDistrict;\n  final String? filterCommune;",
)
s = s.replace(
    "this.isAuction = false, // 🎯 ២. និងដាក់វាចូលក្នុង Constructor ទីនេះ!",
    "this.isAuction = false, // 🎯 ២. និងដាក់វាចូលក្នុង Constructor ទីនេះ!\n    this.filterProvince,\n    this.filterDistrict,\n    this.filterCommune,",
)

# Re-fetch if search/location changes.
if 'void didUpdateWidget(covariant ProductGridView oldWidget)' not in s:
    marker = '  Future<void> _initUserAndFetch() async {'
    did_update = '''  @override\n  void didUpdateWidget(covariant ProductGridView oldWidget) {\n    super.didUpdateWidget(oldWidget);\n    final oldSearch = oldWidget.searchQuery.trim();\n    final newSearch = widget.searchQuery.trim();\n    final locationChanged =\n        oldWidget.filterProvince != widget.filterProvince ||\n        oldWidget.filterDistrict != widget.filterDistrict ||\n        oldWidget.filterCommune != widget.filterCommune;\n    if ((oldSearch != newSearch && newSearch.isNotEmpty) || locationChanged) {\n      _products.clear();\n      _lastDoc = null;\n      _hasMore = true;\n      _fetchProducts();\n    }\n  }\n\n'''
    s = s.replace(marker, did_update + marker)

# Fetch enough rows for smart/location filtering.
s = s.replace(
    "query = query.orderBy('created_at', descending: true).limit(50);",
    "final hasLocationFilter =\n        (widget.filterProvince?.isNotEmpty ?? false) ||\n        (widget.filterDistrict?.isNotEmpty ?? false) ||\n        (widget.filterCommune?.isNotEmpty ?? false);\n    final fetchLimit = hasLocationFilter\n        ? 500\n        : (widget.searchQuery.trim().isEmpty ? 50 : 200);\n    query = query.orderBy('created_at', descending: true).limit(fetchLimit);",
)
s = s.replace('_hasMore = snapshot.docs.length >= 50;', '_hasMore = snapshot.docs.length >= fetchLimit;')

# Smart search/location helpers.
marker = '  // ── BUILD ───────────────────────────────────────────────'
helpers = r'''  String _searchableProductText(Map<String, dynamic> data) {
    final values = <dynamic>[
      data['product_name'],
      data['productName'],
      data['category'],
      data['sub_category'],
      data['sub_sub_category'],
      data['description'],
      data['details'],
      data['brand'],
      data['keywords'],
      data['tags'],
    ];
    return values
        .where((value) => value != null)
        .map((value) => value is List ? value.join(' ') : value.toString())
        .join(' ')
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-zA-Z0-9\u1780-\u17FF]+'), ' ')
        .trim();
  }

  bool _matchesSmartSearch(Map<String, dynamic> data, String rawQuery) {
    final query = rawQuery.toLowerCase().trim();
    if (query.isEmpty) return true;
    final haystack = _searchableProductText(data);
    if (haystack.isEmpty) return false;
    final alternatives = query
        .split('|')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
    for (final alternative in alternatives) {
      if (haystack.contains(alternative)) return true;
      final tokens = alternative
          .replaceAll(RegExp(r'[^a-zA-Z0-9\u1780-\u17FF]+'), ' ')
          .split(RegExp(r'\s+'))
          .where((token) => token.length >= 2)
          .toList();
      if (tokens.isEmpty) continue;
      final matched = tokens.where(haystack.contains).length;
      if (matched >= 1 && matched / tokens.length >= 0.34) return true;
    }
    return false;
  }

  bool _matchesLocationFilter(Map<String, dynamic> data) {
    final province = widget.filterProvince?.trim() ?? '';
    final district = widget.filterDistrict?.trim() ?? '';
    final commune = widget.filterCommune?.trim() ?? '';
    if (province.isEmpty && district.isEmpty && commune.isEmpty) return true;
    final raw = (data['location'] ?? '').toString().trim();
    if (raw.isEmpty) return false;
    final parts = raw
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
    final exactProvince = parts.isNotEmpty && parts[0] == province;
    final exactDistrict = district.isEmpty || (parts.length > 1 && parts[1] == district);
    final exactCommune = commune.isEmpty || (parts.length > 2 && parts[2] == commune);
    if (province.isNotEmpty && exactProvince && exactDistrict && exactCommune) return true;
    if (province.isNotEmpty && !raw.contains(province)) return false;
    if (district.isNotEmpty && !raw.contains(district)) return false;
    if (commune.isNotEmpty && !raw.contains(commune)) return false;
    return true;
  }

'''
if '_matchesSmartSearch' not in s:
    s = s.replace(marker, helpers + marker)

# Replace legacy simple name search with smart search.
old = """      final name = (data['product_name'] ?? data['productName'] ?? '')
          .toString()
          .toLowerCase();
      final query = widget.searchQuery.toLowerCase();"""
if old in s:
    s = s.replace(old, '      final query = widget.searchQuery;')
s = s.replace(
    'name.contains(query) &&\n          matchesSub &&\n          matchesSubSub;',
    '_matchesSmartSearch(data, query) &&\n          matchesSub &&\n          matchesSubSub &&\n          _matchesLocationFilter(data);',
)

p.write_text(s, encoding='utf-8')

out = p.read_text(encoding='utf-8')
for token in [
    'analyzeProductSearch',
    'image_search_rounded',
    'AudioRecorder',
    'filterProvince',
    '_matchesSmartSearch',
    '_matchesLocationFilter',
    'didUpdateWidget(covariant ProductGridView oldWidget)',
]:
    assert token in out, token
