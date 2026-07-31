import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'edit_profile_screen.dart';


class SellerWithdrawScreen extends StatefulWidget {
  const SellerWithdrawScreen({super.key});


  @override
  State<SellerWithdrawScreen> createState() => _SellerWithdrawScreenState();
}


class _SellerWithdrawScreenState extends State<SellerWithdrawScreen> {
  final TextEditingController _amountController = TextEditingController();
  final currencyFormat = NumberFormat('#,###');


  String? userId;
  bool _isLoading = false;
  double _canWithdraw = 0;


  @override
  void initState() {
    super.initState();
    _loadUserId();
  }


  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }


  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userId = prefs.getString('user_uid');
    });
  }


  void _showWithdrawDialog() {
    final pinController = TextEditingController();
    bool isSubmitting = false;

    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => StreamBuilder<DocumentSnapshot>(
          // ១. ទាញទិន្នន័យពី Profile មកប្រើផ្ទាល់តែម្តង
            stream: FirebaseFirestore.instance.collection('users').doc(userId).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

              var userData = snapshot.data!.data() as Map<String, dynamic>;

              // 🛡️ ឆែកមើលថា តើគាត់បានបំពេញព័ត៌មានធនាគារក្នុង Profile ហើយឬនៅ?
              if (userData['bank_account_number'] == null || userData['password'] == null) {
                return AlertDialog(
                  title: const Text("ព័ត៌មានមិនទាន់គ្រប់គ្រាន់", style: TextStyle(fontFamily: 'KHMEROS')),
                  content: const Text("សូមបំពេញព័ត៌មានធនាគារ និងលេខសម្ងាត់ ៦ ខ្ទង់ ជាមុនសិន ទើបអាចដកប្រាក់បាន។"),
                  actions: [
                    // ប៊ូតុងបោះបង់
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("បោះបង់", style: TextStyle(color: Colors.grey)),
                    ),
                    // ប៊ូតុងដែលនឹងនាំទៅកាន់ទំព័រ Profile ផ្ទាល់តែម្តង
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      onPressed: () {
                        // ១. បិទ Dialog សិន
                        Navigator.pop(context);

                        // ២. រុញទៅកាន់អេក្រង់ EditProfileScreen ភ្លាមៗ
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const EditProfileScreen(),
                          ),
                        );
                      },
                      child: const Text("ទៅបំពេញព័ត៌មាន", style: TextStyle(color: Colors.white)),
                    ),
                  ],
                );
              }

              return StatefulBuilder(
                  builder: (context, setDialogState) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      title: const Text("បញ្ជាក់ការដកប្រាក់", style: TextStyle(fontFamily: 'Siemreap', fontWeight: FontWeight.bold)),
                      content: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // បង្ហាញធនាគារដែលគាត់ setup ទុក (មើលបាន តែអ៊ែឌីតអត់បាន)
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(10)),
                              child: ListTile(
                                leading: const Icon(Icons.account_balance, color: Colors.green),
                                title: Text(userData['bank_name'] ?? "ABA"),
                                subtitle: Text(userData['bank_account_number'] ?? ""),
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Text("បញ្ចូលលេខសម្ងាត់ ៦ ខ្ទង់"),
                            const SizedBox(height: 10),
                            TextField(
                              controller: pinController,
                              decoration: const InputDecoration(
                                hintText: "• • • • • •",
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(vertical: 10),
                              ),
                              obscureText: true,
                              textAlign: TextAlign.center,
                              keyboardType: TextInputType.number,
                              maxLength: 6,
                            ),
                          ],
                        ),
                      ),
                      actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text("បោះបង់")),
              ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: isSubmitting ? null : () async {
              String inputPin = pinController.text.trim();
              String savedPin = userData['password'].toString();

              if (inputPin == savedPin) {
              setDialogState(() => isSubmitting = true);

              try {
              // ២. បញ្ជូន Request ទៅ Admin ដោយយកទិន្នន័យពី Profile ទាំងអស់
              await FirebaseFirestore.instance.collection('withdraw_requests').add({
              'seller_id': userId,
              'bank_name': userData['bank_name'],
                'account_name': userData['full_name_kh'],
                'account_number': userData['bank_account_number'],
                'amount': double.tryParse(_amountController.text) ?? 0.0,
                'khqr_url': userData['bank_qr_url'], // យករូប QR ពី Profile
                'status': 'pending',
                'created_at': FieldValue.serverTimestamp(),
              });

              Navigator.pop(context);
              _amountController.clear();
              _showSnackBar("✅ សំណើដកប្រាក់ត្រូវបានបញ្ជូន!");
              } catch (e) {
                _showSnackBar("❌ កំហុសបច្ចេកទេស៖ $e", isError: true);
              }
              } else {
                _showSnackBar("❌ លេខសម្ងាត់មិនត្រឹមត្រូវ!", isError: true);
              }
              },
                child: isSubmitting ? const CircularProgressIndicator(color: Colors.white) : const Text("យល់ព្រម"),
              ),
                      ],
                  ),
              );
            },
        ),
    );
  }


  void _showSnackBar(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontFamily: 'Siemreap')),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    if (userId == null)
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.green)),
      );


    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "ដកប្រាក់ចំណូល",
          style: TextStyle(fontFamily: 'Siemreap'),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || !snapshot.data!.exists)
            return const Center(child: Text("រកមិនឃើញគណនី"));


          var data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
          _canWithdraw = (data['available_balance'] ?? 0)
              .toDouble(); // ប្រើ available_balance ឱ្យត្រូវតាម Cloud Functions


          return SingleChildScrollView(
            padding: const EdgeInsets.all(25),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // កាតបង្ហាញសមតុល្យ
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(30),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Colors.green, Color(0xFF1B5E20)],
                    ),
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Text(
                        "សមតុល្យដែលអាចដកបាន",
                        style: TextStyle(
                          color: Colors.white70,
                          fontFamily: 'Siemreap',
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "${currencyFormat.format(_canWithdraw)} ៛",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                const Text(
                  "ចំនួនទឹកប្រាក់ដែលចង់ដក",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Siemreap',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: "0 ៛",
                    prefixIcon: const Icon(
                      Icons.account_balance_wallet,
                      color: Colors.green,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: const BorderSide(
                        color: Colors.green,
                        width: 2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [50000, 100000, 200000, 500000].map((amount) {
                    return OutlinedButton(
                      onPressed: () =>
                      _amountController.text = amount.toString(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.green,
                        side: const BorderSide(color: Colors.green),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: Text(
                        '${currencyFormat.format(amount)} ៛',
                        style: const TextStyle(fontFamily: 'Siemreap'),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 50),
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: () {
                      double amount =
                          double.tryParse(_amountController.text) ?? 0;
                      if (amount < 5000) {
                        // កំណត់ឱ្យដកយ៉ាងតិច ៥ពាន់
                        _showSnackBar(
                          "⚠️ ចំនួនដកត្រូវតែចាប់ពី ៥,០០០៛ ឡើងទៅ",
                          isError: true,
                        );
                        return;
                      }
                      if (amount > _canWithdraw) {
                        _showSnackBar(
                          "⚠️ លុយក្នុងកាបូបមិនគ្រប់គ្រាន់ទេ!",
                          isError: true,
                        );
                        return;
                      }
                      _showWithdrawDialog();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      "បញ្ជាក់ការដកប្រាក់",
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.white,
                        fontFamily: 'Siemreap',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}



