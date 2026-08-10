import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:my_app/admin_withdraw_list.dart';
import 'package:my_app/edit_profile_screen.dart';
import 'package:my_app/farm_tools.dart';
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
import 'l10n/app_localizations.dart';


class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});


  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}


class _ProfileScreenState extends State<ProfileScreen> {
  String? _loggedUid;
  String? _currentUid; // 👈 ថែមជួរនេះចូល ដើម្បីទុក UID បង្ការការ Rebuild ញឹក
  final String adminUID = "WBdQVvrgEIPBTcgIlumu6bAZGUl2";
  final f = NumberFormat('#,###');
  Stream<DocumentSnapshot>? _userStream;
  Stream<QuerySnapshot>? _orderStream;
  bool _hideBalance = true;
  bool _isLoading = true; // ថែមជួរនេះចូល
  bool _isInvestor = false; // ✅ បន្ថែមបន្ទាត់នេះ


  @override
  void initState() {
    super.initState();
    _loadUserData();
  }


  Future<void> _checkInvestorStatus() async {
    if (_loggedUid == null) return;


    try {
      // អាន sesan_id ពី collection users
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_loggedUid)
          .get();


      final sesanId = userDoc.data()?['sesan_id'] as String?;


      if (sesanId != null && sesanId.isNotEmpty) {
        // ពិនិត្យមើលថា sesan_id នេះមានក្នុងបញ្ជី investors ដែរឬទេ
        final investorDoc = await FirebaseFirestore.instance
            .collection('investors')
            .doc(sesanId)
            .get();


        if (mounted) {
          setState(() {
            _isInvestor = investorDoc.exists;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isInvestor = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error checking investor status: $e');
      if (mounted) {
        setState(() {
          _isInvestor = false;
        });
      }
    }
  }


  Future<void> _loadUserData() async {
    // យក UID ពី Firebase Auth ជាមុន (ត្រឹមត្រូវបំផុត)
    final currentUser = FirebaseAuth.instance.currentUser;
    String? uid = currentUser?.uid;


    // បើ Firebase Auth មិនមាន ទើងយកពី SharedPreferences
    if (uid == null || uid.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      uid = prefs.getString('user_uid');
    }


    if (uid == null || uid.isEmpty) {
      // ✅ កុំ redirect ដោយស្វ័យប្រវត្តិ — ទុកជា Guest state
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loggedUid = null;
        });
      }
      return;
    }
    setState(() {
      _currentUid = uid; // ទុក UID ក្នុង State ឱ្យនៅថេរ
    });


    // Save ទៅ SharedPreferences ជានិច្ច
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_uid', uid);


    if (mounted) {
      setState(() {
        _loggedUid = uid;


        // បង្កើត Stream ឱ្យចំ Document ID
        _userStream = FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .snapshots();


        _orderStream = FirebaseFirestore.instance
            .collection('orders')
            .where('seller_id', isEqualTo: uid)
            .where('status', isEqualTo: 'confirmed')
            .snapshots();


        _isLoading = false; // ប្រាប់ថាទាញ ID រួចហើយ
      });
      // ✅ បន្ថែមបន្ទាត់នេះ
      _checkInvestorStatus();
    }
  }


  Future<void> _ensureUserExists() async {
    if (_loggedUid != null) {
      final userDoc = FirebaseFirestore.instance
          .collection('users')
          .doc(_loggedUid);
      final docSnapshot = await userDoc.get();


      if (!docSnapshot.exists) {
        String role = (_loggedUid == adminUID) ? "admin" : "seller";
        await userDoc.set({
          'uid': _loggedUid,
          'name': "អ្នកលក់ថ្មី",
          'phone': "មិនទាន់មានលេខ",
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
    final l10n = AppLocalizations.of(context)!;
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
          actions: [
            IconButton(
              tooltip: 'Settings',
              icon: const Icon(Icons.settings_rounded),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
            ),
          ],
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
      // ... កូដ UI ខាងក្រោមទុកនៅដដែលទាំងអស់ ...
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          l10n.accountAndMoney,
          style: const TextStyle(fontFamily: 'KHMEROS', fontSize: 18),
        ),
        backgroundColor: Colors.green[700],
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_rounded, color: Colors.white),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
          StreamBuilder<QuerySnapshot>(
            stream: _orderStream,
            builder: (context, snapshot) {
              if (snapshot.hasError)
                return const Icon(Icons.error_outline, color: Colors.red);
              // នៅ build method បន្ថែម null check
              if (_orderStream == null) {
                return const SizedBox.shrink(); // ឬ CircularProgressIndicator
              }


              int count = (snapshot.hasData) ? snapshot.data!.docs.length : 0;


              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.sell, // ✅ រូបស្លាកលក់
                        color: Colors.white,
                        size: 24,
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => OrderManagementScreen(
                              sellerId: _loggedUid ?? "",
                            ),
                          ),
                        );
                      },
                    ),
                    if (count > 0)
                      Positioned(
                        right: 5,
                        top: 5,
                        child: Container(
                          padding: const EdgeInsets.all(2),
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
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _userStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }


          final data = snapshot.data?.data() as Map<String, dynamic>?;


          String name = data?['name'] ?? "រកឈ្មោះមិនឃើញក្នុង Firebase";
          int balance = (data?['balance'] ?? 0).toInt();
          String photoUrl = data?['photoUrl'] ?? "";
          bool isFrozen = data?['isFrozen'] ?? false;


          return SingleChildScrollView(
            child: Column(
              children: [
                _buildHeader(name, photoUrl, balance, isFrozen),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  child: Column(
                    children: [
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
                          title: l10n.sellerWithdrawals,
                          subtitle: l10n.reviewSellerWithdrawals,
                          icon: Icons.monetization_on,
                          color: Colors.redAccent,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AdminWithdrawList(),
                            ),
                          ),
                        ),


                      // មេលុបពីត្រឹម FutureBuilder<DocumentSnapshot>( រហូតដល់វង់ក្រចកបិទរបស់វា រួចដាក់អាខាងក្រោមនេះជំនួស
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF2FAF2),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: Colors.black.withOpacity(0.03),
                            width: 0.5,
                          ),
                        ),
                        child: ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.tag_rounded,
                              color: Colors.green,
                              size: 24,
                            ),
                          ),
                          title: Text(
                            l10n.mySesanId,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                (data?['sesan_id'] != null &&
                                    data!['sesan_id'].toString().isNotEmpty)
                                    ? data['sesan_id']
                                    : l10n.notAvailableYet,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color:
                                  (data?['sesan_id'] != null &&
                                      data!['sesan_id']
                                          .toString()
                                          .isNotEmpty)
                                      ? Colors.black87
                                      : Colors.grey[500],
                                  fontFamily: 'Siemreap',
                                  letterSpacing:
                                  (data?['sesan_id'] != null &&
                                      data!['sesan_id']
                                          .toString()
                                          .isNotEmpty)
                                      ? 1.5
                                      : 0,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                l10n.sesanIdHelp,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF757575), // Colors.grey[600]
                                  fontFamily: 'Siemreap',
                                ),
                              ),
                            ],
                          ),
                          trailing:
                          (data?['sesan_id'] != null &&
                              data!['sesan_id'].toString().isNotEmpty)
                              ? IconButton(
                            icon: const Icon(
                              Icons.copy_rounded,
                              color: Colors.black45,
                              size: 20,
                            ),
                            onPressed: () {
                              Clipboard.setData(
                                ClipboardData(text: data['sesan_id']),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    l10n.idCopied,
                                    style: const TextStyle(
                                      fontFamily: 'Siemreap',
                                    ),
                                  ),
                                  backgroundColor: Colors.green,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                          )
                              : TextButton(
                            onPressed: () => _generateSesanId(),
                            child: Text(
                              l10n.create,
                              style: TextStyle(
                                color: Colors.green[700],
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Siemreap',
                              ),
                            ),
                          ),
                        ),
                      ),


                      _buildMenuCard(
                        title: l10n.myProducts,
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


                      // ✅ បន្ថែមប៊ូតុងថ្មីនៅទីនេះ
                      _buildMenuCard(
                        title: l10n.viewMyShop,
                        subtitle: l10n.previewMyShop,
                        icon: Icons.storefront,
                        color: Colors.teal,
                        onTap: () async {
                          if (_loggedUid == null) return;


                          // ទាញឈ្មោះអ្នកលក់
                          String sellerName = "ហាងរបស់ខ្ញុំ";
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
                      _buildMenuCard(
                        title: l10n.financeCenter,
                        subtitle: l10n.viewIncomeExpenses,
                        icon: Icons.account_balance_wallet,
                        color: Colors.purple,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SellerAccountingScreen(
                                sellerId: _loggedUid ?? "",
                              ),
                            ),
                          );
                        },
                      ),


                      // ✅ បង្ហាញប៊ូតុងវិនិយោគ លុះត្រាតែជាអ្នកវិនិយោគ
                      if (_isInvestor)
                        _buildMenuCard(
                          title: l10n.sesanPartnership,
                          subtitle: l10n.sesanPartnershipDescription,
                          icon: Icons.show_chart_rounded,
                          color: Colors.orange,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                              const InvestmentPitchScreen(),
                            ),
                          ),
                        ),


                      _buildMenuCard(
                        title: l10n.farmTools,
                        subtitle: l10n.calculatorsAndMeasurement,
                        icon: Icons.calculate_rounded,
                        color: Colors.orange,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const FarmToolsPage(),
                            ),
                          );
                        },
                      ),


                      _buildMenuCard(
                        title: l10n.savedProductsAndShops,
                        subtitle: l10n.savedProductsAndFollowedShops,
                        icon: Icons.bookmark_rounded,
                        color: Colors.pinkAccent,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SavedScreen(),
                            ),
                          );
                        },
                      ),
                      StreamBuilder<DocumentSnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('users')
                            .doc(_loggedUid)
                            .snapshots(),
                        builder: (context, snapshot) {
                          // កំពុងផ្ទុក ឬរកមិនឃើញ
                          if (!snapshot.hasData || !snapshot.data!.exists) {
                            return const SizedBox.shrink();
                          }


                          final userData =
                          snapshot.data!.data() as Map<String, dynamic>;
                          final bool isVip = userData['isVip'] == true;


                          if (isVip) {
                            // ── ជា VIP រួចហើយ៖ បង្ហាញកាតដែលគ្មានសកម្មភាព ឬបើក Screen ពិសេស ──
                            return _buildMenuCard(
                              title: l10n.vipMember,
                              subtitle: l10n.vipMemberDescription,
                              icon: Icons.diamond,
                              color: Colors.amber,
                              onTap: () {
                                // អាចរុញទៅកាន់ Screen ដែលបង្ហាញតែអត្ថប្រយោជន៍ ឬក្រាប (ដោយគ្មានជម្រើសទិញ)
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                    const VipMembershipScreen(), // ឬ Screen ថ្មីសម្រាប់ VIP
                                  ),
                                );
                              },
                            );
                          } else {
                            // ── មិនទាន់ជា VIP៖ បង្ហាញ Dialog លក់ ──
                            return _buildMenuCard(
                              title: l10n.becomeVip,
                              subtitle: l10n.becomeVipDescription,
                              icon: Icons.diamond,
                              color: Colors.amber,
                              onTap: _showVipBenefitsDialog,
                            );
                          }
                        },
                      ),
                      _buildMenuCard(
                        title: l10n.editProfile,
                        subtitle: l10n.editProfileDescription,
                        icon: Icons.edit_note,
                        color: Colors.teal,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const EditProfileScreen(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, indent: 70),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ListTile(
                    leading: const Icon(
                      Icons.gavel_rounded,
                      color: Colors.redAccent,
                    ),
                    title: Text(
                      l10n.legalPolicies,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text("Privacy Policy & Terms"),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PolicyScreen(),
                        ),
                      );
                    },
                  ),
                ),


                ListTile(
                  leading: const Icon(
                    Icons.help_outline_rounded,
                    color: Colors.blue,
                  ),
                  title: Text(
                    l10n.helpAndSupport,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () async {
                    final Uri url = Uri.parse(
                      'https://www.facebook.com/share/1EBrJfNXP4/',
                    );
                    if (!await launchUrl(
                      url,
                      mode: LaunchMode.externalApplication,
                    )) {
                      throw Exception('Could not launch $url');
                    }
                  },
                ),
                const Divider(height: 1, indent: 70),
                ListTile(
                  leading: const Icon(
                    Icons.info_outline_rounded,
                    color: Colors.orange,
                  ),
                  title: Text(
                    l10n.aboutUs,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AboutMeScreen(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1, indent: 70),
                const SizedBox(height: 20), // ថែមឃ្លាតបន្តិចឱ្យស្អាត
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: OutlinedButton.icon(
                    onPressed: () {
                      // 🎯 បង្ហាញផ្ទាំងសួរបញ្ជាក់ (Confirmation Dialog)
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
                              // ប៊ូតុង បោះបង់
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: Text(
                                  l10n.cancel,
                                  style: const TextStyle(color: Colors.grey),
                                ),
                              ),
                              // ប៊ូតុង យល់ព្រម (Sign Out)
                              TextButton(
                                onPressed: () async {
                                  final prefs =
                                  await SharedPreferences.getInstance();
                                  await prefs
                                      .clear(); // លុបទិន្នន័យ Login ចោលទាំងអស់


                                  if (context.mounted) {
                                    // បិទ Dialog និងបញ្ជូនទៅទំព័រ Login វិញ
                                    Navigator.of(
                                      context,
                                    ).pushNamedAndRemoveUntil(
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


  void _showVipBenefitsDialog() {
    final l10n = AppLocalizations.of(context)!;
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
              // ចំណងជើង
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
              // ខ្លឹមសារអាចរំកិលបាន
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
              // ប៊ូតុងក្រោម
              Padding(
                padding: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
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
              backgroundImage: photoUrl.isNotEmpty
                  ? NetworkImage(photoUrl)
                  : null,
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
            subtitle: Text(
              AppLocalizations.of(context)!.professionalSeller,
              style: const TextStyle(color: Colors.white70),
            ),
          ),
          const SizedBox(height: 15),


          // ឆែក UID បើមានទើបបង្ហាញ Wallet
          if (_currentUid != null && _currentUid!.isNotEmpty)
            WalletLogic(
              uid: _currentUid!,
              builder: (total, pending, available) =>
                  _buildWalletUI(total, pending, available, isFrozen),
            )
          else
            const Center(child: CircularProgressIndicator(color: Colors.white)),
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
                      AppLocalizations.of(context)!.availableBalance,
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
                        GestureDetector(
                          onTap: () =>
                              setState(() => _hideBalance = !_hideBalance),
                          child: Icon(
                            _hideBalance
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: Colors.grey[400],
                            size: 18,
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


                  // ✅ ប្តូរមកហៅ Screen ថ្មី (មេឆែកឈ្មោះ Class ក្នុង File ថ្មីឱ្យត្រូវផង)
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SellerWithdrawScreen(),
                    ),
                  );
                }, // 👈 បិទ onPressed
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
                  AppLocalizations.of(context)!.withdraw,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ), // 👈 បិទ ElevatedButton
            ], // 👈 បិទ Row children
          ), // 👈 បិទ Row
          const Divider(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMiniBalance(
                AppLocalizations.of(context)!.pendingBalance,
                _hideBalance ? null : pending,
                Colors.orange,
              ),
              _buildMiniBalance(
                AppLocalizations.of(context)!.totalBalance,
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


  Widget _buildMenuCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      ),
    );
  }


  void _showFrozenAlert(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
    final l10n = AppLocalizations.of(context)!;


    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
        newId = (100000 + (DateTime.now().microsecondsSinceEpoch % 900000))
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
                          style: TextStyle(
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
                        style: TextStyle(color: Colors.grey[500], fontSize: 11),
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
        gradient: LinearGradient(
          colors: [const Color(0xFF1B5E20), const Color(0xFF2E7D32)],
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
              border: Border(left: BorderSide(color: color, width: 4)),
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



