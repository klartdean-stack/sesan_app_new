import 'package:flutter/material.dart';

class PlantCalcPage extends StatefulWidget {
  const PlantCalcPage({super.key});

  @override
  State<PlantCalcPage> createState() => _PlantCalcPageState();
}

class _PlantCalcPageState extends State<PlantCalcPage> {
  // ទទួលទិន្នន័យពីកសិករ
  final areaController = TextEditingController(); // ទំហំដី
  final rowSpacingController = TextEditingController(); // ចម្ងាយជួរ
  final plantSpacingController = TextEditingController(); // ចម្ងាយដើម

  int totalPlants = 0;

  // 🎯 Logic គណនា៖ ចំនួនដើម = ផ្ទៃដី / (ចម្ងាយជួរ x ចម្ងាយដើម)
  void calculatePlants() {
    double area = double.tryParse(areaController.text.replaceAll(',', '.')) ?? 0;
    double rowS = double.tryParse(rowSpacingController.text.replaceAll(',', '.')) ?? 0;
    double plantS = double.tryParse(plantSpacingController.text.replaceAll(',', '.')) ?? 0;

    if (area > 0 && rowS > 0 && plantS > 0) {
      setState(() {
        totalPlants = (area / (rowS * plantS)).round();
      });
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('គណនាចំនួនកូនដាំ'),
        backgroundColor: Colors.green,
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _buildInput(
                "ផ្ទៃដីសរុប (ម៉ែត្រការ៉េ)",
                Icons.layers,
                areaController,
              ),
              const SizedBox(height: 15),
              _buildInput(
                "ចម្ងាយចន្លោះជួរ (ម៉ែត្រ)",
                Icons.settings_ethernet,
                rowSpacingController,
              ),
              const SizedBox(height: 15),
              _buildInput(
                "ចម្ងាយចន្លោះដើម (ម៉ែត្រ)",
                Icons.more_horiz,
                plantSpacingController,
              ),
              const SizedBox(height: 25),
              ElevatedButton(
                onPressed: () {
                  FocusScope.of(context).unfocus();
                  calculatePlants();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  minimumSize: const Size(double.infinity, 55),
                ),
                child: const Text(
                  'គណនាចំនួនកូនឈើ',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
              const SizedBox(height: 30),

              // បង្ហាញលទ្ធផលធំៗច្បាស់ៗ
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    const Text(
                      'ចំនួនកូនឈើដែលត្រូវដាំសរុប',
                      style: TextStyle(fontSize: 16),
                    ),
                    Text(
                      '$totalPlants ដើម',
                      style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
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

  Widget _buildInput(String label,
      IconData icon,
      TextEditingController controller,) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(
          decimal: true, signed: false),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.green),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
      ),
    );
  }
}