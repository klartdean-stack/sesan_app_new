import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


class WalletLogic extends StatelessWidget {
  final String uid; // ✅ បន្ថែមឱ្យវាចាំទទួល UID ពីក្រៅ
  final Function(double total, double pending, double available) builder;


  const WalletLogic({super.key, required this.uid, required this.builder});


  @override
  Widget build(BuildContext context) {
    // ❌ ឈប់ប្រើ FirebaseAuth ផ្ទាល់ក្នុងនេះ
    // ឆែកការពារ បើ uid ទទេ មិនឱ្យ Stream ដើរទេ
    if (uid.isEmpty) return builder(0, 0, 0);


    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid) // ✅ ប្រើ uid ដែលបាញ់មកពី Profile
          .snapshots(),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData || !userSnapshot.data!.exists)
          return builder(0, 0, 0);


        var userData = userSnapshot.data!.data() as Map<String, dynamic>;


        double total = (userData['balance'] ?? 0).toDouble();
        double pending = (userData['wallet_balance'] ?? 0).toDouble();
        double available = (userData['available_balance'] ?? 0).toDouble();


        return builder(total, pending, available);
      },
    );
  }
}



