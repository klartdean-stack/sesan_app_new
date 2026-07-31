import 'package:flutter/material.dart';

class AnimalRow {
  TextEditingController nameController = TextEditingController();
  TextEditingController totalOffspringController = TextEditingController();
  TextEditingController maleController = TextEditingController();
  int femaleCount = 0;

  AnimalRow() {
    nameController.text = "";
    totalOffspringController.text = "";
    maleController.text = "";
  }
}

class LivestockTrackerPage extends StatefulWidget {
  const LivestockTrackerPage({super.key});

  @override
  State<LivestockTrackerPage> createState() => _LivestockTrackerPageState();
}

class _LivestockTrackerPageState extends State<LivestockTrackerPage> {
  List<AnimalRow> rows = [AnimalRow()..nameController.text = "មេទី1"];

  int get totalMothers => rows.length;
  int get grandTotalOffspring => rows.fold(
    0,
    (sum, item) =>
        sum + (int.tryParse(item.totalOffspringController.text) ?? 0),
  );
  int get grandTotalMales => rows.fold(
    0,
    (sum, item) => sum + (int.tryParse(item.maleController.text) ?? 0),
  );
  int get grandTotalFemales =>
      rows.fold(0, (sum, item) => sum + item.femaleCount);
  double get average =>
      totalMothers > 0 ? grandTotalOffspring / totalMothers : 0;

  // 🏆 មុខងារស្វែងរកមេពូជឆ្នើម (High Yielding)
  void _showBestBreeder() {
    if (rows.isEmpty) return;

    // ចម្លង List មកតម្រៀបតាមចំនួនកូនសរុបពីច្រើនទៅតិច
    List<AnimalRow> sortedRows = List.from(rows);
    sortedRows.sort((a, b) {
      int aVal = int.tryParse(a.totalOffspringController.text) ?? 0;
      int bVal = int.tryParse(b.totalOffspringController.text) ?? 0;
      return bVal.compareTo(aVal);
    });

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "🏆 ចំណាត់ថ្នាក់មេពូជឆ្នើម",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'Siemreap',
              ),
            ),
            const SizedBox(height: 15),
            ...sortedRows
                .map(
                  (row) => ListTile(
                    leading: const Icon(Icons.star, color: Colors.amber),
                    title: Text(
                      row.nameController.text.isEmpty
                          ? "មេគ្មានឈ្មោះ"
                          : row.nameController.text,
                    ),
                    trailing: Text(
                      "${row.totalOffspringController.text} កូន",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.teal,
                      ),
                    ),
                  ),
                )
                .toList(),
          ],
        ),
      ),
    );
  }

  void _addNewRow() {
    setState(() {
      rows.add(AnimalRow());
      rows.last.nameController.text = "មេទី${rows.length}";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ស្ថិតិកូនសត្វ (Excel Style)'),
        backgroundColor: Colors.teal,
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics_outlined),
            onPressed: _showBestBreeder, // 🎯 ចុចដើម្បីមើលមេពូជឆ្នើម
          ),
        ],
      ),
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.opaque,
          child: Column(
        children: [
          _buildSummaryHeader(),
          Expanded(
            child: ListView.builder(
              itemCount: rows.length,
              itemBuilder: (context, index) => _buildDataRow(index),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              onPressed: _addNewRow,
              icon: const Icon(Icons.add),
              label: const Text("បន្ថែមមេសត្វថ្មី"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ),
        ],
      ),
        ),
    );
  }

  Widget _buildSummaryHeader() {
    return Container(
      color: Colors.teal.shade50,
      padding: const EdgeInsets.all(15),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _summaryItem("មេសរុប", "$totalMothers"),
              _summaryItem("កូនសរុប", "$grandTotalOffspring"),
              _summaryItem("ឈ្លោល", "$grandTotalMales"),
              _summaryItem("ញី", "$grandTotalFemales"),
            ],
          ),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.leaderboard, size: 16, color: Colors.teal),
              const SizedBox(width: 5),
              Text(
                "មធ្យមភាគ៖ ${average.toStringAsFixed(1)} កូន/មេ",
                style: const TextStyle(
                  color: Colors.teal,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12)),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.teal,
          ),
        ),
      ],
    );
  }

  Widget _buildDataRow(int index) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: TextField(
              controller: rows[index].nameController,
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: "ឈ្មោះមេ",
              ),
            ),
          ),
          Expanded(
            child: _inputBox(
              rows[index].totalOffspringController,
              "សរុប",
              (val) => _calculateFemale(index),
            ),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: _inputBox(
              rows[index].maleController,
              "ឈ្លោល",
              (val) => _calculateFemale(index),
            ),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Container(
              height: 45,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                "${rows[index].femaleCount}",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.teal,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
            onPressed: () => setState(() => rows.removeAt(index)),
          ),
        ],
      ),
    );
  }

  void _calculateFemale(int index) {
    int total = int.tryParse(rows[index].totalOffspringController.text) ?? 0;
    int male = int.tryParse(rows[index].maleController.text) ?? 0;
    setState(() {
      rows[index].femaleCount = (total - male >= 0) ? (total - male) : 0;
    });
  }

  Widget _inputBox(
    TextEditingController controller,
    String hint,
    Function(String) onChange,
  ) {
    return SizedBox(
      height: 45,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        onChanged: onChange,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}
