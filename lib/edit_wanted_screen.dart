import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:my_app/location_picker.dart';

class EditWantedScreen extends StatefulWidget {
  final String productId;
  final Map<String, dynamic> productData;

  const EditWantedScreen({
    super.key,
    required this.productId,
    required this.productData,
  });

  @override
  State<EditWantedScreen> createState() => _EditWantedScreenState();
}

class _EditWantedScreenState extends State<EditWantedScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  late TextEditingController _nameController;
  late TextEditingController _qtyController;
  late TextEditingController _priceController;
  late TextEditingController _phoneController;
  late TextEditingController _locationController;
  late TextEditingController _descriptionController;

  String _userId = '';
  List<File> _selectedImages = [];
  List<String> _existingImageUrls = [];
  String _selectedUnit = "គីឡូ";
  String _priceType = "បំពេញតម្លៃ";
  String? _currency; // គ្មានតម្លៃដើម បង្ខំឲ្យជ្រើសរើស
  bool _isLoading = false;

  final List<String> _units = [
    "ដើម", "គ្រាប់", "គ្រឿង", "គីឡូ", "តោន",
    "បាវ", "កញ្ចប់", "ធុង", "ហិតា", "ម៉ែត្រ", "ដុំ", "..."
  ];

  @override
  void initState() {
    super.initState();
    _loadUserId();
    CambodiaLocationService.load(); // ✅ ដូច AddWantedScreen បេះបិទ
    _initFormData();
  }

  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _userId = prefs.getString('user_uid') ?? '');
  }

  void _initFormData() {
    final data = widget.productData;
    _nameController = TextEditingController(text: data['productName'] ?? '');
    _qtyController = TextEditingController(text: data['quantity']?.toString() ?? '');
    _priceController = TextEditingController(
      text: data['price'] != null && data['price'] != 'ចរចារ' ? data['price'].toString() : '',
    );
    _phoneController = TextEditingController(text: data['phone'] ?? '');
    _locationController = TextEditingController(text: data['location'] ?? '');
    _descriptionController = TextEditingController(text: data['description'] ?? '');

    setState(() {
      _selectedUnit = data['unit'] ?? "គីឡូ";
      _priceType = data['price'] == 'ចរចារ' ? 'ចរចារ' : 'បំពេញតម្លៃ';
      _currency = data['currency']?.toString();
      if (data['imageUrls'] != null) {
        _existingImageUrls = List<String>.from(data['imageUrls']);
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _qtyController.dispose();
    _priceController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<File?> _compressImage(File file) async {
    final tempDir = await getTemporaryDirectory();
    final path = "${tempDir.path}/img_${DateTime.now().millisecondsSinceEpoch}.jpg";
    final result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path, path, quality: 60,
    );
    return result != null ? File(result.path) : null;
  }

  Future<void> _pickImages() async {
    final List<XFile> images = await ImagePicker().pickMultiImage();
    if (images.isNotEmpty) {
      if ((_selectedImages.length + images.length) > 3) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("ជ្រើសរើសបានត្រឹមតែ ៣ សន្លឹកប៉ុណ្ណោះ!")),
        );
      } else {
        setState(() => _selectedImages.addAll(images.map((x) => File(x.path)).toList()));
      }
    }
  }

  void _removeExistingImage(String url) {
    setState(() => _existingImageUrls.remove(url));
  }

  void _removeNewImage(File file) {
    setState(() => _selectedImages.remove(file));
  }
  Future<void> _updatePost() async {
    if (_userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("សូម Login មុននឹងកែប្រែ"), backgroundColor: Colors.red),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    if (_priceType == "បំពេញតម្លៃ" && _currency == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("សូមជ្រើសរើសរូបិយប័ណ្ណ (ដុល្លារ ឬ រៀល)")),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      List<String> allImageUrls = List.from(_existingImageUrls);

      // Upload រូបភាពថ្មី
      for (File img in _selectedImages) {
        File? smallImg = await _compressImage(img);
        if (smallImg != null) {
          String fileName = "${DateTime.now().millisecondsSinceEpoch}_${_selectedImages.indexOf(img)}.jpg";
          Reference ref = FirebaseStorage.instance.ref().child('wanted_images/$fileName');
          await ref.putFile(smallImg);
          String url = await ref.getDownloadURL();
          allImageUrls.add(url);
        }
      }

      // រក្សាទុកការកែប្រែ
      await FirebaseFirestore.instance
          .collection('wanted_products')
          .doc(widget.productId)
          .update({
        'productName': _nameController.text.trim(),
        'quantity': _qtyController.text.trim(),
        'unit': _selectedUnit,
        'priceType': _priceType,
        'price': _priceType == "ចរចារ" ? "ចរចារ" : _priceController.text.trim(),
        'currency': _currency,
        'description': _descriptionController.text.trim(),
        'phone': _phoneController.text.trim(),
        'location': _locationController.text.trim(),
        'imageUrls': allImageUrls,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("ការកែប្រែត្រូវបានរក្សាទុក")),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("កំហុស៖ $e")),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text("កែប្រែប្រកាសទិញ", style: TextStyle(fontFamily: 'Siemreap')),
          backgroundColor: Colors.blue[700],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
              key: _formKey,
              child: Column(
                  children: [
                  // --- រូបភាព ---
                  const Text("រូបភាពទំនិញ (អតិបរមា ៣ សន្លឹក)", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                  // រូបភាពចាស់
                  ..._existingImageUrls.map((url) => Stack(
          children: [
          ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(url, width: 80, height: 80, fit: BoxFit.cover),
        ),
        Positioned(
          right: 0, top: 0,
          child: GestureDetector(
            onTap: () => _removeExistingImage(url),
            child: const Icon(Icons.cancel, color: Colors.red),
          ),
        ),
          ],
                  )),
                    // រូបភាពថ្មី
                    ..._selectedImages.map((file) => Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(file, width: 80, height: 80, fit: BoxFit.cover),
                        ),
                        Positioned(
                          right: 0, top: 0,
                          child: GestureDetector(
                            onTap: () => _removeNewImage(file),
                            child: const Icon(Icons.cancel, color: Colors.red),
                          ),
                        ),
                      ],
                    )),
                    // ប៊ូតុងបន្ថែមរូបថត
                    if (_existingImageUrls.length + _selectedImages.length < 3)
                      GestureDetector(
                        onTap: _pickImages,
                        child: Container(
                          width: 80, height: 80,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[400]!),
                          ),
                          child: const Icon(Icons.add_a_photo, size: 30, color: Colors.grey),
                        ),
                      ),
                  ],
              ),
            const SizedBox(height: 20),

            // --- ឈ្មោះទំនិញ ---
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: "ឈ្មោះទំនិញ", border: OutlineInputBorder()),
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
                    decoration: const InputDecoration(labelText: "ចំនួនត្រូវការ", border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField(
                    value: _selectedUnit,
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                    items: _units.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                    onChanged: (v) => setState(() => _selectedUnit = v.toString()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),

            // --- តម្លៃ ---
            const Text("តម្លៃរំពឹងទុក៖", style: TextStyle(fontWeight: FontWeight.bold)),
            Row(
                children: [
                Radio(value: "បំពេញតម្លៃ", groupValue: _priceType, onChanged: (v) => setState(() => _priceType = v.toString())),
            const Text("បំពេញ"),
            Radio(value: "ចរចារ", groupValue: _priceType, onChanged: (v) => setState(() => _priceType = v.toString())),
                  const Text("ចរចារ"),
                ],
            ),
              if (_priceType == "បំពេញតម្លៃ")
          Row(
        children: [
        Expanded(
        child: TextFormField(
          controller: _priceController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: "តម្លៃ", border: OutlineInputBorder()),
        ),
    ),
    const SizedBox(width: 10),
    ToggleButtons(
    isSelected: [_currency == "\$", _currency == "៛"],
    onPressed: (index) => setState(() => _currency = index == 0 ? "\$" : "៛"),
    borderRadius: BorderRadius.circular(8),
    children: const [
    Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text("\$")),
    Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text("៛")),
    ],
    ),
    ],
    ),
    if (_priceType == "បំពេញតម្លៃ" && _currency == null)
    const Padding(
    padding: EdgeInsets.only(top: 5),
    child: Text("សូមជ្រើសរើសរូបិយប័ណ្ណ", style: TextStyle(color: Colors.red, fontSize: 12)),
    ),
    const SizedBox(height: 15),

    // --- លេខទូរស័ព្ទ ---
    TextFormField(
    controller: _phoneController,
    keyboardType: TextInputType.phone,
    decoration: const InputDecoration(
    labelText: "លេខទូរស័ព្ទ", border: OutlineInputBorder(), prefixIcon: Icon(Icons.phone),
    ),
    ),
    const SizedBox(height: 15),

    // --- ទីតាំង (ដូច AddWantedScreen បេះបិទ) ---
    const Text("ទីតាំងត្រូវការទិញ *", style: TextStyle(fontWeight: FontWeight.bold)),
    const SizedBox(height: 10),
    InkWell(
    onTap: () {
    showLocationPicker(
    context,
    onSelected: (location) {
    setState(() => _locationController.text = location.toString());
    },
    );
    },
    borderRadius: BorderRadius.circular(12),
    child: Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
    decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: Colors.grey.shade300, width: 1),
    ),
    child: Row(
    children: [
    const Icon(Icons.location_on_outlined, color: Colors.orange, size: 22),
    const SizedBox(width: 10),
    Expanded(
    child: Text(
    _locationController.text.isEmpty ? "ជ្រើសរើសទីតាំង *" : _locationController.text,
    style: TextStyle(
    fontSize: 14,
    fontFamily: 'Siemreap',
    color: _locationController.text.isEmpty ? Colors.grey.shade600 : Colors.black87,
    ),
      overflow: TextOverflow.ellipsis,
      maxLines: 1,
    ),
    ),
    ],
    ),
    ),
    ),
                    const SizedBox(height: 15),

                    // --- ការពិពណ៌នា ---
                    const Text("រៀបរាប់បន្ថែម *", style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: "ឧទាហរណ៍៖ ត្រូវការទិញយកទៅប្រើប្រាស់ផ្ទាល់ខ្លួន...",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.all(12),
                      ),
                      validator: (v) => v!.isEmpty ? "សូមបំពេញការរៀបរាប់" : null,
                    ),
                    const SizedBox(height: 30),

                    // --- ប៊ូតុងរក្សាទុក ---
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _updatePost,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[700],
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text("រក្សាទុកការកែប្រែ",
                            style: TextStyle(color: Colors.white, fontSize: 18, fontFamily: 'Siemreap')),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
              ),
          ),
        ),
    );
  }
}