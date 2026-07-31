import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:my_app/sack_history_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SackWeigherScreen extends StatefulWidget {
  const SackWeigherScreen({super.key});

  @override
  State<SackWeigherScreen> createState() => _SackWeigherScreenState();
}

class _SackWeigherScreenState extends State<SackWeigherScreen> {
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  List<double> _sacks = [];
  double _unitPrice = 0;
  String _currency = "៛";

  // 🎯 Logic គណនាសរុប
  double get _totalWeight => _sacks.fold(0, (sum, item) => sum + item);
  double get _totalMoney => _totalWeight * _unitPrice;
  String _formatNumber(double value) {
    if (value == 0) return "0";
    final parts = value.toStringAsFixed(2).split('.');
    final intPart = parts[0].replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
    );
    return parts.length > 1 ? '$intPart.${parts[1]}' : intPart;
  }

  // 🎯 Function សម្រាប់បន្ថែមបាវ
  void _addSack() {
    double weight = double.tryParse(_weightController.text.replaceAll(',', '.')) ?? 0;
    if (weight > 0) {
      setState(() {
        _sacks.insert(0, weight);
        _weightController.clear();
      });
    }
  }

  // 🎯 Function សម្រាប់លុបបាវ
  void _removeSack(int index) {
    setState(() => _sacks.removeAt(index));
  }

  // 🎯 Function សម្រាប់កែប្រែទម្ងន់បាវ
  void _editSack(int index) {
    _weightController.text = _sacks[index].toString();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          "កែប្រែទម្ងន់",
          style: TextStyle(fontFamily: 'Siemreap'),
        ),
        content: TextField(
          controller: _weightController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: false),
          autofocus: true,
          decoration: const InputDecoration(suffixText: "គីឡូ"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("បោះបង់"),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _sacks[index] =
                    double.tryParse(_weightController.text.replaceAll(',', '.')) ?? _sacks[index];
                _weightController.clear();
              });
              Navigator.pop(context);
            },
            child: const Text("រក្សាទុក"),
          ),
        ],
      ),
    );
  }

  // 🎯 Function បង្ហាញផ្ទាំងដាក់ឈ្មោះបញ្ជីមុននឹង Save
  void _showSaveDialog() {
    if (_sacks.isEmpty) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          "បញ្ចូលចំណងជើងបញ្ជី",
          style: TextStyle(fontFamily: 'Siemreap'),
        ),
        content: TextField(
          controller: _noteController,
          decoration: const InputDecoration(hintText: "ឧទាហរណ៍៖ បញ្ជីពូដារ៉ា"),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("បោះបង់"),
          ),
          ElevatedButton(
            onPressed: () {
              String note = _noteController.text.trim();
              _saveDataToFirestore(note.isEmpty ? "បញ្ជីគ្មានឈ្មោះ" : note);
              _noteController.clear();
              Navigator.pop(context);
            },
            child: const Text("រក្សាទុក"),
          ),
        ],
      ),
    );
  }
  String? _sellerId;

  @override
  void initState() {
    super.initState();
    _loadSellerId();
  }

  Future<void> _loadSellerId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _sellerId = prefs.getString('user_uid');
    });
  }

  // 🎯 Function រក្សាទុកទិន្នន័យទៅ Firebase
  Future<void> _saveDataToFirestore(String note) async {
    try {
      await FirebaseFirestore.instance.collection('sack_history').add({
        'seller_id': _sellerId ?? 'unknown',   // ✅ ប្តូរត្រង់នេះ
        'note': note,
        'sacks_data': _sacks,
        'total_sacks': _sacks.length,
        'total_weight': _totalWeight,
        'total_price': _totalMoney,
        'currency': _currency,
        'created_at': FieldValue.serverTimestamp(),
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("រក្សាទុកជោគជ័យ! ✅")));
      setState(() => _sacks.clear());
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("បរាជ័យ! ❌")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text(
          "ថ្លឹងបាវ & គិតលុយ",
          style: TextStyle(fontFamily: 'Siemreap'),
        ),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const SackHistoryScreen(),
              ),
            ),
          ),
          IconButton(icon: const Icon(Icons.save), onPressed: _showSaveDialog),
          const SizedBox(width: 8),
        ],
      ),
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.opaque,
          child: Column(
        children: [
          // ១. ប្រអប់បញ្ចូលតម្លៃ (ខាងលើគេ)
          _buildTopPriceInput(),

          // 🎯 ២. ប្រអប់បូកសរុប (ដាក់នៅចន្លោះកណ្តាលតាមបំណងមេ)
          _buildTotalSummarySection(),

          // ៣. ប្រអប់បញ្ចូលទម្ងន់បាវ
          _buildWeightInputSection(),

          // ៤. បញ្ជីបាវដែលបានបញ្ចូលរួច
          Expanded(
            child: ListView.builder(
              itemCount: _sacks.length,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemBuilder: (context, index) => _buildSackItem(index),
            ),
          ),
        ],
      ),
        ),
    );
  }

  Widget _buildTopPriceInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.green[700],
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _priceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: false),
              style: const TextStyle(color: Colors.white, fontSize: 18),
              decoration: const InputDecoration(
                labelText: "តម្លៃក្នុង ១ គីឡូ",
                labelStyle: TextStyle(
                  color: Colors.white70,
                  fontFamily: 'Siemreap',
                ),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white),
                ),
              ),
              onChanged: (v) =>
                  setState(() => _unitPrice = double.tryParse(v.replaceAll(',', '.')) ?? 0),
            ),
          ),
          const SizedBox(width: 15),
          DropdownButton<String>(
            value: _currency,
            dropdownColor: Colors.green[800],
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            items: [
              "៛",
              "\$",
            ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (v) => setState(() => _currency = v!),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalSummarySection() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "ទម្ងន់សរុប៖",
                style: TextStyle(fontFamily: 'Siemreap', fontSize: 16),
              ),
              Text(
                "${_totalWeight.toStringAsFixed(1)} គីឡូ",
                style: const TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ],
          ),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "ទឹកប្រាក់សរុប៖",
                style: TextStyle(fontFamily: 'Siemreap', fontSize: 18),
              ),
              Text(
                _currency == "៛"
                    ? "${_formatNumber(_totalMoney)} ៛"
                    : "\$${_formatNumber(_totalMoney)}",
                style: const TextStyle(
                  color: Colors.orange,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeightInputSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _weightController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: false),
              decoration: InputDecoration(
                hintText: "ទម្ងន់បាវទី ${_sacks.length + 1}",
                hintStyle: const TextStyle(fontFamily: 'Siemreap'),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              onSubmitted: (v) => _addSack(),
            ),
          ),
          const SizedBox(width: 10),
          IconButton.filled(
            onPressed: _addSack,
            icon: const Icon(Icons.add, size: 30),
            style: IconButton.styleFrom(
              backgroundColor: Colors.orange,
              padding: const EdgeInsets.all(12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSackItem(int index) {
    int sackNum = _sacks.length - index;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 2)],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 15,
            backgroundColor: Colors.green[100],
            child: Text(
              "$sackNum",
              style: TextStyle(
                color: Colors.green[800],
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Text(
              "${_sacks[index]} គីឡូ",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.blue),
            onPressed: () => _editSack(index),
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () => _removeSack(index),
          ),
        ],
      ),
    );
  }
}
