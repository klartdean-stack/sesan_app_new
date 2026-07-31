import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class OrderService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ថែមមុខងារនេះចូលក្នុង Class OrderService
  Stream<QuerySnapshot> getPendingOrders() {
    return _db
        .collection('orders')
        .where('status', isEqualTo: 'pending')
        .orderBy('created_at', descending: true)
        .snapshots();
  }

  // ១. Function បង្កើត Order (បំបែកបុងតាមអ្នកលក់ និងកាត់ 7% ស្វ័យប្រវត្តិ)
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
      // កំណត់យក ID អ្នកលក់ប្លែកៗគ្នា
      final sellerIds = cartItems
          .map((item) => item['seller_id']?.toString() ?? 'UNKNOWN')
          .toSet();

      WriteBatch batch = _db.batch();

      for (String sId in sellerIds) {
        // ចម្រាញ់យកទំនិញរបស់អ្នកលក់ម្នាក់ៗ
        List<Map<String, dynamic>> specificItems = cartItems
            .where(
              (item) => (item['seller_id']?.toString() ?? 'UNKNOWN') == sId,
            )
            .toList();

        // ទាញយកលេខទូរស័ព្ទអ្នកលក់ចេញពីទំនិញដំបូង (សម្រាប់ទុកឱ្យ Admin តេតាមដាន)
        String sPhone =
            specificItems.first['seller_phone']?.toString() ?? 'គ្មានលេខ';

        double subTotal = specificItems.fold(0, (sum, item) {
          double price =
              double.tryParse(item['price'].toString().replaceAll(',', '')) ??
              0.0;
          int qty = int.tryParse(item['quantity'].toString()) ?? 1;
          return sum + (price * qty);
        });

        double adminCommission = subTotal * 0.07; // កាត់ 7%
        double sellerEarnings = subTotal - adminCommission; // 93%

        DocumentReference orderRef = _db.collection('orders').doc();

        batch.set(orderRef, {
          'order_id': orderRef.id,
          // ក្នុង batch.set នៃ collection 'orders'
          'is_settled': false,
          'items': specificItems.map((item) {
            return {
              'product_name': item['product_name'] ?? 'គ្មានឈ្មោះ',
              'price':
                  double.tryParse(
                    item['price'].toString().replaceAll(',', ''),
                  ) ??
                  0.0,
              'quantity': int.tryParse(item['quantity'].toString()) ?? 1,
              'seller_id': item['seller_id'] ?? sId,
              // កែត្រង់នេះ៖ ប្រាប់វាថា បើកន្ត្រកមាន seller_phone ឱ្យយកមក
              // បើអត់ទេ ឱ្យឆែកមើលក្នុង phone1 ក្រែងលោជាទំនិញចាស់
              'seller_phone': item['seller_phone'] ?? item['phone1'] ?? sPhone,
              'category': item['category'] ?? 'ទូទៅ',
              'image_url': item['image_url'] ?? '', // រូបភាពទំនិញ
            };
          }).toList(),

          'total_amount': subTotal,
          'admin_commission': adminCommission,
          'seller_earnings': sellerEarnings,

          // ព័ត៌មានអ្នកលក់ និងអតិថិជន (Tracking)
          'seller_id': sId,
          'seller_phone': sPhone, // បន្ថែមលេខអ្នកលក់ក្នុងបុងរួម
          'customer_id': customerId,
          'customer_name': customerName,
          'phone_number': phoneNumber,
          'shipping_address': shippingAddress,
          'payment_image': paymentImage ?? "",

          'status': 'pending',
          'payment_status': 'paid',
          'created_at': FieldValue.serverTimestamp(),

          // សម្រាប់ Report ប្រើបានវែងឆ្ងាយ
          'month_key':
              "${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}",
          'date_key':
              "${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}",
        });
      }
      await batch.commit();
      return true;
    } catch (e) {
      debugPrint("Firebase Order Split Error: $e");
      return false;
    }
  }

  // ៥. Function សម្អាតកន្ត្រកក្រោយទិញរួច (ម៉ត់ចត់តាម UID)
  Future<void> clearCart(String userId) async {
    try {
      var snapshots = await _db
          .collection('carts')
          .where('user_id', isEqualTo: userId)
          .get();
      WriteBatch batch = _db.batch();
      for (var doc in snapshots.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      debugPrint("Clear Cart Error: $e");
    }
  }

  // ៥. មុខងារទាញយក "ប្រវត្តិកម្ម៉ង់" ដែលជោគជ័យសម្រាប់ភ្ញៀវ
  Stream<QuerySnapshot> getOrderHistory(String userId) {
    return _db
        .collection('orders')
        .where('customer_id', isEqualTo: userId)
        .where(
          'status',
          isEqualTo: 'confirmed',
        ) // 🔥 ទាញយកតែបុងដែល Admin បញ្ជាក់រួច
        .orderBy('created_at', descending: true) // តម្រៀបពីថ្មីទៅចាស់
        .snapshots();
  }

  Future<void> confirmPayment(String orderId) async {}
} // ជំនួយសម្រាប់ Format កាលបរិច្ឆេទ

extension DateFormatter on DateTime {
  String format(String pattern) {
    // មេអាចប្រើ intl package បើចង់បាន patterns ច្រើន
    return "${this.year}-${this.month.toString().padLeft(2, '0')}";
  }

  // ថែមមុខងារប្តូរ Status ទៅ Packing និងបូកលុយចូលកាបូបអ្នកលក់
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

      // ១. ប្តូរ Status Order និងកំណត់ថ្ងៃចាប់ផ្តើមវេចខ្ចប់
      batch.update(orderRef, {
        'status': 'packing',
        'packing_date': FieldValue.serverTimestamp(), // 🎯 សម្រាប់រាប់ ៥ ថ្ងៃ
        'is_settled': false, // រក្សាទុកដដែល ដើម្បីឱ្យ Cloud Function ដឹង
      });

      // ២. បាញ់លុយចូលកាបូបអ្នកលក់ភ្លាមៗ (Wallet)
      // វាបូកបញ្ចូលទាំង សរុប (balance) និង រង់ចាំ (wallet_balance)
      batch.update(userRef, {
        'balance': FieldValue.increment(sellerEarnings), // បូកចូលកញ្ចប់សរុប
        'wallet_balance': FieldValue.increment(
          sellerEarnings,
        ), // បូកចូលកញ្ចប់រង់ចាំ
      });

      await batch.commit();
      return true;
    } catch (e) {
      debugPrint("Error Updating to Packing: $e");
      return false;
    }
  }
}
