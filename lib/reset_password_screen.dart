import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String uid; // ទទួលលេខទូរស័ព្ទដែលមានសញ្ញា "+" ពី OTPScreen
  const ResetPasswordScreen({super.key, required this.uid});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _passController = TextEditingController();
  final _confirmPassController = TextEditingController();
  bool _isLoading = false;

  Future<void> _handleReset() async {
    String pass = _passController.text.trim();
    String confirmPass = _confirmPassController.text.trim();

    // ១. ឆែកលក្ខខណ្ឌបញ្ចូលទិន្នន័យ
    if (pass.length != 6 || confirmPass.length != 6) {
      _showMsg("សូមបញ្ចូលលេខសម្ងាត់ឱ្យគ្រប់ ៦ ខ្ទង់");
      return;
    }

    if (pass != confirmPass) {
      _showMsg("លេខសម្ងាត់ទាំង ២ មិនដូចគ្នាទេ!");
      return;
    }

    setState(() => _isLoading = true);

    try {
      // ដូរពី .doc(widget.phone) មកជា .doc(widget.uid) វិញ
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid) // ប្រើ UID ដែលបានមកពី Firebase Auth
          .update({
            'password': pass, // វានឹងទៅដូរលេខ "202666" របស់មិត្តភក្កិមេ ចេញ
            'updated_at': FieldValue.serverTimestamp(),
          });

      _showMsg("ប្ដូរលេខសម្ងាត់ជោគជ័យ!", isSuccess: true);

      // ៣. រុញទៅកាន់ទំព័រដើមវិញ
      if (mounted) {
        Future.delayed(const Duration(seconds: 2), () {
          Navigator.popUntil(context, (route) => route.isFirst);
        });
      }
    } catch (e) {
      _showMsg("មានបញ្ហាក្នុងការរក្សាទុក៖ $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showMsg(String msg, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isSuccess ? Colors.green : Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("កំណត់លេខសម្ងាត់ថ្មី"),
        backgroundColor: const Color(0xFF4CAF50), // ពណ៌បៃតងដូច App Sesan
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "សូមកំណត់លេខសម្ងាត់ ៦ ខ្ទង់ថ្មីសម្រាប់ដកប្រាក់៖",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // ប្រឡោះវាយ Password ទី ១
            TextField(
              controller: _passController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "លេខសម្ងាត់ថ្មី",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
            const SizedBox(height: 10),

            // ប្រឡោះវាយ Password បញ្ជាក់
            TextField(
              controller: _confirmPassController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "បញ្ជាក់លេខសម្ងាត់ថ្មី",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock_reset),
              ),
            ),
            const SizedBox(height: 30),

            // ប៊ូតុងរក្សាទុក
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleReset,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "រក្សាទុកលេខសម្ងាត់ថ្មី",
                        style: TextStyle(fontSize: 18, color: Colors.white),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
