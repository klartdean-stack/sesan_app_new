import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

class AdminActionsService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 🎯 ១. មុខងារ "បង្កក់គណនី" (Toggle Status - វិធីដែលមេចង់បាន)
  // ប្រើ Field 'isFrozen' ជាកុងតាក់សម្រាប់បិទប៊ូតុងដកលុយ
  static Future<void> toggleFreeze(String sellerId, bool status) async {
    try {
      await _db.collection('users').doc(sellerId).update({
        'isFrozen': status, // true គឺបង្កក់ (Disable Button), false គឺធម្មតា
        'updated_at': FieldValue.serverTimestamp(),
      });
      print("គណនី $sellerId ត្រូវបានប្តូរស្ថានភាព Frozen ទៅជា: $status");
    } catch (e) {
      print("Error toggling freeze status: $e");
      throw e;
    }
  }

  // ៣. មុខងារដោះបង្កក់ (Unfreeze)
  static Future<void> unfreezeUser(String sellerId) async {
    await _db.collection('users').doc(sellerId).update({
      'isFrozen': false, // ប្តូរមកជា false ដើម្បីឱ្យគេដកលុយបានវិញ
    });
  }

  // ៤. មុខងារបូកបន្ថែមលុយ (Manual Adjustment)
  static Future<void> addBalance(String sellerId, double amount) async {
    await _db.collection('users').doc(sellerId).update({
      'wallet_balance': FieldValue.increment(
        amount,
      ), // ប្រើ increment ដើម្បីបូកថែមលើលុយដែលមានស្រាប់
    });
  }

  // 🎯 ថែមមុខងារទី ៥ សម្រាប់ប្តូរ Status បណ្តឹងទៅជា "ដោះស្រាយរួច"
  static Future<void> resolveDispute(String docId) async {
    await _db.collection('complaints').doc(docId).update({
      'status': 'resolved',
    });
  }

  // 🎯 មេថែម String orderId ចូលក្នុង Parameter នេះ
  static Future<void> deductBalance({
    required String sellerId,
    required String orderId, // 👈 ថែមអាហ្នឹង ១
    required double amount,
    required String reason,
  }) async {
    try {
      await _db.runTransaction((transaction) async {
        DocumentReference sellerRef = _db.collection('users').doc(sellerId);
        DocumentReference orderRef = _db
            .collection('orders')
            .doc(orderId); // 👈 ថែមអាហ្នឹង ២

        // 🎯 កែក្នុង admin_actions_service.dart ជួរ ៦០ ដល់ ៦៥
        transaction.update(sellerRef, {
          'available_balance': FieldValue.increment(-amount),
          // ❌ លុបជួរ wallet_balance ចេញពីត្រង់នេះ
        });

        // ២. បិទបុងហ្នឹងចោល កុំឱ្យ Cloud Function មកបូកលុយឱ្យវាវិញនៅថ្ងៃទី ៥
        transaction.update(orderRef, {
          'is_settled': true, // 👈 ថែមអាហ្នឹង ៤ (សំខាន់បំផុត)
        });

        // ៣. បង្កើតរបាយការណ៍ (កូដមេដដែល)
        DocumentReference reportRef = _db.collection('admin_reports').doc();
        transaction.set(reportRef, {
          'seller_id': sellerId,
          'order_id': orderId,
          'action': 'ADMIN_DEDUCTION',
          'amount': amount,
          'reason': reason,
          'time': FieldValue.serverTimestamp(),
        });
      });
      _notifySeller(sellerId, amount, reason);
    } catch (e) {
      print("Error in deductBalance: $e");
      throw e;
    }
  }

  // 🎯 ៣. មុខងារបាញ់ Notification (រក្សាទុកដដែល)
  static Future<void> _notifySeller(String sId, double amt, String rs) async {
    try {
      final HttpsCallable callable = FirebaseFunctions.instanceFor(
        region: 'asia-southeast1',
      ).httpsCallable('sendSellerNotification');
      await callable.call({
        'sellerId': sId,
        'title': '⚠️ ការកាត់ប្រាក់ពិន័យ',
        'body': 'គណនីរបស់អ្នកត្រូវបានកាត់ប្រាក់ $amt ៛។ មូលហេតុ៖ $rs',
      });
    } catch (e) {
      print("Notification failed: $e");
    }
  }
}
