import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:my_app/user_profile_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'chat_screen.dart';

class AuctionDetailScreen extends StatefulWidget {
  final String productId;
  const AuctionDetailScreen({super.key, required this.productId});

  @override
  State<AuctionDetailScreen> createState() => _AuctionDetailScreenState();
}

class _AuctionDetailScreenState extends State<AuctionDetailScreen>
    with TickerProviderStateMixin {
  static const _adminId = 'WBdQVvrgEIPBTcgIlumu6bAZGUl2';
  static const _bg = Color(0xFFF7FAF7);
  static const _card = Colors.white;
  static const _border = Color(0xFFDDE8DF);
  static const _accent = Color(0xFF2E7D32);
  static const _accentBlue = Color(0xFFF57C00);
  static const _text = Color(0xFF1F2933);
  static const _textMuted = Color(0xFF6B7280);
  static const _red = Color(0xFFD32F2F);
  static const _gold = Color(0xFFF57C00);

  String _t(String km, String en) =>
      Localizations.localeOf(context).languageCode == 'en' ? en : km;

  bool _isBidding = false;
  int _currentImageIndex = 0;
  late Timer _timer;
  late AnimationController _bidPulseCtrl;
  late Animation<double> _bidPulseAnim;
  late PageController _pageCtrl;

  String? _currentUid;
  String? _currentUserName;
  String? _currentUserPhone;
  String? _currentUserPhoto;
  String? _currentUserRole;
  String _ownerName = '';
  String _ownerPhotoUrl = '';
  String _sesanId = '';

  String _maskPhoneNumber(String phone) {
    if (phone.length <= 5) return phone;
    final firstThree = phone.substring(0, 3);
    final lastTwo = phone.substring(phone.length - 2);
    final maskedLength = phone.length - 5;
    final masked = '*' * maskedLength;
    return '$firstThree$masked$lastTwo';
  }

  bool _isLoggedIn = false;
  bool _userLoaded = false;
  VideoPlayerController? _videoController;
  bool _isVideoPlaying = false;
  int _viewerCount = 0;

  @override
  void initState() {
    super.initState();
    _loadUser();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    _bidPulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _bidPulseAnim = Tween<double>(
      begin: 1.0,
      end: 1.06,
    ).animate(CurvedAnimation(parent: _bidPulseCtrl, curve: Curves.easeInOut));
    _pageCtrl = PageController(keepPage: true);
  }

  @override
  void dispose() {
    _timer.cancel();
    _bidPulseCtrl.dispose();
    _pageCtrl.dispose();
    _removeViewer();
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _addViewer() async {
    if (_currentUid == null) return;
    await FirebaseFirestore.instance
        .collection('auction_products')
        .doc(widget.productId)
        .collection('viewers')
        .doc(_currentUid)
        .set({'viewed_at': FieldValue.serverTimestamp()});
  }

  Future<void> _removeViewer() async {
    if (_currentUid == null) return;
    await FirebaseFirestore.instance
        .collection('auction_products')
        .doc(widget.productId)
        .collection('viewers')
        .doc(_currentUid)
        .delete();
  }

  void _listenViewerCount() {
    FirebaseFirestore.instance
        .collection('auction_products')
        .doc(widget.productId)
        .collection('viewers')
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() => _viewerCount = snapshot.docs.length);
      }
    });
  }

  Future<void> _loadUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = prefs.getString('user_uid');
      final loggedIn = prefs.getBool('is_logged_in') ?? false;
      print('DEBUG: Loading user from SharedPreferences');
      print('DEBUG: user_uid = $uid');
      print('DEBUG: is_logged_in = $loggedIn');
      if (mounted) {
        setState(() {
          _currentUid = uid;
          _currentUserName = prefs.getString('user_name');
          _currentUserPhone = prefs.getString('user_phone');
          _currentUserPhoto = prefs.getString('user_photo');
          _currentUserRole = prefs.getString('user_role');
          _isLoggedIn = loggedIn && uid != null && uid.isNotEmpty;
          _userLoaded = true;
        });
      }
      if (uid != null && uid.isNotEmpty) {
        _addViewer();
        _listenViewerCount();
      }
    } catch (e) {
      print('DEBUG: Error loading user: $e');
      if (mounted) {
        setState(() {
          _userLoaded = true;
        });
      }
    }
  }

  Future<void> _loadOwnerInfo(String ownerId) async {
    if (ownerId.isEmpty) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(ownerId).get();
      if (doc.exists && mounted) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          _ownerName = data['name'] ?? data['displayName'] ?? _t('គ្មានឈ្មោះ', 'Unnamed');
          _ownerPhotoUrl = data['photoUrl'] ?? data['photo'] ?? '';
          _sesanId = data['sesan_id'] ?? '';
        });
      }
    } catch (e) {
      print('Error loading owner: $e');
    }
  }

  void _showDeleteDialog(BuildContext context, String productName) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _red.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.delete_outline_rounded, color: _red, size: 30),
              ),
              const SizedBox(height: 16),
              Text(
                _t('លុបការដេញថ្លៃ?', 'Delete auction?'),
                style: TextStyle(
                  color: _text,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Siemreap',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                productName,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _textMuted, fontSize: 13, fontFamily: 'Siemreap'),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _textMuted,
                        side: const BorderSide(color: _border),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(_t('បោះបង់', 'Cancel'), style: TextStyle(fontFamily: 'Siemreap')),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _red,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () async {
                        await FirebaseFirestore.instance
                            .collection('auction_products')
                            .doc(widget.productId)
                            .delete();
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) Navigator.pop(context);
                      },
                      child: Text(
                        _t('លុប', 'Delete'),
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontFamily: 'Siemreap'),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openAuctionChat({
    required String productName,
    required String ownerId,
    required String winnerId,
    required String winnerName,
  }) async {
    if (_currentUid == null || !_isLoggedIn) {
      _showSnack(_t('❌ សូម Login មុនសិន', '❌ Please log in first'), _red);
      return;
    }
    await FirebaseFirestore.instance
        .collection('auction_chats')
        .doc('auction_${widget.productId}')
        .set({
      'productId': widget.productId,
      'productName': productName,
      'ownerId': ownerId,
      'winnerId': winnerId,
      'winnerName': winnerName,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          productId: widget.productId,
          productName: productName,
          seller_id: ownerId,
          receiver_id: winnerId,
        ),
      ),
    );
  }

  Future<void> _placeBid(int currentPrice, int bidStep, String productName) async {
    print('DEBUG: _placeBid called');
    print('DEBUG: _currentUid = $_currentUid');
    print('DEBUG: _isLoggedIn = $_isLoggedIn');
    print('DEBUG: _userLoaded = $_userLoaded');
    await _loadUser();
    if (_currentUid == null || !_isLoggedIn) {
      _showSnack(_t('❌ សូម Login មុនសិន', '❌ Please log in first'), _red);
      return;
    }
    final confirmed = await _showConfirmDialog(currentPrice + bidStep, productName);
    if (!confirmed) return;
    setState(() => _isBidding = true);
    final newBid = currentPrice + bidStep;
    try {
      final unknownName = _t('មិនស្គាល់', 'Unknown');
      String bidderName = _currentUserName ?? unknownName;
      if (bidderName == unknownName || bidderName.isEmpty) {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(_currentUid).get();
        if (userDoc.exists) {
          final u = userDoc.data() as Map<String, dynamic>;
          bidderName = u['name'] ?? u['displayName'] ?? unknownName;
        }
      }
      final batch = FirebaseFirestore.instance.batch();
      final prodRef = FirebaseFirestore.instance.collection('auction_products').doc(widget.productId);
      batch.update(prodRef, {
        'current_price': newBid,
        'last_bidder': bidderName,
        'last_bidder_id': _currentUid,
        'updated_at': FieldValue.serverTimestamp(),
      });
      batch.set(prodRef.collection('bids').doc(), {
        'bidder_name': bidderName,
        'bidder_id': _currentUid,
        'bid_amount': newBid,
        'bid_time': FieldValue.serverTimestamp(),
      });
      await batch.commit();
      _bidPulseCtrl.forward().then((_) => _bidPulseCtrl.reverse());
      _showSnack('${_t('🎉 ដេញថ្លៃជោគជ័យ!', '🎉 Bid placed successfully!')} ${NumberFormat('#,###').format(newBid)} ៛', _accent);
    } catch (e) {
      _showSnack(_t('❌ កំហុស៖ $e', '❌ Error: $e'), _red);
    } finally {
      if (mounted) setState(() => _isBidding = false);
    }
  }

  Future<bool> _showConfirmDialog(int amount, String name) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => Dialog(
            backgroundColor: _card,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: _accent.withOpacity(0.12), shape: BoxShape.circle),
                    child: const Icon(Icons.gavel_rounded, color: _accent, size: 32),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _t('បញ្ជាក់ការដេញថ្លៃ', 'Confirm bid'),
                    style: TextStyle(color: _text, fontSize: 18, fontWeight: FontWeight.w700, fontFamily: 'Siemreap'),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${NumberFormat('#,###').format(amount)} ៛',
                    style: const TextStyle(color: _gold, fontSize: 24, fontWeight: FontWeight.w800),
                  ),
                  Text(name, style: const TextStyle(color: _textMuted, fontSize: 13, fontFamily: 'Siemreap')),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _textMuted,
                            side: const BorderSide(color: _border),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: () => Navigator.pop(ctx, false),
                          child: Text(_t('បោះបង់', 'Cancel'), style: TextStyle(fontFamily: 'Siemreap')),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _accent,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: () => Navigator.pop(ctx, true),
                          child: Text(
                            _t('យល់ព្រម', 'Confirm'),
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontFamily: 'Siemreap'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ) ??
        false;
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Widget _buildTimer(dynamic endTime) {
    if (endTime == null) return const SizedBox();
    final end = (endTime as Timestamp).toDate();
    final remaining = end.difference(DateTime.now());
    final finished = remaining.isNegative;
    if (finished) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: _red.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _red.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.timer_off_outlined, color: _red, size: 14),
            SizedBox(width: 5),
            Text(
              _t('ចប់ហើយ', 'Ended'),
              style: TextStyle(color: _red, fontWeight: FontWeight.w700, fontSize: 12, fontFamily: 'Siemreap'),
            ),
          ],
        ),
      );
    }
    final h = remaining.inHours;
    final m = remaining.inMinutes % 60;
    final s = remaining.inSeconds % 60;
    final urgent = remaining.inMinutes < 30;
    final color = urgent ? _red : _accentBlue;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, color: color, size: 14),
          const SizedBox(width: 5),
          Text(
            '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 13,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('auction_products').doc(widget.productId).snapshots(),
      builder: (context, snap) {
        if (!snap.hasData || !snap.data!.exists) {
          return const Scaffold(
            backgroundColor: _bg,
            body: Center(child: CircularProgressIndicator(color: _accentBlue)),
          );
        }
        final data = snap.data!.data() as Map<String, dynamic>;
        final productName = data['product_name'] ?? _t('គ្មានឈ្មោះ', 'Unnamed product');
        final currentPrice = int.tryParse(data['current_price']?.toString() ?? '0') ?? 0;
        final bidStep = int.tryParse(data['bid_step']?.toString() ?? '0') ?? 0;
        final endTime = data['end_time'];
        final isFinished =
            endTime != null && (endTime as Timestamp).toDate().isBefore(DateTime.now());
        final lastBidder = data['last_bidder'] as String?;
        final lastBidderId = data['last_bidder_id'] as String?;
        final ownerId = data['owner_id'] as String? ?? '';
        final fmt = NumberFormat('#,###');
        final isOwner = _currentUid == ownerId;
        final isAdmin = _currentUid == _adminId;
        final isWinner = _currentUid == lastBidderId;
        final canDelete = isOwner || isAdmin;
        final canChat =
            isFinished && (isOwner || isWinner) && lastBidderId != null && lastBidderId.isNotEmpty;
        if (ownerId.isNotEmpty && _ownerName.isEmpty) {
          _loadOwnerInfo(ownerId);
        }
        return Scaffold(
          backgroundColor: _bg,
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            systemOverlayStyle: SystemUiOverlayStyle.dark,
            leading: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
              ),
            ),
          ),
          body: Column(
            children: [
              SizedBox(
                height: 360,
                child: Stack(
                  children: [
                    Builder(
                      builder: (context) {
                        final videoUrl = data['video_url']?.toString() ?? '';
                        final images = (data['image_urls'] as List?) ?? [];
                        List<Map<String, dynamic>> mediaItems = [];
                        if (videoUrl.isNotEmpty) mediaItems.add({'type': 'video', 'url': videoUrl});
                        for (var img in images) {
                          mediaItems.add({'type': 'image', 'url': img.toString()});
                        }
                        if (mediaItems.isEmpty) return Container(color: _card);
                        return PageView.builder(
                          controller: _pageCtrl,
                          itemCount: mediaItems.length,
                          onPageChanged: (i) => setState(() => _currentImageIndex = i),
                          itemBuilder: (_, i) {
                            final item = mediaItems[i];
                            if (item['type'] == 'video') {
                              return _AuctionVideoPlayer(
                                videoUrl: item['url'] as String,
                                onPlayingChanged: (playing) {
                                  setState(() => _isVideoPlaying = playing);
                                },
                              );
                            }
                            return CachedNetworkImage(imageUrl: item['url'] as String, fit: BoxFit.cover);
                          },
                        );
                      },
                    ),
                    _buildOwnerBadge(),
                    if (!isFinished)
                      Positioned(
                        top: 60,
                        right: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(color: _red, borderRadius: BorderRadius.circular(20)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.circle, size: 7, color: Colors.white),
                              const SizedBox(width: 4),
                              Text(_t('កំពុងដេញថ្លៃ', 'LIVE'), style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                            ],
                          ),
                        ),
                      ),
                    if (_viewerCount > 0)
                      Positioned(
                        top: 60,
                        left: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.visibility, color: Colors.white, size: 14),
                              const SizedBox(width: 4),
                              Text('$_viewerCount ${_t('នាក់', 'viewers')}', style: const TextStyle(color: Colors.white, fontSize: 11)),
                            ],
                          ),
                        ),
                      ),
                    Builder(
                      builder: (context) {
                        final images = (data['image_urls'] as List?) ?? [];
                        final videoUrl = data['video_url']?.toString() ?? '';
                        final totalItems = (videoUrl.isNotEmpty ? 1 : 0) + images.length;
                        if (totalItems <= 1) return const SizedBox();
                        return Positioned(
                          bottom: 16,
                          left: 0,
                          right: 0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(totalItems, (i) {
                              final isVideo = videoUrl.isNotEmpty && i == 0;
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: const EdgeInsets.symmetric(horizontal: 3),
                                width: _currentImageIndex == i ? 24 : 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: _currentImageIndex == i
                                      ? (isVideo ? Colors.red : _accentBlue)
                                      : Colors.white38,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              );
                            }),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              productName,
                              style: const TextStyle(
                                color: _text,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'Siemreap',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildTimer(endTime),
                          if (canDelete) ...[
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => _showDeleteDialog(context, productName),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: _red.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: _red.withOpacity(0.3)),
                                ),
                                child: const Icon(Icons.delete_outline_rounded, color: _red, size: 20),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),
                      ScaleTransition(
                        scale: _bidPulseAnim,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [_accent.withOpacity(0.15), _accentBlue.withOpacity(0.08)]),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: _accent.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(_t('តម្លៃបច្ចុប្បន្ន', 'Current price'), style: TextStyle(color: _textMuted, fontSize: 12, fontFamily: 'Siemreap')),
                                    const SizedBox(height: 4),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        '${fmt.format(currentPrice)} ៛',
                                        style: const TextStyle(color: _accent, fontSize: 22, fontWeight: FontWeight.w800),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(_t('ដេញបន្ទាប់', 'Next bid'), style: TextStyle(color: _textMuted, fontSize: 12, fontFamily: 'Siemreap')),
                                  const SizedBox(height: 4),
                                  Text('+${fmt.format(bidStep)} ៛', style: const TextStyle(color: _gold, fontSize: 16, fontWeight: FontWeight.w700)),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      '= ${fmt.format(currentPrice + bidStep)} ៛',
                                      style: const TextStyle(color: _text, fontSize: 12, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      if ((data['description'] ?? '').toString().isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _ExpandableDescription(text: data['description'].toString()),
                      ],
                      if (lastBidder != null && lastBidderId != null) ...[
                        const SizedBox(height: 12),
                        FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance.collection('users').doc(lastBidderId).get(),
                          builder: (ctx, winnerSnap) {
                            String? photoUrl;
                            if (winnerSnap.hasData && winnerSnap.data!.exists) {
                              final u = winnerSnap.data!.data() as Map<String, dynamic>;
                              photoUrl = u['photoUrl'] ?? u['photo'] ?? u['avatar'];
                            }
                            return GestureDetector(
                              onTap: isOwner
                                  ? () => _openAuctionChat(
                                        productName: productName,
                                        ownerId: ownerId,
                                        winnerId: lastBidderId,
                                        winnerName: lastBidder,
                                      )
                                  : null,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: _card,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: isOwner ? _gold.withOpacity(0.4) : _gold.withOpacity(0.2)),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(color: _gold, width: 2),
                                        color: _border,
                                      ),
                                      child: ClipOval(
                                        child: photoUrl != null
                                            ? CachedNetworkImage(
                                                imageUrl: photoUrl,
                                                fit: BoxFit.cover,
                                                placeholder: (_, __) => const Icon(Icons.person_rounded, color: _textMuted, size: 22),
                                                errorWidget: (_, __, ___) => const Icon(Icons.person_rounded, color: _textMuted, size: 22),
                                              )
                                            : const Icon(Icons.person_rounded, color: _textMuted, size: 22),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              const Icon(Icons.emoji_events_rounded, color: _gold, size: 13),
                                              const SizedBox(width: 4),
                                              Text(_t('អ្នកឈ្នះបច្ចុប្បន្ន', 'Current winner'), style: const TextStyle(color: _textMuted, fontSize: 11, fontFamily: 'Siemreap')),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(lastBidder, style: const TextStyle(color: _gold, fontSize: 14, fontWeight: FontWeight.w700)),
                                        ],
                                      ),
                                    ),
                                    if (isOwner)
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: _accentBlue.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: _accentBlue.withOpacity(0.3)),
                                        ),
                                        child: const Icon(Icons.chat_bubble_outline_rounded, color: _accentBlue, size: 18),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                      const SizedBox(height: 16),
                      if (isFinished &&
                          lastBidderId != null &&
                          (isOwner || isWinner)) ...[
                        FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance
                              .collection('users')
                              .doc(isOwner ? lastBidderId : ownerId)
                              .get(),
                          builder: (ctx, userSnap) {
                            String? phone;
                            if (userSnap.hasData && userSnap.data!.exists) {
                              final u = userSnap.data!.data() as Map<String, dynamic>;
                              phone = u['phone'] ?? u['phoneNumber'];
                            }
                            phone ??= data['customer_phone'] as String?;
                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: [_gold.withOpacity(0.12), _accent.withOpacity(0.08)]),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: _gold.withOpacity(0.3)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(color: _gold.withOpacity(0.15), shape: BoxShape.circle),
                                        child: const Icon(Icons.emoji_events_rounded, color: _gold, size: 22),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _t('ការដេញថ្លៃបានចប់!', 'Auction ended!'),
                                              style: TextStyle(color: _gold, fontSize: 15, fontWeight: FontWeight.w700, fontFamily: 'Siemreap'),
                                            ),
                                            Text(
                                              isOwner ? '${_t('អ្នកឈ្នះ', 'Winner')}: ${lastBidder ?? ''}' : _t('អ្នកឈ្នះហើយ!', 'You won!'),
                                              style: const TextStyle(color: _textMuted, fontSize: 12, fontFamily: 'Siemreap'),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (phone != null && phone.isNotEmpty) ...[
                                    const SizedBox(height: 14),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: _bg,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: _border),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.phone_outlined, color: _accent, size: 18),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  isOwner ? _t('លេខអ្នកឈ្នះ', 'Winner phone') : _t('លេខម្ចាស់ទំនិញ', 'Seller phone'),
                                                  style: const TextStyle(color: _textMuted, fontSize: 11, fontFamily: 'Siemreap'),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  (isOwner || isWinner) ? phone : _maskPhoneNumber(phone),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  softWrap: false,
                                                  style: TextStyle(
                                                    color: _text,
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                    letterSpacing: (isOwner || isWinner) ? 0.2 : 1,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (isOwner || isWinner) ...[
                                            GestureDetector(
                                              onTap: () async {
                                                final uri = Uri.parse('tel:$phone');
                                                if (await canLaunchUrl(uri)) await launchUrl(uri);
                                              },
                                              child: Container(
                                                padding: const EdgeInsets.all(10),
                                                decoration: BoxDecoration(color: _accent, borderRadius: BorderRadius.circular(10)),
                                                child: const Icon(Icons.call_rounded, color: Colors.white, size: 20),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            GestureDetector(
                                              onTap: () async {
                                                final cleaned = phone!.replaceAll('+', '').replaceAll(' ', '');
                                                final uri = Uri.parse('https://t.me/+$cleaned');
                                                if (await canLaunchUrl(uri)) {
                                                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                                                }
                                              },
                                              child: Container(
                                                padding: const EdgeInsets.all(10),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF0088CC),
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                                child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                  if (canChat) ...[
                                    const SizedBox(height: 10),
                                    SizedBox(
                                      width: double.infinity,
                                      height: 48,
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: _accentBlue,
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        ),
                                        onPressed: () => _openAuctionChat(
                                          productName: productName,
                                          ownerId: ownerId,
                                          winnerId: lastBidderId,
                                          winnerName: lastBidder ?? _t('មិនស្គាល់', 'Unknown'),
                                        ),
                                        icon: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white, size: 18),
                                        label: Text(
                                          isOwner ? _t('Chat ជាមួយអ្នកឈ្នះ', 'Chat with winner') : _t('Chat ជាមួយម្ចាស់ទំនិញ', 'Chat with seller'),
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontFamily: 'Siemreap'),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                      ],
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isFinished ? _border : _accentBlue,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: (isFinished || _isBidding)
                              ? null
                              : () => _placeBid(currentPrice, bidStep, productName),
                          child: _isBidding
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      isFinished ? Icons.lock_outline_rounded : Icons.gavel_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      isFinished
                                          ? _t('ការដេញថ្លៃបានបញ្ចប់', 'Auction ended')
                                          : '${_t('ដេញថ្លៃ', 'Bid')} ${fmt.format(currentPrice + bidStep)} ៛',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        fontFamily: 'Siemreap',
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          const Icon(Icons.history_rounded, color: _textMuted, size: 18),
                          SizedBox(width: 8),
                          Text(
                            _t('ប្រវត្តិដេញថ្លៃ', 'Bid history'),
                            style: TextStyle(color: _text, fontSize: 16, fontWeight: FontWeight.w700, fontFamily: 'Siemreap'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('auction_products')
                            .doc(widget.productId)
                            .collection('bids')
                            .orderBy('bid_time', descending: true)
                            .snapshots(),
                        builder: (ctx, bidSnap) {
                          if (!bidSnap.hasData) {
                            return const Center(child: CircularProgressIndicator(color: _accentBlue));
                          }
                          final bids = bidSnap.data!.docs;
                          if (bids.isEmpty) {
                            return Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: _card,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: _border),
                              ),
                              child: Center(
                                child: Column(
                                  children: [
                                    const Icon(Icons.gavel_rounded, color: _textMuted, size: 32),
                                    const SizedBox(height: 8),
                                    Text(_t('មិនទាន់មានអ្នកដេញ', 'No bids yet'), style: TextStyle(color: _textMuted, fontFamily: 'Siemreap')),
                                  ],
                                ),
                              ),
                            );
                          }
                          return Column(
                            children: List.generate(bids.length, (i) {
                              final bid = bids[i].data() as Map<String, dynamic>;
                              final isTop = i == 0;
                              final bidTime = bid['bid_time'] != null
                                  ? (bid['bid_time'] as Timestamp).toDate()
                                  : null;
                              final String? bidderId = bid['bidder_id'] as String?;
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: isTop ? _gold.withOpacity(0.07) : _card,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: isTop ? _gold.withOpacity(0.3) : _border),
                                ),
                                child: Row(
                                  children: [
                                    _buildBidderAvatar(bidderId: bidderId, isTop: isTop, rank: i + 1),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            bid['bidder_name'] ?? _t('មិនស្គាល់', 'Unknown'),
                                            style: TextStyle(color: isTop ? _gold : _text, fontWeight: FontWeight.w600, fontSize: 14),
                                          ),
                                          if (bidTime != null)
                                            Text(
                                              DateFormat('dd/MM · HH:mm:ss').format(bidTime),
                                              style: const TextStyle(color: _textMuted, fontSize: 11),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      '${fmt.format(bid['bid_amount'] ?? 0)} ៛',
                                      style: TextStyle(color: isTop ? _gold : _accent, fontSize: 15, fontWeight: FontWeight.w800),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOwnerBadge() {
    final displayName = _ownerName.isNotEmpty ? _ownerName : _t('រកឈ្មោះ...', 'Loading name...');
    final displaySesanId = _sesanId.isNotEmpty ? _sesanId : '...';
    return Positioned(
      bottom: 40,
      left: 16,
      child: GestureDetector(
        onTap: () {},
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _gold, width: 1),
                  color: _border,
                ),
                child: ClipOval(
                  child: _ownerPhotoUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: _ownerPhotoUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => const Icon(Icons.person_rounded, color: _textMuted, size: 12),
                          errorWidget: (_, __, ___) => const Icon(Icons.person_rounded, color: _textMuted, size: 12),
                        )
                      : const Icon(Icons.person_rounded, color: _textMuted, size: 12),
                ),
              ),
              const SizedBox(width: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    displayName,
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600, height: 1.1),
                  ),
                  Text(
                    'ID: $displaySesanId',
                    style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 9, height: 1.1),
                  ),
                ],
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 0.5),
                decoration: BoxDecoration(color: _gold.withOpacity(0.2), borderRadius: BorderRadius.circular(3)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBidderAvatar({
    required String? bidderId,
    required bool isTop,
    required int rank,
  }) {
    if (bidderId == null || bidderId.isEmpty) {
      return Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: isTop ? _gold.withOpacity(0.15) : _border,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: isTop
              ? const Icon(Icons.emoji_events_rounded, color: _gold, size: 18)
              : Text(
                  '$rank',
                  style: const TextStyle(color: _textMuted, fontWeight: FontWeight.w700, fontSize: 13),
                ),
        ),
      );
    }
    return _ClickableBidderAvatar(bidderId: bidderId, isTop: isTop, rank: rank);
  }

  Widget _buildRankIcon(bool isTop, int rank) {
    return Center(
      child: isTop
          ? const Icon(Icons.emoji_events_rounded, color: _gold, size: 18)
          : Text(
              '$rank',
              style: const TextStyle(color: _textMuted, fontWeight: FontWeight.w700, fontSize: 13),
            ),
    );
  }
}

class _ExpandableDescription extends StatefulWidget {
  final String text;
  const _ExpandableDescription({required this.text});

  @override
  State<_ExpandableDescription> createState() => _ExpandableDescriptionState();
}

class _ExpandableDescriptionState extends State<_ExpandableDescription> {
  bool _expanded = false;
  static const _card = Color(0xFF161B22);
  static const _border = Color(0xFF30363D);
  static const _text = Color(0xFFE6EDF3);
  static const _textMuted = Color(0xFF8B949E);
  static const _accentBlue = Color(0xFF1F6FEB);

  @override
  Widget build(BuildContext context) {
    final isEnglish = Localizations.localeOf(context).languageCode == 'en';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.description_outlined, color: _accentBlue, size: 16),
              const SizedBox(width: 10),
              Text(
                isEnglish ? 'Description' : 'ការរៀបរាប់',
                style: const TextStyle(color: _text, fontSize: 14, fontWeight: FontWeight.w700, fontFamily: 'Siemreap'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AnimatedCrossFade(
            firstChild: Text(
              widget.text,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _textMuted, fontSize: 13, height: 1.7, fontFamily: 'Siemreap'),
            ),
            secondChild: Text(
              widget.text,
              style: const TextStyle(color: _textMuted, fontSize: 13, height: 1.7, fontFamily: 'Siemreap'),
            ),
            crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _expanded
                      ? (isEnglish ? 'Show less' : 'លាក់វិញ')
                      : (isEnglish ? 'Read more' : 'អានបន្ថែម'),
                  style: const TextStyle(color: _accentBlue, fontSize: 12, fontWeight: FontWeight.w600, fontFamily: 'Siemreap'),
                ),
                Icon(
                  _expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                  color: _accentBlue,
                  size: 16,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ClickableBidderAvatar extends StatefulWidget {
  final String bidderId;
  final bool isTop;
  final int rank;
  const _ClickableBidderAvatar({required this.bidderId, required this.isTop, required this.rank});

  @override
  State<_ClickableBidderAvatar> createState() => _ClickableBidderAvatarState();
}

class _ClickableBidderAvatarState extends State<_ClickableBidderAvatar> {
  static const _textMuted = Color(0xFF8B949E);
  static const _border = Color(0xFF30363D);
  static const _gold = Color(0xFFFFB300);
  String? _photoUrl;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPhoto();
  }

  Future<void> _loadPhoto() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(widget.bidderId).get();
      if (doc.exists && mounted) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          _photoUrl = data['photoUrl'] ?? data['photo'] ?? data['avatar'];
          _isLoading = false;
        });
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => UserProfileScreen(userId: widget.bidderId)),
          );
        },
        borderRadius: BorderRadius.circular(19),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: widget.isTop ? _gold.withOpacity(0.15) : _border,
            shape: BoxShape.circle,
            border: widget.isTop ? Border.all(color: _gold.withOpacity(0.5), width: 2) : null,
          ),
          child: ClipOval(
            child: _photoUrl != null && _photoUrl!.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: _photoUrl!,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => _buildFallbackIcon(),
                    errorWidget: (_, __, ___) => _buildFallbackIcon(),
                  )
                : _buildFallbackIcon(),
          ),
        ),
      ),
    );
  }

  Widget _buildFallbackIcon() {
    return Center(
      child: widget.isTop
          ? const Icon(Icons.emoji_events_rounded, color: _gold, size: 18)
          : Text(
              '${widget.rank}',
              style: const TextStyle(color: _textMuted, fontWeight: FontWeight.w700, fontSize: 13),
            ),
    );
  }
}

class _AuctionVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final Function(bool)? onPlayingChanged;
  const _AuctionVideoPlayer({required this.videoUrl, this.onPlayingChanged});

  @override
  State<_AuctionVideoPlayer> createState() => _AuctionVideoPlayerState();
}

class _AuctionVideoPlayerState extends State<_AuctionVideoPlayer> {
  VideoPlayerController? _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  void _initVideo() {
    _controller = VideoPlayerController.network(widget.videoUrl)
      ..initialize().then((_) {
        if (mounted) {
          setState(() => _initialized = true);
          _controller!.play();
          _controller!.setLooping(true);
          widget.onPlayingChanged?.call(true);
        }
      });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void play() => _controller?.play();
  void pause() => _controller?.pause();
  bool get isPlaying => _controller?.value.isPlaying ?? false;

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Center(child: CircularProgressIndicator());
    }
    return VideoPlayer(_controller!);
  }
}
