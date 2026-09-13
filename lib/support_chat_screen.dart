import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SupportChatScreen extends StatefulWidget {
  final String? threadUserId;

  const SupportChatScreen({super.key, this.threadUserId});

  @override
  State<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends State<SupportChatScreen> {
  static const String _adminUid = 'WBdQVvrgEIPBTcgIlumu6bAZGUl2';

  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();

  String? _currentUid;
  String? _threadUid;
  String _userName = 'Sesan User';
  bool _loading = true;
  bool _sending = false;

  bool get _isAdmin => _currentUid == _adminUid;
  bool get _isEnglish =>
      Localizations.localeOf(context).languageCode == 'en';
  String _t(String km, String en) => _isEnglish ? en : km;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final authUid = FirebaseAuth.instance.currentUser?.uid;
    final uid = (authUid?.isNotEmpty == true)
        ? authUid
        : prefs.getString('user_uid');

    if (uid == null || uid.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    final threadUid = uid == _adminUid && widget.threadUserId?.isNotEmpty == true
        ? widget.threadUserId!
        : uid;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(threadUid)
          .get();
      _userName = (userDoc.data()?['name'] ?? 'Sesan User').toString();
    } catch (_) {}

    if (mounted) {
      setState(() {
        _currentUid = uid;
        _threadUid = threadUid;
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  DocumentReference<Map<String, dynamic>> get _threadRef =>
      FirebaseFirestore.instance.collection('support_chats').doc(_threadUid);

  CollectionReference<Map<String, dynamic>> get _messagesRef =>
      _threadRef.collection('messages');

  Future<void> _sendText() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending || _threadUid == null) return;
    _controller.clear();
    await _sendMessage(text: text);
  }

  Future<void> _pickImage() async {
    if (_sending || _threadUid == null) return;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(_t('ជ្រើសពី Gallery', 'Choose from gallery')),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: Text(_t('ថតរូបថ្មី', 'Take a photo')),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final image = await _picker.pickImage(
      source: source,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 82,
    );
    if (image == null) return;

    setState(() => _sending = true);
    try {
      final Uint8List bytes = await image.readAsBytes();
      if (bytes.isEmpty || bytes.length > 6 * 1024 * 1024) {
        throw StateError('Image too large');
      }
      final fileName =
          'support_${_threadUid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = FirebaseStorage.instance
          .ref()
          .child('support_images/$_threadUid/$fileName');
      await ref.putData(
        bytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      final url = await ref.getDownloadURL();
      await _sendMessage(
        text: _t('📷 រូបភាព', '📷 Image'),
        imageUrl: url,
        manageSendingState: false,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_t(
              'មិនអាចផ្ញើរូបបានទេ',
              'Could not send this image',
            )),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendMessage({
    required String text,
    String imageUrl = '',
    bool manageSendingState = true,
  }) async {
    if (_threadUid == null || _currentUid == null) return;
    if (manageSendingState && mounted) setState(() => _sending = true);

    final senderType = _isAdmin ? 'admin' : 'user';
    try {
      final message = <String, dynamic>{
        'senderId': _currentUid,
        'senderType': senderType,
        'text': text,
        'imageUrl': imageUrl,
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
      };
      await _messagesRef.add(message);

      await _threadRef.set({
        'userId': _threadUid,
        'userName': _userName,
        'adminId': _adminUid,
        'lastMessage': text,
        'lastSenderType': senderType,
        'updatedAt': FieldValue.serverTimestamp(),
        'status': 'open',
        if (!_isAdmin) 'adminUnread': FieldValue.increment(1),
        if (_isAdmin) 'userUnread': FieldValue.increment(1),
      }, SetOptions(merge: true));

      _scrollToBottom();
    } finally {
      if (manageSendingState && mounted) setState(() => _sending = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.green)),
      );
    }

    if (_currentUid == null || _threadUid == null) {
      return Scaffold(
        appBar: AppBar(title: Text(_t('ជំនួយ', 'Support'))),
        body: Center(
          child: Text(_t('សូម Login ជាមុនសិន', 'Please sign in first')),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F5),
      appBar: AppBar(
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        titleSpacing: 0,
        title: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(_adminUid)
              .snapshots(),
          builder: (context, snapshot) {
            final data = snapshot.data?.data();
            final online = data?['isOnline'] == true;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isAdmin
                      ? _userName
                      : _t('Sesan Support', 'Sesan Support'),
                  style: const TextStyle(
                    fontFamily: 'Siemreap',
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  _isAdmin
                      ? _t('Support conversation', 'Support conversation')
                      : online
                          ? _t('AI Support • Admin Online', 'AI Support • Admin online')
                          : _t('AI Support • Admin Offline',
                              'AI Support • Admin offline'),
                  style: const TextStyle(
                    fontFamily: 'Siemreap',
                    fontSize: 11,
                    color: Colors.white70,
                  ),
                ),
              ],
            );
          },
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _messagesRef
                  .orderBy('createdAt', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data?.docs ?? const [];
                if (docs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Text(
                        _t(
                          'សរសេរសាររបស់អ្នកមក Sesan Support។ AI នឹងជួយឆ្លើយជាមុនដោយឥតគិត AI Credit។ ពេល Admin ចូលឆ្លើយ AI នឹងផ្អាក ហើយបើ Admin Offline វានឹងចូលជួយវិញដោយស្វ័យប្រវត្តិ។',
                          'Send your message to Sesan Support. AI answers first for free. When Admin joins and replies, AI pauses; if Admin goes offline, AI automatically resumes support.',
                        ),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'Siemreap',
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  );
                }
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients) {
                    _scrollController.jumpTo(
                      _scrollController.position.maxScrollExtent,
                    );
                  }
                });
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(12),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data();
                    final senderType = (data['senderType'] ?? 'user').toString();
                    final mine = _isAdmin
                        ? senderType == 'admin'
                        : senderType == 'user';
                    final imageUrl = (data['imageUrl'] ?? '').toString();
                    final text = (data['text'] ?? '').toString();
                    final label = senderType == 'admin'
                        ? 'Sesan Support'
                        : senderType == 'ai'
                            ? 'AI Assistant'
                            : _userName;
                    return Align(
                      alignment:
                          mine ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.78,
                        ),
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: mine ? Colors.green.shade100 : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.black12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              label,
                              style: TextStyle(
                                fontFamily: 'Siemreap',
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: senderType == 'ai'
                                    ? Colors.deepPurple
                                    : Colors.green.shade800,
                              ),
                            ),
                            if (imageUrl.isNotEmpty) ...[
                              const SizedBox(height: 5),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(
                                  imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.broken_image_outlined,
                                  ),
                                ),
                              ),
                            ],
                            if (text.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                text,
                                style: const TextStyle(
                                  fontFamily: 'Siemreap',
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(8, 7, 8, 8),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.black12)),
              ),
              child: Row(
                children: [
                  IconButton(
                    tooltip: _t('ផ្ញើរូប', 'Send image'),
                    onPressed: _sending ? null : _pickImage,
                    icon: const Icon(Icons.image_outlined, color: Colors.green),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        hintText: _t('សរសេរសារ...', 'Write a message...'),
                        hintStyle: const TextStyle(fontFamily: 'Siemreap'),
                        filled: true,
                        fillColor: const Color(0xFFF3F5F3),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                    ),
                    onPressed: _sending ? null : _sendText,
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
