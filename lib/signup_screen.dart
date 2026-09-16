import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:my_app/localization/app_translations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
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

  Future<void> _openLegalPage(String url) async {
    try {
      final opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!opened) throw Exception('Could not launch legal page');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            Localizations.localeOf(context).languageCode == 'en'
                ? 'Could not open this page. Please try again.'
                : 'មិនអាចបើកទំព័រនេះបានទេ សូមសាកម្ដងទៀត។',
          ),
        ),
      );
    }
  }

  // OTP សម្រាប់ verify phone ប៉ុណ្ណោះ
  Future<void> _sendOTP() async {
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
          // Auto-verification (Android) - បង្កើត user + link password
          await _handleAutoVerification(
            credential,
            name,
            formattedPhone,
            password,
          );
        },
        verificationFailed: (FirebaseAuthException e) {
          if (mounted) {
            setState(() => _isLoading = false);
            _showSnackBar("❌ ${'error'.tr}: ${e.message}", isError: true);
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
        _showSnackBar("⚠️ ${'problem'.tr}: $e", isError: true);
      }
    }
  }

  // Auto verification សម្រាប់ Android
  Future<void> _handleAutoVerification(
    PhoneAuthCredential phoneCredential,
    String name,
    String phone,
    String password,
  ) async {
    try {
      // 1. Login ដោយ OTP
      final userCredential = await FirebaseAuth.instance.signInWithCredential(
        phoneCredential,
      );

      // 2. Link ជាមួយ Email/Password
      final email = "${phone.replaceAll('+', '')}@sesan.app";
      final emailCredential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );

      await userCredential.user!.linkWithCredential(emailCredential);

      // 3. Save ទៅ Firestore
      await _saveUserToFirestore(
        userCredential.user!.uid,
        name,
        phone,
        password,
      );

      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar("❌ ${'failed'.tr}: $e", isError: true);
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
    } catch (e) {
      if (mounted) {
        _showSnackBar("❌ ${'save_failed'.tr}", isError: true);
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
        title: Text(
          'create_account'.tr,
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
                const Align(
                  alignment: Alignment.centerRight,
                  child: LanguageSwitcher(),
                ),
                const SizedBox(height: 16),
                const Icon(
                  Icons.person_add_rounded,
                  size: 80,
                  color: Colors.green,
                ),
                const SizedBox(height: 10),
                Text(
                  'fill_information'.tr,
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
                const SizedBox(height: 40),

                // ឈ្មោះ
                TextFormField(
                  controller: _nameController,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty)
                      return 'name_required'.tr;
                    return null;
                  },
                  decoration: _inputDecoration(
                    'full_name'.tr,
                    Icons.person_outline,
                  ),
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
                    if (value == null || value.isEmpty)
                      return 'phone_required'.tr;
                    if (value.length < 9) return 'phone_invalid'.tr;
                    return null;
                  },
                  decoration: _inputDecoration(
                    'phone'.tr,
                    Icons.phone_android_outlined,
                  ),
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
                    if (value == null || value.isEmpty)
                      return 'password_required'.tr;
                    if (value.length != 6)
                      return 'password_exact_6'.tr;
                    return null;
                  },
                  decoration: _inputDecoration(
                    'password_6_digits'.tr,
                    Icons.lock_outline,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPasswordVisible
                            ? Icons.visibility
                            : Icons.visibility_off,
                        color: Colors.grey,
                      ),
                      onPressed: () => setState(
                        () => _isPasswordVisible = !_isPasswordVisible,
                      ),
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
                    if (value == null || value.isEmpty)
                      return 'confirm_password_required'.tr;
                    if (value != _passwordController.text)
                      return 'password_mismatch'.tr;
                    return null;
                  },
                  decoration: _inputDecoration(
                    'confirm_password'.tr,
                    Icons.lock_reset,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isConfirmVisible
                            ? Icons.visibility
                            : Icons.visibility_off,
                        color: Colors.grey,
                      ),
                      onPressed: () => setState(
                        () => _isConfirmVisible = !_isConfirmVisible,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 14),
                Builder(
                  builder: (context) {
                    final isEnglish =
                        Localizations.localeOf(context).languageCode == 'en';
                    return Wrap(
                      alignment: WrapAlignment.start,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 3,
                      runSpacing: 0,
                      children: [
                        Text(
                          isEnglish
                              ? 'By continuing, you agree to the'
                              : 'ដោយបន្ត អ្នកយល់ព្រមតាម',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                            fontFamily: 'Siemreap',
                          ),
                        ),
                        InkWell(
                          onTap: () =>
                              _openLegalPage('https://about.sesanshop.com/terms'),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                              'Terms of Service',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.blue,
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ),
                        Text(
                          isEnglish ? 'and' : 'និង',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                            fontFamily: 'Siemreap',
                          ),
                        ),
                        InkWell(
                          onTap: () => _openLegalPage(
                            'https://about.sesanshop.com/privacy',
                          ),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                              'Privacy Policy',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.blue,
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _sendOTP,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            'send_otp'.tr,
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

  InputDecoration _inputDecoration(
    String label,
    IconData icon, {
    Widget? suffixIcon,
  }) {
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
