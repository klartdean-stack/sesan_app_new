import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:my_app/download_helper.dart';
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
  String? selectedProvince;
  String? selectedDistrict;
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final User? currentUser = FirebaseAuth.instance.currentUser;
  final NumberFormat currencyFormat = NumberFormat('#,###', 'en_US');
  late final double _total;

  @override
  void initState() {
    super.initState();
    _loadSavedCustomerData();
    _total = widget.cartDocs.fold(0.0, (sum, doc) {
      final data = doc.data() as Map<String, dynamic>;
      final price = double.tryParse((data['price'] ?? 0).toString().replaceAll(',', '')) ?? 0;
      final qty = int.tryParse((data['quantity'] ?? 1).toString()) ?? 1;
      return sum + price * qty;
    });
  }

  Future<void> _loadSavedCustomerData() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _nameController.text = prefs.getString('saved_name') ?? currentUser?.displayName ?? '';
      _phoneController.text = prefs.getString('saved_phone') ?? currentUser?.phoneNumber ?? '';
      _addressController.text = prefs.getString('saved_address') ?? '';
    });
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
      final picked = await ImagePicker().pickImage(source: source, imageQuality: 80);
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        if (mounted) setState(() => _paymentImageBytes = bytes);
      }
    } catch (e) {
      debugPrint('Payment image error: $e');
    }
  }

  Future<void> _confirmOrder() async {
    if (_isProcessing) return;
    final hasLocation = selectedProvince != null &&
        (isVireakBuntham ? selectedVireakBranch != null : selectedDistrict != null);
    final hasAddress = _addressController.text.trim().isNotEmpty;
    if (_nameController.text.trim().isEmpty || _phoneController.text.trim().isEmpty) {
      _snack(_t('សូមបំពេញឈ្មោះ និងលេខទូរស័ព្ទ!', 'Please enter the recipient name and phone number.'));
      return;
    }
    if (!hasLocation && !hasAddress) {
      _snack(_t('សូមជ្រើសរើសទីតាំង ឬបំពេញអាសយដ្ឋានដឹកជញ្ជូន!', 'Please select a location or enter a delivery address.'));
      return;
    }
    if (_paymentImageBytes == null || _paymentImageBytes!.isEmpty) {
      _snack(_t('សូមជ្រើសរើសរូបភាពប្លង់ផ្ទេរលុយសិន!', 'Please attach the payment receipt.'));
      return;
    }
    setState(() => _isProcessing = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final customerId = prefs.getString('user_uid') ?? currentUser?.uid ?? 'GUEST';
      await prefs.setString('saved_name', _nameController.text.trim());
      await prefs.setString('saved_phone', _phoneController.text.trim());
      await prefs.setString('saved_address', _addressController.text.trim());
      final locationInfo = isVireakBuntham
          ? "${_t('ផ្ញើតាមវិរៈ', 'Vireak Buntham')} (${_t('សាខា', 'branch')}: $selectedVireakBranch)"
          : "${_t('ស្រុក', 'district')}: ${selectedDistrict ?? ''}";
      final finalAddress = '${selectedProvince ?? ''}, $locationInfo, ${_addressController.text.trim()}';
      double exactTotal = 0;
      final cartItems = widget.cartDocs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final price = double.tryParse((data['price'] ?? 0).toString().replaceAll(',', '')) ?? 0;
        final quantity = int.tryParse((data['quantity'] ?? 1).toString()) ?? 1;
        exactTotal += price * quantity;
        return <String, dynamic>{
          'product_id': data['product_id'] ?? doc.id,
          'product_name': data['product_name'] ?? '',
          'price': price,
          'quantity': quantity,
          'image_url': data['image_url'] ?? '',
          'seller_id': data['seller_id'] ?? 'UNKNOWN_ID',
          'seller_name': data['seller_name'] ?? 'Sesan Seller',
          'seller_photo': data['seller_photo'] ?? '',
          'seller_phone': data['seller_phone'] ?? '',
          'order_date': FieldValue.serverTimestamp(),
        };
      }).toList();
      final fileName = DateTime.now().millisecondsSinceEpoch.toString();
      final storageRef = FirebaseStorage.instance.ref().child('payments/$fileName.jpg');
      await storageRef.putData(_paymentImageBytes!, SettableMetadata(contentType: 'image/jpeg')).timeout(const Duration(seconds: 30));
      final paymentUrl = await storageRef.getDownloadURL().timeout(const Duration(seconds: 15));
      final service = OrderService();
      final success = await service.createOrder(
        cartItems: cartItems,
        totalAmount: exactTotal,
        customerId: customerId,
        customerName: _nameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        shippingAddress: finalAddress,
        paymentImage: paymentUrl,
      ).timeout(const Duration(seconds: 20));
      if (!success) {
        if (mounted) _snack(_t('ការបង្កើតការបញ្ជាទិញមានបញ្ហា!', 'Could not create the order.'));
        return;
      }
      try {
        await service.clearCart(customerId).timeout(const Duration(seconds: 8));
      } catch (e) {
        debugPrint('Order exists; cart cleanup can retry later: $e');
      }
      if (mounted) _showSuccessDialog();
    } catch (e) {
      if (mounted) _snack('${_t('មានបញ្ហា', 'Error')}: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _snack(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  void _showSuccessDialog() => showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => AlertDialog(
      title: Text(_t('ការកុម្ម៉ង់ជោគជ័យ!', 'Order submitted!')),
      content: Text(_t('ការកម្មង់រួចរាល់ រង់ចាំការបញ្ជាក់។', 'Your order was submitted and is awaiting confirmation.')),
      actions: [ElevatedButton(onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst), child: Text(_t('ត្រឡប់ទៅផ្ទាំងដើម', 'Return home')))],
    ),
  );

  Future<void> _launchABA() async {
    final url = Uri.parse('https://pay.ababank.com/oRF8/lq8jgwzb');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      await launchUrl(url, mode: LaunchMode.platformDefault);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(_t('ទូទាត់ប្រាក់', 'Checkout')), backgroundColor: Colors.green[700]),
    body: SafeArea(child: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(children: [
      _input(_t('ឈ្មោះអ្នកទទួល', 'Recipient name'), _nameController, Icons.person),
      _input(_t('លេខទូរស័ព្ទ', 'Phone number'), _phoneController, Icons.phone, type: TextInputType.phone),
      _locations(),
      _input(_t('អាសយដ្ឋានលម្អិត (មិនចាំបាច់)', 'Detailed address (optional)'), _addressController, Icons.location_on, maxLines: 2),
      const Divider(height: 35),
      Text(_t('ស្កេនបង់ប្រាក់', 'Scan to pay'), style: const TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 10),
      GestureDetector(onLongPress: () async {
        _snack(_t('⌛️ កំពុងរក្សាទុក...', '⌛️ Saving...'));
        await DownloadHelper.saveQRImage('https://firebasestorage.googleapis.com/v0/b/sesan-my-app.firebasestorage.app/o/20260308_163835.jpg?alt=media&token=95922392-ed40-4483-9097-899987ad06e8');
      }, child: Image.asset('assets/aba_qr.png', height: 150, errorBuilder: (_, __, ___) => const Icon(Icons.qr_code, size: 80))),
      const SizedBox(height: 8),
      Text('${currencyFormat.format(_total)} ៛', style: const TextStyle(fontSize: 24, color: Colors.red, fontWeight: FontWeight.bold)),
      const SizedBox(height: 10),
      ElevatedButton.icon(onPressed: _launchABA, icon: const Icon(Icons.account_balance_wallet), label: Text(_t('បង់ប្រាក់តាម App ABA', 'Pay with ABA app'))),
      const SizedBox(height: 18),
      GestureDetector(onTap: _showPickImageDialog, child: Container(width: 180, height: 180, decoration: BoxDecoration(border: Border.all(color: Colors.green), borderRadius: BorderRadius.circular(15)), child: _paymentImageBytes == null ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.add_a_photo, size: 48, color: Colors.green), Text(_t('ដាក់រូបវិក្កយបត្រ', 'Attach payment receipt'))]) : ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.memory(_paymentImageBytes!, fit: BoxFit.contain)))),
      const SizedBox(height: 25),
      ElevatedButton(onPressed: _isProcessing ? null : _confirmOrder, style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700], minimumSize: const Size(double.infinity, 52)), child: _isProcessing ? const CircularProgressIndicator(color: Colors.white) : Text(_t('បញ្ជាក់ការកុម្ម៉ង់', 'Confirm order'), style: const TextStyle(color: Colors.white))),
    ]))),
  );

  Widget _input(String label, TextEditingController controller, IconData icon, {TextInputType type = TextInputType.text, int maxLines = 1}) => Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(controller: controller, keyboardType: type, maxLines: maxLines, decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon), border: const OutlineInputBorder())));

  Widget _locations() => Column(children: [
    DropdownButtonFormField<String>(value: selectedProvince, decoration: InputDecoration(labelText: _t('ជ្រើសរើសខេត្ត/ក្រុង', 'Select province/city'), border: const OutlineInputBorder()), items: cambodiaProvinceData.keys.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(), onChanged: (v) => setState(() { selectedProvince = v; selectedDistrict = null; selectedVireakBranch = null; })),
    SwitchListTile(title: Text(_t('ផ្ញើតាមវិរៈប៊ុនថាំ', 'Ship with Vireak Buntham')), value: isVireakBuntham, onChanged: (v) => setState(() { isVireakBuntham = v; selectedDistrict = null; selectedVireakBranch = null; })),
    if (selectedProvince != null) DropdownButtonFormField<String>(value: isVireakBuntham ? selectedVireakBranch : selectedDistrict, decoration: InputDecoration(labelText: isVireakBuntham ? _t('ជ្រើសរើសសាខាវិរៈ', 'Select Vireak Buntham branch') : _t('ជ្រើសរើសស្រុក/ខណ្ឌ', 'Select district'), border: const OutlineInputBorder()), items: (isVireakBuntham ? (VETData.branches[selectedProvince] ?? <String>[]) : (cambodiaProvinceData[selectedProvince] ?? <String>[])).map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(), onChanged: (v) => setState(() { if (isVireakBuntham) selectedVireakBranch = v; else selectedDistrict = v; })),
    const SizedBox(height: 12),
  ]);

  void _showPickImageDialog() => showModalBottomSheet(context: context, builder: (_) => SafeArea(child: Wrap(children: [
    ListTile(leading: const Icon(Icons.camera_alt), title: Text(_t('ថតរូប', 'Take a photo')), onTap: () { Navigator.pop(context); _pickImage(ImageSource.camera); }),
    ListTile(leading: const Icon(Icons.photo_library), title: Text(_t('ជ្រើសរើសពីអាល់ប៊ុម', 'Choose from gallery')), onTap: () { Navigator.pop(context); _pickImage(ImageSource.gallery); }),
  ])));
}
