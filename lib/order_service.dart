import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

class OrderService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<QuerySnapshot> getPendingOrders() {
    return _db
        .collection('orders')
        .where('status', isEqualTo: 'pending')
        .orderBy('created_at', descending: true)
        .snapshots();
  }

  // Money fields are calculated only by Cloud Functions.
  Future<bool> createOrder({
    required List<Map<String, dynamic>> cartItems,
    required double totalAmount,
    required String customerId,
    required String customerName,
    required String phoneNumber,
    required String shippingAddress,
    String? paymentImage,
  }) async {
    try {
      final callable = FirebaseFunctions.instanceFor(
        region: 'asia-southeast1',
      ).httpsCallable('secureCreateOrder');

      final items = cartItems.map((item) {
        return {
          'product_id': item['product_id']?.toString() ?? '',
          'quantity': int.tryParse(item['quantity']?.toString() ?? '') ?? 1,
        };
      }).toList();

      await callable.call({
        'items': items,
        'customerName': customerName,
        'phoneNumber': phoneNumber,
        'shippingAddress': shippingAddress,
        'paymentImage': paymentImage ?? '',
      });

      return true;
    } on FirebaseFunctionsException catch (e) {
      debugPrint('secureCreateOrder failed: ${e.code} ${e.message}');
      return false;
    } catch (e) {
      debugPrint('secureCreateOrder error: $e');
      return false;
    }
  }

  Future<void> clearCart(String userId) async {
    try {
      final results = await Future.wait([
        _db.collection('carts').where('customer_id', isEqualTo: userId).get(),
        _db.collection('carts').where('user_id', isEqualTo: userId).get(),
      ]);
      final docsByPath = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
      for (final snapshot in results) {
        for (final doc in snapshot.docs) {
          docsByPath[doc.reference.path] = doc;
        }
      }

      final batch = _db.batch();
      for (final doc in docsByPath.values) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Clear Cart Error: $e');
    }
  }

  Stream<QuerySnapshot> getOrderHistory(String userId) {
    return _db
        .collection('orders')
        .where('customer_id', isEqualTo: userId)
        .where('status', isEqualTo: 'confirmed')
        .orderBy('created_at', descending: true)
        .snapshots();
  }

  Future<void> confirmPayment(String orderId) async {}
}

extension DateFormatter on DateTime {
  String format(String pattern) {
    return '${this.year}-${this.month.toString().padLeft(2, '0')}';
  }

  Future<bool> updateStatusToPacking({
    required String orderId,
    required String sellerId,
    required double sellerEarnings,
  }) async {
    try {
      final callable = FirebaseFunctions.instanceFor(
        region: 'asia-southeast1',
      ).httpsCallable('secureSellerOrderStatus');

      await callable.call({
        'orderId': orderId,
        'status': 'packing',
      });
      return true;
    } on FirebaseFunctionsException catch (e) {
      debugPrint('secureSellerOrderStatus failed: ${e.code} ${e.message}');
      return false;
    } catch (e) {
      debugPrint('Error Updating to Packing: $e');
      return false;
    }
  }
}
