import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_instance/src/extension_instance.dart';
import 'package:get/get_navigation/src/extension_navigation.dart';
import 'package:my_app/controllers/auth_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'account_deletion_service.dart';
import 'forgot_password_screen.dart';
import 'user_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _rememberPhone = false;

  @override
  void initState() {
    super.initState();
    _loadSavedPhone();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedPhone() async {
    final prefs = await SharedPreferences.getInstance();
    final remember = prefs.getBool('remember_phone') ?? false;
    if (remember) {
      final phone = prefs.getString('remembered_phone') ?? '';
      if (mounted) {
        setState(() {
          _phoneController.text = phone;
          _rememberPhone = true;
        });
      }
    }
  }

  Future<bool> _handlePendingDeletion(
    QueryDocumentSnapshot<Map<String, dynamic>> userDoc,
    Map<String, dynamic> userData,
  ) async {
    final isDeleted = userData['isDeleted'] == true;
    final status = userData['accountStatus']?.toString() ?? '';
    if (!isDeleted && status != 'pending_deletion') return true;

    final deadlineValue = userData['restoreDeadline'];
    final deadline = deadlineValue is Timestamp ? deadlineValue.toDate() : null;
    final now = DateTime.now();

    if (deadline == null || now.isAfter(deadline)) {
      await AccountDeletionService.markExpired(userDoc.id);
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar(
          'រយៈពេលស្ដារគណនី 15 ថ្ងៃបានផុតកំណត់ហើយ',
          isError: true,
        );
      }
      return false;
    }

    final daysLeft = deadline.difference(now).inDays + 1;
    if (!mounted) return false;

    final shouldRestore = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.restore_rounded, color: Colors.green),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'ស្ដារគណនីវិញ?',
                style: TextStyle(fontFamily: 'Siemreap'),
              ),
            ),
          ],
        ),
        content: Text(
          'គណនីនេះកំពុងរង់ចាំលុប។ អ្នកនៅសល់ប្រហែល $daysLeft ថ្ងៃសម្រាប់ស្ដារគណនី និង Content របស់អ្នកវិញ។\n\nចុច “ស្ដារគណនី” ដើម្បីបន្ត Login។',
          style: const TextStyle(fontFamily: 'Siemreap', height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('មិនទាន់ស្ដារ'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.restore),
            label: const Text('ស្ដារគណនី'),
          ),
        ],
      ),
    );

    if (shouldRestore != true) {
      if (mounted) setState(() => _isLoading = false);
      return false;
    }

    try {
      final restoredCount =
          await AccountDeletionService.restoreOwnedContent(userDoc.id);

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userDoc.id)
          .set({
        'accountStatus': 'active',
        'isDeleted': false,
        'deletedAt': FieldValue.delete(),
        'restoreDeadline': FieldValue.delete(),
        'archivedContentCount': 0,
        'restoredAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        _showSnackBar(
          restoredCount > 0
              ? '✅ បានស្ដារគណនី និង Content $restoredCount មុខរួចរាល់'
              : '✅ បានស្ដារគណនីរួចរាល់',
        );
      }
      return true;
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar('មិនអាចស្ដារគណនីបាន: $e', isError: true);
      }
      return false;
    }
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final rawPhone = _phoneController.text.trim();
    final password = _passwordController.text.trim();

    final prefsBeforeLogin = await SharedPreferences.getInstance();
    final savedLanguage = prefsBeforeLogin.getString('app_language');
    final savedRememberPhone = prefsBeforeLogin.getBool('remember_phone') ?? false;
    final savedPhone = prefsBeforeLogin.getString('remembered_phone');

    await prefsBeforeLogin.clear();
    if (savedLanguage != null) {
      await prefsBeforeLogin.setString('app_language', savedLanguage);
    }
    if (savedRememberPhone && savedPhone != null && savedPhone.isNotEmpty) {
      await prefsBeforeLogin.setBool('remember_phone', true);
      await prefsBeforeLogin.setString('remembered_phone', savedPhone);
    }
    UserService.clearCache();

    setState(() => _isLoading = true);

    final phoneWith855 = rawPhone.startsWith('+855')
        ? rawPhone
        : rawPhone.startsWith('0')
            ? '+855${rawPhone.substring(1)}'
            : '+855$rawPhone';

    final phoneWithZero = rawPhone.startsWith('+855')
        ? '0${rawPhone.substring(4)}'
        : rawPhone.startsWith('0')
            ? rawPhone
            : '0$rawPhone';

    try {
      final query = await FirebaseFirestore.instance
          .collection('users')
          .where('phone', whereIn: [phoneWith855, phoneWithZero])
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        if (mounted) {
          setState(() => _isLoading = false);
          _showSnackBar('❌ រកមិនឃើញគណនីនេះទេ', isError: true);
        }
        return;
      }

      final userDoc = query.docs.first;
      var userData = userDoc.data();
      final dbPassword = (userData['password'] ?? '').toString().trim();

      if (dbPassword != password) {
        if (mounted) {
          setState(() => _isLoading = false);
          _showSnackBar('🔑 លេខសម្ងាត់មិនត្រឹមត្រូវទេ', isError: true);
        }
        return;
      }

      final canContinue = await _handlePendingDeletion(userDoc, userData);
      if (!canContinue) return;

      final refreshedDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userDoc.id)
          .get();
      userData = refreshedDoc.data() ?? userData;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userDoc.id)
          .update({'lastLogin': FieldValue.serverTimestamp()});

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_uid', userDoc.id);
      await prefs.setString('user_name', userData['name'] ?? '');
      await prefs.setString('user_phone', userData['phone'] ?? '');
      await prefs.setString('user_photo', userData['photoUrl'] ?? '');
      await prefs.setString('user_role', userData['role'] ?? 'seller');
      await prefs.setBool('is_logged_in', true);

      if (_rememberPhone) {
        await prefs.setString('remembered_phone', rawPhone);
        await prefs.setBool('remember_phone', true);
      } else {
        await prefs.remove('remembered_phone');
        await prefs.setBool('remember_phone', false);
      }

      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar('✅ ចូលប្រើប្រាស់ជោគជ័យ');
        await Get.find<AuthController>().loginWithUid(userDoc.id);
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) Get.offAllNamed('/home');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar('⚠️ កំហុស: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 15,
                          spreadRadius: 2,
                        ),
                      ],
                      image: const DecorationImage(
                        image: AssetImage('assets/sesan_icon.jpg'),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('SESAN APP', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.green, letterSpacing: 2)),
                  const SizedBox(height: 8),
                  Text('ចូលប្រើប្រាស់គណនីរបស់អ្នក', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                  const SizedBox(height: 40),
                  _buildTextField(controller: _phoneController, label: 'លេខទូរសព្ទ', hint: 'ឧទាហរណ៍ 088XXXXXXX', icon: Icons.phone_android, isNumber: true, validator: (v) {
                    if (v == null || v.isEmpty) return 'សូមបញ្ចូលលេខទូរសព្ទ';
                    if (!RegExp(r'^(0|\+855)[0-9]{8,9}$').hasMatch(v)) return 'លេខទូរសព្ទមិនត្រឹមត្រូវ';
                    return null;
                  }),
                  const SizedBox(height: 16),
                  _buildTextField(controller: _passwordController, label: 'លេខសម្ងាត់', hint: 'បញ្ចូលលេខសម្ងាត់របស់អ្នក', icon: Icons.lock_outline, isPassword: true, validator: (v) {
                    if (v == null || v.isEmpty) return 'សូមបញ្ចូលលេខសម្ងាត់';
                    if (v.length < 6) return 'លេខសម្ងាត់ត្រូវមានយ៉ាងតិច 6 ខ្ទង់';
                    return null;
                  }),
                  const SizedBox(height: 8),
                  Row(children: [
                    Checkbox(value: _rememberPhone, onChanged: (v) => setState(() => _rememberPhone = v ?? false), activeColor: Colors.green),
                    const Text('ចង់ចាំលេខទូរសព្ទ', style: TextStyle(fontSize: 13)),
                    const Spacer(),
                    TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())), child: Text('ភ្លេចលេខសម្ងាត់?', style: TextStyle(color: Colors.green[700], fontSize: 13))),
                  ]),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleLogin,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                      child: _isLoading
                          ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                          : const Text('ចូលប្រើប្រាស់', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    bool isNumber = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword && !_isPasswordVisible,
      keyboardType: isNumber ? TextInputType.phone : TextInputType.text,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: Colors.green),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
              )
            : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Colors.green, width: 2)),
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
