import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:my_app/support_chat_screen.dart';

class AdminSupportInboxScreen extends StatelessWidget {
  const AdminSupportInboxScreen({super.key});

  bool _isEnglish(BuildContext context) =>
      Localizations.localeOf(context).languageCode == 'en';

  String _t(BuildContext context, String km, String en) =>
      _isEnglish(context) ? en : km;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F5),
      appBar: AppBar(
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        title: Text(
          _t(context, 'ប្រអប់សារ Support', 'Support Inbox'),
          style: const TextStyle(fontFamily: 'Siemreap'),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('support_chats')
            .orderBy('updatedAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data?.docs ?? const [];
          if (docs.isEmpty) {
            return Center(
              child: Text(
                _t(context, 'មិនទាន់មានសារ Support', 'No support messages yet'),
                style: const TextStyle(
                  fontFamily: 'Siemreap',
                  color: Colors.grey,
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              final name = (data['userName'] ?? 'Sesan User').toString();
              final last = (data['lastMessage'] ?? '').toString();
              final unread = (data['adminUnread'] ?? 0) is num
                  ? (data['adminUnread'] as num).toInt()
                  : 0;

              return Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: Colors.black12),
                ),
                child: ListTile(
                  onTap: () async {
                    await FirebaseFirestore.instance
                        .collection('support_chats')
                        .doc(doc.id)
                        .set({'adminUnread': 0}, SetOptions(merge: true));
                    if (!context.mounted) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SupportChatScreen(threadUserId: doc.id),
                      ),
                    );
                  },
                  leading: CircleAvatar(
                    backgroundColor: Colors.green.shade50,
                    child: Icon(Icons.person, color: Colors.green.shade700),
                  ),
                  title: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Siemreap',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    last,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontFamily: 'Siemreap'),
                  ),
                  trailing: unread > 0
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            unread > 99 ? '99+' : '$unread',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      : const Icon(Icons.chevron_right_rounded),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
