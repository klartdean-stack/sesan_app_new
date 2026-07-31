import 'package:flutter/material.dart';

class SeedCalcPage extends StatefulWidget {
  const SeedCalcPage({super.key});

  @override
  State<SeedCalcPage> createState() => _SeedCalcPageState();
}

class _SeedCalcPageState extends State<SeedCalcPage> {
  final _areaCtrl = TextEditingController();

  // --- Controllers បន្ថែមសម្រាប់ដំឡូងមី ---
  final _plantSpacingCtrl = TextEditingController(text: "60"); // cm
  final _rowSpacingCtrl = TextEditingController(text: "100"); // cm
  final _stemLengthCtrl = TextEditingController(text: "1.5"); // m
  final _cutLengthCtrl = TextEditingController(text: "20"); // cm
  final _bundleSizeCtrl = TextEditingController(text: "20"); // ដើម/បាច់

  String _selectedCrop = "ស្រូវ (ព្រួស)";
  double _resultValue = 0;
  int _resultBundles = 0; // សម្រាប់ដំឡូងមី

  final Map<String, double> cropRates = {
    "ស្រូវ (ព្រួស)": 150.0,
    "ស្រូវ (ស្ទូង)": 40.0,
    "ពោត": 25.0,
    "សណ្ដែកសៀង": 70.0,
    "សណ្ដែកបាយ": 35.0,
    "សណ្ដែកដី (គ្រាប់សុទ្ធ)": 120.0,
    "ល្ង": 8.0,
    "ដំឡូងមី (ដើមពូជ)": 0.0, // ប្រើ Logic ពិសេស
  };

  void _calculate() {
    // បំលែងអក្សរពី TextField មកជាលេខ (ការពារកុំឱ្យ Crash បើកសិករវាយខុស)
    double area = double.tryParse(_areaCtrl.text.replaceAll(',', '.')) ?? 0;

    if (area <= 0) {
      // បើអត់ទាន់ដាក់ផ្ទៃដីទេ ឱ្យវាបង្ហាញសារប្រាប់
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("សូមបញ្ចូលផ្ទៃដីជាមុនសិន!")));
      return;
    }

    setState(() {
      if (_selectedCrop == "ដំឡូងមី (ដើមពូជ)") {
        // --- 🎯 Logic ពិសេសសម្រាប់ដំឡូងមី ---
        // បំលែងពី cm ទៅជា m ភ្លាមៗដើម្បីគណនាផ្ទៃដី
        double rSpace = (double.tryParse(_rowSpacingCtrl.text) ?? 100) / 100;
        double pSpace = (double.tryParse(_plantSpacingCtrl.text) ?? 60) / 100;
        double stemL = double.tryParse(_stemLengthCtrl.text) ?? 1.5;
        double cutL = (double.tryParse(_cutLengthCtrl.text) ?? 20) / 100;
        int bundleSize = int.tryParse(_bundleSizeCtrl.text) ?? 20;

        // ១. រកចំនួនកង់ដាំសរុប (ផ្ទៃដី ១ហិកតា = ១០០០០ ម៉ែត្រការ៉េ) + បម្រុង ៥%
        double totalCuts = ((area * 10000) / (rSpace * pSpace)) * 1.05;

        // ២. រកចំនួនកង់ក្នុង ១ ដើម (floor គឺយកចំនួនគត់ដែលកាត់បានពិតប្រាកដ)
        int cutsPerStem = (stemL / cutL).floor();
        if (cutsPerStem <= 0) cutsPerStem = 1; // ការពារកុំឱ្យចែកនឹង ០

        // ៣. រកចំនួនដើមសរុប
        double totalStems = totalCuts / cutsPerStem;

        // ៤. រកចំនួនបាច់ (ceil គឺបង្គត់ឡើងលើ ព្រោះខ្វះដើមដាំមិនកើត)
        _resultBundles = (totalStems / bundleSize).ceil();
        _resultValue = totalCuts;
      } else {
        // --- 🌾 សម្រាប់ដំណាំទូទៅ ---
        _resultValue = area * (cropRates[_selectedCrop] ?? 0);
        _resultBundles = 0;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    bool isCassava = _selectedCrop == "ដំឡូងមី (ដើមពូជ)";

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "គណនាគ្រាប់ពូជ",
          style: TextStyle(fontFamily: 'Siemreap'),
        ),
        backgroundColor: Colors.green.shade800,
        foregroundColor: Colors.white,
      ),
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.opaque,
          child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildDropdown(),
            const SizedBox(height: 15),
            _buildInputField(
              _areaCtrl,
              "ផ្ទៃដីដាំដុះ (ហិកតា)",
              Icons.landscape,
            ),

            // --- 📦 ផ្នែកលោតចេញមកតែពេលរើស "ដំឡូងមី" ---
            if (isCassava) ...[
              const Divider(height: 30, thickness: 1),
              const Text(
                "⚙️ បច្ចេកទេសដាំដំឡូងមី",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildInputField(
                      _rowSpacingCtrl,
                      "ចន្លោះជួរ (cm)",
                      Icons.unfold_more,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildInputField(
                      _plantSpacingCtrl,
                      "ចន្លោះដើម (cm)",
                      Icons.unfold_less,
                    ),
                  ),
                ],
              ),
              _buildInputField(
                _stemLengthCtrl,
                "ប្រវែងដើមពូជ (m)",
                Icons.height,
              ),
              _buildInputField(
                _cutLengthCtrl,
                "ប្រវែងកង់កាត់ដាំ (cm)",
                Icons.content_cut,
              ),
              _buildInputField(
                _bundleSizeCtrl,
                "ចំនួនដើមក្នុង ១ បាច់",
                Icons.inventory_2,
              ),
            ],
            const SizedBox(height: 25),
            ElevatedButton(
              onPressed: () {
                FocusScope.of(context).unfocus();
                _calculate();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade800,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              child: Text(isCassava ? "គណនាចំនួនបាច់" : "គណនាបរិមាណពូជ"),
            ),
            if (_resultValue > 0) _buildResultWidget(isCassava),
          ],
        ),
      ),
        ),
    );
  }

  Widget _buildDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedCrop,
      decoration: InputDecoration(
        labelText: "ប្រភេទដំណាំ",
        filled: true,
        fillColor: Colors.green.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
      ),
      items: cropRates.keys
          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
          .toList(),
      onChanged: (v) => setState(() {
        _selectedCrop = v!;
        _resultValue = 0; // Reset លទ្ធផលពេលប្តូរដំណាំ
      }),
    );
  }

  Widget _buildInputField(
    TextEditingController ctrl,
    String label,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.green),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    );
  }

  Widget _buildResultWidget(bool isCassava) {
    return Container(
      margin: const EdgeInsets.only(top: 25),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isCassava ? Colors.red.shade50 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isCassava ? Colors.red.shade200 : Colors.green,
        ),
      ),
      child: Column(
        children: [
          Text(
            isCassava ? "ចំនួនបាច់ដែលត្រូវទិញចូល៖" : "បរិមាណពូជត្រូវប្រើសរុប៖",
          ),
          const SizedBox(height: 10),
          Text(
            isCassava
                ? "$_resultBundles បាច់"
                : "${_resultValue.toStringAsFixed(0)} គីឡូក្រាម",
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: isCassava ? Colors.red.shade700 : Colors.green.shade900,
            ),
          ),
          if (isCassava) ...[
            const Divider(),
            Text(
              "ស្មើនឹងប្រហែល ${_resultValue.toStringAsFixed(0)} កង់ដាំ",
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
          const SizedBox(height: 8),
          const Text(
            "*(បរិមាណនេះបានបូកបន្ថែម ៥% សម្រាប់បង្ការ)",
            style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }
}
