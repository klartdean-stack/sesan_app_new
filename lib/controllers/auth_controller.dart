import 'package:get/get.dart';
import 'package:my_app/login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';


class AuthController extends GetxController {
  // ✅ ប្រើ bool ធម្មតា — មិន reactive
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
    final guest = prefs.getBool('is_guest') ?? false;


    if (uid != null && uid.isNotEmpty) {
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
    await prefs.remove('user_uid');
  }


  Future<void> loginWithUid(String uid) async {
    isLoggedIn = true;
    userId = uid;
    isGuest = false;


    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_uid', uid);
    await prefs.setBool('is_guest', false);
  }


  Future<void> logout() async {
    isLoggedIn = false;
    isGuest = false;
    userId = '';


    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_uid');
    await prefs.remove('is_guest');


    Get.offAll(() => const LoginScreen());
  }
}



