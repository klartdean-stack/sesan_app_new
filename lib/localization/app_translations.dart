import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppTranslations extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {
        'km_KH': {
          'khmer': 'ខ្មែរ',
          'english': 'English',
          'login_subtitle': 'ចូលប្រើប្រាស់គណនីរបស់អ្នក',
          'phone': 'លេខទូរសព្ទ',
          'phone_hint': 'ឧទាហរណ៍ 088XXXXXXX',
          'phone_required': 'សូមបញ្ចូលលេខទូរសព្ទ',
          'phone_invalid': 'លេខទូរសព្ទមិនត្រឹមត្រូវ',
          'password': 'លេខសម្ងាត់',
          'password_hint': 'បញ្ចូលលេខសម្ងាត់របស់អ្នក',
          'password_required': 'សូមបញ្ចូលលេខសម្ងាត់',
          'password_min_6': 'លេខសម្ងាត់ត្រូវមានយ៉ាងតិច 6 ខ្ទង់',
          'remember_phone': 'ចង់ចាំលេខទូរសព្ទ',
          'forgot_password': 'ភ្លេចលេខសម្ងាត់?',
          'login': 'ចូលប្រើប្រាស់',
          'no_account': 'មិនទាន់មានគណនី? ',
          'register_here': 'ចុះឈ្មោះនៅទីនេះ',
          'continue_guest': 'ចូលមើលសិន',
          'account_not_found': 'រកមិនឃើញគណនីនេះទេ',
          'wrong_password': 'លេខសម្ងាត់មិនត្រឹមត្រូវទេ',
          'login_success': 'ចូលប្រើប្រាស់ជោគជ័យ',
          'settings': 'ការកំណត់',
          'language': 'ភាសា',
          'account': 'គណនី',
          'edit_profile': 'កែព័ត៌មានផ្ទាល់ខ្លួន',
          'blocked_profiles': 'គណនីដែលបាន Block',
          'delete_account': 'លុបគណនី',
          'home': 'ទំព័រដើម',
          'cart': 'កន្ត្រក',
          'chat': 'ឆាត',
          'profile': 'គណនី',
        },
        'en_US': {
          'khmer': 'Khmer',
          'english': 'English',
          'login_subtitle': 'Sign in to your account',
          'phone': 'Phone number',
          'phone_hint': 'Example: 088XXXXXXX',
          'phone_required': 'Please enter your phone number',
          'phone_invalid': 'Invalid phone number',
          'password': 'Password',
          'password_hint': 'Enter your password',
          'password_required': 'Please enter your password',
          'password_min_6': 'Password must contain at least 6 digits',
          'remember_phone': 'Remember phone number',
          'forgot_password': 'Forgot password?',
          'login': 'Sign in',
          'no_account': 'Don’t have an account? ',
          'register_here': 'Register here',
          'continue_guest': 'Continue as guest',
          'account_not_found': 'Account not found',
          'wrong_password': 'Incorrect password',
          'login_success': 'Signed in successfully',
          'settings': 'Settings',
          'language': 'Language',
          'account': 'Account',
          'edit_profile': 'Edit profile',
          'blocked_profiles': 'Blocked profiles',
          'delete_account': 'Delete account',
          'home': 'Home',
          'cart': 'Cart',
          'chat': 'Chat',
          'profile': 'Account',
        },
      };
}

class LanguageController extends GetxController {
  LanguageController(this.currentLocale);

  Locale currentLocale;

  static Future<LanguageController> create() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString('app_language') ?? 'km';
    return LanguageController(
      code == 'en' ? const Locale('en', 'US') : const Locale('km', 'KH'),
    );
  }

  bool get isEnglish => currentLocale.languageCode == 'en';

  Future<void> changeLanguage(String code) async {
    currentLocale =
        code == 'en' ? const Locale('en', 'US') : const Locale('km', 'KH');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_language', code);
    Get.updateLocale(currentLocale);
    update();
  }
}

class LanguageSwitcher extends StatelessWidget {
  const LanguageSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<LanguageController>(
      builder: (controller) {
        return PopupMenuButton<String>(
          tooltip: 'language'.tr,
          onSelected: controller.changeLanguage,
          itemBuilder: (context) => const [
            PopupMenuItem<String>(
              value: 'km',
              child: Text('ខ្មែរ'),
            ),
            PopupMenuItem<String>(
              value: 'en',
              child: Text('English'),
            ),
          ],
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.language, size: 18),
                const SizedBox(width: 6),
                Text(controller.isEnglish ? 'English' : 'ខ្មែរ'),
                const SizedBox(width: 2),
                const Icon(Icons.arrow_drop_down, size: 18),
              ],
            ),
          ),
        );
      },
    );
  }
}
