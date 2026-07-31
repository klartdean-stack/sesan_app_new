import 'package:flutter/material.dart';
import 'dart:math';

class WaterCalculatorPage extends StatefulWidget {
  const WaterCalculatorPage({super.key});

  @override
  State<WaterCalculatorPage> createState() => _WaterCalculatorPageState();
}

class _WaterCalculatorPageState extends State<WaterCalculatorPage> {
  // --- Controllers សម្រាប់អាងមូល ---
  final _diaTopCtrl = TextEditingController();
  final _diaBottomCtrl = TextEditingController();
  final _depthCircleCtrl = TextEditingController();
  bool _isCircleSloped = false;

  // --- Controllers សម្រាប់អាងជ្រុង ---
  final _lengthTopCtrl = TextEditingController();
  final _widthTopCtrl = TextEditingController();
  final _lengthBottomCtrl = TextEditingController();
  final _widthBottomCtrl = TextEditingController();
  final _depthRectCtrl = TextEditingController();
  bool _isRectSloped = false;

  String _resM3 = "0.00";
  String _resLiters = "0";

  // --- Logic គណនាអាងមូល ---
  void _calcCircle() {
    double R = (double.tryParse(_diaTopCtrl.text.replaceAll(',', '.')) ?? 0) / 2;
    double h = double.tryParse(_depthCircleCtrl.text.replaceAll(',', '.')) ?? 0;
    double r = _isCircleSloped
        ? (double.tryParse(_diaBottomCtrl.text.replaceAll(',', '.')) ?? 0) / 2
        : R;

    double vol = (pi * h / 3) * (pow(R, 2) + pow(r, 2) + (R * r));
    _updateResult(vol);
  }

  // --- Logic គណនាអាងជ្រុង ---
  void _calcRect() {
    double L = double.tryParse(_lengthTopCtrl.text.replaceAll(',', '.')) ?? 0;
    double W = double.tryParse(_widthTopCtrl.text.replaceAll(',', '.')) ?? 0;
    double h = double.tryParse(_depthRectCtrl.text.replaceAll(',', '.')) ?? 0;
    double l = _isRectSloped
        ? (double.tryParse(_lengthBottomCtrl.text.replaceAll(',', '.')) ?? 0)
        : L;
    double w = _isRectSloped
        ? (double.tryParse(_widthBottomCtrl.text.replaceAll(',', '.')) ?? 0)
        : W;

    double areaTop = L * W;
    double areaBottom = l * w;
    double vol = (h / 3) * (areaTop + areaBottom + sqrt(areaTop * areaBottom));
    _updateResult(vol);
  }
  void _updateResult(double volM3) {
    setState(() {
      _resM3 = volM3.toStringAsFixed(2);
      _resLiters = (volM3 * 1000).toInt().toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]},',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("គណនាបរិមាណទឹក"),
          backgroundColor: Colors.blue.shade800,
          foregroundColor: Colors.white,
          bottom: TabBar(
            // ពណ៌អក្សរពេលយើងកំពុងមើល Tab ហ្នឹង (ឱ្យពណ៌សច្បាស់)
            labelColor: Colors.white,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),

            // ពណ៌អក្សរ Tab ដែលយើងមិនទាន់ចុច (ឱ្យពណ៌ស្រាល ដើម្បីកុំឱ្យច្រឡំគ្នា)
            unselectedLabelColor: Colors.blue.shade200,
            unselectedLabelStyle: const TextStyle(fontSize: 14),

            // ពណ៌បន្ទាត់ពីក្រោម Tab ដែលកំពុងជ្រើសរើស
            indicatorColor: Colors.white,
            indicatorWeight: 3,

            tabs: [
              Tab(text: "អាងរាងមូល", icon: Icon(Icons.vignette_rounded)),
              Tab(text: "អាងរាងជ្រុង", icon: Icon(Icons.crop_square)),
            ],
          ),
        ),
        body: TabBarView(children: [_buildCirclePage(), _buildRectPage()]),
      ),
    );
  }

  Widget _buildCirclePage() {
    return GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _inputCard("ទំហំអាង/ស្រះមូល", [
            // ថែម Argument ទី៣ ជាអក្សរពន្យល់ (Hint)
            _field(
              _diaTopCtrl,
              "អង្កត់ផ្ចិតមាត់លើ (ម៉ែត្រ)",
              "វាស់ទទឹងកាត់ចំកណ្តាលមាត់ស្រះ",
            ),
            _field(
              _depthCircleCtrl,
              "ជម្រៅទឹក (ម៉ែត្រ)",
              "វាស់បញ្ឈរត្រង់ពីបាតដល់មាត់",
            ),
            SwitchListTile(
              title: const Text("មានជម្រាល (មាត់ធំបាតតូច)"),
              value: _isCircleSloped,
              onChanged: (v) => setState(() => _isCircleSloped = v),
            ),
            if (_isCircleSloped)
              _field(
                _diaBottomCtrl,
                "អង្កត់ផ្ចិតបាតក្រោម (ម៉ែត្រ)",
                "វាស់ទទឹងផ្ទៃបាតខាងក្រោមបង្អស់",
              ),
          ]),
          const SizedBox(height: 10),
          _btn("គណនាបរិមាណ", _calcCircle),
          _resultBox(),
        ],
      ),
        ),
    );
  }

  Widget _buildRectPage() {
    return GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _inputCard("ទំហំអាង/ស្រះជ្រុង", [
            Row(
              children: [
                // បន្ថែម Argument ទី៣ ជាអក្សរពន្យល់ (Hint)
                Expanded(
                  child: _field(
                    _lengthTopCtrl,
                    "បណ្តោយមាត់លើ (ម)",
                    "វាស់ជ្រុងវែងនៃមាត់ស្រះ",
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _field(
                    _widthTopCtrl,
                    "ទទឹងមាត់លើ (ម)",
                    "វាស់ជ្រុងខ្លីនៃមាត់ស្រះ",
                  ),
                ),
              ],
            ),
            _field(
              _depthRectCtrl,
              "ជម្រៅទឹក (ម៉ែត្រ)",
              "វាស់បញ្ឈរត្រង់ពីបាតឡើងលើ",
            ),
            SwitchListTile(
              title: const Text("មានជម្រាល (បាតតូចជាងមាត់)"),
              value: _isRectSloped,
              onChanged: (v) => setState(() => _isRectSloped = v),
            ),
            if (_isRectSloped)
              Row(
                children: [
                  Expanded(
                    child: _field(
                      _lengthBottomCtrl,
                      "បណ្តោយបាត (ម)",
                      "វាស់បណ្តោយផ្ទៃបាតក្រោម",
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _field(
                      _widthBottomCtrl,
                      "ទទឹងបាត (ម)",
                      "វាស់ទទឹងផ្ទៃបាតក្រោម",
                    ),
                  ),
                ],
              ),
          ]),
          const SizedBox(height: 10),
          _btn("គណនាបរិមាណ", _calcRect),
          _resultBox(),
        ],
      ),
        ),
    );
  }

  Widget _inputCard(String title, List<Widget> children) {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade900,
              ),
            ),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, String hint) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: ctrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: label,
          hintText: "ឧទាហរណ៍៖ ៥.០",
          helperText: hint, // អក្សរពន្យល់តូចៗនៅខាងក្រោមប្រអប់
          helperStyle: const TextStyle(color: Colors.blueGrey),
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
        ),
      ),
    );
  }

  Widget _btn(String txt, VoidCallback press) {
    return ElevatedButton(
      onPressed: () {
        FocusScope.of(context).unfocus();
        press();
      },
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 50),
        backgroundColor: Colors.blue.shade800,
      ),
      child: Text(
        txt,
        style: const TextStyle(color: Colors.white, fontSize: 18),
      ),
    );
  }

  Widget _resultBox() {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        children: [
          _resRow("បរិមាណទឹកសរុប", _resM3, "ម៉ែត្រគុប (m³)"),
          const Divider(),
          _resRow(
            "បរិមាណទឹកសរុប",
            _resLiters,
            "លីត្រ (Liters)",
            isHighlight: true,
          ),
        ],
      ),
    );
  }

  Widget _resRow(
    String label,
    String val,
    String unit, {
    bool isHighlight = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              val,
              style: TextStyle(
                fontSize: isHighlight ? 24 : 18,
                fontWeight: FontWeight.bold,
                color: isHighlight ? Colors.blue.shade900 : Colors.black,
              ),
            ),
            Text(
              unit,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ],
    );
  }
}
