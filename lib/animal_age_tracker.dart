// ==================== animal_age_tracker_page.dart ====================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'animal_history_page.dart';

class AnimalAgeTrackerPage extends StatefulWidget {
  const AnimalAgeTrackerPage({super.key});

  @override
  State<AnimalAgeTrackerPage> createState() => _AnimalAgeTrackerPageState();
}

class _AnimalAgeTrackerPageState extends State<AnimalAgeTrackerPage> {
  List<Map<String, dynamic>> animals = [];
  String animalType = "ជ្រូក";

  final List<String> animalTypes = [
    "ជ្រូក",
    "គោ",
    "ក្របី",
    "ទា",
    "មាន់",
    "ផ្សេងៗ",
  ];

  String _userId = '';
  bool _isUserLoading = true;
  String _batchId = ''; // ✅ លេខសំគាល់សំបុក

  @override
  void initState() {
    super.initState();
    _loadUserId();
    _generateBatchId(); // ✅ បង្កើត Batch ID ជាមុន
  }

  Future<void> _loadUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String uid = prefs.getString('user_uid') ?? '';
      debugPrint("🐷 AnimalTracker - UID: '$uid'");

      if (mounted) {
        setState(() {
          _userId = uid;
          _isUserLoading = false;
        });
        if (_userId.isNotEmpty) _addAnimal();
      }
    } catch (e) {
      debugPrint("❌ Load User ID Error: $e");
      if (mounted) setState(() => _isUserLoading = false);
    }
  }

  // ✅ បង្កើត Batch ID ដោយស្វ័យប្រវត្តិ (BATCH-20260504-001)
  void _generateBatchId() {
    String dateStr = DateFormat('yyyyMMdd').format(DateTime.now());
    _batchId = 'BATCH-$dateStr';
  }

  // ✅ Auto Generate ID A-1, A-2, A-3...
  String _generateAutoId(int index) {
    String prefix = animalType == "ជ្រូក" ? "P" :
    animalType == "គោ" ? "C" :
    animalType == "ក្របី" ? "B" :
    animalType == "ទា" ? "D" :
    animalType == "មាន់" ? "K" : "X";
    return "$prefix-${index + 1}";
  }

  void _addAnimal() {
    setState(() {
      int newIndex = animals.length;
      animals.add({
        'id': _generateAutoId(newIndex), // ✅ Auto ID
        'birthDate': DateTime.now().toIso8601String(),
        'sellAge': '6',
      });
    });
  }

  Future<void> _saveAllAnimals() async {
    if (_userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("⚠️ សូម Login មុននឹងរក្សាទុក"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (animals.isEmpty) return;

    // ✅ បង្ហាញ Dialog បញ្ជាក់ Batch ID
    bool? confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text(
              "រក្សាទុកសត្វ",
              style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Siemreap'),
            ),
            content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                Text("ប្រភេទ: $animalType"),
            Text("ចំនួន: ${animals.length} ក្បាល"),
            const SizedBox(height: 8),
            Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.indigo.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                    children: [
                    const Icon(Icons.label, color: Colors.indigo),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "លេខសំគាល់សំបុក:",
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    Text(
                      _batchId,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo,
                      ),
                    ),
                  ],
                ),
                    ],
                ),
            ),
                ],
            ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("បោះបង់"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
              child: const Text("រក្សាទុក", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
    );

    if (confirm != true) return;

    try {
      int savedCount = 0;
      for (var animal in animals) {
        String animalId = animal['id'].toString().trim();
        if (animalId.isNotEmpty) {
          await FirebaseFirestore.instance.collection('animal_tracking').add({
            'id': animalId,
            'animalCode': animalId,
            'type': animalType,
            'batchId': _batchId, // ✅ រក្សាទុក Batch ID
            'birthDate': animal['birthDate'],
            'sellAge': animal['sellAge'],
            'userId': _userId,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          savedCount++;
        }
      }

      if (savedCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("✅ បានរក្សាទុក $savedCount ក្បាល\nBatch: $_batchId"),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
        setState(() {
          animals.clear();
          _generateBatchId(); // ✅ បង្កើត Batch ថ្មី
          _addAnimal();
        });
      }
    } catch (e) {
      debugPrint("Save Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Error: $e"), backgroundColor: Colors.red),
      );
    }
  }

  String _calculateAge(String birthDateStr) {
    if (birthDateStr.isEmpty) return "-";
    try {
      DateTime birthDate = DateTime.parse(birthDateStr);
      DateTime now = DateTime.now();
      if (birthDate.isAfter(now)) return "មិនទាន់កើត";

      int days = now.difference(birthDate).inDays;
      int months = (days / 30.44).floor();
      int remainingDays = (days % 30.44).floor();
      return "$months ខែ $remainingDays ថ្ងៃ";
    } catch (e) {
      return "-";
    }
  }

  String _calculateRemaining(String birthDateStr, String sellAgeStr) {
    if (birthDateStr.isEmpty || sellAgeStr == '0') return "-";
    try {
      DateTime birthDate = DateTime.parse(birthDateStr);
      double sellMonths = double.tryParse(sellAgeStr.replaceAll(',', '.')) ?? 0;
      int wholeMonths = sellMonths.floor();
      double fractionMonth = sellMonths - wholeMonths;
      int extraDays = (fractionMonth * 30.44).round();

      DateTime sellDate = DateTime(
        birthDate.year,
        birthDate.month + wholeMonths,
        birthDate.day + extraDays,
      );
      int remainingDays = sellDate.difference(DateTime.now()).inDays;
      return remainingDays <= 0 ? "គ្រប់លក់" : "$remainingDays ថ្ងៃ";
    } catch (e) {
      return "-";
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isUserLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('តាមដានអាយុសត្វ'),
          backgroundColor: Colors.indigo,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text("កំពុងពិនិត្យការចូល..."),
            ],
          ),
        ),
      );
    }
    if (_userId.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('តាមដានអាយុសត្វ'),
          backgroundColor: Colors.indigo,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.login, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              const Text(
                "សូម Login មុននឹងប្រើប្រាស់",
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('តាមដានអាយុសត្វ'),
        backgroundColor: Colors.indigo,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AnimalHistoryPage()),
            ),
          ),
          IconButton(icon: const Icon(Icons.save), onPressed: _saveAllAnimals),
        ],
      ),
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.opaque,
          child: Column(
        children: [
          _buildHeaderCard(),
          _buildBatchInfo(), // ✅ បង្ហាញ Batch ID
          _buildTableTitle(),
          Expanded(
            child: ListView.builder(
              itemCount: animals.length,
              itemBuilder: (context, index) => _buildDataRow(index),
            ),
          ),
        ],
      ),
        ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addAnimal,
        backgroundColor: Colors.indigo,
        icon: const Icon(Icons.add),
        label: const Text("បន្ថែម", style: TextStyle(fontFamily: 'Siemreap')),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
      Row(
      children: [
      Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.indigo.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.pets, color: Colors.indigo),
    ),
    const SizedBox(width: 12),
    const Text(
    "ប្រភេទសត្វ",
    style: TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    fontFamily: 'Siemreap',
    ),
    ),
    ],
    ),
    const SizedBox(height: 16),
    Container(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    decoration: BoxDecoration(
    color: Colors.grey[50],
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: Colors.grey[300]!),
    ),
    child: DropdownButtonHideUnderline(
    child: DropdownButton<String>(
    value: animalType,
    isExpanded: true,
    icon: const Icon(Icons.arrow_drop_down, color: Colors.indigo),
    style: const TextStyle(
    fontSize: 16,
    color: Colors.black87,
    fontFamily: 'Siemreap',
    ),
      items: animalTypes.map((String type) {
        return DropdownMenuItem<String>(
          value: type,
          child: Text(type),
        );
      }).toList(),
      onChanged: (String? newValue) {
        if (newValue != null) {
          setState(() {
            animalType = newValue;
            // ✅ កែ ID ទាំងអស់ពេលប្តូរប្រភេទ
            for (int i = 0; i < animals.length; i++) {
              animals[i]['id'] = _generateAutoId(i);
            }
          });
        }
      },
    ),
    ),
    ),
          ],
      ),
    );
  }

  // ✅ Widget ថ្មីបង្ហាញ Batch ID
  Widget _buildBatchInfo() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.indigo.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.indigo.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.label_outline, color: Colors.indigo, size: 20),
          const SizedBox(width: 10),
          Text(
            "សំបុកបច្ចុប្បន្ន: ",
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 13,
              fontFamily: 'Siemreap',
            ),
          ),
          Text(
            _batchId,
            style: const TextStyle(
              color: Colors.indigo,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const Spacer(),
          Text(
            "${animals.length} ក្បាល",
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableTitle() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.indigo,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              "លេខសម្គាល់",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              "ថ្ងៃកំណើត",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              "អាយុឥឡូវ",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              "អាយុលក់",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              "នៅសល់",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildDataRow(int index) {
    return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
          Expanded(
          flex: 2,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.indigo.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              animals[index]['id'],
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.indigo,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: InkWell(
            onTap: () async {
              DateTime? picked = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime(2000),
                lastDate: DateTime.now(),
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: const ColorScheme.light(
                        primary: Colors.indigo,
                      ),
                    ),
                    child: child!,
                  );
                },
              );
              if (picked != null) {
                setState(
                      () => animals[index]['birthDate'] = picked.toIso8601String(),
                );
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: Colors.indigo.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.indigo.withOpacity(0.2)),
              ),
              child: Text(
                DateFormat('dd/MM/yy').format(
                  DateTime.parse(animals[index]['birthDate']),
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.indigo,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: Text(
            _calculateAge(animals[index]['birthDate']),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: TextField(
                onChanged: (v) => setState(() => animals[index]['sellAge'] = v),
                textAlign: TextAlign.center,
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: false),
                decoration: InputDecoration(
                    hintText: "ខែ",
                    hintStyle: TextStyle(color: Colors.grey[400], fontSize: 12),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 4,
                    ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.indigo),
                  ),
                ),
            ),
        ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _calculateRemaining(
                    animals[index]['birthDate'],
                    animals[index]['sellAge'],
                  ) ==
                      "គ្រប់លក់"
                      ? Colors.green.withOpacity(0.1)
                      : Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _calculateRemaining(
                    animals[index]['birthDate'],
                    animals[index]['sellAge'],
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _calculateRemaining(
                      animals[index]['birthDate'],
                      animals[index]['sellAge'],
                    ) ==
                        "គ្រប់លក់"
                        ? Colors.green[700]
                        : Colors.orange[700],
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          ],
        ),
    );
  }
}