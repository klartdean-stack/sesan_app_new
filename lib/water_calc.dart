import 'package:flutter/material.dart';

class IrrigationCalcPage extends StatefulWidget {
  const IrrigationCalcPage({super.key});

  @override
  State<IrrigationCalcPage> createState() => _IrrigationCalcPageState();
}

class _IrrigationCalcPageState extends State<IrrigationCalcPage> {
  final _widthCtrl = TextEditingController(text: "50"); // ទទឹងដី (m)
  final _lengthCtrl = TextEditingController(text: "100"); // បណ្តោយដី (m)
  final _rowSpaceCtrl = TextEditingController(text: "1.2"); // ចន្លោះជួរ (m)
  final _plantSpaceCtrl = TextEditingController(text: "0.6"); // ចន្លោះដើម (m)

  // លទ្ធផលគណនា
  int _totalRows = 0;
  double _mainPipe = 0;
  double _lateralPipe = 0;
  int _drippers = 0;
  int _valves = 0; // ដឺមី
  int _elbows = 0; // កែង
  int _connectors = 0; // កាវស៊ក

  void _calculate() {
    double w = double.tryParse(_widthCtrl.text) ?? 0;
    double l = double.tryParse(_lengthCtrl.text) ?? 0;
    double rs = double.tryParse(_rowSpaceCtrl.text) ?? 1;
    double ps = double.tryParse(_plantSpaceCtrl.text) ?? 1;

    if (w > 0 && l > 0) {
      setState(() {
        _totalRows = (w / rs).floor(); // ចំនួនជួរ
        _mainPipe = w; // ទុយោមេ
        _lateralPipe = l * _totalRows; // ទុយោកូន (ប្រវែងជួរ x ចំនួនជួរ)
        _drippers = (_lateralPipe / ps).floor(); // ចំនួនក្បាលដំណក់
        _valves = _totalRows; // ដឺមីបិទបើកតាមជួរ
        _elbows = _totalRows; // កែងនៅចុងជួរ
        _connectors = _totalRows; // កាវស៊កភ្ជាប់ទុយោមេទៅកូន
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("គណនាប្រព័ន្ធទឹកកសិកម្ម"),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
      ),
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.opaque,
          child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildInputSection(),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                FocusScope.of(context).unfocus();
                _calculate();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[800],
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text(
                "គណនាគ្រឿងបន្លាស់",
                style: TextStyle(color: Colors.white),
              ),
            ),
            const SizedBox(height: 20),
            if (_lateralPipe > 0) _buildResultSection(),
          ],
        ),
      ),
        ),
    );
  }

  Widget _buildInputSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: _buildField(_widthCtrl, "ទទឹងដី (m)")),
                const SizedBox(width: 10),
                Expanded(child: _buildField(_lengthCtrl, "បណ្តោយ (m)")),
              ],
            ),
            Row(
              children: [
                Expanded(child: _buildField(_rowSpaceCtrl, "ចន្លោះជួរ (m)")),
                const SizedBox(width: 10),
                Expanded(child: _buildField(_plantSpaceCtrl, "ចន្លោះដើម (m)")),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController ctrl, String label) {
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: label),
    );
  }

  Widget _buildResultSection() {
    return Column(
      children: [
        _resultTile(
          "ទុយោមេ (Main)",
          "${_mainPipe.toStringAsFixed(1)} ម៉ែត្រ",
          Icons.line_weight,
        ),
        _resultTile(
          "ទុយោកូន (Lateral)",
          "${_lateralPipe.toStringAsFixed(1)} ម៉ែត្រ",
          Icons.linear_scale,
        ),
        _resultTile("ចំនួនជួរ", "$_totalRows ជួរ", Icons.reorder),
        const Divider(),
        _resultTile(
          "វ៉ាន/ដឺមី (Valves)",
          "$_valves គ្រាប់",
          Icons.settings_input_component,
        ),
        _resultTile("កែង (Elbows)", "$_elbows គ្រាប់", Icons.square_foot),
        _resultTile(
          "កាវស៊ក/តំណ",
          "$_connectors គ្រាប់",
          Icons.add_circle_outline,
        ),
        _resultTile("ក្បាលដំណក់", "$_drippers គ្រាប់", Icons.water_drop),
      ],
    );
  }

  Widget _resultTile(String title, String value, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: Colors.blue),
      title: Text(title),
      trailing: Text(
        value,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
    );
  }
}
