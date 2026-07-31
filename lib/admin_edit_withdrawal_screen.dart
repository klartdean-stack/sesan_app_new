import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class AdminEditWithdrawalScreen extends StatefulWidget {
  final String userId;
  final Map<String, dynamic> userData;

  const AdminEditWithdrawalScreen({
    super.key,
    required this.userId,
    required this.userData,
  });

  @override
  State<AdminEditWithdrawalScreen> createState() => _AdminEditWithdrawalScreenState();
}

class _AdminEditWithdrawalScreenState extends State<AdminEditWithdrawalScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _fullNameKhController;
  late TextEditingController _bankAccountNumberController;
  late TextEditingController _idNumberController;

  File? _qrImageFile;
  String? _currentQrImageUrl;
  String _selectedBank = 'ABA';

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fullNameKhController = TextEditingController(text: widget.userData['full_name_kh'] ?? '');
    _bankAccountNumberController = TextEditingController(text: widget.userData['bank_account_number'] ?? '');
    _idNumberController = TextEditingController(text: widget.userData['id_card'] ?? '');
    _selectedBank = widget.userData['bank_name'] ?? 'ABA';
    _currentQrImageUrl = widget.userData['bank_qr_url'] ?? '';
  }

  @override
  void dispose() {
    _fullNameKhController.dispose();
    _bankAccountNumberController.dispose();
    _idNumberController.dispose();
    super.dispose();
  }

  Future<void> _saveWithdrawalInfo() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      String finalQrUrl = _currentQrImageUrl ?? '';

      if (_qrImageFile != null) {
        final qrRef = FirebaseStorage.instance.ref().child('qr_codes/${widget.userId}.jpg');
        await qrRef.putFile(_qrImageFile!);
        finalQrUrl = await qrRef.getDownloadURL();
      }

      await FirebaseFirestore.instance.collection('users').doc(widget.userId).update({
        'full_name_kh': _fullNameKhController.text.trim(),
        'bank_name': _selectedBank,
        'bank_account_number': _bankAccountNumberController.text.trim(),
        'bank_qr_url': finalQrUrl,
        'id_card': _idNumberController.text.trim(),
        'updated_at': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ រក្សាទុកជោគជ័យ"), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("❌ បញ្ហា: $e")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('កែប្រែព័ត៌មានដកប្រាក់', style: TextStyle(fontFamily: 'KHMEROS')),
          backgroundColor: Colors.orange[800],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
            padding: const EdgeInsets.all(25),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                // ឈ្មោះពេញ
                TextFormField(
                controller: _fullNameKhController,
                decoration: const InputDecoration(
                  labelText: 'ឈ្មោះពិត (អក្សរឡាតាំង/ខ្មែរ)',
                  prefixIcon: Icon(Icons.badge),
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'សូមបំពេញឈ្មោះពិត' : null,
              ),
              const SizedBox(height: 20),
                // ធនាគារ
                DropdownButtonFormField<String>(
                  value: _selectedBank,
                  decoration: const InputDecoration(
                    labelText: 'រើសធនាគារ',
                    prefixIcon: Icon(Icons.account_balance, color: Colors.green),
                    border: OutlineInputBorder(),
                  ),
                  items: ['ABA', 'ACLEDA', 'Wing', 'Canadia']
                      .map((bank) => DropdownMenuItem(value: bank, child: Text(bank)))
                      .toList(),
                  onChanged: (val) => setState(() => _selectedBank = val!),
                ),
                const SizedBox(height: 20),

                // លេខគណនី
                TextFormField(
                  controller: _bankAccountNumberController,
                  decoration: const InputDecoration(
                    labelText: 'លេខគណនីធនាគារ',
                    prefixIcon: Icon(Icons.credit_card),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'សូមបំពេញលេខគណនី' : null,
                ),
                const SizedBox(height: 20),

                // លេខអត្តសញ្ញាណ
                TextFormField(
                  controller: _idNumberController,
                  decoration: const InputDecoration(
                    labelText: 'លេខអត្តសញ្ញាណ (9 ខ្ទង់)',
                    prefixIcon: Icon(Icons.credit_card),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  maxLength: 9,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'សូមបញ្ចូលលេខអត្តសញ្ញាណ';
                    if (v.trim().length != 9) return 'ត្រូវមាន ៩ ខ្ទង់';
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // QR Code
                const Text('រូបភាព KHQR សម្រាប់ទទួលលុយ'),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () async {
                    final picker = ImagePicker();
                    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
                    if (image != null) setState(() => _qrImageFile = File(image.path));
                  },
                  child: Container(
                    height: 150,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.grey[50],
                    ),
                    child: _qrImageFile != null
                        ? Image.file(_qrImageFile!, fit: BoxFit.contain)
                        : (_currentQrImageUrl != null && _currentQrImageUrl!.isNotEmpty)
                        ? Image.network(_currentQrImageUrl!, fit: BoxFit.contain)
                        : const Icon(Icons.qr_code_scanner, size: 50, color: Colors.grey),
                  ),
                ),

                const SizedBox(height: 30),

                // ប៊ូតុងរក្សាទុក
                SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                        onPressed: _saveWithdrawalInfo,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[800],
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      child: const Text('រក្សាទុក', style: TextStyle(color: Colors.white, fontSize: 18)),
                    ),
                ),
                ],
              ),
            ),
        ),
    );
  }
}