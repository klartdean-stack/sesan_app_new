import 'package:cloud_firestore/cloud_firestore.dart';

class AccountDeletionService {
  AccountDeletionService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const List<Map<String, String>> _ownedCollections = [
    {'collection': 'products', 'ownerField': 'seller_id'},
    {'collection': 'wanted_products', 'ownerField': 'userId'},
    {'collection': 'pre_orders', 'ownerField': 'owner_id'},
    {'collection': 'auction_products', 'ownerField': 'owner_id'},
  ];

  static DocumentReference<Map<String, dynamic>> _archiveRoot(String uid) =>
      _db.collection('deleted_accounts').doc(uid);

  static Future<int> archiveOwnedContent(String uid) async {
    var archived = 0;
    final root = _archiveRoot(uid);
    await root.set({
      'userId': uid,
      'archivedAt': FieldValue.serverTimestamp(),
      'restoreDeadline': Timestamp.fromDate(
        DateTime.now().add(const Duration(days: 15)),
      ),
      'status': 'recoverable',
    }, SetOptions(merge: true));

    for (final spec in _ownedCollections) {
      final collection = spec['collection']!;
      final ownerField = spec['ownerField']!;
      final snapshot = await _db
          .collection(collection)
          .where(ownerField, isEqualTo: uid)
          .get();

      for (final document in snapshot.docs) {
        final archiveId = '${collection}__${document.id}';
        await root.collection('content').doc(archiveId).set({
          'originalCollection': collection,
          'originalId': document.id,
          'data': document.data(),
          'archivedAt': FieldValue.serverTimestamp(),
        });
        await document.reference.delete();
        archived++;
      }
    }
    return archived;
  }

  static Future<int> restoreOwnedContent(String uid) async {
    final root = _archiveRoot(uid);
    final snapshot = await root.collection('content').get();
    var restored = 0;

    for (final archive in snapshot.docs) {
      final data = archive.data();
      final collection = data['originalCollection']?.toString();
      final documentId = data['originalId']?.toString();
      final rawData = data['data'];
      if (collection == null || documentId == null || rawData is! Map) continue;

      await _db.collection(collection).doc(documentId).set(
            Map<String, dynamic>.from(rawData),
          );
      await archive.reference.delete();
      restored++;
    }

    await root.set({
      'status': 'restored',
      'restoredAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return restored;
  }

  static Future<void> markExpired(String uid) async {
    await _archiveRoot(uid).set({
      'status': 'expired',
      'expiredAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await _db.collection('users').doc(uid).set({
      'accountStatus': 'deletion_expired',
      'deletionExpiredAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
