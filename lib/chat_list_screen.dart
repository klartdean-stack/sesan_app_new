import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:my_app/farm_tools.dart';
import 'package:my_app/order_management_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'chat_screen.dart';
import 'package:flutter/cupertino.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});
  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  Map<String, dynamic>? _foundUser;
  bool _isSearchLoading = false;
  String _searchError = '';
  String? currentUserId;
  bool _isUserLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadUserId();
  }

  Future<void> _loadUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String uid = prefs.getString('user_uid') ?? '';
      if (uid.isEmpty) {
        uid = FirebaseAuth.instance.currentUser?.uid ?? '';
        if (uid.isNotEmpty) {
          await prefs.setString('user_uid', uid);
        }
      }
      if (mounted) {
        setState(() {
          currentUserId = uid.isNotEmpty ? uid : null;
          _isUserLoaded = true;
        });
      }
    } catch (e) {
      debugPrint("Load User ID Error: $e");
      if (mounted) setState(() => _isUserLoaded = true);
    }
  }

  Future<void> _markAsSeen(String chatRoomId) async {
    if (currentUserId == null || currentUserId!.isEmpty) return;
    try {
      final batch = FirebaseFirestore.instance.batch();
      final unreadQuery = await FirebaseFirestore.instance
          .collection('chats')
          .where('chatRoomId', isEqualTo: chatRoomId)
          .where('receiver', isEqualTo: currentUserId)
          .where('status', isNotEqualTo: 'seen')
          .get();
      for (var doc in unreadQuery.docs) {
        batch.update(doc.reference, {'status': 'seen'});
      }
      await batch.commit();
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .update({'unreadCount': 0})
          .catchError((e) => debugPrint("Update unreadCount error: $e"));
    } catch (e) {
      debugPrint("Mark as seen error: $e");
    }
  }

  Future<void> _searchById(String id) async {
    setState(() {
      _isSearchLoading = true;
      _foundUser = null;
      _searchError = '';
    });
    try {
      final result = await FirebaseFirestore.instance
          .collection('users')
          .where('sesan_id', isEqualTo: id)
          .limit(1)
          .get();
      if (result.docs.isEmpty) {
        setState(() {
          _searchError = 'រកមិនឃើញ ID: $id';
          _isSearchLoading = false;
        });
        return;
      }
      final foundData = result.docs.first.data();
      final foundUid = result.docs.first.id;
      if (foundUid == currentUserId) {
        setState(() {
          _searchError = 'នេះគឺជា ID របស់អ្នកផ្ទាល់!';
          _isSearchLoading = false;
        });
        return;
      }
      setState(() {
        _foundUser = {...foundData, 'uid': foundUid};
        _isSearchLoading = false;
      });
    } catch (e) {
      setState(() {
        _searchError = '❌ មានបញ្ហា: $e';
        _isSearchLoading = false;
      });
    }
  }

  void _openChatWithFoundUser(Map<String, dynamic> user) {
    _searchController.clear();
    final targetUid = user['uid']?.toString() ?? '';
    if (targetUid.isEmpty) return;
    setState(() => _foundUser = null);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          seller_id: targetUid,
          receiver_id: targetUid,
          productName: 'Chat',
          productId: 'general',
        ),
      ),
    );
  }@override
  Widget build(BuildContext context) {
    if (!_isUserLoaded) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("បញ្ជីសារ", style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.green[700],
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (currentUserId == null || currentUserId!.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("បញ្ជីសារ", style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.green[700],
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.login, color: Colors.orange, size: 64),
              const SizedBox(height: 16),
              const Text('សូម Login មុននឹងប្រើឆាត', style: TextStyle(fontSize: 18, color: Colors.orange)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('ត្រឡប់ក្រោយ'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
        appBar: PreferredSize(
            preferredSize: const Size.fromHeight(100),
            child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.green[700]!, Colors.green[800]!, Colors.teal[700]!],
                  ),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                          children: [
                      Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                      child: const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Row(
                            children: [
                            const Text("បញ្ជីសារ", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Container(
                                height: 36,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
                                ),
                                child: TextField(
                                    controller: _searchController,
                                    keyboardType: TextInputType.number,
                                    maxLength: 6,
                                    textInputAction: TextInputAction.done,
                                    onSubmitted: (_) => FocusScope.of(context).unfocus(),
                                    onTapOutside: (_) => FocusScope.of(context).unfocus(),
                                    style: const TextStyle(color: Colors.white, fontSize: 13),
                                    onChanged: (v) {setState(() { _foundUser = null; _searchError = ''; });
                                    if (v.length == 6) _searchById(v);
                                    },
                                  decoration: InputDecoration(
                                    hintText: 'Sesan ID...',
                                    hintStyle: const TextStyle(color: Colors.white54, fontSize: 13),
                                    prefixIcon: const Icon(Icons.search, color: Colors.white70, size: 18),
                                    suffixIcon: _searchController.text.isNotEmpty
                                        ? IconButton(
                                      icon: const Icon(Icons.close, color: Colors.white70, size: 18),
                                      onPressed: () {
                                        _searchController.clear();
                                        FocusScope.of(context).unfocus();
                                        setState(() { _foundUser = null; _searchError = ''; });
                                      },
                                    )
                                        : null,
                                    border: InputBorder.none,
                                    counterText: '',
                                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                                    isDense: true,
                                  ),
                                ),
                            ),
                        ),
                            ],
                        ),
                    ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FarmToolsPage())),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
                                ),
                                child: const Icon(Icons.calculate_rounded, color: Colors.white, size: 22),
                              ),
                            ),
                          ],
                      ),
                    ),
                ),
            ),
        ),
        body: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            behavior: HitTestBehavior.opaque,
            child: Column(
                children: [
                if (MediaQuery.of(context).viewInsets.bottom > 0) _buildKeyboardToolbar(),
    if (_isSearchLoading)
    const Padding(
    padding: EdgeInsets.only(top: 12),
    child: CircularProgressIndicator(color: Colors.green),
    ),
    if (_searchError.isNotEmpty) _buildSearchError(),
    if (_foundUser != null) _buildFoundUserTile(),
    Expanded(
    child: StreamBuilder<QuerySnapshot>(
    stream: FirebaseFirestore.instance
        .collection('chats')
        .where('users', arrayContains: currentUserId)
        .orderBy('time', descending: true)
        .snapshots(),
    builder: (context, snapshot) {
    if (snapshot.hasError) return Center(child: Text("មានបញ្ហា៖ ${snapshot.error}"));
    if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return _buildEmptyState();
    final Map<String, Map<String, dynamic>> conversations = {};
    for (var doc in snapshot.data!.docs) {final data = doc.data() as Map<String, dynamic>;
    final roomId = data['chatRoomId'] ?? '';
    if (roomId.isNotEmpty && !conversations.containsKey(roomId)) {
      conversations[roomId] = data;
    }
    }
    final listItems = conversations.values.toList();
    if (listItems.isEmpty) return _buildEmptyState();
    return ListView.builder(
      itemCount: listItems.length,
      itemBuilder: (context, index) {
        var chat = listItems[index];
        final usersList = chat['users'];
        if (usersList == null) return const SizedBox();
        String otherUserId = (usersList as List).firstWhere((id) => id != currentUserId, orElse: () => '');
        if (otherUserId.isEmpty) return const SizedBox();
        return _buildChatTile(chat, otherUserId);
      },
    );
    },
    ),
    ),
                ],
            ),
        ),
    );
  }

  Widget _buildKeyboardToolbar() {
    return Container(
      color: Colors.grey[200],
      height: 44,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            onPressed: () => FocusScope.of(context).unfocus(),
            child: const Text('រួចរាល់', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildChatTile(Map<String, dynamic> chat, String otherUserId) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(otherUserId).snapshots(),
      builder: (context, userSnapshot) {
        var userData = userSnapshot.data?.data() as Map<String, dynamic>?;
        String userName = userData?['name'] ?? 'អ្នកប្រើប្រាស់';
        String userImg = userData?['photoUrl'] ?? '';
        bool isOnline = userData?['isOnline'] == true;
        return ListTile(
          onTap: () async {
            await _markAsSeen(chat['chatRoomId']);
            if (!mounted) return;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChatScreen(
                  seller_id: otherUserId,
                  receiver_id: otherUserId,
                  productName: chat['productName'] ?? 'Chat',
                  productId: chat['productId'] ?? 'general',
                ),
              ),
            );
          },
          leading: _buildAvatarWithUnread(userImg, chat['chatRoomId'], isOnline),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(userName, style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              if (chat['time'] != null)
                Text(_formatTime(chat['time']), style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
          subtitle: Row(
            children: [
              Container(
                width: 7, height: 7,
                margin: const EdgeInsets.only(right: 5),
                decoration: BoxDecoration(color: isOnline ? Colors.green : Colors.grey, shape: BoxShape.circle),
              ),
              Expanded(
                child: Text(
                  isOnline ? 'កំពុង Online' : _formatLastSeen(userData?['lastSeen']),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: isOnline ? Colors.green : Colors.grey),
                ),
              ),
            ],
          ),
        );
      },
    );
  }Widget _buildAvatarWithUnread(String img, String roomId, bool isOnline) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        CircleAvatar(
          radius: 28,
          backgroundImage: img.isNotEmpty ? NetworkImage(img) : null,
          child: img.isEmpty ? const Icon(Icons.person) : null,
        ),
        Positioned(
          bottom: 0, left: 0,
          child: Container(
            width: 13, height: 13,
            decoration: BoxDecoration(
              color: isOnline ? Colors.greenAccent : Colors.grey,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
            ),
          ),
        ),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('chats')
              .where('chatRoomId', isEqualTo: roomId)
              .where('receiver', isEqualTo: currentUserId)
              .where('status', isNotEqualTo: 'seen')
              .snapshots(),
          builder: (context, unread) {
            if (!unread.hasData || unread.data!.docs.isEmpty) return const SizedBox();
            return Positioned(
              right: -2, top: -2,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                child: Center(
                  child: Text('${unread.data!.docs.length}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildFoundUserTile() => GestureDetector(
    onTap: () => _openChatWithFoundUser(_foundUser!),
    child: Container(
      margin: const EdgeInsets.all(10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundImage: (_foundUser?['photoUrl'] != null) ? NetworkImage(_foundUser!['photoUrl']) : null,
            child: (_foundUser?['photoUrl'] == null) ? const Icon(Icons.person) : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_foundUser?['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('ID: ${_foundUser?['sesan_id'] ?? ""}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          const Icon(Icons.chat, color: Colors.green),
        ],
      ),
    ),
  );

  Widget _buildEmptyState() => const Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.chat_bubble_outline, color: Colors.grey, size: 64),
        SizedBox(height: 16),
        Text('មិនទាន់មានការសន្ទនា', style: TextStyle(color: Colors.grey, fontSize: 16)),
        SizedBox(height: 8),
        Text('ចាប់ផ្តើមសន្ទនាជាមួយអ្នកលក់ឥឡូវនេះ!', style: TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    ),
  );

  Widget _buildSearchError() => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Text(_searchError, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
  );String _formatLastSeen(dynamic timestamp) {
    if (timestamp == null) return 'អសកម្ម';
    final time = (timestamp as Timestamp).toDate();
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'ទើបតែសកម្ម';
    if (diff.inMinutes < 60) return 'សកម្ម ${diff.inMinutes} នាទីមុន';
    if (diff.inHours < 24) return 'សកម្ម ${diff.inHours} ម៉ោងមុន';
    return 'សកម្ម ${diff.inDays} ថ្ងៃមុន';
  }

  String _formatTime(Timestamp ts) => DateFormat('hh:mm a').format(ts.toDate());
}