import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:my_app/location_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';


class AddPreOrderScreen extends StatefulWidget {
  const AddPreOrderScreen({super.key});


  @override
  State<AddPreOrderScreen> createState() => _AddPreOrderScreenState();
}


class _AddPreOrderScreenState extends State<AddPreOrderScreen> {
  final _formKey = GlobalKey<FormState>();


  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _locationController =
  TextEditingController(); // ✅ fix
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();


  List<File> _images = [];
  String? _selectedUnit;
  String? currentUid;
  bool _isUploading = false;


  final List<String> _units = [
    'គីឡូក្រាម (Kg)',
    'តោន (Ton)',
    'ហិកតា (Ha)',
    'គ្រឿង',
    'ផ្លែ',
    'កាន',
    'ធុង',
    'ដើម',
    'បាច់',
    'បាវ',
    'ស្រះ',
    'កញ្ចប់',
    'ឡូ',
    'ដុំ',
    'ម៉ែត្រ',
    'លីត្រ',
    'ផ្សេងៗ',
  ];


  @override
  void initState() {
    super.initState();
    _loadCurrentUid();
    CambodiaLocationService.load();
  }


  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    _descController.dispose();
    _dateController.dispose();
    super.dispose();
  }


  Future<void> _loadCurrentUid() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getString('user_uid') ?? '';
    if (mounted) setState(() => currentUid = uid.isNotEmpty ? uid : null);
  }


  Future<void> _pickImages() async {
    final List<XFile> pickedFiles = await ImagePicker().pickMultiImage();
    if (pickedFiles.isEmpty) return;


    if (_images.length + pickedFiles.length > 7) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('អាចដាក់រូបភាពបានច្រើនបំផុតត្រឹម ៧ សន្លឹក'),
          ),
        );
      }
      return;
    }


    for (var file in pickedFiles) {
      File compressed = await _compressImage(File(file.path));
      if (mounted) setState(() => _images.add(compressed));
    }
  }


  Future<File> _compressImage(File file) async {
    final tempDir = await getTemporaryDirectory();
    final path =
        '${tempDir.path}/img_${DateTime.now().millisecondsSinceEpoch}.jpg';
    var result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      path,
      quality: 60,
    );
    return File(result!.path);
  }


  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        _dateController.text = DateFormat('dd-MM-yyyy').format(picked);
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'ចុះឈ្មោះលក់មុន',
          style: TextStyle(fontFamily: 'Siemreap', fontSize: 18),
        ),
        backgroundColor: Colors.orange[800],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.translucent,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              // ── រូបភាព ─────────────────────────────────────
              _buildSectionTitle('រូបភាពផលិតផល (យ៉ាងតិច ១ សន្លឹក)'),
              const SizedBox(height: 10),
              _buildImageArea(),
              const SizedBox(height: 20),


              // ── ព័ត៌មានលម្អិត ────────────────────────────────
              _buildSectionTitle('ព័ត៌មានលម្អិត'),
              const SizedBox(height: 10),


              _buildTextField(
                _nameController,
                'ឈ្មោះផលិតផល',
                'ឧ. ស្វាយកែវរមៀត...',
                Icons.inventory_2_outlined,
              ),


              // តម្លៃ + ឯកតា
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: _buildTextField(
                      _priceController,
                      'តម្លៃជាលុយរៀល',
                      '0.00',
                      Icons.sell_outlined,
                      isNumber: true,
                      isPrice: true,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(flex: 1, child: _buildUnitDropdown()),
                ],
              ),


              // ថ្ងៃប្រមូលផល
              GestureDetector(
                onTap: () => _selectDate(context),
                child: AbsorbPointer(
                  child: _buildTextField(
                    _dateController,
                    'ថ្ងៃប្រមូលផល',
                    'ជ្រើសរើសថ្ងៃ',
                    Icons.calendar_today_outlined,
                  ),
                ),
              ),


              /// ROW ទីតាំង និង MAP
              Row(
                children: [
                  /// =========================
                  /// LOCATION PICKER (កែឱ្យត្រូវជាមួយ _locationController)
                  /// =========================
                  Expanded(
                    flex: 3,
                    child: InkWell(
                      onTap: () {
                        showLocationPicker(
                          context,
                          onSelected: (location) {
                            setState(() {
                              // ✅ កែឈ្មោះទៅជា _locationController ឱ្យត្រូវតាម Variable ខាងលើ
                              _locationController.text = location.toString();
                            });
                          },
                        );
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 15,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors
                                .grey
                                .shade300, // ពណ៌ឱ្យស៊ីជាមួយ TextField ផ្សេងទៀត
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons
                                  .location_on_outlined, // ប្រើ Icon បែប Outlined ឱ្យស៊ីជាមួយស្ទាយថ្មី
                              color: Colors
                                  .orange
                                  .shade800, // ប្រើពណ៌ទឹកក្រូចឱ្យស៊ីជាមួយ AppBar
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _locationController.text.isEmpty
                                    ? "ជ្រើសរើសទីតាំង *"
                                    : _locationController.text,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontFamily: 'Siemreap',
                                  color: _locationController.text.isEmpty
                                      ? Colors.grey.shade600
                                      : Colors.black87,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),


                  const SizedBox(width: 10),


                  /// =========================
                  /// MAP BUTTON (Disabled)
                  /// =========================
                  Expanded(
                    flex: 1,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.map_outlined,
                            color: Colors.grey.shade400,
                            size: 20,
                          ),
                          const Text(
                            "Map",
                            style: TextStyle(fontSize: 10, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16), // ថែមឃ្លាតបន្តិចមុនចូលលេខទូរស័ព្ទ


              _buildTextField(
                _phoneController,
                'លេខទូរស័ព្ទ',
                '012 345 xxx',
                Icons.phone_android_outlined,
                isNumber: true,
              ),


              _buildTextField(
                _descController,
                'ការពិពណ៌នា និងលក្ខខណ្ឌផ្សេងៗ',
                'រៀបរាប់ពីផលិតផលរបស់អ្នក...',
                Icons.notes,
                maxLines: 4,
              ),
              const SizedBox(height: 30),
              _buildSubmitButton(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
        ),
    );
  }


  // ── Section Title ──────────────────────────────────────────
  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 15,
        fontFamily: 'Siemreap',
      ),
    );
  }


  // ── Image Area ─────────────────────────────────────────────
  Widget _buildImageArea() {
    return SizedBox(
      height: 110,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _images.length + 1,
        itemBuilder: (context, index) {
          if (index == _images.length) {
            return GestureDetector(
              onTap: _pickImages,
              child: Container(
                width: 100,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.orange.withOpacity(0.5),
                    style: BorderStyle.solid,
                  ),
                ),
                child: const Icon(
                  Icons.add_a_photo_outlined,
                  color: Colors.orange,
                  size: 30,
                ),
              ),
            );
          }
          return Stack(
            children: [
              Container(
                width: 100,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  image: DecorationImage(
                    image: FileImage(_images[index]),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned(
                top: 5,
                right: 15,
                child: GestureDetector(
                  onTap: () => setState(() => _images.removeAt(index)),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }


  // ── TextField ──────────────────────────────────────────────
  Widget _buildTextField(
      TextEditingController controller,
      String label,
      String hint,
      IconData icon, {
        bool isNumber = false,
        bool isPrice = false, // ✅ បន្ថែមសម្រាប់ប្រអប់តម្លៃ
        int maxLines = 1,
      }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        maxLines: maxLines,
        inputFormatters: isPrice
            ? [ThousandsSeparatorInputFormatter()]
            : null, // ✅ បន្ថែម
        style: const TextStyle(fontFamily: 'Siemreap', fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, size: 20),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.orange.shade400, width: 2),
          ),
        ),
        validator: (value) => value!.isEmpty ? 'សូមបញ្ចូលព័ត៌មាន' : null,
      ),
    );
  }


  // ── Unit Dropdown ──────────────────────────────────────────
  Widget _buildUnitDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      margin: const EdgeInsets.only(bottom: 16),
      height: 58,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButtonFormField<String>(
          // ✅ ប្ដូរជា DropdownButtonFormField
          value: _selectedUnit,
          isExpanded: true,
          style: const TextStyle(
            fontFamily: 'Siemreap',
            color: Colors.black,
            fontSize: 13,
          ),
          decoration: const InputDecoration(
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
          hint: const Text(
            'ជ្រើសរើសឯកតា *',
            style: TextStyle(fontSize: 13),
          ), // ✅ បន្ថែម hint
          items: _units
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: (val) => setState(() => _selectedUnit = val!),
          validator: (value) =>
          value == null ? 'សូមជ្រើសរើសឯកតា' : null, // ✅ បន្ថែម validator
        ),
      ),
    );
  }


  // ── Submit Button ──────────────────────────────────────────
  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: (_isUploading || _images.isEmpty) ? null : _submitData,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange[800],
          disabledBackgroundColor: Colors.grey,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        child: _isUploading
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text(
          'ប្រកាសលក់មុនឥឡូវនេះ',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            fontFamily: 'Siemreap',
          ),
        ),
      ),
    );
  }


  // ── Submit Data ────────────────────────────────────────────
  Future<void> _submitData() async {
    if (!_formKey.currentState!.validate() || _images.isEmpty) return;


    if (currentUid == null || currentUid!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ សូម Login មុន!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }


    if (_locationController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ សូមជ្រើសរើសខេត្តមុន!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }


    setState(() => _isUploading = true);


    try {
      // ✅ Upload រូបភាព
      List<String> imageUrls = [];
      for (int i = 0; i < _images.length; i++) {
        String fileName =
            'pre_orders/$currentUid/${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        Reference ref = FirebaseStorage.instance.ref().child(fileName);
        await ref.putFile(_images[i]);
        String url = await ref.getDownloadURL();
        imageUrls.add(url);
      }


      // ✅ Parse ថ្ងៃខែ
      DateTime harvestDate = DateFormat(
        'dd-MM-yyyy',
      ).parse(_dateController.text);


      // ✅ Save Firestore
      await FirebaseFirestore.instance.collection('pre_orders').add({
        'owner_id': currentUid,
        'product_name': _nameController.text.trim(),
        'price':
        double.tryParse(_priceController.text.replaceAll(',', '')) ?? 0.0,
        'unit': _selectedUnit ?? 'មិនបានជ្រើសរើស',
        'harvest_date': Timestamp.fromDate(harvestDate),
        'location': _locationController.text.trim(),
        'phone': _phoneController.text.trim(),
        'description': _descController.text.trim(),
        'images': imageUrls,
        'created_at': FieldValue.serverTimestamp(),
        'status': 'active',
      });
      if (mounted) {
        setState(() => _isUploading = false);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ ប្រកាសបានជោគជ័យ!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Upload Error: $e');
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ មានបញ្ហា: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}


class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  static final NumberFormat _formatter = NumberFormat('#,###');
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    if (newValue.text.isEmpty) return newValue;
    String baseText = newValue.text.replaceAll(',', '');
    int? value = int.tryParse(baseText);
    if (value == null) return oldValue;
    String newText = _formatter.format(value);
    return newValue.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}



