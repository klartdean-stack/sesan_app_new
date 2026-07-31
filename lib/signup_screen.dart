import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'otp_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _isConfirmVisible = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _verifyPhone() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final rawPhone = _phoneController.text.trim();
    final password = _passwordController.text.trim();

    final formattedPhone = rawPhone.startsWith('+')
        ? rawPhone
        : (rawPhone.startsWith('0')
        ? '+855${rawPhone.substring(1)}'
        : '+855$rawPhone');

    setState(() => _isLoading = true);

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: formattedPhone,
        verificationCompleted: (PhoneAuthCredential credential) async {
          final userCredential = await FirebaseAuth.instance
              .signInWithCredential(credential);
          await _saveUserToFirestore(
            userCredential.user!.uid,
            name,
            formattedPhone,
            password,
          );
        },
        verificationFailed: (FirebaseAuthException e) {
          if (mounted) {
            setState(() => _isLoading = false);
            _showSnackBar("❌ កំហុស: ${e.message}", isError: true);
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          if (mounted) {
            setState(() => _isLoading = false);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => OTPScreen(
                  verificationId: verificationId,
                  name: name,
                  phone: formattedPhone,
                  password: password,
                ),
              ),
            );
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {},
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar("⚠️ បញ្ហា៖ $e", isError: true);
      }
    }
  }

  Future<void> _saveUserToFirestore(
      String uid,
      String name,
      String phone,
      String password,
      ) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'uid': uid,
        'name': name,
        'phone': phone,
        'password': password,
        'balance': 0,
        'wallet_balance': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar("❌ បរាជ័យក្នុងការរក្សាទុកទិន្នន័យ", isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
            elevation: 0,
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios),
              onPressed: () => Navigator.pop(context),
            ),
          title: const Text(
            "បង្កើតគណនីថ្មី",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
            child: SingleChildScrollView(
                padding: const EdgeInsets.all(25.0),
                child: Form(
                    key: _formKey,
                    child: Column(
                        children: [
                        const Icon(Icons.person_add_rounded, size: 80, color: Colors.green),
                    const SizedBox(height: 10),
                    const Text(
                      "បំពេញព័ត៌មានខាងក្រោម",
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                    const SizedBox(height: 40),

                    // ឈ្មោះ
                    TextFormField(
                      controller: _nameController,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return 'សូមបញ្ចូលឈ្មោះ';
                        return null;
                      },
                      decoration: _inputDecoration("ឈ្មោះពេញ", Icons.person_outline),
                    ),
                    const SizedBox(height: 20),

                    // លេខទូរស័ព្ទ
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'សូមបញ្ចូលលេខទូរស័ព្ទ';
                        if (value.length < 9) return 'លេខទូរស័ព្ទមិនត្រឹមត្រូវ';
                        return null;
                      },
                      decoration: _inputDecoration("លេខទូរស័ព្ទ", Icons.phone_android_outlined),
                    ),
                    const SizedBox(height: 20),

                    // លេខសម្ងាត់ ៦ ខ្ទង់
                    TextFormField(
                      controller: _passwordController,
                      obscureText: !_isPasswordVisible,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'សូមបញ្ចូលលេខសម្ងាត់';
                        if (value.length != 6) return 'លេខសម្ងាត់ត្រូវតែមាន ៦ ខ្ទង់';
                        return null;
                      },
                      decoration: _inputDecoration(
                        "លេខសម្ងាត់ ៦ ខ្ទង់",
                        Icons.lock_outline,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                            color: Colors.grey,
                          ),
                          onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // បញ្ជាក់លេខសម្ងាត់
                    TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: !_isConfirmVisible,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'សូមបញ្ជាក់លេខសម្ងាត់';
                          if (value != _passwordController.text) return 'លេខសម្ងាត់មិនដូចគ្នា';
                          return null;
                        },
                      decoration: _inputDecoration(
                        "បញ្ជាក់លេខសម្ងាត់",
                        Icons.lock_reset,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isConfirmVisible ? Icons.visibility : Icons.visibility_off,
                            color: Colors.grey,
                          ),
                          onPressed: () => setState(() => _isConfirmVisible = !_isConfirmVisible),
                        ),
                      ),
                    ),

                          const SizedBox(height: 40),

                          SizedBox(
                            width: double.infinity,
                            height: 55,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _verifyPhone,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                              child: _isLoading
                                  ? const CircularProgressIndicator(color: Colors.white)
                                  : const Text(
                                "ផ្ញើលេខកូដ OTP",
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                    ),
                ),
            ),
        ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon, {Widget? suffixIcon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.green),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.grey[50],
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Colors.green, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Colors.red),
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}