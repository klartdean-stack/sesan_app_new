import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'product_detail.dart';

class UserNotificationScreen extends StatefulWidget {
  const UserNotificationScreen({super.key});

  @override
  State<UserNotificationScreen> createState() => _UserNotificationScreenState();
}

class _UserNotificationScreenState extends State<UserNotificationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadUserId();
    _tabController.addListener(_onTabChanged); // ✅ បន្ថែម
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      // តែពេល Tab ផ្លាស់ប្ដូរចប់
      final index = _tabController.index;
      if (index == 1) {
        _markNotificationsAsRead(['new_comment', 'comment_reply']);
      } else if (index == 2) {
        _markNotificationsAsRead(['new_rating']); // បើចង់ឲ្យពិន្ទុក៏ដូចគ្នា
      }
    }
  }

  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _currentUserId = prefs.getString('user_uid') ?? '';
      });
    }
  }

  Future<void> _markNotificationsAsRead(List<String> types) async {
    if (_currentUserId == null || _currentUserId!.isEmpty) return;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUserId)
          .collection('notifications')
          .where('type', whereIn: types)
          .where('isRead', isEqualTo: false)
          .get();

      if (snapshot.docs.isEmpty) return;

      final batch = FirebaseFirestore.instance.batch();
      for (var doc in snapshot.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e) {
      debugPrint("Error marking notifications as read: $e");
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: const Color(0xFFF0F2F8),
        appBar: AppBar(
            title: const Text(
              'ការជូនដំណឹង',
              style: TextStyle(
                fontFamily: 'Siemreap',
                color: Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            backgroundColor: Colors.white,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.black87),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(50),
              child: TabBar(
                controller: _tabController,
                indicatorColor: const Color(0xFF3B5BFF),
                labelColor: Colors.black87,
                unselectedLabelColor: Colors.grey,
                isScrollable: false,
                tabs: [
              // Tab 1: ដំណឹងទូទៅ
              const Tab(
              child: Text(
              'ដំណឹងទូទៅ',
                style: TextStyle(fontFamily: 'Siemreap', fontSize: 12),
              ),
            ),
            // Tab 2: មតិយោបល់ (មាន Badge)
            StreamBuilder<QuerySnapshot>(
                stream: _currentUserId != null && _currentUserId!.isNotEmpty
                    ? FirebaseFirestore.instance
                    .collection('users')
                    .doc(_currentUserId)
                    .collection('notifications')
                    .where(
                  'type',
                  whereIn: ['new_comment', 'comment_reply'],
                )
                    .where('isRead', isEqualTo: false)
                    .snapshots()
                    : Stream.empty(),
                builder: (context, snapshot) {
                  int count = snapshot.hasData ? snapshot.data!.docs.length : 0;
                  return Tab(
                      child: Stack(clipBehavior: Clip.none,
                        children: [
                          const Text(
                            'មតិយោបល់',
                            style: TextStyle(
                              fontFamily: 'Siemreap',
                              fontSize: 12,
                            ),
                          ),
                          if (count > 0)
                            Positioned(
                              right: -18,
                              top: -4,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 18,
                                  minHeight: 18,
                                ),
                                child: Text(
                                  '$count',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                        ],
                      ),
                  );
                },
            ),
                  // Tab 3: ពិន្ទុ (អាចបន្ថែម Badge ស្រដៀងគ្នា)
                  const Tab(
                    child: Text(
                      'ពិន្ទុ',
                      style: TextStyle(fontFamily: 'Siemreap', fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
        ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAnnouncementsTab(),
          _buildPersonalTab(type: 'comment'), // មតិយោបល់
          _buildPersonalTab(type: 'rating'), // ពិន្ទុ
        ],
      ),
    );
  }

  // ── ផ្ទាំង Announcement (កូដដើមរបស់អ្នក) ─────
  Widget _buildAnnouncementsTab() {
    return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('announcements')
            .orderBy('created_at', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF3B5BFF)),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.notifications_none_rounded,
                      size: 64,
                      color: Colors.grey.shade400,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'មិនទាន់មានដំណឹងថ្មីឡើយ',
                    style: TextStyle(
                      fontFamily: 'Siemreap',
                      color: Colors.grey.shade500,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final data = docs[index].data() as Map<String, dynamic>;
                final isFirst = index == 0;
                return _NotiCard(data: data, isNew: isFirst, isPersonal: false);},
          );
        },
    );
  }

  // ── ផ្ទាំង Personal Notifications (មតិយោបល់ និងពិន្ទុ) ──
  Widget _buildPersonalTab({required String type}) {
    if (_currentUserId == null || _currentUserId!.isEmpty) {
      return const Center(child: Text('កំពុងផ្ទុក...'));
    }

    // កំណត់តម្រងតាមប្រភេទ
    String filterType;
    switch (type) {
      case 'comment':
        filterType = 'new_comment'; // ឬ 'comment_reply'
        break;
      case 'rating':
        filterType = 'new_rating'; // សន្មតថាប្រើ type នេះ
        break;
      default:
        filterType = 'new_comment';
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUserId)
          .collection('notifications')
          .where('type', isEqualTo: filterType)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF3B5BFF)),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          String emptyMessage;
          IconData emptyIcon;
          if (type == 'comment') {
            emptyMessage = 'មិនមានការជូនដំណឹងពីមតិ';
            emptyIcon = Icons.comment_bank_outlined;
          } else {
            emptyMessage = 'មិនមានការជូនដំណឹងពីពិន្ទុ';
            emptyIcon = Icons.star_border_rounded;
          }
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(emptyIcon, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 20),
                Text(
                  emptyMessage,
                  style: TextStyle(
                    fontFamily: 'Siemreap',
                    color: Colors.grey.shade500,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          );
        }

        final docs = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            return _NotiCard(
              data: data,
              isNew: false,
              isPersonal: true,
              onTap: () => _handlePersonalNotificationTap(data),
            );
          },
        );
      },
    );
  }

  Future<void> _handlePersonalNotificationTap(Map<String, dynamic> data) async {
    // ទាញ productId ពី data (អាស្រ័យលើ Cloud Function ថាដាក់ key អ្វី)
    final String? productId = data['productId'] ?? data['product_id'];
    if (productId != null && productId.isNotEmpty) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('products')
            .doc(productId)
            .get();
        if (doc.exists) {
          final product = doc.data()!;
          product['id'] = productId;
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProductDetailScreen(product: product),
              ),
            );
          }
        }
      } catch (e) {
        debugPrint("Error fetching product: $e");
      }
    }
  }
}

// ── Notification Card (ដូចដើម កែបន្តិចបន្តួច) ──
class _NotiCard extends StatefulWidget {
  final Map<String, dynamic> data;
  final bool isNew;
  final bool isPersonal;
  final VoidCallback? onTap;

  const _NotiCard({
    required this.data,
    this.isNew = false,
    this.isPersonal = false,
    this.onTap,
  });

  @override
  State<_NotiCard> createState() => _NotiCardState();
}

class _NotiCardState extends State<_NotiCard> {
  bool _isExpanded = false;
  static const int _maxChars = 150;

  _NotiStyle _getStyle(String? type, bool personal) {
    if (personal) {
      // ប្រភេទសម្រាប់personal
      if (type == 'comment_reply') {
        return _NotiStyle(
          color: const Color(0xFF8B5CF6),
          bg: const Color(0xFFF3EEFF),
          icon: Icons.reply_rounded,
        );
      } else if (type == 'new_comment') {
        return _NotiStyle(
          color: const Color(0xFF3B5BFF),
          bg: const Color(0xFFEEF2FF),
          icon: Icons.chat_bubble_rounded,
        );
      } else if (type == 'new_rating') {
        return _NotiStyle(
          color: const Color(0xFFFFB300), // ពណ៌មាស
          bg: const Color(0xFFFFF8E1),
          icon: Icons.star_rounded,
        );
      }
      // បើមិនស្គាល់
      return _NotiStyle(
        color: const Color(0xFF3B5BFF),
        bg: const Color(0xFFEEF2FF),
        icon: Icons.notifications_rounded,
      );
    }

    // សម្រាប់ announcements
    switch (type) {
      case 'warning':
        return _NotiStyle(
          color: const Color(0xFFFF6B35),
          bg: const Color(0xFFFFF3EE),
          icon: Icons.warning_amber_rounded,
        );
      case 'success':
        return _NotiStyle(
          color: const Color(0xFF2DCB73),
          bg: const Color(0xFFEEFBF4),
          icon: Icons.check_circle_rounded,
        );
      case 'info':
        return _NotiStyle(
          color: const Color(0xFF3B5BFF),
          bg: const Color(0xFFEEF2FF),
          icon: Icons.info_rounded,
        );
      default:
        return _NotiStyle(
          color: const Color(0xFF3B5BFF),
          bg: const Color(0xFFEEF2FF),
          icon: Icons.campaign_rounded,
        );
    }
  }

  String _formatDate(dynamic ts) {
    if (ts == null) return '';
    try {
      final date = (ts as Timestamp).toDate();
      return DateFormat('dd MMM yyyy • HH:mm').format(date);
    } catch (_) {
      return '';
    }
  }

  String _getTitle(Map<String, dynamic> data, bool personal) {
    if (personal) return data['title'] ?? '';
    return data['title'] ?? '';
  }

  String _getBody(Map<String, dynamic> data, bool personal) {
    if (personal) return data['body'] ?? '';
    return data['message'] ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final personal = widget.isPersonal;
    final title = _getTitle(widget.data, personal);
    final body = _getBody(widget.data, personal);
    final type = widget.data['type'] as String?;
    final style = _getStyle(type, personal);
    final date = personal
        ? _formatDate(widget.data['createdAt'])
        : _formatDate(widget.data['created_at']);
    final isLong = body.length > _maxChars;

    return GestureDetector(
        onTap: widget.onTap,
        child: Container(
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: style.color.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    Container(height: 4, color: style.color),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                      Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                  Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: style.bg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(style.icon, color: style.color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Colors.black87,
                              fontFamily: 'Siemreap',
                              height: 1.4,
                            ),
                          ),
                        ),
                        if (widget.isNew && !personal)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'ថ្មី',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontFamily: 'Siemreap',
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (date.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 12,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            date,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade400,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
                ),
                      ],
                  ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Divider(height: 1, color: Colors.grey.shade100),
                    ),
                    AnimatedCrossFade(
                        firstChild: Text(
                          body,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            height: 1.6,
                            color: Colors.grey.shade700,
                            fontSize: 13.5,
                            fontFamily: 'Siemreap',
                          ),
                        ),
                        secondChild: Text(
                            body,
                            style: TextStyle(
                              height: 1.6,
                              color: Colors.grey.shade700,
                              fontSize: 13.5,fontFamily: 'Siemreap',
                            ),
                        ),
                      crossFadeState: _isExpanded
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                      duration: const Duration(milliseconds: 200),
                    ),
                        if (isLong)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: () =>
                                  setState(() => _isExpanded = !_isExpanded),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _isExpanded ? 'បិទវិញ' : 'មើលបន្ថែម',
                                    style: TextStyle(
                                      color: style.color,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      fontFamily: 'Siemreap',
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    _isExpanded
                                        ? Icons.keyboard_arrow_up_rounded
                                        : Icons.keyboard_arrow_down_rounded,
                                    color: style.color,
                                    size: 18,
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                  ),
                ),
                    ],
                ),
            ),
        ),
    );
  }
}

// ── Style Model ───────────────────────────────────────────
class _NotiStyle {
  final Color color;
  final Color bg;
  final IconData icon;

  _NotiStyle({required this.color, required this.bg, required this.icon});
}