import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // ✅ បន្ថែម

class LandMeasureScreen extends StatefulWidget {
  const LandMeasureScreen({super.key});
  @override
  _LandMeasureScreenState createState() => _LandMeasureScreenState();
}

class _LandMeasureScreenState extends State<LandMeasureScreen> {
  // Controller សម្រាប់របៀបទី ១ (៤ ជ្រុង)
  final _w1 = TextEditingController();
  final _w2 = TextEditingController();
  final _l1 = TextEditingController();
  final _l2 = TextEditingController();

  // Controller សម្រាប់របៀបទី ២ (២ ជ្រុង)
  final _simpleW = TextEditingController();
  final _simpleL = TextEditingController();

  double _sqm = 0;
  double _hectare = 0;
  bool _isFourSides = true;

  // ✅ ទ្រង់ទ្រាយសម្រាប់កាត់ខ្ទង់
  final NumberFormat _fmtSqm = NumberFormat('#,###.##');       // ម៉ែត្រការ៉េ
  final NumberFormat _fmtHectare = NumberFormat('#,###.####'); // ហិកតា

  // ✅ ជំនួយញែកលេខដោយលុបសញ្ញាក្បៀស (,) ចេញ
  double _parseInput(TextEditingController ctrl) {
    final text = ctrl.text.replaceAll(',', '').trim();
    return double.tryParse(text) ?? 0;
  }

  void _calculate() {
    double result = 0;
    if (_isFourSides) {
      double w1 = _parseInput(_w1);
      double w2 = _parseInput(_w2);
      double l1 = _parseInput(_l1);
      double l2 = _parseInput(_l2);
      result = ((w1 + w2) / 2) * ((l1 + l2) / 2);
    } else {
      double w = _parseInput(_simpleW);
      double l = _parseInput(_simpleL);
      result = w * l;
    }

    setState(() {
      _sqm = result;
      _hectare = _sqm / 10000;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("គណនាផ្ទៃដីកសិកម្ម"),
        backgroundColor: Colors.green,
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // ជ្រើសរើសរបៀប
              Row(
                children: [
                  _modeBtn("វាស់ ៤ ជ្រុង", _isFourSides,
                          () => setState(() => _isFourSides = true)),
                  const SizedBox(width: 10),
                  _modeBtn("ទទឹង x បណ្ដោយ", !_isFourSides,
                          () => setState(() => _isFourSides = false)),
                ],
              ),
              const SizedBox(height: 25),

              // ប្រអប់បញ្ចូល
              if (_isFourSides) ...[
                _buildInput("ទទឹងទី ១ / ក្បាលដី (ម)", _w1),
                _buildInput("ទទឹងទី ២ / កន្ទុយដី (ម)", _w2),
                _buildInput("បណ្ដោយទី ១ / ខាងឆ្វេង (ម)", _l1),
                _buildInput("បណ្ដោយទី ២ / ខាងស្តាំ (ម)", _l2),
              ] else ...[
                _buildInput("ទទឹង (ម)", _simpleW),
                _buildInput("បណ្ដោយ (ម)", _simpleL),
              ],

              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: () {
                  FocusScope.of(context).unfocus();
                  _calculate();
                },
                child: const Text(
                  "គណនាផ្ទៃដី",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 55),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),

              if (_sqm > 0) _resultSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _modeBtn(String text, bool active, VoidCallback onTap) {return Expanded(
    child: OutlinedButton(
      onPressed: onTap,
      child: Text(text),
      style: OutlinedButton.styleFrom(
        backgroundColor: active ? Colors.green : Colors.white,
        foregroundColor: active ? Colors.white : Colors.green,
        side: const BorderSide(color: Colors.green),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
    ),
  );
  }

  Widget _buildInput(String label, TextEditingController ctrl) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Localizations.override(
        context: context,
        locale: const Locale('en', 'US'), // ឲ្យក្ដារចុចបង្ហាញចំនុចទសភាគ (.)
        child: TextField(
          controller: ctrl,
          keyboardType:
          const TextInputType.numberWithOptions(decimal: true, signed: false),
          decoration: InputDecoration(
            labelText: label,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
          ),
        ),
      ),
    );
  }

  Widget _resultSection() {
    return Column(
      children: [
        const SizedBox(height: 30),
        const Text(
          "លទ្ធផលគណនា៖",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 10),
        _cardResult("${_fmtSqm.format(_sqm)} ម៉ែត្រការ៉េ", Colors.green),
        const SizedBox(height: 10),
        _cardResult("${_fmtHectare.format(_hectare)} ហិកតា", Colors.blue),
      ],
    );
  }

  Widget _cardResult(String val, Color col) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: col.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: col, width: 2),
      ),
      child: Text(
        val,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: col),
      ),
    );
  }
}