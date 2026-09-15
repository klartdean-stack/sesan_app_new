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
  bool _isAgreed = false, _hasReadAll = false, _isLoading = true, _alreadyAccepted = false;
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _sections = [], _filteredSections = [];
  final _primaryGreen = const Color(0xFF2E7D32), _lightGreen = const Color(0xFF4CAF50), _accentYellow = const Color(0xFFFFC107), _bgCream = const Color(0xFFF5F5DC);
  static const _currentVersion = '2026.08.29';
  bool get _isEnglish => Localizations.localeOf(context).languageCode == 'en';
  String _t(String km, String en) => _isEnglish ? en : km;

  static const _kmTitles = [
    'ការទទួលស្គាល់កិច្ចសន្យា និងសុពលភាពនីតិកម្ម','យន្តការការពារប្រតិបត្តិការហិរញ្ញវត្ថុ','គោលការណ៍កម្រៃសេវា និងលក្ខខណ្ឌទូទាត់','ទំនួលខុសត្រូវរបស់អ្នកលក់ និងទណ្ឌកម្មតាមផ្លូវច្បាប់','ឯកជនភាពទិន្នន័យ និងយន្តការដោះស្រាយជម្លោះ','ភស្តុភារកម្ម និងហានិភ័យដឹកជញ្ជូន','អំណាចគ្រប់គ្រងព័ត៌មាន និងតម្លៃទីផ្សារ','វិធានការបង្កកគណនី និងការផាកពិន័យ','ការការពារកម្មសិទ្ធិបញ្ញា និងអត្តសញ្ញាណវេទិកា','ករណីប្រធានស័ក្តិ (Force Majeure)','ការប្រឆាំងការលាងប្រាក់ និងសកម្មភាពខុសច្បាប់','សិទ្ធិធ្វើវិសោធនកម្ម និងសុពលភាពបទប្បញ្ញត្តិ','ភស្តុតាងឌីជីថល និងភស្តុតាងសក្ខីកម្ម','លក្ខខណ្ឌមោឃភាពនៃប្រតិបត្តិការ','ការបដិសេធការធានាគុណភាពទំនិញ','លក្ខខណ្ឌការដេញថ្លៃ (Auction)','ទំនិញ និងសកម្មភាពហាមឃាត់'];
  static const _enTitles = ['Acceptance of the agreement and legal validity','Protection of financial transactions','Service fees and payment conditions','Seller responsibilities and legal penalties','Data privacy and dispute resolution','Logistics and delivery risks','Control of information and market prices','Account suspension and penalties','Intellectual property and platform identity','Force majeure','Anti-money laundering and unlawful activity','Amendments and validity of provisions','Digital records and evidence','Invalid transactions','Product-quality disclaimer','Auction conditions','Prohibited and unlawful products'];
  static const _kmContents = [
    'ការចូលប្រើ Sesan ឬការបញ្ជាទិញ គឺជាការយល់ព្រមលើកិច្ចសន្យាអេឡិចត្រូនិចនេះ។ អ្នកប្រើប្រាស់ត្រូវគោរពលក្ខខណ្ឌ និងទទួលខុសត្រូវចំពោះការរំលោភ។',
    'ដើម្បីការពារប្រាក់ និងការបោកប្រាស់ អតិថិជនគួរប្រើកន្ត្រក និងវិធីទូទាត់ក្នុងកម្មវិធី។ អាចដាក់បណ្ដឹងស្នើបង្កកប្រាក់ក្នុង ៤ ថ្ងៃ ប្រសិនបើទំនិញខុសពីការប្រកាស។',
    'កម្រៃសេវាស្តង់ដារ ៧% សម្រាប់ការទិញតាមកន្ត្រក។ អ្នកលក់ទំនិញតម្លៃខ្ពស់អាចបិទកន្ត្រក និងលក់ផ្ទាល់។ ប្រាក់ក្នុងប្រព័ន្ធរង់ចាំ ៥ ថ្ងៃ ហើយបើគ្មានបណ្ដឹង នឹងអាចប្រើបាននៅថ្ងៃទី ៦។',
    'អ្នកលក់ត្រូវផ្ដល់ព័ត៌មានត្រឹមត្រូវ និងទំនិញស្របតាមការប្រកាស។ ព័ត៌មាន ឬភស្តុតាងក្លែងក្លាយអាចនាំឱ្យបិទគណនី និងចាត់វិធានការតាមច្បាប់។',
    'ព័ត៌មានផ្ទាល់ខ្លួនត្រូវរក្សាជាសម្ងាត់។ Admin អាចពិនិត្យជម្លោះដោយផ្អែកលើប្រវត្តិប្រតិបត្តិការ និងភស្តុតាង ហើយអ្នកប្រើនៅតែមានសិទ្ធិតាមច្បាប់កម្ពុជា។',
    'អ្នកទិញ និងអ្នកលក់ត្រូវព្រមព្រៀងពេលវេលា តម្លៃ និងវិធីដឹកជញ្ជូន។ ការទទួលខុសត្រូវលើការខូចខាតអាស្រ័យលើការរៀបចំដឹកជញ្ជូន និងភស្តុតាង។',
    'Sesan អាចកែ ឬលុបការបង្ហោះបំភាន់ ខុសច្បាប់ ឬបង្កគ្រោះថ្នាក់។ អ្នកលក់ទទួលខុសត្រូវលើតម្លៃ និងការអះអាងរបស់ខ្លួន។',
    'Sesan អាចបង្កកគណនី ឬប្រតិបត្តិការជាបណ្ដោះអាសន្នពេលស៊ើបអង្កេតការបោកប្រាស់ ការរំលោភ ឬបណ្ដឹង។ ករណីធ្ងន់ធ្ងរ ឬកើតឡើងញឹកញាប់អាចបិទជាអចិន្ត្រៃយ៍។',
    'អ្នកប្រើអាចបង្ហោះតែខ្លឹមសារដែលខ្លួនមានសិទ្ធិប្រើ។ ហាមចម្លងរូបភាព អត្ថបទ ម៉ាក ឬកម្មសិទ្ធិបញ្ញារបស់អ្នកដទៃដោយគ្មានសិទ្ធិ។',
    'Sesan មិនទទួលខុសត្រូវចំពោះការខកខានដោយហេតុការណ៍ក្រៅការគ្រប់គ្រង ដូចជា គ្រោះធម្មជាតិ ជម្លោះប្រដាប់អាវុធ ការដាច់បណ្ដាញ ការវាយប្រហារសាយប័រ ឬអាសន្នជាតិ។',
    'ហាមប្រើកាបូប និងសេវា Sesan សម្រាប់លាងប្រាក់ ហិរញ្ញប្បទានភេរវកម្ម ឬសកម្មភាពខុសច្បាប់។ គណនីសង្ស័យអាចត្រូវផ្អាក និងរាយការណ៍ទៅអាជ្ញាធរ។',
    'Sesan អាចកែប្រែលក្ខខណ្ឌពេលចាំបាច់ និងជូនដំណឹងតាមកម្មវិធី notification ឬ email។ ការបន្តប្រើក្រោយការកែប្រែ គឺជាការយល់ព្រមលើលក្ខខណ្ឌថ្មី។',
    'រូបភាពផលិតផល វីដេអូបើកកញ្ចប់ ប្រវត្តិ chat និងប្រវត្តិប្រតិបត្តិការ អាចប្រើជាភស្តុតាងឌីជីថលក្នុងការដោះស្រាយជម្លោះ។',
    'Admin អាចប្រកាសមោឃភាពប្រតិបត្តិការបោកប្រាស់ ឬកេងប្រព័ន្ធ។ ប្រាក់អាចបង្វិលជូនអ្នកទិញក្រោយកាត់កម្រៃរដ្ឋបាលក្នុង ៧ ថ្ងៃធ្វើការ។',
    'Sesan ជាវេទិកាសម្របសម្រួលទីផ្សារ និងមិនធានាដោយផ្ទាល់លើគុណភាព សុវត្ថិភាព ឬភាពស្របច្បាប់នៃទំនិញរបស់អ្នកលក់ឡើយ ប៉ុន្តែអាចជួយដោះស្រាយជម្លោះ។',
    'ការដេញថ្លៃដែលបានបញ្ជាក់មិនអាចដកវិញ។ អ្នកឈ្នះត្រូវបង់ក្នុង ២៤ ម៉ោង។ ថ្លៃដាក់ Auction ១៥,០០០៛ សម្រាប់ ៤៨ ម៉ោង ឬ Premium ២៥,០០០៛ សម្រាប់ ៧២ ម៉ោង មិនអាចបង្វិលវិញ។ Admin អាចលុប Auction ដែលរំលោភគោលការណ៍។',
    'ហាមបង្ហោះ ផ្សព្វផ្សាយ ទិញ លក់ ឬជួញដូរទំនិញខុសច្បាប់ រួមមានសត្វព្រៃការពារ អាវុធ គ្រាប់រំសេវ គ្រឿងផ្ទុះ គ្រឿងញៀន ទំនិញលួច ទំនិញក្លែងក្លាយ និងសារធាតុគីមីហាមឃាត់។ Sesan អាចលុបការបង្ហោះ ផ្អាកគណនី រក្សាភស្តុតាង និងរាយការណ៍ទៅអាជ្ញាធរ។'];
  static const _enContents = [
    'Accessing Sesan or placing an order constitutes acceptance of this electronic agreement. Users must comply with the terms and remain responsible for violations.',
    'For payment security and fraud prevention, customers should use the Sesan cart and in-app payment methods. A complaint and hold may be requested within 4 days when an item materially differs from its listing.',
    'Standard cart orders carry a 7% management fee. Sellers of high-value products may disable the cart and arrange a direct purchase. Platform payments remain pending for 5 days and become available on day 6 if no complaint is filed.',
    'Sellers must provide accurate product information and deliver the advertised quality. False information or fabricated evidence may lead to permanent suspension and legal action.',
    'Personal information is kept confidential. Admin may review disputes using transaction records and evidence, while users retain rights available under Cambodian law.',
    'Buyer and seller must clearly agree on delivery time, cost and method. Responsibility for loss or damage follows the selected arrangement and available evidence.',
    'Sesan may moderate, correct or remove misleading, unlawful or harmful listings. Sellers remain responsible for their prices and product claims.',
    'Sesan may temporarily freeze an account or transaction while investigating fraud, abuse or complaints. Serious or repeated violations may lead to permanent suspension.',
    'Users may upload only content they own or are legally allowed to use. Unauthorized copying of images, text, trademarks or other protected work is prohibited.',
    'Sesan is not liable for failure or delay caused by events outside reasonable control, including natural disasters, armed conflict, major outages, cyberattacks or national emergencies.',
    'Sesan services must not be used for money laundering, terrorist financing or unlawful activity. Suspicious accounts may be suspended and reported to competent authorities.',
    'Sesan may amend these terms when necessary and notify users through the app, notification or email. Continued use after an amendment constitutes acceptance.',
    'Product photos, parcel-opening videos, chat history and transaction records may be used as digital evidence in a dispute.',
    'Admin may invalidate fraudulent transactions or transactions that exploit the platform. A refund may be issued less applicable administrative charges within 7 working days.',
    'Sesan provides a marketplace and transaction-facilitation service and does not independently guarantee seller product quality, safety or legality, although it may assist with dispute resolution.',
    'A confirmed bid cannot be withdrawn. The winner must pay within 24 hours. Auction fees are 15,000 KHR for 48 hours or 25,000 KHR for Premium 72 hours and are non-refundable. Admin may remove auctions that violate policy.',
    'Users must not post, advertise, buy, sell or trade unlawful products, including protected wildlife, weapons, ammunition, explosives, narcotics, stolen or counterfeit goods and banned chemicals. Sesan may remove listings, suspend accounts, preserve evidence and report suspected violations.'];

  @override void initState(){super.initState();_scrollController.addListener(_onScroll);_checkPreviousAcceptance();_initializeSections();}
  @override void dispose(){_scrollController.dispose();_searchController.dispose();super.dispose();}
  void _initializeSections(){_sections=List.generate(17,(i)=>{'number':'${i+1}','titleKm':_kmTitles[i],'titleEn':_enTitles[i],'contentKm':_kmContents[i],'contentEn':_enContents[i],'icon': i==15?Icons.gavel:i==16?Icons.block:Icons.policy_outlined});_filteredSections=List.from(_sections);_isLoading=false;}
  void _onScroll(){if(_scrollController.hasClients&&_scrollController.offset>=_scrollController.position.maxScrollExtent-100&&!_hasReadAll)setState(()=>_hasReadAll=true);}
  Future<void> _checkPreviousAcceptance() async {final p=await SharedPreferences.getInstance();final d=p.getString('policy_accepted_date');if((p.getBool('policy_accepted')??false)&&d!=null&&p.getString('policy_version')==_currentVersion&&DateTime.now().difference(DateTime.parse(d)).inDays<30){if(mounted)setState(()=>_alreadyAccepted=true);}}
  void _filterSections(String q){final s=q.toLowerCase();setState(()=>_filteredSections=_sections.where((e)=>e['titleKm'].toString().toLowerCase().contains(s)||e['titleEn'].toString().toLowerCase().contains(s)||e['contentKm'].toString().toLowerCase().contains(s)||e['contentEn'].toString().toLowerCase().contains(s)).toList());}

  @override Widget build(BuildContext context){if(_isLoading)return _shimmer();if(_alreadyAccepted)return Scaffold(appBar:AppBar(title:Text(_t('គោលការណ៍','Policy'))),body:Center(child:Text(_t('អ្នកបានយល់ព្រមលើលក្ខខណ្ឌរួចរាល់ហើយ','You have already accepted these terms'))));final list=_searchController.text.isEmpty?_sections:_filteredSections;return Scaffold(backgroundColor:_bgCream,appBar:AppBar(backgroundColor:_primaryGreen,foregroundColor:Colors.white,title:Text(_t('គោលការណ៍ និងលក្ខខណ្ឌច្បាប់','Policies and legal terms')),bottom:PreferredSize(preferredSize:const Size.fromHeight(58),child:Padding(padding:const EdgeInsets.fromLTRB(16,0,16,10),child:TextField(controller:_searchController,onChanged:_filterSections,decoration:InputDecoration(hintText:_t('ស្វែងរកប្រការ...','Search terms...'),filled:true,fillColor:Colors.white,border:OutlineInputBorder(borderRadius:BorderRadius.circular(12),borderSide:BorderSide.none))))),body:Column(children:[Expanded(child:SingleChildScrollView(controller:_scrollController,padding:const EdgeInsets.all(16),child:Column(children:[Container(padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:_accentYellow.withOpacity(.12),borderRadius:BorderRadius.circular(12)),child:Text(_t('សូមអានប្រការទាំង ១៧ ឱ្យចប់ មុនពេលចុចយល់ព្រម។','Please read all 17 sections before accepting.'))),const SizedBox(height:12),...list.map(_section),const SizedBox(height:20)]))),_agreement()]));}
  Widget _section(Map<String,dynamic> s)=>Card(child:ExpansionTile(leading:Icon(s['icon'] as IconData,color:_lightGreen),title:Text(_t('ប្រការ ${s['number']}','Section ${s['number']}')),subtitle:Text(_isEnglish?s['titleEn']:s['titleKm'],style:const TextStyle(fontWeight:FontWeight.bold)),children:[Padding(padding:const EdgeInsets.all(16),child:Text(_isEnglish?s['contentEn']:s['contentKm'],style:const TextStyle(height:1.6))) ]));
  Widget _agreement()=>SafeArea(top:false,child:Container(color:Colors.white,padding:const EdgeInsets.all(14),child:Column(mainAxisSize:MainAxisSize.min,children:[CheckboxListTile(contentPadding:EdgeInsets.zero,value:_isAgreed,onChanged:_hasReadAll?(v)=>setState(()=>_isAgreed=v??false):null,title:Text(_t('ខ្ញុំបានអាន និងយល់ព្រមលើប្រការទាំង ១៧','I have read and accept all 17 sections'))),SizedBox(width:double.infinity,child:ElevatedButton(onPressed:_isAgreed?_acceptPolicy:null,child:Text(_t('បញ្ជាក់ការយល់ព្រម','Accept and continue'))))])));
  Future<void> _acceptPolicy() async {try{final p=await SharedPreferences.getInstance();String? uid=p.getString('user_uid');uid=(uid==null||uid.isEmpty)?FirebaseAuth.instance.currentUser?.uid:uid;if(uid==null||uid.isEmpty)throw Exception(_t('សូមចូលគណនីឡើងវិញ','Please sign in again'));final now=DateTime.now();await FirebaseFirestore.instance.collection('users').doc(uid).update({'has_accepted_terms':true,'accepted_date':Timestamp.fromDate(now),'policy_version':_currentVersion});await p.setBool('policy_accepted',true);await p.setString('policy_accepted_date',now.toIso8601String());await p.setString('policy_version',_currentVersion);if(mounted)Navigator.pop(context,true);}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('${_t('មានបញ្ហា','Error')}: $e')));}}
  Widget _shimmer()=>Scaffold(backgroundColor:_bgCream,body:Shimmer.fromColors(baseColor:Colors.green.shade100,highlightColor:Colors.green.shade50,child:ListView.builder(padding:const EdgeInsets.all(20),itemCount:7,itemBuilder:(_,__)=>Container(height:80,margin:const EdgeInsets.only(bottom:12),color:Colors.white))));
}
