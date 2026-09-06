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
    try {
      final uid = await _getUserUid();
      if (uid == null) {
        if (mounted) setState(() {
          _isLoading = false;
          _errorMessage = appText(context, km: 'សូម Login ជាមុន', en: 'Please sign in first');
        });
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
      final reports = reportsSnap.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();
      reports.sort((a, b) {
        final at = a['time'] is Timestamp ? (a['time'] as Timestamp).millisecondsSinceEpoch : 0;
        final bt = b['time'] is Timestamp ? (b['time'] as Timestamp).millisecondsSinceEpoch : 0;
        return bt.compareTo(at);
      });
      if (mounted) setState(() {
        _blockedUsers = users;
        _reports = reports;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      if (mounted) setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _unblockUser(String userId) async {
    if (_currentUserId == null) return;
    await FirebaseFirestore.instance.collection('users').doc(_currentUserId).set({
      'blockedUsers': FieldValue.arrayRemove([userId]),
    }, SetOptions(merge: true));
    if (mounted) setState(() => _blockedUsers.removeWhere((u) => u['id'] == userId));
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(appText(context, km: 'Block និង Report', en: 'Blocked & reported')),
          backgroundColor: Colors.green[700],
          foregroundColor: Colors.white,
          bottom: TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: appText(context, km: 'បាន Block', en: 'Blocked')),
              Tab(text: appText(context, km: 'បាន Report', en: 'Reported')),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? Center(child: Text(_errorMessage!, textAlign: TextAlign.center))
                : TabBarView(children: [_blockedTab(), _reportedTab()]),
      ),
    );
  }

  Widget _blockedTab() {
    if (_blockedUsers.isEmpty) {
      return Center(child: Text(appText(context, km: 'មិនទាន់មានអ្នកប្រើដែលបាន Block', en: 'No blocked users')));
    }
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        itemCount: _blockedUsers.length,
        itemBuilder: (_, index) {
          final user = _blockedUsers[index];
          final photo = user['photoUrl'].toString();
          return ListTile(
            leading: CircleAvatar(
              backgroundImage: photo.isNotEmpty ? CachedNetworkImageProvider(photo) : null,
              child: photo.isEmpty ? const Icon(Icons.person) : null,
            ),
            title: Text(user['name'].toString(), maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text('Sesan ID: ${user['sesan_id']}'),
            trailing: TextButton(
              onPressed: () => _unblockUser(user['id'].toString()),
              child: Text(appText(context, km: 'ដោះ Block', en: 'Unblock')),
            ),
          );
        },
      ),
    );
  }

  Widget _reportedTab() {
    if (_reports.isEmpty) {
      return Center(child: Text(appText(context, km: 'មិនទាន់មាន Profile ដែលបាន Report', en: 'No reported profiles')));
    }
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        itemCount: _reports.length,
        itemBuilder: (_, index) {
          final report = _reports[index];
          return ListTile(
            leading: const CircleAvatar(child: Icon(Icons.flag_outlined)),
            title: Text((report['reported_user_name'] ?? 'User').toString()),
            subtitle: Text('${report['reason'] ?? 'other'} • ${report['status'] ?? 'pending'}'),
          );
        },
      ),
    );
  }
}
