import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gal/gal.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'order_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'location_data.dart';
import 'vireak_buntham_data.dart';
import 'localized_text.dart';

class ReceiptScreen extends StatefulWidget {
  final List<QueryDocumentSnapshot> cartDocs;

  const ReceiptScreen({super.key, required this.cartDocs});

  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  String _t(String km, String en) => appText(context, km: km, en: en);
  Uint8List? _paymentImageBytes;
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

  late final double _total;

  @override
  void initState() {
    super.initState();
    _loadSavedCustomerData();
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
      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        if (mounted) {
          setState(() {
            _paymentImageBytes = bytes;
          });
        }
      }
    } catch (e) {
      debugPrint("Error: $e");
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
      _showSnackBar(_t(
        "សូមបំពេញឈ្មោះ និងលេខទូរស័ព្ទ!",
        "Please enter the recipient name and phone number.",
      ));
      return;
    }

    if (!isLocationSelected && !isAddressTyped) {
      _showSnackBar(_t(
        "សូមជ្រើសរើសទីតាំង ឬបំពេញអាសយដ្ឋានដឹកជញ្ជូន!",
        "Please select a location or enter a delivery address.",
      ));
      return;
    }

    if (_paymentImageBytes == null || _paymentImageBytes!.isEmpty) {
      _showSnackBar(_t(
        "សូមជ្រើសរើសរូបភាពប្លង់ផ្ទេរលុយសិន!",
        "Please attach the payment receipt.",
      ));
      return;
    }

    setState(() => _isProcessing = true);

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? userIdFromPrefs = prefs.getString('user_uid');

      final String locationInfo = isVireakBuntham
          ? "${_t('ផ្ញើតាមវិរៈ', 'Vireak Buntham')} (${_t('សាខា', 'branch')}: $selectedVireakBranch)"
          : "${_t('ស្រុក', 'district')}: ${selectedDistrict ?? ''}";
      final String finalAddress =
          "$selectedProvince, $locationInfo, ${_addressController.text.trim()}";

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
          .child('payments/$fileName.jpg');
      await storageRef
          .putData(
            _paymentImageBytes!,
            SettableMetadata(contentType: 'image/jpeg'),
          )
          .timeout(const Duration(seconds: 30));
      String paymentImageUrl = await storageRef
          .getDownloadURL()
          .timeout(const Duration(seconds: 15));

      OrderService orderService = OrderService();
      bool success = await orderService
          .createOrder(
            cartItems: cartItems,
            totalAmount: exactTotal,
            customerId: userIdFromPrefs ?? 'GUEST',
            customerName: _nameController.text,
            phoneNumber: _phoneController.text,
            shippingAddress: finalAddress,
            paymentImage: paymentImageUrl,
          )
          .timeout(const Duration(seconds: 20));

      if (success) {
        try {
          await orderService
              .clearCart(userIdFromPrefs ?? 'GUEST')
              .timeout(const Duration(seconds: 8));
        } catch (error) {
          debugPrint("Cart cleanup will be retried later: $error");
        }
        if (mounted) _showSuccessWaitingDialog();
      } else {
        if (mounted) {
          _showSnackBar(_t(
            "ការបង្កើតការបញ្ជាទិញមានបញ្ហា!",
            "Could not create the order.",
          ));
        }
      }
    } catch (e) {
      if (mounted) _showSnackBar("${_t('មានបញ្ហា', 'Error')}៖ $e");
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
        title: Text(_t("ការកុម្ម៉ង់ជោគជ័យ!", "Order submitted!")),
        content: Text(
          _t(
            "ការកម្មង់រួចរាល់ រង់ចាំការបញ្ជាក់។ អ្នកអាចត្រឡប់ទៅផ្ទាំងដើមបាន។",
            "Your order was submitted and is awaiting confirmation. You may return to the home screen.",
          ),
        ),
        actions: [
          Center(
            child: ElevatedButton(
              onPressed: () =>
                  Navigator.of(context).popUntil((route) => route.isFirst),
              child: Text(_t("ត្រឡប់ទៅផ្ទាំងដើម", "Return home")),
            ),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _saveAssetQrToGallery() async {
    final byteData = await rootBundle.load('assets/aba_qr.png');
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/aba_qr_download.png');
    await file.writeAsBytes(
      byteData.buffer.asUint8List(
        byteData.offsetInBytes,
        byteData.lengthInBytes,
      ),
    );
    await Gal.putImage(file.path);
  }

  Future<void> _launchABA() async {
    final Uri url = Uri.parse('https://pay.ababank.com/oRF8/oizn40j9');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      await launchUrl(url, mode: LaunchMode.platformDefault);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_t("ទូទាត់ប្រាក់", "Checkout")),
        backgroundColor: Colors.green[700],
        elevation: 0,
      ),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInput(
                _t("ឈ្មោះអ្នកទទួល", "Recipient name"),
                _nameController,
                Icons.person,
              ),
              _buildInput(
                _t("លេខទូរស័ព្ទ", "Phone number"),
                _phoneController,
                Icons.phone,
                inputType: TextInputType.phone,
              ),
              const SizedBox(height: 10),
              _buildLocationDropdowns(),
              const SizedBox(height: 10),
              _buildInput(
                _t(
                  "អាសយដ្ឋានលម្អិត (មិនចាំបាច់)",
                  "Detailed address (optional)",
                ),
                _addressController,
                Icons.location_on,
                maxLines: 1,
              ),
              const Divider(height: 20),
              Center(
                child: Text(
                  _t("ស្កេនបង់ប្រាក់", "Scan to pay"),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: GestureDetector(
                  onLongPress: () async {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(_t("⌛️ កំពុងរក្សាទុក...", "⌛️ Saving...")),
                      ),
                    );
                    await _saveAssetQrToGallery();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(_t(
                            "✅ រក្សាទុកជោគជ័យ!",
                            "✅ Saved successfully!",
                          )),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
                  child: Image.asset(
                    "assets/aba_qr.png",
                    height: 200,
                    errorBuilder: (c, e, s) =>
                        const Icon(Icons.qr_code, size: 60),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: Text(
                  "${currencyFormat.format(_total)} ៛",
                  style: const TextStyle(
                    fontSize: 20,
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
                  size: 19,
                ),
                label: Text(
                  _t("បង់ប្រាក់តាម App ABA", "Pay with ABA app"),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF005D7E),
                  minimumSize: const Size(double.infinity, 40),
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: GestureDetector(
                  onTap: () => _showPickImageDialog(),
                  child: Container(
                    height: 140,
                    width: 140,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: Colors.green.withOpacity(0.5),
                        width: 2,
                      ),
                    ),
                    child: _paymentImageBytes == null
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.add_a_photo_rounded,
                                size: 36,
                                color: Colors.green,
                              ),
                              Text(
                                _t(
                                  "ដាក់រូបវិក្កយបត្រ",
                                  "Attach payment receipt",
                                ),
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 11),
                              ),
                            ],
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(13),
                            child: Image.memory(
                              _paymentImageBytes!,
                              fit: BoxFit.contain,
                              gaplessPlayback: true,
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  minimumSize: const Size(double.infinity, 46),
                ),
                onPressed: _isProcessing ? null : _confirmOrder,
                child: _isProcessing
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        _t("បញ្ជាក់ការកុម្ម៉ង់", "Confirm order"),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
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
              title: Text(_t('ថតរូប', 'Take a photo')),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.blue),
              title: Text(_t('ជ្រើសរើសពីអាល់ប៊ុម', 'Choose from gallery')),
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
          isDense: true,
          style: const TextStyle(fontSize: 13, fontFamily: 'Siemreap'),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 10,
            ),
            labelText: _t("ជ្រើសរើសខេត្ត/ក្រុង", "Select province/city"),
            labelStyle: const TextStyle(
              fontSize: 12,
              fontFamily: 'Siemreap',
            ),
            prefixIcon: const Icon(Icons.map_outlined, size: 20),
            prefixIconConstraints: const BoxConstraints(minWidth: 38),
            border: const OutlineInputBorder(),
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
          dense: true,
          visualDensity: const VisualDensity(vertical: -3),
          contentPadding: EdgeInsets.zero,
          title: Text(
            _t("ផ្ញើតាមវិរៈប៊ុនថាំ", "Ship with Vireak Buntham"),
            style: const TextStyle(
              fontSize: 12,
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
                  isDense: true,
                  style: const TextStyle(
                    fontSize: 13,
                    fontFamily: 'Siemreap',
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    labelText: _t(
                      "ជ្រើសរើសសាខាវិរៈ",
                      "Select Vireak Buntham branch",
                    ),
                    labelStyle: const TextStyle(
                      fontSize: 12,
                      fontFamily: 'Siemreap',
                    ),
                    prefixIcon: const Icon(
                      Icons.location_on,
                      color: Colors.red,
                      size: 20,
                    ),
                    prefixIconConstraints: const BoxConstraints(minWidth: 38),
                    border: const OutlineInputBorder(),
                  ),
                  items: (VETData.branches[selectedProvince] ?? [])
                      .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                      .toList(),
                  onChanged: (val) =>
                      setState(() => selectedVireakBranch = val),
                )
              : DropdownButtonFormField<String>(
                  value: selectedDistrict,
                  isDense: true,
                  style: const TextStyle(
                    fontSize: 13,
                    fontFamily: 'Siemreap',
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    labelText: _t(
                      "ជ្រើសរើសស្រុក/ខណ្ឌ",
                      "Select district",
                    ),
                    labelStyle: const TextStyle(
                      fontSize: 12,
                      fontFamily: 'Siemreap',
                    ),
                    prefixIcon: const Icon(Icons.location_city, size: 20),
                    prefixIconConstraints: const BoxConstraints(minWidth: 38),
                    border: const OutlineInputBorder(),
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
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: controller,
        keyboardType: inputType,
        maxLines: maxLines,
        style: const TextStyle(fontSize: 13, fontFamily: 'Siemreap'),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 10,
          ),
          prefixIcon: Icon(icon, size: 20),
          prefixIconConstraints: const BoxConstraints(minWidth: 38),
          labelText: hint,
          labelStyle: const TextStyle(fontSize: 12, fontFamily: 'Siemreap'),
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
