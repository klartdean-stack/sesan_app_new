import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'chat_moderation_menu.dart';
import 'chat_screen_legacy.dart' as legacy;

export 'chat_screen_legacy.dart' hide ChatScreen;

/// iOS chat entry point that keeps the existing chat implementation intact
/// while adding direct moderation actions.
class ChatScreen extends StatefulWidget {
  final String productId;
  final String productName;
  final String seller_id;
  final String receiver_id;

  const ChatScreen({
    super.key,
    required this.productId,
    required this.productName,
    required this.seller_id,
    required this.receiver_id,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  String _currentUserId = '';

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    var uid = prefs.getString('user_uid') ?? '';
    if (uid.isEmpty) {
      uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    }
    if (mounted) setState(() => _currentUserId = uid);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        legacy.ChatScreen(
          productId: widget.productId,
          productName: widget.productName,
          seller_id: widget.seller_id,
          receiver_id: widget.receiver_id,
        ),
        if (_currentUserId.isNotEmpty &&
            widget.seller_id.isNotEmpty &&
            _currentUserId != widget.seller_id)
          Positioned(
            top: MediaQuery.paddingOf(context).top + kToolbarHeight + 6,
            right: 8,
            child: Material(
              color: Colors.green.shade700,
              elevation: 3,
              shape: const CircleBorder(),
              child: ChatModerationMenu(
                currentUserId: _currentUserId,
                targetUserId: widget.seller_id,
              ),
            ),
          ),
      ],
    );
  }
}
