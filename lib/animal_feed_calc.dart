import 'package:flutter/material.dart';

class AnimalFeedCalcPage extends StatefulWidget {
  const AnimalFeedCalcPage({super.key});
  @override
  State<AnimalFeedCalcPage> createState() => _AnimalFeedCalcPageState();
}

class _AnimalFeedCalcPageState extends State<AnimalFeedCalcPage> {
  // ទិន្នន័យរូបមន្តសម្រាប់ទម្ងន់សរុប ១០០០គីឡូ (cite: 1000058071.jpg)
  final Map<String, Map<String, double>> formulas = {
    "មាន់ពង": {
      "ពោត": 470,
      "កន្ទក់": 150,
      "សណ្តែកសៀង": 210,
      "ម្សៅសាច់ត្រី": 50,
      "ប្រេងឆា": 20,
      "អំបិល": 3,
      "ម្សៅថ្មកំបោរ": 67,
      "បុ្រលល្បាយ": 30,
    },
    "ទាពង": {
      "ពោត": 460,
      "កន្ទក់": 150,
      "សណ្តែកសៀង": 220,
      "ម្សៅសាច់ត្រី": 55,
      "ប្រេងឆា": 15,
      "អំបិល": 3,
      "ម្សៅថ្មកំបោរ": 67,
      "បុ្រលល្បាយ": 30,
    },
    "ក្រួចពង": {
      "ពោត": 440,
      "កន្ទក់": 120,
      "សណ្តែកសៀង": 270,
      "ម្សៅសាច់ត្រី": 50,
      "ប្រេងឆា": 20,
      "អំបិល": 3,
      "ម្សៅថ្មកំបោរ": 67,
      "បុ្រលល្បាយ": 30,
    },
  };

  String _selectedType = "មាន់ពង";
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    // បង្កើត Controller សម្រាប់គ្រឿងផ្សំនីមួយៗ
    formulas["មាន់ពង"]!.keys.forEach((key) {
      _controllers[key] = TextEditingController();
    });
  }

  void _updateValues(String changedKey, String value) {
    double inputVal = double.tryParse(value) ?? 0;
    if (inputVal <= 0) return;

    double baseVal = formulas[_selectedType]![changedKey]!;
    double ratio = inputVal / baseVal;

    setState(() {
      formulas[_selectedType]!.forEach((key, val) {
        if (key != changedKey) {
          _controllers[key]!.text = (val * ratio).toStringAsFixed(2);
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("ជំនួយការផ្សំចំណីសត្វ"),
        backgroundColor: Colors.orange.shade700,
      ),
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.opaque,
          child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              value: _selectedType,
              items: formulas.keys
                  .map(
                    (e) =>
                        DropdownMenuItem(value: e, child: Text("រូបមន្ត $e")),
                  )
                  .toList(),
              onChanged: (v) => setState(() {
                _selectedType = v!;
                _controllers.values.forEach((c) => c.clear());
              }),
              decoration: const InputDecoration(
                labelText: "រើសប្រភេទសត្វ",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "បញ្ចូលទម្ងន់គ្រឿងផ្សំណាមួយ (គីឡូ)៖",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const Divider(),
            ...formulas[_selectedType]!.keys
                .map((key) => _buildInput(key))
                .toList(),
          ],
        ),
      ),
        ),
    );
  }

  Widget _buildInput(String key) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: _controllers[key],
        keyboardType: TextInputType.number,
        onChanged: (v) => _updateValues(key, v),
        decoration: InputDecoration(
          labelText: key,
          suffixText: "គីឡូក្រាម",
          border: const OutlineInputBorder(),
          prefixIcon: const Icon(Icons.bakery_dining, color: Colors.orange),
        ),
      ),
    );
  }
}
