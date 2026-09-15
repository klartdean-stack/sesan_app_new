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

  void _notifyCartChanged() => cartRevision.value++;

  String maskPhone(String phone) {
    final value = phone.trim().replaceAll(RegExp(r'\s+'), '');
    if (value.isEmpty) return '';
    if (value.length <= 3) return 'XXX';
    return '${value.substring(0, value.length - 3)}XXX';
  }

  Future<void> revealPhone({String? buyerId}) async {
    _phoneHideTimer?.cancel();
    showPhone.value = true;
    await logMarketplaceEvent('phone_reveal', buyerId: buyerId);
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
      final ids = snapshot.docs
          .map((doc) => (doc.data()['product_id'] ?? '').toString())
          .where((id) => id.isNotEmpty)
          .toSet();
      cartProductIds
        ..clear()
        ..addAll(ids);
      cartBusyIds.removeWhere((id) => !ids.contains(id));
      _notifyCartChanged();
    }, onError: (error) {
      debugPrint('Seller cart listener error: $error');
    });
  }

  bool canAddToCart(String productId) {
    return productId.isNotEmpty &&
        !cartProductIds.contains(productId) &&
        !cartBusyIds.contains(productId);
  }

  void markCartBusy(String productId) {
    if (productId.isEmpty) return;
    cartBusyIds.add(productId);
    _notifyCartChanged();
  }

  void markCartAdded(String productId) {
    if (productId.isEmpty) return;
    cartProductIds.add(productId);
    cartBusyIds.remove(productId);
    _notifyCartChanged();
  }

  void clearCartBusy(String productId) {
    cartBusyIds.remove(productId);
    _notifyCartChanged();
  }

  Future<bool> removeProductFromCart({
    required String userId,
    required String productId,
  }) async {
    if (userId.isEmpty ||
        productId.isEmpty ||
        cartBusyIds.contains(productId)) {
      return false;
    }

    markCartBusy(productId);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('carts')
          .where('customer_id', isEqualTo: userId)
          .get();
      final batch = FirebaseFirestore.instance.batch();
      var found = false;
      for (final doc in snapshot.docs) {
        if ((doc.data()['product_id'] ?? '').toString() == productId) {
          batch.delete(doc.reference);
          found = true;
        }
      }
      if (found) await batch.commit();
      cartProductIds.remove(productId);
      cartBusyIds.remove(productId);
      _notifyCartChanged();
      return found;
    } catch (e) {
      cartBusyIds.remove(productId);
      _notifyCartChanged();
      debugPrint('Seller remove cart error: $e');
      return false;
    }
  }

  Future<void> logMarketplaceEvent(
    String type, {
    String? buyerId,
    String productId = '',
  }) async {
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
