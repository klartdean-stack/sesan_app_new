import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // ✅ បន្ថែម

class CompostCalcPage extends StatefulWidget {
  const CompostCalcPage({super.key});
  @override
  State<CompostCalcPage> createState() => _CompostCalcPageState();
}

class _CompostCalcPageState extends State<CompostCalcPage> {
  final Map<String, Map<String, dynamic>> formulas = {
    "រូបមន្តផលិតជីកំប៉ុស្តគោក": {
      'cow': 50.0,
      'husk': 10.0,
      'chicken': 30.0,
      'leaf': 10.0,
      'water': 0.0, // ✅ មិនប្រើទឹក
      'ph': 5.93,
      'n': 2.28,
      'p': 4.58,
      'k': 0.97,
    },
    "រូបមន្តផលិតជីកំប៉ុស្តទឹក": {
      'cow': 40.0,
      'husk': 0.0,
      'chicken': 50.0,
      'leaf': 10.0,
      'water': 200.0, // ✅ បន្ថែមទឹក 200 លីត្រ
      'ph': 8.20,
      'n': 3.30,
      'p': 2.44,
      'k': 2.08,
    },
  };

  String _selectedFormula = "រូបមន្តផលិតជីកំប៉ុស្តគោក";
  final _cowCtrl = TextEditingController();
  final _huskCtrl = TextEditingController();
  final _chickenCtrl = TextEditingController();
  final _leafCtrl = TextEditingController();
  final _waterCtrl = TextEditingController(); // ✅ បន្ថែម
  double _resPH = 0, _resN = 0, _resP = 0, _resK = 0;

  // ✅ មុខងារដក comma
  double _parseNumber(String text) {
    String clean = text.replaceAll(',', '');
    return double.tryParse(clean) ?? 0;
  }
  void _updateValues(String field, String value) {
    double inputVal = _parseNumber(value);
    var f = formulas[_selectedFormula]!;

    if (f[field] == 0) return;
    if (inputVal <= 0) return;

    double ratio = inputVal / f[field];

    setState(() {
      if (field != 'cow' && f['cow'] > 0)
        _cowCtrl.text = (f['cow'] * ratio).toStringAsFixed(1);
      if (field != 'husk' && f['husk'] > 0)
        _huskCtrl.text = (f['husk'] * ratio).toStringAsFixed(1);
      if (field != 'chicken' && f['chicken'] > 0)
        _chickenCtrl.text = (f['chicken'] * ratio).toStringAsFixed(1);
      if (field != 'leaf' && f['leaf'] > 0)
        _leafCtrl.text = (f['leaf'] * ratio).toStringAsFixed(1);
      // ✅ បន្ថែមទឹក
      if (field != 'water' && f['water'] > 0)
        _waterCtrl.text = (f['water'] * ratio).toStringAsFixed(1);

      _resPH = f['ph'];
      _resN = f['n'];
      _resP = f['p'];
      _resK = f['k'];
    });
  }

  List<Map<String, dynamic>> _getVisibleFields() {
    var f = formulas[_selectedFormula]!;
    List<Map<String, dynamic>> fields = [];

    if (f['cow'] > 0) {
      fields.add({
        'key': 'cow',
        'label': 'លាមកគោស្ងួត (គីឡូ)',
        'ctrl': _cowCtrl,
      });
    }
    if (f['husk'] > 0) {
      fields.add({
        'key': 'husk',
        'label': 'អង្កាម/កន្ទក់ (គីឡូ)',
        'ctrl': _huskCtrl,
      });
    }
    if (f['chicken'] > 0) {
      fields.add({
        'key': 'chicken',
        'label': 'លាមកមាន់/ជ្រូក (គីឡូ)',
        'ctrl': _chickenCtrl,
      });
    }
    if (f['leaf'] > 0) {
      fields.add({
        'key': 'leaf',
        'label': 'ស្លឹកឈើស្រស់ (គីឡូ)',
        'ctrl': _leafCtrl,
      });
    }
    // ✅ បន្ថែមទឹក
    if (f['water'] > 0) {
      fields.add({
        'key': 'water',
        'label': 'ទឹកស្អាត (លីត្រ)',
        'ctrl': _waterCtrl,
      });
    }
    return fields;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text("ម៉ាស៊ីនគណនាជីកំប៉ុស្ត"),
          backgroundColor: Colors.brown.shade700,
        ),
        body: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            behavior: HitTestBehavior.opaque,
            child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                    children: [
                    DropdownButtonFormField<String>(
                    value: _selectedFormula,
                    items: formulas.keys
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                      onChanged: (v) => setState(() {
                        _selectedFormula = v!;
                        _cowCtrl.clear();
                        _huskCtrl.clear();
                        _chickenCtrl.clear();
                        _leafCtrl.clear();
                        _waterCtrl.clear(); // ✅ បន្ថែម
                        _resPH = 0;
                        _resN = 0;
                        _resP = 0;
                        _resK = 0;
                      }),
                      decoration: const InputDecoration(
                        labelText: "រើសប្រភេទរូបមន្ត",
                        border: OutlineInputBorder(),
                      ),
                    ),
                      const SizedBox(height: 20),
                      // ✅ បង្ហាញតែ fields ដែលមានតម្លៃ > 0
                      ..._getVisibleFields().map((field) {
                        return _buildInput(
                          field['ctrl'],
                          field['label'],
                          field['key'],
                        );
                      }).toList(),
                      if (_resN > 0) _buildResultCard(),
                    ],
                ),
            ),
        ),
    );
  }

  Widget _buildInput(TextEditingController ctrl, String label, String field) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        // ✅ អនុញ្ញាតទសភាគ
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (v) => _updateValues(field, v),
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    double cow = _parseNumber(_cowCtrl.text);
    double husk = _parseNumber(_huskCtrl.text);
    double chicken = _parseNumber(_chickenCtrl.text);
    double leaf = _parseNumber(_leafCtrl.text);
    double water = _parseNumber(_waterCtrl.text); // ✅ បន្ថែម

    double totalWeight = cow + husk + chicken + leaf + water; // ✅ បូកទឹកចូល

    // ✅ គណនាសារធាតុចិញ្ចឹម (គិតតែគ្រឿងផ្សំស្ងួត មិនរាប់ទឹក)
    double dryWeight = cow + husk + chicken + leaf;
    double weightN = (dryWeight * _resN) / 100;
    double weightP = (dryWeight * _resP) / 100;
    double weightK = (dryWeight * _resK) / 100;

    final NumberFormat numberFormat = NumberFormat("#,###.0", "en_US");
    final NumberFormat decimalFormat = NumberFormat("#,###.00", "en_US");

    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.green.shade50, Colors.white]),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.green.shade300),
      ),
      child: Column(
        children: [
          Text(
            "លទ្ធផលសម្រាប់ជីសរុប៖ ${numberFormat.format(totalWeight)} ${_selectedFormula.contains('ទឹក') ? 'លីត្រ' : 'គីឡូ'}",
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.brown,
            ),
          ),
          const Divider(),
          // ✅ បង្ហាញបរិមាណទឹកប្រសិនបើមាន
          if (_selectedFormula.contains('ទឹក') && water > 0)
            _resItem(
              "បរិមាណទឹកសរុប៖",
              "${numberFormat.format(water)} លីត្រ",
              Colors.blue,
            ),
          _resItem(
            "អាសូត (N) ទទួលបាន៖",
            "${decimalFormat.format(weightN)} គីឡូ",
            Colors.orange,
          ),
          _resItem(
            "ផូស្វ័រ (P) ទទួលបាន៖",
            "${decimalFormat.format(weightP)} គីឡូ",
            Colors.blue,
          ),
          _resItem(
            "ប៉ូតាស្យូម (K) ទទួលបាន៖",
            "${decimalFormat.format(weightK)} គីឡូ",
            Colors.red,
          ),
          const Divider(),
          Text(
            "កម្រិត pH: ${_resPH.toStringAsFixed(2)}",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _resItem(String label, String val, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            val,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}