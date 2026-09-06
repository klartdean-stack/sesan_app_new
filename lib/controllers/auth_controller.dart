import 'package:get/get.dart';
import 'package:my_app/login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthController extends GetxController {
  bool isLoggedIn = false;
  bool isGuest = false;
  String userId = '';

  @override
  void onInit() {
    super.onInit();
    checkLoginStatus();
  }

  Future<void> checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getString('user_uid');
    final savedLoggedIn = prefs.getBool('is_logged_in') ?? false;
    final guest = prefs.getBool('is_guest') ?? false;

    if (savedLoggedIn && uid != null && uid.isNotEmpty) {
      isLoggedIn = true;
      userId = uid;
      isGuest = false;
    } else if (guest) {
      isGuest = true;
      isLoggedIn = false;
      userId = '';
    } else {
      isLoggedIn = false;
      isGuest = false;
      userId = '';
    }
  }

  Future<void> loginAsGuest() async {
    isGuest = true;
    isLoggedIn = false;
    userId = '';

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_guest', true);
    await prefs.setBool('is_logged_in', false);
    await prefs.remove('user_uid');
  }

  Future<void> loginWithUid(String uid) async {
    isLoggedIn = true;
    userId = uid;
    isGuest = false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_uid', uid);
    await prefs.setBool('is_logged_in', true);
    await prefs.setBool('is_guest', false);
  }

  Future<void> logout() async {
    isLoggedIn = false;
    isGuest = false;
    userId = '';

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_uid');
    await prefs.remove('is_guest');
    await prefs.remove('is_logged_in');

    Get.offAll(() => const LoginScreen());
  }
}
