import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:my_app/map_picker_screen.dart';
import 'package:my_app/product_list.dart';
import 'package:my_app/location_picker.dart';


class EditProductScreen extends StatefulWidget {
  final String productId;
  final Map<String, dynamic> productData;
  final bool isWanted; // ប្រកាសតែម្តងបានហើយ
  final String? currentUserId; // 🎯 ថែមជួរនេះសម្រាប់ទទួល UID


  const EditProductScreen({
    super.key,
    required this.productId,
    required this.productData,
    required this.isWanted, // កែឱ្យសល់តែជួរនេះមួយ
    this.currentUserId, // 🎯 ទទួលពីអេក្រង់មុន
  });


  @override
  State<EditProductScreen> createState() => _EditProductScreenState();
}


class _EditProductScreenState extends State<EditProductScreen> {
  final _formKey = GlobalKey<FormState>();


  late TextEditingController _nameController;
  late TextEditingController _priceController;
  late TextEditingController _descController;
  late TextEditingController _phoneController;
  late TextEditingController _locationController;


  final ImagePicker _picker = ImagePicker();
  List<File> _imageFiles = []; // សម្រាប់ទុកបញ្ជីរូបភាពថ្មី
  List<String> _existingImageUrls = []; // សម្រាប់ទុកបញ្ជីរូបភាពចាស់
  bool _isLoading = false;
  double? selectedLat;
  double? selectedLng;
  bool _isOwner = false; // ✅ បន្ថែមនេះ


  @override
  void initState() {
    super.initState();


    // ✅ បន្ថែមបន្ទាត់នេះ (ដូច AddPreOrderScreen)
    CambodiaLocationService.load();


    _checkOwnership();


    final data = widget.productData;
    final formatter = NumberFormat('#,###');


    // ✅ កំណត់តម្លៃដំបូងសម្រាប់ _priceController
    String initialPrice = data['price']?.toString() ?? '';
    if (initialPrice.isNotEmpty) {
      try {
        initialPrice = formatter.format(
          int.parse(initialPrice.replaceAll(',', '')),
        );
      } catch (e) {
        // ទុកតម្លៃដើមបើ Format មិនបាន
      }
    }
    _priceController = TextEditingController(text: initialPrice);


    // ✅ កំណត់តម្លៃដំបូងសម្រាប់ Controllers ផ្សេងទៀត
    _nameController = TextEditingController(
      text: data['product_name']?.toString() ?? '',
    );
    _descController = TextEditingController(
      text: data['description']?.toString() ?? '',
    );
    _phoneController = TextEditingController(
      text: widget.productData['phone1']?.toString() ?? '',
    );
    _locationController = TextEditingController(
      text: data['location']?.toString() ?? '',
    );


    // ✅ កំណត់ Lat/Lng
    selectedLat = data['lat'] != null ? (data['lat'] as num).toDouble() : null;
    selectedLng = data['lng'] != null ? (data['lng'] as num).toDouble() : null;


    // ✅ ទាញយកបញ្ជីរូបភាពដែលមានស្រាប់
    if (data['image_urls'] != null) {
      _existingImageUrls = List<String>.from(data['image_urls']);
    } else if (data['image_url'] != null) {
      _existingImageUrls = [data['image_url']];
    }
  }


  /// ✅ ពិនិត្យថាអ្នកបើកជាម្ចាស់ឬអត់
  Future<void> _checkOwnership() async {
    final currentUserId = widget.currentUserId ?? await UserService.getUserId();
    final productOwnerId = widget.isWanted
        ? widget.productData['userId']
        : widget.productData['seller_id'];


    setState(() {
      _isOwner =
          currentUserId != null &&
              productOwnerId != null &&
              currentUserId == productOwnerId;
    });


    // 🔥 DEBUG
    print("Current User: $currentUserId");
    print("Product Owner: $productOwnerId");
    print("Is Owner: $_isOwner");
  }


  // ✅ មុខងាររើសរូបភាពច្រើនសន្លឹក
  Future<void> _pickImages() async {
    final List<XFile> selectedImages = await _picker.pickMultiImage(
      imageQuality: 50,
    );
    if (selectedImages.isNotEmpty) {
      setState(() {
        _imageFiles.addAll(
          selectedImages.map((xFile) => File(xFile.path)).toList(),
        );
      });
    }
  }


  Future<void> _updateProduct() async {
    if (!_isOwner) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("🚫 អ្នកមិនមានសិទ្ធិកែប្រែទំនិញនេះទេ")),
      );
      return;
    }
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        List<String> allImageUrls = List.from(_existingImageUrls);


        for (File file in _imageFiles) {
          String fileName = DateTime.now().millisecondsSinceEpoch.toString();
          final storageRef = FirebaseStorage.instance.ref().child(
            'products/images/$fileName.jpg',
          );
          await storageRef.putFile(file);
          String url = await storageRef.getDownloadURL();
          allImageUrls.add(url);
        }


        // ✅ កែសម្រួលត្រង់នេះ ដើម្បីឱ្យ Admin រក ID ឃើញ និងលេខទូរស័ព្ទមិនបាត់
        await FirebaseFirestore.instance
            .collection('products')
            .doc(widget.productId)
            .update({
          'product_name': _nameController.text.trim(),
          // ✅ ថែម " ៛" នៅខាងក្រោយតម្លៃ ដើម្បីឱ្យដូចកូដចាស់មេ
          'price': _priceController.text
              .trim(), // រក្សាទុកត្រឹម 1,000 (មានក្បៀស តែអត់មាន ៛)
          'description': _descController.text.trim(),
          'phone1': _phoneController.text
              .trim(), // ប្តូរឱ្យត្រូវជាមួយ AddProductPage
          'location': _locationController.text.trim(),
          'lat': selectedLat,
          'lng': selectedLng,
          'image_urls': allImageUrls,
          'updatedAt': FieldValue.serverTimestamp(),
          // ⚠️ សំខាន់បំផុត៖ ត្រូវបោះ seller_id ទៅវិញទើប Admin រកឃើញ
          'seller_id': widget.productData['seller_id'],
        });


        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("✅ កែប្រែបានសម្រេច!"),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        debugPrint("Update Error: $e");
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    // ✅ បើមិនមែនម្ចាស់ → បង្ហាញ error ហើយ pop វិញ
    if (!_isOwner && !_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.block, size: 80, color: Colors.red),
              const SizedBox(height: 20),
              const Text(
                "🚫 អ្នកមិនមានសិទ្ធិកែប្រែទំនិញនេះទេ",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("ត្រឡប់ក្រោយ"),
              ),
            ],
          ),
        ),
      );
    }


    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "កែប្រែផលិតផល",
          style: TextStyle(fontFamily: 'KHMEROS'),
        ),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "រូបភាពផលិតផល",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 10),
              // ✅ ផ្នែកបង្ហាញរូបភាពជាជួរ
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  GestureDetector(
                    onTap: _pickImages,
                    child: Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade400),
                      ),
                      child: const Icon(
                        Icons.add_a_photo,
                        size: 30,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                  // បង្ហាញរូបភាពចាស់
                  ..._existingImageUrls.map(
                        (url) => Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            url,
                            width: 90,
                            height: 90,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: GestureDetector(
                            onTap: () => setState(
                                  () => _existingImageUrls.remove(url),
                            ),
                            child: const CircleAvatar(
                              radius: 12,
                              backgroundColor: Colors.red,
                              child: Icon(
                                Icons.close,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // បង្ហាញរូបភាពថ្មី
                  ..._imageFiles.map(
                        (file) => Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(
                            file,
                            width: 90,
                            height: 90,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: GestureDetector(
                            onTap: () =>
                                setState(() => _imageFiles.remove(file)),
                            child: const CircleAvatar(
                              radius: 12,
                              backgroundColor: Colors.red,
                              child: Icon(
                                Icons.close,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 25),


              _buildInput(
                _nameController,
                "ឈ្មោះផលិតផល",
                Icons.shopping_bag,
              ),
              _buildInput(
                _priceController,
                "តម្លៃ (៛)",
                Icons.account_balance_wallet,
                isNumber: true,
              ),
              _buildInput(
                _phoneController,
                "លេខទូរស័ព្ទ",
                Icons.phone,
                isNumber: true,
              ),
              const SizedBox(height: 10),
              _buildInput(
                _descController,
                "ការពិពណ៌នា",
                Icons.description,
                maxLines: 3,
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
                              _locationController.text = location
                                  .toString();
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
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _updateProduct,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    "រក្សាទុកការកែប្រែ",
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildInput(
      TextEditingController controller,
      String label,
      IconData icon, {
        bool isNumber = false,
        int maxLines = 1,
      }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        inputFormatters: isNumber && label.contains("តម្លៃ")
            ? [
          FilteringTextInputFormatter.digitsOnly,
          ThousandsSeparatorInputFormatter(),
        ]
            : null,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.green[700]),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.grey[50],
        ),
        validator: (value) => value!.isEmpty ? "សូមបំពេញ $label" : null,
      ),
    );
  }
}


class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    if (newValue.text.isEmpty) return newValue;


    // លុបក្បៀសចាស់ចេញ រួចដាក់ថ្មី
    String newText = newValue.text.replaceAll(',', '');
    final formatter = NumberFormat('#,###');
    String formattedText = formatter.format(int.parse(newText));


    return newValue.copyWith(
      text: formattedText,
      selection: TextSelection.collapsed(offset: formattedText.length),
    );
  }
}



