import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';


class DigitalContractScreen extends StatefulWidget {
  const DigitalContractScreen({super.key});


  @override
  State<DigitalContractScreen> createState() => _DigitalContractScreenState();
}


class _DigitalContractScreenState extends State<DigitalContractScreen> {
  bool _showStamp = false;
  String _uid = ''; // ✅ បន្ថែម


  @override
  void initState() {
    super.initState();
    _loadUid(); // ✅ បន្ថែម
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) setState(() => _showStamp = true);
    });
  }


  // ✅ បន្ថែម function នេះ
  Future<void> _loadUid() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getString('user_uid') ?? '';
    if (mounted) setState(() => _uid = uid);
  }


  @override
  Widget build(BuildContext context) {
    // ✅ ប្រើ _uid ជំនួស FirebaseAuth
    if (_uid.isEmpty) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0E21),
        body: Center(child: CircularProgressIndicator()),
      );
    }


    final String uid = _uid; // ✅ ប្រើ _uid
    final String contractId = uid.length >= 8
        ? "SESAN-${uid.substring(0, 8).toUpperCase()}-${DateTime.now().year}"
        : "SESAN-INVESTOR-${DateTime.now().year}";


    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        title: const Text(
          "កិច្ចសន្យាវិនិយោគឌីជីថល",
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontFamily: 'Siemreap',
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('shareholders')
            .doc(uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.blueAccent),
            );
          }


          var data = snapshot.data!.data() as Map<String, dynamic>;
          String name = data['name'] ?? "អ្នកវិនិយោគ";
          int shares = data['total_shares'] ?? 0;
          double pricePerShare = 41000.0;
          double totalInvestment = shares * pricePerShare;
          String date = DateFormat('dd MMMM yyyy', 'km').format(DateTime.now());
          String idCard = data['id_card'] ?? "គ្មានព័ត៌មាន";


          return Stack(
            children: [
              // Watermark background
              Positioned.fill(
                child: Opacity(
                  opacity: 0.015,
                  child: Center(
                    child: Transform.rotate(
                      angle: -0.4,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.security, size: 250, color: Colors.white),
                          SizedBox(height: 20),
                          Text(
                            "SESAN\nCONFIDENTIAL",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 50,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),


              SingleChildScrollView(
                padding: const EdgeInsets.all(25),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Security Badge
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 25,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.green.withOpacity(0.2),
                              Colors.greenAccent.withOpacity(0.1),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(25),
                          border: Border.all(
                            color: Colors.greenAccent.withOpacity(0.4),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.verified_user,
                                color: Colors.greenAccent,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "កិច្ចសន្យាមានសុពលភាព",
                                  style: TextStyle(
                                    color: Colors.greenAccent,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Siemreap',
                                  ),
                                ),
                                Text(
                                  "ចុះបថ្ចីលេខ: $contractId",
                                  style: TextStyle(
                                    color: Colors.greenAccent.withOpacity(0.7),
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),


                    // ក្បាលលិខិត
                    Center(
                      child: Column(
                        children: [
                          const Text(
                            "ព្រះរាជាណាចក្រកម្ពុជា",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Colors.white,
                              fontFamily: 'Siemreap',
                              letterSpacing: 2,
                            ),
                          ),
                          const Text(
                            "ជាតិ សាសនា ព្រះមហាក្សត្រ",
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white70,
                              fontFamily: 'Siemreap',
                              letterSpacing: 3,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.blue.withOpacity(0.2),
                                  Colors.blueAccent.withOpacity(0.1),
                                ],
                              ),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.blueAccent.withOpacity(0.3),
                              ),
                            ),
                            child: const Icon(
                              Icons.waves,
                              size: 50,
                              color: Colors.blueAccent,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: Colors.blueAccent.withOpacity(0.5),
                                  width: 2,
                                ),
                              ),
                            ),
                            child: const Text(
                              "កិច្ចសន្យាវិនិយោគមូលធនភាគហ៊ុន",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: Colors.blueAccent,
                                fontFamily: 'Siemreap',
                              ),
                            ),
                          ),
                          const Text(
                            "(Digital Share Subscription Agreement)",
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white54,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          const SizedBox(height: 15),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 15,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              "លេខឯកសារ: $contractId\nកាលបរិច្ឆេទ: $date",
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.white54,
                                fontFamily: 'Siemreap',
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 35),


                    // ផ្នែកទី១: ភាគីពាក់ព័ន្ធ
                    _buildMainTitle("ផ្នែកទី១ ភាគីពាក់ព័ន្ធ (Parties)"),
                    const SizedBox(height: 15),


                    _buildSubTitle("ភាគី 'ក' - អ្នកវិនិយោគ (Investor)"),
                    _buildInfoBox([
                      _buildInfoRow("ឈ្មោះពេញ", name),
                      _buildInfoRow("លេខអត្តសញ្ញាណប័ណ្ណ", idCard),
                      _buildInfoRow("ភាគហ៊ុនដែលទិញ", "$shares ហ៊ុន"),
                      _buildInfoRow(
                        "តម្លៃក្នុងមួយហ៊ុន",
                        "${NumberFormat('#,###').format(pricePerShare)} រៀល",
                      ),
                      _buildInfoRow(
                        "ទឹកប្រាក់វិនិយោគសរុប",
                        "${NumberFormat('#,###').format(totalInvestment)} រៀល",
                      ),
                    ]),


                    const SizedBox(height: 15),
                    _buildSubTitle("ភាគី 'ខ' - ក្រុមហ៊ុន (Company)"),
                    _buildInfoBox([
                      _buildInfoRow("ឈ្មោះក្រុមហ៊ុន", "ក្រុមហ៊ុន SESAN ឯ.ក"),
                      _buildInfoRow(
                        "ប្រភេទក្រុមហ៊ុន",
                        "ក្រុមហ៊ុនវិនិយោគមូលធនភាគហ៊ុន",
                      ),
                      _buildInfoRow(
                        "តំណាងច្បាប់",
                        "លោក ក្លត ដៀន (នាយកប្រតិបត្តិ)",
                      ),
                      _buildInfoRow(
                        "អាសយដ្ឋាន",
                        "ភ្នំពេញ, ព្រះរាជាណាចក្រកម្ពុជា",
                      ),
                    ]),


                    const SizedBox(height: 25),


                    // ផ្នែកទី២: សេចក្ដីណែនាំ
                    _buildMainTitle("ផ្នែកទី២ សេចក្ដីណែនាំ (Preamble)"),
                    const SizedBox(height: 10),
                    _buildParagraph(
                      "កិច្ចសន្យានេះបានធ្វើឡើងនៅថ្ងៃទី $date រវាងភាគីទាំងពីរដែលបានរៀបរាប់ខាងលើ ដោយមានគោលបំណងកំណត់លក្ខខណ្ឌ និងល័ក្ខខ័ណ្ឌនៃការវិនិយោគភាគហ៊ុនក្នុងគម្រោងកសិកម្ម SESAN ដែលជាគម្រោងអភិវឌ្ឍន៍វិស័យកសិ-បច្ចេកវិទ្យាដ៏ទំនើបនៅព្រះរាជាណាចក្រកម្ពុជា។",
                    ),


                    const SizedBox(height: 25),


                    // ផ្នែកទី៣: ខ្លឹមសារកិច្ចសន្យា
                    _buildMainTitle(
                      "ផ្នែកទី៣ ខ្លឹមសារកិច្ចសន្យា (Terms & Conditions)",
                    ),
                    const SizedBox(height: 15),


                    _buildArticleTitle("ប្រការ ១. វត្ថុបំណងនៃកិច្ចសន្យា"),
                    _buildParagraph(
                      "ភាគី 'ក' បានយល់ព្រមជាគោលការណ៍ និងបានសម្រេចចិត្តវិនិយោគទិញភាគហ៊ុនចំនួន $shares ហ៊ុន នៃក្រុមហ៊ុន SESAN ឯ.ក ក្នុងតម្លៃ ${NumberFormat('#,###').format(pricePerShare)} រៀលក្នុងមួយហ៊ុន សរុបទឹកប្រាក់ ${NumberFormat('#,###').format(totalInvestment)} រៀល (ខ្មែរ៖ ${NumberFormat('#,###').format(totalInvestment)} រៀល)។ ភាគហ៊ុនទាំងនេះប្រគល់ជូនភាគី 'ក' ដោយស្របច្បាប់ និងមានសុពលភាពពេញលេញ។",
                    ),


                    const SizedBox(height: 15),
                    _buildArticleTitle("ប្រការ ២. ការទូទាត់ប្រាក់វិនិយោគ"),
                    _buildParagraph(
                      "២.១ ភាគី 'ក' បានធ្វើការទូទាត់ប្រាក់វិនិយោគពេញលេញរួចរាល់តាមរយៈប្រព័ន្ធទូទាត់ដែលក្រុមហ៊ុនបានកំណត់។\n"
                          "២.២ ការទូទាត់ប្រាក់ត្រូវបានគិតជាការទទួលខុសត្រូវចុងក្រោយ និងមិនអាចសងវិញបានឡើយ លើកលែងតែមានការយល់ព្រមជាលាយលក្ខណ៍អក្សរពីភាគីទាំងពីរ។\n"
                          "២.៣ ក្រុមហ៊ុននឹងចេញប័ណ្ណបញ្ជាក់ការទូទាត់ (Payment Receipt) ក្នុងរយៈពេល ៣ ថ្ងៃការងារបន្ទាប់ពីការទូទាត់ប្រាក់បានបញ្ចប់។",
                    ),


                    const SizedBox(height: 15),
                    _buildArticleTitle(
                      "ប្រការ ៣. សិទ្ធិ និងផលប្រយោជន៍របស់ភាគហ៊ុន",
                    ),
                    _buildParagraph(
                      "៣.១ ភាគី 'ក' មានសិទ្ធិទទួលបានភាគលាភ (Dividends) ប្រចាំឆមាស ឬប្រចាំឆ្នាំ តាមកាលកំណត់ដែលក្រុមហ៊ុនប្រកាស។\n"
                          "៣.២ ភាគី 'ក' មានសិទ្ធិចូលរួមប្រជុំភាគហ៊ុន និងបោះឆ្នោតតាមសម្បទានភាគហ៊ុនដែលខ្លួនមាន។\n"
                          "៣.៣ ភាគី 'ក' មានសិទ្ធិទទួលបានរបាយការណ៍ហិរញ្ញវត្ថុ និងព័ត៌មានប្រតិបត្តិការក្រុមហ៊ុនតាមរយៈ Digital Platform របស់ SESAN។\n"
                          "៣.៤ ភាគី 'ក' មិនមានសិទ្ធិចូលរួមក្នុងការគ្រប់គ្រងប្រចាំថ្ងៃរបស់ក្រុមហ៊ុនឡើយ លើកលែងតែត្រូវបានតែងតាំងជាសមាជិកក្រុមប្រឹក្សាភិបាល។",
                    ),


                    const SizedBox(height: 15),
                    _buildArticleTitle("ប្រការ ៤. កាតព្វកិច្ចរបស់ភាគី 'ក'"),
                    _buildParagraph(
                      "៤.១ ភាគី 'ក' ត្រូវគោរព និងអនុវត្តតាមច្បាប់ លិខិតបទដ្ឋានគតិយុត្ត និងបទបញ្ជាផ្ទៃក្នុងរបស់ក្រុមហ៊ុន។\n"
                          "៤.២ ភាគី 'ក' មិនត្រូវបង្ហាញព័ត៌មានសម្ងាត់របស់ក្រុមហ៊ុនដល់ភាគីទីបីឡើយ លើកលែងតែមានការអនុញ្ញាតជាលាយលក្ខណ៍អក្សរ។\n"
                          "៤.៣ ភាគី 'ក' ត្រូវធ្វើការទូទាត់ប្រាក់វិនិយោគបន្ថែម (ប្រសិនបើមាន) តាមកាលកំណត់ដែលបានព្រមព្រៀង។",
                    ),


                    const SizedBox(height: 15),
                    _buildArticleTitle("ប្រការ ៥. កាតព្វកិច្ចរបស់ភាគី 'ខ'"),
                    _buildParagraph(
                      "៥.១ ភាគី 'ខ' ត្រូវធានាថាភាគហ៊ុនដែលបានលក់ជូនភាគី 'ក' ជាភាគហ៊ុនស្របច្បាប់ និងមិនមានបញ្ហាជម្លោះផ្លូវច្បាប់ណាមួយឡើយ។\n"
                          "៥.២ ភាគី 'ខ' ត្រូវចេញប័ណ្ណបញ្ជាក់កម្មសិទ្ធិភាគហ៊ុន (Share Certificate) ជាលាយលក្ខណ៍ឌីជីថលក្នុងរយៈពេល ៧ ថ្ងៃការងារ។\n"
                          "៥.៣ ភាគី 'ខ' ត្រូវផ្តល់របាយការណ៍ហិរញ្ញវត្ថុប្រចាំត្រីមាសដល់ភាគី 'ក' តាមរយៈកម្មវិធីឌីជីថល។\n"
                          "៥.៤ ភាគី 'ខ' ត្រូវធានាថាទ្រព្យសម្បត្តិ និងប្រតិបត្តិការរបស់ក្រុមហ៊ុនត្រូវបានគ្រប់គ្រងដោយវិជ្ជាជីវៈ និងស្មារតីស្មោះត្រង់។",
                    ),


                    const SizedBox(height: 15),
                    _buildArticleTitle("ប្រការ ៦. ការផ្ទេរភាគហ៊ុន"),
                    _buildParagraph(
                      "៦.១ ភាគី 'ក' អាចធ្វើការផ្ទេរភាគហ៊ុនទៅភាគីទីបីបាន តែត្រូវបានក្រុមហ៊ុនយល់ព្រមជាលាយលក្ខណ៍អក្សរ និងបង់ថ្លៃសេវាផ្ទេរតាមការកំណត់។\n"
                          "៦.២ ការផ្ទេរភាគហ៊ុនត្រូវធ្វើឡើងតាមប្រព័ន្ធឌីជីថលរបស់ក្រុមហ៊ុន និងត្រូវបានកត់ត្រាក្នុងប្រព័ន្ធ Blockchain ដើម្បីធានាភាពត្រឹមត្រូវ។\n"
                          "៦.៣ ភាគី 'ក' មិនអាចធ្វើការដកភាគហ៊ុនវិញបានឡើយ លើកលែងតែមានការផ្តាច់ចោលកិច្ចសន្យាតាមលក្ខខណ្ឌខាងក្រោម។",
                    ),


                    const SizedBox(height: 15),
                    _buildArticleTitle("ប្រការ ៧. ការផ្តាច់ចោលកិច្ចសន្យា"),
                    _buildParagraph(
                      "៧.១ កិច្ចសន្យានេះអាចត្រូវបានផ្តាច់ចោលបានដោយភាពយល់ព្រមទៅវិញទៅមករវាងភាគីទាំងពីរ។\n"
                          "៧.២ ក្នុងករណីភាគី 'ក' បំពានល័ក្ខខ័ណ្ឌសំខាន់ៗនៃកិច្ចសន្យា ភាគី 'ខ' មិនអាចបង្ខំឲ្យភាគី 'ក' ទូទាត់ប្រាក់បន្ថែមបានឡើយ ប៉ុន្តែអាចពិចារណាលើការផ្តាច់ចោលកិច្ចសន្យា។\n"
                          "៧.៣ ក្នុងករណីភាគី 'ខ' បំពានល័ក្ខខ័ណ្ឌសំខាន់ៗ ភាគី 'ក' មានសិទ្ធិទាមទារសំណងខូចខាតតាមច្បាប់ជាធរមាន។",
                    ),


                    const SizedBox(height: 15),
                    _buildArticleTitle("ប្រការ ៨. ការដោះស្រាយវិវាទ"),
                    _buildParagraph(
                      "៨.១ ភាគីទាំងពីរត្រូវធ្វើការចរចាដោះស្រាយវិវាទដោយសន្តិវិធីជាមុនសិន។\n"
                          "៨.២ ប្រសិនបើការចរចាមិនបានសម្រេច ភាគីទាំងពីរយល់ព្រមឲ្យអាជ្ញាសវនាការសម្រេចចិត្តជាចុងក្រោយ។\n"
                          "៨.៣ អាជ្ញាសវនាការត្រូវបានជ្រើសរើសដោយភាពយល់ព្រមទៅវិញទៅមក ឬតាមការកំណត់ដោយក្រុមប្រឹក្សាភិបាលក្រុមហ៊ុន។",
                    ),


                    const SizedBox(height: 15),
                    _buildArticleTitle(
                      "ប្រការ ៩. កាលបរិច្ឆេទ និងការបន្តអនុវត្ត",
                    ),
                    _buildParagraph(
                      "៩.១ កិច្ចសន្យានេះមានសុពលភាពចាប់ពីថ្ងៃចុះហត្ថលេខា រហូតដល់ភាគីទាំងពីរបានព្រមព្រៀងផ្តាច់ចោល។\n"
                          "៩.២ កិច្ចសន្យានេះត្រូវបានធ្វើឡើងជា ២ ច្បាប់ ភាគីម្នាក់ៗទុក ១ ច្បាប់ ហើយមានតម្លៃស្មើគ្នា។\n"
                          "៩.៣ កិច្ចសន្យានេះត្រូវបានចារឹកទុកក្នុងប្រព័ន្ធ Blockchain ដើម្បីធានាភាពពិតប្រាកដ និងមិនអាចកែប្រែបាន។",
                    ),


                    const SizedBox(height: 15),
                    _buildArticleTitle("ប្រការ ១០. បទបញ្ជាផ្សេងៗ"),
                    _buildParagraph(
                      "១០.១ ភាគីទាំងពីរបានអាន យល់ព្រម និងយល់ដឹងពេញលេញអំពីលក្ខខណ្ឌទាំងអស់នៃកិច្ចសន្យានេះ។\n"
                          "១០.២ កិច្ចសន្យានេះត្រូវបានធ្វើឡើងដោយសេរីវិញ្ញាណ គ្មានការបង្ខិតបង្ខំ ឬបោកបញ្ឆោតណាមួយឡើយ។\n"
                          "១០.៣ ភាគីទាំងពីរយល់ព្រមថាកិច្ចសន្យានេះត្រូវបានចុះហត្ថលេខាជាលាយលក្ខណ៍ឌីជីថល ហើយមានសុពលភាពស្មើគ្នានឹងហត្ថលេខាដៃតាមច្បាប់ជាធរមាន។",
                    ),


                    const SizedBox(height: 35),


                    // ផ្នែកទី៤: ការយល់ព្រម
                    _buildMainTitle("ផ្នែកទី៤ ការយល់ព្រម (Acknowledgment)"),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: Colors.blueAccent.withOpacity(0.2),
                        ),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: Colors.greenAccent,
                            size: 40,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            "ខ្ញុំបាទ/នាងខ្ញុំ $name បានអាន យល់ព្រម និងយល់ដឹងពេញលេញអំពីលក្ខខណ្ឌ និងល័ក្ខខ័ណ្ឌទាំងអស់នៃកិច្ចសន្យានេះ។ ខ្ញុំបាទ/នាងខ្ញុំសន្យាថានឹងគោរព និងអនុវត្តតាមកិច្ចសន្យានេះជាធរមាន។",
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              height: 1.6,
                              fontFamily: 'Siemreap',
                            ),
                          ),
                        ],
                      ),
                    ),


                    const SizedBox(height: 35),


                    // QR Code Verification
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(25),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withOpacity(0.05),
                              Colors.white.withOpacity(0.02),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(25),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.1),
                          ),
                        ),
                        child: Column(
                          children: [
                            QrImageView(
                              data: contractId,
                              version: QrVersions.auto,
                              size: 180,
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF0A0E21),
                              embeddedImage: const AssetImage(
                                'assets/sesan_logo.png',
                              ),
                              embeddedImageStyle: const QrEmbeddedImageStyle(
                                size: Size(40, 40),
                              ),
                            ),
                            const SizedBox(height: 15),
                            const Text(
                              "សឺមីកូដផ្ទៀងផ្ទាត់សុពលភាព",
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontFamily: 'Siemreap',
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              contractId,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 10,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),


                    const SizedBox(height: 50),
                    // ហត្ថលេខា
                    Row(
                      children: [
                        Expanded(
                          child: _buildSignatureBlock(
                            "ភាគី 'ក'\nអ្នកវិនិយោគ",
                            name,
                            "ថ្ងៃទី $date",
                            Icons.fingerprint,
                            Colors.blueAccent,
                          ),
                        ),
                        const SizedBox(width: 25),
                        Expanded(
                          child: _buildSignatureBlock(
                            "ភាគី 'ខ'\nក្រុមហ៊ុន SESAN",
                            "លោក ក្លត ដៀន\nនាយកប្រតិបត្តិ",
                            "ថ្ងៃទី $date",
                            Icons.verified_user,
                            Colors.redAccent,
                          ),
                        ),
                      ],
                    ),


                    const SizedBox(height: 30),


                    // Footer
                    Center(
                      child: Column(
                        children: [
                          Divider(color: Colors.white.withOpacity(0.1)),
                          const SizedBox(height: 10),
                          Text(
                            "កិច្ចសន្យានេះត្រូវបានចុះហត្ថលេខាជាលាយលក្ខណ៍ឌីជីថល\nហើយបានចារឹកទុកក្នុងប្រព័ន្ធ Blockchain របស់ SESAN",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.3),
                              fontSize: 10,
                              height: 1.5,
                              fontFamily: 'Siemreap',
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            "© ${DateTime.now().year} SESAN Co., Ltd. រក្សាសិទ្ធិគ្រប់យ៉ាង",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.2),
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
                    ),


                    const SizedBox(height: 40),
                  ],
                ),
              ),


              // Official Stamp Animation
              if (_showStamp)
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.elasticOut,
                  right: 10,
                  bottom: 100,
                  child: AnimatedOpacity(
                    opacity: _showStamp ? 0.7 : 0,
                    duration: const Duration(milliseconds: 500),
                    child: Transform.rotate(
                      angle: -0.25,
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.red.withOpacity(0.6),
                            width: 3,
                          ),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.verified,
                              color: Colors.red.withOpacity(0.6),
                              size: 30,
                            ),
                            const SizedBox(height: 5),
                            Text(
                              "OFFICIAL\nAPPROVED\nSESAN",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.red.withOpacity(0.6),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }


  // Helper Widgets
  Widget _buildMainTitle(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.blueAccent.withOpacity(0.3),
            width: 1,
          ),
        ),
      ),
      child: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 15,
          color: Colors.blueAccent,
          fontFamily: 'Siemreap',
        ),
      ),
    );
  }


  Widget _buildSubTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 13,
          color: Colors.white,
          fontFamily: 'Siemreap',
        ),
      ),
    );
  }


  Widget _buildArticleTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 5),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.blueAccent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Colors.white,
                fontFamily: 'Siemreap',
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildInfoBox(List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }


  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              "$label:",
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 12,
                fontFamily: 'Siemreap',
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                fontFamily: 'Siemreap',
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildParagraph(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 14),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12.5,
          height: 1.8,
          color: Colors.white70,
          fontFamily: 'Siemreap',
        ),
      ),
    );
  }


  Widget _buildSignatureBlock(
      String title,
      String name,
      String date,
      IconData icon,
      Color color,
      ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.white70,
              fontFamily: 'Siemreap',
              height: 1.5,
            ),
          ),
          const SizedBox(height: 15),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 35),
          ),
          const SizedBox(height: 15),
          Text(
            name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: Colors.white,
              fontFamily: 'Siemreap',
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            date,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              color: Colors.white.withOpacity(0.5),
              fontFamily: 'Siemreap',
            ),
          ),
        ],
      ),
    );
  }
}



