import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:my_app/location_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';


class AddWantedScreen extends StatefulWidget {
  const AddWantedScreen({super.key});


  @override
  State<AddWantedScreen> createState() => _AddWantedScreenState();
}


class _AddWantedScreenState extends State<AddWantedScreen> {
  final _formKey = GlobalKey<FormState>();


  // Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _qtyController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();


  String _userId = '';


  // Variables
  List<File> _selectedImages = [];
  String _selectedUnit = "គីឡូ";
  String _priceType = "បំពេញតម្លៃ";
  String? _currency;
  bool _isLoading = false;


  final List<String> _units = [
    "ដើម",
    "គ្រាប់",
    "គ្រឿង",
    "គីឡូ",
    "តោន",
    "បាវ",
    "កញ្ចប់",
    "ធុង",
    "ហិតា",
    "ម៉ែត្រ",
    "ដុំ",
    "...",
  ];


  @override
  void initState() {
    super.initState();
    _loadUserId();
    CambodiaLocationService.load();
  }


  Future<void> _loadUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String uid = prefs.getString('user_uid') ?? '';
      if (mounted) setState(() => _userId = uid);
    } catch (e) {
      debugPrint("Load User ID Error: $e");
    }
  }


  Future<File?> _compressImage(File file) async {
    final tempDir = await getTemporaryDirectory();
    final path =
        "${tempDir.path}/img_${DateTime.now().millisecondsSinceEpoch}.jpg";
    final result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      path,
      quality: 60,
    );
    return result != null ? File(result.path) : null;
  }


  Future<void> _pickImages() async {
    int remaining = 3 - _selectedImages.length;
    if (remaining <= 0) return;


    final List<XFile> images = await ImagePicker().pickMultiImage();
    if (images.isNotEmpty) {
      if (images.length > remaining) {
        setState(() {
          _selectedImages.addAll(
            images.take(remaining).map((x) => File(x.path)).toList(),
          );
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("ជ្រើសរើសបានអតិបរមាត្រឹមតែ ៣ សន្លឹកប៉ុណ្ណោះ!"),
          ),
        );
      } else {
        setState(() {
          _selectedImages.addAll(images.map((x) => File(x.path)).toList());
        });
      }
    }
  }


  Future<void> _submitPost() async {
    if (_userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("សូម Login មុននឹងប្រកាស"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (_priceType == "បំពេញតម្លៃ" && _currency == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("សូមជ្រើសរើសរូបិយប័ណ្ណ (ដុល្លារ ឬ រៀល)")),
      );
      return;
    }
    if (!_formKey.currentState!.validate() || _selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("សូមបំពេញព័ត៌មាន និងដាក់រូបភាពយ៉ាងហោច ១ សន្លឹក"),
        ),
      );
      return;
    }


    setState(() => _isLoading = true);
    List<String> imageUrls = [];
    try {
      for (File img in _selectedImages) {
        File? smallImg = await _compressImage(img);
        if (smallImg != null) {
          String fileName =
              "${DateTime.now().millisecondsSinceEpoch}_${_selectedImages.indexOf(img)}.jpg";
          Reference ref = FirebaseStorage.instance.ref().child(
            'wanted_images/$fileName',
          );
          await ref.putFile(smallImg);
          String url = await ref.getDownloadURL();
          imageUrls.add(url);
        }
      }


      await FirebaseFirestore.instance.collection('wanted_products').add({
        'productName': _nameController.text.trim(),
        'quantity': _qtyController.text.trim(),
        'unit': _selectedUnit,
        // ✅ រក្សាទុកតម្លៃឲ្យបានត្រឹមត្រូវ
        'priceType': _priceType,
        'price': _priceType == "ចរចារ"
            ? "ចរចារ"
            : _priceController.text.replaceAll(',', '').trim(),
        'currency': _priceType == "ចរចារ"
            ? "..." // ✅ ប្ដូរពី "ចរចារ" ទៅជា null
            : (_currency ?? '៛'), // ✅ ជួសជុល
        'description': _descriptionController.text.trim(),
        'phone': _phoneController.text.trim(),
        'location': _locationController.text.trim(),
        'imageUrls': imageUrls,
        'userId': _userId,
        'createdAt': FieldValue.serverTimestamp(),
      });


      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("ប្រកាសទិញត្រូវបានចុះផ្សាយ")),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("កំហុស៖ $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "បង្កើតការប្រកាសទិញ",
          style: TextStyle(fontFamily: 'Siemreap'),
        ),
      ),
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.translucent,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
              // --- រូបភាព ---
              _buildImageSection(),
              const SizedBox(height: 20),


              // --- ឈ្មោះទំនិញ ---
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: "ឈ្មោះទំនិញ",
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v!.isEmpty ? "សូមបញ្ចូលឈ្មោះ" : null,
              ),
              const SizedBox(height: 15),


              // --- ចំនួន និង ឯកតា ---
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _qtyController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "ចំនួនត្រូវការ",
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField(
                      value: _selectedUnit,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                      items: _units
                          .map(
                            (u) => DropdownMenuItem(
                          value: u,
                          child: Text(u),
                        ),
                      )
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _selectedUnit = v.toString()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),


              // --- តម្លៃ ---
              _buildPriceSection(),
              const SizedBox(height: 15),


              // --- លេខទូរស័ព្ទ ---
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: "លេខទូរស័ព្ទ",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? "សូមបញ្ចូលលេខទូរស័ព្ទ"
                    : null, // ✅ បន្ថែម
              ),
              const SizedBox(height: 15),


              // --- ទីតាំង ---
              _buildLocationPicker(),
              const SizedBox(height: 15),


              // --- ការពិពណ៌នា ---
              const Text(
                "រៀបរាប់បន្ថែម *",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _descriptionController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText:
                  "ឧទាហរណ៍៖ ត្រូវការទិញយកទៅប្រើប្រាស់ផ្ទាល់ខ្លួន...",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
              const SizedBox(height: 30),


              // --- ប៊ូតុងផ្ញើ ---
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _submitPost,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    "ចុះផ្សាយប្រកាសទិញ",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontFamily: 'Siemreap',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
        ),
    );
  }


  // ✅ ផ្នែករូបភាព (ជួសជុលប្រអប់ធំទំនេរចោល)
  Widget _buildImageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "រូបភាពទំនិញត្រូវការទិញ (អតិបរមា ៣ សន្លឹក) *",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),


        // ✅ បង្ហាញប្រអប់ធំសម្រាប់ចុច តែនៅពេលគ្មានរូបភាព
        if (_selectedImages.isEmpty)
          GestureDetector(
            onTap: _pickImages,
            child: Container(
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200, width: 2),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_a_photo, size: 40, color: Colors.blue),
                  const SizedBox(height: 8),
                  Text(
                    "ចុចដើម្បីដាក់រូបភាព (0/3)",
                    style: TextStyle(
                      color: Colors.blue[800],
                      fontFamily: 'Siemreap',
                    ),
                  ),
                ],
              ),
            ),
          ),


        // ✅ បង្ហាញរូបភាពដែលបានជ្រើសរើស (បង្ហាញជានិច្ចបើមាន)
        if (_selectedImages.isNotEmpty) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount:
              _selectedImages.length +
                  (_selectedImages.length < 3
                      ? 1
                      : 0), // +1 សម្រាប់ប៊ូតុងបន្ថែម
              itemBuilder: (context, index) {
                // ✅ ប៊ូតុងបន្ថែមរូបភាព (បង្ហាញនៅខាងចុង បើមិនទាន់គ្រប់ 3)
                if (index == _selectedImages.length) {
                  return GestureDetector(
                    onTap: _pickImages,
                    child: Container(
                      width: 90,
                      height: 90,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: const Icon(
                        Icons.add,
                        size: 30,
                        color: Colors.blue,
                      ),
                    ),
                  );
                }


                // ✅ រូបភាពដែលបានជ្រើសរើស
                return Stack(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(right: 10),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          _selectedImages[index],
                          width: 90,
                          height: 90,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 5,
                      top: 0,
                      child: GestureDetector(
                        onTap: () =>
                            setState(() => _selectedImages.removeAt(index)),
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.cancel,
                            color: Colors.red,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 5),
          // ✅ បង្ហាញចំនួនរូបភាព
          Text(
            "បានជ្រើសរើស ${_selectedImages.length}/3 សន្លឹក",
            style: TextStyle(
              fontSize: 12,
              color: _selectedImages.length >= 3 ? Colors.red : Colors.green,
              fontFamily: 'Siemreap',
            ),
          ),
        ],
      ],
    );
  }


  // ✅ ផ្នែកតម្លៃ (សាមញ្ញ ស្អាត មិនច្រឡំ)
  Widget _buildPriceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "តម្លៃរំពឹងទុក៖",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 8),


        // Radio buttons
        Row(
          children: [
            Radio(
              value: "បំពេញតម្លៃ",
              groupValue: _priceType,
              onChanged: (v) => setState(() => _priceType = v.toString()),
              activeColor: Colors.blue,
              visualDensity: VisualDensity.compact,
            ),
            GestureDetector(
              onTap: () => setState(() => _priceType = "បំពេញតម្លៃ"),
              child: const Text("បំពេញ", style: TextStyle(fontSize: 13)),
            ),
            const SizedBox(width: 16),
            Radio(
              value: "ចរចារ",
              groupValue: _priceType,
              onChanged: (v) => setState(() => _priceType = v.toString()),
              activeColor: Colors.orange,
              visualDensity: VisualDensity.compact,
            ),
            GestureDetector(
              onTap: () => setState(() => _priceType = "ចរចារ"),
              child: const Text("ចរចារ", style: TextStyle(fontSize: 13)),
            ),
          ],
        ),


        const SizedBox(height: 8),


        // ប្រអប់បញ្ចូលតម្លៃ + ប៊ូតុងរូបិយប័ណ្ណ
        if (_priceType == "បំពេញតម្លៃ")
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ប្រអប់បញ្ចូលតម្លៃ (គ្មានសញ្ញា $)
              TextFormField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                inputFormatters: [ThousandsSeparatorInputFormatter()],
                decoration: const InputDecoration(
                  labelText: "តម្លៃ",
                  border: OutlineInputBorder(),
                  // ✅ គ្មាន prefixIcon ដើម្បីកុំឲ្យច្រឡំ
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                ),
              ),
              const SizedBox(height: 10),


              // ✅ ប៊ូតុងរូបិយប័ណ្ណ (សាមញ្ញ តូច)
              const Text(
                "រូបិយប័ណ្ណ៖",
                style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  // ប៊ូតុង ដុល្លារ ($)
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _currency = "\$"),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _currency == "\$"
                              ? Colors.blue
                              : Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _currency == "\$"
                                ? Colors.blue
                                : Colors.grey[300]!,
                            width: _currency == "\$" ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "\$",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: _currency == "\$"
                                    ? Colors.white
                                    : Colors.black54,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              "ដុល្លារ",
                              style: TextStyle(
                                fontSize: 13,
                                color: _currency == "\$"
                                    ? Colors.white
                                    : Colors.black54,
                                fontFamily: 'Siemreap',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // ប៊ូតុង រៀល (៛)
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _currency = "៛"),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _currency == "៛"
                              ? Colors.orange
                              : Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _currency == "៛"
                                ? Colors.orange
                                : Colors.grey[300]!,
                            width: _currency == "៛" ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "៛",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: _currency == "៛"
                                    ? Colors.white
                                    : Colors.black54,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              "រៀល",
                              style: TextStyle(
                                fontSize: 13,
                                color: _currency == "៛"
                                    ? Colors.white
                                    : Colors.black54,
                                fontFamily: 'Siemreap',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              // សារព្រមានបើមិនបានជ្រើសរើស
              if (_currency == null)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text(
                    "សូមជ្រើសរើសរូបិយប័ណ្ណ",
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
            ],
          ),


        // បង្ហាញ "ចរចារ"
        if (_priceType == "ចរចារ")
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.handshake, color: Colors.orange, size: 20),
                SizedBox(width: 8),
                Text(
                  "តម្លៃអាចចរចារបាន",
                  style: TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    fontFamily: 'Siemreap',
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }


  // ✅ ផ្នែកទីតាំង
  Widget _buildLocationPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "ទីតាំងត្រូវការទិញ *",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: InkWell(
                onTap: () {
                  showLocationPicker(
                    context,
                    onSelected: (location) {
                      setState(
                            () => _locationController.text = location.toString(),
                      );
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
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        color: Colors.orange.shade800,
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
      ],
    );
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



