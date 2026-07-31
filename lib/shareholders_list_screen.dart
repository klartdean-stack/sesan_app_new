import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:my_app/shareholder_detail_screen.dart';

class ShareholdersListScreen extends StatelessWidget {
  const ShareholdersListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: const Color(0xFF0F1419),
        appBar: AppBar(
          title: const Text(
            "បញ្ជីអ្នកវិនិយោគ",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'Siemreap',
            ),
          ),
          backgroundColor: const Color(0xFF161B2E),
          elevation: 0,
          leading: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        body: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('shareholders')
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: Color(0xFF58A6FF)),
                );
              }

              var docs = snapshot.data!.docs;
              if (docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.people_outline,
                        size: 64,
                        color: Colors.white.withOpacity(0.2),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "មិនទាន់មានអ្នកវិនិយោគទេ",
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

              return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    var data = docs[index].data() as Map<String, dynamic>;
                    var uid = docs[index].id;

                    return GestureDetector(
                        onTap: () {
                          // ✅ Navigate ទៅ ShareholderDetailScreen (file ទី3)
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ShareholderDetailScreen(
                                data: {
                                  ...data,
                                  'uid': uid,
                                },
                              ),
                            ),
                          );
                        },
                        child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E2329),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFF30363D),
                                width: 1,
                              ),
                            ),
                            child: Row(
                                children: [
                                // Avatar
                                Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        const Color(0xFF58A6FF).withOpacity(0.3),
                                        const Color(0xFF58A6FF).withOpacity(0.1),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                  shape: BoxShape.circle,
                                ),
                                  child: Center(
                                    child: Text(
                                      "${index + 1}",
                                      style: const TextStyle(
                                        color: Color(0xFF58A6FF),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ),
                                  const SizedBox(width: 14),

                                  // Info
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          data['name'] ?? "គ្មានឈ្មោះ",
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15,
                                            fontFamily: 'Siemreap',
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          "ទុនវិនិយោគ: ${NumberFormat('#,###').format(data['invested_amount'] ?? 0)} ៛",
                                          style: const TextStyle(
                                            color: Color(0xFF8B949E),
                                            fontSize: 12,
                                            fontFamily: 'Siemreap',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Shares
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        "${data['total_shares'] ?? 0}",
                                        style: const TextStyle(
                                          color: Color(0xFF3FB950),
                                          fontSize: 20,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const Text(
                                        "ហ៊ុន",
                                        style: TextStyle(
                                          color: Color(0xFF8B949E),
                                          fontSize: 11,
                                          fontFamily: 'Siemreap',
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(
                                    Icons.arrow_forward_ios,
                                    color: Color(0xFF8B949E),
                                    size: 14,
                                  ),
                                ],
                            ),
                        ),
                    );
                  },
              );
            },
        ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF58A6FF),
        onPressed: () {
          // បង្កើតអ្នកវិនិយោគថ្មី
        },
        icon: const Icon(Icons.add),
        label: const Text(
          'បន្ថែម',
          style: TextStyle(fontFamily: 'Siemreap'),
        ),
      ),
    );
  }
  // ═══════════════════════════════════════════════════════════
  //  ⭐ FIXED: Detail Bottom Sheet with Scroll ⭐
  // ═══════════════════════════════════════════════════════════
  void _showDetailBottomSheet(BuildContext context, Map<String, dynamic> data) {
    showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true, // អនុញ្ញាតឲ្យ scroll ពេញអេក្រង់
        builder: (context) => DraggableScrollableSheet(
            initialChildSize: 0.6,
            maxChildSize: 0.9,
            minChildSize: 0.4,
            expand: false,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF1E2329),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                    children: [
                // Handle bar (fixed)
                Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFF30363D),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),

              // Header (fixed)
              Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
              children: [
              Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
              gradient: LinearGradient(
              colors: [
              const Color(0xFF58A6FF).withOpacity(0.3),
              const Color(0xFF58A6FF).withOpacity(0.1),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              ),
              child: const Icon(
              Icons.person,
              color: Color(0xFF58A6FF),
              size: 28,
              ),
              ),
              const SizedBox(width: 16),
              Expanded(
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Text(
              data['name'] ?? 'មិនស្គាល់',
              style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontFamily: 'Siemreap',
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
              'អ្នកវិនិយោគ #${data['uid']?.toString().substring(0, 8) ?? 'N/A'}',
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
              ),
              const SizedBox(height: 20),
                      // Scrollable content
                      Expanded(
                        child: ListView(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          children: [
                            // Stats Cards
                            Row(
                              children: [
                                Expanded(
                                  child: _buildStatCard(
                                    'ហ៊ុនសរុប',
                                    '${data['total_shares'] ?? 0}',
                                    Icons.pie_chart_outline,
                                    const Color(0xFF58A6FF),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildStatCard(
                                    'ទុនវិនិយោគ',
                                    '${NumberFormat('#,###').format(data['invested_amount'] ?? 0)} ៛',
                                    Icons.account_balance_wallet_outlined,
                                    const Color(0xFF3FB950),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),

                            // Info Section
                            _buildSectionTitle('ព័ត៌មានផ្ទាល់ខ្លួន'),
                            _buildInfoItem(
                              icon: Icons.phone_outlined,
                              label: 'លេខទូរស័ព្ទ',
                              value: data['phone'] ?? 'មិនមាន',
                            ),
                            _buildInfoItem(
                              icon: Icons.badge_outlined,
                              label: 'អត្តសញ្ញាណប័ណ្ណ',
                              value: data['id_card'] ?? 'មិនមាន',
                            ),
                            _buildInfoItem(
                              icon: Icons.location_on_outlined,
                              label: 'អាសយដ្ឋាន',
                              value: data['address'] ?? 'មិនមាន',
                              isLongText: true,
                            ),
                            _buildInfoItem(
                              icon: Icons.account_balance_outlined,
                              label: 'លេខគណនីធនាគារ',
                              value: data['bank_account'] ?? 'មិនមាន',
                            ),

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
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ],
                ),
              );
            },
        ),
    );
  }

  Widget _buildStatCard(
      String label,
      String value,
      IconData icon,
      Color color,
      ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1419),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF8B949E),
              fontSize: 11,
              fontFamily: 'Siemreap',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
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
            title,
            style: const TextStyle(
              color: Color(0xFF8B949E),
              fontSize: 13,
              fontWeight: FontWeight.w600,
              fontFamily: 'Siemreap',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
    bool isLongText = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1419),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment:
        isLongText ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF58A6FF).withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFF58A6FF), size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF8B949E),
                    fontSize: 12,
                    fontFamily: 'Siemreap',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Siemreap',
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
