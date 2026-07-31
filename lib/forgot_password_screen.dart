import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _obscurePass = true;
  bool _obscureConfirm = true;
  String? _verificationId;
  bool _codeSent = false;
  bool _passwordReset = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  // ── ពណ៌ ──────────────────────────────────────
  static const Color bgColor = Color(0xFF0A0E21);
  static const Color cardColor = Color(0xFF1A1F3D);
  static const Color accentColor = Color(0xFF3B5BFF);
  static const Color greenColor = Color(0xFF00C48C);

  Future<void> _sendOtp() async {
    if (!_formKey.currentState!.validate()) return;
    final phone = _phoneController.text.trim();
    String phoneWith855 = phone.startsWith('+855')
        ? phone
        : phone.startsWith('0')
        ? '+855${phone.substring(1)}'
        : '+855$phone';

    final query = await FirebaseFirestore.instance
        .collection('users')
        .where('phone', whereIn: [
      phoneWith855,
      phone.startsWith('+855') ? '0${phone.substring(4)}' : phone
    ])
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      _showSnack('មិនមានគណនីចុះឈ្មោះជាមួយលេខនេះទេ', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phoneWith855,
        timeout: const Duration(seconds: 60),

        verificationCompleted: (PhoneAuthCredential credential) async {
          if (credential.smsCode != null) {
            setState(() {
              _codeController.text = credential.smsCode!;
              _isLoading = false;
            });
          }
        },

        verificationFailed: (FirebaseAuthException e) {
          _showSnack('បរាជ័យ៖ ${e.message}', isError: true);
          setState(() => _isLoading = false);
        },

        codeSent: (String verificationId, int? resendToken) {
          setState(() {
            _verificationId = verificationId;
            _codeSent = true;
            _isLoading = false;
          });
          _showSnack('បានផ្ញើ OTP ជោគជ័យ!', isError: false);
        },

        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnack('មានបញ្ហា៖ $e', isError: true);
    }
  }

  Future<void> _verifyAndReset() async {
    final code = _codeController.text.trim();
    final password = _passwordController.text.trim();
    final confirm = _confirmController.text.trim();

    if (code.isEmpty || password.isEmpty) {
      _showSnack('សូមបំពេញគ្រប់ចន្លោះ', isError: true);
      return;
    }
    if (password.length < 6) {
      _showSnack('លេខសម្ងាត់ត្រូវមានយ៉ាងតិច ៦ តួ', isError: true);
      return;
    }
    if (password != confirm) {
      _showSnack('លេខសម្ងាត់មិនត្រូវគ្នា', isError: true);
      return;
    }
    final credential = PhoneAuthProvider.credential(
      verificationId: _verificationId!,
      smsCode: code,
    );
    await _verifyCodeAndReset(credential);
  }Future<void> _verifyCodeAndReset(PhoneAuthCredential credential) async {
    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.signInWithCredential(credential);
      final phone = _phoneController.text.trim();
      String phoneWith855 = phone.startsWith('+855')
          ? phone
          : phone.startsWith('0')
          ? '+855${phone.substring(1)}'
          : '+855$phone';
      final query = await FirebaseFirestore.instance
          .collection('users')
          .where('phone', whereIn: [
        phoneWith855,
        phone.startsWith('+855') ? '0${phone.substring(4)}' : phone,
      ])
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        _showSnack('រកមិនឃើញគណនី', isError: true);
        setState(() => _isLoading = false);
        return;
      }

      await query.docs.first.reference.update({
        'password': _passwordController.text.trim(),
      });

      setState(() {
        _isLoading = false;
        _passwordReset = true;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnack('កូដមិនត្រឹមត្រូវ ឬផុតកំណត់', isError: true);
    }
  }

  void _showSnack(String msg, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        backgroundColor: isError ? const Color(0xFFDA3633) : const Color(0xFF238636),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('ភ្លេចលេខសម្ងាត់',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Siemreap', fontSize: 17)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Form(
          key: _formKey,
          child: _passwordReset
              ? _buildSuccessView()
              : _codeSent
              ? _buildCodeVerification()
              : _buildPhoneInput(),
        ),
      ),
    );
  }

  Widget _buildPhoneInput() {
    return Column(
        children: [
        const SizedBox(height: 40),
    Container(
    width: 90, height: 90,
    decoration: BoxDecoration(
    shape: BoxShape.circle,
    color: accentColor.withOpacity(0.12),
    border: Border.all(color: accentColor.withOpacity(0.35), width: 2),
    ),
    child: const Icon(Icons.lock_reset, color: accentColor, size: 42),
    ),
    const SizedBox(height: 24),
    const Text('កំណត់លេខសម្ងាត់ឡើងវិញ',
    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Siemreap')),
    const SizedBox(height: 8),
    Text('បញ្ចូលលេខទូរស័ព្ទដែលបានចុះឈ្មោះ\nប្រព័ន្ធនឹងផ្ញើ OTP ទៅលេខរបស់អ្នក',
    textAlign: TextAlign.center,
    style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13, height: 1.6, fontFamily: 'Siemreap')),
    const SizedBox(height: 36),
    _buildStepRow(step: 1),
    const SizedBox(height: 32),
    _buildLabel('លេខទូរស័ព្ទ'),
    const SizedBox(height: 8),
    TextFormField(
    controller: _phoneController,
    keyboardType: TextInputType.phone,style: const TextStyle(color: Colors.white, fontSize: 15),
      decoration: _inputDeco('ឧ. 012 345 678', Icons.phone_android_outlined),
      validator: (v) => v!.isEmpty ? 'សូមបញ្ចូលលេខទូរស័ព្ទ' : null,
    ),
          const SizedBox(height: 28),
          _buildMainButton(label: 'ផ្ញើ OTP', icon: Icons.send_rounded, onTap: _sendOtp),
          const SizedBox(height: 40),
        ],
    );
  }

  Widget _buildCodeVerification() {
    return Column(
        children: [
        const SizedBox(height: 40),
    Container(
    width: 90, height: 90,
    decoration: BoxDecoration(
    shape: BoxShape.circle,
    color: greenColor.withOpacity(0.12),
    border: Border.all(color: greenColor.withOpacity(0.35), width: 2),
    ),
    child: const Icon(Icons.mark_email_read_outlined, color: greenColor, size: 42),
    ),
    const SizedBox(height: 24),
    const Text('ផ្ទៀងផ្ទាត់ OTP',
    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Siemreap')),
    const SizedBox(height: 8),
    Text('លេខកូដ ៦ ខ្ទង់ត្រូវបានផ្ញើទៅ\n${_phoneController.text.trim()}',
    textAlign: TextAlign.center,
    style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13, height: 1.6, fontFamily: 'Siemreap')),
    const SizedBox(height: 36),
    _buildStepRow(step: 2),
    const SizedBox(height: 32),
    _buildLabel('លេខកូដ OTP'),
    const SizedBox(height: 8),
    TextFormField(
    controller: _codeController,
    keyboardType: TextInputType.number,
    maxLength: 6,
    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 8),
    textAlign: TextAlign.center,
    decoration: _inputDeco('_ _ _ _ _ _', Icons.pin_outlined).copyWith(counterText: ''),
    ),
    const SizedBox(height: 20),
    _buildLabel('លេខសម្ងាត់ថ្មី'),
    const SizedBox(height: 8),
    TextFormField(
    controller: _passwordController,
    obscureText: _obscurePass,
    style: const TextStyle(color: Colors.white, fontSize: 15),
    decoration: _inputDeco('យ៉ាងតិច ៦ តួ', Icons.lock_outline).copyWith(
    suffixIcon: IconButton(
    icon: Icon(_obscurePass ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Colors.white38, size: 20),
    onPressed: () => setState(() => _obscurePass = !_obscurePass),
    ),
    ),
    validator: (v) => (v == null || v.length < 6) ? 'យ៉ាងតិច ៦ តួ' : null,
    ),
    const SizedBox(height: 16),
    _buildLabel('បញ្ជាក់លេខសម្ងាត់'),
    const SizedBox(height: 8),
    TextFormField(
    controller: _confirmController,
    obscureText: _obscureConfirm,
    style: const TextStyle(color: Colors.white, fontSize: 15),
    decoration: _inputDeco('វាយម្ដងទៀត', Icons.lock_outline).copyWith(
    suffixIcon: IconButton(
    icon: Icon(_obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Colors.white38, size: 20),
    onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
    ),
    ),
    ),
    const SizedBox(height: 28),
    Row(
    children: [
    Expanded(
    child: OutlinedButton.icon(
    style: OutlinedButton.styleFrom(
    side: BorderSide(color: Colors.white.withOpacity(0.2)),
    padding: const EdgeInsets.symmetric(vertical: 14),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    onPressed: () => setState(() { _codeSent = false; _verificationId = null; }),icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white54, size: 15),
      label: const Text('ថយក្រោយ', style: TextStyle(color: Colors.white60, fontFamily: 'Siemreap')),
    ),
    ),
      const SizedBox(width: 14),
      Expanded(
        flex: 2,
        child: _buildMainButton(label: 'ប្ដូរលេខសម្ងាត់', icon: Icons.check_rounded, onTap: _verifyAndReset, color: greenColor),
      ),
    ],
    ),
          const SizedBox(height: 40),
        ],
    );
  }

  Widget _buildSuccessView() {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.8,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 110, height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: greenColor.withOpacity(0.12),
              border: Border.all(color: greenColor.withOpacity(0.4), width: 3),
              boxShadow: [BoxShadow(color: greenColor.withOpacity(0.25), blurRadius: 30, spreadRadius: -5)],
            ),
            child: const Icon(Icons.check_rounded, color: greenColor, size: 56),
          ),
          const SizedBox(height: 28),
          const Text('ជោគជ័យ!', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold, fontFamily: 'Siemreap')),
          const SizedBox(height: 10),
          Text('លេខសម្ងាត់ត្រូវបានប្ដូរជោគជ័យ\nអ្នកអាចចូលប្រើប្រាស់ App បានហើយ',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14, height: 1.6, fontFamily: 'Siemreap')),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            child: _buildMainButton(label: 'ត្រឡប់ទៅចូលប្រើ', icon: Icons.login_rounded, onTap: () => Navigator.pop(context), color: accentColor),
          ),
        ],
      ),
    );
  }

  Widget _buildStepRow({required int step}) {
    final steps = ['លេខទូរស័ព្ទ', 'OTP', 'ជោគជ័យ'];
    return Row(
      children: List.generate(steps.length * 2 - 1, (i) {
        if (i.isOdd) {
          final lineStep = i ~/ 2;
          return Expanded(
            child: Container(
              height: 2,
              decoration: BoxDecoration(
                gradient: lineStep < step - 1 ? LinearGradient(colors: [accentColor, accentColor.withOpacity(0.3)]) : null,
                color: lineStep < step - 1 ? null : Colors.white.withOpacity(0.1),
              ),
            ),
          );
        }
        final dotStep = i ~/ 2 + 1;
        final isActive = dotStep <= step;
        final isCurrent = dotStep == step;
        return Column(
          children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive ? accentColor : Colors.white.withOpacity(0.08),
                border: isCurrent ? Border.all(color: Colors.white, width: 2) : null,
                boxShadow: isActive ? [BoxShadow(color: accentColor.withOpacity(0.4), blurRadius: 10, spreadRadius: -2)] : null,
              ),
              child: Center(
                child: isActive && !isCurrent
                    ? const Icon(Icons.check, color: Colors.white, size: 16)
                    : Text('$dotStep', style: TextStyle(color: isActive ? Colors.white : Colors.white30, fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ),
            const SizedBox(height: 6),
            Text(steps[dotStep - 1], style: TextStyle(color: isActive ? Colors.white70 : Colors.white24, fontSize: 10, fontFamily: 'Siemreap')),
          ],
        );
      }),
    );
  }

  Widget _buildLabel(String text) {
    return Text(text, style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 13, fontFamily: 'Siemreap', fontWeight: FontWeight.w500));
  }InputDecoration _inputDeco(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 13),
      prefixIcon: Icon(icon, color: Colors.white.withOpacity(0.35), size: 20),
      filled: true,
      fillColor: Colors.white.withOpacity(0.05),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: accentColor, width: 1.5)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.redAccent)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
    );
  }

  Widget _buildMainButton({required String label, required IconData icon, required VoidCallback onTap, Color color = accentColor}) {
    return SizedBox(
      width: double.infinity, height: 52,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 4,
          shadowColor: color.withOpacity(0.4),
        ),
        onPressed: _isLoading ? null : onTap,
        icon: _isLoading
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Icon(icon, size: 18),
        label: _isLoading
            ? const Text('កំពុងដំណើរការ...', style: TextStyle(fontFamily: 'Siemreap', fontWeight: FontWeight.bold))
            : Text(label, style: const TextStyle(fontFamily: 'Siemreap', fontWeight: FontWeight.bold, fontSize: 15)),
      ),
    );
  }
}