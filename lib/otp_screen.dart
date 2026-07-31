import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:my_app/reset_password_screen.dart';

class OTPScreen extends StatefulWidget {
  final String verificationId;
  final String name;
  final String phone;
  final String password;

  const OTPScreen({
    super.key,
    required this.verificationId,
    required this.name,
    required this.phone,
    required this.password,
  });

  @override
  State<OTPScreen> createState() => _OTPScreenState();
}

class _OTPScreenState extends State<OTPScreen> {
  final _otpController = TextEditingController();
  bool _isLoading = false;

  Future<void> _verifyAndLogin() async {
    String otp = _otpController.text.trim();
    if (otp.length < 6) {
      _showSnackBar("⚠️ សូមបញ្ចូលលេខកូដឱ្យគ្រប់ ៦ ខ្ទង់", isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // ១. ផ្ទៀងផ្ទាត់ OTP ជាមួយ Firebase Auth
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: widget.verificationId,
        smsCode: otp,
      );

      // ចូលប្រព័ន្ធដើម្បីយក UID ពិតប្រាកដ
      UserCredential userCredential = await FirebaseAuth.instance
          .signInWithCredential(credential);
      String uid = userCredential.user!.uid;

      // ២. បើមកពីមុខងារ "ភ្លេចលេខសម្ងាត់" (Reset Password Case)
      if (widget.name == "ResetPassword") {
        setState(() => _isLoading = false);
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  ResetPasswordScreen(uid: uid), // បោះ UID ទៅ Update
            ),
          );
        }
        return; // ចប់ការងារត្រឹមនេះសម្រាប់ Reset Password
      }

      // ៣. បើមកពីការចុះឈ្មោះ ឬ Login ធម្មតា (Sign Up / Login Case)
      DocumentReference userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid);
      DocumentSnapshot userDoc = await userRef.get();

      if (!userDoc.exists) {
        await userRef.set({
          'uid': uid,
          'name': widget.name,
          'phone': widget.phone,
          'password': widget.password, // លេខកូដសម្រាប់ដកលុយ
          'balance': 0,
          'wallet_balance': 0,
          'today_earnings': 0,
          'createdAt': FieldValue.serverTimestamp(),
          'lastLogin': FieldValue.serverTimestamp(),
        });
      } else {
        // បើមានអាខោនហើយ គ្រាន់តែ Update ម៉ោងចូលប្រើ
        await userRef.update({'lastLogin': FieldValue.serverTimestamp()});
      }

      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar("❌ លេខកូដ OTP មិនត្រឹមត្រូវ៖ $e", isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 30.0),
        child: Column(
          children: [
            const Icon(Icons.security_rounded, size: 80, color: Colors.green),
            const SizedBox(height: 20),
            const Text(
              "ផ្ទៀងផ្ទាត់លេខកូដ OTP",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: const TextStyle(color: Colors.grey, fontSize: 14),
                children: [
                  const TextSpan(text: "លេខកូដ ៦ ខ្ទង់បានផ្ញើទៅកាន់\n"),
                  TextSpan(
                    text: widget.phone,
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 50), // ប្រអប់វាយ OTP ស្អាតៗ
            TextField(
              controller: _otpController,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: 15,
                color: Colors.green,
              ),
              decoration: InputDecoration(
                hintText: "000000",
                hintStyle: TextStyle(
                  color: Colors.grey[300],
                  letterSpacing: 15,
                ),
                filled: true,
                fillColor: Colors.grey[50],
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: const BorderSide(color: Colors.green, width: 2),
                ),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
            ),

            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _verifyAndLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  elevation: 2,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "ផ្ទៀងផ្ទាត់ និងចូលប្រើ",
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 20),
            TextButton(
              onPressed: _isLoading ? null : () => Navigator.pop(context),
              child: const Text(
                "ប្តូរលេខទូរស័ព្ទ?",
                style: TextStyle(color: Colors.blueGrey),
              ),
            ),
          ],
        ),
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
