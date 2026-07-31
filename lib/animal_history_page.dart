// ==================== animal_history_page.dart ====================
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'animal_detail_page.dart';

class AnimalHistoryPage extends StatefulWidget {
  const AnimalHistoryPage({super.key});

  @override
  State<AnimalHistoryPage> createState() => _AnimalHistoryPageState();
}

class _AnimalHistoryPageState extends State<AnimalHistoryPage> {
  String? userId;
  bool isLoading = true;
  String? selectedBatch; // ✅ Filter by batch
  List<String> batches = []; // ✅ List of all batches

  @override
  void initState() {
    super.initState();
    _loadUserId();
  }

  Future<void> _loadUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String uid = prefs.getString('user_uid') ?? '';
      debugPrint("🐷 AnimalHistory - SharedPreferences UID: '$uid'");

      if (mounted) {
        setState(() {
          userId = uid.isNotEmpty ? uid : null;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("❌ Load User ID Error: $e");
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  String _calculateAge(String? birthDateStr) {
    if (birthDateStr == null || birthDateStr.isEmpty) return "-";

    try {
      DateTime birthDate = DateTime.parse(birthDateStr);
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

  String _formatDate(dynamic timestamp) {
    try {
      if (timestamp == null) return "-";
      DateTime date;
      if (timestamp is Timestamp) {
        date = timestamp.toDate();
      } else if (timestamp is String) {
        date = DateTime.parse(timestamp);
      } else {
        return "-";
      }
      return DateFormat('dd/MM/yyyy').format(date);
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
    if (isLoading) {
      return Scaffold(
          backgroundColor: const Color(0xFFF5F7FA),
          appBar: AppBar(
            title: const Text(
              "ប្រវត្តិសត្វ",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.indigo,
            foregroundColor: Colors.white,
            centerTitle: true,
            elevation: 0,
          ),
          body: const Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.indigo),
                  SizedBox(height: 16),
                  Text("កំពុងផ្ទុក...", style: TextStyle(color: Colors.grey)),
                ],
              ),
          ),
      );
    }

    if (userId == null || userId!.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          title: const Text("ប្រវត្តិសត្វ"),
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
          centerTitle: true,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.account_circle_outlined,
                size: 80,
                color: Colors.grey[300],
              ),
              const SizedBox(height: 16),
              const Text(
                "សូម Login មុននឹងមើលប្រវត្តិ",
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () async {
                  setState(() => isLoading = true);
                  await _loadUserId();
                },
                icon: const Icon(Icons.refresh),
                label: const Text("ព្យាយាមម្តងទៀត"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          title: const Text(
            "ប្រវត្តិសត្វដែលបានរក្សាទុក",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => setState(() {}),
            ),
          ],
        ),
        body: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('animal_tracking')
                .where('userId', isEqualTo: userId)
                .orderBy('updatedAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                // ✅ Extract unique batches
                var docs = snapshot.data!.docs;
                var allBatches = docs
                    .map(
                      (d) =>
                  (d.data() as Map<String, dynamic>)['batchId']
                      ?.toString() ??
                      'Unknown',
                )
                    .toSet()
                    .toList();
                if (allBatches.isNotEmpty && batches.isEmpty) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    setState(() => batches = allBatches);
                  });
                }
              }

              if (snapshot.hasError) {
                debugPrint("❌ Animal Stream Error: ${snapshot.error}");
                return _buildErrorWidget(snapshot.error.toString());
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return _buildLoadingWidget();
              }

              final docs = snapshot.data?.docs ?? [];

              if (docs.isEmpty) {
                return _buildEmptyWidget();
              }

              // ✅ Filter by batch if selected
              var filteredDocs = selectedBatch == null
                  ? docs
                  : docs.where((d) {
                var data = d.data() as Map<String, dynamic>;
                return data['batchId'] == selectedBatch;
              }).toList();
              return Column(
                  children: [
                  // ✅ Batch Filter Chips
                  if (batches.isNotEmpty)
              Container(
                  height: 60,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,vertical: 8,
                  ),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    ChoiceChip(
                      label: const Text("ទាំងអស់"),
                      selected: selectedBatch == null,
                      onSelected: (_) => setState(() => selectedBatch = null),
                      selectedColor: Colors.indigo,
                      labelStyle: TextStyle(
                        color: selectedBatch == null
                            ? Colors.white
                            : Colors.black,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ...batches.map((batch) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(batch),
                          selected: selectedBatch == batch,
                          onSelected: (_) =>
                              setState(() => selectedBatch = batch),
                          selectedColor: Colors.indigo,
                          labelStyle: TextStyle(
                            color: selectedBatch == batch
                                ? Colors.white
                                : Colors.black,
                          ),
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredDocs.length,
                        itemBuilder: (context, index) {
                          try {
                            var data =
                            filteredDocs[index].data() as Map<String, dynamic>?;
                            if (data == null) return const SizedBox.shrink();
                            return _buildAnimalCard(data, index);
                          } catch (e) {
                            debugPrint("❌ Animal card error: $e");
                            return const SizedBox.shrink();
                          }
                        },
                      ),
                    ),
                  ],
              );
            },
        ),
    );
  }

  Widget _buildAnimalCard(Map<String, dynamic> data, int index) {
    String animalCode = data['animalCode']?.toString() ?? 'គ្មានលេខ';
    String animalType = data['type']?.toString() ?? 'មិនស្គាល់';
    String? birthDate = data['birthDate']?.toString();
    String age = _calculateAge(birthDate);
    String formattedBirthDate = _formatDate(data['birthDate']);
    String formattedUpdateDate = _formatDate(data['updatedAt']);
    String batchId = data['batchId']?.toString() ?? '';

    Color animalColor = _getAnimalColor(animalType);
    IconData animalIcon = _getAnimalIcon(animalType);

    return TweenAnimationBuilder(
        duration: Duration(milliseconds: 300 + (index * 80)),
        tween: Tween<double>(begin: 0, end: 1),
        builder: (context, double value, child) {
          return Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, 30 * (1 - value)),
              child: child,
            ),
          );
        },
        child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AnimalDetailPage(animalData: data),
                ),
              );
            },
            child: Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: ClipRRect(
                    borderRadius:BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Row(
                    children: [
                    Container(
                    width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: animalColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(animalIcon, color: animalColor, size: 32),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            animalCode,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: animalColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  animalType,
                                  style: TextStyle(
                                    color: animalColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // ✅ Show Batch ID
                              if (batchId.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    batchId,
                                    style: TextStyle(
                                      color: Colors.grey[700],
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: Colors.grey,
                    ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildInfoItem(Icons.cake, "កើត", formattedBirthDate),
                      _buildInfoItem(Icons.access_time, "អាយុ", age),
                    ],
                  ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildInfoItem(
                              Icons.update,
                              "ធ្វើបច្ចុប្បន្នភាព",
                              formattedUpdateDate,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ),
        ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey[400]),
        const SizedBox(width: 4),
        Text(
          "$label: ",
          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              color: Colors.indigo,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            "កំពុងផ្ទុកប្រវត្តិសត្វ...",
            style: TextStyle(color: Colors.grey[500], fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.pets, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text(
            "មិនទាន់មានប្រវត្តិសត្វ",
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Text(
            "ចុចប៊ូតុង + ដើម្បីបន្ថែមសត្វថ្មី",
            style: TextStyle(fontSize: 14, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red[300], size: 64),
            const SizedBox(height: 16),
            Text(
              "មិនអាចផ្ទុកបាន: $error",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
          ],
        ),
      ),
    );
  }
}