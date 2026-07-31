import 'package:flutter/material.dart';

class ElectricCalcPage extends StatefulWidget {
  const ElectricCalcPage({super.key});

  @override
  State<ElectricCalcPage> createState() => _ElectricCalcPageState();
}

class _ElectricCalcPageState extends State<ElectricCalcPage> {
  final distanceController = TextEditingController();
  final wattController = TextEditingController();
  final wirePriceCtrl = TextEditingController();
  final breakerPriceCtrl = TextEditingController();
  final postPriceCtrl = TextEditingController(); // តម្លៃបង្គោល

  double wireSize = 0, totalAmps = 0, vDrop = 0, finalVoltage = 220;
  double recommendedBreaker = 0, totalCost = 0;
  int postCount = 0;

  void calculateAll() {
    double distance = double.tryParse(distanceController.text) ?? 0;
    double watts = double.tryParse(wattController.text) ?? 0;

    if (distance > 0 && watts > 0) {
      setState(() {
        totalAmps = watts / 220;

        // គណនាទំហំខ្សែតាមចរន្ត
        if (totalAmps <= 12)
          wireSize = 1.5;
        else if (totalAmps <= 16)
          wireSize = 2.5;
        else if (totalAmps <= 25)
          wireSize = 4.0;
        else
          wireSize = 6.0;

        // គណនាការធ្លាក់វ៉ុល
        vDrop = (totalAmps * distance * 0.037) / wireSize;
        finalVoltage = 220 - vDrop;
        recommendedBreaker = totalAmps * 1.25;

        // គណនាចំនួនបង្គោល (ចម្ងាយ ៣០ម៉ែត្រមួយ)
        postCount = (distance / 30).ceil() + 1;

        // គណនាថ្លៃដើម
        double wPrice = double.tryParse(wirePriceCtrl.text) ?? 0;
        double bPrice = double.tryParse(breakerPriceCtrl.text) ?? 0;
        double pPrice = double.tryParse(postPriceCtrl.text) ?? 0;
        totalCost = (distance * wPrice) + bPrice + (postCount * pPrice);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'វិស្វករអគ្គិសនី',
          style: TextStyle(fontFamily: 'Siemreap'),
        ),
        backgroundColor: Colors.orange.shade900,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.orange.shade900, Colors.orange.shade50],
            stops: const [0.1, 0.3],
          ),
        ),
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.opaque,
          child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 5,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _buildInput(
                        "ចម្ងាយខ្សែ (ម៉ែត្រ)",
                        Icons.settings_ethernet,
                        distanceController,
                      ),
                      _buildInput(
                        "កម្លាំងវ៉ាត់សរុប (Watt)",
                        Icons.bolt,
                        wattController,
                      ),
                      const Divider(),
                      _buildInput(
                        "តម្លៃខ្សែ/ម៉ែត្រ (៛)",
                        Icons.money,
                        wirePriceCtrl,
                      ),
                      _buildInput(
                        "តម្លៃបង្គោល/ដើម (៛)",
                        Icons.fence,
                        postPriceCtrl,
                      ),
                      _buildInput(
                        "តម្លៃឌីសង់ទ័រ (៛)",
                        Icons.security,
                        breakerPriceCtrl,
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: () {
                          FocusScope.of(context).unfocus();
                          calculateAll();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade900,
                          minimumSize: const Size(double.infinity, 55),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        child: const Text(
                          'គណនាគ្រឿងបន្លាស់ និងតម្លៃ',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 25),
              if (totalAmps > 0) _buildResultCard(),
              const SizedBox(height: 50),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildInput(String label, IconData icon, TextEditingController ctrl) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.orange.shade900),
          filled: true,
          fillColor: Colors.grey.shade100,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    bool isUnsafe = finalVoltage < 190;
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(25),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(25),
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
          ),
          child: Column(
            children: [
              const Text(
                "🛠️ គ្រឿងបន្លាស់ដែលត្រូវប្រើ",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 15),
              _resRow(
                "ទំហំខ្សែកាប:",
                "${wireSize.toStringAsFixed(1)} mm²",
                Colors.blue.shade800,
              ),
              _resRow("ចំនួនបង្គោលភ្លើង:", "$postCount ដើម", Colors.brown),
              _resRow(
                "ឌីសង់ទ័រ (Breaker):",
                "${recommendedBreaker.toStringAsFixed(0)} A",
                Colors.purple,
              ),
              const Divider(height: 30),

              // បង្ហាញស្ថានភាពភ្លើង
              Text(
                "ភ្លើងនៅចុងខ្សែ",
                style: TextStyle(color: Colors.grey.shade600),
              ),
              Text(
                "${finalVoltage.toStringAsFixed(0)}V",
                style: TextStyle(
                  fontSize: 45,
                  fontWeight: FontWeight.bold,
                  color: isUnsafe ? Colors.red : Colors.green,
                ),
              ),

              if (isUnsafe)
                Container(
                  margin: const EdgeInsets.only(top: 10),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    "⚠️ គ្រោះថ្នាក់៖ ភ្លើងខ្សោយពេក ម៉ូទ័រអាចនឹងឆេះ!",
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),

              const Divider(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "💰 ចំណាយសរុប:",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    "${totalCost.toStringAsFixed(0)} ៛",
                    style: const TextStyle(
                      fontSize: 24,
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _resRow(String t, String v, Color c) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(t, style: const TextStyle(fontSize: 15)),
          Text(
            v,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: c,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
