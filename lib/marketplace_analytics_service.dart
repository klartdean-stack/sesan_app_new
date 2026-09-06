import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class MarketplaceAnalyticsService {
  MarketplaceAnalyticsService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static Future<void> logEvent({
    required String type,
    required String buyerId,
    required String sellerId,
    String productId = '',
    String source = '',
    List<String>? sellerIds,
    List<String>? productIds,
    String? orderId,
    num? totalAmount,
  }) async {
    try {
      final data = <String, dynamic>{
        'type': type,
        'buyerId': buyerId,
        'sellerId': sellerId,
        'productId': productId,
        'source': source,
        'createdAt': FieldValue.serverTimestamp(),
      };

      if (sellerIds != null && sellerIds.isNotEmpty) data['sellerIds'] = sellerIds;
      if (productIds != null && productIds.isNotEmpty) data['productIds'] = productIds;
      if (orderId != null && orderId.isNotEmpty) data['orderId'] = orderId;
      if (totalAmount != null) data['totalAmount'] = totalAmount;

      await _db.collection('marketplace_events').add(data);
    } catch (e) {
      debugPrint('Marketplace analytics error: $e');
    }
  }

  static Future<void> logOrderCompleted({
    required String orderId,
    required String buyerId,
    required String sellerId,
    String productId = '',
    num? totalAmount,
  }) async {
    if (orderId.isEmpty) return;
    try {
      await _db.collection('marketplace_events').doc('order_completed_$orderId').set({
        'type': 'order_completed',
        'buyerId': buyerId,
        'sellerId': sellerId,
        'productId': productId,
        'orderId': orderId,
        'source': 'admin_confirmation',
        if (totalAmount != null) 'totalAmount': totalAmount,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Marketplace order analytics error: $e');
    }
  }
}
