import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart'; // ✅ បន្ថែម

class CurrencyScreen extends StatefulWidget {
  const CurrencyScreen({super.key});

  @override
  State<CurrencyScreen> createState() => _CurrencyScreenState();
}

class _CurrencyScreenState extends State<CurrencyScreen> {
  // --- Controllers សម្រាប់គ្រប់រូបិយប័ណ្ណ ---
  final _usdCtrl = TextEditingController();
  final _khrCtrl = TextEditingController();
  final _thbCtrl = TextEditingController();
  final _vndCtrl = TextEditingController();
  final _cnyCtrl = TextEditingController();
  final _eurCtrl = TextEditingController();
  final _jpyCtrl = TextEditingController();
  final _lakCtrl = TextEditingController(); // ឡាវ 🇱🇦
  final _krwCtrl = TextEditingController(); // កូរ៉េ 🇰🇷
  final _inrCtrl = TextEditingController(); // ឥណ្ឌា 🇮🇳

  // --- អត្រាប្តូរប្រាក់ (Default Values) ---
  double rateUsdToKhr = 4120;
  double rateUsdToThb = 35.5;
  double rateUsdToVnd = 24500;
  double rateUsdToCny = 7.2;
  double rateUsdToEur = 0.92;
  double rateUsdToJpy = 150;
  double rateUsdToLak = 21000; // ឡាវ
  double rateUsdToKrw = 1350; // កូរ៉េ
  double rateUsdToInr = 83.5; // ឥណ្ឌា

  bool isLoading = false;

  // ✅ ទ្រង់ទ្រាយសម្រាប់កាត់ខ្ទង់
  final NumberFormat _fmtWhole = NumberFormat('#,###');       // សម្រាប់ចំនួនគត់ (គ្មានទសភាគ)
  final NumberFormat _fmtDecimal = NumberFormat('#,###.00'); // សម្រាប់ចំនួនទសភាគ ២ខ្ទង់

  @override
  void initState() {
    super.initState();
    _fetchOnlineRates();
  }

  // 🌐 ទាញទិន្នន័យពី API អន្តរជាតិ
  Future<void> _fetchOnlineRates() async {
    if (!mounted) return;
    setState(() => isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('https://api.exchangerate-api.com/v4/latest/USD'),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final rates = data['rates'];
        setState(() {
          rateUsdToThb = rates['THB'].toDouble();
          rateUsdToVnd = rates['VND'].toDouble();
          rateUsdToCny = rates['CNY'].toDouble();
          rateUsdToEur = rates['EUR'].toDouble();
          rateUsdToJpy = rates['JPY'].toDouble();
          rateUsdToLak = rates['LAK'].toDouble();
          rateUsdToKrw = rates['KRW'].toDouble();
          rateUsdToInr = rates['INR'].toDouble();
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // ✅ កែប្រែ _updatePrices ឲ្យកាត់ខ្ទង់
  void _updatePrices(String value, String type) {
    // លុបសញ្ញាក្បៀសចេញមុនគណនា
    String cleanValue = value.replaceAll(',', '');
    if (cleanValue.isEmpty) {
      _clearAllFields();
      return;
    }
    double input = double.tryParse(cleanValue) ?? 0;
    double usdAmount = 0;

    switch (type) {
      case 'USD': usdAmount = input; break;
      case 'KHR': usdAmount = input / rateUsdToKhr; break;
      case 'THB': usdAmount = input / rateUsdToThb; break;
      case 'VND': usdAmount = input / rateUsdToVnd; break;
      case 'CNY': usdAmount = input / rateUsdToCny; break;
      case 'EUR': usdAmount = input / rateUsdToEur; break;
      case 'JPY': usdAmount = input / rateUsdToJpy; break;
      case 'LAK': usdAmount = input / rateUsdToLak; break;
      case 'KRW': usdAmount = input / rateUsdToKrw; break;
      case 'INR': usdAmount = input / rateUsdToInr; break;
    }

    // ជំនួយសម្រាប់កំណត់តម្លៃកាត់ខ្ទង់
    void _setFormatted(TextEditingController ctrl, double val, {bool hasDecimal = false}) {
      final String formatted = hasDecimal ? _fmtDecimal.format(val) : _fmtWhole.format(val);
      ctrl.text = formatted;
      // ដាក់ cursor នៅចុងក្រោយ
      ctrl.selection = TextSelection.collapsed(offset: formatted.length);
    }setState(() {
      if (type != 'USD') _setFormatted(_usdCtrl, usdAmount, hasDecimal: true);
      if (type != 'KHR') _setFormatted(_khrCtrl, usdAmount * rateUsdToKhr);
      if (type != 'THB') _setFormatted(_thbCtrl, usdAmount * rateUsdToThb, hasDecimal: true);
      if (type != 'VND') _setFormatted(_vndCtrl, usdAmount * rateUsdToVnd);
      if (type != 'CNY') _setFormatted(_cnyCtrl, usdAmount * rateUsdToCny, hasDecimal: true);
      if (type != 'EUR') _setFormatted(_eurCtrl, usdAmount * rateUsdToEur, hasDecimal: true);
      if (type != 'JPY') _setFormatted(_jpyCtrl, usdAmount * rateUsdToJpy);
      if (type != 'LAK') _setFormatted(_lakCtrl, usdAmount * rateUsdToLak);
      if (type != 'KRW') _setFormatted(_krwCtrl, usdAmount * rateUsdToKrw);
      if (type != 'INR') _setFormatted(_inrCtrl, usdAmount * rateUsdToInr, hasDecimal: true);
    });
  }

  void _clearAllFields() {
    setState(() {
      _usdCtrl.clear();
      _khrCtrl.clear();
      _thbCtrl.clear();
      _vndCtrl.clear();
      _cnyCtrl.clear();
      _eurCtrl.clear();
      _jpyCtrl.clear();
      _lakCtrl.clear();
      _krwCtrl.clear();
      _inrCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text(
          "ប្តូររូបិយប័ណ្ណ",
          style: TextStyle(fontFamily: 'Siemreap'),
        ),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _fetchOnlineRates,
            icon: isLoading
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
                : const Icon(Icons.sync),
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildRateInfo(),
              const SizedBox(height: 20),
              _buildField("ដុល្លារ (USD)", "🇺🇸", _usdCtrl, 'USD'),
              _buildField("រៀល (KHR)", "🇰🇭", _khrCtrl, 'KHR'),
              _buildField("បាត (THB)", "🇹🇭", _thbCtrl, 'THB'),
              _buildField("គីបឡាវ (LAK)", "🇱🇦", _lakCtrl, 'LAK'),
              _buildField("វ៉ុនកូរ៉េ (KRW)", "🇰🇷", _krwCtrl, 'KRW'),
              _buildField("រូពីឥណ្ឌា (INR)", "🇮🇳", _inrCtrl, 'INR'),
              _buildField("ដុង (VND)", "🇻🇳", _vndCtrl, 'VND'),
              _buildField("យ័ន (CNY)", "🇨🇳", _cnyCtrl, 'CNY'),
              _buildField("អឺរ៉ូ (EUR)", "🇪🇺", _eurCtrl, 'EUR'),
              _buildField("យេន (JPY)", "🇯🇵", _jpyCtrl, 'JPY'),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _clearAllFields,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  minimumSize: const Size(double.infinity, 55),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: const Text(
                  "សម្អាតទិន្នន័យទាំងអស់",
                  style: TextStyle(
                    fontSize: 16,
                    fontFamily: 'Siemreap',
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRateInfo() {return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [Colors.blue.shade400, Colors.blue.shade700],
      ),
      borderRadius: BorderRadius.circular(15),
      boxShadow: [
        BoxShadow(
          color: Colors.blue.withOpacity(0.3),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      children: [
        const Text(
          "⚠️ បញ្ជាក់៖ អត្រាប្តូរប្រាក់នេះទាញចេញពីទីផ្សារអន្តរជាតិ (API)",
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontFamily: 'Siemreap',
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 5),
        Text(
          isLoading
              ? "កំពុងអាប់ដេត..."
              : "តម្លៃអាចនឹងខុសគ្នាពីធនាគារក្នុងស្រុកបន្តិចបន្តួច",
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
            fontFamily: 'Siemreap',
          ),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
  }

  Widget _buildField(
      String label,
      String flag,
      TextEditingController ctrl,
      String type,
      ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6)],
      ),
      child: TextField(
        controller: ctrl,
        onChanged: (v) => _updatePrices(v, type),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          fontFamily: 'Siemreap',
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(
            fontFamily: 'Siemreap',
            fontSize: 15,
            color: Colors.grey,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Text(flag, style: const TextStyle(fontSize: 26)),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    );
  }
}