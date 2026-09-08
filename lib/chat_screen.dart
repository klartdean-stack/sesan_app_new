import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'chat_moderation_menu.dart';
import 'chat_screen_legacy.dart' as legacy;
import 'localized_text.dart';

export 'chat_screen_legacy.dart' hide ChatScreen;

/// iOS chat entry point that preserves the existing chat implementation while
/// enforcing Sesan block privacy and exposing direct Block/Report actions.
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

  /// Resolve the other participant instead of assuming seller_id is always
  /// the moderation target. This makes Block/Report work in both directions:
  /// buyer -> seller and seller -> buyer.
  String get _peerUserId {
    if (_currentUserId.isEmpty) return '';

    final sellerId = widget.seller_id.trim();
    final receiverId = widget.receiver_id.trim();

    if (sellerId.isNotEmpty && sellerId != _currentUserId) {
      return sellerId;
    }
    if (receiverId.isNotEmpty && receiverId != _currentUserId) {
      return receiverId;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final peerUserId = _peerUserId;

    if (_currentUserId.isEmpty || peerUserId.isEmpty) {
      return legacy.ChatScreen(
        productId: widget.productId,
        productName: widget.productName,
        seller_id: widget.seller_id,
        receiver_id: widget.receiver_id,
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUserId)
          .snapshots(),
      builder: (context, mySnapshot) {
        if (!mySnapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(peerUserId)
              .snapshots(),
          builder: (context, theirSnapshot) {
            if (!theirSnapshot.hasData) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final myBlocked = List<String>.from(
              (mySnapshot.data?.data()?['blockedUsers'] as List?) ?? const [],
            );
            final theirBlocked = List<String>.from(
              (theirSnapshot.data?.data()?['blockedUsers'] as List?) ?? const [],
            );

            final blockedByMe = myBlocked.contains(peerUserId);
            final blockedByThem = theirBlocked.contains(_currentUserId);

            if (blockedByMe || blockedByThem) {
              return _buildBlockedChat(
                context,
                peerUserId: peerUserId,
                blockedByMe: blockedByMe,
                blockedByThem: blockedByThem,
              );
            }

            return Stack(
              children: [
                legacy.ChatScreen(
                  productId: widget.productId,
                  productName: widget.productName,
                  seller_id: widget.seller_id,
                  receiver_id: widget.receiver_id,
                ),
                Positioned(
                  top: MediaQuery.paddingOf(context).top + kToolbarHeight + 6,
                  right: 8,
                  child: Material(
                    color: Colors.green.shade700,
                    elevation: 3,
                    shape: const CircleBorder(),
                    child: ChatModerationMenu(
                      currentUserId: _currentUserId,
                      targetUserId: peerUserId,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildBlockedChat(
    BuildContext context, {
    required String peerUserId,
    required bool blockedByMe,
    required bool blockedByThem,
  }) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        title: Text(
          appText(context, km: 'ឆាត', en: 'Chat'),
          style: const TextStyle(fontFamily: 'Siemreap'),
        ),
        actions: [
          ChatModerationMenu(
            currentUserId: _currentUserId,
            targetUserId: peerUserId,
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.block_rounded,
                size: 72,
                color: Colors.red.shade300,
              ),
              const SizedBox(height: 18),
              Text(
                appText(
                  context,
                  km: 'មិនអាចប្រើឆាតនេះបានទេ',
                  en: 'This chat is unavailable',
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Siemreap',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                blockedByMe
                    ? appText(
                        context,
                        km: 'អ្នកបាន Block អ្នកប្រើនេះ។ សារ និង Content រវាងគ្នាត្រូវបានលាក់។ អ្នកអាចដោះ Block តាមម៉ឺនុយខាងលើ។',
                        en: 'You blocked this user. Messages and content between you are hidden. You can unblock from the menu above.',
                      )
                    : appText(
                        context,
                        km: 'អ្នកប្រើនេះបាន Block អ្នក។ សារ និង Content រវាងគ្នាត្រូវបានលាក់។',
                        en: 'This user blocked you. Messages and content between you are hidden.',
                      ),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Siemreap',
                  fontSize: 13,
                  height: 1.6,
                  color: Colors.grey.shade600,
                ),
              ),
              if (blockedByMe && blockedByThem) ...[
                const SizedBox(height: 10),
                Text(
                  appText(
                    context,
                    km: 'ភាគីទាំងពីរបាន Block គ្នា។',
                    en: 'Both users have blocked each other.',
                  ),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
