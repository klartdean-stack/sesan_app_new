import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthSessionStore {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _emailKey = 'firebase_auth_email';
  static const String _passwordKey = 'firebase_auth_password';
  static const String _uidKey = 'firebase_auth_uid';
  static const String _providerKey = 'firebase_auth_provider';

  static Future<void> save({
    required String email,
    required String password,
    required String uid,
  }) async {
    await _storage.write(key: _emailKey, value: email);
    await _storage.write(key: _passwordKey, value: password);
    await _storage.write(key: _uidKey, value: uid);
    await _storage.write(key: _providerKey, value: 'password');
  }

  static Future<void> saveGoogle({required String uid}) async {
    await _storage.write(key: _uidKey, value: uid);
    await _storage.write(key: _providerKey, value: 'google');
    await _storage.delete(key: _emailKey);
    await _storage.delete(key: _passwordKey);
  }

  static Future<User?> restore({
    String? expectedUid,
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final storedUid = await _storage.read(key: _uidKey);
    final provider = await _storage.read(key: _providerKey) ?? 'password';
    if (storedUid == null) return null;
    if (expectedUid != null &&
        expectedUid.isNotEmpty &&
        storedUid != expectedUid) {
      await clear();
      return null;
    }

    try {
      if (provider == 'google') {
        final googleUser = await GoogleSignIn().signInSilently().timeout(timeout);
        if (googleUser == null) return null;

        final googleAuth = await googleUser.authentication;
        final googleCredential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        final googleResult = await FirebaseAuth.instance
            .signInWithCredential(googleCredential)
            .timeout(timeout);
        final googleFirebaseUser = googleResult.user;
        if (googleFirebaseUser == null || googleFirebaseUser.uid != storedUid) {
          await FirebaseAuth.instance.signOut();
          return null;
        }
        return googleFirebaseUser;
      }

      final email = await _storage.read(key: _emailKey);
      final password = await _storage.read(key: _passwordKey);
      if (email == null || password == null) return null;

      final credential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password)
          .timeout(timeout);
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
    await _storage.delete(key: _providerKey);
  }
}
