import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:my_app/otp_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
          const SnackBar(content: Text("✅ រក្សាទុក Profile ជោគជ័យ"),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("❌ បញ្ហា: $e")));
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
          const SnackBar(
              content: Text("លេខអត្តសញ្ញាណមិនត្រឹមត្រូវ មិនអាចកែប្រែបាន"),
              backgroundColor: Colors.red),
        );
        return;
      }
    } else {
      if (idNumber.isEmpty || idNumberConfirm.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("សូមបំពេញលេខអត្តសញ្ញាណឲ្យបានពីរដង"),
              backgroundColor: Colors.red),
        );
        return;
      }
      if (idNumber != idNumberConfirm) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("លេខអត្តសញ្ញាណមិនត្រូវគ្នា"),
              backgroundColor: Colors.red),
        );
        return;
      }
      if (idNumber.length != 9) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("លេខអត្តសញ្ញាណត្រូវមាន ៩ ខ្ទង់"),
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
          const SnackBar(content: Text("✅ រក្សាទុកព័ត៌មានដកប្រាក់ជោគជ័យ"),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("❌ បញ្ហា: $e")));
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
            title: const Text("ប្ដូរលេខសម្ងាត់ ៦ ខ្ទង់",
                style: TextStyle(fontFamily: 'KHMEROS')),
            content: Form(
              key: formKeyDialog,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDialogInput(oldPassController, "លេខសម្ងាត់ចាស់"),
                  _buildDialogInput(newPassController, "លេខសម្ងាត់ថ្មី"),
                  _buildDialogInput(confirmPassController, "បញ្ជាក់លេខថ្មី"),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context),
                  child: const Text("បោះបង់")),
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
                child: const Text(
                    "រក្សាទុក", style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
    );
  }

  Future<void> _updateTransactionPassword(String oldP, String newP,
      String confirmP) async {
    if (newP != confirmP) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("❌ លេខថ្មីមិនស៊ីគ្នា"), backgroundColor: Colors.red),
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
          const SnackBar(
              content: Text("✅ ប្ដូរជោគជ័យ"), backgroundColor: Colors.green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("❌ លេខចាស់មិនត្រឹមត្រូវ"),
              backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ បញ្ហា: $e")));
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
        validator: (value) => value!.length < 6 ? "ត្រូវមាន ៦ ខ្ទង់" : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("កែប្រែព័ត៌មានផ្ទាល់ខ្លួន",
            style: TextStyle(fontFamily: 'KHMEROS')),
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
              _buildInput(_nameController, "ឈ្មោះបង្ហាញ", Icons.person),
              _buildInput(
                  _phoneController, "លេខទូរស័ព្ទ", Icons.phone, isNumber: true),
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
                  child: const Text("រក្សាទុក Profile",
                      style: TextStyle(color: Colors.white, fontSize: 16)),
                ),
              ),

              const SizedBox(height: 40),
              const Divider(height: 1, thickness: 1),
              const SizedBox(height: 15),

              // Withdrawal info section
              const Text("ព័ត៌មានសម្រាប់ដកប្រាក់ (បំពេញម្តងគត់)",
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.blueGrey)),
              const SizedBox(height: 15),

              // Full name (required)
              _buildInput(_fullNameKhController, "ឈ្មោះពិត (អក្សរឡាតាំង/ខ្មែរ)",
                  Icons.badge,
                  validator: (v) =>
                  (v == null || v
                      .trim()
                      .isEmpty) ? "សូមបំពេញឈ្មោះពិត" : null),

              // Bank dropdown (required implicitly)
              DropdownButtonFormField<String>(
                value: _selectedBank,
                decoration: InputDecoration(
                  labelText: "រើសធនាគារ",
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
              _buildInput(_bankAccountNumberController, "លេខគណនីធនាគារ (តែ ៛)",
                  Icons.credit_card, isNumber: true,
                  validator: (v) =>
                  (v == null || v
                      .trim()
                      .isEmpty) ? "សូមបំពេញលេខគណនី" : null),

              const SizedBox(height: 20),
              const Text("លេខអត្តសញ្ញាណ (សម្រាប់សុវត្ថិភាព)",
                  style: TextStyle(fontWeight: FontWeight.bold)),
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
                  labelText: "លេខអត្តសញ្ញាណ (9 ខ្ទង់)",
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
                        .isEmpty) return "សូមបញ្ចូលលេខអត្តសញ្ញាណចាស់";
                    if (v.trim() != _storedNationalId!.trim())
                      return "លេខអត្តសញ្ញាណមិនត្រឹមត្រូវ";
                  } else {
                    // First time: must not be empty and 9 digits
                    if (v == null || v
                        .trim()
                        .isEmpty) return "សូមបញ្ចូលលេខអត្តសញ្ញាណ";
                    if (v
                        .trim()
                        .length != 9) return "ត្រូវមាន ៩ ខ្ទង់";
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
                    labelText: "បញ្ជាក់លេខអត្តសញ្ញាណ",
                    prefixIcon: const Icon(Icons.credit_card),
                    counterText: "",
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (v) {
                    if (v == null || v
                        .trim()
                        .isEmpty) return "សូមបញ្ជាក់លេខអត្តសញ្ញាណ";
                    if (v.trim() != _idNumberController.text.trim())
                      return "មិនត្រូវគ្នា";
                    return null;
                  },
                ),
              ],

              const SizedBox(height: 20),
              const Text("រូបភាព KHQR សម្រាប់ទទួលលុយ"),
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
                  child: const Text("រក្សាទុកព័ត៌មានដកប្រាក់",
                      style: TextStyle(color: Colors.white, fontSize: 16)),
                ),
              ),

              const SizedBox(height: 30),
              const Divider(),

              // Change password
              OutlinedButton.icon(
                onPressed: _showChangePasswordDialog,
                icon: const Icon(Icons.lock_outline),
                label: const Text("ប្ដូរលេខសម្ងាត់ ៦ ខ្ទង់"),
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
                      const SnackBar(content: Text("សូមបំពេញលេខទូរស័ព្ទសិន!")),
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
                        SnackBar(content: Text(
                            "ផ្ញើសារមិនជោគជ័យ៖ ${e.message}")),
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
                child: const Text("ភ្លេចលេខសម្ងាត់? កំណត់ឡើងវិញតាម OTP",
                    style: TextStyle(color: Colors.grey,
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