import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'localized_text.dart';

class BlockedListScreen extends StatefulWidget {
  const BlockedListScreen({super.key});

  @override
  State<BlockedListScreen> createState() => _BlockedListScreenState();
}

class _BlockedListScreenState extends State<BlockedListScreen> {
  String? _currentUserId;
  List<Map<String, dynamic>> _blockedUsers = [];
  List<Map<String, dynamic>> _reports = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<String?> _getUserUid() async {
    final prefs = await SharedPreferences.getInstance();
    var uid = prefs.getString('user_uid') ?? '';
    uid = uid.isNotEmpty ? uid : (FirebaseAuth.instance.currentUser?.uid ?? '');
    return uid.isEmpty ? null : uid;
  }

  Future<void> _loadData() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final uid = await _getUserUid();
      if (uid == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = appText(context, km: 'សូម Login ជាមុន', en: 'Please sign in first');
          });
        }
        return;
      }
      _currentUserId = uid;

      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final reportsSnap = await FirebaseFirestore.instance
          .collection('profile_reports')
          .where('reporter_id', isEqualTo: uid)
          .get();

      final ids = List<String>.from((userDoc.data()?['blockedUsers'] as List?) ?? const []);
      final users = <Map<String, dynamic>>[];
      for (final id in ids) {
        final doc = await FirebaseFirestore.instance.collection('users').doc(id).get();
        final data = doc.data() ?? <String, dynamic>{};
        users.add({
          'id': id,
          'name': data['name'] ?? data['shopName'] ?? 'User',
          'sesan_id': data['sesan_id'] ?? data['sesanId'] ?? id,
          'photoUrl': data['photoUrl'] ?? data['profile_image'] ?? '',
        });
      }

      final reports = <Map<String, dynamic>>[];
      for (final reportDoc in reportsSnap.docs) {
        final report = <String, dynamic>{...reportDoc.data(), 'id': reportDoc.id};
        final reportedId = (report['reported_user_id'] ?? report['reportedUserId'] ?? report['reported_id'] ?? '').toString();
        if (reportedId.isNotEmpty) {
          final reportedDoc = await FirebaseFirestore.instance.collection('users').doc(reportedId).get();
          final reportedData = reportedDoc.data() ?? <String, dynamic>{};
          report['reported_user_id'] = reportedId;
          report['reported_user_name'] = report['reported_user_name'] ?? reportedData['name'] ?? reportedData['shopName'] ?? 'User';
          report['reported_user_photo'] = report['reported_user_photo'] ?? reportedData['photoUrl'] ?? reportedData['profile_image'] ?? '';
          report['reported_sesan_id'] = reportedData['sesan_id'] ?? reportedData['sesanId'] ?? reportedId;
        }
        reports.add(report);
      }
      reports.sort((a, b) => _reportTime(b).compareTo(_reportTime(a)));

      if (mounted) {
        setState(() {
          _blockedUsers = users;
          _reports = reports;
          _isLoading = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  int _reportTime(Map<String, dynamic> report) {
    final value = report['time'] ?? report['createdAt'] ?? report['created_at'];
    return value is Timestamp ? value.millisecondsSinceEpoch : 0;
  }

  Future<void> _unblockUser(String userId) async {
    if (_currentUserId == null) return;
    await FirebaseFirestore.instance.collection('users').doc(_currentUserId).set({
      'blockedUsers': FieldValue.arrayRemove([userId]),
    }, SetOptions(merge: true));
    if (mounted) {
      setState(() => _blockedUsers.removeWhere((u) => u['id'] == userId));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(appText(context, km: 'បានដោះ Block រួចរាល់', en: 'User unblocked')),
      ));
    }
  }

  Future<void> _blockReportedUser(String userId) async {
    if (_currentUserId == null || userId.isEmpty) return;
    await FirebaseFirestore.instance.collection('users').doc(_currentUserId).set({
      'blockedUsers': FieldValue.arrayUnion([userId]),
    }, SetOptions(merge: true));
    await _loadData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(appText(context, km: 'បាន Block អ្នកប្រើរួចរាល់', en: 'User blocked')),
      ));
    }
  }

  Future<void> _deleteReport(Map<String, dynamic> report) async {
    final reportId = report['id']?.toString() ?? '';
    if (reportId.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(appText(context, km: 'លុប Report?', en: 'Delete report?')),
        content: Text(appText(
          context,
          km: 'វានឹងលុប Report នេះចេញពីបញ្ជីរបស់អ្នក។',
          en: 'This removes the report from your reported profiles list.',
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(appText(context, km: 'បោះបង់', en: 'Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(appText(context, km: 'លុប', en: 'Delete'), style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await FirebaseFirestore.instance.collection('profile_reports').doc(reportId).delete();
    if (mounted) setState(() => _reports.removeWhere((r) => r['id'] == reportId));
  }

  bool _isBlocked(String userId) => _blockedUsers.any((u) => u['id'].toString() == userId);

  String _reasonLabel(dynamic value) {
    final reason = (value ?? 'other').toString();
    if (Localizations.localeOf(context).languageCode == 'en') return reason;
    const labels = {
      'spam': 'សាររំខាន / Spam',
      'fake': 'គណនីក្លែងក្លាយ',
      'fraud': 'បោកប្រាស់',
      'harassment': 'រំខាន ឬគំរាមកំហែង',
      'inappropriate': 'មាតិកាមិនសមរម្យ',
      'other': 'ផ្សេងៗ',
    };
    return labels[reason.toLowerCase()] ?? reason;
  }

  String _statusLabel(dynamic value) {
    final status = (value ?? 'pending').toString().toLowerCase();
    final english = Localizations.localeOf(context).languageCode == 'en';
    switch (status) {
      case 'resolved':
      case 'completed':
        return english ? 'Resolved' : 'បានដោះស្រាយ';
      case 'rejected':
        return english ? 'Rejected' : 'បានបដិសេធ';
      case 'reviewing':
      case 'in_review':
        return english ? 'Reviewing' : 'កំពុងពិនិត្យ';
      default:
        return english ? 'Pending' : 'កំពុងរង់ចាំ';
    }
  }

  Color _statusColor(dynamic value) {
    final status = (value ?? 'pending').toString().toLowerCase();
    if (status == 'resolved' || status == 'completed') return Colors.green;
    if (status == 'rejected') return Colors.red;
    if (status == 'reviewing' || status == 'in_review') return Colors.blue;
    return Colors.orange;
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(appText(context, km: 'គ្រប់គ្រង Block និង Report', en: 'Blocked & reported')),
          backgroundColor: Colors.green[700],
          foregroundColor: Colors.white,
          actions: [
            IconButton(onPressed: _loadData, icon: const Icon(Icons.refresh)),
          ],
          bottom: TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: appText(context, km: 'បាន Block (${_blockedUsers.length})', en: 'Blocked (${_blockedUsers.length})')),
              Tab(text: appText(context, km: 'បាន Report (${_reports.length})', en: 'Reported (${_reports.length})')),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? _errorView()
                : TabBarView(children: [_blockedTab(), _reportedTab()]),
      ),
    );
  }

  Widget _errorView() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 42, color: Colors.redAccent),
              const SizedBox(height: 10),
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _loadData, child: Text(appText(context, km: 'ព្យាយាមម្ដងទៀត', en: 'Try again'))),
            ],
          ),
        ),
      );

  Widget _blockedTab() {
    if (_blockedUsers.isEmpty) {
      return _empty(Icons.person_off_outlined, appText(context, km: 'មិនទាន់មានអ្នកប្រើដែលបាន Block', en: 'No blocked users'));
    }
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _blockedUsers.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, index) {
          final user = _blockedUsers[index];
          final photo = user['photoUrl'].toString();
          return Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundImage: photo.isNotEmpty ? CachedNetworkImageProvider(photo) : null,
                child: photo.isEmpty ? const Icon(Icons.person) : null,
              ),
              title: Text(user['name'].toString(), maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text('Sesan ID: ${user['sesan_id']}', style: const TextStyle(fontSize: 11)),
              trailing: TextButton(
                onPressed: () => _unblockUser(user['id'].toString()),
                child: Text(appText(context, km: 'ដោះ Block', en: 'Unblock')),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _reportedTab() {
    if (_reports.isEmpty) {
      return _empty(Icons.outlined_flag, appText(context, km: 'មិនទាន់មាន Profile ដែលបាន Report', en: 'No reported profiles'));
    }
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _reports.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, index) {
          final report = _reports[index];
          final userId = (report['reported_user_id'] ?? '').toString();
          final photo = (report['reported_user_photo'] ?? '').toString();
          final blocked = userId.isNotEmpty && _isBlocked(userId);
          final statusColor = _statusColor(report['status']);
          return Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundImage: photo.isNotEmpty ? CachedNetworkImageProvider(photo) : null,
                  child: photo.isEmpty ? const Icon(Icons.person_outline) : null,
                ),
                title: Text((report['reported_user_name'] ?? 'User').toString(), maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if ((report['reported_sesan_id'] ?? '').toString().isNotEmpty)
                      Text('Sesan ID: ${report['reported_sesan_id']}', style: const TextStyle(fontSize: 11)),
                    const SizedBox(height: 3),
                    Text(_reasonLabel(report['reason']), style: const TextStyle(fontSize: 11)),
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(color: statusColor.withOpacity(.12), borderRadius: BorderRadius.circular(20)),
                      child: Text(_statusLabel(report['status']), style: TextStyle(fontSize: 10, color: statusColor, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'block' && userId.isNotEmpty) _blockReportedUser(userId);
                    if (value == 'unblock' && userId.isNotEmpty) _unblockUser(userId);
                    if (value == 'delete_report') _deleteReport(report);
                  },
                  itemBuilder: (_) => [
                    if (userId.isNotEmpty)
                      PopupMenuItem(
                        value: blocked ? 'unblock' : 'block',
                        child: Row(children: [
                          Icon(blocked ? Icons.lock_open : Icons.block, size: 18),
                          const SizedBox(width: 8),
                          Text(blocked ? appText(context, km: 'ដោះ Block', en: 'Unblock') : appText(context, km: 'Block អ្នកប្រើ', en: 'Block user')),
                        ]),
                      ),
                    PopupMenuItem(
                      value: 'delete_report',
                      child: Row(children: [
                        const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                        const SizedBox(width: 8),
                        Text(appText(context, km: 'លុបចេញពីបញ្ជី', en: 'Remove from list')),
                      ]),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _empty(IconData icon, String text) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 54, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
      );
}
