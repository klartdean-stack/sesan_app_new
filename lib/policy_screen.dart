import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';


class PolicyScreen extends StatefulWidget {
  const PolicyScreen({super.key});


  @override
  State<PolicyScreen> createState() => _PolicyScreenState();
}


class _PolicyScreenState extends State<PolicyScreen> {
  bool _isAgreed = false;
  bool _hasReadAll = false;
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = true;
  bool _alreadyAccepted = false;


  List<Map<String, dynamic>> _sections = [];
  List<Map<String, dynamic>> _filteredSections = [];
  final TextEditingController _searchController = TextEditingController();


  final Color _primaryGreen = const Color(0xFF2E7D32);
  final Color _lightGreen = const Color(0xFF4CAF50);
  final Color _accentYellow = const Color(0xFFFFC107);
  final Color _bgWhite = Colors.white;
  final Color _bgCream = const Color(0xFFF5F5DC);
  final Color _textDark = const Color(0xFF1B5E20);


  static const _currentVersion = '2026.04.21';

  bool get _isEnglish =>
      Localizations.localeOf(context).languageCode == 'en';

  String _t(String km, String en) => _isEnglish ? en : km;

  static const List<String> _englishTitles = [
    'Acceptance of the agreement and legal validity',
    'Protection of financial transactions',
    'Service fees and payment conditions',
    'Seller responsibilities and legal penalties',
    'Data privacy and dispute resolution',
    'Logistics and delivery risks',
    'Control of information and market prices',
    'Account suspension and penalties',
    'Intellectual property and platform identity',
    'Force majeure',
    'Anti-money laundering and unlawful activity',
    'Amendments and validity of provisions',
    'Digital records and evidence',
    'Invalid transactions',
    'Product-quality disclaimer',
    'Auction conditions',
  ];

  static const List<String> _englishContents = [
    'Accessing Sesan or placing an order constitutes legal acceptance of this electronic agreement.\n\n• Users must comply with every stated condition.\n• Users remain legally responsible for violations.\n• Continued use after an update constitutes acceptance of the updated terms.',
    'For payment security and fraud prevention, customers must use the Sesan cart and the payment methods provided inside the app.\n\n• Transaction funds are kept in a protected system.\n• A customer may file a complaint and request a hold within 4 days when an item materially differs from its listing.\n• Sesan is not responsible for losses or disputes arising from transactions completed outside the platform.',
    '• Standard fee: Sesan deducts a 7% management fee from orders completed through the cart.\n• Zero-fee option: sellers of high-value products may disable the cart and arrange a direct purchase.\n• A grey cart button means online checkout is disabled; contact the seller by chat.\n• Platform payments remain pending for 5 days.\n• If no complaint is filed during the first 4 days, funds become available to the seller on day 6.\n• Cancelled payments are refunded after applicable administrative charges.',
    '• Sellers must provide accurate product information and deliver the quality advertised.\n• False information or fabricated evidence is a serious violation.\n• Sesan may permanently suspend an account and refer conduct for action under applicable Cambodian civil and criminal law.',
    '• Personal information is kept confidential and handled according to applicable privacy requirements.\n• Sesan Admin reviews platform disputes using transaction records and submitted evidence.\n• Users may still exercise any rights available to them under Cambodian law.',
    '• Delivery time, cost and method must be clearly agreed by the buyer and seller.\n• Responsibility for loss or damage follows the selected delivery arrangement and available evidence.\n• Buyers should inspect the parcel promptly and report a problem within the complaint period.',
    '• Sesan may moderate, correct or remove misleading, unlawful or harmful listings.\n• Sellers remain responsible for their own prices and product claims.\n• Manipulation of prices, reviews or platform data is prohibited.',
    '• Sesan may temporarily freeze an account or transaction while investigating fraud, abuse, chargebacks or policy violations.\n• Serious or repeated violations may lead to permanent suspension and financial or legal consequences.\n• Users may contact support and provide evidence for review.',
    '• Users may upload only content they own or are legally allowed to use.\n• Copying another person’s images, text, trademarks or other protected work is prohibited.\n• The Sesan name and marks may not be used to mislead the public or obtain unauthorized benefit.',
    'Sesan is not liable for failure or delay caused by events outside reasonable control, including natural disasters, armed conflict, major power or telecommunications outages, cyberattacks, epidemics or national emergencies. Sesan will notify users where practical and work to restore service promptly.',
    '• Sesan wallets and services must not be used for money laundering, terrorist financing or any unlawful activity.\n• Suspicious accounts may be suspended immediately and reported to competent authorities.\n• Sesan will cooperate with a lawful official investigation.',
    '• Sesan may amend these terms when necessary and notify users through the app, notification or email.\n• Continued use after an amendment constitutes acceptance of the new terms.\n• If one provision is invalid, the remaining provisions continue in full force.',
    '• Product photos, parcel-opening videos, chat history and transaction records may be used as digital evidence in a dispute.\n• Delivery staff and recipients are encouraged to record the handover.\n• Clear digital evidence will be considered during dispute resolution.',
    '• Admin may invalidate a fraudulent transaction or one that exploits the platform.\n• A refund may be issued to the buyer, less applicable administrative charges, within 7 working days.\n• A fraudulent seller remains responsible for the amount, fees and resulting losses.',
    'Sesan provides a marketplace and transaction-facilitation service. It does not independently guarantee the quality, safety or legality of products posted by sellers. Product-related loss remains a matter between buyer and seller under applicable law, although Sesan may assist with dispute resolution.',
    '• A confirmed bid cannot be withdrawn.\n• The winner must pay within 24 hours after the auction ends or the result may be cancelled.\n• Auction listing fees—15,000 KHR for 48 hours or 25,000 KHR for Premium 72 hours—are non-refundable.\n• Admin may remove an auction that violates policy without refunding the listing fee.\n• The seller and winner must coordinate payment and delivery within the required time.',
  ];

  List<Map<String, dynamic>> get _localizedSections {
    if (!_isEnglish) return _sections;
    return List.generate(_sections.length, (index) {
      final section = Map<String, dynamic>.from(_sections[index]);
      section['number'] = '${index + 1}';
      section['title'] = _englishTitles[index];
      section['content'] = _englishContents[index];
      return section;
    });
  }


  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _checkPreviousAcceptance();
    _initializeSections();
  }


  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }


  void _initializeSections() {
    _sections = [
      {
        'number': '១',
        'title': 'ការទទួលស្គាល់កិច្ចសន្យា និងសុពលភាពនីតិកម្ម',
        'content':
        'រាល់ការចូលប្រើប្រាស់ ឬប្រតិបត្តិការបញ្ជាទិញតាមរយៈ'
            'កម្មវិធី សេសាន (Sesan) ត្រូវបានចាត់ទុកជាការបង្ហាញ'
            'ឆន្ទៈយល់ព្រមដោយស្របច្បាប់ នូវរាល់បទប្បញ្ញត្តិ'
            'នៃកិច្ចសន្យាអេឡិចត្រូនិចនេះ។\n\n'
            '• អ្នកប្រើប្រាស់មានកាតព្វកិច្ចអនុវត្តតាម'
            'លក្ខខណ្ឌដែលបានកំណត់ទាំងអស់។\n'
            '• មិនអាចបដិសេធទំនួលខុសត្រូវតាមផ្លូវច្បាប់'
            'ក្នុងករណីមានការរំលោភបំពានឡើយ។\n'
            '• ការប្រើប្រាស់កម្មវិធីបន្តបន្ទាប់ ចាត់ទុកថា'
            'ជាការយល់ព្រមចំពោះការកែប្រែណាមួយ'
            'ដែលកើតមានក្រោយពេលនោះ។',
        'icon': Icons.gavel,
      },
      {
        'number': '២',
        'title': 'យន្តការការពារប្រតិបត្តិការហិរញ្ញវត្ថុ',
        'content':
        'ដើម្បីធានាសុវត្ថិភាពប្រាក់ និងការពារហានិភ័យ'
            'នៃការបោកប្រាស់ កម្មវិធី សេសាន តម្រូវឱ្យ'
            'អតិថិជនប្រតិបត្តិការតាមរយៈ "កន្ត្រកទំនិញ" '
            'និងប្រព័ន្ធទូទាត់មជ្ឈការរបស់កម្មវិធីតែប៉ុណ្ណោះ។\n\n'
            '• ការធានាសុវត្ថិភាព៖ ប្រាក់ប្រតិបត្តិការ'
            'នឹងត្រូវរក្សាទុកក្នុងប្រព័ន្ធបច្ចេកវិទ្យា'
            'ដែលមានសុវត្ថិភាពកម្រិតខ្ពស់។\n'
            '• សិទ្ធិដាក់ពាក្យបណ្ដឹង៖ អតិថិជនមានសិទ្ធិ'
            'ដាក់ពាក្យបណ្ដឹងបង្កកប្រាក់ក្នុងរយៈពេល ០៤ ថ្ងៃ '
            'ប្រសិនបើទំនិញខុសពីលក្ខណៈបច្ចេកទេស'
            'ដែលបានប្រកាស។\n'
            '• ការលើកលែងទំនួលខុសត្រូវ៖ សេសាន មិន'
            'ទទួលខុសត្រូវចំពោះការបាត់បង់ ឬជម្លោះ'
            'ដែលកើតចេញពីការទិញដូរក្រៅប្រព័ន្ធឡើយ។',
        'icon': Icons.account_balance_wallet,
      },
      {
        'number': '៣',
        'title': 'គោលការណ៍កម្រៃសេវា និងលក្ខខណ្ឌទូទាត់',
        'content':
        '• កម្រៃសេវាស្តង់ដារ៖ ប្រព័ន្ធនឹងកាត់កម្រៃសេវាគ្រប់គ្រងចំនួន ៧% នៃតម្លៃប្រតិបត្តិការសរុប សម្រាប់ការទិញតាមកន្ត្រក់។\n'
            '• ការរួចកម្រៃសេវា (០%)៖ ចំពោះទំនិញតម្លៃខ្ពស់ (ត្រាក់ទ័រ, ដ្រូន...) អ្នកលក់អាចប្រើមុខងារ "បិទកន្ត្រក់" ដើម្បីចៀសវាងការកាត់កម្រៃ ៧%។\n'
            '• ការបញ្ជាទិញ៖ ប្រសិនបើប៊ូតុងកន្ត្រក់មាន "ពណ៌ប្រផេះ" មានន័យថាអ្នកលក់បានបិទការទិញតាមប្រព័ន្ធ។ សូមចុចលើប៊ូតុង "ឆាត" ដើម្បីទាក់ទងទិញដោយផ្ទាល់។\n'
            '• ស្ថានភាពរង់ចាំ (Pending)៖ សម្រាប់ការទិញតាមប្រព័ន្ធ ប្រាក់នឹងត្រូវរក្សាទុកក្នុងស្ថានភាពរង់ចាំរយៈពេល ០៥ ថ្ងៃជាដាច់ខាត។\n'
            '• ការអនុម័តប្រាក់៖ បើគ្មានបណ្ដឹងក្នុងរយៈពេល ០៤ ថ្ងៃដំបូង ប្រាក់នឹងផ្ទេរចូលកាបូបលុយអ្នកលក់នៅថ្ងៃទី ០៦។\n'
            '• ការបង្វិលប្រាក់៖ ករណីបោះបង់ ប្រាក់នឹងបង្វិលក្រោយការកាត់កម្រៃរដ្ឋបាល។',
        'icon': Icons.payments,
      },
      {
        'number': '៤',
        'title': 'ទំនួលខុសត្រូវរបស់អ្នកលក់ និងទណ្ឌកម្មតាមផ្លូវច្បាប់',
        'content':
        '• កាតព្វកិច្ច៖ អ្នកលក់ត្រូវធានាភាពត្រឹមត្រូវ'
            'នៃព័ត៌មានទំនិញ និងគុណភាពស្របតាមស្ដង់ដារ'
            'ដែលបានប្រកាស។\n'
            '• ការដាក់ទណ្ឌកម្ម៖ ការផ្ដល់ព័ត៌មានមិនពិត '
            'ឬភស្តុតាងក្លែងក្លាយ ជាបទល្មើសធ្ងន់ធ្ងរ។\n'
            '• សេសាន រក្សាសិទ្ធិបិទគណនីជាអចិន្ត្រៃយ៍ '
            'និងចាត់វិធានការតាមក្រមរដ្ឋប្បវេណី '
            'និងក្រមព្រហ្មទណ្ឌជាធរមាន'
            'នៃព្រះរាជាណាចក្រកម្ពុជា។',
        'icon': Icons.assignment_ind,
      },
      {
        'number': '៥',
        'title': 'ឯកជនភាពទិន្នន័យ និងយន្តការដោះស្រាយជម្លោះ',
        'content':
        '• ការការពារទិន្នន័យ៖ ព័ត៌មានផ្ទាល់ខ្លួន'
            'ត្រូវបានរក្សាជាការសម្ងាត់ ស្របតាមច្បាប់'
            'ស្ដីពីការការពារទិន្នន័យផ្ទាល់ខ្លួន។\n'
            '• យន្តការដោះស្រាយជម្លោះ៖ រាល់ជម្លោះ'
            'ដែលកើតឡើងក្នុងប្រព័ន្ធ ការសម្រេចរបស់'
            'រដ្ឋបាល សេសាន គឺជាយន្តការដោះស្រាយ'
            'បឋមជាដាច់ខាត។\n'
            '• ករណីមិនអាចដោះស្រាយបាន ជម្លោះនឹង'
            'ត្រូវបញ្ជូនទៅដោះស្រាយតាមនីតិវិធីច្បាប់'
            'ជាធរមាននៃព្រះរាជាណាចក្រកម្ពុជា។',
        'icon': Icons.security,
      },
      {
        'number': '៦',
        'title': 'ភស្តុភារកម្ម និងហានិភ័យដឹកជញ្ជូន',
        'content':
        '• ការវេចខ្ចប់៖ អ្នកលក់មានកាតព្វកិច្ច'
            'រៀបចំការវេចខ្ចប់ឱ្យបានត្រឹមត្រូវ'
            'តាមបច្ចេកទេស។ ការខូចខាតដោយសារ'
            'ការវេចខ្ចប់មិនត្រឹមត្រូវ ជាបន្ទុក'
            'របស់អ្នកលក់ទាំងស្រុង។\n'
            '• ភស្តុតាងបញ្ជាក់៖ អ្នកដឹកជញ្ជូន'
            'ត្រូវថតរូបភាពទុកជាភស្តុតាង នៅពេល'
            'ប្រគល់ទំនិញដល់អតិថិជន ដើម្បីការពារ'
            'ការបដិសេធថាមិនបានទទួល។\n'
            '• ហានិភ័យ៖ ហានិភ័យបាត់បង់ ឬខូចខាត'
            'ទំនិញក្នុងពេលដឹកជញ្ជូន ជាការទទួល'
            'ខុសត្រូវរបស់ភាគីដឹកជញ្ជូន លុះត្រាតែ'
            'មានភស្តុតាងផ្ទុយ។',
        'icon': Icons.local_shipping,
      },
      {
        'number': '៧',
        'title': 'អំណាចគ្រប់គ្រងព័ត៌មាន និងតម្លៃទីផ្សារ',
        'content':
        '• ការគ្រប់គ្រងតម្លៃ៖ កម្មវិធី សេសាន '
            'រក្សាសិទ្ធិក្នុងការស្នើឱ្យកែសម្រួលតម្លៃ '
            'ប្រសិនបើឃើញថាមានការបំប៉ោងតម្លៃ'
            'ខុសពីតម្លៃទីផ្សារពិតប្រាកដ។\n'
            '• ការដកចេញផលិតផល៖ រដ្ឋបាលមានសិទ្ធិ'
            'ដកចេញ ឬបិទផលិតផលណាដែលខុសច្បាប់ '
            'ដោយមិនត្រូវជូនដំណឹងជាមុន។\n'
            '• ព័ត៌មានមិនពិត៖ ផលិតផលណាដែលបង្ហោះ'
            'ព័ត៌មានមិនត្រឹមត្រូវ នឹងត្រូវដកចេញភ្លាម '
            'ហើយម្ចាស់ទំនិញអាចត្រូវដាក់ទណ្ឌកម្ម។',
        'icon': Icons.admin_panel_settings,
      },
      {
        'number': '៨',
        'title': 'វិធានការបង្កកគណនី និងការផាកពិន័យ',
        'content':
        '• វិធានការបង្កក៖ ក្នុងករណីមានពាក្យបណ្ដឹង'
            'ជម្លោះដែលមិនទាន់ដោះស្រាយ រដ្ឋបាលមានសិទ្ធិ'
            'បង្កកប្រាក់ក្នុងកាបូបលុយ'
            'របស់អ្នកលក់ជាបណ្ដោះអាសន្ន។\n'
            '• ទណ្ឌកម្មហិរញ្ញវត្ថុ៖ ការព្យាយាម'
            'បោកប្រាស់ ០៣ ដងឡើងទៅ នឹងត្រូវ'
            'ប្រឈមនឹងការផាកពិន័យ ឬការដកឈ្មោះ'
            'ចេញពីវេទិកាជាអចិន្ត្រៃយ៍។\n'
            '• ការប្ដឹងទៅតុលាការ៖ ក្នុងករណីជម្លោះ'
            'ធ្ងន់ធ្ងរ សេសាន រក្សាសិទ្ធិប្ដឹងទៅ'
            'តុលាការដើម្បីស្វែងរកសំណង'
            'តាមផ្លូវច្បាប់។',
        'icon': Icons.block,
      },
      {
        'number': '៩',
        'title': 'ការការពារកម្មសិទ្ធិបញ្ញា និងអត្តសញ្ញាណវេទិកា',
        'content':
        '• សិទ្ធិរូបភាព៖ អ្នកលក់ត្រូវប្រើតែរូបភាព'
            'ដែលជាកម្មសិទ្ធិស្របច្បាប់របស់ខ្លួន។ '
            'ការប្រើរូបភាពរបស់អ្នកដទៃ'
            'ដោយគ្មានការអនុញ្ញាត ជាការរំលោភ'
            'បំពានកម្មសិទ្ធិបញ្ញា។\n'
            '• ការការពារម៉ាកសញ្ញា៖ ហាមដាច់ខាត'
            'ការប្រើប្រាស់ឈ្មោះ ឬសញ្ញាសម្គាល់ '
            '"សេសាន" ក្នុងគោលបំណងកេងចំណេញ '
            'ឬធ្វើឱ្យសាធារណជនយល់ច្រឡំ។',
        'icon': Icons.copyright,
      },
      {
        'number': '១០',
        'title': 'ករណីប្រធានស័ក្តិ​ (Force Majeure)',
        'content':
        'សេសាន ត្រូវបានលើកលែងទំនួលខុសត្រូវ'
            'ចំពោះការខកខានកាតព្វកិច្ចដែលបណ្ដាល'
            'មកពីហេតុការណ៍ក្រៅពីការគ្រប់គ្រង'
            'ដូចជា៖\n\n'
            '• គ្រោះធម្មជាតិ (ព្យុះ ទឹកជំនន់ ភ្លើងឆេះ)\n'
            '• ជម្លោះប្រដាប់អាវុធ ឬបះបោរ\n'
            '• ការដាច់ចរន្តអគ្គិសនីឬ'
            'បណ្ដាញទូរគមនាគមន៍ជាស្ថាប័ន\n'
            '• ការវាយប្រហារតាមប្រព័ន្ធព័ត៌មានវិទ្យា\n'
            '• ជំងឺឆ្លងដ៏ធ្ងន់ធ្ងរ ឬគ្រោះអនាម័យជាតិ\n\n'
            'ក្នុងករណីទាំងនេះ សេសាន នឹងជូនដំណឹង'
            'ដល់អ្នកប្រើប្រាស់ ហើយព្យាយាមស្ដារ'
            'សេវាកម្មឱ្យបានឆាប់រហ័ស។',
        'icon': Icons.warning_amber,
      },
      {
        'number': '១១',
        'title': 'ការប្រឆាំងការលាងប្រាក់ និងសកម្មភាពខុសច្បាប់',
        'content':
        '• ការទប់ស្កាត់បទល្មើស៖ ហាមឃាត់'
            'ការប្រើប្រាស់កាបូបលុយក្នុងកម្មវិធី'
            'សម្រាប់សកម្មភាពលាងប្រាក់ '
            'ហិរញ្ញប្បទានភេរវករ ឬ'
            'សកម្មភាពខុសច្បាប់ណាមួយ។\n'
            '• ការរាយការណ៍៖ គណនីណាដែលត្រូវ'
            'បានសង្ស័យ នឹងត្រូវផ្អាកភ្លាម '
            'ហើយព័ត៌មានបានប្រគល់ជូន'
            'អាជ្ញាធរមានសមត្ថកិច្ច។\n'
            '• ការសហការផ្នែកច្បាប់៖ សេសាន '
            'នឹងផ្ដល់ព័ត៌មានពេញលេញ'
            'ដល់អាជ្ញាធរ ក្នុងករណីមាន'
            'ការស៊ើបអង្កេតផ្លូវការ។',
        'icon': Icons.shield,
      },
      {
        'number': '១២',
        'title': 'សិទ្ធិធ្វើវិសោធនកម្ម និងសុពលភាពបទប្បញ្ញត្តិ',
        'content':
        '• វិសោធនកម្ម៖ កម្មវិធី សេសាន '
            'រក្សាសិទ្ធិក្នុងការកែប្រែ ឬ'
            'បន្ថែមបទប្បញ្ញត្តិនៃលក្ខខណ្ឌនេះ'
            'តាមការចាំបាច់ ដោយជូនដំណឹង'
            'តាមរយៈ notification ឬ email ។\n'
            '• ការយល់ព្រមបន្ត៖ ការប្រើប្រាស់'
            'កម្មវិធីបន្តបន្ទាប់ ក្រោយការកែប្រែ '
            'ចាត់ទុកថាជាការយល់ព្រម'
            'ចំពោះវិសោធនកម្មថ្មី'
            'ដោយគ្មានលក្ខខណ្ឌ។\n'
            '• សុពលភាព៖ ប្រសិនបើបទប្បញ្ញត្តិ'
            'ណាមួយត្រូវបានកំណត់ថាមោឃ '
            'បទប្បញ្ញត្តិដែលនៅសល់'
            'នៅតែមានសុពលភាពពេញលេញ។',
        'icon': Icons.edit_note,
      },
      {
        'number': '១៣',
        'title': 'ភស្តុតាងឌីជីថល និងភស្តុតាងសក្ខីកម្ម',
        'content':
        '• ភស្តុតាងឌីជីថល៖ រូបភាពផលិតផល '
            'វីដេអូពេលបើកកញ្ចប់ ប្រវត្តិ chat '
            'ប្រវត្តិប្រតិបត្តិការ ត្រូវបានចាត់ទុក'
            'ជាភស្តុតាងសក្ខីកម្មស្របច្បាប់'
            'ក្នុងការដោះស្រាយជម្លោះ។\n'
            '• ការថតរូប៖ អ្នកដឹកជញ្ជូន'
            'និងអ្នកទទួលទំនិញ ត្រូវបាន'
            'លើកទឹកចិត្តឱ្យថតរូបភាព'
            'ទុកជាភស្តុតាង ក្នុងអំឡុងពេល'
            'ផ្ទេរទំនិញ។\n'
            '• ការច្រានចោលភស្តុតាង៖ '
            'ការបដិសេធចំពោះភស្តុតាង'
            'ឌីជីថលដែលច្បាស់លាស់ '
            'នឹងមិនត្រូវបានទទួលស្គាល់'
            'ក្នុងដំណើរការដោះស្រាយជម្លោះឡើយ។',
        'icon': Icons.camera_alt,
      },
      {
        'number': '១៤',
        'title': 'លក្ខខណ្ឌមោឃភាពនៃប្រតិបត្តិការ',
        'content':
        '• ការប្រកាសមោឃភាព៖ រដ្ឋបាលមានសិទ្ធិ'
            'ប្រកាសមោឃភាពលើប្រតិបត្តិការណា'
            'ដែលមានការបោកប្រាស់ '
            'ឬកេងចំណេញប្រព័ន្ធ។\n'
            '• ការបង្វិលប្រាក់៖ ប្រាក់នឹងត្រូវ'
            'បង្វិលជូនអ្នកទិញ ក្រោយការកាត់'
            'កម្រៃរដ្ឋបាល ក្នុងរយៈពេល'
            '០៧ ថ្ងៃធ្វើការ។\n'
            '• ករណីអ្នកលក់មានការក្លែងបន្លំ '
            'អ្នកលក់ត្រូវទទួលខុសត្រូវបង់ប្រាក់'
            'ទាំងអស់ រួមទាំងកម្រៃ '
            'និងការខូចខាតផ្សេងៗ'
            'ដែលបានកើតឡើង។',
        'icon': Icons.cancel,
      },
      {
        'number': '១៥',
        'title': 'ការបដិសេធការធានាគុណភាពទំនិញ',
        'content':
        'កម្មវិធី សេសាន ដើរតួជាវេទិកា'
            'សម្របសម្រួលប្រតិបត្តិការប៉ុណ្ណោះ '
            'ហើយ មិនផ្ដល់ការធានាលើ'
            'គុណភាព សុវត្ថិភាព ឬភាពស្របច្បាប់'
            'នៃទំនិញដែលបង្ហោះ'
            'ដោយអ្នកលក់ឡើយ។\n\n'
            '• រាល់ការខូចខាត ឬផលវិបាក'
            'ដែលកើតចេញពីការប្រើប្រាស់ផលិតផល '
            'ជាទំនួលខុសត្រូវផ្ទាល់'
            'រវាងអ្នកទិញ និងអ្នកលក់ '
            'ស្របតាម'
            'ក្រមរដ្ឋប្បវេណីជាធរមាន។\n'
            '• សេសាន នឹងដើរតួជាអន្ទាញ'
            'ក្នុងការជួយដោះស្រាយជម្លោះ '
            'ប៉ុន្តែមិនទទួលខុសត្រូវ'
            'ដោយផ្ទាល់ចំពោះគុណភាព'
            'នៃការពិពណ៌នាទំនិញឡើយ។',
        'icon': Icons.info_outline,
      },
      {
        'number': '១៦',
        'title': 'លក្ខខណ្ឌការដេញថ្លៃ (Auction)',
        'content':
        '• ការដេញថ្លៃមិនអាចដកវិញបានទេ '
            'នៅពេលដែលបានចុច'
            'បញ្ជាក់ការដេញថ្លៃរួច។\n'
            '• អ្នកឈ្នះត្រូវបង់ប្រាក់'
            'ក្នុងរយៈពេល ២៤ ម៉ោង '
            'បន្ទាប់ពីការដេញថ្លៃបានបញ្ចប់ '
            'បើមិនដូច្នោះ ការដេញថ្លៃ'
            'នឹងត្រូវលុបចោល។\n'
            '• ថ្លៃសេវាដាក់ auction '
            '១៥,០០០ ៛ (កញ្ចប់ធម្មតា ៤៨ ម៉ោង) '
            'និង ២៥,០០០ ៛ (Premium ៧២ ម៉ោង) '
            'មិនអាចបង្វិលវិញបានទេ។\n'
            '• Admin រក្សាសិទ្ធិលុប auction '
            'ណាដែលរំលោភគោលការណ៍ '
            'ដោយមិនជូនដំណឹងជាមុន '
            'ហើយថ្លៃសេវានឹងមិន'
            'ត្រូវបានបង្វិលឡើយ។\n'
            '• ម្ចាស់ទំនិញ និងអ្នកឈ្នះ'
            'ត្រូវទំនាក់ទំនងគ្នា'
            'ដើម្បីរៀបចំការទូទាត់'
            'ក្នុងរយៈពេលកំណត់។',
        'icon': Icons.gavel,
      },
    ];
    _filteredSections = List.from(_sections);
    setState(() => _isLoading = false);
  }


  void _onScroll() {
    if (_scrollController.offset >=
        _scrollController.position.maxScrollExtent - 100) {
      if (!_hasReadAll) setState(() => _hasReadAll = true);
    }
  }


  Future<void> _checkPreviousAcceptance() async {
    final prefs = await SharedPreferences.getInstance();
    final accepted = prefs.getBool('policy_accepted') ?? false;
    final acceptedDate = prefs.getString('policy_accepted_date');
    final acceptedVersion = prefs.getString('policy_version') ?? '';


    if (accepted &&
        acceptedDate != null &&
        acceptedVersion == _currentVersion) {
      final diff = DateTime.now()
          .difference(DateTime.parse(acceptedDate))
          .inDays;
      if (diff < 30) {
        setState(() => _alreadyAccepted = true);
        if (mounted) {
          Future.delayed(
            const Duration(seconds: 1),
                () => Navigator.pop(context),
          );
        }
      }
    }
  }


  void _filterSections(String query) {
    setState(() {
      _filteredSections = _localizedSections
          .where(
            (s) =>
        s['title'].toString().contains(query) ||
            s['content'].toString().contains(query),
      )
          .toList();
    });
  }


  @override
  Widget build(BuildContext context) {
    if (_isLoading) return _buildShimmer();
    if (_alreadyAccepted) return _buildAlreadyAccepted();


    return Scaffold(
      backgroundColor: _bgCream,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            height: 4,
            child: LinearProgressIndicator(
              value: _hasReadAll ? 1.0 : 0.3,
              backgroundColor: Colors.green.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation<Color>(_lightGreen),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 16),
                  _buildWarningCard(),
                  const SizedBox(height: 20),
                  ...(_searchController.text.isEmpty
                          ? _localizedSections
                          : _filteredSections)
                      .map(_buildSectionCard),
                  const SizedBox(height: 20),
                  _buildFooter(),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
          _buildAgreementSection(),
        ],
      ),
    );
  }


  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _primaryGreen,
      elevation: 0,
      centerTitle: true,
      iconTheme: const IconThemeData(color: Colors.white),
      title: Text(
        _t('គោលការណ៍ និងលក្ខខណ្ឌច្បាប់', 'Policies and legal terms'),
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          fontFamily: 'Siemreap',
          color: Colors.white,
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(58),
        child: Container(
          color: _primaryGreen.withOpacity(0.9),
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
          child: TextField(
            controller: _searchController,
            onChanged: _filterSections,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: _t('ស្វែងរកប្រការ...', 'Search terms...'),
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
              prefixIcon: Icon(
                Icons.search,
                color: Colors.white.withOpacity(0.7),
              ),
              filled: true,
              fillColor: Colors.white.withOpacity(0.15),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 15,
                vertical: 10,
              ),
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildHeader() {
    return Center(
      child: Column(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: Colors.green.withOpacity(
              0.1,
            ), // រក្សាពណ៌បៃតងខ្ចីដដែល
            child: const Icon(
              Icons.balance, // នេះគឺជា Icon ជញ្ជីង
              size: 40,
              color: Colors.green, // ពណ៌បៃតងឱ្យស៊ីជាមួយ Theme របស់មេ
            ),
          ),
          const SizedBox(height: 14),
          Text(
            _t('លក្ខខណ្ឌប្រើប្រាស់ និងកិច្ចសន្យាផ្លូវច្បាប់', 'Terms of use and legal agreement'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: _primaryGreen,
              fontFamily: 'Siemreap',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _t('សេសាន (Sesan) — កសិ-បច្ចេកវិទ្យា', 'Sesan — Agricultural technology'),
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
        ],
      ),
    );
  }


  Widget _buildWarningCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _accentYellow.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _accentYellow.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _accentYellow.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.warning_amber, color: _accentYellow, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _t('ចំណាំសំខាន់', 'Important notice'),
                  style: TextStyle(
                    color: Colors.orange[800],
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    fontFamily: 'Siemreap',
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _t(
                    'សូមអានប្រការទាំង ១៦ ឱ្យចប់ មុនពេលចុចយល់ព្រម។ ការយល់ព្រមមានសុពលភាពតាមច្បាប់ជាធរមានរបស់ព្រះរាជាណាចក្រកម្ពុជា។',
                    'Please read all 16 sections before accepting. Your acceptance has legal effect under the applicable laws of Cambodia.',
                  ),
                  style: TextStyle(
                    color: Colors.orange[700],
                    fontSize: 11,
                    height: 1.5,
                    fontFamily: 'Siemreap',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildSectionCard(Map<String, dynamic> section) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _bgWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ExpansionTile(
        iconColor: _lightGreen,
        collapsedIconColor: Colors.grey[400],
        leading: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            section['icon'] as IconData,
            color: _lightGreen,
            size: 19,
          ),
        ),
        title: Text(
          _t('ប្រការ ${section['number']}', 'Section ${section['number']}'),
          style: TextStyle(color: Colors.grey[500], fontSize: 11),
        ),
        subtitle: Text(
          section['title'],
          style: TextStyle(
            color: _textDark,
            fontWeight: FontWeight.bold,
            fontSize: 13,
            fontFamily: 'Siemreap',
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Text(
              section['content'],
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 13,
                height: 1.8,
                fontFamily: 'Siemreap',
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildFooter() {
    return Center(
      child: Column(
        children: [
          Container(height: 1, color: Colors.green.withOpacity(0.2)),
          const SizedBox(height: 14),
          Text(
            _t('ធ្វើបច្ចុប្បន្នភាពចុងក្រោយ៖ ថ្ងៃទី ២១ ខែមេសា ឆ្នាំ ២០២៦', 'Last updated: 21 April 2026'),
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            _t('© 2026 Sesan Agriculture. រក្សាសិទ្ធិគ្រប់យ៉ាង', '© 2026 Sesan Agriculture. All rights reserved.'),
            style: TextStyle(color: Colors.grey[400], fontSize: 11),
          ),
        ],
      ),
    );
  }


  Widget _buildAgreementSection() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      decoration: BoxDecoration(
        color: _bgWhite,
        border: Border(top: BorderSide(color: Colors.green.withOpacity(0.2))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!_hasReadAll)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _accentYellow.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.keyboard_double_arrow_down_rounded,
                      color: Colors.orange[700],
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _t('សូមរំកិលអានឱ្យចប់មុនពេលយល់ព្រម', 'Scroll to the end before accepting'),
                      style: TextStyle(
                        color: Colors.orange[700],
                        fontSize: 11,
                        fontFamily: 'Siemreap',
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                Checkbox(
                  value: _isAgreed,
                  onChanged: _hasReadAll
                      ? (v) => setState(() => _isAgreed = v!)
                      : null,
                  activeColor: _lightGreen,
                  checkColor: Colors.white,
                  side: BorderSide(
                    color: _hasReadAll ? _lightGreen : Colors.grey.shade300,
                  ),
                ),
                Expanded(
                  child: Text(
                    _t(
                      'ខ្ញុំបានអាន និងយល់ព្រមលើប្រការទាំង ១៦ ហើយទទួលស្គាល់ទំនួលខុសត្រូវស្របតាមច្បាប់ជាធរមាន។',
                      'I have read and accept all 16 sections and acknowledge my responsibilities under applicable law.',
                    ),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: _hasReadAll ? Colors.black87 : Colors.grey[400],
                      fontFamily: 'Siemreap',
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isAgreed ? _lightGreen : Colors.grey[300],
                  foregroundColor: _isAgreed ? Colors.white : Colors.grey[500],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: _isAgreed ? 3 : 0,
                ),
                onPressed: _isAgreed ? _acceptPolicy : null,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _isAgreed
                          ? Icons.check_circle_outline_rounded
                          : Icons.lock_outline_rounded,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _t('បញ្ជាក់ការយល់ព្រម', 'Accept and continue'),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        fontFamily: 'Siemreap',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


  Future<void> _acceptPolicy() async {
    try {
      // ✅ ទាញ UID ពី SharedPreferences ជាមុនសិន
      final prefs = await SharedPreferences.getInstance();
      String? uid = prefs.getString('user_uid');

      // ✅ ប្រសិនបើគ្មានក្នុង SharedPreferences ទើបប្រើ FirebaseAuth
      if (uid == null || uid.isEmpty) {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          uid = user.uid;
        }
      }

      // ✅ ប្រសិនបើនៅតែគ្មាន UID ទេ បង្ហាញ Error
      if (uid == null || uid.isEmpty) {
        throw Exception(_t('មិនអាចកំណត់អត្តសញ្ញាណអ្នកប្រើប្រាស់បានទេ។ សូមចូលប្រើប្រាស់គណនីឡើងវិញ។', 'Could not identify your account. Please sign in again.'));
      }

      final now = DateTime.now();

      // ✅ ប្រើ UID ដែលទាញបាន
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({
        'has_accepted_terms': true,
        'accepted_date': Timestamp.fromDate(now),
        'policy_version': _currentVersion,
      });

      await prefs.setBool('policy_accepted', true);
      await prefs.setString('policy_accepted_date', now.toIso8601String());
      await prefs.setString('policy_version', _currentVersion);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: _lightGreen,
            content: Text(
              _t('✅ បានយល់ព្រមដោយជោគជ័យ!', '✅ Terms accepted successfully!'),
              style: const TextStyle(fontFamily: 'Siemreap'),
            ),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text(
              '${_t('❌ មានបញ្ហា', '❌ Error')}: $e',
              style: const TextStyle(fontFamily: 'Siemreap'),
            ),
          ),
        );
      }
    }
  }


  Widget _buildShimmer() {
    return Scaffold(
      backgroundColor: _bgCream,
      body: Shimmer.fromColors(
        baseColor: Colors.green.withOpacity(0.1),
        highlightColor: Colors.green.withOpacity(0.25),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 60),
              Container(
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView.builder(
                  itemCount: 6,
                  itemBuilder: (_, __) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildAlreadyAccepted() {
    return Scaffold(
      backgroundColor: _bgCream,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_rounded, color: _lightGreen, size: 64),
            const SizedBox(height: 20),
            Text(
              _t('អ្នកបានយល់ព្រម\nលើលក្ខខណ្ឌរួចរាល់ហើយ', 'You have already accepted\nthese terms'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _primaryGreen,
                fontSize: 16,
                fontFamily: 'Siemreap',
                height: 1.6,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _t('កំពុងបញ្ជូនទៅទំព័របន្ទាប់...', 'Taking you to the next page...'),
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}



