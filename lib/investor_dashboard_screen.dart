import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:my_app/Shareholder_dividend_history.dart';
import 'package:my_app/company_report_screen.dart';
import 'package:my_app/digital_contract_screen.dart';
import 'package:my_app/transaction_history_screen.dart';


class InvestorDashboardScreen extends StatefulWidget {
  const InvestorDashboardScreen({super.key});


  @override
  State<InvestorDashboardScreen> createState() =>
      _InvestorDashboardScreenState();
}


class _InvestorDashboardScreenState extends State<InvestorDashboardScreen> {
  File? _agreementImage;
  bool _isObscured = true;
  bool _isLoading = true;


  @override
  void initState() {
    super.initState();
    _loadObscureSetting();
  }


  Future<void> _loadObscureSetting() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isObscured = prefs.getBool('isObscured') ?? true;
    });
  }


  Future<void> _toggleObscure() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isObscured = !_isObscured;
    });
    await prefs.setBool('isObscured', _isObscured);
  }


  Future<void> _submitTransferRequest(
      BuildContext context,
      Map<String, dynamic> senderData, {
        required String receiverName,
        required String receiverId,
        required String receiverPhone,
        required int amount,
        required String note,
      }) async {
    if (_agreementImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("សូមភ្ជាប់រូបភាពភស្តុតាងព្រមព្រៀង")),
      );
      return;
    }


    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (c) => const Center(child: CircularProgressIndicator()),
      );


      String fileName =
          'transfers/${DateTime.now().millisecondsSinceEpoch}.jpg';
      var storageRef = FirebaseStorage.instance.ref().child(fileName);
      await storageRef.putFile(_agreementImage!);
      String imageUrl = await storageRef.getDownloadURL();


      await FirebaseFirestore.instance.collection('transfer_requests').add({
        'sender_id': senderData['uid'],
        'sender_name': senderData['name'] ?? "មិនស្គាល់ឈ្មោះ",
        'sender_phone': senderData['phone'] ?? "គ្មានលេខ",
        'sender_id_card': senderData['id_card'] ?? "គ្មាន ID",
        'receiver_name': receiverName,
        'receiver_id_card': receiverId,
        'receiver_phone': receiverPhone,
        'amount': amount,
        'note': note,
        'agreement_image': imageUrl,
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
      });


      Navigator.pop(context);
      Navigator.pop(context);
      setState(() => _agreementImage = null);


      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.green,
          content: Text("✅ សំណើផ្ទេរត្រូវបានបញ្ជូនទៅ Admin រួចរាល់!"),
        ),
      );
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("❌ មានបញ្ហា: $e")));
    }
  }


  void _showTransferForm(
      BuildContext context,
      Map<String, dynamic> senderData,
      int totalShares,
      ) {
    final nameController = TextEditingController();
    final idController = TextEditingController();
    final phoneController = TextEditingController();
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1F3D),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            "បែបបទស្នើសុំផ្ទេរភាគហ៊ុន",
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontFamily: 'Siemreap',
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildField(nameController, "ឈ្មោះអ្នកទទួល", Icons.person),
                _buildField(idController, "លេខអត្តសញ្ញាណប័ណ្ណ", Icons.badge),
                _buildField(
                  phoneController,
                  "លេខទូរស័ព្ទ",
                  Icons.phone,
                  isNumber: true,
                ),
                _buildField(
                  amountController,
                  "ចំនួនហ៊ុន (អ្នកមាន: $totalShares)",
                  Icons.pie_chart,
                  isNumber: true,
                ),
                _buildField(
                  noteController,
                  "មូលហេតុ (ជម្រើស)",
                  Icons.note,
                  maxLines: 2,
                ),
                const SizedBox(height: 15),
                const Text(
                  "រូបភាពភស្តុតាងព្រមព្រៀង",
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () async {
                    final picker = ImagePicker();
                    final pickedFile = await picker.pickImage(
                      source: ImageSource.gallery,
                      imageQuality: 80,
                    );
                    if (pickedFile != null) {
                      setDialogState(
                            () => _agreementImage = File(pickedFile.path),
                      );
                    }
                  },
                  child: Container(
                    height: 120,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: _agreementImage == null
                        ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(
                          Icons.add_a_photo,
                          color: Colors.white54,
                          size: 40,
                        ),
                        SizedBox(height: 8),
                        Text(
                          "ចុចដើម្បីបញ្ចូលរូបភាព",
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    )
                        : ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        _agreementImage!,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() => _agreementImage = null);
                Navigator.pop(context);
              },
              child: const Text(
                "បោះបង់",
                style: TextStyle(color: Colors.white70),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orangeAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                int amount = int.tryParse(amountController.text) ?? 0;
                if (amount > 0 &&
                    amount <= totalShares &&
                    nameController.text.isNotEmpty) {
                  _submitTransferRequest(
                    context,
                    senderData,
                    receiverName: nameController.text,
                    receiverId: idController.text,
                    receiverPhone: phoneController.text,
                    amount: amount,
                    note: noteController.text,
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("សូមពិនិត្យទិន្នន័យឡើងវិញ")),
                  );
                }
              },
              child: const Text("បញ្ជូនសំណើ"),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildField(
      TextEditingController controller,
      String label,
      IconData icon, {
        bool isNumber = false,
        int maxLines = 1,
      }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        style: const TextStyle(color: Colors.white, fontFamily: 'Siemreap'),
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        maxLines: maxLines,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.blueAccent, size: 20),
          labelText: label,
          labelStyle: const TextStyle(color: Colors.grey, fontSize: 12),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.white24),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.blueAccent),
          ),
          filled: true,
          fillColor: Colors.white.withOpacity(0.05),
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _getUid(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF0A0E21),
            body: Center(child: CircularProgressIndicator()),
          );
        }


        final uid = snapshot.data ?? '';


        // ✅ ប្រើ SharedPreferences UID
        if (uid.isEmpty) {
          return Scaffold(
            backgroundColor: const Color(0xFF0A0E21),
            body: Center(
              child: Text(
                'សូមចូលប្រើប្រាស់គណនីសិន',
                style: TextStyle(color: Colors.white),
              ),
            ),
          );
        }


        return _buildDashboardUI(uid);
      },
    );
  }


  // ✅ function ទាញ uid ពី SharedPreferences
  Future<String> _getUid() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_uid') ?? '';
  }


  Widget _buildDashboardUI(String uid) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0E21),
        elevation: 0,
        title: const Text(
          'វិនិយោគិន Dashboard',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Siemreap',
            fontSize: 16,
          ),
        ),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.delayed(const Duration(seconds: 1));
          setState(() {});
        },
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('shareholders')
              .doc(uid)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError)
              return Center(
                child: Text(
                  'Error: ${snapshot.error}',
                  style: const TextStyle(color: Colors.white),
                ),
              );
            if (snapshot.connectionState == ConnectionState.waiting)
              return _buildShimmerLoading();


            if (!snapshot.hasData || !snapshot.data!.exists) {
              return _buildNoInvestmentView(context);
            }


            var investorData = snapshot.data!.data() as Map<String, dynamic>;
            // ✅ ដាក់ uid ចូល investorData ដើម្បីប្រើក្នុង widgets
            investorData['uid'] = uid;
            int myShares = investorData['total_shares'] ?? 0;


            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ១. Investor Card
                  _buildInvestorCard(investorData, myShares),
                  const SizedBox(height: 20),


                  // ២. Asset Summary
                  _buildAssetSummary(myShares),
                  const SizedBox(height: 20),


                  // ៣. Portfolio Chart
                  _buildPortfolioChart(),
                  const SizedBox(height: 20),


                  // ៤. Quick Actions
                  _buildQuickActionsHeader(),
                  const SizedBox(height: 12),
                  _buildQuickActionsGrid(context, investorData, myShares),
                  const SizedBox(height: 20),


                  // ៥. Buy More Button
                  _buildBuyMoreButton(context),
                  const SizedBox(height: 30),
                ],
              ),
            );
          },
        ),
      ),
    );
  }


  Widget _buildShimmerLoading() {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF1A1F3D),
      highlightColor: const Color(0xFF2A2F4D),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              height: 220,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Container(
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildInvestorCard(Map<String, dynamic> data, int shares) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A237E), Color(0xFF0D47A1), Color(0xFF01579B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: [0.0, 0.5, 1.0],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
            spreadRadius: -5,
          ),
        ],
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Stack(
            children: [
              Positioned(
                right: -30,
                bottom: -30,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.05),
                  ),
                ),
              ),
              Positioned(
                left: -20,
                top: -20,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.03),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            "SESAN INVESTOR",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 9,
                              letterSpacing: 1.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              constraints: const BoxConstraints(),
                              padding: EdgeInsets.zero,
                              icon: Icon(
                                _isObscured
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: Colors.white54,
                                size: 20,
                              ),
                              onPressed: _toggleObscure,
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.waves,
                              color: Colors.white.withOpacity(0.4),
                              size: 22,
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      data['name']?.toString().toUpperCase() ?? "KLART DEAN",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        fontFamily: 'Siemreap',
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        _cardInfo("ចំនួនហ៊ុន", "$shares ហ៊ុន"),
                        const SizedBox(width: 40),


                        _cardInfo(
                          "ID អ្នកវិនិយោគ",
                          "INV-${data['uid']?.toString().substring(0, 5).toUpperCase() ?? "WBDQV"}",
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSmallInfo(
                              "លុយចំណេញដកបាន",
                              "${data['balance'] ?? 0} ៛",
                            ),
                            const SizedBox(height: 8),
                            _buildSmallInfo(
                              "កាលបរិច្ឆេទវិនិយោគ",
                              data['join_date'] ?? "២៥ មីនា ២០២៦",
                            ),
                          ],
                        ),
                        _buildSmallInfo(
                          "សរុបដែលធ្លាប់បាន",
                          "${data['total_earned'] ?? 0} ៛",
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _cardInfo(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white60,
            fontSize: 10,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }


  Widget _buildSmallInfo(String label, String value) {
    bool isMoney = label.contains("លុយ") || label.contains("សរុប");
    String displayValue = (_isObscured && isMoney) ? "×××××× ៛" : value;


    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 10,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          displayValue,
          style: const TextStyle(
            color: Colors.greenAccent,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }


  Widget _buildAssetSummary(int myShares) {
    final formatter = NumberFormat('#,###', 'km');
    int initialValue = myShares * 41000;
    int currentValue = myShares * 45000;
    int profit = currentValue - initialValue;
    double profitPercent = initialValue > 0 ? (profit / initialValue) * 100 : 0;


    return Row(
      children: [
        Expanded(
          child: _statBox(
            "តម្លៃដើម",
            "${formatter.format(initialValue)} ៛",
            Colors.white70,
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: _statBox(
            "តម្លៃបច្ចុប្បន្ន",
            "${formatter.format(currentValue)} ៛",
            Colors.greenAccent,
            subtitle:
            "+${formatter.format(profit)} ៛ (${profitPercent.toStringAsFixed(1)}%)",
          ),
        ),
      ],
    );
  }


  Widget _statBox(
      String label,
      String value,
      Color valColor, {
        String? subtitle,
      }) {
    String displayValue = _isObscured ? "×××××× ៛" : value;
    String? displaySubtitle = subtitle != null && _isObscured
        ? "×××××× ៛"
        : subtitle;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 10,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            displayValue,
            style: TextStyle(
              color: valColor,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (displaySubtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              displaySubtitle,
              style: TextStyle(
                color: Colors.greenAccent.withOpacity(0.7),
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }


  Widget _buildPortfolioChart() {
    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "កំណើនទ្រព្យសម្បត្តិ",
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 1,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.white.withOpacity(0.05),
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${value.toInt()}M',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.3),
                            fontSize: 10,
                          ),
                        );
                      },
                      reservedSize: 30,
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        const months = ['មក', 'មី', 'មិ', 'មស', 'កក', 'តា'];
                        if (value.toInt() >= 0 &&
                            value.toInt() < months.length) {
                          return Text(
                            months[value.toInt()],
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.3),
                              fontSize: 10,
                            ),
                          );
                        }
                        return const SizedBox();
                      },
                      reservedSize: 22,
                    ),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: const [
                      FlSpot(0, 2),
                      FlSpot(1, 2.5),
                      FlSpot(2, 3),
                      FlSpot(3, 2.8),
                      FlSpot(4, 4),
                      FlSpot(5, 4.5),
                    ],
                    isCurved: true,
                    color: Colors.greenAccent,
                    barWidth: 3,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 4,
                          color: Colors.greenAccent,
                          strokeWidth: 2,
                          strokeColor: Colors.white,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.greenAccent.withOpacity(0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildQuickActionsHeader() {
    return const Text(
      "សេវាកម្មរហ័ស",
      style: TextStyle(
        color: Colors.white70,
        fontSize: 14,
        fontWeight: FontWeight.bold,
        fontFamily: 'Siemreap',
      ),
    );
  }


  Widget _buildQuickActionsGrid(
      BuildContext context,
      Map<String, dynamic> investorData,
      int myShares,
      ) {
    final actions = [
      {
        'icon': Icons.history,
        'label': 'ប្រវត្តិទិញ',
        'color': Colors.blueAccent,
        'onTap': () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const TransactionHistoryScreen(),
          ),
        ),
      },
      {
        'icon': Icons.payments,
        'label': 'ប្រាក់ចំណេញ',
        'color': Colors.greenAccent,
        'onTap': () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ShareholderDividendHistory(
              userShares: investorData['total_shares'] ?? 0,
            ),
          ),
        ),
      },
      {
        'icon': Icons.description,
        'label': 'របាយការណ៍',
        'color': Colors.orangeAccent,
        'onTap': () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const CompanyReportScreen()),
        ),
      },
      {
        'icon': Icons.security,
        'label': 'កិច្ចសន្យា',
        'color': Colors.purpleAccent,
        'onTap': () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const DigitalContractScreen(),
          ),
        ),
      },
      {
        'icon': Icons.swap_horiz,
        'label': 'ផ្ទេរភាគហ៊ុន',
        'color': Colors.orangeAccent,
        'onTap': () => _showTransferForm(context, investorData, myShares),
      },
      {
        'icon': Icons.account_balance_wallet,
        'label': 'ដកលុយ',
        'color': Colors.tealAccent,
        'onTap': () {
          // TODO: Implement withdraw
        },
      },
    ];


    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.0,
      ),
      itemCount: actions.length,
      itemBuilder: (context, index) {
        return GestureDetector(
          onTap: actions[index]['onTap'] as VoidCallback?,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: (actions[index]['color'] as Color).withOpacity(0.2),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (actions[index]['color'] as Color).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    actions[index]['icon'] as IconData,
                    color: actions[index]['color'] as Color,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  actions[index]['label'] as String,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontFamily: 'Siemreap',
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }


  Widget _buildBuyMoreButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blueAccent.withOpacity(0.2),
          foregroundColor: Colors.blueAccent,
          side: const BorderSide(color: Colors.blueAccent),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.add_circle_outline),
        label: const Text(
          "ទិញភាគហ៊ុនបន្ថែម",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            fontFamily: 'Siemreap',
          ),
        ),
      ),
    );
  }


  Widget _buildNoInvestmentView(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 80,
            color: Colors.white.withOpacity(0.2),
          ),
          const SizedBox(height: 20),
          const Text(
            "អ្នកមិនទាន់មានភាគហ៊ុននៅឡើយទេ",
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
              fontFamily: 'Siemreap',
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
            ),
            child: const Text(
              "ចាប់ផ្តើមវិនិយោគ",
              style: TextStyle(fontFamily: 'Siemreap'),
            ),
          ),
        ],
      ),
    );
  }
}



