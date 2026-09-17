import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:my_app/admin_withdraw_list.dart';
import 'package:my_app/admin_ai_dashboard_screen.dart';
import 'package:my_app/admin_marketplace_analytics_screen.dart';
import 'package:my_app/admin_support_inbox_screen.dart';
import 'package:my_app/ai_packages_screen.dart';
import 'package:my_app/edit_profile_screen.dart';
import 'package:my_app/sesan_ai_assistant_screen.dart';
import 'package:my_app/support_chat_screen.dart';
import 'package:my_app/investment_pitch_screen.dart';
import 'package:my_app/logout_button.dart';
import 'package:my_app/logout_service.dart';
import 'package:my_app/saved_screen.dart';
import 'package:my_app/seller_profile_screen.dart';
import 'package:my_app/seller_withdraw_screen.dart';
import 'package:my_app/vip_membership_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'login_screen.dart';
import 'policy_screen.dart';
import 'product_list.dart';
import 'admin_confirm.dart';
import 'edit_product.dart';
import 'seller_accounting_screen.dart';
import 'order_management_screen.dart';
import 'wallet_logic.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'logout_button.dart';
import 'settings_screen.dart';
import 'seller_guide_screen.dart';
import 'seller_digital_agreement_screen.dart';
import 'l10n/app_localizations.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  AppLocalizations? _fallbackLocalizations;

  AppLocalizations? get _localizations =>
      Localizations.of<AppLocalizations>(context, AppLocalizations) ??
      _fallbackLocalizations;

  String _t(String km, String en) =>
      Localizations.localeOf(context).languageCode == 'en' ? en : km;

  String? _loggedUid;
  String? _currentUid;
  final String adminUID = "WBdQVvrgEIPBTcgIlumu6bAZGUl2";
  final f = NumberFormat('#,###');
  Stream<DocumentSnapshot>? _userStream;
  Stream<QuerySnapshot>? _orderStream;
  bool _hideBalance = true;
  bool _isLoading = true;
  bool _isInvestor = false;
  bool _isSellerMode = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Localizations.of<AppLocalizations>(context, AppLocalizations) == null &&
        _fallbackLocalizations == null) {
      final locale = Localizations.maybeLocaleOf(context) ?? const Locale('km');
      AppLocalizations.delegate.load(locale).then((localizations) {
        if (mounted && _fallbackLocalizations == null) {
          setState(() => _fallbackLocalizations = localizations);
        }
      });
    }
  }

  Future<void> _checkInvestorStatus() async {
    if (_loggedUid == null) return;
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_loggedUid)
          .get();
      final sesanId = userDoc.data()?['sesan_id'] as String?;
      if (sesanId != null && sesanId.isNotEmpty) {
        final investorDoc = await FirebaseFirestore.instance
            .collection('investors')
            .doc(sesanId)
            .get();
        if (mounted) setState(() => _isInvestor = investorDoc.exists);
      } else {
        if (mounted) setState(() => _isInvestor = false);
      }
    } catch (e) {
      debugPrint('Error checking investor status: $e');
      if (mounted) setState(() => _isInvestor = false);
    }
  }

  Future<void> _loadUserData() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    String? uid = currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      uid = prefs.getString('user_uid');
    }
    if (uid == null || uid.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loggedUid = null;
        });
      }
      return;
    }
    setState(() => _currentUid = uid);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_uid', uid);
    final savedSellerMode = prefs.getBool('profile_seller_mode_$uid') ?? false;
    if (mounted) {
      setState(() {
        _loggedUid = uid;
        _isSellerMode = savedSellerMode;
        _userStream = FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .snapshots();
        _orderStream = FirebaseFirestore.instance
            .collection('orders')
            .where('seller_id', isEqualTo: uid)
            .where('status', isEqualTo: 'confirmed')
            .snapshots();
        _isLoading = false;
      });
      _checkInvestorStatus();
    }
  }

  Future<void> _toggleProfileMode() async {
    final uid = _loggedUid ?? _currentUid;
    final nextSellerMode = !_isSellerMode;

    setState(() => _isSellerMode = nextSellerMode);

    if (uid == null || uid.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('profile_seller_mode_$uid', nextSellerMode);
  }

  Future<void> _ensureUserExists() async {
    if (_loggedUid != null) {
      final userDoc = FirebaseFirestore.instance.collection('users').doc(_loggedUid);
      final docSnapshot = await userDoc.get();
      if (!docSnapshot.exists) {
        String role = (_loggedUid == adminUID) ? "admin" : "seller";
        await userDoc.set({
          'uid': _loggedUid,
          'name': _t('អ្នកលក់ថ្មី', 'New seller'),
          'phone': _t('មិនទាន់មានលេខ', 'No phone number yet'),
          'photoUrl': "",
          'role': role,
          'balance': 0,
          'created_at': FieldValue.serverTimestamp(),
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = _localizations;
    if (l10n == null) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator(color: Colors.green)),
      );
    }
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.green,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }
    if (_loggedUid == null || _loggedUid!.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text(l10n.account, style: const TextStyle(fontFamily: 'Siemreap')),
          backgroundColor: Colors.green[700],
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.person_outline, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                l10n.signInToViewAccount,
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pushNamed(context, '/login'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: Text(
                  l10n.goToSignIn,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          _isSellerMode ? l10n.accountAndMoney : l10n.account,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontFamily: 'KHMEROS', fontSize: 15),
        ),
        backgroundColor: Colors.green[700],
        elevation: 0,
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Tooltip(
              message: _isSellerMode
                  ? _t('ប្តូរទៅរបៀបអ្នកប្រើ', 'Switch to User Mode')
                  : _t('ប្តូរទៅរបៀបអ្នកលក់', 'Switch to Seller Mode'),
              child: IconButton(
                onPressed: _toggleProfileMode,
                icon: Icon(
                  _isSellerMode
                      ? Icons.person_outline_rounded
                      : Icons.storefront_outlined,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _userStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data?.data() as Map<String, dynamic>?;
          String name =
              data?['name'] ?? _t("រកឈ្មោះមិនឃើញ", "Name not found");
          int balance = (data?['balance'] ?? 0).toInt();
          String photoUrl = data?['photoUrl'] ?? "";
          bool isFrozen = data?['isFrozen'] ?? false;

          return SingleChildScrollView(
            child: Column(
              children: [
                _buildHeader(name, photoUrl, balance, isFrozen),
                if (_isSellerMode) ...[
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    child: Column(
                      children: [
                        _buildFinanceCenterCard(l10n),
                        _buildSellerOrdersCard(),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  child: _isSellerMode
                      ? _buildSellerMode(data, l10n)
                      : _buildUserMode(data, l10n),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: OutlinedButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            title: Text(
                              l10n.signOut,
                              style: const TextStyle(
                                fontFamily: 'Siemreap',
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            content: Text(
                              l10n.signOutConfirmation,
                              style: const TextStyle(fontFamily: 'Siemreap'),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: Text(
                                  l10n.cancel,
                                  style: const TextStyle(color: Colors.grey),
                                ),
                              ),
                              TextButton(
                                onPressed: () async {
                                  final prefs =
                                      await SharedPreferences.getInstance();
                                  await prefs.clear();
                                  if (context.mounted) {
                                    Navigator.of(context).pushNamedAndRemoveUntil(
                                      '/login',
                                      (route) => false,
                                    );
                                  }
                                },
                                child: Text(
                                  l10n.signOut,
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                    icon: const Icon(Icons.logout, color: Colors.red),
                    label: Text(
                      l10n.signOut,
                      style: const TextStyle(
                        color: Colors.red,
                        fontFamily: 'Siemreap',
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFinanceCenterCard(AppLocalizations l10n) {
    return _buildMenuCard(
      title: l10n.financeCenter,
      subtitle: l10n.viewIncomeExpenses,
      icon: Icons.account_balance_wallet,
      color: Colors.purple,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SellerAccountingScreen(
            sellerId: _loggedUid ?? "",
          ),
        ),
      ),
    );
  }

  Widget _buildSellerOrdersCard() {
    return StreamBuilder<QuerySnapshot>(
      stream: _orderStream,
      builder: (context, snapshot) {
        final count = snapshot.hasData ? snapshot.data!.docs.length : 0;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            _buildMenuCard(
              title: _t('ការបញ្ជាទិញរបស់អ្នកលក់', 'Seller Orders'),
              subtitle: _t(
                'គ្រប់គ្រង និងតាមដានការបញ្ជាទិញរបស់អ្នក',
                'Manage and track your seller orders',
              ),
              icon: Icons.receipt_long_rounded,
              color: Colors.blueGrey,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => OrderManagementScreen(
                    sellerId: _loggedUid ?? "",
                  ),
                ),
              ),
            ),
            if (count > 0)
              Positioned(
                right: 38,
                top: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    count > 99 ? '99+' : '$count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildSesanAiAssistantCard() {
    return _buildMenuCard(
      title: _t('Sesan AI ជំនួយការ', 'Sesan AI Assistant'),
      subtitle: _t(
        'សួរអំពីកសិកម្ម ការលក់ និងហិរញ្ញវត្ថុ',
        'Ask about farming, sales, and finance',
      ),
      icon: Icons.auto_awesome_rounded,
      color: Colors.green,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const SesanAiAssistantScreen(),
        ),
      ),
    );
  }

  Widget _buildUserMode(
    Map<String, dynamic>? data,
    AppLocalizations l10n,
  ) {
    return Column(
      children: [
        _buildSesanAiAssistantCard(),
        _buildSesanIdCard(data, l10n),
        _buildMenuCard(
          title: _t('កញ្ចប់ Sesan AI', 'Sesan AI Packages'),
          subtitle: _t(
            'មើល Credit តម្លៃ និងស្នើសុំជាវកញ្ចប់',
            'View credits, prices and request a subscription',
          ),
          icon: Icons.workspace_premium_outlined,
          color: Colors.deepPurple,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AiPackagesScreen()),
          ),
        ),
        if (_isInvestor)
          _buildMenuCard(
            title: l10n.sesanPartnership,
            subtitle: l10n.sesanPartnershipDescription,
            icon: Icons.show_chart_rounded,
            color: Colors.orange,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const InvestmentPitchScreen(),
              ),
            ),
          ),
        _buildMenuCard(
          title: l10n.savedProductsAndShops,
          subtitle: l10n.savedProductsAndFollowedShops,
          icon: Icons.bookmark_rounded,
          color: Colors.pinkAccent,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SavedScreen()),
          ),
        ),
        _buildVipCard(l10n),
        _buildCommonAccountMenus(l10n),
      ],
    );
  }

  Widget _buildSellerMode(
    Map<String, dynamic>? data,
    AppLocalizations l10n,
  ) {
    return Column(
      children: [
        _buildSesanAiAssistantCard(),
        _buildMenuCard(
          title: _t('គ្រប់គ្រងការបង្ហោះ', 'Manage posts'),
          subtitle: l10n.managePostedProducts,
          icon: Icons.inventory_2,
          color: Colors.blue,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ProductListScreen(
                category: 'ទំនិញរបស់ខ្ញុំ',
              ),
            ),
          ),
        ),
        _buildMenuCard(
          title: l10n.viewMyShop,
          subtitle: l10n.previewMyShop,
          icon: Icons.storefront,
          color: Colors.teal,
          onTap: () async {
            if (_loggedUid == null) return;
            String sellerName = _t("ហាងរបស់ខ្ញុំ", "My shop");
            try {
              final doc = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(_loggedUid)
                  .get();
              if (doc.exists) {
                sellerName = doc.data()?['name'] ?? sellerName;
              }
            } catch (_) {}
            if (mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SellerProfileScreen(
                    sellerId: _loggedUid!,
                    sellerName: sellerName,
                  ),
                ),
              );
            }
          },
        ),
        if (_loggedUid == adminUID)
          _buildMenuCard(
            title: _t('ប្រអប់សារ Support', 'Support Inbox'),
            subtitle: _t(
              'ឆ្លើយតបសំណួរ និងបញ្ហារបស់អ្នកប្រើប្រាស់',
              'Reply to user questions and support requests',
            ),
            icon: Icons.support_agent_rounded,
            color: Colors.green,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AdminSupportInboxScreen(),
              ),
            ),
          ),
        if (_loggedUid == adminUID)
          _buildMenuCard(
            title: l10n.adminDashboard,
            subtitle: l10n.reviewCustomerPayments,
            icon: Icons.admin_panel_settings,
            color: Colors.orange,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AdminConfirmPage(),
              ),
            ),
          ),
        if (_loggedUid == adminUID)
          _buildMenuCard(
            title: _t('គ្រប់គ្រង Sesan AI', 'Sesan AI Dashboard'),
            subtitle: _t(
              'ការប្រើប្រាស់ Credit និងមតិយោបល់',
              'Usage, credits and feedback',
            ),
            icon: Icons.auto_awesome_rounded,
            color: Colors.deepPurple,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AdminAiDashboardScreen(),
              ),
            ),
          ),
        if (_loggedUid == adminUID)
          _buildMenuCard(
            title: _t('វិភាគ Marketplace', 'Marketplace Analytics'),
            subtitle: _t(
              'តាមដាន Show number, Chat, Cart, Checkout និង Order',
              'Track phone reveals, chats, cart, checkout and orders',
            ),
            icon: Icons.insights_rounded,
            color: Colors.indigo,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AdminMarketplaceAnalyticsScreen(),
              ),
            ),
          ),
        if (_loggedUid == adminUID)
          _buildMenuCard(
            title: l10n.sellerWithdrawals,
            subtitle: l10n.reviewSellerWithdrawals,
            icon: Icons.monetization_on,
            color: Colors.redAccent,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => AdminWithdrawList()),
            ),
          ),
        _buildSesanIdCard(data, l10n),
        _buildMenuCard(
          title: _t('កញ្ចប់ Sesan AI', 'Sesan AI Packages'),
          subtitle: _t(
            'មើល Credit តម្លៃ និងស្នើសុំជាវកញ្ចប់',
            'View credits, prices and request a subscription',
          ),
          icon: Icons.workspace_premium_outlined,
          color: Colors.deepPurple,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AiPackagesScreen()),
          ),
        ),
        _buildVipCard(l10n),
        if (_isInvestor)
          _buildMenuCard(
            title: l10n.sesanPartnership,
            subtitle: l10n.sesanPartnershipDescription,
            icon: Icons.show_chart_rounded,
            color: Colors.orange,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const InvestmentPitchScreen(),
              ),
            ),
          ),
        _buildMenuCard(
          title: l10n.savedProductsAndShops,
          subtitle: l10n.savedProductsAndFollowedShops,
          icon: Icons.bookmark_rounded,
          color: Colors.pinkAccent,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SavedScreen()),
          ),
        ),
        _buildMenuCard(
          title: _t('មគ្គុទេសក៍អ្នកលក់', 'Seller guide'),
          subtitle: _t(
            'រៀនបង្ហោះ លក់តាមកន្ត្រក គ្រប់គ្រងស្តុក និង Order',
            'Learn posting, cart sales, stock, and orders',
          ),
          icon: Icons.menu_book_rounded,
          color: Colors.green,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const SellerGuideScreen(),
            ),
          ),
        ),
        _buildMenuCard(
          title: _t(
            'កិច្ចព្រមព្រៀងឌីជីថលអ្នកលក់',
            'Seller digital agreement',
          ),
          subtitle: _t(
            'អាន និងយល់ព្រមលើលក្ខខណ្ឌលក់ដូរជាមួយ Sesan App',
            'Review and accept the Sesan App seller terms',
          ),
          icon: Icons.draw_rounded,
          color: Colors.indigo,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const SellerDigitalAgreementScreen(),
            ),
          ),
        ),
        _buildCommonAccountMenus(l10n),
      ],
    );
  }

  Widget _buildVipCard(AppLocalizations l10n) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(_loggedUid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const SizedBox.shrink();
        }
        final userData = snapshot.data!.data() as Map<String, dynamic>;
        final bool isVip = userData['isVip'] == true;
        if (isVip) {
          return _buildMenuCard(
            title: l10n.vipMember,
            subtitle: l10n.vipMemberDescription,
            icon: Icons.diamond,
            color: Colors.amber,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const VipMembershipScreen(),
              ),
            ),
          );
        }
        return _buildMenuCard(
          title: l10n.becomeVip,
          subtitle: l10n.becomeVipDescription,
          icon: Icons.diamond,
          color: Colors.amber,
          onTap: _showVipBenefitsDialog,
        );
      },
    );
  }

  Widget _buildCommonAccountMenus(AppLocalizations l10n) {
    return Column(
      children: [
        _buildMenuCard(
          title: l10n.legalPolicies,
          subtitle: _t(
            "គោលការណ៍ឯកជនភាព និងលក្ខខណ្ឌប្រើប្រាស់",
            "Privacy Policy & Terms",
          ),
          icon: Icons.gavel_rounded,
          color: Colors.redAccent,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const PolicyScreen()),
          ),
        ),
        _buildMenuCard(
          title: l10n.settings,
          subtitle: _t(
            "ភាសា និងការកំណត់គណនី",
            "Language & account settings",
          ),
          icon: Icons.settings_rounded,
          color: Colors.green,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SettingsScreen()),
          ),
        ),
        _buildMenuCard(
          title: l10n.helpAndSupport,
          subtitle: _t(
            "ឆាតជាមួយ Sesan Support និងប្រើ AI ពេល Admin មិននៅ",
            "Chat with Sesan Support, with AI help when Admin is away",
          ),
          icon: Icons.support_agent_rounded,
          color: Colors.blue,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const SupportChatScreen(),
            ),
          ),
        ),
        _buildMenuCard(
          title: l10n.aboutUs,
          subtitle: _t(
            "ស្វែងយល់បន្ថែមអំពី Sesan",
            "Learn more about Sesan",
          ),
          icon: Icons.info_outline_rounded,
          color: Colors.orange,
          onTap: () async {
            final Uri url = Uri.parse('https://about.sesanshop.com');
            if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
              throw Exception('Could not launch $url');
            }
          },
        ),
      ],
    );
  }

  void _showVipBenefitsDialog() {
    final l10n = _localizations!;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Row(
                  children: [
                    Icon(Icons.diamond, color: Colors.amber[700], size: 28),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n.vipBenefits,
                        style: const TextStyle(
                          fontFamily: 'Siemreap',
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _benefitLine('👑 ${l10n.vipBadgeBenefit}'),
                      _benefitLine('📊 ${l10n.vipStatisticsBenefit}'),
                      _benefitLine('🎯 ${l10n.vipPromotionBenefit}'),
                      _benefitLine('💎 ${l10n.vipSupportBenefit}'),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.amber.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.monetization_on,
                              color: Colors.amber.shade800,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                l10n.vipPrice,
                                style: TextStyle(
                                  fontFamily: 'Siemreap',
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber.shade900,
                                  fontSize: 15,
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
              Padding(
                padding: const EdgeInsets.only(
                  bottom: 20,
                  left: 20,
                  right: 20,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(
                        l10n.notNow,
                        style: const TextStyle(
                          fontFamily: 'Siemreap',
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber.shade700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const VipMembershipScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.shopping_cart_checkout, size: 20),
                      label: Text(
                        l10n.buyNow,
                        style: const TextStyle(
                          fontFamily: 'Siemreap',
                          fontWeight: FontWeight.bold,
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

  Widget _benefitLine(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle, size: 18, color: Colors.green),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontFamily: 'Siemreap', fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(
    String name,
    String photoUrl,
    int balance,
    bool isFrozen,
  ) {
    return Container(
      padding: const EdgeInsets.only(bottom: 25),
      decoration: BoxDecoration(
        color: Colors.green[700],
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              radius: 30,
              backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
              child: photoUrl.isEmpty
                  ? const Icon(Icons.person, size: 35)
                  : null,
            ),
            title: Text(
              name,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            subtitle: _isSellerMode
                ? Text(
                    _localizations!.professionalSeller,
                    style: const TextStyle(color: Colors.white70),
                  )
                : null,
          ),
          if (_isSellerMode) ...[
            const SizedBox(height: 15),
            if (_currentUid != null && _currentUid!.isNotEmpty)
              WalletLogic(
                uid: _currentUid!,
                builder: (total, pending, available) =>
                    _buildWalletUI(total, pending, available, isFrozen),
              )
            else
              const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildWalletUI(
    double total,
    double pending,
    double available,
    bool isFrozen,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _localizations!.availableBalance,
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            _hideBalance
                                ? '••••••'
                                : '${f.format(available)} ៛',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () {
                            setState(() => _hideBalance = !_hideBalance);
                          },
                          tooltip:
                              _hideBalance ? _t('បង្ហាញសមតុល្យ', 'Show balance') : _t('លាក់សមតុល្យ', 'Hide balance'),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 48,
                            minHeight: 48,
                          ),
                          icon: Icon(
                            _hideBalance
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: Colors.grey[500],
                            size: 22,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  if (isFrozen) {
                    _showFrozenAlert(context);
                    return;
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SellerWithdrawScreen(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                ),
                child: Text(
                  _localizations!.withdraw,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
            ],
          ),
          const Divider(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMiniBalance(
                _localizations!.pendingBalance,
                _hideBalance ? null : pending,
                Colors.orange,
              ),
              _buildMiniBalance(
                _localizations!.totalBalance,
                _hideBalance ? null : total,
                Colors.blue,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniBalance(String label, double? amount, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
        Text(
          amount == null ? '••••••' : '${f.format(amount)} ៛',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildSesanIdCard(
    Map<String, dynamic>? data,
    AppLocalizations l10n,
  ) {
    final sesanId = (data?['sesan_id'] ?? '').toString().trim();
    final hasId = sesanId.isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: const Color(0xFFF7FAF3),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(
          color: Colors.black.withOpacity(0.06),
          width: 0.8,
        ),
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 6,
        ),
        minLeadingWidth: 44,
        leading: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.10),
            borderRadius: BorderRadius.circular(11),
          ),
          child: const Icon(
            Icons.tag_rounded,
            color: Colors.green,
            size: 23,
          ),
        ),
        title: Text(
          l10n.mySesanId,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            height: 1.22,
            fontFamily: 'Siemreap',
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                hasId ? sesanId : l10n.notAvailableYet,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.25,
                  fontWeight: hasId ? FontWeight.w700 : FontWeight.w400,
                  color: hasId
                      ? const Color(0xFF303530)
                      : const Color(0xFF757575),
                  fontFamily: 'Siemreap',
                  letterSpacing: hasId ? 1.1 : 0,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                l10n.sesanIdHelp,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10.5,
                  height: 1.25,
                  color: Color(0xFF5F6368),
                  fontFamily: 'Siemreap',
                ),
              ),
            ],
          ),
        ),
        trailing: hasId
            ? IconButton(
                tooltip: l10n.idCopied,
                visualDensity: VisualDensity.compact,
                icon: const Icon(
                  Icons.copy_rounded,
                  color: Color(0xFF4F554F),
                  size: 19,
                ),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: sesanId));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        l10n.idCopied,
                        style: const TextStyle(fontFamily: 'Siemreap'),
                      ),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              )
            : TextButton(
                onPressed: _generateSesanId,
                child: Text(
                  l10n.create,
                  style: TextStyle(
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Siemreap',
                    fontSize: 11,
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildMenuCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: const Color(0xFFF7FAF3),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(
          color: Colors.black.withOpacity(0.06),
          width: 0.8,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        dense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 6,
        ),
        minLeadingWidth: 44,
        leading: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withOpacity(0.10),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: color, size: 23),
        ),
        title: Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            height: 1.22,
            fontFamily: 'Siemreap',
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              height: 1.30,
              color: Color(0xFF5F6368),
              fontFamily: 'Siemreap',
            ),
          ),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios_rounded,
          size: 14,
          color: Color(0xFF4F554F),
        ),
      ),
    );
  }

  void _showFrozenAlert(BuildContext context) {
    final l10n = _localizations!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.report_problem, color: Colors.orange),
            const SizedBox(width: 10),
            Text(l10n.accountNotice),
          ],
        ),
        content: Text(
          l10n.frozenAccountMessage,
          style: const TextStyle(fontFamily: 'KHMEROS'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.ok),
          ),
        ],
      ),
    );
  }

  Future<void> _generateSesanId() async {
    if (_loggedUid == null) return;
    final l10n = _localizations!;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.tag_rounded,
                  color: Colors.green[700],
                  size: 30,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.createSesanIdTitle,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Siemreap',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.createSesanIdDescription,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 13,
                  fontFamily: 'Siemreap',
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey,
                        side: BorderSide(color: Colors.grey[300]!),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text(
                        l10n.cancel,
                        style: const TextStyle(fontFamily: 'Siemreap'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[700],
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text(
                        l10n.create,
                        style: const TextStyle(
                          color: Color.fromARGB(255, 246, 247, 245),
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Siemreap',
                        ),
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

    if (confirm != true) return;

    try {
      String newId = '';
      bool isUnique = false;

      while (!isUnique) {
        newId = (100000 +
                (DateTime.now().microsecondsSinceEpoch % 900000))
            .toString();

        final existing = await FirebaseFirestore.instance
            .collection('users')
            .where('sesan_id', isEqualTo: newId)
            .limit(1)
            .get();

        if (existing.docs.isEmpty) isUnique = true;
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(_loggedUid)
          .update({
            'sesan_id': newId,
            'sesan_id_created': FieldValue.serverTimestamp(),
          });

      if (mounted) setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.sesanIdCreated(newId),
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'Siemreap',
              ),
            ),
            backgroundColor: Colors.green[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.errorMessage(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class AboutMeScreen extends StatelessWidget {
  const AboutMeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F0),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: const Color(0xFF1B5E20),
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFF1B5E20),
                          Color(0xFF2E7D32),
                          Color(0xFF388E3C),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40),
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                          border: Border.all(color: Colors.white, width: 3),
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/sesan_icon.jpg',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.eco,
                              size: 50,
                              color: Color(0xFF2E7D32),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        l10n.sesan,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'Siemreap',
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          l10n.forKhmerFarmers,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontFamily: 'Siemreap',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildQuoteCard(l10n),
                  const SizedBox(height: 20),
                  _buildCard(
                    emoji: '🌾',
                    title: l10n.aboutLandTitle,
                    content: l10n.aboutLandContent,
                    color: const Color(0xFF1B5E20),
                  ),
                  const SizedBox(height: 16),
                  _buildCard(
                    emoji: '👨‍🌾',
                    title: l10n.aboutFarmersTitle,
                    content: l10n.aboutFarmersContent,
                    color: const Color(0xFFE65100),
                  ),
                  const SizedBox(height: 16),
                  _buildCard(
                    emoji: '💚',
                    title: l10n.aboutWorkValueTitle,
                    content: l10n.aboutWorkValueContent,
                    color: const Color(0xFF1565C0),
                  ),
                  const SizedBox(height: 16),
                  _buildCard(
                    emoji: '🎯',
                    title: l10n.aboutMissionTitle,
                    content: l10n.aboutMissionContent,
                    color: const Color(0xFF6A1B9A),
                  ),
                  const SizedBox(height: 16),
                  _buildCard(
                    emoji: '🙏',
                    title: l10n.aboutThanksTitle,
                    content: l10n.aboutThanksContent,
                    color: const Color(0xFF2E7D32),
                  ),
                  const SizedBox(height: 30),
                  Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1B5E20).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFF2E7D32).withOpacity(0.2),
                          ),
                        ),
                        child: Text(
                          l10n.aboutSlogan,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.8,
                            color: Color(0xFF1B5E20),
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Siemreap',
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '© ${DateTime.now().year} Sesan Agriculture Technology',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 11,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuoteCard(AppLocalizations l10n) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text('❓', style: TextStyle(fontSize: 32)),
          const SizedBox(height: 12),
          Text(
            l10n.aboutQuestion,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              fontFamily: 'Siemreap',
              height: 1.6,
            ),
          ),
          const SizedBox(height: 12),
          Container(height: 2, width: 60, color: Colors.white38),
          const SizedBox(height: 12),
          Text(
            l10n.aboutQuestionAnswer,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontFamily: 'Siemreap',
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({
    required String emoji,
    required String title,
    required String content,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
            decoration: BoxDecoration(
              color: color.withOpacity(0.07),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
              border: Border(
                left: BorderSide(color: color, width: 4),
              ),
            ),
            child: Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: color,
                      fontFamily: 'Siemreap',
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              content,
              style: const TextStyle(
                fontSize: 14,
                height: 1.9,
                color: Color(0xFF37474F),
                fontFamily: 'Siemreap',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
