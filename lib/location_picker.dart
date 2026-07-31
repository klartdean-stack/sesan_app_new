import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';


/// =======================================================
///  CAMBODIA LOCATION PICKER PRO - REBORN
///  កែលម្អទាំងស្រុងជាមួយនឹង UI ទំនើប និងងាយស្រួលប្រើ
/// =======================================================


class LocationResult {
  final String province;
  final String district;
  final String commune;


  LocationResult({
    required this.province,
    required this.district,
    required this.commune,
  });


  @override
  String toString() {
    if (district.isEmpty && commune.isEmpty) return province;
    if (commune.isEmpty) return "$province, $district";
    return "$province, $district, $commune";
  }
}


/// =======================================================
/// SERVICE
/// =======================================================


class CambodiaLocationService {
  static Map<String, dynamic> _data = {};


  static Future<void> load() async {
    try {
      final jsonString = await rootBundle.loadString(
        'assets/json/cambodia_locations.json',
      );
      _data = json.decode(jsonString);
    } catch (e) {
      _data = {};
    }
  }


  static List<String> getProvinces() {
    return _data.keys.toList();
  }


  static List<String> getDistricts(String province) {
    if (!_data.containsKey(province)) return [];
    return (_data[province] as Map<String, dynamic>).keys.toList();
  }


  static List<String> getCommunes(String province, String district) {
    if (!_data.containsKey(province)) return [];
    final districts = _data[province] as Map<String, dynamic>;
    if (!districts.containsKey(district)) return [];
    return List<String>.from(districts[district]);
  }


  static List<LocationResult> search(String query) {
    final results = <LocationResult>[];
    if (query.trim().isEmpty) return results;


    for (final province in _data.keys) {
      final districts = _data[province] as Map<String, dynamic>;
      for (final district in districts.keys) {
        final communes = List<String>.from(districts[district]);
        for (final commune in communes) {
          final fullText = "$province $district $commune".toLowerCase();
          if (fullText.contains(query.toLowerCase())) {
            results.add(
              LocationResult(
                province: province,
                district: district,
                commune: commune,
              ),
            );
          }
        }
      }
    }
    return results;
  }
}


/// =======================================================
/// MAIN PICKER FUNCTION
/// =======================================================


Future<void> showLocationPicker(
    BuildContext context, {
      required Function(LocationResult location) onSelected,
    }) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    enableDrag: true,
    builder: (_) {
      return LocationPickerSheet(onSelected: onSelected);
    },
  );
}


/// =======================================================
/// LOCATION PICKER SHEET - REBORN UI
/// =======================================================


class LocationPickerSheet extends StatefulWidget {
  final Function(LocationResult location) onSelected;


  const LocationPickerSheet({super.key, required this.onSelected});


  @override
  State<LocationPickerSheet> createState() => _LocationPickerSheetState();
}


class _LocationPickerSheetState extends State<LocationPickerSheet>
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _manualController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final FocusNode _manualFocus = FocusNode();


  String? selectedProvince;
  String? selectedDistrict;
  String searchQuery = "";
  bool showManualInput = false;
  int _currentStep = 0; // 0: Province, 1: District, 2: Commune


  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(1.0, 0.0), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _slideController,
            curve: Curves.easeInOutCubic,
          ),
        );
  }


  @override
  void dispose() {
    _searchController.dispose();
    _manualController.dispose();
    _searchFocus.dispose();
    _manualFocus.dispose();
    _slideController.dispose();
    super.dispose();
  }


  void _goToStep(int step, {String? province, String? district}) {
    setState(() {
      _currentStep = step;
      if (province != null) selectedProvince = province;
      if (district != null) selectedDistrict = district;
      showManualInput = false;
      _manualController.clear();
    });
    _slideController.forward(from: 0.0);
  }


  void _goBack() {
    if (_currentStep == 2) {
      _goToStep(1);
    } else if (_currentStep == 1) {
      _goToStep(0);
      selectedProvince = null;
    }
  }


  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      expand: false,
      builder: (_, controller) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            boxShadow: [
              BoxShadow(color: Colors.black12, blurRadius: 20, spreadRadius: 5),
            ],
          ),
          child: Column(
            children: [
              // Handle Bar
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 20),


              // Header Section
              _buildHeader(),


              const SizedBox(height: 16),


              // Search or Manual Input
              _buildInputSection(),


              const SizedBox(height: 16),


              // Breadcrumb Navigation
              if (_currentStep > 0) _buildBreadcrumb(),


              const SizedBox(height: 8),


              // Content Area with Animation
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: _buildContent(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }


  /// =======================================================
  /// HEADER
  /// =======================================================


  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          if (_currentStep > 0)
            IconButton(
              onPressed: _goBack,
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.arrow_back_ios_new, size: 18),
              ),
            )
          else
            const SizedBox(width: 48),


          Expanded(
            child: Column(
              children: [
                Text(
                  _getTitle(),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getSubtitle(),
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),


          // Close Button
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.close, size: 18),
            ),
          ),
        ],
      ),
    );
  }


  String _getTitle() {
    if (searchQuery.isNotEmpty) return "🔍 លទ្ធផលស្វែងរក";
    if (showManualInput) return "✍️ បញ្ចូលដៃ";
    if (_currentStep == 0) return "📍 ជ្រើសខេត្ត";
    if (_currentStep == 1) return "🏘️ ជ្រើសស្រុក";
    return "🏡 ជ្រើសឃុំ/សង្កាត់";
  }


  String _getSubtitle() {
    if (searchQuery.isNotEmpty)
      return "រកឃើញ ${_getSearchResults().length} ទីតាំង";
    if (showManualInput) return "បញ្ចូលទីតាំងតាមបំណងរបស់អ្នក";
    if (_currentStep == 0) return "ជ្រើសរើសខេត្ត/ក្រុងដែលអ្នកចង់បាន";
    if (_currentStep == 1) return "ក្នុងខេត្ត $selectedProvince";
    return "ក្នុងស្រុក $selectedDistrict";
  }


  /// =======================================================
  /// INPUT SECTION (Search + Manual Toggle)
  /// =======================================================


  Widget _buildInputSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // Search Bar
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocus,
              onChanged: (v) {
                setState(() {
                  searchQuery = v;
                  showManualInput = false;
                });
              },
              decoration: InputDecoration(
                hintText: "ស្វែងរក ខេត្ត ស្រុក ឬ ឃុំ...",
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 15),
                prefixIcon: Icon(Icons.search, color: Colors.grey.shade400),
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => searchQuery = "");
                    _searchFocus.requestFocus();
                  },
                )
                    : null,
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(
                    color: Color(0xFF4CAF50),
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
          ),


          // Toggle Manual Input (only when not searching)
          if (searchQuery.isEmpty)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(top: 12),
              child: InkWell(
                onTap: () {
                  setState(() {
                    showManualInput = !showManualInput;
                    if (showManualInput) {
                      _manualFocus.requestFocus();
                    } else {
                      _manualController.clear();
                    }
                  });
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: showManualInput
                        ? const Color(0xFFE8F5E9)
                        : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: showManualInput
                          ? const Color(0xFF4CAF50)
                          : Colors.grey.shade200,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        showManualInput ? Icons.edit : Icons.edit_note,
                        size: 20,
                        color: showManualInput
                            ? const Color(0xFF4CAF50)
                            : Colors.grey.shade600,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              showManualInput
                                  ? "បិទការបញ្ចូលដៃ"
                                  : "បញ្ចូលទីតាំងដៃ",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: showManualInput
                                    ? const Color(0xFF4CAF50)
                                    : Colors.grey.shade700,
                              ),
                            ),
                            if (!showManualInput)
                              Text(
                                "វាយបញ្ចូលទីតាំងតាមចិត្តអ្នក",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Icon(
                        showManualInput
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        color: Colors.grey.shade400,
                      ),
                    ],
                  ),
                ),
              ),
            ),


          // Manual Input Field (Inline - No Dialog!)
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            child: showManualInput && searchQuery.isEmpty
                ? Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "វាយបញ្ចូលទីតាំង",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _manualController,
                    focusNode: _manualFocus,
                    maxLines: 2,
                    style: const TextStyle(fontSize: 15),
                    decoration: InputDecoration(
                      hintText: _getManualHint(),
                      hintStyle: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 14,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFF4CAF50),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        final text = _manualController.text.trim();
                        if (text.isNotEmpty) {
                          LocationResult result;
                          if (_currentStep == 0) {
                            result = LocationResult(
                              province: text,
                              district: "",
                              commune: "",
                            );
                          } else if (_currentStep == 1) {
                            result = LocationResult(
                              province: selectedProvince!,
                              district: text,
                              commune: "",
                            );
                          } else {
                            result = LocationResult(
                              province: selectedProvince!,
                              district: selectedDistrict!,
                              commune: text,
                            );
                          }
                          widget.onSelected(result);
                          Navigator.pop(context);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4CAF50),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        "បញ្ជាក់ទីតាំង",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }


  String _getManualHint() {
    if (_currentStep == 0) return "ឧទាហរណ៍៖ ភ្នំពេញ, បាត់ដំបង...";
    if (_currentStep == 1) return "ឧទាហរណ៍៖ ស្រុកពញាឮ, ស្រុកមង្គលបូរី...";
    return "ឧទាហរណ៍៖ ឃុំទួលពង្រ, សង្កាត់ទន្លេបាសាក់...";
  }


  /// =======================================================
  /// BREADCRUMB
  /// =======================================================


  Widget _buildBreadcrumb() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.location_on, size: 16, color: Colors.grey.shade500),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _currentStep == 1
                    ? selectedProvince!
                    : "$selectedProvince  >  $selectedDistrict",
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }


  /// =======================================================
  /// CONTENT BUILDER
  /// =======================================================


  Widget _buildContent() {
    if (searchQuery.isNotEmpty) {
      return _buildSearchResults();
    }


    switch (_currentStep) {
      case 0:
        return _buildProvinceList();
      case 1:
        return _buildDistrictList();
      case 2:
        return _buildCommuneList();
      default:
        return _buildProvinceList();
    }
  }


  List<LocationResult> _getSearchResults() {
    return CambodiaLocationService.search(searchQuery);
  }


  /// =======================================================
  /// SEARCH RESULTS
  /// =======================================================


  Widget _buildSearchResults() {
    final results = _getSearchResults();


    if (results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              "រកមិនឃើញទីតាំង",
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "សូមព្យាយាមវាយឈ្មោះផ្សេងទៀត",
              style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
            ),
          ],
        ),
      );
    }


    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: results.length,
      itemBuilder: (_, index) {
        final item = results[index];
        return _LocationCard(
          title: item.commune,
          subtitle: "${item.province}  •  ${item.district}",
          icon: Icons.location_on,
          iconColor: const Color(0xFF4CAF50),
          onTap: () {
            widget.onSelected(item);
            Navigator.pop(context);
          },
          isLast: index == results.length - 1,
        );
      },
    );
  }


  /// =======================================================
  /// PROVINCE LIST
  /// =======================================================


  Widget _buildProvinceList() {
    final provinces = CambodiaLocationService.getProvinces();


    if (provinces.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }


    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: provinces.length,
      itemBuilder: (_, index) {
        final province = provinces[index];
        return _LocationCard(
          title: province,
          icon: Icons.map_outlined,
          iconColor: const Color(0xFF2196F3),
          onTap: () => _goToStep(1, province: province),
          isLast: index == provinces.length - 1,
        );
      },
    );
  }


  /// =======================================================
  /// DISTRICT LIST
  /// =======================================================


  Widget _buildDistrictList() {
    final districts = CambodiaLocationService.getDistricts(selectedProvince!);


    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: districts.length,
      itemBuilder: (_, index) {
        final district = districts[index];
        return _LocationCard(
          title: district,
          icon: Icons.location_city_outlined,
          iconColor: const Color(0xFFFF9800),
          onTap: () => _goToStep(2, district: district),
          isLast: index == districts.length - 1,
        );
      },
    );
  }


  /// =======================================================
  /// COMMUNE LIST
  /// =======================================================


  Widget _buildCommuneList() {
    final communes = CambodiaLocationService.getCommunes(
      selectedProvince!,
      selectedDistrict!,
    );


    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: communes.length,
      itemBuilder: (_, index) {
        final commune = communes[index];
        return _LocationCard(
          title: commune,
          icon: Icons.home_outlined,
          iconColor: const Color(0xFF9C27B0),
          onTap: () {
            widget.onSelected(
              LocationResult(
                province: selectedProvince!,
                district: selectedDistrict!,
                commune: commune,
              ),
            );
            Navigator.pop(context);
          },
          isLast: index == communes.length - 1,
        );
      },
    );
  }
}


/// =======================================================
/// MODERN LOCATION CARD
/// =======================================================


class _LocationCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;
  final bool isLast;


  const _LocationCard({
    required this.title,
    this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.onTap,
    this.isLast = false,
  });


  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: isLast ? 20 : 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade100),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade100,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Icon Container
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
                const SizedBox(width: 16),


                // Text Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      if (subtitle != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            subtitle!,
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 13,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),


                // Arrow
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


/// =======================================================
/// EXAMPLE SCREEN
/// =======================================================


class ExampleLocationScreen extends StatefulWidget {
  const ExampleLocationScreen({super.key});


  @override
  State<ExampleLocationScreen> createState() => _ExampleLocationScreenState();
}


class _ExampleLocationScreenState extends State<ExampleLocationScreen> {
  String selectedLocation = "មិនទាន់ជ្រើសទីតាំង";
  bool isLoading = true;


  @override
  void initState() {
    super.initState();
    _loadData();
  }


  Future<void> _loadData() async {
    await CambodiaLocationService.load();
    setState(() => isLoading = false);
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text(
          "ជ្រើសរើសទីតាំង",
          style: TextStyle(
            color: Color(0xFF1A1A1A),
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFF1A1A1A)),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Location Display Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Icon(
                        Icons.location_on,
                        size: 40,
                        color: Color(0xFF4CAF50),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      "ទីតាំងបច្ចុប្បន្ន",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      selectedLocation,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),


              // Select Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    showLocationPicker(
                      context,
                      onSelected: (location) {
                        setState(() {
                          selectedLocation = location.toString();
                        });
                      },
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.map_outlined),
                      SizedBox(width: 12),
                      Text(
                        "ជ្រើសរើសទីតាំង",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}



