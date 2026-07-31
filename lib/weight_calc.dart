import 'package:flutter/material.dart';

class AnimalWeightPage extends StatefulWidget {
  const AnimalWeightPage({super.key});

  @override
  State<AnimalWeightPage> createState() => _AnimalWeightPageState();
}

class _AnimalWeightPageState extends State<AnimalWeightPage> {
  final _girthCtrl = TextEditingController();
  final _lengthCtrl = TextEditingController();
  String _selectedAnimal = "គោ";
  double _totalWeight = 0;
  double _meatWeight = 0;
  double _boneWeight = 0;
  bool _isLoading = false; // 🎯 ថែមអាហ្នឹងសម្រាប់ Loading

  // មុខងារគណនា
  void _calculate() {
    setState(() {
      _isLoading = true; // 🎯 បង្ហាញ Loading
    });

    double g = double.tryParse(_girthCtrl.text) ?? 0;
    double l = double.tryParse(_lengthCtrl.text) ?? 0;

    if (g == 0 || l == 0) {
      setState(() {
        _isLoading = false; // 🎯 បិទ Loading
      });
      return;
    }

    // ១. កំណត់មេគុណចែក (Divisor) តាមប្រភេទសត្វ
    double divisor = 10838; // គោ (Default)
    double meatPercent = 0.40; // សាច់សុទ្ធ ៤០%
    double bonePercent = 0.15; // ឆ្អឹង ១៥%

    if (_selectedAnimal == "ក្របី") {
      divisor = 10000;
      meatPercent = 0.42;
    } else if (_selectedAnimal == "ជ្រូក") {
      divisor = 14400;
      meatPercent = 0.55;
    } else if (_selectedAnimal == "សេះ") {
      divisor = 11877;
      meatPercent = 0.35;
    } else if (_selectedAnimal == "ពពែ/ចៀម") {
      divisor = 11500;
      meatPercent = 0.35;
    }

    // 🎯 ប្រើ Future.delayed ដើម្បីឱ្យឃើញ Animation Loading បន្តិច
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          // ២. គណនាទម្ងន់រស់សរុប (Live Weight)
          _totalWeight = (g * g * l) / divisor;

          // ៣. គណនាបំបែកសាច់ និងឆ្អឹង
          _meatWeight = _totalWeight * meatPercent;
          _boneWeight = _totalWeight * bonePercent;
          _isLoading = false; // 🎯 បិទ Loading ពេលគណនារួច
        });
        // 🎯 បិទ Keyboard ក្រោយពេលគណនារួច
        FocusScope.of(context).unfocus();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "ជញ្ជីងប៉ាន់ស្មានទម្ងន់",
          style: TextStyle(fontFamily: 'Siemreap'),
        ),
        backgroundColor: Colors.orange.shade900,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // 🎯 ១. ថែមរូបភាពបង្ហាញរបៀបវាស់ (Visual Guide)
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Column(
                children: [
                  Image.asset(
                    'assets/measure_guide.png', // 🎯 មេត្រូវដាក់រូបភាពក្នុង assets
                    height: 120,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "របៀបវាស់៖ ទំហំទ្រូង (វាស់ជុំវិញទ្រូងក្រោយជើងមុខ) និង ប្រវែងដងខ្លួន (វាស់ពីស្មាដល់គល់កន្ទុយ)",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.orange),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 25),

            // ជ្រើសរើសសត្វ
            DropdownButtonFormField<String>(
              value: _selectedAnimal,
              decoration: const InputDecoration(
                labelText: "ប្រភេទសត្វ",
                border: OutlineInputBorder(),
              ),
              items: [
                "គោ",
                "ក្របី",
                "ជ្រូក",
                "សេះ",
                "ពពែ/ចៀម",
              ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() => _selectedAnimal = v!),
            ),
            const SizedBox(height: 20),

            // ប្រអប់បញ្ចូលរង្វាស់
            TextField(
              controller: _girthCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ), // 🎯 កែឱ្យស្គាល់លេខក្បៀស
              decoration: const InputDecoration(
                labelText: "ទំហំទ្រូង (សង់ទីម៉ែត្រ)",
                hintText: "ឧទាហរណ៍៖ 150.5",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.straighten),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _lengthCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ), // 🎯 កែឱ្យស្គាល់លេខក្បៀស
              decoration: const InputDecoration(
                labelText: "ប្រវែងដងខ្លួន (សង់ទីម៉ែត្រ)",
                hintText: "ឧទាហរណ៍៖ 120.0",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.straighten),
              ),
            ),
            const SizedBox(height: 25),

            // 🎯 ២. ប៊ូតុងគណនាជាមួយ Loading (Progress Indicator)
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _calculate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade900,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 25,
                        height: 25,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 3,
                        ),
                      )
                    : const Text(
                        "គណនាទម្ងន់ឥឡូវនេះ",
                        style: TextStyle(fontSize: 18),
                      ),
              ),
            ),

            // បង្ហាញលទ្ធផល
            if (_totalWeight > 0) _buildResultSection(),

            const SizedBox(height: 30),

            // 🎯 ៣. ថែមកាតព័ត៌មានបន្ថែម (Tips)
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "💡 កំណត់សំគាល់ និងការណែនាំ៖",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 10),
                  Text(
                    "• លទ្ធផលនេះគ្រាន់តែជាការប៉ាន់ស្មានប៉ុណ្ណោះ សូមផ្ទៀងផ្ទាត់ជាមួយជញ្ជីងពិតប្រាកដមុននឹងទិញលក់។",
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  Text(
                    "• ដើម្បីវាស់បានត្រឹមត្រូវ សូមឱ្យសត្វឈរត្រង់ និងវាស់ឱ្យណែនបន្តិច。",
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultSection() {
    return Column(
      children: [
        const SizedBox(height: 30),
        const Text(
          "លទ្ធផលនៃការប៉ាន់ស្មាន",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),

        // កាតទម្ងន់សរុប
        _resultCard(
          "ទម្ងន់រស់សរុប",
          "${_totalWeight.toStringAsFixed(1)} គីឡូក្រាម",
          Colors.orange.shade900,
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            // កាតសាច់សុទ្ធ
            Expanded(
              child: _resultCard(
                "សាច់សុទ្ធ (ប្រហែល)",
                "${_meatWeight.toStringAsFixed(1)} គីឡូ",
                Colors.red,
              ),
            ),
            const SizedBox(width: 15),
            // កាតឆ្អឹង
            Expanded(
              child: _resultCard(
                "ឆ្អឹង (ប្រហែល)",
                "${_boneWeight.toStringAsFixed(1)} គីឡូ",
                Colors.blueGrey,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _resultCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 2),
      ),
      child: Column(
        children: [
          Text(title, style: TextStyle(fontSize: 12, color: color)),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
