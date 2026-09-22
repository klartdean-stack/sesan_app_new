import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:my_app/auction_main_screen.dart';
import 'package:my_app/smart_scan_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:my_app/wanted_detail_screen.dart';
import 'main.dart';
import 'product_detail.dart';
import 'pre_order_detail_screen.dart';
import 'edit_product.dart';
import 'location_picker.dart';
import 'category_localization.dart';
import 'localized_text.dart';
import 'marketplace_analytics_service.dart';

/// 🎯 Service យក User ID (Firebase Auth ឬ SharedPreferences)
class UserService {
  static String? _cachedUserId;

  static Future<String?> getUserId() async {
    if (_cachedUserId != null) return _cachedUserId;

    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser != null) {
      _cachedUserId = firebaseUser.uid;
      return _cachedUserId;
    }

    final prefs = await SharedPreferences.getInstance();
    _cachedUserId =
        prefs.getString('user_uid') ??
        prefs.getString('uid') ??
        prefs.getString('user_id');

    return _cachedUserId;
  }

  static void clearCache() => _cachedUserId = null;
}

// ─────────────────────────────────────────────────────────────
// ProductListScreen
// ─────────────────────────────────────────────────────────────
class ProductListScreen extends StatefulWidget {
  final String category;
  const ProductListScreen({super.key, required this.category});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  String _currentSearch = "";
  final TextEditingController _searchController = TextEditingController();
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
      builder: (sheetContext) {
        return StatefulBuilder(
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
              required String hint,
              required String? value,
              required List<String> items,
              required ValueChanged<String?> onChanged,
              required bool enabled,
            }) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Siemreap',
                    ),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: value,
                    isExpanded: true,
                    decoration: InputDecoration(
                      hintText: hint,
                      filled: true,
                      fillColor: enabled ? Colors.white : Colors.grey.shade100,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 11,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    items: items
                        .map((item) => DropdownMenuItem<String>(
                              value: item,
                              child: Text(
                                item,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontFamily: 'Siemreap',
                                ),
                              ),
                            ))
                        .toList(),
                    onChanged: enabled ? onChanged : null,
                  ),
                ],
              );
            }

            return SafeArea(
              child: Container(
                padding: EdgeInsets.only(
                  left: 18,
                  right: 18,
                  top: 12,
                  bottom: 18 + MediaQuery.of(context).viewInsets.bottom,
                ),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAF8),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 42,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const CircleAvatar(
                            radius: 19,
                            backgroundColor: Color(0xFFE6F4EA),
                            child: Icon(Icons.location_on_outlined, color: Colors.green),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  appText(context, km: 'ចម្រុះតាមទីតាំង', en: 'Filter by location'),
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Siemreap',
                                  ),
                                ),
                                Text(
                                  appText(
                                    context,
                                    km: 'ជ្រើសត្រឹមខេត្ត ស្រុក ឬឃុំ/សង្កាត់បាន',
                                    en: 'Choose a province, district, or commune',
                                  ),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
                                    fontFamily: 'Siemreap',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(sheetContext),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      selector(
                        label: appText(context, km: 'ខេត្ត/រាជធានី', en: 'Province / City'),
                        hint: appText(context, km: 'ជ្រើសខេត្ត', en: 'Select province'),
                        value: province,
                        items: provinces,
                        enabled: true,
                        onChanged: (value) => setSheetState(() {
                          province = value;
                          district = null;
                          commune = null;
                        }),
                      ),
                      const SizedBox(height: 12),
                      selector(
                        label: appText(context, km: 'ស្រុក/ខណ្ឌ', en: 'District'),
                        hint: appText(context, km: 'ជ្រើសស្រុក', en: 'Select district'),
                        value: district,
                        items: districts,
                        enabled: province != null,
                        onChanged: (value) => setSheetState(() {
                          district = value;
                          commune = null;
                        }),
                      ),
                      const SizedBox(height: 12),
                      selector(
                        label: appText(context, km: 'ឃុំ/សង្កាត់', en: 'Commune'),
                        hint: appText(context, km: 'ជ្រើសឃុំ/សង្កាត់', en: 'Select commune'),
                        value: commune,
                        items: communes,
                        enabled: district != null,
                        onChanged: (value) => setSheetState(() => commune = value),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                setState(() {
                                  _selectedProvince = null;
                                  _selectedDistrict = null;
                                  _selectedCommune = null;
                                });
                                Navigator.pop(sheetContext);
                              },
                              icon: const Icon(Icons.refresh, size: 18),
                              label: Text(
                                appText(context, km: 'ទាំងអស់', en: 'All locations'),
                                style: const TextStyle(fontFamily: 'Siemreap'),
                              ),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 48),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
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
                              icon: const Icon(Icons.check, size: 18),
                              label: Text(
                                appText(context, km: 'អនុវត្ត', en: 'Apply'),
                                style: const TextStyle(fontFamily: 'Siemreap'),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade700,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(0, 48),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
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

  String _pickedImageMime(XFile image) {
    final mime = image.mimeType?.toLowerCase();
    if (mime == 'image/png' || mime == 'image/webp') return mime!;
    return 'image/jpeg';
  }

  Future<void> _searchWithImage(XFile image) async {
    if (_isSearchBusy || !_canUseAiSearch() || !mounted) return;

    setState(() => _isSearchBusy = true);
    try {
      final bytes = await image.readAsBytes();
      if (bytes.isEmpty || bytes.length > 3300000) {
        throw StateError('Image is too large');
      }
      final input =
          'data:${_pickedImageMime(image)};base64,${base64Encode(bytes)}';
      _applyAiSearch(await _callAiSearch(image: input));
    } on FirebaseFunctionsException catch (error) {
      _showSearchMessage(
        error.message ??
            _searchLabel(
              'មិនអាចស្វែងរកតាមរូបបានទេ',
              'Could not search with this image',
            ),
      );
    } catch (error) {
      debugPrint('AI image search error: $error');
      _showSearchMessage(
        _searchLabel(
          'រូបធំពេក ឬមិនអាចអានបាន',
          'The image is too large or could not be read',
        ),
      );
    } finally {
      if (mounted) setState(() => _isSearchBusy = false);
    }
  }

  Future<void> _startSmartScan() async {
    if (_isSearchBusy) return;

    final image = await Navigator.push<XFile?>(
      context,
      MaterialPageRoute(builder: (_) => const SmartScanScreen()),
    );

    if (image != null && mounted) {
      await _searchWithImage(image);
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
      _showVoiceListeningSheet();
    } catch (error) {
      debugPrint('Start voice search error: $error');
      _showSearchMessage(_searchLabel(
        'មិនអាចចាប់ផ្តើមថតសម្លេងបានទេ',
        'Could not start voice recording',
      ));
    }
  }

  void _showVoiceListeningSheet() {
    _voiceSheetOpen = true;
    showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
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
        fontFamily: 'Siemreap', fontWeight: FontWeight.bold, fontSize: 20,
      ),
    ),
    const SizedBox(height: 14),
    const LinearProgressIndicator(minHeight: 4),
  ],
),
        ),
      ),
    ).whenComplete(() => _voiceSheetOpen = false);
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
if (candidate.isNotEmpty) { bytes = candidate; break; }
        } catch (_) {}
      }
      if (bytes == null || bytes.isEmpty || bytes.length > 7500000) {
        throw StateError('Recorded audio could not be read');
      }
      final mime = kIsWeb ? 'audio/wav' : 'audio/m4a';
      _applyAiSearch(await _callAiSearch(audio: 'data:$mime;base64,${base64Encode(bytes)}'));
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
                tooltip: appText(context, km: 'ចម្រុះតាមទីតាំង', en: 'Filter by location'),
                onPressed: _showLocationFilter,
                icon: Icon(
                  _hasLocationFilter ? Icons.filter_alt : Icons.filter_alt_outlined,
                  color: Colors.white,
                  size: 25,
                ),
              ),
              if (_hasLocationFilter)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.amber,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(_hasLocationFilter ? 94 : 66),
          child: Padding(
            padding: const EdgeInsets.only(left: 15, right: 15, bottom: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() => _currentSearch = value.trim().toLowerCase());
                    },
                    decoration: InputDecoration(
                      hintText: appText(context, km: 'ស្វែងរកទំនិញ...', en: 'Search products...'),
                      hintStyle: const TextStyle(fontFamily: 'Siemreap', fontSize: 13),
                      prefixIcon: const Icon(Icons.search, color: Colors.grey, size: 20),
                      prefixIconConstraints: const BoxConstraints.tightFor(
                        width: 34,
                        height: 36,
                      ),
                      suffixIconConstraints: const BoxConstraints.tightFor(
                        width: 88,
                        height: 44,
                      ),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Tooltip(
                            message: _searchLabel(
                              'Smart Scan — QR ឬទំនិញ',
                              'Smart Scan — QR or product',
                            ),
                            child: SizedBox(
                              width: 44,
                              height: 44,
                              child: InkResponse(
                                radius: 22,
                                onTap: _isSearchBusy ? null : _startSmartScan,
                                child: Center(
                                  child: _isSearchBusy
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.center_focus_strong_rounded,
                                          size: 20,
                                          color: Colors.blue,
                                        ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 44,
                              height: 44,
                            child: InkResponse(
                              radius: 22,
                              onTap: _isSearchBusy ? null : _toggleVoiceSearch,
                              child: Center(
                                child: Icon(
                                  _isVoiceSearching
                                      ? Icons.stop_circle_rounded
                                      : Icons.mic_rounded,
                                  size: 20,
                                  color: _isVoiceSearching
                                      ? Colors.red
                                      : Colors.green,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 9),
                    ),
                  ),
                ),
                if (_hasLocationFilter) ...[
                  const SizedBox(height: 7),
                  InkWell(
                    onTap: _showLocationFilter,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.16),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.location_on, size: 14, color: Colors.white),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              _locationFilterLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Siemreap',
                              ),
                            ),
                          ),
                          const Icon(Icons.keyboard_arrow_down, size: 17, color: Colors.white),
                        ],
                      ),
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

class ProductGridView extends StatefulWidget {
  final String category;
  final String searchQuery;
  final bool isHome;
  final bool isAuction; // 🎯 ១. ត្រូវប្រកាស Variable នេះនៅទីនេះ!
  final String? filterProvince;
  final String? filterDistrict;
  final String? filterCommune;

  const ProductGridView({
    super.key,
    required this.category,
    this.searchQuery = "",
    this.isHome = false,
    this.isAuction = false, // 🎯 ២. និងដាក់វាចូលក្នុង Constructor ទីនេះ!
    this.filterProvince,
    this.filterDistrict,
    this.filterCommune,
  });

  @override
  State<ProductGridView> createState() => _ProductGridViewState();
}

class _ProductGridViewState extends State<ProductGridView>
    with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();
  final int _batchSize = 35; // ✅ ប្ដូរពី 35 → 100
  List<DocumentSnapshot> _products = [];
  bool _isLoading = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastDoc;
  String? _currentUserId;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _cartSubscription;
  final Set<String> _cartProductIds = <String>{};
  final Set<String> _cartAddingIds = <String>{};
  final Map<String, int> _stockQuantityOverrides = <String, int>{};
  final Set<String> _stockUpdatingIds = <String>{};
  String _selectedManageType = 'sale';
  static String _lastManageType = 'sale';
  String _selectedSubCategory = 'ទាំងអស់'; // ✅ បន្ថែមបន្ទាត់នេះ
  String _selectedSubSubCategory = 'ទាំងអស់'; // ✅ បន្ថែម
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initUserAndFetch();
    if (!widget.isHome) {
      _scrollController.addListener(_onScroll);
    }
  }

  @override
  void didUpdateWidget(covariant ProductGridView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldSearch = oldWidget.searchQuery.trim();
    final newSearch = widget.searchQuery.trim();
    final locationChanged =
        oldWidget.filterProvince != widget.filterProvince ||
        oldWidget.filterDistrict != widget.filterDistrict ||
        oldWidget.filterCommune != widget.filterCommune;
    if ((oldSearch != newSearch && newSearch.isNotEmpty) || locationChanged) {
      _products.clear();
      _lastDoc = null;
      _hasMore = true;
      _fetchProducts();
    }
  }

  Future<void> _initUserAndFetch() async {
    _currentUserId = await UserService.getUserId();
    if (widget.category == "ទំនិញរបស់ខ្ញុំ") {
      final prefs = await SharedPreferences.getInstance();
      final savedType = prefs.getString('manage_posts_tab');
      _selectedManageType = savedType ?? _lastManageType;
    }

    _listenToCart();

    // ✅ Clear តែពេលចូលមកដំបូង
    if (mounted) {
      setState(() {
        _products.clear();
        _lastDoc = null;
        _hasMore = true;
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fetchProducts();
    });
  }

  void _listenToCart() {
    _cartSubscription?.cancel();
    final uid = _currentUserId;
    if (uid == null || uid.isEmpty) return;

    _cartSubscription = FirebaseFirestore.instance
        .collection('carts')
        .where('customer_id', isEqualTo: uid)
        .snapshots()
        .listen(
          (snapshot) {
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
          },
          onError: (error) {
            debugPrint('Cart state listener error: $error');
          },
        );
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoading &&
        _hasMore) {
      _fetchProducts();
    }
  }

  // ── FETCH PRODUCTS ──────────────────────────────────────
  Future<void> _fetchProducts() async {
    if (_isLoading || !_hasMore) return;

    if (!mounted) return; // ✅ បន្ថែម

    setState(() => _isLoading = true);

    try {
      if (widget.category == "ទំនិញរបស់ខ្ញុំ") {
        await _fetchMyProducts();
      } else {
        await _fetchByCategory();
      }
    } catch (e) {
      debugPrint("Error fetching products: $e");
    }

    if (mounted) {
      // ✅ បន្ថែមការពិនិត្យ
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchMyProducts() async {
    if (!mounted) return;
    if (_currentUserId == null) {
      setState(() => _hasMore = false);
      return;
    }

    final futures = await Future.wait([
      FirebaseFirestore.instance
          .collection('products')
          .where('seller_id', isEqualTo: _currentUserId)
          .orderBy('created_at', descending: true)
          .get(),
      FirebaseFirestore.instance
          .collection('wanted_products')
          .where('userId', isEqualTo: _currentUserId)
          .orderBy('createdAt', descending: true)
          .get(),
      FirebaseFirestore.instance
          .collection('pre_orders')
          .where('owner_id', isEqualTo: _currentUserId)
          .get(),
    ]);

    if (!mounted) return; // ✅ បន្ថែមបន្ទាប់ពី await

    final combined = <DocumentSnapshot>[];
    combined.addAll(futures[0].docs);
    combined.addAll(futures[1].docs);
    combined.addAll(futures[2].docs);

    combined.sort((a, b) {
      final dataA = a.data() as Map<String, dynamic>;
      final dataB = b.data() as Map<String, dynamic>;
      final timeA =
          dataA['created_at'] ??
          dataA['createdAt'] ??
          dataA['savedAt'] ??
          Timestamp.now();
      final timeB =
          dataB['created_at'] ??
          dataB['createdAt'] ??
          dataB['savedAt'] ??
          Timestamp.now();
      return (timeB as Timestamp).compareTo(timeA as Timestamp);
    });

    if (mounted) {
      setState(() {
        _products.clear();
        _products.addAll(combined);
        _hasMore = false;
      });
    }
  }

  Future<void> _fetchByCategory() async {
    if (!mounted) return;

    // 🎯 ១. រើស Collection តាមកុងតាក់ (បើ true ទៅ auction_products បើ false ទៅ products ធម្មតា)
    String targetCollection = widget.isAuction
        ? 'auction_products'
        : 'products';
    Query query = FirebaseFirestore.instance.collection(targetCollection);

    bool isCategoryAll =
        widget.category == "ReadAll" || widget.category == "ទាំងអស់";

    if (!isCategoryAll) {
      query = query.where('category', isEqualTo: widget.category);
    }

    // 🎯 ២. តម្រៀបតាមថ្ងៃខែបង្កើត និងកំណត់ចំនួនទាញទិន្នន័យ (លែងមានការប្រើ status នាំឱ្យទាក់កូដទៀតហើយ)
    final hasLocationFilter =
        (widget.filterProvince?.isNotEmpty ?? false) ||
        (widget.filterDistrict?.isNotEmpty ?? false) ||
        (widget.filterCommune?.isNotEmpty ?? false);
    final fetchLimit = hasLocationFilter
        ? 500
        : (widget.searchQuery.trim().isEmpty ? 50 : 200);
    query = query.orderBy('created_at', descending: true).limit(fetchLimit);

    if (_lastDoc != null) {
      query = query.startAfterDocument(_lastDoc!);
    }

    final snapshot = await query.get();

    if (!mounted) return;

    _lastDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : _lastDoc;

    if (mounted) {
      setState(() {
        for (var doc in snapshot.docs) {
          // 🎯 ៣. រុញទិន្នន័យចូលបញ្ជីដោយផ្ទាល់ភ្លាមៗ លឿន និងរលូនបំផុត
          if (!_products.any((e) => e.id == doc.id)) {
            _products.add(doc);
          }
        }

        _hasMore = snapshot.docs.length >= fetchLimit;
      });
    }
  }

  String _searchableProductText(Map<String, dynamic> data) {
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
    final exactDistrict =
        district.isEmpty || (parts.length > 1 && parts[1] == district);
    final exactCommune =
        commune.isEmpty || (parts.length > 2 && parts[2] == commune);
    if (province.isNotEmpty && exactProvince && exactDistrict && exactCommune)
      return true;
    if (province.isNotEmpty && !raw.contains(province)) return false;
    if (district.isNotEmpty && !raw.contains(district)) return false;
    if (commune.isNotEmpty && !raw.contains(commune)) return false;
    return true;
  }

  // ── BUILD ───────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    super.build(context); // ✅ ត្រូវតែមាន
    // ✅ ត្រងតាម Sub Category
    final filtered = _products.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final query = widget.searchQuery;

      final postType = _managePostType(doc);
      final matchesManageType =
          widget.category != 'ទំនិញរបស់ខ្ញុំ' ||
          postType == _selectedManageType;

      final subCategory = (data['sub_category'] ?? '').toString();
      final subSubCategory = (data['sub_sub_category'] ?? '').toString();

      final matchesSub =
          _selectedSubCategory == 'ទាំងអស់' ||
          subCategory == _selectedSubCategory;

      final matchesSubSub =
          _selectedSubSubCategory == 'ទាំងអស់' ||
          subSubCategory == _selectedSubSubCategory;

      return matchesManageType &&
          _matchesSmartSearch(data, query) &&
          matchesSub &&
          matchesSubSub &&
          _matchesLocationFilter(data);
    }).toList();

    // ✅ បើគ្មានទំនិញ ហើយមិនមែនកំពុងផ្ទុក
    if (filtered.isEmpty && !_isLoading) {
      return Column(
        children: [
          if (!widget.isHome) _buildSubCategoryFilter(),
          if (widget.category == 'ទំនិញរបស់ខ្ញុំ') _buildManageTabs(),
          const Expanded(
            child: Center(
              child: Text(
                "មិនមានទំនិញដែលអ្នករកទេ",
                style: TextStyle(fontFamily: 'Siemreap'),
              ),
            ),
          ),
        ],
      );
    }

    // ✅ បង្ហាញ Sub Category Filter + GridView
    return Column(
      children: [
        if (!widget.isHome) _buildSubCategoryFilter(),
        if (widget.category == 'ទំនិញរបស់ខ្ញុំ') _buildManageTabs(),
        Expanded(
          child: GridView.builder(
            key: const PageStorageKey('productGrid'),
            controller: widget.isHome ? null : _scrollController,
            shrinkWrap: widget.isHome,
            addRepaintBoundaries: true,
            addAutomaticKeepAlives: true,
            physics: widget.isHome
                ? const NeverScrollableScrollPhysics()
                : const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(12),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: MediaQuery.of(context).size.width > 800 ? 4 : 2,
              childAspectRatio: MediaQuery.of(context).size.width > 800
                  ? 0.75
                  : 0.68,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount:
                filtered.length +
                ((_hasMore && _isLoading && !widget.isHome) ? 1 : 0),
            itemBuilder: (context, index) {
              if (!widget.isHome && _isLoading && index >= filtered.length) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.green),
                );
              }
              return RepaintBoundary(child: _buildProductCard(filtered[index]));
            },
          ),
        ),
      ],
    );
  }

  String _managePostType(DocumentSnapshot doc) {
    final path = doc.reference.path;
    if (path.contains('wanted_products')) return 'wanted';
    if (path.contains('pre_orders')) return 'preorder';
    return 'sale';
  }

  Widget _buildManageTabs() {
    final tabs = <({String value, String km, String en, Color color})>[
      (value: 'sale', km: 'ទំនិញលក់', en: 'For sale', color: Colors.green),
      (value: 'wanted', km: 'ប្រកាសទិញ', en: 'Wanted', color: Colors.blue),
      (value: 'preorder', km: 'លក់មុន', en: 'Pre-order', color: Colors.orange),
    ];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      child: Row(
        children: tabs.map((tab) {
          final selected = _selectedManageType == tab.value;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () async {
                  if (selected) return;
                  setState(() => _selectedManageType = tab.value);
                  _lastManageType = tab.value;
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('manage_posts_tab', tab.value);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected ? tab.color : tab.color.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: tab.color.withOpacity(selected ? 1 : 0.28),
                    ),
                  ),
                  child: Text(
                    appText(context, km: tab.km, en: tab.en),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Siemreap',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : tab.color,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSubCategoryFilter() {
    if (widget.category == 'ទាំងអស់' || widget.category == 'ទំនិញរបស់ខ្ញុំ') {
      return const SizedBox.shrink();
    }

    // បញ្ជី Sub Categories
    final Map<String, dynamic> subCategories = {
      'គ្រឿងចក្រ': ['ទាំងអស់', 'ថ្មី', 'មួយទឹក', 'កាប់សាច់', 'គ្រឿងបន្លាស់'],
      'សម្ភារៈកសិកម្ម': {
        'ទាំងអស់': [],
        'ម៉ាស៊ីន': ['ទាំងអស់', 'ថ្មី', 'មួយទឹក', 'កាប់សាច់'],
        'ឧបករណ៍': ['ទាំងអស់', 'ថ្មី', 'មួយទឹក', 'កាប់សាច់'],
        'គ្រឿងបន្លាស់': ['ទាំងអស់', 'ថ្មី', 'មួយទឹក', 'កាប់សាច់'],
      },
      'ពូជដំណាំ': [
        'ទាំងអស់',
        'ឈើហូបផ្លែ',
        'បន្លែ',
        'ផ្ការ',
        'ឈើព្រៃ',
        'ផ្សេងៗ',
      ],
      'ពូជសត្វចិញ្ចឹម': [
        'ទាំងអស់',
        'គោ',
        'ក្របី',
        'ជ្រូក',
        'ចៀម',
        'ពពែ',
        'មាន់',
        'ទា',
        'ក្ងាន',
        'ក្រួច',
        'អណ្ដើក/កន្ឋាយ',
        'ត្រី',
        'កង្កែប',
        'ពស់',
        'ជន្លេន',
        'ផ្សេងៗ',
      ],
      'ជីនិងថ្នាំ': ['ទាំងអស់', 'ជី', 'ថ្នាំ', 'វីតាមីន', 'ចំណីសត្វ', 'ផ្សេងៗ'],

      'បន្លែផ្លែឈើ': [
        'ទាំងអស់',
        'បន្លែ',
        'ផ្លែឈើ',
        'គ្រឿងទេស',
        'អាហារផ្អាប់',
        'ស៊ុត',
        'ផ្សេងៗ',
      ],

      'ត្រីសាច់': [
        'ទាំងអស់',
        'ត្រី',
        'សាច់',
        'កង្កែប',
        'អណ្ដើក',
        'ពស់',
        'ក្ដាម',
        'ផ្សេងៗ',
      ],
      'សេវាកម្ម': [
        'ទាំងអស់',
        'សេវាកម្មសត្វ',
        'ដំណាំ',
        'ម៉ាស៊ីន',
        'គ្រឿងចក្រ',
        'ទឹក/ភ្លើង',
        'ហិរញ្ញវត្ថុ',
        'ច្បាប់',
        'ផ្សេងៗ',
      ],
      'ផ្សេងៗ': [
        'ទាំងអស់',
        'ដីកសិកម្ម',
        'កសិដ្ឋាន',
        'តំណាងចែកចាយ/ហ្វ្រែនឆាយ',
        'ផលិតផលឌីជីថល',
        'សៀវភៅកសិកម្ម',
        'ផ្សេងៗ',
      ],
    };

    final subData = subCategories[widget.category];
    if (subData == null) return const SizedBox.shrink();

    // ✅ បើជា Map (មាន 3 ជាន់)
    if (subData is Map) {
      final subList = subData.keys.cast<String>().toList();
      final subSubList =
          _selectedSubCategory != 'ទាំងអស់' &&
              subData.containsKey(_selectedSubCategory)
          ? subData[_selectedSubCategory] as List<String>?
          : null;

      return Column(
        children: [
          // Sub Category Row
          Container(
            height: 40,
            margin: const EdgeInsets.only(bottom: 4),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: subList.length,
              itemBuilder: (context, index) {
                final sub = subList[index];
                final isSelected = _selectedSubCategory == sub;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(
                      sub,
                      style: TextStyle(
                        fontFamily: 'Siemreap',
                        fontSize: 11,
                        color: isSelected ? Colors.white : Colors.black87,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedSubCategory = sub;
                        _selectedSubSubCategory = 'ទាំងអស់';
                      });
                    },
                    selectedColor: Colors.orange,
                    checkmarkColor: Colors.white,
                    backgroundColor: Colors.grey[100],
                    side: BorderSide(
                      color: isSelected ? Colors.orange : Colors.grey[300]!,
                    ),
                  ),
                );
              },
            ),
          ),

          // Sub-Sub Category Row (បង្ហាញតែពេលមាន)
          if (subSubList != null && subSubList.length > 1)
            Container(
              height: 40,
              margin: const EdgeInsets.only(bottom: 4),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: subSubList.length,
                itemBuilder: (context, index) {
                  final subSub = subSubList[index];
                  final isSelected = _selectedSubSubCategory == subSub;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text(
                        subSub,
                        style: TextStyle(
                          fontFamily: 'Siemreap',
                          fontSize: 11,
                          color: isSelected ? Colors.white : Colors.black87,
                        ),
                      ),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          _selectedSubSubCategory = subSub;
                        });
                      },
                      selectedColor: Colors.red,
                      checkmarkColor: Colors.white,
                      backgroundColor: Colors.grey[100],
                      side: BorderSide(
                        color: isSelected ? Colors.red : Colors.grey[300]!,
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      );
    }

    // ✅ បើជា List (មាន 2 ជាន់)
    if (subData is List) {
      final subs = subData.cast<String>();
      if (subs.length <= 1) return const SizedBox.shrink();

      return Container(
        height: 40,
        margin: const EdgeInsets.only(bottom: 4),
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: subs.length,
          itemBuilder: (context, index) {
            final sub = subs[index];
            final isSelected = _selectedSubCategory == sub;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(
                  sub,
                  style: TextStyle(
                    fontFamily: 'Siemreap',
                    fontSize: 12,
                    color: isSelected ? Colors.white : Colors.black87,
                  ),
                ),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    _selectedSubCategory = sub;
                  });
                },
                selectedColor: Colors.green,
                checkmarkColor: Colors.white,
                backgroundColor: Colors.grey[100],
                side: BorderSide(
                  color: isSelected ? Colors.green : Colors.grey[300]!,
                ),
              ),
            );
          },
        ),
      );
    }

    return const SizedBox.shrink();
  }

  int _stockQuantityValue(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString().replaceAll(',', '').trim() ?? '') ??
        0;
  }

  Future<void> _changeProductStock(
    String productId,
    Map<String, dynamic> data,
    int delta,
  ) async {
    if (_stockUpdatingIds.contains(productId)) return;
    final previous =
        _stockQuantityOverrides[productId] ??
        _stockQuantityValue(data['stock_quantity']);
    final optimistic = (previous + delta).clamp(0, 999999999).toInt();
    setState(() {
      _stockQuantityOverrides[productId] = optimistic;
      _stockUpdatingIds.add(productId);
    });

    final ref = FirebaseFirestore.instance
        .collection('products')
        .doc(productId);
    try {
      final newQuantity = await FirebaseFirestore.instance.runTransaction<int>((
        transaction,
      ) async {
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
          content: Text(
            appText(
              context,
              km: 'មិនអាចកែចំនួនស្តុកបានទេ',
              en: 'Could not update stock quantity.',
            ),
          ),
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
    final previous =
        _stockQuantityOverrides[productId] ??
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

    final ref = FirebaseFirestore.instance
        .collection('products')
        .doc(productId);
    try {
      final newQuantity = await FirebaseFirestore.instance.runTransaction<int>((
        transaction,
      ) async {
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
          content: Text(
            appText(context, km: 'បានកែចំនួនស្តុករួចរាល់', en: 'Stock updated'),
          ),
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
          content: Text(
            insufficient
                ? appText(
                    context,
                    km: 'មិនអាចកាត់លើសចំនួនស្តុកបានទេ',
                    en: 'Cannot deduct more than the available stock.',
                  )
                : appText(
                    context,
                    km: 'មិនអាចកែចំនួនស្តុកបានទេ',
                    en: 'Could not update stock quantity.',
                  ),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showBulkStockDialog(
    String productId,
    Map<String, dynamic> data,
  ) async {
    final current =
        _stockQuantityOverrides[productId] ??
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
            title: Text(
              appText(context, km: 'កែចំនួនស្តុក', en: 'Adjust stock'),
              style: const TextStyle(fontFamily: 'Siemreap'),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${appText(context, km: 'ស្តុកបច្ចុប្បន្ន', en: 'Current stock')}: ${formatter.format(current)}',
                    style: const TextStyle(
                      fontFamily: 'Siemreap',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      ChoiceChip(
                        label: Text(appText(context, km: 'កាត់', en: 'Deduct')),
                        selected: mode == 'deduct',
                        onSelected: (_) => setDialogState(() {
                          mode = 'deduct';
                          errorText = null;
                        }),
                      ),
                      ChoiceChip(
                        label: Text(appText(context, km: 'បន្ថែម', en: 'Add')),
                        selected: mode == 'add',
                        onSelected: (_) => setDialogState(() {
                          mode = 'add';
                          errorText = null;
                        }),
                      ),
                      ChoiceChip(
                        label: Text(
                          appText(context, km: 'កំណត់សល់', en: 'Set remaining'),
                        ),
                        selected: mode == 'set',
                        onSelected: (_) => setDialogState(() {
                          mode = 'set';
                          errorText = null;
                        }),
                      ),
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
                      labelText: appText(
                        context,
                        km: 'បញ្ចូលចំនួន',
                        en: 'Enter quantity',
                      ),
                      errorText: errorText,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      mode == 'deduct'
                          ? '${formatter.format(current)} − ${formatter.format(amount)} = ${formatter.format(preview)}'
                          : mode == 'add'
                          ? '${formatter.format(current)} + ${formatter.format(amount)} = ${formatter.format(preview)}'
                          : '${appText(context, km: 'ស្តុកថ្មី', en: 'New stock')}: ${formatter.format(preview)}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(appText(context, km: 'បោះបង់', en: 'Cancel')),
              ),
              ElevatedButton(
                onPressed: amountController.text.trim().isEmpty
                    ? null
                    : () {
                        if (mode == 'deduct' && amount > current) {
                          setDialogState(
                            () => errorText = appText(
                              context,
                              km: 'ចំនួនលើសស្តុកបច្ចុប្បន្ន',
                              en: 'Amount exceeds current stock',
                            ),
                          );
                          return;
                        }
                        Navigator.pop(dialogContext, {
                          'mode': mode,
                          'amount': amount,
                        });
                      },
                child: Text(appText(context, km: 'រក្សាទុក', en: 'Save')),
              ),
            ],
          );
        },
      ),
    );
    if (result == null) return;
    await _applyBulkStockChange(
      productId,
      data,
      result['mode'] as String,
      result['amount'] as int,
    );
  }

  Future<void> _setInitialProductStock(
    String productId,
    Map<String, dynamic> data,
  ) async {
    final quantityController = TextEditingController();
    final unitController = TextEditingController(
      text: (data['stock_unit'] ?? '').toString(),
    );
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          appText(context, km: 'កំណត់ស្តុក', en: 'Set stock'),
          style: const TextStyle(fontFamily: 'Siemreap'),
        ),
        content: Row(
          children: [
            Expanded(
              child: TextField(
                controller: quantityController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: appText(context, km: 'ចំនួន', en: 'Quantity'),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: unitController,
                decoration: InputDecoration(
                  labelText: appText(context, km: 'ឯកតា', en: 'Unit'),
                  hintText: appText(context, km: 'ដើម/គីឡូ', en: 'item/kg'),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(appText(context, km: 'បោះបង់', en: 'Cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              final quantity = int.tryParse(quantityController.text.trim());
              if (quantity == null || quantity < 0) return;
              Navigator.pop(dialogContext, {
                'quantity': quantity,
                'unit': unitController.text.trim(),
              });
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
      await FirebaseFirestore.instance
          .collection('products')
          .doc(productId)
          .update({
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
    final tracksStock =
        _stockQuantityOverrides.containsKey(productId) ||
        data['track_stock'] == true ||
        data['stock_quantity'] != null;
    if (!tracksStock) {
      return SizedBox(
        width: double.infinity,
        height: 30,
        child: OutlinedButton.icon(
          onPressed: () => _setInitialProductStock(productId, data),
          icon: const Icon(Icons.inventory_2_outlined, size: 15),
          label: Text(
            appText(context, km: 'កំណត់ស្តុក', en: 'Set stock'),
            style: const TextStyle(fontFamily: 'Siemreap', fontSize: 10),
          ),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            foregroundColor: Colors.green.shade700,
            side: BorderSide(color: Colors.green.shade200),
          ),
        ),
      );
    }
    final quantity =
        _stockQuantityOverrides[productId] ??
        _stockQuantityValue(data['stock_quantity']);
    final isUpdating = _stockUpdatingIds.contains(productId);
    Widget stockButton(IconData icon, VoidCallback? onPressed) =>
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: onPressed == null
                  ? Colors.grey.shade100
                  : Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 17,
              color: onPressed == null ? Colors.grey : Colors.green.shade700,
            ),
          ),
        );
    return Row(
      children: [
        stockButton(
          Icons.remove,
          quantity > 0 && !isUpdating
              ? () => _changeProductStock(productId, data, -1)
              : null,
        ),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: isUpdating
                ? null
                : () => _showBulkStockDialog(productId, data),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      '${appText(context, km: 'ស្តុក', en: 'Stock')}: ${NumberFormat('#,###').format(quantity)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Siemreap',
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: quantity == 0 ? Colors.red : Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(width: 3),
                  const Icon(Icons.edit_outlined, size: 12, color: Colors.grey),
                ],
              ),
            ),
          ),
        ),
        stockButton(
          Icons.add,
          isUpdating ? null : () => _changeProductStock(productId, data, 1),
        ),
      ],
    );
  }

  // ── PRODUCT CARD ────────────────────────────────────────
  Widget _buildProductCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final String docId = doc.id;

    final String postType = _managePostType(doc);
    final bool isWanted = postType == 'wanted';
    final bool isPreOrder = postType == 'preorder';

    // 🎯 កំណត់តម្លៃចាក់សោដំបូង
    bool currentLockStatus = data['is_locked'] ?? false;
    final bool? shippingIncluded = data['shipping_included'];

    final String name = isWanted
        ? (data['productName'] ?? appText(context, km: 'គ្មានឈ្មោះ', en: 'Unnamed product'))
        : (data['product_name'] ?? appText(context, km: 'គ្មានឈ្មោះ', en: 'Unnamed product'));
    final String price = (data['price'] ?? '0').toString();
    final String location = (data['location'] ?? 'ភ្នំពេញ').toString();
    final dynamic timestamp =
        data['created_at'] ?? data['savedAt'] ?? data['createdAt'];

    String imageUrl = "";
    final urls = data['imageUrls'] ?? data['image_urls'];
    if (urls is List && urls.isNotEmpty) {
      imageUrl = urls[0].toString();
    } else if (data['imageUrl'] != null) {
      imageUrl = data['imageUrl'].toString();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isSmallCard = constraints.maxWidth < 200;

        return GestureDetector(
          onTap: () =>
              _onProductTap(docId, data, isWanted, isPreOrder: isPreOrder),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 🖼 ផ្នែករូបភាព
                    // 🖼 ផ្នែករូបភាព (ជាមួយ Play icon បើមានវីដេអូ)
                    Expanded(
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(12),
                            ),
                            child: imageUrl.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: imageUrl,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    memCacheHeight: 350,
                                    maxWidthDiskCache: 500,
                                    placeholder: (context, url) =>
                                        Container(color: Colors.grey[100]),
                                    errorWidget: (context, url, error) =>
                                        const Icon(
                                          Icons.broken_image,
                                          color: Colors.grey,
                                        ),
                                  )
                                : Container(
                                    color: Colors.grey[100],
                                    child: const Icon(
                                      Icons.image_not_supported,
                                      color: Colors.grey,
                                    ),
                                  ),
                          ),
                          // ✅ បង្ហាញ Play Icon បើមាន video_url
                          if (data['video_url'] != null &&
                              data['video_url'].toString().isNotEmpty)
                            Positioned(
                              bottom: 4,
                              right: 4,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                padding: const EdgeInsets.all(4),
                                child: const Icon(
                                  Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          // ✅ បង្ហាញ Verified Badge បើ shop_tier មាន basic ឬ premium
                          if (data['shop_tier'] != null &&
                              (data['shop_tier'] == 'basic' ||
                                  data['shop_tier'] == 'premium'))
                            Positioned(
                              bottom: 4,
                              left: 4,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: data['shop_tier'] == 'premium'
                                      ? Colors.amber.withOpacity(0.8)
                                      : Colors.blueAccent.withOpacity(0.8),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  data['shop_tier'] == 'premium'
                                      ? Icons.diamond_rounded
                                      : Icons.verified_user_rounded,
                                  color: Colors.white,
                                  size: 14,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    // 📝 ផ្នែកព័ត៌មានអត្ថបទ
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: isSmallCard ? 12 : 14,
                              fontFamily: 'Siemreap',
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(
                                Icons.access_time,
                                size: 10,
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                _formatTimeAgo(timestamp),
                                style: const TextStyle(
                                  fontSize: 9,
                                  color: Colors.grey,
                                  fontFamily: 'Siemreap',
                                ),
                              ),
                              const Text(
                                " • ",
                                style: TextStyle(
                                  fontSize: 9,
                                  color: Colors.grey,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  location,
                                  style: const TextStyle(
                                    fontSize: 9,
                                    color: Colors.grey,
                                    fontFamily: 'Siemreap',
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "$price ៛",
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              if (!isWanted)
                                _buildCartButton(
                                  data,
                                  docId,
                                  currentLockStatus,
                                  shippingIncluded,
                                )
                              else
                                const Icon(
                                  Icons.info_outline,
                                  color: Colors.orange,
                                  size: 18,
                                ),
                            ],
                          ),

                          if (widget.category == 'ទំនិញរបស់ខ្ញុំ' &&
                              postType == 'sale') ...[
                            const SizedBox(height: 6),
                            _buildInlineStockControl(docId, data),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),

                // 🔘 ផ្នែក Switch ស្ទីល iOS (បៃតង=បើក, ប្រផេះ=បិទ) + Snackbars
                if (widget.category == "ទំនិញរបស់ខ្ញុំ" && postType == 'sale')
                  Positioned(
                    top: 8,
                    left: 8,
                    child: StatefulBuilder(
                      builder: (context, setLocalState) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // បង្ហាញអក្សរ បើក ឬ បិទ នៅខាងលើ Switch
                            Text(
                              currentLockStatus ? "បើក" : "បិទ",
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: currentLockStatus
                                    ? Colors.green
                                    : Colors.grey[600],
                                fontFamily: 'Siemreap',
                              ),
                            ),
                            const SizedBox(height: 2),
                            Transform.scale(
                              scale: 0.75, // ទំហំសមល្មមសម្រាប់ Card
                              child: Switch.adaptive(
                                value: currentLockStatus,
                                // 🎯 បើបើកសោរ (True) ចេញពណ៌បៃតង, បើបិទ (False) ចេញពណ៌ប្រផេះ
                                activeColor: Colors.green,
                                activeTrackColor: Colors.green.withOpacity(0.3),
                                inactiveThumbColor: Colors.white,
                                inactiveTrackColor: Colors.grey[400],
                                onChanged: (bool newValue) async {
                                  // ១. Update UI ភ្លាមៗ
                                  setLocalState(
                                    () => currentLockStatus = newValue,
                                  );
                                  data['is_locked'] = newValue;

                                  try {
                                    // ២. Update ទៅ Firebase
                                    await FirebaseFirestore.instance
                                        .collection(
                                          isWanted
                                              ? 'wanted_products'
                                              : 'products',
                                        )
                                        .doc(docId)
                                        .update({'is_locked': newValue});

                                    // ៣. បង្ហាញ Snackbar តាមមេចង់បាន
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          newValue
                                              ? "បិទលក់តាមកន្ត្រក់"
                                              : "បើកការលក់តាមកន្ត្រក់",
                                          style: const TextStyle(
                                            fontFamily: 'Siemreap',
                                          ),
                                        ),
                                        duration: const Duration(seconds: 1),
                                        backgroundColor: newValue
                                            ? Colors.grey[700]
                                            : Colors.green,
                                      ),
                                    );
                                  } catch (e) {
                                    setLocalState(
                                      () => currentLockStatus = !newValue,
                                    );
                                    data['is_locked'] = !newValue;
                                  }
                                },
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                // 🛠 ផ្នែកប៊ូតុង កែប្រែ/លុប (បង្ហាញរហូតក្នុង Screen នេះ មិនបាច់ឆែកលក្ខខណ្ឌនាំភ្លាត់)
                if (widget.category == "ទំនិញរបស់ខ្ញុំ" && postType == 'sale')
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // ១. ប៊ូតុង Edit (ពណ៌ខៀវ)
                        if (!isWanted && !isPreOrder) // normal sale only
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => EditProductScreen(
                                    productId: docId,
                                    productData: data,
                                    isWanted: isWanted,
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.9),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 3,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.edit,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        const SizedBox(width: 8),

                        // ២. ប៊ូតុង Delete (ពណ៌ក្រហម)
                        GestureDetector(
                          onTap: () => _showDeleteConfirm(
                            docId,
                            isWanted,
                            isPreOrder: isPreOrder,
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.9),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(color: Colors.black26, blurRadius: 3),
                              ],
                            ),
                            child: const Icon(
                              Icons.delete,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
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

  // ── CART BUTTON ─────────────────────────────────────────
  Widget _buildCartButton(
    Map<String, dynamic> data,
    String docId,
    bool isLocked,
    bool? shippingIncluded,
  ) {
    final disabled =
        isLocked || data['shop_closed'] == true || shippingIncluded == false;
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

  // ── LOCK SWITCH ─────────────────────────────────────────
  Widget _buildLockSwitch(
    String docId,
    Map<String, dynamic> data,
    bool isWanted,
    bool isLocked,
  ) {
    return Positioned(
      top: 8,
      left: 8,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isLocked ? Icons.lock : Icons.lock_open,
              size: 14,
              color: isLocked ? Colors.red : Colors.green,
            ),
            const SizedBox(width: 4),
            SizedBox(
              width: 35,
              height: 20,
              child: Switch(
                value: !isLocked,
                onChanged: (value) =>
                    _toggleLock(docId, data, isWanted, isLocked),
                activeColor: Colors.green,
                inactiveThumbColor: Colors.red,
                inactiveTrackColor: Colors.red[200],
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleLock(
    String docId,
    Map<String, dynamic> data,
    bool isWanted,
    bool currentStatus,
  ) async {
    setState(() {
      data['is_locked'] = !currentStatus;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          !currentStatus ? "🔒 ចាក់សោរទំនិញរួចរាល់" : "🔓 បើកសោរវិញរួចរាល់",
          style: const TextStyle(fontFamily: 'Siemreap'),
        ),
        duration: const Duration(milliseconds: 800),
      ),
    );

    try {
      await FirebaseFirestore.instance
          .collection(isWanted ? 'wanted_products' : 'products')
          .doc(docId)
          .update({'is_locked': !currentStatus});
    } catch (e) {
      setState(() => data['is_locked'] = currentStatus);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("ការតភ្ជាប់មានបញ្ហា! សូមព្យាយាមម្តងទៀត")),
      );
    }
  }

  // ── OWNER TOOLS ─────────────────────────────────────────
  Widget _buildOwnerTools(
    String docId,
    Map<String, dynamic> data,
    bool isWanted, {
    bool isPreOrder = false,
  }) {
    return Positioned(
      top: 8,
      right: 8,
      child: Row(
        children: [
          if (!isWanted)
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EditProductScreen(
                      productId: docId,
                      productData: data,
                      isWanted: isWanted,
                      currentUserId: _currentUserId,
                    ),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: const BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.edit, color: Colors.white, size: 16),
              ),
            ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () =>
                _showDeleteConfirm(docId, isWanted, isPreOrder: isPreOrder),
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: const BoxDecoration(
                color: Colors.redAccent,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delete, color: Colors.white, size: 16),
            ),
          ),
        ],
      ),
    );
  }

  void _onProductTap(
    String docId,
    Map<String, dynamic> data,
    bool isWanted, {
    bool isPreOrder = false,
  }) {
    final productWithId = Map<String, dynamic>.from(data);
    productWithId['id'] = docId;
    productWithId['isWanted'] = isWanted;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => isPreOrder
            ? PreOrderDetailScreen(documentId: docId, data: productWithId)
            : isWanted
            ? WantedDetailScreen(data: productWithId)
            : ProductDetailScreen(product: productWithId),
      ),
    );
  }

  void _showDeleteConfirm(
    String docId,
    bool isWanted, {
    bool isPreOrder = false,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("លុបទំនិញ"),
        content: const Text("តើបងពិតជាចង់លុបទំនិញនេះមែនទេ?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("ទេ"),
          ),
          TextButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection(
                    isPreOrder
                        ? 'pre_orders'
                        : isWanted
                        ? 'wanted_products'
                        : 'products',
                  )
                  .doc(docId)
                  .delete();
              Navigator.pop(context);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text("លុបទំនិញជោគជ័យ!")));
            },
            child: const Text("លុប", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // ── ADD TO CART ─────────────────────────────────────────
  Future<void> _fastAddToCart(
    Map<String, dynamic> product,
    String productId,
  ) async {
    if (_currentUserId == null || productId.isEmpty) return;
    if (_cartProductIds.contains(productId) ||
        _cartAddingIds.contains(productId))
      return;
    if (mounted) setState(() => _cartAddingIds.add(productId));

    final urls = product['image_urls'] ?? product['imageUrls'];
    final String finalImageUrl =
        product['image_url']?.toString() ??
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
        'product_name': product['product_name'] ?? appText(context, km: 'គ្មានឈ្មោះ', en: 'Unnamed product'),
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
            content: Text(
              appText(
                context,
                km: '✅ បន្ថែមទៅកន្ត្រករួចរាល់!',
                en: '✅ Added to cart!',
              ),
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _cartAddingIds.remove(productId));
      debugPrint('Add to Cart Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${appText(context, km: '❌ បរាជ័យ', en: '❌ Failed')}: $e',
            ),
          ),
        );
      }
    }
  }

  Future<void> _removeFromCart(String productId) async {
    final uid = _currentUserId;
    if (uid == null ||
        uid.isEmpty ||
        productId.isEmpty ||
        _cartAddingIds.contains(productId))
      return;
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
            content: Text(
              appText(
                context,
                km: '↩️ បានដកចេញពីកន្ត្រក',
                en: '↩️ Removed from cart',
              ),
            ),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _cartAddingIds.remove(productId));
      debugPrint('Remove from cart error: $e');
    }
  }

  // ── FORMAT TIME AGO (នៅក្នុង class ឥឡូវ) ─────────────────
  String _formatTimeAgo(dynamic timestamp) {
    if (timestamp == null) return "មុននេះបន្តិច";

    DateTime date;
    if (timestamp is Timestamp) {
      date = timestamp.toDate();
    } else if (timestamp is DateTime) {
      date = timestamp;
    } else {
      return "មុននេះបន្តិច";
    }

    final Duration diff = DateTime.now().difference(date);

    if (diff.inMinutes < 1) return "មុននេះបន្តិច";
    if (diff.inMinutes < 60) return "${diff.inMinutes} នាទីមុន";
    if (diff.inHours < 24) return "${diff.inHours} ម៉ោងមុន";
    if (diff.inDays < 7) return "${diff.inDays} ថ្ងៃមុន";
    return "${date.day}/${date.month}/${date.year}";
  }

  @override
  void dispose() {
    _cartSubscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }
}
