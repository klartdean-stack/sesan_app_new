import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'localized_text.dart';

class ChatModerationMenu extends StatelessWidget {
  final String currentUserId;
  final String targetUserId;

  const ChatModerationMenu({
    super.key,
    required this.currentUserId,
    required this.targetUserId,
  });

  @override
  Widget build(BuildContext context) {
    if (currentUserId.isEmpty ||
        targetUserId.isEmpty ||
        currentUserId == targetUserId) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .snapshots(),
      builder: (context, snapshot) {
        final blocked = List<String>.from(
          (snapshot.data?.data()?['blockedUsers'] as List?) ?? const [],
        );
        final isBlocked = blocked.contains(targetUserId);

        return PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.white),
          onSelected: (value) async {
            if (value == 'block') {
              await _confirmBlock(context);
            } else if (value == 'unblock') {
              await _unblock(context);
            } else if (value == 'report') {
              await _showReportDialog(context);
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem<String>(
              value: isBlocked ? 'unblock' : 'block',
              child: Row(
                children: [
                  Icon(
                    isBlocked ? Icons.lock_open : Icons.block,
                    color: isBlocked ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    isBlocked
                        ? appText(context, km: 'ដោះ Block', en: 'Unblock')
                        : appText(context, km: 'Block អ្នកប្រើ', en: 'Block user'),
                  ),
                ],
              ),
            ),
            PopupMenuItem<String>(
              value: 'report',
              child: Row(
                children: [
                  const Icon(Icons.flag_outlined, color: Colors.orange),
                  const SizedBox(width: 10),
                  Text(
                    appText(
                      context,
                      km: 'រាយការណ៍ Profile',
                      en: 'Report profile',
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmBlock(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          appText(context, km: 'Block អ្នកប្រើនេះ?', en: 'Block this user?'),
        ),
        content: Text(
          appText(
            context,
            km: 'អ្នកអាចដោះ Block វិញនៅក្នុង Settings > Block និង Report។',
            en: 'You can unblock later in Settings > Blocked & reported profiles.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(appText(context, km: 'បោះបង់', en: 'Cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Block'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await FirebaseFirestore.instance.collection('users').doc(currentUserId).set({
      'blockedUsers': FieldValue.arrayUnion([targetUserId]),
    }, SetOptions(merge: true));

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            appText(
              context,
              km: 'បាន Block អ្នកប្រើនេះរួចរាល់',
              en: 'User blocked successfully',
            ),
          ),
        ),
      );
    }
  }

  Future<void> _unblock(BuildContext context) async {
    await FirebaseFirestore.instance.collection('users').doc(currentUserId).set({
      'blockedUsers': FieldValue.arrayRemove([targetUserId]),
    }, SetOptions(merge: true));

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            appText(
              context,
              km: 'បានដោះ Block រួចរាល់',
              en: 'User unblocked successfully',
            ),
          ),
        ),
      );
    }
  }

  Future<void> _showReportDialog(BuildContext context) async {
    String selectedReason = 'fake_profile';
    final detailsController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            appText(context, km: 'រាយការណ៍ Profile', en: 'Report profile'),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedReason,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: appText(
                      context,
                      km: 'មូលហេតុ',
                      en: 'Reason',
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'fake_profile',
                      child: Text(
                        appText(context, km: 'Profile ក្លែងក្លាយ', en: 'Fake profile'),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'scam',
                      child: Text(
                        appText(context, km: 'ឆបោក ឬបោកប្រាស់', en: 'Scam or fraud'),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'harassment',
                      child: Text(
                        appText(context, km: 'រំខាន ឬគំរាមកំហែង', en: 'Harassment'),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'inappropriate_content',
                      child: Text(
                        appText(context, km: 'Content មិនសមរម្យ', en: 'Inappropriate content'),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'other',
                      child: Text(appText(context, km: 'ផ្សេងៗ', en: 'Other')),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => selectedReason = value);
                    }
                  },
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: detailsController,
                  maxLines: 4,
                  maxLength: 500,
                  decoration: InputDecoration(
                    labelText: appText(
                      context,
                      km: 'ព័ត៌មានបន្ថែម',
                      en: 'Additional details',
                    ),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(appText(context, km: 'បោះបង់', en: 'Cancel')),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(dialogContext);
                await _submitReport(
                  context,
                  selectedReason,
                  detailsController.text.trim(),
                );
              },
              icon: const Icon(Icons.send),
              label: Text(appText(context, km: 'បញ្ជូន', en: 'Submit')),
            ),
          ],
        ),
      ),
    );

    detailsController.dispose();
  }

  Future<void> _submitReport(
    BuildContext context,
    String reason,
    String details,
  ) async {
    final docs = await Future.wait([
      FirebaseFirestore.instance.collection('users').doc(currentUserId).get(),
      FirebaseFirestore.instance.collection('users').doc(targetUserId).get(),
    ]);
    final reporterData = docs[0].data() ?? <String, dynamic>{};
    final reportedData = docs[1].data() ?? <String, dynamic>{};

    await FirebaseFirestore.instance.collection('profile_reports').add({
      'reporter_id': currentUserId,
      'reporter_name': reporterData['name'] ?? 'Unknown',
      'reported_user_id': targetUserId,
      'reported_user_name': reportedData['name'] ?? 'Unknown',
      'reason': reason,
      'details': details,
      'time': FieldValue.serverTimestamp(),
      'status': 'pending',
      'source': 'chat',
    });

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            appText(
              context,
              km: 'បានបញ្ជូន Report ទៅ Admin រួចរាល់',
              en: 'Report submitted to admin',
            ),
          ),
        ),
      );
    }
  }
}
