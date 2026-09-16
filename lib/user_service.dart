import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserService {
  static String? _cachedUserId;

  /// យក User ID (Firebase Auth ឬ SharedPreferences)
  static Future<String?> getUserId() async {
    // ១. បើមាន cache ត្រឡប់ភ្លាម
    if (_cachedUserId != null) return _cachedUserId;

    // ២. ព្យាយាមពី Firebase Auth ជាមុន
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser != null) {
      _cachedUserId = firebaseUser.uid;
      return _cachedUserId;
    }

    // ៣. យកពី SharedPreferences
    final prefs = await SharedPreferences.getInstance();

    // ឆែកថាតើជា Guest ឬ User ដែលបាន Login
    final isLoggedIn = prefs.getBool('is_logged_in') ?? false;
    final isGuest = prefs.getBool('is_guest') ?? false;

    if (!isLoggedIn && !isGuest) return null;

    if (isGuest) {
      _cachedUserId = 'guest';
      return _cachedUserId;
    }

    _cachedUserId =
        prefs.getString('user_uid') ??
        prefs.getString('uid') ??
        prefs.getString('user_id');

    return _cachedUserId;
  }

  /// លុប cache (ពេល logout/login ថ្មី)
  static void clearCache() {
    _cachedUserId = null;
  }

  /// Logout លុបតែ auth/session keys ដើម្បីរក្សា Remember phone/settings
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_uid');
    await prefs.remove('is_logged_in');
    await prefs.remove('is_guest');
    await prefs.remove('user_name');
    await prefs.remove('user_phone');
    await prefs.remove('user_photo');
    await prefs.remove('user_role');
    clearCache();
  }
}
