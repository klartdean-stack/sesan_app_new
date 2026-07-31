import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_instance/src/extension_instance.dart';
import 'package:get/get_navigation/src/extension_navigation.dart';
import 'package:my_app/controllers/auth_controller.dart';
import 'package:my_app/home_screen.dart';
import 'package:my_app/product_list.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'forgot_password_screen.dart';
import 'user_service.dart' hide UserService;


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


  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;


    final rawPhone = _phoneController.text.trim();
    final password = _passwordController.text.trim();


    // ✅ លុប SharedPreferences ចាស់មុន login ថ្មី!
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    UserService.clearCache(); // សម្អាត cache ផង


    setState(() => _isLoading = true);
    // ... កូដដដែល ...


    // ✅ បង្កើតទម្រង់លេខ ២ formats
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
      // ✅ ស្វែងរក user ក្នុង Firestore
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
      final userData = userDoc.data();
      final dbPassword = (userData['password'] ?? '').toString().trim();


      if (dbPassword != password) {
        if (mounted) {
          setState(() => _isLoading = false);
          _showSnackBar('🔑 លេខសម្ងាត់មិនត្រឹមត្រូវទេ', isError: true);
        }
        return;
      }
      // ✅ ១. Update lastLogin ទៅ Firebase (ថែមត្រង់នេះ)
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userDoc.id)
          .update({'lastLogin': FieldValue.serverTimestamp()});
      // ✅ Save ព័ត៌មាន user ក្នុង SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_uid', userDoc.id);
      await prefs.setString('user_name', userData['name'] ?? '');
      await prefs.setString('user_phone', userData['phone'] ?? '');
      await prefs.setString('user_photo', userData['photoUrl'] ?? '');
      await prefs.setString('user_role', userData['role'] ?? 'seller');
      await prefs.setBool('is_logged_in', true);


      // ✅ Save phone ប្រសិនបើ remember
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


        // 🎯 ថែមជួរនេះ៖ ដាស់ AuthController ឱ្យដឹងថាមាន User បាន Login ហើយ
        await Get.find<AuthController>().loginWithUid(userDoc.id);


        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          // 🎯 កែមកប្រើ Get.offAllNamed ជំនួស Navigator ដើម្បីឱ្យ Obx ក្នុង main.dart ដំណើរការស្របគ្នា
          Get.offAllNamed('/home');
        }
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


                  // ── Logo ──────────────────────────────────
                  // 🎯 ស្វែងរកកន្លែងបង្ហាញ Icon រូបកាបូប ហើយជំនួសដោយកូដនេះ
                  Container(
                    width: 130, // ទំហំមេអាចសារ៉េតាមចិត្ត
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
                      // 🎯 ប្រើ AssetImage ដើម្បីទាញយក sesan_icon.jpg
                      image: const DecorationImage(
                        image: AssetImage('assets/sesan_icon.jpg'),
                        fit: BoxFit.cover, // ឱ្យរូបភាពពេញរង្វង់ស្អាត
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'SESAN APP',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'ចូលប្រើប្រាស់គណនីរបស់អ្នក',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 40),


                  // ── លេខទូរសព្ទ ───────────────────────────
                  _buildTextField(
                    controller: _phoneController,
                    label: 'លេខទូរសព្ទ',
                    hint: 'ឧទាហរណ៍ 088XXXXXXX',
                    icon: Icons.phone_android,
                    isNumber: true,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'សូមបញ្ចូលលេខទូរសព្ទ';
                      if (!RegExp(r'^(0|\+855)[0-9]{8,9}$').hasMatch(v)) {
                        return 'លេខទូរសព្ទមិនត្រឹមត្រូវ';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),


                  // ── លេខសម្ងាត់ ────────────────────────────
                  _buildTextField(
                    controller: _passwordController,
                    label: 'លេខសម្ងាត់',
                    hint: 'បញ្ចូលលេខសម្ងាត់របស់អ្នក',
                    icon: Icons.lock_outline,
                    isPassword: true,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'សូមបញ្ចូលលេខសម្ងាត់';
                      if (v.length < 6)
                        return 'លេខសម្ងាត់ត្រូវមានយ៉ាងតិច 6 ខ្ទង់';
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),


                  // ── Remember + Forgot ─────────────────────
                  Row(
                    children: [
                      Checkbox(
                        value: _rememberPhone,
                        onChanged: (v) =>
                            setState(() => _rememberPhone = v ?? false),
                        activeColor: Colors.green,
                      ),
                      const Text(
                        'ចង់ចាំលេខទូរសព្ទ',
                        style: TextStyle(fontSize: 13),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
                        ),
                        child: Text(
                          'ភ្លេចលេខសម្ងាត់?',
                          style: TextStyle(
                            color: Colors.green[700],
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),


                  // ── ប៊ូតុងចូល ─────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                          : const Text(
                        'ចូលប្រើប្រាស់',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),


                  // ── ចុះឈ្មោះ ──────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'មិនទាន់មានគណនី? ',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pushNamed(context, '/signup'),
                        child: const Text(
                          'ចុះឈ្មោះនៅទីនេះ',
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // ── ប៊ូតុងចូលមើលសិន ─────────────────────────
                  // ── ប៊ូតុងចូលមើលសិន ─────────────────────────
                  OutlinedButton.icon(
                    onPressed: () async {
                      await Get.find<AuthController>().loginAsGuest();
                      // 🎯 កែត្រង់នេះ៖ បញ្ជូន guestMode: true ទៅឱ្យ HomeScreen ផងដើម្បីកុំឱ្យវាច្រឡំ
                      Get.offAllNamed('/home-guest'); // Guest mode
                    },
                    icon: const Icon(Icons.person_outline, color: Colors.green),
                    label: const Text(
                      'ចូលមើលសិន',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 14,
                      ),
                      side: const BorderSide(color: Colors.green, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30), // រាងមូល
                      ),
                      backgroundColor: Colors.green.shade50.withOpacity(
                        0.3,
                      ), // ពណ៌ផ្ទៃថ្លាបៃតងខ្ចី
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
    bool isNumber = false,
    bool isPassword = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword ? !_isPasswordVisible : false,
      keyboardType: isNumber ? TextInputType.phone : TextInputType.text,
      validator: validator,
      style: const TextStyle(fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: Colors.green),
        suffixIcon: isPassword
            ? IconButton(
          icon: Icon(
            _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
            color: Colors.grey[600],
          ),
          onPressed: () =>
              setState(() => _isPasswordVisible = !_isPasswordVisible),
        )
            : null,
        filled: true,
        fillColor: Colors.grey[50],
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
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
          borderSide: const BorderSide(color: Colors.red, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
      ),
    );
  }


  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? Colors.redAccent : Colors.green[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}



