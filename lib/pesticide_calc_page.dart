import 'package:flutter/material.dart';

class PesticideCalcPage extends StatefulWidget {
  const PesticideCalcPage({super.key});

  @override
  State<PesticideCalcPage> createState() => _PesticideCalcPageState();
}

class _PesticideCalcPageState extends State<PesticideCalcPage> {
  final _tankCtrl = TextEditingController(text: "20"); // តម្លៃដើម ២០ លីត្រ
  final _rateCtrl = TextEditingController();
  double _result = 0;

  void _calculate() {
    double tankSize = double.tryParse(_tankCtrl.text) ?? 0;
    double ratePer20L = double.tryParse(_rateCtrl.text) ?? 0;

    setState(() {
      // រូបមន្ត៖ (ថ្នាំក្នុង ២០លីត្រ / ២០) * ចំណុះធុងពិត
      if (tankSize > 0 && ratePer20L > 0) {
        _result = (ratePer20L / 20) * tankSize;
      } else {
        _result = 0;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("លាយថ្នាំកសិកម្ម"),
        backgroundColor: Colors.purple[700],
        foregroundColor: Colors.white,
      ),
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.opaque,
          child: SingleChildScrollView(
        padding: const EdgeInsets.all(25),
        child: Column(
          children: [
            // ១. កន្លែងរើស ឬ វាយចំណុះធុង
            _buildInputCard(
              title: "១. ចំណុះធុងបាញ់របស់អ្នក (លីត្រ)",
              controller: _tankCtrl,
              hint: "ឧទាហរណ៍៖ 25, 30, 50...",
              icon: Icons.gas_meter_rounded,
              onChanged: (v) => _calculate(),
            ),

            const SizedBox(height: 20),

            // ២. កន្លែងវាយចំនួន CC លើដបថ្នាំ
            _buildInputCard(
              title: "២. បរិមាណថ្នាំលើដប (CC ក្នុងទឹក ២០លីត្រ)",
              controller: _rateCtrl,
              hint: "ឧទាហរណ៍៖ 20, 25, 30...",
              icon: Icons.science_rounded,
              onChanged: (v) => _calculate(),
            ),

            const SizedBox(height: 30),

            // ៣. បង្ហាញលទ្ធផល
            _buildResultDisplay(),
          ],
        ),
      ),
        ),
    );
  }

  Widget _buildInputCard({
    required String title,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required Function(String) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          onChanged: onChanged,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: Colors.purple),
            hintText: hint,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildResultDisplay() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple.shade700, Colors.purple.shade500],
        ),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(color: Colors.purple.withOpacity(0.3), blurRadius: 15),
        ],
      ),
      child: Column(
        children: [
          const Text(
            "បរិមាណថ្នាំត្រូវប្រើ",
            style: TextStyle(color: Colors.white70, fontSize: 18),
          ),
          Text(
            "${_result.toStringAsFixed(1)} CC",
            style: const TextStyle(
              fontSize: 55,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const Text("មីលីលីត្រ (ml)", style: TextStyle(color: Colors.white60)),
        ],
      ),
    );
  }
}
