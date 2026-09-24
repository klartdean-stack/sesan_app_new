import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:my_app/localization/app_translations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'otp_screen.dart';
import 'package:my_app/controllers/auth_controller.dart';
import 'google_auth_service.dart';

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

  Future<void> _handleGoogleSignUp() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final result = await GoogleAuthService.signIn();
      if (result == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      await Get.find<AuthController>().loginWithUid(result.uid);

      if (!mounted) return;
      _showSnackBar(
        result.isNewUser
            ? (Localizations.localeOf(context).languageCode == 'en'
                ? '✅ Account created with Google'
                : '✅ បានបង្កើតគណនីតាម Google រួចរាល់')
            : (Localizations.localeOf(context).languageCode == 'en'
                ? '✅ Signed in with Google'
                : '✅ ចូលគណនី Google បានជោគជ័យ'),
      );
      Get.offAllNamed('/home');
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final isEnglish =
          Localizations.localeOf(context).languageCode == 'en';
      final message = e.code == 'account-pending-deletion'
          ? (isEnglish
              ? 'This account is pending deletion. Restore it with your existing sign-in method first.'
              : 'គណនីនេះកំពុងរង់ចាំការលុប។ សូមប្រើវិធីចូលគណនីចាស់ដើម្បីស្ដារវិញសិន។')
          : (e.message ?? e.code);
      _showSnackBar('⚠️ $message', isError: true);
    } catch (e) {
      if (mounted) {
        _showSnackBar(
          Localizations.localeOf(context).languageCode == 'en'
              ? 'Could not continue with Google: $e'
              : 'មិនអាចបន្តជាមួយ Google បាន៖ $e',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _friendlyOtpError(Object error) {
    final isEnglish = Localizations.localeOf(context).languageCode == 'en';
    final raw = error.toString();
    final normalized = raw.toLowerCase();

    if (normalized.contains('api_key_ios_app_blocked') ||
        normalized.contains('requests from this ios client application')) {
      return isEnglish
          ? 'OTP verification is temporarily unavailable. Please try again shortly.'
          : 'ប្រព័ន្ធផ្ទៀងផ្ទាត់ OTP មិនទាន់អាចប្រើបានទេ។ សូមសាកល្បងម្ដងទៀតបន្តិចក្រោយ។';
    }

    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'invalid-phone-number':
          return isEnglish
              ? 'Please enter a valid phone number.'
              : 'សូមបញ្ចូលលេខទូរស័ព្ទឱ្យបានត្រឹមត្រូវ។';
        case 'too-many-requests':
          return isEnglish
              ? 'Too many OTP requests. Please wait and try again.'
              : 'បានស្នើ OTP ច្រើនដងពេក។ សូមរង់ចាំហើយសាកល្បងម្ដងទៀត។';
        case 'quota-exceeded':
          return isEnglish
              ? 'The OTP sending limit has been reached. Please try again later.'
              : 'ដល់កំណត់ផ្ញើ OTP ហើយ។ សូមសាកល្បងម្ដងទៀតពេលក្រោយ។';
      }
      return error.message ?? error.code;
    }

    return isEnglish
        ? 'Could not send OTP. Please try again.'
        : 'មិនអាចផ្ញើ OTP បានទេ។ សូមសាកល្បងម្ដងទៀត។';
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
            _showSnackBar('❌ ${_friendlyOtpError(e)}', isError: true);
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
        _showSnackBar('⚠️ ${_friendlyOtpError(e)}', isError: true);
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
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(child: Divider(color: Colors.grey.shade300)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        Localizations.localeOf(context).languageCode == 'en'
                            ? 'OR'
                            : 'ឬ',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: Colors.grey.shade300)),
                  ],
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : _handleGoogleSignUp,
                    icon: const Text(
                      'G',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF4285F4),
                      ),
                    ),
                    label: Text(
                      Localizations.localeOf(context).languageCode == 'en'
                          ? 'Continue with Google'
                          : 'បន្តជាមួយ Google',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      backgroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
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
