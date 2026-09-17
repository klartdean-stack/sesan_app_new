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
          'chat_seller': 'អ្នកលក់',
          'chat_online': 'កំពុងអនឡាញ',
          'chat_offline': 'ក្រៅបណ្ដាញ',
          'chat_unknown': 'មិនស្គាល់',
          'chat_last_seen_now': 'ទើបតែអនឡាញ',
          'chat_last_seen_minutes': 'អនឡាញមុន @count នាទី',
          'chat_last_seen_hours': 'អនឡាញមុន @count ម៉ោង',
          'chat_last_seen_days': 'អនឡាញមុន @count ថ្ងៃ',
          'chat_manage_sales': 'គ្រប់គ្រងការលក់',
          'chat_block': 'Block អ្នកប្រើ',
          'chat_unblock': 'ដោះ Block',
          'chat_block_success': 'បាន Block អ្នកប្រើរួចរាល់',
          'chat_unblock_success': 'បានដោះ Block រួចរាល់',
          'chat_you_blocked': 'អ្នកបាន Block អ្នកប្រើនេះ',
          'chat_blocked_you': 'អ្នកប្រើនេះបាន Block អ្នក',
          'chat_create_invoice': 'បង្កើតបុង',
          'chat_block_title': 'Block អ្នកប្រើនេះ?',
          'chat_block_body': 'បន្ទាប់ពី Block អ្នកនឹងមិនឃើញមាតិកា និងសាររបស់គ្នាទៅវិញទៅមក។',
          'chat_unblock_title': 'ដោះ Block អ្នកប្រើនេះ?',
          'chat_unblock_body': 'អ្នកនឹងអាចទាក់ទង និងមើលមាតិកាគ្នាវិញ។',
          'chat_cancel': 'បោះបង់',
          'chat_quick_price': 'តម្លៃប៉ុន្មាន?',
          'chat_quick_location': 'ទីតាំងនៅណាដែរ?',
          'chat_quick_stock': 'នៅមានស្តុកទេ?',
          'chat_quick_available': 'បាទ/ចា៎ វានៅមាន',
          'chat_quick_product': 'សួស្ដី! តើសួរទំនិញមួយណាដែរ?',
          'chat_quick_delivery_info': 'សុំលេខ និងទីតាំងទទួលឥវ៉ាន់ផង',
          'chat_quick_invoice': 'ជួយចេញបុងឱ្យផង',
          'chat_quick_received': 'បានទទួល! សូមអរគុណច្រើន! 🙏',
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
          'chat_seller': 'Seller',
          'chat_online': 'Online',
          'chat_offline': 'Offline',
          'chat_unknown': 'Unknown',
          'chat_last_seen_now': 'Last seen just now',
          'chat_last_seen_minutes': 'Last seen @count min ago',
          'chat_last_seen_hours': 'Last seen @count hr ago',
          'chat_last_seen_days': 'Last seen @count days ago',
          'chat_manage_sales': 'Manage sales',
          'chat_block': 'Block user',
          'chat_unblock': 'Unblock',
          'chat_block_success': 'User blocked successfully',
          'chat_unblock_success': 'User unblocked successfully',
          'chat_you_blocked': 'You blocked this user',
          'chat_blocked_you': 'This user blocked you',
          'chat_create_invoice': 'Create invoice',
          'chat_block_title': 'Block this user?',
          'chat_block_body': 'After blocking, you will no longer see each other’s content or messages.',
          'chat_unblock_title': 'Unblock this user?',
          'chat_unblock_body': 'You will be able to contact and view each other’s content again.',
          'chat_cancel': 'Cancel',
          'chat_quick_price': 'How much is it?',
          'chat_quick_location': 'Where are you located?',
          'chat_quick_stock': 'Is it still in stock?',
          'chat_quick_available': 'Yes, it is available.',
          'chat_quick_product': 'Hello! Which product are you asking about?',
          'chat_quick_delivery_info': 'Please send your phone number and delivery location.',
          'chat_quick_invoice': 'Please create an invoice.',
          'chat_quick_received': 'Received. Thank you! 🙏',
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
