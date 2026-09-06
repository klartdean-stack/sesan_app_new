import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:my_app/user_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'chat_screen.dart';
import 'localized_text.dart';

class UserProfileScreen extends StatefulWidget {
  final String userId;
  final String? currentUserId;

  const UserProfileScreen({
    super.key,
    required this.userId,
    this.currentUserId,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  bool _isPhoneVisible = false;
  bool _isOwner = false;
  bool _isBlockedByMe = false;
  bool _isBlockedByThem = false;
  bool _isUpdatingBlock = false;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _checkOwnership();
  }

  Future<void> _checkOwnership() async {
    final id = await UserService.getUserId();
    if (!mounted) return;
    setState(() {
      _currentUserId = id;
      _isOwner = id == widget.userId;
    });
    await _checkBlockStatus();
  }

  Future<void> _checkBlockStatus() async {
    final currentId = _currentUserId;
    if (currentId == null || currentId.isEmpty || currentId == widget.userId) {
      return;
    }

    try {
      final results = await Future.wait([
        FirebaseFirestore.instance.collection('users').doc(currentId).get(),
        FirebaseFirestore.instance.collection('users').doc(widget.userId).get(),
      ]);
      final myData = results[0].data() ?? <String, dynamic>{};
      final theirData = results[1].data() ?? <String, dynamic>{};
      final myBlockedUsers = (myData['blockedUsers'] as List?) ?? const [];
      final theirBlockedUsers =
          (theirData['blockedUsers'] as List?) ?? const [];

      if (!mounted) return;
      setState(() {
        _isBlockedByMe = myBlockedUsers.contains(widget.userId);
        _isBlockedByThem = theirBlockedUsers.contains(currentId);
      });
    } catch (e) {
      debugPrint('Check profile block status error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUserId == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.amber)),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (!_isOwner)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onSelected: (value) {
                if (value == 'block') {
                  _confirmBlockUser();
                } else if (value == 'unblock') {
                  _unblockUser();
                } else if (value == 'report') {
                  _showReportDialog();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem<String>(
                  value: _isBlockedByMe ? 'unblock' : 'block',
                  child: Row(
                    children: [
                      Icon(
                        _isBlockedByMe ? Icons.lock_open : Icons.block,
                        color: _isBlockedByMe ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _isBlockedByMe
                            ? appText(
                                context,
                                km: 'ដោះ Block',
                                en: 'Unblock user',
                              )
                            : appText(
                                context,
                                km: 'Block អ្នកប្រើនេះ',
                                en: 'Block user',
                              ),
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
            ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _ProfileSkeletonLoader();
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const _ErrorStateWidget();
          }

          Map<String, dynamic> data =
              snapshot.data!.data() as Map<String, dynamic>;

          final bool isPhoneHidden = data['isPhoneHidden'] == true;

          if (!_isOwner && (_isBlockedByMe || _isBlockedByThem)) {
            return _buildBlockedProfile(data);
          }

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                _ProfileHeader(data: data, userId: widget.userId),

                Transform.translate(
                  offset: const Offset(0, -30),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _ActionButton(
                          icon: Icons.chat_bubble_outline,
                          label: appText(context, km: 'ឆាត', en: 'Chat'),
                          color: Colors.blueAccent,
                          onTap: () => _openChat(context, data),
                        ),
                        _ActionButton(
                          icon: isPhoneHidden
                              ? Icons.phone_disabled
                              : Icons.phone,
                          label: isPhoneHidden
                              ? appText(context, km: 'លាក់លេខ', en: 'Private')
                              : appText(context, km: 'ហៅទូរស័ព្ទ', en: 'Call'),
                          color: isPhoneHidden ? Colors.grey : Colors.green,
                          onTap: isPhoneHidden
                              ? () => _showSnackBar(
                                  appText(
                                    context,
                                    km: '⚠️ លេខទូរស័ព្ទនេះស្ថិតក្នុងមុខងារឯកជនភាព',
                                    en: '⚠️ This phone number is private',
                                  ),
                                )
                              : () => _makeCall(data['phone']),
                        ),
                      ],
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionTitle(
                        title: appText(
                          context,
                          km: 'ព័ត៌មានលម្អិត',
                          en: 'Profile details',
                        ),
                      ),
                      const SizedBox(height: 10),
                      _InfoCard(
                        children: [
                          _buildPhoneTile(
                            context,
                            data['phone'],
                            isPhoneHidden,
                          ),
                          const Divider(height: 1, indent: 56),
                          _buildInfoTile(
                            context,
                            icon: Icons.calendar_month,
                            title: appText(
                              context,
                              km: 'ថ្ងៃចូលរួម',
                              en: 'Joined',
                            ),
                            value: data['createdAt'] != null
                                ? DateFormat('dd MMMM yyyy', 'km_KH').format(
                                    (data['createdAt'] as Timestamp).toDate(),
                                  )
                                : appText(
                                    context,
                                    km: 'មិនស្គាល់',
                                    en: 'Unknown',
                                  ),
                            iconColor: Colors.orange,
                          ),
                          const Divider(height: 1, indent: 56),
                          _buildIdTile(context, data['sesan_id'] ?? '---'),
                        ],
                      ),

                      if (_isOwner) ...[
                        const SizedBox(height: 25),
                        _SectionTitle(
                          title: appText(
                            context,
                            km: 'ការកំណត់ឯកជនភាព',
                            en: 'Privacy settings',
                          ),
                        ),
                        const SizedBox(height: 10),
                        _InfoCard(
                          children: [
                            SwitchListTile(
                              secondary: Icon(
                                isPhoneHidden
                                    ? Icons.lock_outline
                                    : Icons.lock_open,
                                color: isPhoneHidden
                                    ? Colors.red
                                    : Colors.green,
                              ),
                              title: Text(
                                appText(
                                  context,
                                  km: 'របៀបឯកជនភាព',
                                  en: 'Privacy mode',
                                ),
                                style: const TextStyle(
                                  fontFamily: 'Siemreap',
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                isPhoneHidden
                                    ? appText(
                                        context,
                                        km: 'អ្នកដទៃមិនអាចឃើញលេខ ឬខលមកបានទេ',
                                        en: 'Others cannot see or call this number',
                                      )
                                    : appText(
                                        context,
                                        km: 'អ្នកដទៃអាចឃើញលេខ និងខលមកបាន',
                                        en: 'Others can see and call this number',
                                      ),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontFamily: 'Siemreap',
                                ),
                              ),
                              value: isPhoneHidden,
                              activeColor: Colors.red,
                              onChanged: (bool value) {
                                _updatePhonePrivacy(value);
                              },
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 30),
                      const _SectionTitle(title: 'សកម្មភាពគណនី'),
                      const SizedBox(height: 10),
                      _ActivitySection(data: data),
                      const _SectionTitle(title: 'ប្រវត្តិដេញថ្លៃ'),
                      const SizedBox(height: 10),
                      _BidHistorySection(userId: widget.userId),

                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBlockedProfile(Map<String, dynamic> data) {
    final bool unavailableBecauseTheyBlocked = _isBlockedByThem;
    final String name =
        (data['name'] ??
                data['shopName'] ??
                appText(context, km: 'អ្នកប្រើ', en: 'User'))
            .toString();
    final String sesanId =
        (data['sesan_id'] ?? data['sesanId'] ?? widget.userId).toString();
    final String photoUrl =
        (data['photoUrl'] ??
                data['profile_image'] ??
                data['profileImage'] ??
                '')
            .toString();

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: const Color(0xFFF8F9FA),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 42,
                  backgroundColor: Colors.grey.shade200,
                  backgroundImage: photoUrl.isNotEmpty
                      ? CachedNetworkImageProvider(photoUrl)
                      : null,
                  child: photoUrl.isEmpty
                      ? Icon(
                          Icons.person,
                          size: 46,
                          color: Colors.grey.shade500,
                        )
                      : null,
                ),
                const SizedBox(height: 12),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Siemreap',
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Sesan ID: $sesanId',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 18),
                Icon(
                  Icons.person_off_outlined,
                  size: 54,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 14),
                Text(
                  appText(
                    context,
                    km: 'មិនអាចមើល Profile នេះបានទេ',
                    en: 'This profile is unavailable',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Siemreap',
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  unavailableBecauseTheyBlocked
                      ? appText(
                          context,
                          km: 'ព័ត៌មាន និង Content របស់អ្នកប្រើនេះត្រូវបានលាក់។',
                          en: 'This user’s information and content are hidden.',
                        )
                      : appText(
                          context,
                          km: 'អ្នកបាន Block អ្នកប្រើនេះ។ ដោះ Block ដើម្បីមើល Profile វិញ។',
                          en: 'You blocked this user. Unblock them to view the profile again.',
                        ),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Siemreap',
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
                if (_isBlockedByMe) ...[
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _isUpdatingBlock ? null : _unblockUser,
                    icon: const Icon(Icons.lock_open),
                    label: Text(
                      appText(
                        context,
                        km: 'ដោះ Block',
                        en: 'Unblock user',
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmBlockUser() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          appText(
            context,
            km: 'Block អ្នកប្រើនេះ?',
            en: 'Block this user?',
          ),
        ),
        content: Text(
          appText(
            context,
            km: 'បន្ទាប់ពី Block ភាគីទាំងពីរមិនអាចមើលព័ត៌មាន ឬ Content របស់គ្នាបានទេ។ អ្នកអាចដោះ Block វិញនៅពេលក្រោយ។',
            en: 'After blocking, both sides will be unable to view each other’s profile information or content. You can unblock later.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(appText(context, km: 'បោះបង់', en: 'Cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              appText(context, km: 'Block', en: 'Block'),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _blockUser();
    }
  }

  Future<void> _blockUser() async {
    final currentId = _currentUserId;
    if (_isUpdatingBlock || currentId == null || currentId.isEmpty) return;

    setState(() => _isUpdatingBlock = true);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentId)
          .set({
            'blockedUsers': FieldValue.arrayUnion([widget.userId]),
          }, SetOptions(merge: true));
      if (!mounted) return;
      setState(() => _isBlockedByMe = true);
      _showSnackBar(
        appText(
          context,
          km: 'បាន Block អ្នកប្រើនេះរួចរាល់',
          en: 'User blocked successfully',
        ),
      );
    } catch (e) {
      if (mounted) {
        _showSnackBar(
          appText(
            context,
            km: 'មិនអាច Block បាន៖ $e',
            en: 'Could not block user: $e',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdatingBlock = false);
    }
  }

  Future<void> _unblockUser() async {
    final currentId = _currentUserId;
    if (_isUpdatingBlock || currentId == null || currentId.isEmpty) return;

    setState(() => _isUpdatingBlock = true);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentId)
          .set({
            'blockedUsers': FieldValue.arrayRemove([widget.userId]),
          }, SetOptions(merge: true));
      if (!mounted) return;
      setState(() => _isBlockedByMe = false);
      await _checkBlockStatus();
      if (mounted) {
        _showSnackBar(
          appText(
            context,
            km: 'បានដោះ Block រួចរាល់',
            en: 'User unblocked successfully',
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(
          appText(
            context,
            km: 'មិនអាចដោះ Block បាន៖ $e',
            en: 'Could not unblock user: $e',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdatingBlock = false);
    }
  }

  Future<void> _showReportDialog() async {
    String selectedReason = 'fake_profile';
    final detailsController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            appText(
              context,
              km: 'រាយការណ៍ Profile',
              en: 'Report profile',
            ),
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
                      km: 'មូលហេតុនៃការរាយការណ៍',
                      en: 'Reason for report',
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'fake_profile',
                      child: Text(
                        appText(
                          context,
                          km: 'Profile ក្លែងក្លាយ',
                          en: 'Fake profile',
                        ),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'scam',
                      child: Text(
                        appText(
                          context,
                          km: 'ឆបោក ឬបោកប្រាស់',
                          en: 'Scam or fraud',
                        ),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'harassment',
                      child: Text(
                        appText(
                          context,
                          km: 'រំខាន ឬប្រើពាក្យមិនសមរម្យ',
                          en: 'Harassment or abusive behavior',
                        ),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'inappropriate_content',
                      child: Text(
                        appText(
                          context,
                          km: 'Content មិនសមរម្យ',
                          en: 'Inappropriate content',
                        ),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'other',
                      child: Text(
                        appText(
                          context,
                          km: 'មូលហេតុផ្សេង',
                          en: 'Other',
                        ),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => selectedReason = value);
                    }
                  },
                ),
                const SizedBox(height: 16),
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
                    hintText: appText(
                      context,
                      km: 'ពន្យល់អំពីបញ្ហាដែលអ្នកបានជួប...',
                      en: 'Describe the problem you experienced...',
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
                await _submitProfileReport(
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

  Future<void> _submitProfileReport(String reason, String details) async {
    final currentId = _currentUserId;
    if (currentId == null || currentId.isEmpty) return;

    try {
      final docs = await Future.wait([
        FirebaseFirestore.instance.collection('users').doc(currentId).get(),
        FirebaseFirestore.instance.collection('users').doc(widget.userId).get(),
      ]);
      final reporterData = docs[0].data() ?? <String, dynamic>{};
      final reportedData = docs[1].data() ?? <String, dynamic>{};

      await FirebaseFirestore.instance.collection('profile_reports').add({
        'reporter_id': currentId,
        'reporter_name': reporterData['name'] ?? 'Unknown',
        'reported_user_id': widget.userId,
        'reported_user_name': reportedData['name'] ?? 'Unknown',
        'reason': reason,
        'details': details,
        'time': FieldValue.serverTimestamp(),
        'status': 'pending',
      });

      if (mounted) {
        _showSnackBar(
          appText(
            context,
            km: 'បានបញ្ជូន Report ទៅកាន់ Admin រួចរាល់',
            en: 'Report submitted to admin',
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(
          appText(
            context,
            km: 'មិនអាចបញ្ជូន Report បាន៖ $e',
            en: 'Could not submit report: $e',
          ),
        );
      }
    }
  }

  Future<void> _makeCall(String? phone) async {
    if (phone == null || phone.isEmpty) {
      _showSnackBar('មិនមានលេខទូរស័ព្ទ');
      return;
    }

    final Uri telUri = Uri(scheme: 'tel', path: phone);
    try {
      await launchUrl(telUri, mode: LaunchMode.externalApplication);
    } catch (e) {
      _showSnackBar('មិនអាចខលបាន: $e');
    }
  }

  Future<void> _updatePhonePrivacy(bool isHidden) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUserId)
          .update({'isPhoneHidden': isHidden});
      _showSnackBar(
        isHidden
            ? '🔐 បានបិទលេខទូរស័ព្ទជាឯកជន'
            : '🔓 បានបើកលេខទូរស័ព្ទជាសាធារណៈ',
      );
    } catch (e) {
      _showSnackBar('កំហុស៖ $e');
    }
  }

  Widget _buildPhoneTile(BuildContext context, String? phone, bool isHidden) {
    final bool hasPhone = phone != null && phone.isNotEmpty;
    final String displayPhone = hasPhone
        ? (_isPhoneVisible ? phone : _maskPhone(phone))
        : 'អត់មានលេខ';

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.purple.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.phone_android, color: Colors.purple, size: 20),
      ),
      title: Text(
        'លេខទូរស័ព្ទ',
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey[600],
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              displayPhone,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (hasPhone && _isOwner) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => setState(() => _isPhoneVisible = !_isPhoneVisible),
              child: Icon(
                _isPhoneVisible ? Icons.visibility_off : Icons.visibility,
                size: 18,
                color: Colors.grey[400],
              ),
            ),
          ],
        ],
      ),
      trailing: IconButton(
        icon: Icon(
          isHidden ? Icons.phone_disabled : Icons.call,
          color: (hasPhone && !isHidden) ? Colors.green : Colors.grey,
          size: 22,
        ),
        onPressed: () {
          if (isHidden) {
            _showSnackBar('⚠️ ម្ចាស់គណនីបានបិទការហៅចូល');
          } else if (hasPhone) {
            _makeCall(phone);
          } else {
            _showSnackBar('មិនមានលេខទូរស័ព្ទ');
          }
        },
      ),
    );
  }

  String _maskPhone(String phone) {
    if (phone.length <= 6) return phone;
    return phone.replaceRange(3, phone.length - 3, ' * * ');
  }

  Widget _buildIdTile(BuildContext context, String sesanId) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.teal.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.perm_identity, color: Colors.teal, size: 20),
      ),
      title: Text(
        'Sesan ID',
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey[600],
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        sesanId,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
          letterSpacing: 2,
        ),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.copy, size: 20, color: Colors.blueAccent),
        onPressed: () {
          Clipboard.setData(ClipboardData(text: sesanId));
          _showSnackBar('✅ ចម្លង ID រួចរាល់!');
        },
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _openChat(BuildContext context, Map<String, dynamic> userData) {
    final String receiverName = userData['name'] ?? 'អ្នកប្រើប្រាស់';
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          productId:
              'direct_chat_${widget.userId}_${widget.currentUserId ?? "unknown"}',
          productName: receiverName,
          seller_id: widget.userId,
          receiver_id: widget.currentUserId ?? '',
        ),
      ),
    );
  }

  Widget _buildInfoTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    required Color iconColor,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey[600],
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        value,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final bool disabled;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: disabled ? 0.4 : 1.0,
      child: Material(
        color: disabled ? Colors.grey[200] : Colors.white,
        elevation: disabled ? 0 : 4,
        shadowColor: Colors.black12,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: disabled ? null : onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: 140,
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              children: [
                Icon(icon, color: disabled ? Colors.grey : color, size: 28),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: disabled ? Colors.grey : Colors.grey[800],
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    fontFamily: 'Siemreap',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final Map<String, dynamic> data;
  final String userId;
  const _ProfileHeader({required this.data, required this.userId});

  @override
  Widget build(BuildContext context) {
    final String name = data['name'] ?? 'គ្មានឈ្មោះ';
    final String photoUrl = data['photoUrl'] ?? '';
    final String sesanId = data['sesan_id'] ?? '---';

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4facfe), Color(0xFF00f2fe)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(40),
          bottomRight: Radius.circular(40),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 60),
          child: Column(
            children: [
              Hero(
                tag: 'profile_image_$userId',
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.5),
                      width: 4,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.white,
                    child: CircleAvatar(
                      radius: 56,
                      backgroundColor: Colors.grey[200],
                      backgroundImage: photoUrl.isNotEmpty
                          ? CachedNetworkImageProvider(photoUrl)
                          : null,
                      child: photoUrl.isEmpty
                          ? const Icon(
                              Icons.person,
                              size: 60,
                              color: Colors.grey,
                            )
                          : null,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                name,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      blurRadius: 10.0,
                      color: Colors.black26,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.verified, size: 14, color: Colors.white70),
                    const SizedBox(width: 6),
                    Text(
                      'ID: $sesanId',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
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

class _BidHistorySection extends StatefulWidget {
  final String userId;
  const _BidHistorySection({required this.userId});

  @override
  State<_BidHistorySection> createState() => _BidHistorySectionState();
}

class _BidHistorySectionState extends State<_BidHistorySection>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Map<String, String> _productNameCache = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<String> _getProductName(String productId) async {
    if (_productNameCache.containsKey(productId)) {
      return _productNameCache[productId]!;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('auction_products')
          .doc(productId)
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final name = data['product_name']?.toString() ?? 'គ្មានឈ្មោះ';
        _productNameCache[productId] = name;
        return name;
      }
    } catch (e) {
      debugPrint('Error fetching product name: $e');
    }

    _productNameCache[productId] = 'គ្មានឈ្មោះ';
    return 'គ្មានឈ្មោះ';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
          child: TabBar(
            controller: _tabController,
            indicator: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4),
              ],
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            labelColor: Colors.blueAccent,
            unselectedLabelColor: Colors.grey[600],
            labelStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              fontFamily: 'Siemreap',
            ),
            tabs: const [
              Tab(text: 'ប្រវត្តិដេញថ្លៃ'),
              Tab(text: 'ប្រវត្តិឈ្នះ'),
            ],
          ),
        ),
        SizedBox(
          height: 400,
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildBidHistoryTab(),
              _buildWinHistoryTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBidHistoryTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collectionGroup('bids')
          .where('bidder_id', isEqualTo: widget.userId)
          .orderBy('bid_time', descending: true)
          .limit(20)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState('មិនទាន់មានប្រវត្តិដេញថ្លៃ');
        }

        final bids = snapshot.data!.docs;
        return ListView.builder(
          itemCount: bids.length,
          itemBuilder: (context, index) {
            final bid = bids[index].data() as Map<String, dynamic>;
            final String productId =
                bids[index].reference.parent.parent?.id ?? '';
            return _buildBidTile(bid, productId);
          },
        );
      },
    );
  }

  Widget _buildWinHistoryTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('auction_products')
          .where('last_bidder_id', isEqualTo: widget.userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState('មិនទាន់មានប្រវត្តិឈ្នះ');
        }

        final products = snapshot.data!.docs;
        return ListView.builder(
          itemCount: products.length,
          itemBuilder: (context, index) {
            final data = products[index].data() as Map<String, dynamic>;
            final productName =
                data['product_name']?.toString() ?? 'គ្មានឈ្មោះ';
            final currentPrice = data['current_price'] ?? 0;
            final endTime = data['end_time'];

            return ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.emoji_events,
                  color: Colors.amber,
                  size: 24,
                ),
              ),
              title: Text(
                productName,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              subtitle: endTime != null
                  ? Text(
                      'បញ្ចប់៖ ${DateFormat('dd/MM/yyyy').format((endTime as Timestamp).toDate())}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    )
                  : null,
              trailing: Text(
                '${NumberFormat('#,###').format(currentPrice)} ៛',
                style: const TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBidTile(Map<String, dynamic> bid, String productId) {
    final bidTime = bid['bid_time'] != null
        ? (bid['bid_time'] as Timestamp).toDate()
        : null;
    final amount = bid['bid_amount'] ?? 0;

    return FutureBuilder<String>(
      future: _getProductName(productId),
      builder: (context, nameSnapshot) {
        final productName = nameSnapshot.data ?? 'កំពុងផ្ទុក...';

        return ListTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.gavel, color: Colors.blueAccent),
          ),
          title: Text(
            productName,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          subtitle: bidTime != null
              ? Text(
                  DateFormat('dd/MM/yyyy HH:mm').format(bidTime),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                )
              : null,
          trailing: Text(
            '${NumberFormat('#,###').format(amount)} ៛',
            style: const TextStyle(
              color: Colors.green,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(String message) {
    return _InfoCard(
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Icon(Icons.gavel_outlined, color: Colors.grey, size: 40),
              const SizedBox(height: 8),
              Text(
                message,
                style: const TextStyle(
                  color: Colors.grey,
                  fontFamily: 'Siemreap',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.grey[800],
          fontFamily: 'Siemreap',
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final List<Widget> children;
  const _InfoCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(children: children),
      ),
    );
  }
}

class _ProfileSkeletonLoader extends StatelessWidget {
  const _ProfileSkeletonLoader();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        children: [
          Container(
            height: 350,
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Colors.blueAccent,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(40),
                bottomRight: Radius.circular(40),
              ),
            ),
            child: const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: List.generate(3, (index) => _SkeletonTile()),
            ),
          ),
        ],
      ),
    );
  }
}

class _SkeletonTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(width: 80, height: 12, color: Colors.grey[200]),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  height: 14,
                  color: Colors.grey[200],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorStateWidget extends StatelessWidget {
  const _ErrorStateWidget();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_off, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'មិនអាចរកឃើញអ្នកប្រើប្រាស់នេះបានទេ',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
              fontFamily: 'Siemreap',
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ត្រឡប់ក្រោយ'),
          ),
        ],
      ),
    );
  }
}

class _ActivitySection extends StatelessWidget {
  final Map<String, dynamic> data;
  const _ActivitySection({required this.data});

  @override
  Widget build(BuildContext context) {
    String formatTimestamp(dynamic timestamp) {
      if (timestamp == null) return 'មិនទាន់មានទិន្នន័យ';
      if (timestamp is Timestamp) {
        return DateFormat(
          'dd/MM/yyyy HH:mm',
          'km_KH',
        ).format(timestamp.toDate());
      }
      return 'ទិន្នន័យមិនត្រឹមត្រូវ';
    }

    return _InfoCard(
      children: [
        _buildActivityTile(
          icon: Icons.login_rounded,
          iconColor: Colors.blue,
          title: 'ចូលប្រើចុងក្រោយ',
          value: formatTimestamp(data['lastLogin']),
        ),
        const Divider(height: 1, indent: 56),
        _buildActivityTile(
          icon: Icons.update_rounded,
          iconColor: Colors.orange,
          title: 'កែប្រែទិន្នន័យចុងក្រោយ',
          value: formatTimestamp(data['lastUpdate']),
        ),
      ],
    );
  }

  Widget _buildActivityTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          color: Colors.grey,
          fontFamily: 'Siemreap',
        ),
      ),
      subtitle: Text(
        value,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }
}
