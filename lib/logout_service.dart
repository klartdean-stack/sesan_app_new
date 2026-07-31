import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:my_app/login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'user_service.dart'; // បើមាន


/// 🔥 Service សម្រាប់ Logout - ប្រើគ្រប់ទីកន្លែងក្នុង App
class LogoutService {
  /// ✅ Logout ពិតប្រាកដ - លុបទាំងអស់
  static Future<void> performLogout(BuildContext context) async {
    // ១. Logout Firebase
    try {
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      debugPrint("Firebase logout error: $e");
    }


    // ២. លុប SharedPreferences ទាំងអស់
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();


    // ៣. សម្អាត cache (បើមាន UserService)
    UserService.clearCache();


    // ៤. បញ្ជូនទៅ Login Screen
    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false, // លុប stack ទាំងអស់
      );
    }
  }


  /// ⚠️ បង្ហាញ Dialog បញ្ជាក់មុន logout
  static void showLogoutConfirm(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.logout, color: Colors.red),
            SizedBox(width: 10),
            Text(
              "ចាកចេញ",
              style: TextStyle(
                fontFamily: 'Siemreap',
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: const Text(
          "តើអ្នកប្រាកដជាចង់ចាកចេញពីគណនីនេះមែនទេ?",
          style: TextStyle(fontFamily: 'Siemreap'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "បោះបង់",
              style: TextStyle(fontFamily: 'Siemreap'),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // បិទ dialog
              performLogout(context); // ធ្វើ logout
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              "ចាកចេញ",
              style: TextStyle(fontFamily: 'Siemreap'),
            ),
          ),
        ],
      ),
    );
  }
}



