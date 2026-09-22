import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_session_store.dart';

class GoogleAuthResult {
  final String uid;
  final Map<String, dynamic> userData;
  final bool isNewUser;

  const GoogleAuthResult({
    required this.uid,
    required this.userData,
    required this.isNewUser,
  });
}

class GoogleAuthService {
  static final GoogleSignIn _googleSignIn = GoogleSignIn();

  static Future<GoogleAuthResult?> signIn({
    bool forceAccountPicker = true,
  }) async {
    // Explicit Google sign-in should always let the user choose a Gmail
    // account. This is important on shared/multi-account Android devices.
    if (forceAccountPicker) {
      try {
        await _googleSignIn.signOut();
      } catch (_) {}
    }

    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null;

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final authResult =
        await FirebaseAuth.instance.signInWithCredential(credential);
    final user = authResult.user;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'google-user-missing',
        message: 'Google sign-in did not return a Firebase user.',
      );
    }

    final userRef =
        FirebaseFirestore.instance.collection('users').doc(user.uid);
    final snapshot = await userRef.get();
    final isNewUser = !snapshot.exists;

    if (isNewUser) {
      await userRef.set({
        'uid': user.uid,
        'name': (user.displayName ?? googleUser.displayName ?? '').trim(),
        'email': (user.email ?? googleUser.email).trim(),
        'phone': user.phoneNumber ?? '',
        'photoUrl': user.photoURL ?? googleUser.photoUrl ?? '',
        'authProvider': 'google',
        'balance': 0,
        'wallet_balance': 0,
        'today_earnings': 0,
        'accountStatus': 'active',
        'isDeleted': false,
        'createdAt': FieldValue.serverTimestamp(),
        'lastLogin': FieldValue.serverTimestamp(),
      });
    } else {
      await userRef.set({
        'email': user.email ?? googleUser.email,
        'authProvider': 'google',
        'lastLogin': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    final freshSnapshot = await userRef.get();
    final data = freshSnapshot.data() ?? <String, dynamic>{};

    if (data['isDeleted'] == true ||
        data['accountStatus'] == 'pending_deletion') {
      await FirebaseAuth.instance.signOut();
      await _googleSignIn.signOut();
      throw FirebaseAuthException(
        code: 'account-pending-deletion',
        message:
            'This account is pending deletion. Please use your existing recovery flow first.',
      );
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_uid', user.uid);
    await prefs.setString(
      'user_name',
      (data['name'] ?? user.displayName ?? '').toString(),
    );
    await prefs.setString(
      'user_phone',
      (data['phone'] ?? user.phoneNumber ?? '').toString(),
    );
    await prefs.setString(
      'user_photo',
      (data['photoUrl'] ?? user.photoURL ?? '').toString(),
    );
    await prefs.setString('user_role', (data['role'] ?? 'user').toString());
    await prefs.setBool('is_logged_in', true);
    await prefs.setBool('is_guest', false);

    await AuthSessionStore.saveGoogle(uid: user.uid);

    return GoogleAuthResult(
      uid: user.uid,
      userData: data,
      isNewUser: isNewUser,
    );
  }

  static Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
    await _googleSignIn.signOut();
    await AuthSessionStore.clear();
  }
}
