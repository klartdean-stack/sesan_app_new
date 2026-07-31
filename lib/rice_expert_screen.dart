import 'package:flutter/material.dart';

class RiceMasterProPage extends StatefulWidget {
  const RiceMasterProPage({super.key});

  @override
  State<RiceMasterProPage> createState() => _RiceMasterProPageState();
}

class _RiceMasterProPageState extends State<RiceMasterProPage> {
  final _areaCtrl = TextEditingController();
  String _riceType = 'ស្រូវស្រាល (៩០ថ្ងៃ)';
  bool _showResult = false;

  // រូបមន្តគណនាជីតាមស្តង់ដារបច្ចេកទេស (ក្នុង ១ ហិកតា)
  Map<String, double> getFertilizer(double hectare) {
    return {
      'urea': 150 * hectare, // ជីអ៊ុយរ៉េ (អាសូត)
      'dap': 100 * hectare, // ជីដាប (ផូស្វ័រ)
      'potash': 50 * hectare, // ជីប៉ូតាស្យូម
    };
  }

  void _calculate() {
    if (_areaCtrl.text.isNotEmpty) {
      setState(() => _showResult = true);
      FocusScope.of(context).unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green[50],
      appBar: AppBar(
        title: const Text(
          "មេបច្ចេកទេសស្រូវ (Sesan)",
          style: TextStyle(fontFamily: 'Siemreap'),
        ),
        backgroundColor: Colors.green[800],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInputSection(),
            if (_showResult) ...[
              const SizedBox(height: 25),
              _buildFertilizerCard(),
              const SizedBox(height: 20),
              _buildTimelineSection(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInputSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: Colors.green.withOpacity(0.1), blurRadius: 10),
        ],
      ),
      child: Column(
        children: [
          TextField(
            controller: _areaCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: "ទំហំដីដាំដុះ (ហិកតា)",
              prefixIcon: Icon(Icons.landscape, color: Colors.green),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 15),
          DropdownButtonFormField<String>(
            value: _riceType,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: "ប្រភេទពូជស្រូវ",
            ),
            items: [
              'ស្រូវស្រាល (៩០ថ្ងៃ)',
              'ស្រូវកណ្តាល (១២០ថ្ងៃ)',
              'ស្រូវធ្ងន់ (១៥០ថ្ងៃ)',
            ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (v) => setState(() => _riceType = v!),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _calculate,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[800],
              minimumSize: const Size(double.infinity, 55),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              "ចាប់ផ្តើមរៀបចំផែនការ",
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFertilizerCard() {
    double area = double.tryParse(_areaCtrl.text) ?? 0;
    var f = getFertilizer(area);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.green[800],
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          const Text(
            "🧪 បរិមាណជីដែលត្រូវប្រើសរុប",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Divider(color: Colors.white54),
          _fertRow(
            "ជីអ៊ុយរ៉េ (អាសូត)",
            "${f['urea']!.toStringAsFixed(0)} គីឡូ",
          ),
          _fertRow("ជីដាប (ផូស្វ័រ)", "${f['dap']!.toStringAsFixed(0)} គីឡូ"),
          _fertRow("ជីប៉ូតាស្យូម", "${f['potash']!.toStringAsFixed(0)} គីឡូ"),
        ],
      ),
    );
  }

  Widget _fertRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70)),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "📅 កាលវិភាគថែទាំតាមដំណាក់កាល",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 15),
        _timelineItem(
          "វគ្គលូតលាស់ (១៥-២០ ថ្ងៃ)",
          "បាចជីលើកទី១ (អ៊ុយរ៉េ + ដាប) ដើម្បីជួយដល់ការបែកគុម្ព និងឫស។",
          Icons.grass,
        ),
        _timelineItem(
          "វគ្គបង្កបង្កើនផល (មុនចេញផ្កា)",
          "បាចជីលើកទី២ ដើម្បីជួយដល់ការកកើតកូរ និងគ្រាប់ស្រូវឱ្យដាក់។",
          Icons.grain,
        ),
        _timelineItem(
          "វគ្គទុំ (មុនច្រូតកាត់ ១០ថ្ងៃ)",
          "បញ្ចុះទឹកចេញពីស្រែ ដើម្បីឱ្យស្រូវទុំស្រុះគ្នា និងងាយស្រួលច្រូត។",
          Icons.content_cut,
        ),
      ],
    );
  }

  Widget _timelineItem(String title, String desc, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: Colors.green[800],
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  desc,
                  style: const TextStyle(color: Colors.black54, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
