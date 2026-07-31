import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:image_picker/image_picker.dart';
import 'package:my_app/admin_stock_management.dart';
import 'package:my_app/admin_transfer_requests_screen.dart';
import 'package:my_app/download_helper.dart';
import 'package:my_app/investment_terms_screen.dart';
import 'package:my_app/investor_dashboard_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';


class InvestmentPitchScreen extends StatefulWidget {
  const InvestmentPitchScreen({super.key});


  @override
  State<InvestmentPitchScreen> createState() => _InvestmentPitchScreenState();
}


class _InvestmentPitchScreenState extends State<InvestmentPitchScreen> {
  int currentPriceFromFirebase = 41000;
  File? _receiptImage;
  final _formKey = GlobalKey<FormState>();
  final formatter = NumberFormat('#,###');


  final nameController = TextEditingController();
  final shareController = TextEditingController();
  final idController = TextEditingController();
  final phoneController = TextEditingController();
  final addressController = TextEditingController();
  final bankAccController = TextEditingController();


  bool _isSubmitting = false;


  @override
  void dispose() {
    nameController.dispose();
    shareController.dispose();
    idController.dispose();
    phoneController.dispose();
    addressController.dispose();
    bankAccController.dispose();
    super.dispose();
  }


  Future<bool> _isAdmin() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;


      // ឆែកមើល ID Admin របស់មេ
      const String adminUid = "WBdQVvrgEIPBTcgIlumu6bAZGUl2";


      if (user.uid == adminUid) {
        return true;
      }


      return false;
    } catch (e) {
      debugPrint("Error checking admin: $e");
      return false;
    }
  }


  Future<String?> _uploadImage(File image) async {
    try {
      String fileName =
          'receipts/${DateTime.now().millisecondsSinceEpoch}_${FirebaseAuth.instance.currentUser?.uid}.png';
      Reference ref = FirebaseStorage.instance.ref().child(fileName);
      await ref.putFile(image);
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint("Upload error: $e");
      return null;
    }
  }


  Future<void> _saveToFirestore(Map<String, dynamic> data) async {
    await FirebaseFirestore.instance
        .collection('investment_requests')
        .add(data);
  }


  Future<Map<String, List<int>>> _fetchMonthlyData() async {
    final currentYear = DateTime.now().year;
    List<int> uMonthly = List.filled(12, 0);
    List<int> pMonthly = List.filled(12, 0);
    List<int> oMonthly = List.filled(12, 0);


    try {
      final results = await Future.wait([
        FirebaseFirestore.instance.collection('users').get(),
        FirebaseFirestore.instance.collection('products').get(),
        FirebaseFirestore.instance.collection('orders').get(),
      ]);


      // ១. សម្រាប់ Collection users (ប្រើ Key: createdAt)
      for (var doc in results[0].docs) {
        var data = doc.data() as Map<String, dynamic>;
        // ដូរពី timestamp មក createdAt តាមរូបមេ
        DateTime? date = data['createdAt']?.toDate();
        if (date != null && date.year == currentYear) {
          uMonthly[date.month - 1]++;
        }
      }


      // ២. សម្រាប់ Collection products (ប្រើ Key: created_at)
      for (var doc in results[1].docs) {
        var data = doc.data() as Map<String, dynamic>;
        // ដូរមក created_at
        DateTime? date = data['created_at']?.toDate();
        if (date != null && date.year == currentYear) {
          pMonthly[date.month - 1]++;
        }
      }


      // ៣. សម្រាប់ Collection orders (ប្រើ Key: created_at)
      for (var doc in results[2].docs) {
        var data = doc.data() as Map<String, dynamic>;
        // ដូរមក created_at
        DateTime? date = data['created_at']?.toDate();
        if (date != null && date.year == currentYear) {
          oMonthly[date.month - 1]++;
        }
      }


      return {'users': uMonthly, 'products': pMonthly, 'orders': oMonthly};
    } catch (e) {
      debugPrint("Error fetching graph data: $e");
      return {'users': uMonthly, 'products': pMonthly, 'orders': oMonthly};
    }
  }


  void _clearForm() {
    nameController.clear();
    shareController.clear();
    idController.clear();
    phoneController.clear();
    addressController.clear();
    bankAccController.clear();
    setState(() => _receiptImage = null);
  }


  // បង្កើត Stream សម្រាប់ auth state
  Stream<bool> get _adminStream {
    return FirebaseAuth.instance.authStateChanges().asyncMap((user) async {
      if (user == null) return false;
      const String adminUid = "WBdQVvrgEIPBTcgIlumu6bAZGUl2";
      return user.uid == adminUid;
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F121F),
      appBar: AppBar(
        title: const Text(
          "SESAN INVESTMENT",
          style: TextStyle(
            letterSpacing: 2,
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // ✅ StreamBuilder តែមួយគត់ - លុប FutureBuilder ចាស់ចេញ
          StreamBuilder<bool>(
            stream: _adminStream,
            initialData: false,
            builder: (context, snapshot) {
              // Loading state
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  width: 40,
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.redAccent,
                      ),
                    ),
                  ),
                );
              }


              // ប្រសិនបើ admin → បង្ហាញ button
              if (snapshot.data == true) {
                return PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.admin_panel_settings,
                    color: Colors.redAccent,
                  ),
                  onSelected: (value) {
                    if (value == 'stock') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AdminStockManagement(),
                        ),
                      );
                    } else if (value == 'transfers') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AdminTransferRequestsScreen(),
                        ),
                      );
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'stock',
                      child: Row(
                        children: [
                          Icon(
                            Icons.inventory_2,
                            color: Colors.redAccent,
                            size: 20,
                          ),
                          SizedBox(width: 10),
                          Text("គ្រប់គ្រងភាគហ៊ុន"),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'transfers',
                      child: Row(
                        children: [
                          Icon(
                            Icons.swap_horiz,
                            color: Colors.redAccent,
                            size: 20,
                          ),
                          SizedBox(width: 10),
                          Text("សំណើផ្ទេរ"),
                        ],
                      ),
                    ),
                  ],
                );
              }


              // មិនមែន admin → មិនបង្ហាញអ្វី
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            _buildDashboardButton(),
            const SizedBox(height: 20),
            _buildProjectInfoCard(),
            const SizedBox(height: 25),
            _buildInvestmentHeader(),
            const SizedBox(height: 20),
            _buildPriceChart(),
            const SizedBox(height: 30),
            _buildStockStats(),
            const SizedBox(height: 25),
            _buildTrustIndicators(),
            const SizedBox(height: 25),
            _buildRiskWarning(),
            const SizedBox(height: 25),
            _buildInvestmentTerms(),
            const SizedBox(height: 30),
            _buildMainActionButton(context),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }


  Widget _buildDashboardButton() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.amber.withOpacity(0.1),
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: const BorderSide(color: Colors.amber, width: 1),
          ),
          elevation: 0,
        ),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const InvestorDashboardScreen()),
          );
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.dashboard_customize_rounded, color: Colors.amber),
            SizedBox(width: 10),
            Text(
              "ទៅកាន់ Investor Dashboard",
              style: TextStyle(
                color: Colors.amber,
                fontWeight: FontWeight.bold,
                fontSize: 15,
                fontFamily: 'Siemreap',
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildProjectInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.blue.withOpacity(0.2),
            Colors.purple.withOpacity(0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.shopping_bag,
                  color: Colors.blueAccent,
                  size: 28,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "SESAN E-Commerce Platform",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        fontFamily: 'Siemreap',
                      ),
                    ),
                    Text(
                      "វេទិកាពាណិជ្ជកម្មឌីជីថលនៅកម្ពុជា",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 12,
                        fontFamily: 'Siemreap',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          _buildProjectStat("🛒 អ្នកលក់ (Sellers)", "...ហាង"),
          _buildProjectStat("👥 អ្នកប្រើប្រាស់", "...នាក់"),
          _buildProjectStat("📦 ការបញ្ជាទិញ/ខែ", "....ការបញ្ជា"),
          _buildProjectStat("📈 កំណើនប្រចាំឆ្នាំ", "...%"),
          _buildProjectStat("🏆 ពានរង្វាន់", "...2025"),
        ],
      ),
    );
  }


  Widget _buildProjectStat(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 12,
              fontFamily: 'Siemreap',
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              color: Colors.greenAccent,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildInvestmentHeader() {
    return Column(
      children: [
        const Text(
          "តម្លៃក្នុង ១ ហ៊ុនបច្ចុប្បន្ន",
          style: TextStyle(
            color: Colors.grey,
            fontSize: 13,
            fontFamily: 'Siemreap',
          ),
        ),
        StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('app_equity_stats')
              .doc('current')
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 35,
                child: Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.greenAccent,
                  ),
                ),
              );
            }


            int currentPrice = 41000;
            if (snapshot.hasData && snapshot.data!.exists) {
              var data = snapshot.data!.data() as Map<String, dynamic>?;
              currentPrice = data?['price_per_share'] ?? 41000;
              currentPriceFromFirebase = currentPrice;
            }


            return Column(
              children: [
                Text(
                  "${formatter.format(currentPrice)} ៛",
                  style: const TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 35,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (snapshot.hasData &&
                    (snapshot.data!.data()
                    as Map<String, dynamic>)?['price_change'] !=
                        null)
                  Text(
                    "${(snapshot.data!.data() as Map<String, dynamic>)['price_change'] > 0 ? '+' : ''}${(snapshot.data!.data() as Map<String, dynamic>)['price_change']}% សប្ដាហ៍នេះ",
                    style: TextStyle(
                      color:
                      ((snapshot.data!.data()
                      as Map<
                          String,
                          dynamic
                      >)['price_change'] ??
                          0) >=
                          0
                          ? Colors.greenAccent
                          : Colors.redAccent,
                      fontSize: 12,
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 5),
        Text(
          "Valuation: ${formatter.format(410000000)} ៛",
          style: const TextStyle(color: Colors.white24, fontSize: 11),
        ),
      ],
    );
  }


  Widget _buildPriceChart() {
    return FutureBuilder<Map<String, List<int>>>(
      future: _fetchMonthlyData(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Shimmer.fromColors(
            baseColor: const Color(0xFF1A1F3D),
            highlightColor: const Color(0xFF2A2F4D),
            child: Container(
              height: 220,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          );
        }


        var users = snapshot.data!['users']!;
        var products = snapshot.data!['products']!;
        var orders = snapshot.data!['orders']!;


        List<FlSpot> userSpots = [];
        List<FlSpot> productSpots = [];
        List<FlSpot> orderSpots = [];


        for (int i = 0; i < 12; i++) {
          userSpots.add(FlSpot(i.toDouble(), users[i].toDouble()));
          productSpots.add(FlSpot(i.toDouble(), products[i].toDouble()));
          orderSpots.add(FlSpot(i.toDouble(), orders[i].toDouble()));
        }


        return Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "ស្ថិតិប្រតិបត្តិការប្រចាំឆ្នាំ",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Siemreap',
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      "Live",
                      style: TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              SizedBox(
                height: 200,
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (value) =>
                          FlLine(color: Colors.white10, strokeWidth: 1),
                    ),
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: 1,
                          getTitlesWidget: (val, meta) {
                            const months = [
                              'មករា',
                              'កុម្ភៈ',
                              'មីនា',
                              'មេសា',
                              'ឧសភា',
                              'មិថុនា',
                              'កក្កដា',
                              'សីហា',
                              'កញ្ញា',
                              'តុលា',
                              'វិច្ឆិកា',
                              'ធ្នូ',
                            ];
                            if (val >= 0 && val < 12) {
                              return Text(
                                months[val.toInt()],
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 8,
                                ),
                              );
                            }
                            return const Text('');
                          },
                        ),
                      ),
                      leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      _lineData(Colors.blueAccent, userSpots),
                      _lineData(Colors.orangeAccent, productSpots),
                      _lineData(Colors.greenAccent, orderSpots),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 15),
              _buildLegend(),
            ],
          ),
        );
      },
    );
  }


  LineChartBarData _lineData(Color color, List<FlSpot> spots) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      color: color,
      barWidth: 3,
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
          radius: 4,
          color: color,
          strokeWidth: 2,
          strokeColor: Colors.white,
        ),
      ),
      belowBarData: BarAreaData(show: true, color: color.withOpacity(0.1)),
    );
  }


  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _legendItem(Colors.blueAccent, "អ្នកប្រើ"),
        const SizedBox(width: 20),
        _legendItem(Colors.orangeAccent, "ផលិតផល"),
        const SizedBox(width: 20),
        _legendItem(Colors.greenAccent, "ការបញ្ជាទិញ"),
      ],
    );
  }


  Widget _legendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 11,
            fontFamily: 'Siemreap',
          ),
        ),
      ],
    );
  }


  Widget _buildStockStats() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('app_equity_stats')
          .doc('current') // ផ្ទៀងផ្ទាត់ Document ID ឱ្យត្រូវ
          .snapshots(),
      builder: (context, snapshot) {
        // តម្លៃ Default សម្រាប់ការពារ Error ពេលបណ្ដាញយឺត
        int totalShares = 10000;
        int listedShares = 3000;
        int availableShares = 0;


        if (snapshot.hasData && snapshot.data!.exists) {
          var data = snapshot.data!.data() as Map<String, dynamic>;


          // ទាញទិន្នន័យតាម Key ពិតក្នុង Firestore របស់មេ
          totalShares = data['company_total_shares'] ?? 10000;
          listedShares = data['total_listed_shares'] ?? 3000;
          availableShares = data['available_shares'] ?? 0;
        }


        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _statColumn("ភាគហ៊ុនសរុប", "$totalShares", Colors.white),
                  // បង្ហាញតែ "ហ៊ុនដាក់លក់" និង "នៅសល់" តាមបញ្ជារបស់មេ
                  _statColumn(
                    "ហ៊ុនដាក់លក់",
                    "$listedShares",
                    Colors.orangeAccent,
                  ),
                  _statColumn("នៅសល់", "$availableShares", Colors.greenAccent),
                ],
              ),
              const SizedBox(height: 15),
              // បង្ហាញ Progress Bar ធៀបនឹងចំនួនដាក់លក់ ៣០០០ ហ៊ុន
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: listedShares > 0
                      ? (listedShares - availableShares) / listedShares
                      : 0,
                  backgroundColor: Colors.white.withOpacity(0.1),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Colors.greenAccent,
                  ),
                  minHeight: 8,
                ),
              ),
            ],
          ),
        );
      },
    );
  }


  Widget _statColumn(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 11,
            fontFamily: 'Siemreap',
          ),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ],
    );
  }


  Widget _buildTrustIndicators() {
    return Row(
      children: [
        Expanded(
          child: _trustCard(
            Icons.verified_user,
            "ចុះបញ្ជីច្បាប់",
            "...",
            Colors.blueAccent,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _trustCard(
            Icons.security,
            "ប្រព័ន្ធសុវត្ថិភាព",
            "SSL + Escrow",
            Colors.greenAccent,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _trustCard(
            Icons.local_shipping,
            "ប្រព័ន្ធដឹកជញ្ជូន",
            "គ្របដណ្តប់ទូទាំងប្រទេស",
            Colors.orangeAccent,
          ),
        ),
      ],
    );
  }


  Widget _trustCard(IconData icon, String title, String subtitle, Color color) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              fontFamily: 'Siemreap',
            ),
          ),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(color: color, fontSize: 10),
          ),
        ],
      ),
    );
  }


  Widget _buildRiskWarning() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.orangeAccent.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.warning_amber,
              color: Colors.orangeAccent,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "ការព្រមានពីហានិភ័យ",
                  style: TextStyle(
                    color: Colors.orangeAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    fontFamily: 'Siemreap',
                  ),
                ),
                Text(
                  "ការវិនិយោគមានហានិភ័យ។ តម្លៃភាគហ៊ុនអាចឡើងឬធ្លាក់។ សូមពិចារណាឲ្យហើយមុនវិនិយោគ។",
                  style: TextStyle(
                    color: Colors.orangeAccent.withOpacity(0.7),
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


  Widget _buildInvestmentTerms() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.description, color: Colors.blueAccent),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "លក្ខខណ្ឌវិនិយោគ",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    fontFamily: 'Siemreap',
                  ),
                ),
                Text(
                  "សូមអានមុនពេលវិនិយោគ",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.arrow_forward_ios,
              color: Colors.white54,
              size: 16,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const InvestmentTermsScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }


  Widget _buildMainActionButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF3B5BFF),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          elevation: 5,
          shadowColor: const Color(0xFF3B5BFF).withOpacity(0.5),
        ),
        onPressed: () => _showPurchaseDialog(context),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.rocket_launch, color: Colors.white),
            SizedBox(width: 10),
            Text(
              "ចាប់ផ្ដើមវិនិយោគឥឡូវនេះ",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
                fontFamily: 'Siemreap',
              ),
            ),
          ],
        ),
      ),
    );
  }


  Future<void> _launchABA() async {
    final Uri url = Uri.parse('https://pay.ababank.com/oRF8/lq8jgwzb');
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      await launchUrl(url, mode: LaunchMode.platformDefault);
    }
  }


  void _showPurchaseDialog(BuildContext context) {
    String selectedBank = 'ABA';
    int totalPrice = 0;
    int currentStep = 0;


    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F121F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => DraggableScrollableSheet(
          initialChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) => Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  "ទម្រង់ស្នើសុំវិនិយោគ",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontFamily: 'Siemreap',
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  "ជំហាន ${currentStep + 1}/3",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 20),


                Row(
                  children: [
                    _stepIndicator(0, currentStep, Icons.person),
                    _stepLine(0, currentStep),
                    _stepIndicator(1, currentStep, Icons.payment),
                    _stepLine(1, currentStep),
                    _stepIndicator(2, currentStep, Icons.check_circle),
                  ],
                ),


                const SizedBox(height: 25),


                Expanded(
                  child: Form(
                    key: _formKey,
                    child: SingleChildScrollView(
                      controller: scrollController,
                      child: _buildStepContent(
                        currentStep,
                        setModalState,
                        selectedBank,
                        totalPrice,
                      ),
                    ),
                  ),
                ),


                const SizedBox(height: 20),
                Row(
                  children: [
                    if (currentStep > 0)
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white24),
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () => setModalState(() => currentStep--),
                          child: const Text(
                            "ថយក្រោយ",
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                      ),
                    if (currentStep > 0) const SizedBox(width: 10),
                    Expanded(
                      flex: currentStep == 0 ? 1 : 2,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3B5BFF),
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _isSubmitting
                            ? null
                            : () {
                          // បើកំពុងវិល មិនឱ្យចុចបានទេ
                          if (currentStep < 2) {
                            if (_formKey.currentState!.validate()) {
                              setModalState(() => currentStep++);
                            }
                          } else {
                            _submitInvestment(context, setModalState);
                          }
                        },
                        child: _isSubmitting
                            ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                            : Text(
                          currentStep < 2 ? "បន្ត" : "បញ្ជូនសំណើ",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  Widget _stepIndicator(int step, int currentStep, IconData icon) {
    bool isActive = step <= currentStep;
    bool isCurrent = step == currentStep;


    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: isActive
            ? const Color(0xFF3B5BFF)
            : Colors.white.withOpacity(0.1),
        shape: BoxShape.circle,
        border: isCurrent ? Border.all(color: Colors.white, width: 2) : null,
      ),
      child: Icon(
        icon,
        color: isActive ? Colors.white : Colors.white.withOpacity(0.3),
        size: 20,
      ),
    );
  }


  Widget _stepLine(int step, int currentStep) {
    return Expanded(
      child: Container(
        height: 2,
        color: step < currentStep
            ? const Color(0xFF3B5BFF)
            : Colors.white.withOpacity(0.1),
      ),
    );
  }


  Widget _buildStepContent(
      int step,
      Function setModalState,
      String selectedBank,
      int totalPrice,
      ) {
    switch (step) {
      case 0:
        return Column(
          children: [
            _buildDarkInput("ឈ្មោះពេញ *", nameController, Icons.person),
            _buildDarkInput("លេខអត្តសញ្ញាណប័ណ្ណ *", idController, Icons.badge),
            _buildDarkInput(
              "លេខទូរស័ព្ទ *",
              phoneController,
              Icons.phone,
              TextInputType.phone,
            ),
            _buildDarkInput(
              "អាសយដ្ឋាន *",
              addressController,
              Icons.location_on,
            ),
          ],
        );
      case 1:
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('app_equity_stats')
              .doc('current')
              .snapshots(),
          builder: (context, snapshot) {
            // ✅ ទាញ price_per_share ពី Firestore ផ្ទាល់
            if (snapshot.hasData && snapshot.data!.exists) {
              final data = snapshot.data!.data() as Map<String, dynamic>;
              currentPriceFromFirebase = data['price_per_share'] ?? 41000;
            }


            // ✅ គណនា total auto
            int shares = int.tryParse(shareController.text) ?? 0;
            int totalPrice = shares * currentPriceFromFirebase;


            return Column(
              children: [
                TextFormField(
                  controller: shareController,
                  keyboardType: TextInputType.number,
                  onChanged: (val) {
                    // ✅ setModalState ដើម្បី UI update ភ្លាម
                    setModalState(() {});
                  },
                  style: const TextStyle(color: Colors.white),
                  decoration: _darkInputDecoration(
                    'ចំនួនហ៊ុនដែលស្នើទិញ *',
                    Icons.pie_chart,
                  ),
                  validator: (v) => (v == null || v.isEmpty) ? 'ចាំបាច់' : null,
                ),
                const SizedBox(height: 10),


                // ✅ បង្ហាញ price per share
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'តម្លៃក្នុង ១ ហ៊ុន:',
                        style: TextStyle(
                          color: Colors.white54,
                          fontFamily: 'Siemreap',
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        '${formatter.format(currentPriceFromFirebase)} ៛',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),


                // ✅ total price auto
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.greenAccent.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'សរុបត្រូវបង់:',
                        style: TextStyle(
                          color: Colors.white70,
                          fontFamily: 'Siemreap',
                        ),
                      ),
                      Text(
                        '${formatter.format(totalPrice)} ៛',
                        style: const TextStyle(
                          color: Colors.greenAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 15),


                DropdownButtonFormField<String>(
                  value: 'ABA',
                  dropdownColor: const Color(0xFF1A1F3D),
                  decoration: _darkInputDecoration(
                    'ជ្រើសរើសធនាគារ *',
                    Icons.account_balance,
                  ),
                  items: ['ABA', 'Wing', 'Canadia', 'ACLEDA']
                      .map(
                        (s) => DropdownMenuItem(
                      value: s,
                      child: Text(
                        s,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  )
                      .toList(),
                  onChanged: (val) => setModalState(() {}),
                ),
                const SizedBox(height: 15),
                _buildDarkInput(
                  'លេខគណនីរបស់អ្នក *',
                  bankAccController,
                  Icons.credit_card,
                ),
              ],
            );
          },
        );
      case 2:
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.qr_code, color: Colors.blueAccent, size: 40),
                  const SizedBox(height: 10),
                  const Text(
                    "សឺមីកូដបង់ប្រាក់",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Siemreap',
                    ),
                  ),
                  const SizedBox(height: 10),
                  CachedNetworkImage(
                    imageUrl:
                    "https://firebasestorage.googleapis.com/v0/b/sesan-my-app.firebasestorage.app/o/20260308_163835.jpg?alt=media&token=95922392-ed40-4483-9097-899987ad06e8",
                    height: 150,
                    placeholder: (context, url) =>
                    const CircularProgressIndicator(),
                    errorWidget: (context, url, error) =>
                    const Icon(Icons.error),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: _launchABA,
                    icon: const Icon(
                      Icons.open_in_new,
                      color: Colors.white,
                      size: 16,
                    ),
                    label: const Text(
                      "បើក App ABA",
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF005D7E),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Column(
                children: [
                  const Text(
                    "ថតរូបវិក្កយបត្របង់ប្រាក់ *",
                    style: TextStyle(
                      color: Colors.white70,
                      fontFamily: 'Siemreap',
                    ),
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () async {
                      final xfile = await ImagePicker().pickImage(
                        source: ImageSource.gallery,
                        imageQuality: 80,
                      );
                      if (xfile != null) {
                        setModalState(() => _receiptImage = File(xfile.path));
                      }
                    },
                    child: Container(
                      height: 140,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                      child: _receiptImage == null
                          ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_a_photo,
                            color: Colors.white.withOpacity(0.3),
                            size: 40,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "ចុចដើម្បីបញ្ចូលរូបភាព",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      )
                          : ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(
                          _receiptImage!,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }


  Widget _buildDarkInput(
      String label,
      TextEditingController controller,
      IconData icon, [
        TextInputType? type,
        Function(String)? onChanged,
      ]) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextFormField(
        controller: controller,
        keyboardType: type,
        onChanged: onChanged,
        style: const TextStyle(color: Colors.white),
        decoration: _darkInputDecoration(label, icon),
        validator: (v) => (v == null || v.isEmpty) ? "ចាំបាច់" : null,
      ),
    );
  }


  InputDecoration _darkInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
      prefixIcon: Icon(icon, color: Colors.white.withOpacity(0.5)),
      filled: true,
      fillColor: Colors.white.withOpacity(0.05),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.blueAccent),
      ),
      errorStyle: const TextStyle(color: Colors.redAccent),
    );
  }


  Future<void> _submitInvestment(
      BuildContext context,
      Function setModalState,
      ) async {
    // ✅ validate ជាមុនសិន
    if (!_formKey.currentState!.validate() || _receiptImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text('សូមបំពេញទិន្នន័យឲ្យពេញលេញ និងភ្ជាប់រូបភាព'),
        ),
      );
      return;
    }


    setModalState(() => _isSubmitting = true);


    try {
      // ✅ prefs ក្នុង try
      final prefs = await SharedPreferences.getInstance();
      final uid = prefs.getString('user_uid') ?? '';


      String? url = await _uploadImage(_receiptImage!);
      if (url == null) throw Exception('Upload failed');


      final formData = {
        'name': nameController.text.trim(),
        'shares': int.parse(shareController.text),
        'id_card': idController.text.trim(),
        'phone': phoneController.text.trim(),
        'address': addressController.text.trim(),
        'bank_account': bankAccController.text.trim(),
        'bank_name': 'ABA',
        'total_price':
        int.parse(shareController.text) * currentPriceFromFirebase,
        'receipt_url': url,
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
        'user_id': uid, // ✅ UID ពិតប្រាកដ
      };


      await _saveToFirestore(formData);
      _clearForm();


      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.green,
            content: Text(
              '✅ សំណើវិនិយោគត្រូវបានបញ្ជូនជោគជ័យ!',
              style: TextStyle(fontFamily: 'Siemreap'),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text('❌ មានបញ្ហា: $e'),
          ),
        );
      }
    } finally {
      setModalState(() => _isSubmitting = false);
    }
  }
}



