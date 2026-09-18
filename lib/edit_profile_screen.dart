import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:my_app/otp_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'localized_text.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  String? uid;

  // Controllers
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _fullNameKhController;
  late TextEditingController _bankAccountNumberController;
  late TextEditingController _idNumberController;
  late TextEditingController _idNumberConfirmController;

  // Images & QR
  File? _imageFile;
  File? _qrImageFile;
  String? _currentImageUrl;
  String? _currentQrImageUrl;
  String? _storedNationalId;

  String _selectedBank = 'ABA';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeUser();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _fullNameKhController = TextEditingController();
    _bankAccountNumberController = TextEditingController();
    _idNumberController = TextEditingController();
    _idNumberConfirmController = TextEditingController();
  }

  Future<void> _initializeUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? tempUid = prefs.getString('user_uid');
      if (tempUid == null || tempUid.isEmpty) {
        final user = FirebaseAuth.instance.currentUser;
        tempUid = user?.uid;
      }
      if (tempUid != null && tempUid.isNotEmpty) {
        setState(() => uid = tempUid);
        _loadUserData();
      }
    } catch (e) {
      debugPrint("Error initializing user: $e");
    }
  }

  void _loadUserData() async {
    if (uid == null || uid!.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      var doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (doc.exists) {
        Map<String, dynamic> data = doc.data()!;
        setState(() {
          _nameController.text = data['name'] ?? '';
          _phoneController.text = data['phone'] ?? '';
          _currentImageUrl = data['photoUrl'] ?? '';

          _fullNameKhController.text = data['full_name_kh'] ?? '';
          _bankAccountNumberController.text = data['bank_account_number'] ?? '';
          _selectedBank = data['bank_name'] ?? 'ABA';
          _currentQrImageUrl = data['bank_qr_url'] ?? '';
          _storedNationalId = data['id_card'] ?? '';
          _idNumberController.text = _storedNationalId ?? '';
        });
      }
    } catch (e) {
      debugPrint("Load error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 50);
    if (image != null) setState(() => _imageFile = File(image.path));
  }

  // ─── រក្សាទុក Profile មូលដ្ឋាន (ឈ្មោះ, លេខទូរស័ព្ទ, រូបថត) ────────────
  Future<void> _saveBasicProfile() async {
    setState(() => _isLoading = true);
    try {
      String finalImageUrl = _currentImageUrl ?? '';
      if (_imageFile != null) {
        final storageRef = FirebaseStorage.instance.ref().child(
            'profiles/$uid.jpg');
        await storageRef.putFile(_imageFile!);
        finalImageUrl = await storageRef.getDownloadURL();
      }
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'photoUrl': finalImageUrl,
        'updated_at': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(appText(context,
                km: "✅ រក្សាទុក Profile ជោគជ័យ",
                en: "✅ Profile saved successfully")),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(appText(context,
                km: "❌ បញ្ហា: $e", en: "❌ Error: $e"))));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── រក្សាទុកព័ត៌មានដកប្រាក់ ──────────
  Future<void> _saveWithdrawalInfo() async {
    if (!_formKey.currentState!.validate()) return;

    String idNumber = _idNumberController.text.trim();
    String idNumberConfirm = _idNumberConfirmController.text.trim();

    // ពិនិត្យលេខអត្តសញ្ញាណ
    if (_storedNationalId != null && _storedNationalId!.isNotEmpty) {
      if (idNumber != _storedNationalId!.trim()) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(appText(context,
                  km: "លេខអត្តសញ្ញាណមិនត្រឹមត្រូវ មិនអាចកែប្រែបាន",
                  en: "The ID number is incorrect and cannot be changed")),
              backgroundColor: Colors.red),
        );
        return;
      }
    } else {
      if (idNumber.isEmpty || idNumberConfirm.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(appText(context,
              km: "សូមបំពេញលេខអត្តសញ្ញាណឲ្យបានពីរដង",
              en: "Please enter the ID number twice")),
              backgroundColor: Colors.red),
        );
        return;
      }
      if (idNumber != idNumberConfirm) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(appText(context,
              km: "លេខអត្តសញ្ញាណមិនត្រូវគ្នា",
              en: "The ID numbers do not match")),
              backgroundColor: Colors.red),
        );
        return;
      }
      if (idNumber.length != 9) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(appText(context,
              km: "លេខអត្តសញ្ញាណត្រូវមាន ៩ ខ្ទង់",
              en: "The ID number must be 9 digits")),
              backgroundColor: Colors.red),
        );
        return;
      }
    }

    setState(() => _isLoading = true);
    try {
      String finalQrUrl = _currentQrImageUrl ?? '';
      if (_qrImageFile != null) {
        final qrRef = FirebaseStorage.instance.ref().child('qr_codes/$uid.jpg');
        await qrRef.putFile(_qrImageFile!);
        finalQrUrl = await qrRef.getDownloadURL();
      }

      Map<String, dynamic> updateData = {
        'full_name_kh': _fullNameKhController.text.trim(),
        'bank_name': _selectedBank,
        'bank_account_number': _bankAccountNumberController.text.trim(),
        'bank_qr_url': finalQrUrl,
        'id_card': idNumber.isNotEmpty ? idNumber : FieldValue.delete(),
        'updated_at': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance.collection('users').doc(uid).update(
          updateData);

      setState(() {
        _storedNationalId = idNumber.isNotEmpty ? idNumber : null;
        _idNumberConfirmController.clear();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(appText(context,
              km: "✅ រក្សាទុកព័ត៌មានដកប្រាក់ជោគជ័យ",
              en: "✅ Withdrawal information saved successfully")),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(appText(context,
                km: "❌ បញ្ហា: $e", en: "❌ Error: $e"))));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ផ្លាស់ប្តូរលេខសម្ងាត់
  void _showChangePasswordDialog() {
    final oldPassController = TextEditingController();
    final newPassController = TextEditingController();
    final confirmPassController = TextEditingController();
    final formKeyDialog = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) =>
          AlertDialog(
            title: Text(appText(context,
                km: "ប្ដូរលេខសម្ងាត់ ៦ ខ្ទង់", en: "Change 6-digit PIN"),
                style: const TextStyle(fontFamily: 'KHMEROS')),
            content: Form(
              key: formKeyDialog,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDialogInput(oldPassController,
                      appText(context, km: "លេខសម្ងាត់ចាស់", en: "Old PIN")),
                  _buildDialogInput(newPassController,
                      appText(context, km: "លេខសម្ងាត់ថ្មី", en: "New PIN")),
                  _buildDialogInput(confirmPassController,
                      appText(context, km: "បញ្ជាក់លេខថ្មី", en: "Confirm new PIN")),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context),
                  child: Text(appText(context, km: "បោះបង់", en: "Cancel"))),
              ElevatedButton(
                onPressed: () {
                  if (formKeyDialog.currentState!.validate()) {
                    _updateTransactionPassword(
                      oldPassController.text.trim(),
                      newPassController.text.trim(),
                      confirmPassController.text.trim(),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700]),
                child: Text(
                    appText(context, km: "រក្សាទុក", en: "Save"),
                    style: const TextStyle(color: Colors.white)),
              ),
            ],
          ),
    );
  }

  Future<void> _updateTransactionPassword(String oldP, String newP,
      String confirmP) async {
    if (newP != confirmP) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(appText(context,
                km: "❌ លេខថ្មីមិនស៊ីគ្នា",
                en: "❌ The new PINs do not match")),
            backgroundColor: Colors.red),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      var doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      String currentPass = doc.data()?['password'] ?? '';
      if (oldP == currentPass) {
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'password': newP,
          'lastUpdate': FieldValue.serverTimestamp(),
        });
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(appText(context,
                  km: "✅ ប្ដូរជោគជ័យ", en: "✅ Changed successfully")),
              backgroundColor: Colors.green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(appText(context,
              km: "❌ លេខចាស់មិនត្រឹមត្រូវ",
              en: "❌ The old PIN is incorrect")),
              backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(appText(context,
              km: "❌ បញ្ហា: $e", en: "❌ Error: $e"))));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildDialogInput(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextFormField(
        controller: controller,
        keyboardType: TextInputType.number,
        maxLength: 6,
        obscureText: true,
        decoration: InputDecoration(labelText: label),
        validator: (value) => value!.length < 6
            ? appText(context, km: "ត្រូវមាន ៦ ខ្ទង់", en: "Must be 6 digits")
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(appText(context,
            km: "កែប្រែព័ត៌មានផ្ទាល់ខ្លួន", en: "Edit profile"),
            style: const TextStyle(fontFamily: 'KHMEROS')),
        backgroundColor: Colors.green[700],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(25),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Profile image
              GestureDetector(
                onTap: _pickImage,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.grey[300],
                      backgroundImage: _imageFile != null
                          ? FileImage(_imageFile!)
                          : (_currentImageUrl != null &&
                          _currentImageUrl!.isNotEmpty ? NetworkImage(
                          _currentImageUrl!) as ImageProvider
                          : null),
                      child: (_imageFile == null && (_currentImageUrl == null ||
                          _currentImageUrl!.isEmpty))
                          ? const Icon(
                          Icons.person, size: 60, color: Colors.white)
                          : null,
                    ),
                    Positioned(
                      bottom: 0, right: 0,
                      child: CircleAvatar(
                        backgroundColor: Colors.green[700], radius: 18,
                        child: const Icon(
                            Icons.camera_alt, size: 18, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              // Basic info fields (no validation)
              _buildInput(_nameController,
                  appText(context, km: "ឈ្មោះបង្ហាញ", en: "Display name"),
                  Icons.person),
              _buildInput(
                  _phoneController,
                  appText(context, km: "លេខទូរស័ព្ទ", en: "Phone number"),
                  Icons.phone, isNumber: true),
              const SizedBox(height: 20),

              // Save Basic Profile button
              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton(
                  onPressed: _saveBasicProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(appText(context,
                      km: "រក្សាទុក Profile", en: "Save profile"),
                      style: const TextStyle(color: Colors.white, fontSize: 16)),
                ),
              ),

              const SizedBox(height: 40),
              const Divider(height: 1, thickness: 1),
              const SizedBox(height: 15),

              // Withdrawal info section
              Text(appText(context,
                  km: "ព័ត៌មានសម្រាប់ដកប្រាក់ (បំពេញម្តងគត់)",
                  en: "Withdrawal information (complete once)"),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.blueGrey)),
              const SizedBox(height: 15),

              // Full name (required)
              _buildInput(_fullNameKhController,
                  appText(context,
                      km: "ឈ្មោះពិត (អក្សរឡាតាំង/ខ្មែរ)",
                      en: "Full name (Latin/Khmer)"),
                  Icons.badge,
                  validator: (v) =>
                  (v == null || v
                      .trim()
                      .isEmpty) ? appText(context,
                          km: "សូមបំពេញឈ្មោះពិត",
                          en: "Please enter your full name") : null),

              // Bank dropdown (required implicitly)
              DropdownButtonFormField<String>(
                value: _selectedBank,
                decoration: InputDecoration(
                  labelText: appText(context,
                      km: "រើសធនាគារ", en: "Select a bank"),
                  prefixIcon: const Icon(
                      Icons.account_balance, color: Colors.green),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                items: ['ABA', 'ACLEDA', 'Wing', 'Canadia']
                    .map((bank) =>
                    DropdownMenuItem(value: bank, child: Text(bank)))
                    .toList(),
                onChanged: (val) => setState(() => _selectedBank = val!),
              ),
              const SizedBox(height: 20),

              // Bank account number (required)
              _buildInput(_bankAccountNumberController,
                  appText(context,
                      km: "លេខគណនីធនាគារ (តែ ៛)",
                      en: "Bank account number (KHR only)"),
                  Icons.credit_card, isNumber: true,
                  validator: (v) =>
                  (v == null || v
                      .trim()
                      .isEmpty) ? appText(context,
                          km: "សូមបំពេញលេខគណនី",
                          en: "Please enter the account number") : null),

              const SizedBox(height: 20),
              Text(appText(context,
                  km: "លេខអត្តសញ្ញាណ (សម្រាប់សុវត្ថិភាព)",
                  en: "ID number (for security)"),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              // National ID field
              TextFormField(
                controller: _idNumberController,
                keyboardType: TextInputType.number,
                maxLength: 9,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(9)
                ],
                decoration: InputDecoration(
                  labelText: appText(context,
                      km: "លេខអត្តសញ្ញាណ (9 ខ្ទង់)",
                      en: "ID number (9 digits)"),
                  prefixIcon: const Icon(Icons.credit_card),
                  counterText: "",
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) {
                  if (_storedNationalId != null &&
                      _storedNationalId!.isNotEmpty) {
                    // Must match old ID
                    if (v == null || v
                        .trim()
                        .isEmpty) return appText(context,
                            km: "សូមបញ្ចូលលេខអត្តសញ្ញាណចាស់",
                            en: "Please enter the existing ID number");
                    if (v.trim() != _storedNationalId!.trim())
                      return appText(context,
                          km: "លេខអត្តសញ្ញាណមិនត្រឹមត្រូវ",
                          en: "The ID number is incorrect");
                  } else {
                    // First time: must not be empty and 9 digits
                    if (v == null || v
                        .trim()
                        .isEmpty) return appText(context,
                            km: "សូមបញ្ចូលលេខអត្តសញ្ញាណ",
                            en: "Please enter the ID number");
                    if (v
                        .trim()
                        .length != 9) return appText(context,
                            km: "ត្រូវមាន ៩ ខ្ទង់", en: "Must be 9 digits");
                  }
                  return null;
                },
              ),
              // Confirm ID field (only for first time)
              if (_storedNationalId == null || _storedNationalId!.isEmpty) ...[
                const SizedBox(height: 10),
                TextFormField(
                  controller: _idNumberConfirmController,
                  keyboardType: TextInputType.number,
                  maxLength: 9,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(9)
                  ],
                  decoration: InputDecoration(
                    labelText: appText(context,
                        km: "បញ្ជាក់លេខអត្តសញ្ញាណ",
                        en: "Confirm ID number"),
                    prefixIcon: const Icon(Icons.credit_card),
                    counterText: "",
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (v) {
                    if (v == null || v
                        .trim()
                        .isEmpty) return appText(context,
                            km: "សូមបញ្ជាក់លេខអត្តសញ្ញាណ",
                            en: "Please confirm the ID number");
                    if (v.trim() != _idNumberController.text.trim())
                      return appText(context,
                          km: "មិនត្រូវគ្នា", en: "Does not match");
                    return null;
                  },
                ),
              ],

              const SizedBox(height: 20),
              Text(appText(context,
                  km: "រូបភាព KHQR សម្រាប់ទទួលលុយ",
                  en: "KHQR image for receiving payments")),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () async {
                  final picker = ImagePicker();
                  final XFile? image = await picker.pickImage(
                      source: ImageSource.gallery);
                  if (image != null) setState(() =>
                  _qrImageFile = File(image.path));
                },
                child: Container(
                  height: 150, width: double.infinity,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.grey[50],
                  ),
                  child: _qrImageFile != null
                      ? Image.file(_qrImageFile!, fit: BoxFit.contain)
                      : (_currentQrImageUrl != null &&
                      _currentQrImageUrl!.isNotEmpty)
                      ? Image.network(_currentQrImageUrl!, fit: BoxFit.contain)
                      : const Icon(
                      Icons.qr_code_scanner, size: 50, color: Colors.grey),
                ),
              ),
              const SizedBox(height: 30),
              // Save withdrawal info button
              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton(
                  onPressed: _saveWithdrawalInfo,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[800],
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(appText(context,
                      km: "រក្សាទុកព័ត៌មានដកប្រាក់",
                      en: "Save withdrawal information"),
                      style: const TextStyle(color: Colors.white, fontSize: 16)),
                ),
              ),

              const SizedBox(height: 30),
              const Divider(),

              // Change password
              OutlinedButton.icon(
                onPressed: _showChangePasswordDialog,
                icon: const Icon(Icons.lock_outline),
                label: Text(appText(context,
                    km: "ប្ដូរលេខសម្ងាត់ ៦ ខ្ទង់",
                    en: "Change 6-digit PIN")),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  foregroundColor: Colors.green[700],
                  side: BorderSide(color: Colors.green[700]!),
                ),
              ),
              const SizedBox(height: 10),
              // Forgot password
              TextButton(
                onPressed: () async {
                  String phoneNumber = _phoneController.text.trim();
                  if (phoneNumber.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(appText(context,
                          km: "សូមបំពេញលេខទូរស័ព្ទសិន!",
                          en: "Please enter your phone number first!"))),
                    );
                    return;
                  }
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) =>
                    const Center(child: CircularProgressIndicator()),
                  );
                  await FirebaseAuth.instance.verifyPhoneNumber(
                    phoneNumber: phoneNumber,
                    verificationCompleted: (
                        PhoneAuthCredential credential) async {},
                    verificationFailed: (FirebaseAuthException e) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(appText(context,
                            km: "ផ្ញើសារមិនជោគជ័យ៖ ${e.message}",
                            en: "Could not send the message: ${e.message}"))),
                      );
                    },
                    codeSent: (String verificationId, int? resendToken) {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              OTPScreen(
                                verificationId: verificationId,
                                name: "ResetPassword",
                                phone: phoneNumber,
                                password: "",
                              ),
                        ),
                      );
                    },
                    codeAutoRetrievalTimeout: (String verificationId) {},
                  );
                },
                child: Text(appText(context,
                    km: "ភ្លេចលេខសម្ងាត់? កំណត់ឡើងវិញតាម OTP",
                    en: "Forgot your PIN? Reset it with OTP"),
                    style: const TextStyle(color: Colors.grey,
                        fontSize: 14,
                        fontFamily: 'KHMEROS')),
              ),
            ],
          ),
        ),
      ),
    );
  }
// Reusable text field with optional validator
  Widget _buildInput(
      TextEditingController controller,
      String label,
      IconData icon, {
        bool isNumber = false,
        String? Function(String?)? validator,
      }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: TextFormField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.phone : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.green[700]),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        validator: validator,
      ),
    );
  }
}
