import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationService {
  // Function សម្រាប់ Update Token ទៅ Firestore
  static Future<void> updateSellerToken() async {
    try {
      // ១. យកលេខ Token របស់ទូរស័ព្ទ
      String? token = await FirebaseMessaging.instance.getToken();

      // ២. យក ID របស់ Seller ដែលកំពុងប្រើ App
      String? uid = FirebaseAuth.instance.currentUser?.uid;

      if (token != null && uid != null) {
        // ៣. រក្សាទុកក្នុង Collection 'sellers' (ប្រើម្ដងហើយម្ដងទៀតវានឹងជាន់លើអាចាស់)
        await FirebaseFirestore.instance.collection('users').doc(uid).set(
          {'fcmToken': token, 'lastUpdate': FieldValue.serverTimestamp()},
          SetOptions(merge: true),
        ); // merge: true គឺដើម្បីកុំឱ្យវាលុបទិន្នន័យចាស់ៗចោល

        print("🎯 បច្ចុប្បន្នភាព Token រួចរាល់៖ $token");
      }
    } catch (e) {
      print("❌ បញ្ហាពេល Update Token: $e");
    }
  }
}
