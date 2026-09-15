import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Shared Android V51 parity helpers for SellerProfileScreen.
class SellerProfileV51Support {
  SellerProfileV51Support({required this.sellerId});

  final String sellerId;
  Timer? _phoneHideTimer;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _cartSubscription;

  final ValueNotifier<bool> showPhone = ValueNotifier<bool>(false);
  final ValueNotifier<int> cartRevision = ValueNotifier<int>(0);
  final Set<String> cartProductIds = <String>{};
  final Set<String> cartBusyIds = <String>{};

  String maskPhone(String phone) {
    final value = phone.trim().replaceAll(RegExp(r'\s+'), '');
    if (value.isEmpty) return '';
    if (value.length <= 3) return 'XXX';
    return '${value.substring(0, value.length - 3)}XXX';
  }

  Future<void> revealPhone({String? buyerId}) async {
    _phoneHideTimer?.cancel();
    showPhone.value = true;
    try {
      await FirebaseFirestore.instance.collection('marketplace_events').add({
        'type': 'phone_reveal',
        'buyerId': buyerId ?? FirebaseAuth.instance.currentUser?.uid ?? '',
        'sellerId': sellerId,
        'productId': '',
        'source': 'seller_shop',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Seller phone analytics error: $e');
    }
    _phoneHideTimer = Timer(const Duration(seconds: 5), () {
      showPhone.value = false;
    });
  }

  void listenToCart(String userId) {
    _cartSubscription?.cancel();
    if (userId.isEmpty) return;
    _cartSubscription = FirebaseFirestore.instance
        .collection('carts')
        .where('customer_id', isEqualTo: userId)
        .snapshots()
        .listen((snapshot) {
      cartProductIds
        ..clear()
        ..addAll(snapshot.docs
            .map((doc) => (doc.data()['product_id'] ?? '').toString())
            .where((id) => id.isNotEmpty));
      cartRevision.value++;
    });
  }

  Future<void> logMarketplaceEvent(String type, {String? buyerId, String productId = ''}) async {
    try {
      await FirebaseFirestore.instance.collection('marketplace_events').add({
        'type': type,
        'buyerId': buyerId ?? FirebaseAuth.instance.currentUser?.uid ?? '',
        'sellerId': sellerId,
        'productId': productId,
        'source': 'seller_shop',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Seller marketplace analytics error: $e');
    }
  }

  void dispose() {
    _phoneHideTimer?.cancel();
    _cartSubscription?.cancel();
    showPhone.dispose();
    cartRevision.dispose();
  }
}
