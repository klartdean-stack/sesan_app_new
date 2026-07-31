import 'package:flutter/material.dart';

class PigFeedCalcPage extends StatefulWidget {
  const PigFeedCalcPage({super.key});
  @override
  State<PigFeedCalcPage> createState() => _PigFeedCalcPageState();
}

class _PigFeedCalcPageState extends State<PigFeedCalcPage> {
  // រូបមន្តគិតជា (%) យោងតាមតារាងរូបភាព (cite: 1000058072.jpg, 1000058074.jpg)
  final Map<String, Map<String, double>> pigFormulas = {
    "កូនជ្រូកបៅដោះ": {
      "ចុងអង្ករ": 55,
      "កាកសណ្តែកសៀង": 10,
      "កាកសណ្តែកមានប្រេង": 12,
      "ទឹកដោះគោ": 10,
      "ម្សៅត្រី": 5,
      "ប្រេងឆា": 3,
      "ប្រេមិច": 9,
    },
    "ជ្រូកសាច់ (20-60kg)": {
      "មើមដំឡូងមី": 10,
      "ពោត": 20,
      "ម្សៅទឹកដោះ": 5,
      "កន្ទក់": 25,
      "ម្សៅត្រី": 4,
      "ក្បាលបង្កង": 4,
      "កាកសណ្តែកសៀង": 20,
      "កន្ទក់សណ្តែកបាយ": 10,
      "សំបកខ្យង": 1,
      "ប្រេមិច": 0.5,
    },
    "ជ្រូកសាច់ (60kg-លក់)": {
      "មើមដំឡូងមី": 15,
      "ពោត": 30,
      "កន្ទក់": 30,
      "ម្សៅត្រី": 3,
      "ក្បាលបង្កង": 3,
      "កាកសណ្តែកសៀង": 10,
      "កន្ទក់សណ្តែកបាយ": 10,
      "សំបកខ្យង": 1,
      "ប្រេមិច": 0.25,
    },
    "មេជ្រូកមានផ្ទៃពោះ": {
      "មើមដំឡូងមី": 20,
      "ពោត": 20,
      "កន្ទក់": 35,
      "ម្សៅត្រី": 2,
      "ក្បាលបង្កង": 2,
      "កាកសណ្តែកសៀង": 10,
      "កន្ទក់សណ្តែកបាយ": 12,
      "សំបកខ្យង": 1,
      "ប្រេមិច": 0.25,
    },
  };

  String _selectedType = "ជ្រូកសាច់ (20-60kg)";
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  void _initControllers() {
    _controllers.clear();
    pigFormulas[_selectedType]!.keys.forEach((key) {
      _controllers[key] = TextEditingController();
    });
  }

  void _updateValues(String changedKey, String value) {
    double inputVal = double.tryParse(value) ?? 0;
    if (inputVal <= 0) return;

    double baseVal = pigFormulas[_selectedType]![changedKey]!;
    double ratio = inputVal / baseVal;

    setState(() {
      pigFormulas[_selectedType]!.forEach((key, val) {
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
        title: const Text("ជំនួយការផ្សំចំណីជ្រូក"),
        backgroundColor: Colors.pink.shade400,
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
              items: pigFormulas.keys
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) {
                setState(() {
                  _selectedType = v!;
                  _initControllers();
                });
              },
              decoration: const InputDecoration(
                labelText: "ជ្រើសរើសប្រភេទជ្រូក",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "បញ្ចូលទម្ងន់គ្រឿងផ្សំណាមួយ (គីឡូ) ដើម្បីគណនាគ្រឿងផ្សំផ្សេងទៀត៖",
              style: TextStyle(fontSize: 12, color: Colors.blueGrey),
            ),
            const Divider(height: 30),
            ...pigFormulas[_selectedType]!.keys
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
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: _controllers[key],
        keyboardType: TextInputType.number,
        onChanged: (v) => _updateValues(key, v),
        decoration: InputDecoration(
          labelText: key,
          suffixText: "គីឡូក្រាម",
          border: const OutlineInputBorder(),
          prefixIcon: const Icon(Icons.inventory, color: Colors.pink),
        ),
      ),
    );
  }
}
