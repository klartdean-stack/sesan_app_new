// ==================== animal_detail_page.dart ====================
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AnimalDetailPage extends StatelessWidget {
  final Map<String, dynamic> animalData;

  const AnimalDetailPage({super.key, required this.animalData});

  String _calculateAge(dynamic birthDateRaw) {
    if (birthDateRaw == null) return "-";

    try {
      DateTime birthDate;

      if (birthDateRaw is String) {
        birthDate = DateTime.parse(birthDateRaw);
      } else if (birthDateRaw is Timestamp) {
        birthDate = birthDateRaw.toDate();
      } else {
        return "-";
      }

      DateTime now = DateTime.now();

      if (birthDate.isAfter(now)) return "មិនទាន់កើត";

      int totalDays = now.difference(birthDate).inDays;

      if (totalDays < 30) {
        return "$totalDays ថ្ងៃ";
      } else if (totalDays < 365) {
        int months = (totalDays / 30.44).floor();
        int remainingDays = (totalDays % 30.44).floor();
        return "$months ខែ ${remainingDays > 0 ? '$remainingDays ថ្ងៃ' : ''}";
      } else {
        int years = (totalDays / 365.25).floor();
        int remainingMonths = ((totalDays % 365.25) / 30.44).floor();
        return "$years ឆ្នាំ ${remainingMonths > 0 ? '$remainingMonths ខែ' : ''}";
      }
    } catch (e) {
      debugPrint("Age calculation error: $e");
      return "-";
    }
  }

  String _calculateRemaining(dynamic birthDateRaw, dynamic sellAgeRaw) {
    if (birthDateRaw == null || sellAgeRaw == null) return "-";

    String sellAgeStr = sellAgeRaw.toString();
    if (sellAgeStr == '0' || sellAgeStr.isEmpty) return "-";

    try {
      DateTime birthDate;

      if (birthDateRaw is String) {
        birthDate = DateTime.parse(birthDateRaw);
      } else if (birthDateRaw is Timestamp) {
        birthDate = birthDateRaw.toDate();
      } else {
        return "-";
      }

      int sellMonths = int.tryParse(sellAgeStr) ?? 0;

      DateTime sellDate = DateTime(
        birthDate.year,
        birthDate.month + sellMonths,
        birthDate.day,
      );
      DateTime now = DateTime.now();

      int remainingDays = sellDate.difference(now).inDays;

      if (remainingDays <= 0) {
        return "គ្រប់លក់";
      } else {
        return "$remainingDays ថ្ងៃ";
      }
    } catch (e) {
      debugPrint("Remaining calculation error: $e");
      return "-";
    }
  }

  String _formatDate(dynamic dateRaw, {String format = 'dd/MM/yy'}) {
    try {
      if (dateRaw == null) return "-";

      DateTime date;
      if (dateRaw is Timestamp) {
        date = dateRaw.toDate();
      } else if (dateRaw is String) {
        date = DateTime.parse(dateRaw);
      } else {
        return "-";
      }

      return DateFormat(format).format(date);
    } catch (e) {
      return "-";
    }
  }

  Color _getAnimalColor(String? type) {
    switch (type?.toLowerCase()) {
      case 'ជ្រូក':
      case 'pig':
        return Colors.pink;
      case 'គោ':
      case 'cow':
        return Colors.brown;
      case 'ក្របី':
      case 'buffalo':
        return Colors.blueGrey;
      case 'មាន់':
      case 'chicken':
        return Colors.orange;
      case 'ទា':
      case 'duck':
        return Colors.yellow.shade700;
      default:
        return Colors.indigo;
    }
  }

  IconData _getAnimalIcon(String? type) {
    switch (type?.toLowerCase()) {
      case 'ជ្រូក':
      case 'pig':
        return Icons.square;
      case 'គោ':
      case 'cow':
        return Icons.grass;
      case 'ក្របី':
      case 'buffalo':
        return Icons.water;
      case 'មាន់':
      case 'chicken':
        return Icons.egg;
      case 'ទា':
      case 'duck':
        return Icons.water_drop;
      default:
        return Icons.pets;
    }
  }

  @override
  Widget build(BuildContext context) {
    String animalCode =
        animalData['animalCode']?.toString() ??
            animalData['id']?.toString() ??
            'គ្មានលេខ';
    String animalType = animalData['type']?.toString() ?? 'មិនស្គាល់';
    String batchId = animalData['batchId']?.toString() ?? '';

    dynamic bDateRaw = animalData['birthDate'];
    String formattedBDate = _formatDate(bDateRaw);
    String rawBDate = bDateRaw?.toString() ?? "";

    dynamic updatedAtRaw = animalData['updatedAt'];
    String updatedAt = updatedAtRaw != null
        ? _formatDate(updatedAtRaw, format: 'dd/MM/yyyy HH:mm')
        : "មិនមាន";

    dynamic sellAgeRaw = animalData['sellAge'];
    String sellAgeStr = sellAgeRaw?.toString() ?? "0";

    Color animalColor = _getAnimalColor(animalType);
    IconData animalIcon = _getAnimalIcon(animalType);

    return Scaffold(
        backgroundColor: const Color(0xFFF0F2F5),
        appBar: AppBar(
          title: const Text(
            "ព័ត៌មានលម្អិតសត្វ",
            style: TextStyle(fontFamily: 'Siemreap'),
          ),
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
        ),
        body: SingleChildScrollView(
            padding: const EdgeInsets.all(15),
            child: Column(
                children: [
                // 🏷️ Hero Card
                Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                  Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: animalColor.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(animalIcon, size: 50, color: animalColor),
                ),
                const SizedBox(height: 20),
                Text(
                  animalCode,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: animalColor,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: animalColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    animalType,
                    style: TextStyle(
                      fontSize: 16,
                      color: animalColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                // ✅ Show Batch ID
                if (batchId.isNotEmpty) ...[
            const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            "សំបុក: $batchId",
            style: TextStyle(fontSize: 13, color: Colors.grey[700]),
          ),
        ),
        ],
        const SizedBox(height: 16),
    const Divider(),
    const SizedBox(height: 12),
    Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
    Icon(Icons.update, size: 16, color: Colors.grey[400]),
      const SizedBox(width: 8),
      Text(
        "ធ្វើបច្ចុប្បន្នភាព: $updatedAt",
        style: TextStyle(fontSize: 13, color: Colors.grey[500]),
      ),
    ],
    ),
                  ],
                ),
            ),
            const SizedBox(height: 24),
            _buildSectionTitle("សង្ខេបរហ័ស"),
            const SizedBox(height: 12),
            // ✅ Fix: Use LayoutBuilder to prevent overflow
            LayoutBuilder(
              builder: (context, constraints) {
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: (constraints.maxWidth - 12) / 2,
                      child: _buildStatCard(
                        Icons.cake,
                        "ថ្ងៃកំណើត",
                        formattedBDate,
                        Colors.blue,
                      ),
                    ),
                    SizedBox(
                      width: (constraints.maxWidth - 12) / 2,
                      child: _buildStatCard(
                        Icons.access_time,
                        "អាយុបច្ចុប្បន្ន",
                        _calculateAge(rawBDate),
                        Colors.green,
                      ),
                    ),
                    SizedBox(
                      width: (constraints.maxWidth - 12) / 2,
                      child: _buildStatCard(
                        Icons.flag,
                        "អាយុលក់",
                        "$sellAgeStr ខែ",
                        Colors.purple,
                      ),
                    ),
                    SizedBox(
                      width: (constraints.maxWidth - 12) / 2,
                      child: _buildStatCard(
                        Icons.timer,
                        "នៅសល់",
                        _calculateRemaining(rawBDate, sellAgeStr),
                        _calculateRemaining(rawBDate, sellAgeStr) == "គ្រប់លក់"
                            ? Colors.green
                            : Colors.orange,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            _buildSectionTitle("ព័ត៌មានលម្អិត"),
            const SizedBox(height: 12),
            Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                  _buildDetailRow(
                  Icons.tag,
                  "លេខកូដសត្វ",
                  animalCode,
                  animalColor,
                ),
                const Divider(height: 24),
                _buildDetailRow(
                  Icons.pets,
                  "ប្រភេទ",
                  animalType,
                  animalColor,
                ),
                if (batchId.isNotEmpty) ...[
            const Divider(height: 24),
        _buildDetailRow(Icons.label, "សំបុក", batchId, Colors.grey),
        ],
        const Divider(height: 24),
    _buildDetailRow(
    Icons.cake,
    "ថ្ងៃកំណើត",
    formattedBDate,
    Colors.blue,
    ),
    const Divider(height: 24),
    _buildDetailRow(
    Icons.access_time,
    "អាយុបច្ចុប្បន្ន",
    _calculateAge(rawBDate),Colors.green,
    ),
                    const Divider(height: 24),
                    _buildDetailRow(
                      Icons.flag,
                      "អាយុគ្រប់លក់",
                      "$sellAgeStr ខែ",
                      Colors.purple,
                    ),
                    const Divider(height: 24),
                    _buildDetailRow(
                      Icons.timer,
                      "ថ្ងៃនៅសល់",
                      _calculateRemaining(rawBDate, sellAgeStr),
                      _calculateRemaining(rawBDate, sellAgeStr) == "គ្រប់លក់"
                          ? Colors.green
                          : Colors.orange,
                    ),
                  ],
                ),
            ),
                  const SizedBox(height: 24),
                  _buildSectionTitle("ព្រឹត្តិការណ៍សំខាន់"),
                  const SizedBox(height: 12),
                  _buildTimelineCard(rawBDate, sellAgeStr),
                  const SizedBox(height: 30),
                ],
            ),
        ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 24,
          decoration: BoxDecoration(
            color: Colors.indigo,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.indigo,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
      IconData icon,
      String label,
      String value,
      Color color,
      ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
      IconData icon,
      String label,
      String value,
      Color color,
      ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(color: Colors.grey[500], fontSize: 13),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineCard(String rawBDate, String sellAgeStr) {
    if (rawBDate.isEmpty || sellAgeStr == '0') {
      return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.grey[100],
            borderRadius: BorderRadius.circular(16),
          ),
        child: const Center(
          child: Text(
            "មិនទាន់មានព័ត៌មានគ្រប់គ្រាន់",
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    try {
      DateTime birthDate = DateTime.parse(rawBDate);
      int sellMonths = int.tryParse(sellAgeStr) ?? 0;
      DateTime sellDate = DateTime(
        birthDate.year,
        birthDate.month + sellMonths,
        birthDate.day,
      );
      DateTime now = DateTime.now();

      double progress = 0;
      if (sellDate.isAfter(birthDate)) {
        int totalDays = sellDate.difference(birthDate).inDays;
        int passedDays = now.difference(birthDate).inDays;
        progress = (passedDays / totalDays).clamp(0.0, 1.0);
      }

      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                _buildTimelineDot(
                  Icons.cake,
                  "កើត",
                  _formatDate(rawBDate),
                  true,
                ),
                Expanded(
                  child: Container(
                    height: 4,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: progress,
                      child: Container(
                        decoration: BoxDecoration(
                          color: progress >= 1 ? Colors.green : Colors.indigo,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ),
                _buildTimelineDot(
                  Icons.flag,
                  "លក់",
                  _formatDate(sellDate.toIso8601String()),
                  progress >= 1,
                ),
              ],
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(
                progress >= 1 ? Colors.green : Colors.indigo,
              ),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 8),
            Text(
              "${(progress * 100).toInt()}% នៃពេលវេលាលក់",
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    } catch (e) {
      return const SizedBox.shrink();
    }
  }

  Widget _buildTimelineDot(
      IconData icon,
      String label,
      String date,
      bool isCompleted,
      ) {
    return Column(
      children: [
      Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: isCompleted
            ? Colors.green.withOpacity(0.15)
            : Colors.indigo.withOpacity(0.15),
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        color: isCompleted ? Colors.green : Colors.indigo,
        size: 22,
      ),
    ),
    const SizedBox(height: 6),
    Text(
    label,
    style: TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: Colors.grey[700],
    ),
    ),
    Text(date, style: TextStyle(fontSize: 10,color: Colors.grey[500])),
      ],
    );
  }
}