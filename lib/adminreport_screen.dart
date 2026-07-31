import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AdminReportScreen extends StatefulWidget {
  const AdminReportScreen({super.key});

  @override
  State<AdminReportScreen> createState() => _AdminReportScreenState();
}

class _AdminReportScreenState extends State<AdminReportScreen> {
  final fmt = NumberFormat('#,###');
  String _filterType = 'all'; // all, accepted, rejected

  // Action type mapping
  static const Map<String, Map<String, dynamic>> _actionConfig = {
    'PACKING': {
      'label': 'កំពុងខ្ចប់',
      'icon': Icons.inventory_2_outlined,
      'color': Color(0xFF58A6FF),
      'bgColor': Color(0xFF0D3880),
    },
    'ACCEPTED': {
      'label': 'បានយល់ព្រម',
      'icon': Icons.check_circle_outline,
      'color': Color(0xFF3FB950),
      'bgColor': Color(0xFF0D4429),
    },
    'ON_DELIVERY': {
      'label': 'កំពុងដឹក',
      'icon': Icons.local_shipping_outlined,
      'color': Color(0xFFA371F7),
      'bgColor': Color(0xFF3D1D70),
    },
    'REJECTED': {
      'label': 'បានបដិសេធ',
      'icon': Icons.cancel_outlined,
      'color': Color(0xFFF85149),
      'bgColor': Color(0xFF5A1A1A),
    },
    'ADMIN_DEDUCTION': {
      'label': 'ការកាត់ប្រាក់',
      'icon': Icons.remove_circle_outline,
      'color': Color(0xFFF0883E),
      'bgColor': Color(0xFF5C3D1E),
    },
  };

  bool _isAcceptedAction(String action) {
    return ['PACKING', 'ACCEPTED', 'ON_DELIVERY'].contains(action);
  }

  bool _isRejectedAction(String action) {
    return ['REJECTED', 'ADMIN_DEDUCTION'].contains(action);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: const Color(0xFF0F1419),
        body: SafeArea(
            child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('admin_reports')
                    .orderBy('time', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF58A6FF),
                      ),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return _buildEmptyState();
                  }

                  final docs = snapshot.data!.docs;

                  // Calculate stats
                  final totalAccepted = docs.where((d) {
                    final data = d.data() as Map<String, dynamic>;
                    return _isAcceptedAction(data['action']?.toString() ?? '');
                  }).length;

                  final totalRejected = docs.where((d) {
                    final data = d.data() as Map<String, dynamic>;
                    return _isRejectedAction(data['action']?.toString() ?? '');
                  }).length;

                  // Filter docs
                  var filteredDocs = docs;
                  if (_filterType == 'accepted') {
                    filteredDocs = docs.where((d) {
                      final data = d.data() as Map<String, dynamic>;
                      return _isAcceptedAction(data['action']?.toString() ?? '');
                    }).toList();
                  } else if (_filterType == 'rejected') {
                    filteredDocs = docs.where((d) {
                      final data = d.data() as Map<String, dynamic>;
                      return _isRejectedAction(data['action']?.toString() ?? '');
                    }).toList();
                  }

                  // Group by date
                  final groupedData = _groupByDate(filteredDocs);

                  return CustomScrollView(
                      slivers: [
                      // Header with stats
                      SliverToBoxAdapter(
                      child: _buildHeader(totalAccepted, totalRejected),
                  ),

                  // Filter chips
                  SliverToBoxAdapter(
                  child: _buildFilterChips(),
                  ),
                        // Grouped list
                        ...groupedData.entries.map((entry) {
                          return SliverToBoxAdapter(
                            child: _buildDateSection(entry.key, entry.value),
                          );
                        }).toList(),

                        const SliverToBoxAdapter(
                          child: SizedBox(height: 30),
                        ),
                      ],
                  );
                },
            ),
        ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 64,
            color: Colors.white.withOpacity(0.2),
          ),
          const SizedBox(height: 16),
          Text(
            'មិនទាន់មានសកម្មភាព',
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 16,
              fontFamily: 'Siemreap',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(int accepted, int rejected) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF161B2E),
            const Color(0xFF0F1419),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.arrow_back_ios_new,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    'របាយការណ៍សកម្មភាព',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Siemreap',
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.filter_list,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Stats cards
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  label: 'យល់ព្រម',
                  value: '$accepted',
                  icon: Icons.check_circle_outline,
                  color: const Color(0xFF3FB950),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  label: 'បដិសេធ/កាត់ប្រាក់',
                  value: '$rejected',
                  icon: Icons.cancel_outlined,
                  color: const Color(0xFFF85149),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
  required String label,
  required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2329),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF8B949E),
              fontSize: 12,
              fontFamily: 'Siemreap',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    final filters = [
      {'key': 'all', 'label': 'ទាំងអស់'},
      {'key': 'accepted', 'label': 'យល់ព្រម'},
      {'key': 'rejected', 'label': 'បដិសេធ'},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: filters.map((filter) {
            final isSelected = _filterType == filter['key'];
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => setState(() => _filterType = filter['key']!),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF58A6FF)
                        : const Color(0xFF1E2329),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF58A6FF)
                          : const Color(0xFF30363D),
                    ),
                  ),
                  child: Text(
                    filter['label']!,
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : const Color(0xFF8B949E),
                      fontSize: 13,
                      fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.normal,
                      fontFamily: 'Siemreap',
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Map<String, List<QueryDocumentSnapshot>> _groupByDate(
      List<QueryDocumentSnapshot> docs) {
    final grouped = <String, List<QueryDocumentSnapshot>>{};
    final now = DateTime.now();

    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final timestamp = data['time'] as Timestamp?;
      if (timestamp == null) continue;

      final date = timestamp.toDate();
      String key;

      if (_isSameDay(date, now)) {
        key = 'ថ្ងៃនេះ';
      } else if (_isSameDay(date, now.subtract(const Duration(days: 1)))) {
        key = 'ម្សិលមិញ';
      } else if (now.difference(date).inDays < 7) {
        key = 'សប្តាហ៍នេះ';
      } else {
        key = DateFormat('dd MMMM yyyy').format(date);
      }

      grouped.putIfAbsent(key, () => []).add(doc);
    }

    return grouped;
  }
  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Widget _buildDateSection(
      String dateLabel, List<QueryDocumentSnapshot> docs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 16,
                decoration: BoxDecoration(
                  color: const Color(0xFF58A6FF),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                dateLabel,
                style: const TextStyle(
                  color: Color(0xFF8B949E),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Siemreap',
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '(${docs.length})',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        ...docs.map((doc) => _buildReportCard(doc)),
      ],
    );
  }

  Widget _buildReportCard(QueryDocumentSnapshot doc) {
    final report = doc.data() as Map<String, dynamic>;
    final action = report['action']?.toString() ?? 'UNKNOWN';
    final String sellerId = report['seller_id']?.toString() ?? ''; // យក ID ដើម្បីទៅទាញឈ្មោះ

    final config = _actionConfig[action] ?? {
      'label': action,
      'icon': Icons.help_outline,
      'color': Colors.grey,
      'bgColor': Colors.grey.withOpacity(0.1),
    };

    final timestamp = report['time'] as Timestamp?;
    final date = timestamp?.toDate();
    final timeStr = date != null ? DateFormat('HH:mm').format(date) : '--:--';

    final bool hasAmount = report['amount'] != null;
    final double? amount = hasAmount ? (report['amount'] as num).toDouble() : null;

    return GestureDetector(
        onTap: () => _showDetailBottomSheet(report),
        child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E2329),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF30363D), width: 1),
            ),
            child: FutureBuilder<DocumentSnapshot>(
              // 🎯 គន្លឹះសំខាន់៖ ទៅទាញទិន្នន័យអ្នកលក់ពី Collection 'users'
                future: FirebaseFirestore.instance.collection('users').doc(sellerId).get(),
                builder: (context, userSnap) {
                  String displayName = "កំពុងទាញ...";
                  String? avatarUrl;

                  if (userSnap.hasData && userSnap.data!.exists) {
                    final userData = userSnap.data!.data() as Map<String, dynamic>;
                    displayName = userData['name'] ?? "គ្មានឈ្មោះ";
                    avatarUrl = userData['image']; // យក URL រូបភាពអ្នកលក់
                  } else if (!userSnap.hasData) {
                    displayName = "អ្នកលក់ #${sellerId.substring(0, 5)}";
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    // ១. បង្ហាញរូប Avatar អ្នកលក់ (ជំនួសឱ្យ Icon ធម្មតា ដើម្បីឱ្យស្អាត)
                    Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: config['bgColor'] as Color,
                      borderRadius: BorderRadius.circular(12),
                      image: avatarUrl != null
                          ? DecorationImage(image: NetworkImage(avatarUrl), fit: BoxFit.cover)
                          : null,
                    ),
                    child: avatarUrl == null
                        ? Icon(config['icon'] as IconData, color: config['color'] as Color, size: 24)
                        : null,
                  ),
                  const SizedBox(width: 14),

                  // ២. ផ្នែកខ្លឹមសារ
                  Expanded(
                  child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                  Expanded(
                  child: Text(
                  displayName, // 🎯 បង្ហាញឈ្មោះពិតនៅទីនេះ
                  style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Siemreap',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  ),
                  ),
                  Text(
                  timeStr,
                  style: const TextStyle(color: Color(0xFF8B949E), fontSize: 11),
                  ),
                  ],
                  ),
                  const SizedBox(height: 4),
                    // ៣. Badge ប្រភេទសកម្មភាព
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: (config['color'] as Color).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        config['label'] as String,
                        style: TextStyle(
                          color: config['color'] as Color,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Siemreap',
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // ៤. មូលហេតុ ឬ ចំនួនទឹកប្រាក់
                    if (report['reason'] != null)
                      Text(
                        report['reason'],
                        style: const TextStyle(color: Color(0xFF8B949E), fontSize: 13, fontFamily: 'Siemreap'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (hasAmount)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '${fmt.format(amount)} ៛',
                          style: const TextStyle(
                            color: Color(0xFFF85149),
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                  ],
                  ),
                  ),
                    ],
                  );
                },
            ),
        ),
    );
  }

  void _showDetailBottomSheet(Map<String, dynamic> report) {
    final action = report['action']?.toString() ?? 'UNKNOWN';
    final config = _actionConfig[action] ?? {
      'label': action,
      'icon': Icons.help_outline,
      'color': Colors.grey,
      'bgColor': Colors.grey.withOpacity(0.1),
    };

    showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) => DraggableScrollableSheet(
            initialChildSize: 0.6,
            maxChildSize: 0.9,
            minChildSize: 0.4,
            builder: (_, controller) => Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF1E2329),
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.all(24),
                children: [
              // Handle
              Center(
              child: Container(
              width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF30363D),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Header
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: config['bgColor'] as Color,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    config['icon'] as IconData,
                    color: config['color'] as Color,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        config['label'] as String,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Siemreap',
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'សកម្មភាព #${report['action']}',
                        style: const TextStyle(
                          color: Color(0xFF8B949E),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Info sections
            _buildDetailSection('ព័ត៌មានអ្នកលក់', [
              _buildDetailItem('ឈ្មោះ', report['seller_name'] ?? report['customer_name'] ?? 'មិនស្គាល់'),
              _buildDetailItem('ID', report['seller_id']?.toString() ?? 'N/A'),
            ]),

            if (report['order_id'] != null)
        _buildDetailSection('ព័ត៌មានបុង', [
      _buildDetailItem('លេខបុង', '#${report['order_id']}'),
    ]),

    _buildDetailSection('ព័ត៌មានសកម្មភាព', [
    _buildDetailItem('ប្រភេទ', report['action'] ?? 'N/A'),
    if (report['amount'] != null)
    _buildDetailItem(
    'ចំនួនប្រាក់',
    '${fmt.format((report['amount'] as num).toDouble())} ៛',
    valueColor: const Color(0xFFF85149),
    ),
    _buildDetailItem(
    'ពេលវេលា',
    _formatFullDateTime(report['time']),
    ),
    ]),

    if (report['reason'] != null)
    _buildDetailSection('មូលហេតុ', [
    Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
    color: const Color(0xFF0F1419),
    borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
    report['reason'],
    style: const TextStyle(
    color: Colors.white70,
    fontSize: 14,
    fontFamily: 'Siemreap',
    height: 1.6,
    ),
    ),
    ),
    ]),
                  const SizedBox(height: 24),

                  // Close button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF30363D),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'បិទ',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Siemreap',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
        ),
    );
  }

  Widget _buildDetailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF8B949E),
            fontSize: 12,
            fontWeight: FontWeight.w600,
            fontFamily: 'Siemreap',
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0F1419),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: children,
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildDetailItem(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF8B949E),
                fontSize: 13,
                fontFamily: 'Siemreap',
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor ?? Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                fontFamily: 'Siemreap',
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatFullDateTime(dynamic timestamp) {
    if (timestamp == null) return 'មិនស្គាល់';
    final date = (timestamp as Timestamp).toDate();
    return DateFormat('dd MMMM yyyy • HH:mm:ss').format(date);
  }
}