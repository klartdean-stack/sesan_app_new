import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // ✅ បន្ថែម

class NPKCalcPage extends StatefulWidget {
  const NPKCalcPage({super.key});

  @override
  State<NPKCalcPage> createState() => _NPKCalcPageState();
}

class _NPKCalcPageState extends State<NPKCalcPage> {
  final _nCtrl = TextEditingController();
  final _pCtrl = TextEditingController();
  final _kCtrl = TextEditingController();

  double _urea = 0;
  double _dap = 0;
  double _mop = 0;

  // ✅ មុខងារដក comma
  double _parseNumber(String text) {
    String clean = text.replaceAll(',', '');
    return double.tryParse(clean) ?? 0;
  }

  void _calculateNPK() {
    // ✅ ប្រើ _parseNumber
    double targetN = _parseNumber(_nCtrl.text);
    double targetP = _parseNumber(_pCtrl.text);
    double targetK = _parseNumber(_kCtrl.text);

    setState(() {
      _mop = (targetK / 60) * 100;
      _dap = (targetP / 46) * 100;
      double nInDap = _dap * 0.18;
      double remainingN = targetN - nInDap;
      _urea = remainingN > 0 ? (remainingN / 46) * 100 : 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "គណនាជី N-P-K",
          style: TextStyle(fontFamily: 'Siemreap'),
        ),
        backgroundColor: Colors.green.shade800,
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Text(
                "បញ្ចូលរូបមន្តដីដែលចង់បាន (គីឡូ/ហិកតា)",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  _buildInputBox(_nCtrl, "N", Colors.orange),
                  const SizedBox(width: 10),
                  _buildInputBox(_pCtrl, "P", Colors.blue),
                  const SizedBox(width: 10),
                  _buildInputBox(_kCtrl, "K", Colors.red),
                ],
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: () {
                  FocusScope.of(context).unfocus();
                  _calculateNPK();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade800,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 55),
                ),
                child: const Text("គណនាបរិមាណបាវជី"),
              ),
              if (_urea > 0 || _dap > 0 || _mop > 0) _buildResult(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputBox(TextEditingController ctrl, String label, Color color) {
    return Expanded(
      child: TextField(
        controller: ctrl,
        // ✅ អនុញ្ញាតទសភាគ
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textAlign: TextAlign.center,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: color, fontWeight: FontWeight.bold),
          border: const OutlineInputBorder(),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: color, width: 2),
          ),
        ),
      ),
    );
  }

  Widget _buildResult() {
    // ✅ Format លេខ
    final NumberFormat numberFormat = NumberFormat("#,###.0", "en_US");

    return Container(
        margin: const EdgeInsets.only(top: 30),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.green.shade300),
        ),
      child: Column(
        children: [
          const Text(
            "បរិមាណជីដែលកសិករត្រូវប្រើសរុប៖",
            style: TextStyle(fontSize: 15),
          ),
          const Divider(height: 30),
          _resultItem("ជីអ៊ុយរ៉េ (46-0-0)", _urea, numberFormat),
          _resultItem("ជីដេអាប៉េ (18-46-0)", _dap, numberFormat),
          _resultItem("ជីប៉ូតាស្យូម (0-0-60)", _mop, numberFormat),
        ],
      ),
    );
  }

  Widget _resultItem(String title, double value, NumberFormat format) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title),
          Text(
            "${format.format(value)} គីឡូក្រាម",
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Colors.green,
            ),
          ),
        ],
      ),
    );
  }
}