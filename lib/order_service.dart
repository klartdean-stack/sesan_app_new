import 'package:cloud_firestore/cloud_firestore.dart';
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
      final sellerIds = cartItems
          .map((item) => item['seller_id']?.toString() ?? 'UNKNOWN')
          .toSet();

      final Map<String, int> requestedByProduct = {};
      for (final item in cartItems) {
        final productId = item['product_id']?.toString() ?? '';
        if (productId.isEmpty) continue;
        final qty = int.tryParse(item['quantity']?.toString() ?? '') ?? 1;
        requestedByProduct[productId] =
            (requestedByProduct[productId] ?? 0) + qty;
      }

      await _db.runTransaction((transaction) async {
        final Map<String, DocumentSnapshot<Map<String, dynamic>>> products = {};

        for (final productId in requestedByProduct.keys) {
          final ref = _db.collection('products').doc(productId);
          products[productId] = await transaction.get(ref);
        }

        for (final entry in requestedByProduct.entries) {
          final productId = entry.key;
          final requestedQty = entry.value;
          final snapshot = products[productId];
          final data = snapshot?.data();

          if (snapshot == null || !snapshot.exists || data == null) {
            continue;
          }

          if (data['track_stock'] == true) {
            final available = data['stock_quantity'] is num
                ? (data['stock_quantity'] as num).toInt()
                : int.tryParse(data['stock_quantity']?.toString() ?? '') ?? 0;

            if (requestedQty <= 0 || available < requestedQty) {
              final name = data['product_name']?.toString() ?? productId;
              throw StateError(
                'OUT_OF_STOCK: $name (available: $available, requested: $requestedQty)',
              );
            }

            final remaining = available - requestedQty;
            transaction.update(snapshot.reference, {
              'stock_quantity': remaining,
              'sold_quantity': FieldValue.increment(requestedQty),
              'is_available': remaining > 0,
              'stock_updated_at': FieldValue.serverTimestamp(),
            });
          }
        }

        for (final sId in sellerIds) {
          final specificItems = cartItems
              .where(
                (item) =>
                    (item['seller_id']?.toString() ?? 'UNKNOWN') == sId,
              )
              .toList();

          final sPhone =
              specificItems.first['seller_phone']?.toString() ?? 'គ្មានលេខ';

          final subTotal = specificItems.fold<double>(0, (sum, item) {
            final price = double.tryParse(
                  item['price'].toString().replaceAll(',', ''),
                ) ??
                0.0;
            final qty = int.tryParse(item['quantity'].toString()) ?? 1;
            return sum + (price * qty);
          });

          final adminCommission = subTotal * 0.07;
          final sellerEarnings = subTotal - adminCommission;
          final orderRef = _db.collection('orders').doc();

          transaction.set(orderRef, {
            'order_id': orderRef.id,
            'is_settled': false,
            'stock_restored': false,
            'items': specificItems.map((item) {
              final productId = item['product_id']?.toString() ?? '';
              final productData = products[productId]?.data();

              return {
                'product_id': productId,
                'product_name': item['product_name'] ?? 'គ្មានឈ្មោះ',
                'price': double.tryParse(
                      item['price'].toString().replaceAll(',', ''),
                    ) ??
                    0.0,
                'quantity': int.tryParse(item['quantity'].toString()) ?? 1,
                'stock_tracked': productData?['track_stock'] == true,
                'stock_unit':
                    productData?['stock_unit'] ?? item['stock_unit'] ?? 'item',
                'seller_id': item['seller_id'] ?? sId,
                'seller_name': item['seller_name'] ?? 'អាជីវករ សេសាន',
                'seller_photo': item['seller_photo'] ?? '',
                'seller_phone':
                    item['seller_phone'] ?? item['phone1'] ?? sPhone,
                'category': item['category'] ?? 'ទូទៅ',
                'image_url': item['image_url'] ?? '',
              };
            }).toList(),
            'total_amount': subTotal,
            'admin_commission': adminCommission,
            'seller_earnings': sellerEarnings,
            'seller_id': sId,
            'seller_phone': sPhone,
            'customer_id': customerId,
            'customer_name': customerName,
            'phone_number': phoneNumber,
            'shipping_address': shippingAddress,
            'payment_image': paymentImage ?? '',
            'status': 'pending',
            'payment_status': 'paid',
            'created_at': FieldValue.serverTimestamp(),
            'month_key':
                "${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}",
            'date_key':
                "${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}",
          });
        }
      });

      return true;
    } catch (e) {
      debugPrint("Firebase Order Split/Stock Error: $e");
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
      debugPrint("Clear Cart Error: $e");
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
    return "${this.year}-${this.month.toString().padLeft(2, '0')}";
  }

  Future<bool> updateStatusToPacking({
    required String orderId,
    required String sellerId,
    required double sellerEarnings,
  }) async {
    try {
      WriteBatch batch = FirebaseFirestore.instance.batch();

      DocumentReference orderRef = FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId);
      DocumentReference userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(sellerId);

      batch.update(orderRef, {
        'status': 'packing',
        'packing_date': FieldValue.serverTimestamp(),
        'is_settled': false,
      });

      batch.update(userRef, {
        'balance': FieldValue.increment(sellerEarnings),
        'wallet_balance': FieldValue.increment(sellerEarnings),
      });

      await batch.commit();
      return true;
    } catch (e) {
      debugPrint("Error Updating to Packing: $e");
      return false;
    }
  }
}
