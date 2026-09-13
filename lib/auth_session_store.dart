import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthSessionStore {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _emailKey = 'firebase_auth_email';
  static const String _passwordKey = 'firebase_auth_password';
  static const String _uidKey = 'firebase_auth_uid';

  static Future<void> save({
    required String email,
    required String password,
    required String uid,
  }) async {
    await _storage.write(key: _emailKey, value: email);
    await _storage.write(key: _passwordKey, value: password);
    await _storage.write(key: _uidKey, value: uid);
  }

  static Future<User?> restore({String? expectedUid}) async {
    final email = await _storage.read(key: _emailKey);
    final password = await _storage.read(key: _passwordKey);
    final storedUid = await _storage.read(key: _uidKey);
    if (email == null || password == null || storedUid == null) return null;
    if (expectedUid != null &&
        expectedUid.isNotEmpty &&
        storedUid != expectedUid) {
      await clear();
      return null;
    }

    try {
      final credential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);
      final user = credential.user;
      if (user == null || user.uid != storedUid) {
        await FirebaseAuth.instance.signOut();
        await clear();
        return null;
      }
      return user;
    } on FirebaseAuthException catch (error) {
      if (error.code == 'user-not-found' ||
          error.code == 'wrong-password' ||
          error.code == 'invalid-credential' ||
          error.code == 'user-disabled') {
        await clear();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear() async {
    await _storage.delete(key: _emailKey);
    await _storage.delete(key: _passwordKey);
    await _storage.delete(key: _uidKey);
  }
}
