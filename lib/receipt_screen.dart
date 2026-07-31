import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:my_app/download_helper.dart';
import 'order_service.dart';
import 'telegram_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'location_data.dart';
import 'vireak_buntham_data.dart';

class ReceiptScreen extends StatefulWidget {
  final List<QueryDocumentSnapshot> cartDocs;

  const ReceiptScreen({super.key, required this.cartDocs});

  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  File? _paymentImage;
  bool _isProcessing = false;
  bool isVireakBuntham = false;
  String? selectedVireakBranch;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  String? selectedProvince;
  String? selectedDistrict;

  final User? currentUser = FirebaseAuth.instance.currentUser;
  final NumberFormat currencyFormat = NumberFormat("#,###", "en_US");

  // 🎯 គណនា total ម្តងហើយផ្ទុកជា final (មិន rebuild រាល់ពេល)
  late final double _total;

  @override
  void initState() {
    super.initState();
    _loadSavedCustomerData();
    // 🎯 គណនា total ម្តងតែប៉ុណ្ណោះ ដោយគុណ quantity
    _total = widget.cartDocs.fold(0.0, (sum, doc) {
      double price =
          double.tryParse(doc['price'].toString().replaceAll(',', '')) ?? 0.0;
      int qty = int.tryParse(doc['quantity']?.toString() ?? '1') ?? 1;
      return sum + (price * qty);
    });
  }

  Future<void> _loadSavedCustomerData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _nameController.text =
            prefs.getString('saved_name') ?? (currentUser?.displayName ?? "");
        _phoneController.text = prefs.getString('saved_phone') ??
            (currentUser?.phoneNumber ?? "");
        if (prefs.getString('saved_address') != null) {
          _addressController.text = prefs.getString('saved_address')!;
        }
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await ImagePicker().pickImage(
        source: source,
        imageQuality: 80,
      );
      if (pickedFile != null && mounted) {
        setState(() {
          _paymentImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      debugPrint("Error: \$e");
    }
  }

  Future<void> _confirmOrder() async {
    if (_isProcessing) return;

    bool isLocationSelected = selectedProvince != null &&
        (isVireakBuntham
            ? selectedVireakBranch != null
            : selectedDistrict != null);
    bool isAddressTyped = _addressController.text.trim().isNotEmpty;

    if (_nameController.text.isEmpty || _phoneController.text.isEmpty) {
      _showSnackBar("សូមបំពេញឈ្មោះ និងលេខទូរស័ព្ទ!");
      return;
    }

    if (!isLocationSelected && !isAddressTyped) {
      _showSnackBar("សូមជ្រើសរើសទីតាំង ឬបំពេញអាសយដ្ឋានដឹកជញ្ជូន!");
      return;
    }

    if (_paymentImage == null) {
      _showSnackBar("សូមជ្រើសរើសរូបភាពប្លង់ផ្ទេរលុយសិន!");
      return;
    }

    setState(() => _isProcessing = true);

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? userIdFromPrefs = prefs.getString('user_uid');String locationInfo = isVireakBuntham
          ? "ផ្ញើតាមវិរៈ (សាខា: \$selectedVireakBranch)"
          : "ស្រុក: \${selectedDistrict ?? ''}";
      String finalAddress =
          "\$selectedProvince, \$locationInfo, \${_addressController.text}".trim();

      await prefs.setString('saved_name', _nameController.text);
      await prefs.setString('saved_phone', _phoneController.text);
      await prefs.setString('saved_address', _addressController.text);

      double exactTotal = 0.0;

      List<Map<String, dynamic>> cartItems = widget.cartDocs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;

        double price =
            double.tryParse(data['price'].toString().replaceAll(',', '')) ??
                0.0;
        int quantity = int.tryParse(data['quantity'].toString()) ?? 1;
        exactTotal += (price * quantity);

        return {
          'product_id': data['product_id'] ?? doc.id,
          'product_name': data['product_name'] ?? 'គ្មានឈ្មោះ',
          'price': price,
          'quantity': quantity,
          'image_url': data['image_url'] ?? '',
          'seller_id': data['seller_id'] ?? 'UNKNOWN_ID',
          'seller_name': data['seller_name'] ?? 'អាជីវករ សេសាន',
          'seller_photo': data['seller_photo'] ?? '',
          'seller_phone': data['seller_phone'] ?? '',
          'order_date': FieldValue.serverTimestamp(),
        };
      }).toList();

      String fileName = DateTime.now().millisecondsSinceEpoch.toString();
      var storageRef = FirebaseStorage.instance
          .ref()
          .child('payments/\$fileName.jpg');
      await storageRef.putFile(_paymentImage!);
      String paymentImageUrl = await storageRef.getDownloadURL();

      OrderService orderService = OrderService();
      bool success = await orderService.createOrder(
        cartItems: cartItems,
        totalAmount: exactTotal,
        customerId: userIdFromPrefs ?? 'GUEST',
        customerName: _nameController.text,
        phoneNumber: _phoneController.text,
        shippingAddress: finalAddress,
        paymentImage: paymentImageUrl,
      );

      if (success) {
        String telegramMsg =
            "🔔 *មានការកុម្ម៉ង់ថ្មី*\\n👤 ភ្ញៀវ៖ \${_nameController.text}\\n💰 សរុប៖ \${exactTotal.toStringAsFixed(0)} ៛";
        await TelegramService.sendMessage(telegramMsg);

        await orderService.clearCart(userIdFromPrefs ?? 'GUEST');

        if (mounted) _showSuccessWaitingDialog();
      } else {
        if (mounted) _showSnackBar("ការបង្កើត Order មានបញ្ហា!");
      }
    } catch (e) {
      if (mounted) _showSnackBar("មានបញ្ហា៖ \$e");
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showSuccessWaitingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text("ការកុម្ម៉ង់ជោគជ័យ!"),
        content: const Text(
          "ការកម្មង់រួចរាល់ រងចាំការបញ្ជាក់។ បងអាចត្រលប់ទៅផ្ទាំងដើមបាន។",
        ),
        actions: [
          Center(
            child: ElevatedButton(
              onPressed: () =>
                  Navigator.of(context).popUntil((route) => route.isFirst),
              child: const Text("ត្រឡប់ទៅផ្ទាំងដើម"),
            ),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _launchABA() async {
    final Uri url = Uri.parse('https://pay.ababank.com/oRF8/lq8jgwzb');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      await launchUrl(url, mode: LaunchMode.platformDefault);
    }
  }

  @override
  Widget build(BuildContext context) {return Scaffold(
      appBar: AppBar(
        title: const Text("ទូទាត់ប្រាក់"),
        backgroundColor: Colors.green[700],
        // 🎯 ប្រើ leading ធម្មតា (មិនប្រើ custom) ដើម្បីឲ្យ swipe back រលូន
        elevation: 0,
      ),
      // 🎯 បន្ថយ resizeToAvoidBottomInset ដើម្បីការពារ UI jump
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInput("ឈ្មោះអ្នកទទួល", _nameController, Icons.person),
              _buildInput(
                "លេខទូរស័ព្ទ",
                _phoneController,
                Icons.phone,
                inputType: TextInputType.phone,
              ),
              const SizedBox(height: 10),
              _buildLocationDropdowns(),
              const SizedBox(height: 10),
              _buildInput(
                "អាសយដ្ឋានលម្អិត(មិនចាំបាច់)",
                _addressController,
                Icons.location_on,
                maxLines: 2,
              ),
              const Divider(height: 40),
              const Center(
                child: Text(
                  "ស្កេនបង់ប្រាក់",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: GestureDetector(
                  onLongPress: () async {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("⌛️ កំពុងរក្សាទុក...")),
                    );
                    await DownloadHelper.saveQRImage(
                      "https://firebasestorage.googleapis.com/v0/b/sesan-my-app.firebasestorage.app/o/20260308_163835.jpg?alt=media&token=95922392-ed40-4483-9097-899987ad06e8",
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("✅ រក្សាទុកជោគជ័យ!"),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
                  child: Image.asset(
                    "assets/aba_qr.png",
                    height: 150,
                    errorBuilder: (c, e, s) =>
                        const Icon(Icons.qr_code, size: 80),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: Text(
                  "${currencyFormat.format(_total)} ៛",
                  style: const TextStyle(
                    fontSize: 24,
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: _launchABA,
                icon: const Icon(
                  Icons.account_balance_wallet,
                  color: Colors.white,
                ),
                label: const Text(
                  "បង់ប្រាក់តាម App ABA",
                  style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF005D7E),
                  minimumSize: const Size(double.infinity, 45),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: GestureDetector(
                  onTap: () => _showPickImageDialog(),
                  child: Container(
                    height: 180,
                    width: 180,decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: Colors.green.withOpacity(0.5),
                        width: 2,
                      ),
                    ),
                    child: _paymentImage == null
                        ? const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_a_photo_rounded,
                                size: 50,
                                color: Colors.green,
                              ),
                              Text("ដាក់រូបវិក្កយបត្រ"),
                            ],
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(13),
                            child: Image.file(
                              _paymentImage!,
                              fit: BoxFit.contain,
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  minimumSize: const Size(double.infinity, 55),
                ),
                onPressed: _isProcessing ? null : _confirmOrder,
                child: _isProcessing
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "បញ្ជាក់ការកុម្ម៉ង់",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _showPickImageDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.green),
              title: const Text('ថតរូប (Camera)'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.blue),
              title: const Text('ជ្រើសរើសពីអាល់ប៊ុម (Gallery)'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationDropdowns() {
    return Column(
      children: [
        DropdownButtonFormField<String>(
          value: selectedProvince,
          decoration: const InputDecoration(
            labelText: "ជ្រើសរើសខេត្ត/ក្រុង",
            prefixIcon: Icon(Icons.map_outlined),
            border: OutlineInputBorder(),
          ),
          items: cambodiaProvinceData.keys
              .map((s) => DropdownMenuItem(value: s, child: Text(s)))
              .toList(),
          onChanged: (val) => setState(() {
            selectedProvince = val;
            selectedDistrict = null;
            selectedVireakBranch = null;
          }),
        ),
        const SizedBox(height: 10),
        SwitchListTile(
          title: const Text("ផ្ញើតាមវិរៈប៊ុនថាំ",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          value: isVireakBuntham,
          onChanged: (val) => setState(() {
            isVireakBuntham = val;
            selectedDistrict = null;
            selectedVireakBranch = null;
          }),
        ),
        if (selectedProvince != null) ...[
          const SizedBox(height: 10),
          isVireakBuntham
              ? DropdownButtonFormField<String>(
                  value: selectedVireakBranch,
                  decoration: const InputDecoration(
                    labelText: "ជ្រើសរើសសាខាវិរៈ",
                    prefixIcon: Icon(Icons.location_on, color: Colors.red),
                    border: OutlineInputBorder(),
                  ),
                  items: (VETData.branches[selectedProvince] ?? [])
                      .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                      .toList(),
                  onChanged: (val) =>
                      setState(() => selectedVireakBranch = val),
                )
              : DropdownButtonFormField<String>(
                  value: selectedDistrict,
                  decoration: const InputDecoration(
                    labelText: "ជ្រើសរើសស្រុក/ខណ្ឌ",
                    prefixIcon: Icon(Icons.location_city),
                    border: OutlineInputBorder(),
                  ),
                  items: cambodiaProvinceData[selectedProvince!]!
                      .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                      .toList(),
                  onChanged: (val) => setState(() => selectedDistrict = val),
                ),
        ],
      ],
    );
  }

  Widget _buildInput(
    String hint,
    TextEditingController controller,
    IconData icon, {
    TextInputType inputType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextField(
        controller: controller,
        keyboardType: inputType,
        maxLines: maxLines,
        decoration: InputDecoration(
          prefixIcon: Icon(icon),
          labelText: hint,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}