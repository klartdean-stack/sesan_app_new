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

  String _t(String km, String en) =>
      Localizations.localeOf(context).languageCode == 'en' ? en : km;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadUserId();
    _tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      if (_tabController.index == 1) {
        _markNotificationsAsRead(['new_comment', 'comment_reply']);
      } else if (_tabController.index == 2) {
        _markNotificationsAsRead(['new_rating']);
      }
    }
  }

  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _currentUserId = prefs.getString('user_uid') ?? '');
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
      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Error marking notifications as read: $e');
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F8),
      appBar: AppBar(
        title: Text(
          _t('ការជូនដំណឹង', 'Notifications'),
          style: const TextStyle(
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
            tabs: [
              Tab(child: Text(_t('ដំណឹងទូទៅ', 'General'), style: const TextStyle(fontFamily: 'Siemreap', fontSize: 12))),
              StreamBuilder<QuerySnapshot>(
                stream: _currentUserId != null && _currentUserId!.isNotEmpty
                    ? FirebaseFirestore.instance
                        .collection('users')
                        .doc(_currentUserId)
                        .collection('notifications')
                        .where('type', whereIn: ['new_comment', 'comment_reply'])
                        .where('isRead', isEqualTo: false)
                        .snapshots()
                    : const Stream.empty(),
                builder: (context, snapshot) {
                  final count = snapshot.hasData ? snapshot.data!.docs.length : 0;
                  return Tab(
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Text(_t('មតិយោបល់', 'Comments'), style: const TextStyle(fontFamily: 'Siemreap', fontSize: 12)),
                        if (count > 0)
                          Positioned(
                            right: -18,
                            top: -4,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                              child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
              Tab(child: Text(_t('ពិន្ទុ', 'Ratings'), style: const TextStyle(fontFamily: 'Siemreap', fontSize: 12))),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAnnouncementsTab(),
          _buildPersonalTab(type: 'comment'),
          _buildPersonalTab(type: 'rating'),
        ],
      ),
    );
  }

  Widget _buildAnnouncementsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('announcements').orderBy('created_at', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF3B5BFF)));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _emptyState(Icons.notifications_none_rounded, _t('មិនទាន់មានដំណឹងថ្មីឡើយ', 'No new notifications yet'));
        }
        final docs = snapshot.data!.docs;
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            return _NotiCard(data: data, isNew: index == 0, isPersonal: false);
          },
        );
      },
    );
  }

  Widget _buildPersonalTab({required String type}) {
    if (_currentUserId == null || _currentUserId!.isEmpty) {
      return Center(child: Text(_t('កំពុងផ្ទុក...', 'Loading...')));
    }
    final filterType = type == 'rating' ? 'new_rating' : 'new_comment';
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
          return const Center(child: CircularProgressIndicator(color: Color(0xFF3B5BFF)));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return type == 'comment'
              ? _emptyState(Icons.comment_bank_outlined, _t('មិនមានការជូនដំណឹងពីមតិ', 'No comment notifications'))
              : _emptyState(Icons.star_border_rounded, _t('មិនមានការជូនដំណឹងពីពិន្ទុ', 'No rating notifications'));
        }
        final docs = snapshot.data!.docs;
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            return _NotiCard(data: data, isPersonal: true, onTap: () => _handlePersonalNotificationTap(data));
          },
        );
      },
    );
  }

  Widget _emptyState(IconData icon, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 20),
          Text(message, style: TextStyle(fontFamily: 'Siemreap', color: Colors.grey.shade500, fontSize: 16)),
        ],
      ),
    );
  }

  Future<void> _handlePersonalNotificationTap(Map<String, dynamic> data) async {
    final String? productId = data['productId'] ?? data['product_id'];
    if (productId == null || productId.isEmpty) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('products').doc(productId).get();
      if (!doc.exists || !mounted) return;
      final product = doc.data()!;
      product['id'] = productId;
      Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailScreen(product: product)));
    } catch (e) {
      debugPrint('Error fetching product: $e');
    }
  }
}

class _NotiCard extends StatefulWidget {
  final Map<String, dynamic> data;
  final bool isNew;
  final bool isPersonal;
  final VoidCallback? onTap;

  const _NotiCard({required this.data, this.isNew = false, this.isPersonal = false, this.onTap});

  @override
  State<_NotiCard> createState() => _NotiCardState();
}

class _NotiCardState extends State<_NotiCard> {
  bool _isExpanded = false;
  static const int _maxChars = 150;

  String _t(String km, String en) =>
      Localizations.localeOf(context).languageCode == 'en' ? en : km;

  _NotiStyle _getStyle(String? type, bool personal) {
    if (personal) {
      if (type == 'comment_reply') return const _NotiStyle(color: Color(0xFF8B5CF6), bg: Color(0xFFF3EEFF), icon: Icons.reply_rounded);
      if (type == 'new_comment') return const _NotiStyle(color: Color(0xFF3B5BFF), bg: Color(0xFFEEF2FF), icon: Icons.chat_bubble_rounded);
      if (type == 'new_rating') return const _NotiStyle(color: Color(0xFFFFB300), bg: Color(0xFFFFF8E1), icon: Icons.star_rounded);
    }
    switch (type) {
      case 'warning':
        return const _NotiStyle(color: Color(0xFFFF6B35), bg: Color(0xFFFFF3EE), icon: Icons.warning_amber_rounded);
      case 'success':
        return const _NotiStyle(color: Color(0xFF2DCB73), bg: Color(0xFFEEFBF4), icon: Icons.check_circle_rounded);
      case 'info':
        return const _NotiStyle(color: Color(0xFF3B5BFF), bg: Color(0xFFEEF2FF), icon: Icons.info_rounded);
      default:
        return const _NotiStyle(color: Color(0xFF3B5BFF), bg: Color(0xFFEEF2FF), icon: Icons.campaign_rounded);
    }
  }

  String _formatDate(dynamic ts) {
    if (ts == null) return '';
    try {
      return DateFormat('dd MMM yyyy • HH:mm').format((ts as Timestamp).toDate());
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final personal = widget.isPersonal;
    final title = (widget.data['title'] ?? '').toString();
    final body = (personal ? widget.data['body'] : widget.data['message'] ?? widget.data['body'] ?? '').toString();
    final type = widget.data['type'] as String?;
    final style = _getStyle(type, personal);
    final date = _formatDate(personal ? widget.data['createdAt'] : widget.data['created_at']);
    final isLong = body.length > _maxChars;

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: style.color.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4))],
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
                          decoration: BoxDecoration(color: style.bg, borderRadius: BorderRadius.circular(12)),
                          child: Icon(style.icon, color: style.color, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87, fontFamily: 'Siemreap', height: 1.4))),
                                  if (widget.isNew && !personal)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(20)),
                                      child: Text(_t('ថ្មី', 'NEW'), style: const TextStyle(color: Colors.white, fontSize: 10, fontFamily: 'Siemreap', fontWeight: FontWeight.bold)),
                                    ),
                                ],
                              ),
                              if (date.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Row(children: [Icon(Icons.access_time_rounded, size: 12, color: Colors.grey.shade400), const SizedBox(width: 4), Text(date, style: TextStyle(fontSize: 11, color: Colors.grey.shade400))]),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1, color: Colors.grey.shade100)),
                    AnimatedCrossFade(
                      firstChild: Text(body, maxLines: 4, overflow: TextOverflow.ellipsis, style: TextStyle(height: 1.6, color: Colors.grey.shade700, fontSize: 13.5, fontFamily: 'Siemreap')),
                      secondChild: Text(body, style: TextStyle(height: 1.6, color: Colors.grey.shade700, fontSize: 13.5, fontFamily: 'Siemreap')),
                      crossFadeState: _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                      duration: const Duration(milliseconds: 200),
                    ),
                    if (isLong)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => setState(() => _isExpanded = !_isExpanded),
                          iconAlignment: IconAlignment.end,
                          icon: Icon(_isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, color: style.color, size: 18),
                          label: Text(_isExpanded ? _t('បិទវិញ', 'Show less') : _t('មើលបន្ថែម', 'Show more'), style: TextStyle(color: style.color, fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'Siemreap')),
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

class _NotiStyle {
  final Color color;
  final Color bg;
  final IconData icon;
  const _NotiStyle({required this.color, required this.bg, required this.icon});
}
