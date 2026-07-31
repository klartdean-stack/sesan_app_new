import 'package:flutter/material.dart';

class FenceCalcPage extends StatefulWidget {
  const FenceCalcPage({super.key});

  @override
  State<FenceCalcPage> createState() => _FenceCalcPageState();
}

class _FenceCalcPageState extends State<FenceCalcPage> {
  // ១. បន្ថែមជម្រើសប្រភេទរបង
  int selectedType = 0; // 0: របងបង្គោលឈើ, 1: របងជញ្ជាំងឥដ្ឋ

  // Controllers
  final lengthController = TextEditingController();
  final spacingController = TextEditingController(); // សម្រាប់របងឈើ
  final heightController = TextEditingController(); // សម្រាប់របងជញ្ជាំង
  final layerController = TextEditingController(); // ចំនួនជាន់ខ្សែលួស

  // Controllers សម្រាប់តម្លៃលុយ
  final postPriceCtrl = TextEditingController();
  final wirePriceCtrl = TextEditingController();
  final brickPriceCtrl = TextEditingController();
  final cementPriceCtrl = TextEditingController();

  // លទ្ធផលគណនា
  double resPost = 0, resWire = 0, resNails = 0; // របងឈើ
  double resBrick = 0, resCement = 0, resSand = 0; // របងជញ្ជាំង
  double totalMoney = 0;

  void calculateAll() {
    double totalLength = double.tryParse(lengthController.text.replaceAll(',', '.')) ?? 0;
    if (totalLength <= 0) return;

    setState(() {
      totalMoney = 0; // Reset លុយ
      if (selectedType == 0) {
        // --- Logic របងបង្គោលឈើ ---
        double spacing = double.tryParse(spacingController.text.replaceAll(',', '.')) ?? 2.5;
        int layers = int.tryParse(layerController.text.replaceAll(',', '.')) ?? 4;

        resPost = (totalLength / spacing) + 1;
        resWire = totalLength * layers;
        resNails = resPost * layers; // ដែកគោលមេអំបៅ

        // គណនាលុយបើមានបញ្ចូលតម្លៃ
        double pPrice = double.tryParse(postPriceCtrl.text.replaceAll(',', '.')) ?? 0;
        double wPrice =
            double.tryParse(wirePriceCtrl.text.replaceAll(',', '.')) ?? 0; // តម្លៃក្នុង ១ ម៉ែត្រ
        totalMoney = (resPost * pPrice) + (resWire * wPrice);
      } else {
        // --- Logic របងជញ្ជាំងឥដ្ឋ ---
        double height = double.tryParse(heightController.text.replaceAll(',', '.')) ?? 0;
        double area = totalLength * height;

        resBrick = area * 65; // ៦៥ ដុំ/ម២
        resCement = area * 0.25; // ០.២៥ បាវ/ម២
        resSand = area * 0.05; // ០.០៥ ម៉ែត្រគូប/ម២

        // គណនាលុយបើមានបញ្ចូលតម្លៃ
        double bPrice = double.tryParse(brickPriceCtrl.text.replaceAll(',', '.')) ?? 0;
        double cPrice = double.tryParse(cementPriceCtrl.text.replaceAll(',', '.')) ?? 0;
        totalMoney = (resBrick * bPrice) + (resCement * cPrice);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'គណនារបង',
          style: TextStyle(fontFamily: 'Siemreap'),
        ),
        backgroundColor: Colors.green.shade700,
      ),
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.opaque,
          child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 🎯 ផ្នែករើសប្រភេទរបង
            Row(
              children: [
                _typeButton(0, "របងបង្គោលឈើ", Icons.fence),
                const SizedBox(width: 10),
                _typeButton(
                  1,
                  "របងជញ្ជាំងឥដ្ឋ",
                  Icons.foundation,
                ), // ប្ដូរមកប្រើ Icon នេះវិញមេ
              ],
            ),
            const SizedBox(height: 20),

            _buildInput(
              'ប្រវែងរបងសរុប (ម៉ែត្រ)',
              Icons.straighten,
              lengthController,
            ),

            // បង្ហាញ Input តាមប្រភេទរបង
            if (selectedType == 0) ...[
              _buildInput(
                'ចម្ងាយបង្គោល (ម៉ែត្រ)',
                Icons.space_bar,
                spacingController,
              ),
              _buildInput('ចំនួនជាន់ខ្សែលួស', Icons.layers, layerController),
              const Divider(),
              _buildInput(
                'តម្លៃបង្គោល ១ដើម (៛)',
                Icons.attach_money,
                postPriceCtrl,
              ),
              _buildInput(
                'តម្លៃខ្សែលួស ១ម៉ែត្រ (៛)',
                Icons.money,
                wirePriceCtrl,
              ),
            ] else ...[
              _buildInput(
                'កម្ពស់ជញ្ជាំង (ម៉ែត្រ)',
                Icons.height,
                heightController,
              ),
              const Divider(),
              _buildInput('តម្លៃឥដ្ឋ ១ដុំ (៛)', Icons.grid_on, brickPriceCtrl),
              _buildInput(
                'តម្លៃស៊ីម៉ងត៍ ១បាវ (៛)',
                Icons.shopping_bag,
                cementPriceCtrl,
              ),
            ],
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                FocusScope.of(context).unfocus();
                calculateAll();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text(
                'គណនា និងសរុបលុយ',
                style: TextStyle(color: Colors.white),
              ),
            ),

            const SizedBox(height: 20),
            _buildResultCard(),
            const SizedBox(height: 100),
          ],
        ),
      ),
        ),
    );
  }

  Widget _typeButton(int index, String label, IconData icon) {
    bool isSelected = selectedType == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => selectedType = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.green.shade700 : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? Colors.white : Colors.black54),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black54,
                  fontSize: 12,
                ),
              ),
            ],
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
        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: false),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.green.shade700),
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '📊 លទ្ធផលប៉ាន់ស្មាន',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          if (selectedType == 0) ...[
            _resRow("ចំនួនបង្គោលឈើ", "${resPost.toInt()} ដើម"),
            _resRow("ខ្សែលួសសរុប", "${resWire.toInt()} ម៉ែត្រ"),
            _resRow("ដែកគោលមេអំបៅ", "${resNails.toInt()} គ្រាប់"),
          ] else ...[
            _resRow("ចំនួនឥដ្ឋ", "${resBrick.toInt()} ដុំ"),
            _resRow("ស៊ីម៉ងត៍", "${resCement.toStringAsFixed(1)} បាវ"),
            _resRow("ខ្សាច់", "${resSand.toStringAsFixed(2)} ម៉ែត្រគូប"),
          ],
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "💰 ទឹកប្រាក់សរុប:",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(
                "${_formatMoney(totalMoney)} ៛",
                style: const TextStyle(
                  fontSize: 22,
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  String _formatMoney(double value) {
    if (value == 0) return "0";
    final intVal = value.toInt();
    return intVal.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
    );
  }

  Widget _resRow(String t, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(t),
          Text(v, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
