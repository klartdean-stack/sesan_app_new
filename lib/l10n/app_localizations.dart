import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Lightweight localization bridge for screens ported from Android V51.
///
/// The Android app uses generated localization classes. The iOS parity branch
/// still uses a mixed GetX/appText setup, so this bridge exposes the generated
/// API surface needed by migrated screens without requiring generated files.
class AppLocalizations {
  final String languageCode;
  const AppLocalizations._(this.languageCode);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizations._(Localizations.localeOf(context).languageCode);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('km'),
  ];

  bool get _en => languageCode == 'en';
  String _v(String km, String en) => _en ? en : km;

  String get searchProducts => _v('ស្វែងរកទំនិញ...', 'Search products...');
  String get account => _v('គណនី', 'Account');
  String get signInToViewAccount =>
      _v('សូមចូលគណនីដើម្បីមើលព័ត៌មានគណនី', 'Sign in to view your account');
  String get goToSignIn => _v('ទៅចូលគណនី', 'Go to sign in');
  String get accountAndMoney => _v('គណនី និងហិរញ្ញវត្ថុ', 'Account & Finance');
  String get signOut => _v('ចាកចេញ', 'Sign out');
  String get signOutConfirmation =>
      _v('តើអ្នកពិតជាចង់ចាកចេញពីគណនីមែនទេ?', 'Are you sure you want to sign out?');
  String get cancel => _v('បោះបង់', 'Cancel');
  String get financeCenter => _v('មជ្ឈមណ្ឌលហិរញ្ញវត្ថុ', 'Finance Center');
  String get viewIncomeExpenses =>
      _v('មើលចំណូល ចំណាយ និងសមតុល្យ', 'View income, expenses and balance');
  String get sesanPartnership => _v('ភាពជាដៃគូ Sesan', 'Sesan Partnership');
  String get sesanPartnershipDescription => _v(
        'មើលព័ត៌មានវិនិយោគ និងភាពជាដៃគូ',
        'View investment and partnership information',
      );
  String get savedProductsAndShops =>
      _v('ទំនិញ និងហាងដែលបានរក្សាទុក', 'Saved products & shops');
  String get savedProductsAndFollowedShops => _v(
        'មើលទំនិញដែលបានរក្សាទុក និងហាងដែលបានតាមដាន',
        'View saved products and followed shops',
      );
  String get managePostedProducts =>
      _v('គ្រប់គ្រងទំនិញដែលបានបង្ហោះ', 'Manage posted products');
  String get viewMyShop => _v('មើលហាងរបស់ខ្ញុំ', 'View my shop');
  String get previewMyShop =>
      _v('មើលហាងដូចដែលអតិថិជនឃើញ', 'Preview your shop as customers see it');
  String get adminDashboard => _v('ផ្ទាំងគ្រប់គ្រង Admin', 'Admin Dashboard');
  String get reviewCustomerPayments =>
      _v('ពិនិត្យការទូទាត់របស់អតិថិជន', 'Review customer payments');
  String get sellerWithdrawals => _v('សំណើដកប្រាក់អ្នកលក់', 'Seller Withdrawals');
  String get reviewSellerWithdrawals =>
      _v('ពិនិត្យសំណើដកប្រាក់របស់អ្នកលក់', 'Review seller withdrawal requests');
  String get vipMember => _v('សមាជិក VIP', 'VIP Member');
  String get vipMemberDescription =>
      _v('គ្រប់គ្រងអត្ថប្រយោជន៍ និងសមាជិកភាព VIP', 'Manage VIP membership and benefits');
  String get becomeVip => _v('ក្លាយជាសមាជិក VIP', 'Become VIP');
  String get becomeVipDescription =>
      _v('ទទួលបានអត្ថប្រយោជន៍បន្ថែមពី Sesan App', 'Unlock more Sesan App benefits');
  String get legalPolicies => _v('គោលការណ៍ និងលក្ខខណ្ឌ', 'Policies & Terms');
  String get settings => _v('ការកំណត់', 'Settings');
  String get helpAndSupport => _v('ជំនួយ និងការគាំទ្រ', 'Help & Support');
  String get aboutUs => _v('អំពីយើង', 'About us');
  String get vipBenefits => _v('អត្ថប្រយោជន៍ VIP', 'VIP Benefits');
  String get vipBadgeBenefit => _v('ទទួលសញ្ញា VIP លើប្រូហ្វាល់', 'VIP badge on your profile');
  String get vipStatisticsBenefit => _v('មើលស្ថិតិបន្ថែម', 'Access additional statistics');
  String get vipPromotionBenefit => _v('ទទួលអាទិភាពផ្សព្វផ្សាយ', 'Priority promotion benefits');
  String get vipSupportBenefit => _v('ទទួលការគាំទ្រអាទិភាព', 'Priority support');
  String get vipPrice => _v('សូមពិនិត្យតម្លៃនៅទំព័រ VIP', 'See current price on the VIP page');
  String get notNow => _v('មិនទាន់ទេ', 'Not now');
  String get buyNow => _v('ទិញឥឡូវ', 'Buy now');
  String get professionalSeller => _v('អ្នកលក់អាជីព', 'Professional Seller');
  String get availableBalance => _v('សមតុល្យអាចប្រើបាន', 'Available balance');
  String get withdraw => _v('ដកប្រាក់', 'Withdraw');
  String get pendingBalance => _v('កំពុងរង់ចាំ', 'Pending');
  String get totalBalance => _v('សមតុល្យសរុប', 'Total balance');
  String get mySesanId => _v('Sesan ID របស់ខ្ញុំ', 'My Sesan ID');
  String get notAvailableYet => _v('មិនទាន់មាន', 'Not available yet');
  String get sesanIdHelp =>
      _v('លេខសម្គាល់តែមួយគត់សម្រាប់គណនីរបស់អ្នក', 'Your unique Sesan account ID');
  String get idCopied => _v('បានចម្លង ID', 'ID copied');
  String get create => _v('បង្កើត', 'Create');
  String get accountNotice => _v('សេចក្តីជូនដំណឹងគណនី', 'Account notice');
  String get frozenAccountMessage => _v(
        'គណនីនេះត្រូវបានផ្អាកជាបណ្ដោះអាសន្ន។ សូមទាក់ទង Sesan Support។',
        'This account is temporarily frozen. Please contact Sesan Support.',
      );
  String get ok => _v('យល់ព្រម', 'OK');
  String get createSesanIdTitle => _v('បង្កើត Sesan ID', 'Create Sesan ID');
  String get createSesanIdDescription => _v(
        'Sesan ID ជាលេខសម្គាល់តែមួយគត់សម្រាប់គណនីរបស់អ្នក។',
        'Sesan ID is a unique identifier for your account.',
      );
  String sesanIdCreated(String id) =>
      _v('បានបង្កើត Sesan ID: $id', 'Sesan ID created: $id');
  String errorMessage(String error) => _v('មានកំហុស: $error', 'Error: $error');

  String get sesan => 'Sesan';
  String get forKhmerFarmers =>
      _v('បច្ចេកវិទ្យាសម្រាប់កសិករខ្មែរ', 'Technology for Cambodian farmers');
  String get aboutLandTitle => _v('ដី និងកសិកម្ម', 'Land & Agriculture');
  String get aboutLandContent => _v(
        'Sesan ត្រូវបានបង្កើតឡើងដើម្បីជួយភ្ជាប់កសិករ អ្នកលក់ និងអ្នកទិញក្នុងទីផ្សារកសិកម្មឌីជីថល។',
        'Sesan was built to connect farmers, sellers, and buyers in a digital agricultural marketplace.',
      );
  String get aboutFarmersTitle => _v('សម្រាប់កសិករ', 'For Farmers');
  String get aboutFarmersContent => _v(
        'យើងចង់ឱ្យកសិករមានឧបករណ៍សាមញ្ញសម្រាប់លក់ ទិញ ស្វែងរកព័ត៌មាន និងគ្រប់គ្រងការងារ។',
        'We want farmers to have simple tools to sell, buy, find information, and manage their work.',
      );
  String get aboutWorkValueTitle => _v('តម្លៃការងារ', 'Our Values');
  String get aboutWorkValueContent => _v(
        'យើងផ្តោតលើភាពសាមញ្ញ តម្លាភាព និងការបង្កើតអត្ថប្រយោជន៍ពិតប្រាកដសម្រាប់សហគមន៍កសិកម្ម។',
        'We focus on simplicity, transparency, and practical value for the agricultural community.',
      );
  String get aboutMissionTitle => _v('បេសកកម្ម', 'Mission');
  String get aboutMissionContent => _v(
        'បេសកកម្មរបស់យើងគឺប្រើបច្ចេកវិទ្យាដើម្បីធ្វើឱ្យទីផ្សារ និងចំណេះដឹងកសិកម្មកាន់តែងាយស្រួលប្រើ។',
        'Our mission is to use technology to make agricultural markets and knowledge easier to access.',
      );
  String get aboutThanksTitle => _v('សូមអរគុណ', 'Thank you');
  String get aboutThanksContent => _v(
        'សូមអរគុណអ្នកប្រើប្រាស់ អ្នកលក់ កសិករ និងដៃគូទាំងអស់ដែលគាំទ្រ Sesan។',
        'Thank you to all users, sellers, farmers, and partners who support Sesan.',
      );
  String get aboutSlogan => _v(
        'រួមគ្នាបង្កើតអនាគតកសិកម្មឌីជីថលកម្ពុជា',
        'Building Cambodia’s digital agricultural future together',
      );
  String get aboutQuestion =>
      _v('ហេតុអ្វីបានជាយើងបង្កើត Sesan?', 'Why did we build Sesan?');
  String get aboutQuestionAnswer => _v(
        'ដើម្បីធ្វើឱ្យការទិញ លក់ និងចែករំលែកចំណេះដឹងកសិកម្មកាន់តែងាយស្រួល។',
        'To make buying, selling, and sharing agricultural knowledge easier.',
      );
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      locale.languageCode == 'km' || locale.languageCode == 'en';

  @override
  Future<AppLocalizations> load(Locale locale) =>
      SynchronousFuture<AppLocalizations>(
        AppLocalizations._(locale.languageCode),
      );

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
