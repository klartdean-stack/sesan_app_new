import 'package:flutter/material.dart';

class CropWaterCalcPage extends StatefulWidget {
  const CropWaterCalcPage({super.key});

  @override
  State<CropWaterCalcPage> createState() => _CropWaterCalcPageState();
}

class _CropWaterCalcPageState extends State<CropWaterCalcPage> {
  final _areaCtrl = TextEditingController(); // ផ្ទៃដី
  final _pumpFlowCtrl = TextEditingController(
    text: "5000",
  ); // កម្លាំងម៉ូទ័រ (លីត្រ/ម៉ោង)
  String _cropType = "បន្លែស្លឹក";

  double _dailyLiters = 0;
  double _minutesNeeded = 0;

  // កម្រិតតម្រូវការទឹក (លីត្រ/ម៉ែត្រការ៉េ/ថ្ងៃ) តាមបច្ចេកទេសក្នុងវីដេអូ
  final Map<String, double> waterUsage = {
    "បន្លែស្លឹក": 5.0, // ត្រូវការទឹកមធ្យម ៥លីត្រ
    "បន្លែយកផ្លែ": 8.0, // ម្ទេស, ប៉េងប៉ោះ ត្រូវការទឹកច្រើនជាង
    "ឈើហូបផ្លែ": 12.0, // ធុរេន, ស្វាយ ត្រូវការទឹកច្រើនបំផុត
    "ដំណាំចម្ការ": 4.0, // ពោត, សណ្ដែក ត្រូវការទឹកមធ្យម
  };

  void _calculate() {
    double area = double.tryParse(_areaCtrl.text) ?? 0;
    double pumpFlow = double.tryParse(_pumpFlowCtrl.text) ?? 5000;
    if (area == 0) return;

    setState(() {
      // ១. គណនាទឹកសរុបប្រចាំថ្ងៃ (លីត្រ)
      _dailyLiters = area * waterUsage[_cropType]!;

      // ២. គណនារយៈពេលស្រោច (នាទី) = (ទឹកសរុប / កម្លាំងម៉ូទ័រ) * ៦០នាទី
      _minutesNeeded = (_dailyLiters / pumpFlow) * 60;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "តម្រូវការទឹកដំណាំ",
          style: TextStyle(fontFamily: 'Siemreap'),
        ),
        backgroundColor: Colors.blueAccent.shade700,
      ),
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.opaque,
          child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildCardInput(
              child: DropdownButtonFormField<String>(
                value: _cropType,
                decoration: const InputDecoration(
                  labelText: "ប្រភេទដំណាំ",
                  border: InputBorder.none,
                ),
                items: waterUsage.keys
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => setState(() => _cropType = v!),
              ),
            ),
            _buildCardInput(
              child: TextField(
                controller: _areaCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "ផ្ទៃដីដាំដុះ (ម៉ែត្រការ៉េ)",
                  border: InputBorder.none,
                  prefixIcon: Icon(Icons.layers),
                ),
              ),
            ),
            _buildCardInput(
              child: TextField(
                controller: _pumpFlowCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "កម្លាំងម៉ូទ័រ (លីត្រ/ម៉ោង)",
                  border: InputBorder.none,
                  prefixIcon: Icon(Icons.speed),
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                FocusScope.of(context).unfocus();
                _calculate();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent.shade700,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                "គណនាការស្រោចស្រព",
                style: TextStyle(fontSize: 18),
              ),
            ),
            if (_dailyLiters > 0) _buildResultSection(),
          ],
        ),
      ),
        ),
    );
  }

  Widget _buildCardInput({required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: child,
    );
  }

  Widget _buildResultSection() {
    return Container(
      margin: const EdgeInsets.only(top: 30),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade50, Colors.blue.shade100],
        ),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.blue.shade300),
      ),
      child: Column(
        children: [
          const Text(
            "បរិមាណទឹកត្រូវការសរុបក្នុង ១ ថ្ងៃ",
            style: TextStyle(fontSize: 14, color: Colors.blueGrey),
          ),
          Text(
            "${_dailyLiters.toStringAsFixed(0)} លីត្រ",
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade900,
            ),
          ),
          const Divider(height: 30),
          const Text(
            "រយៈពេលត្រូវបើកទឹកស្រោច",
            style: TextStyle(fontSize: 14, color: Colors.blueGrey),
          ),
          Text(
            "${_minutesNeeded.toStringAsFixed(0)} នាទី",
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.orange,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            "*(យោបល់៖ គួរស្រោច ព្រឹក ៥០% និង ល្ងាច ៥០%)",
            style: TextStyle(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}
