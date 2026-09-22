import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:my_app/add_pre_order_screen.dart';
import 'package:my_app/add_wanted_screen.dart';
import 'package:my_app/admin_confirm.dart';
import 'package:my_app/chat_list_screen.dart';
import 'package:my_app/auction_main_screen.dart';
import 'package:my_app/notification_service.dart';
import 'package:my_app/pre_order_grid_view.dart';
import 'package:my_app/smart_scan_screen.dart';
import 'product_search_v51.dart';
import 'package:my_app/upload_controller.dart';
import 'package:my_app/user_notification_list.dart';
import 'package:my_app/wanted_grid_view.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'add_product.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';
import 'cart_screen.dart';
import 'package:firebase_auth/firebase_auth.dart'; // ផាសជួរនេះចូលដើម្បីបាត់ក្រហម
import 'auction_add_screen.dart';
import 'chat_list_screen.dart';
import 'product_list.dart';
import 'product_list_v51_screen.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart'; // ថែមតែមួយជួរនេះ
import 'package:firebase_messaging/firebase_messaging.dart'; // ថែមជួរនេះ
import 'l10n/app_localizations.dart';

class HomeScreen extends StatefulWidget {
  final bool guestMode; // បន្ថែមនេះ
  const HomeScreen({super.key, this.guestMode = false}); // កែនេះ

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _t(String km, String en) =>
      Localizations.localeOf(context).languageCode == 'en' ? en : km;

  int _currentIndex = 0;
  String _selectedCategory = "ទាំងអស់";
  String _searchQuery = "";

  final TextEditingController _homeSearchController = TextEditingController();
  ProductSearchV51Controller? _searchAiController;

  ProductSearchV51Controller get _searchAi =>
      _searchAiController ??= ProductSearchV51Controller(
        context,
        onStateChanged: () {
          if (mounted) setState(() {});
        },
      );

  Future<void> _applyAiSearch(String value) async {
    if (!mounted || value.trim().isEmpty) return;

    final primary = value.split('|').first.trim();
    _homeSearchController.text = primary;
    _homeSearchController.selection = TextSelection.collapsed(
      offset: primary.length,
    );

    setState(() => _searchQuery = value.toLowerCase());
  }

  Future<void> _imageSearch() async {
    final result = await _searchAi.searchByImage();
    if (result != null) {
      await _applyAiSearch(result);
    }
    if (mounted) setState(() {});
  }

  Future<void> _smartScanSearch() async {
    if (_searchAiController?.busy == true) return;

    final image = await Navigator.push<XFile?>(
      context,
      MaterialPageRoute(builder: (_) => const SmartScanScreen()),
    );
    if (image == null || !mounted) return;

    final result = await _searchAi.searchSelectedImage(image);
    if (result != null) {
      await _applyAiSearch(result);
    }
    if (mounted) setState(() {});
  }

  Future<void> _voiceSearch() async {
    final ai = _searchAi;
    if (ai.recording || ai.busy) return;

    await ai.startVoice(onResult: _applyAiSearch);
    if (mounted) setState(() {});
  }

  // ១. ថែមជួរនេះដើម្បីឱ្យស្គាល់ UID (បាត់ក្រហម build)
  String? _loggedUid;
  String? name;
  bool _isAuthReady = false;

  @override
  void initState() {
    super.initState();

    loadUser();

    if (!widget.guestMode) {
      NotificationService.updateSellerToken();
      _subscribeAdminTopic();
      _checkAndRequestPermission();
    }
  }

  Future<void> loadUser() async {
    try {
      // Explicit guest mode is already a resolved auth state.
      if (widget.guestMode) {
        if (mounted) {
          setState(() {
            _loggedUid = null;
            _isAuthReady = true;
          });
        }
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_uid');

      // No saved account: resolved as guest. Do not redirect from Home.
      if (userId == null || userId.isEmpty) {
        if (mounted) {
          setState(() {
            _loggedUid = null;
            _isAuthReady = true;
          });
        }
        return;
      }

      _setupFcmToken(userId);

      // While this network read is pending, Cart/Chat/Account/+ stay visually
      // normal but taps are ignored so a slow connection cannot misclassify
      // a signed-in user as a guest and send them to Login.
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (!mounted) return;

      if (doc.exists) {
        setState(() {
          name = doc.data()?['name']?.toString();
          _loggedUid = userId;
          _isAuthReady = true;
        });
      } else {
        setState(() {
          _loggedUid = null;
          _isAuthReady = true;
        });
      }
    } catch (e) {
      debugPrint('Home auth check failed: $e');
      if (mounted) {
        // The check has finished (even if it failed). Release the silent lock.
        // Keep any saved UID if available rather than forcing a false guest.
        final prefs = await SharedPreferences.getInstance();
        final savedUid = prefs.getString('user_uid');
        setState(() {
          _loggedUid =
              (savedUid != null && savedUid.isNotEmpty) ? savedUid : null;
          _isAuthReady = true;
        });
      }
    }
  }

  // 🎯 បន្ថែម Function នេះដើម្បីទាញ FCM Token និងរក្សាទុកទៅ Firestore
  Future<void> _setupFcmToken(String userId) async {
    try {
      FirebaseMessaging messaging = FirebaseMessaging.instance;

      // ១. សុំសិទ្ធិបង្ហាញ Notification (សម្រាប់ Android 13+ និង iOS)
      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        // ២. ទាញយក Token ពី Firebase
        String? token = await messaging.getToken();

        if (token != null) {
          print("🔥 FCM Token: $token");

          // ៣. រក្សាទុក Token ទៅក្នុង Collection 'users' តាមរយៈ userId
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .update({
                'fcmToken': token,
                'lastUpdate':
                    FieldValue.serverTimestamp(), // ថែមម៉ោងដែលវា Update
              });
        }
      }
    } catch (e) {
      print("❌ Error setting up FCM Token: $e");
    }
  }

  // ១. បន្ថែម Function សម្រាប់រាប់ចំនួន Noti ដែលមិនទាន់អាន
  Future<int> _getUnreadCount(List<QueryDocumentSnapshot> docs) async {
    final prefs = await SharedPreferences.getInstance();
    // យកពេលវេលាដែលចុចមើលចុងក្រោយ (បើអត់មាន យក 0)
    int lastRead = prefs.getInt('last_read_noti') ?? 0;

    int unread = 0;
    for (var doc in docs) {
      // បង្ការបញ្ហា Timestamp null
      var data = doc.data() as Map<String, dynamic>;
      Timestamp? time = data['created_at'] as Timestamp?;

      if (time != null && time.millisecondsSinceEpoch > lastRead) {
        unread++;
      }
    }
    return unread;
  }

  // ២. បន្ថែម Function សម្រាប់សម្គាល់ថាបានអានហើយ
  void _markAsRead() async {
    final prefs = await SharedPreferences.getInstance();
    // រក្សាទុកពេលវេលាបច្ចុប្បន្ន ជាម៉ោងដែលបានអានចុងក្រោយ
    await prefs.setInt('last_read_noti', DateTime.now().millisecondsSinceEpoch);

    // Refresh UI ឱ្យលេខ Noti ក្រហមបាត់ទៅ
    if (mounted) {
      setState(() {});
    }
  }

  // ៣. បន្ថែម Function នេះដើម្បីទាញទិន្នន័យពី SharedPrefs
  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _loggedUid = prefs.getString('user_uid');
    });
  }

  void _subscribeAdminTopic() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.uid == "លេខ_ID_របស់មេ") {
      await FirebaseMessaging.instance.subscribeToTopic('admin_orders');
    }
  }

  String _categoryLabel(String name) {
    switch (name) {
      case 'ទាំងអស់':
        return _t('ទាំងអស់', 'All');
      case 'គ្រឿងចក្រ':
        return _t('គ្រឿងចក្រ', 'Machinery');
      case 'សម្ភារៈកសិកម្ម':
        return _t('សម្ភារៈកសិកម្ម', 'Farm supplies');
      case 'ពូជដំណាំ':
        return _t('ពូជដំណាំ', 'Crop seeds');
      case 'ពូជសត្វចិញ្ចឹម':
        return _t('ពូជសត្វចិញ្ចឹម', 'Livestock');
      case 'ជីនិងថ្នាំ':
        return _t('ជីនិងថ្នាំ', 'Fertilizer & chemicals');
      case 'បន្លែផ្លែឈើ':
        return _t('បន្លែផ្លែឈើ', 'Fruit & vegetables');
      case 'ត្រីសាច់':
        return _t('ត្រីសាច់', 'Fish & meat');
      case 'សេវាកម្ម':
        return _t('សេវាកម្ម', 'Services');
      case 'ផ្សេងៗ':
        return _t('ផ្សេងៗ', 'Other');
      default:
        return name;
    }
  }

  final List<Map<String, dynamic>> categories = [
    {'name': 'ទាំងអស់', 'icon': Icons.apps, 'isIcon': true},
    {
      'name': 'គ្រឿងចក្រ',
      'image': 'assets/ic_machinery.png.jpg',
      'isIcon': false,
    },
    {
      'name': 'សម្ភារៈកសិកម្ម',
      'image': 'assets/ic_tools.png.jpg',
      'isIcon': false,
    },
    {'name': 'ពូជដំណាំ', 'image': 'assets/ic_seeds.png.jpg', 'isIcon': false},
    {
      'name': 'ពូជសត្វចិញ្ចឹម',
      'image': 'assets/ic_livestock.png.jpg',
      'isIcon': false,
    },
    {
      'name': 'ជីនិងថ្នាំ',
      'image': 'assets/ic_fertilizer.png.jpg',
      'isIcon': false,
    },
    {
      'name': 'បន្លែផ្លែឈើ',
      'image': 'assets/ic_vegetables.jpg',
      'isIcon': false,
    },
    {'name': 'ត្រីសាច់', 'image': 'assets/ic_meat.png.jpg', 'isIcon': false},
    {'name': 'សេវាកម្ម', 'image': 'assets/ic_service.jpg', 'isIcon': false},
    {'name': 'ផ្សេងៗ', 'icon': Icons.grid_view, 'isIcon': true},
  ];

  @override
  void dispose() {
    _homeSearchController.dispose();
    _searchAiController?.dispose();
    super.dispose();
  }

  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final UploadController uploadController = Get.find<UploadController>();
    final user = FirebaseAuth.instance.currentUser;

    // ៤. ឆែកតាម _loggedUid វិញដើម្បីកុំឱ្យចូលជាភ្ញៀវ
    bool isGuest = _loggedUid == null || _loggedUid!.isEmpty;

    return Scaffold(
      appBar: _currentIndex == 0
          ? AppBar(
              backgroundColor: Colors.green[700],
              automaticallyImplyLeading: false,
              // 💡 កែមកប្រើ titleSpacing ទាបដើម្បីឱ្យ Search Bar រីកបានវែង
              titleSpacing: 10,
              title: Row(
                children: [
                  // ១. Logo សេសាន (បង្ហាញតែលើអេក្រង់ធំ)
                  if (MediaQuery.of(context).size.width > 600)
                    const Padding(
                      padding: EdgeInsets.only(right: 10),
                      child: Text(
                        "SESAN",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ),

                  // ២. ប្រអប់ Search Bar (ប្រើ Expanded ដើម្បីឱ្យវារីកពេញលំហដែលនៅសល់)
                  Expanded(
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: TextField(
                        controller: _homeSearchController,
                        onChanged: (value) {
                          setState(() => _searchQuery = value.trim());
                        },
                        decoration: InputDecoration(
                          hintText: l10n.searchProducts,
                          hintStyle: const TextStyle(
                            fontFamily: 'Siemreap',
                            fontSize: 13,
                          ),
                          prefixIcon: const Icon(Icons.search, size: 20),
                          suffixIconConstraints:
                              const BoxConstraints.tightFor(
                            width: 96,
                            height: 48,
                          ),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 48,
                                height: 48,
                                child: InkResponse(
                                  radius: 24,
                                  onTap: _searchAiController?.busy == true
                                      ? null
                                      : _smartScanSearch,
                                  child: Center(
                                    child: _searchAiController?.busy == true
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.center_focus_strong_rounded,
                                            color: Colors.blue,
                                            size: 20,
                                          ),
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 48,
                                height: 48,
                                child: InkResponse(
                                  radius: 24,
                                  onTap:
                                      (_searchAiController?.busy == true ||
                                          _searchAiController?.recording == true)
                                      ? null
                                      : _voiceSearch,
                                  child: Center(
                                    child: Icon(
                                      Icons.mic_rounded,
                                      color:
                                          _searchAiController?.recording == true
                                              ? Colors.red
                                              : Colors.green,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 9,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // ៣. Icon ជូនដំណឹង (ដាក់នៅកៀនខាងស្តាំបំផុត និងបង្រួមចន្លោះ)
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 52,
                        height: 52,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints.tightFor(
                            width: 52,
                            height: 52,
                          ),
                          icon: const Icon(
                            Icons.notifications_none_rounded,
                            color: Colors.white,
                            size: 26,
                          ),
                          onPressed: () {
                            _markAsRead(); // ✅ សម្គាល់ថាអានរួច
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => UserNotificationScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                      // 🎯 ផ្នែករាប់លេខ Noti ក្រហម
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('announcements')
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const SizedBox();
                          return FutureBuilder<int>(
                            future: _getUnreadCount(snapshot.data!.docs),
                            builder: (context, countSnapshot) {
                              int count = countSnapshot.data ?? 0;
                              if (count == 0) return const SizedBox();
                              return Positioned(
                                right: 0,
                                top: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 16,
                                    minHeight: 16,
                                  ),
                                  child: Text(
                                    '$count',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            )
          : null,
      body: Stack(
        // 🎯 ប្រើ Stack ដើម្បីឱ្យវាជាន់ពីលើគ្នា
        children: [
          IndexedStack(
            // កូដចាស់របស់មេ
            index: _currentIndex,
            children: [
              _buildMainHome(),
              const CartScreen(),
              AddProductPage(productId: null),
              ChatListScreen(),
              const ProfileScreen(),
            ],
          ),

          // 🎯 ផាសដុំកូដ Obx (ជំហានទី ២) ត្រង់នេះ
          Obx(() {
            return uploadController.uploadProgress.value > 0 &&
                    uploadController.uploadProgress.value < 1.0
                ? Positioned(
                    // ឱ្យវាអណ្ដែតនៅខាងលើបង្អស់
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      color: Colors.blue.shade50,
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.cloud_upload,
                                color: Colors.blue,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                '${_t('កំពុងបង្ហោះទំនិញ...', 'Uploading product...')} ${(uploadController.uploadProgress.value * 100).toInt()}%',
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          LinearProgressIndicator(
                            value: uploadController.uploadProgress.value,
                            backgroundColor: Colors.grey.shade300,
                            color: Colors.blue,
                          ),
                        ],
                      ),
                    ),
                  )
                : const SizedBox.shrink();
          }),
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navBtn(Icons.home, 0, isGuest), // ថែម isGuest
            _navBtn(Icons.shopping_cart_outlined, 1, isGuest), // ថែម isGuest
            const SizedBox(width: 40),
            _navBtn(Icons.chat, 3, isGuest), // ថែម isGuest
            _navBtn(Icons.person, 4, isGuest), // ថែម isGuest
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (!_isAuthReady) {
            // Keep the button looking normal, but ignore taps until auth is known.
            return;
          }

          // ២. កែសម្រួលការឆែកត្រង់ប៊ូតុង (+) ផុសលក់
          if (isGuest) {
            _showLoginRequiredDialog(
              context,
              _t('ដើម្បីផុសលក់ទំនិញបាន', 'to post a product'),
            );
          } else {
            setState(() => _currentIndex = 2);
          }
        },
        backgroundColor: Colors.green,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  // ៣. បង្កើត Dialog សម្រាប់ដេញភ្ញៀវទៅ Login (ដាក់នៅខាងក្រោម build)
  void _showLoginRequiredDialog(BuildContext context, String actionText) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_t('សូមចូលប្រើប្រាស់', 'Sign in required')),
        content: Text(
          _t(
            '$actionText មេត្រូវចូលប្រើប្រាស់គណនីជាមុនសិន។',
            'Please sign in $actionText.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              _t('មើលសិន', 'Not now'),
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/login');
            },
            child: Text(
              _t('ទៅ Login', 'Go to sign in'),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _navBtn(IconData icon, int index, bool isGuest) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    // ១. កំណត់ឈ្មោះ Label តាម index (រក្សាកូដដើមរបស់មេ)
    String label = "";
    switch (index) {
      case 0:
        label = _t('ទំព័រដើម', 'Home');
        break;
      case 1:
        label = _t('កន្ត្រក', 'Cart');
        break;
      case 3:
        label = _t('ឆាត', 'Chat');
        break;
      case 4:
        label = _t('គណនី', 'Account');
        break;
    }

    return InkWell(
      onTap: () {
        if (!_isAuthReady) {
          // Auth state is still resolving: silently ignore the tap.
          return;
        }

        // បើមិនទាន់ Login ហើយចុចប៊ូតុងផ្សេងក្រៅពីទំព័រដើម ឱ្យលោត Dialog
        if (index != 0 && isGuest) {
          _showLoginRequiredDialog(
            context,
            _t('ដើម្បីប្រើប្រាស់មុខងារនេះ', 'to use this feature'),
          );
        } else {
          setState(() => _currentIndex = index);
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ២. ឆែកមើល បើជាប៊ូតុង "ឆាត" (Index 3) ឱ្យវាបង្ហាញលេខក្រហម Notification
          index == 3
              ? StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(currentUserId)
                      .snapshots(),
                  builder: (context, snapshot) {
                    int totalUnread = 0;
                    if (snapshot.hasData && snapshot.data!.exists) {
                      var data = snapshot.data!.data() as Map<String, dynamic>;
                      totalUnread = data['unreadCount'] ?? 0;
                    }

                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(
                          icon,
                          color: _currentIndex == index
                              ? Colors.green
                              : Colors.grey,
                        ),
                        // បង្ហាញរង្វង់ក្រហមតែពេលមានសារមិនទាន់អាន (totalUnread > 0)
                        if (totalUnread > 0)
                          Positioned(
                            right: -5,
                            top: -5,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 16,
                                minHeight: 16,
                              ),
                              child: Center(
                                child: Text(
                                  '$totalUnread',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                )
              // ៣. បើមិនមែនប៊ូតុងឆាតទេ បង្ហាញ Icon ធម្មតា
              : Icon(
                  icon,
                  color: _currentIndex == index ? Colors.green : Colors.grey,
                ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: _currentIndex == index ? Colors.green : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainHome() {
    return DefaultTabController(
      length: 3,
      child: Builder(
        builder: (context) {
          final TabController tabController = DefaultTabController.of(context);

          return Stack(
            children: [
              // 💡 ប្រើ NestedScrollView ជំនួស CustomScrollView ដើម្បីដោះស្រាយបញ្ហា Tab បាត់ទំនិញ
              NestedScrollView(
                headerSliverBuilder: (context, innerBoxIsScrolled) {
                  return [
                    SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // --- ១. Banner ---
                          AspectRatio(
                            // Android 51 banner source is 1280x405.
                            // Keep the exact ratio so the whole image is visible.
                            aspectRatio: 1280 / 405,
                            child: SizedBox(
                              width: double.infinity,
                              child: Image.asset(
                                'assets/sesan_banner.png.jpg',
                                width: double.infinity,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),

                          // --- ២. Categories (កែសម្រួលថ្មី) ---
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                              vertical: 8.0,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              // រុញអក្សរទៅឆ្វេង ប៊ូតុងទៅស្តាំ
                              children: [
                                Text(
                                  _t('ប្រភេទផលិតផល', 'Product categories'),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Siemreap',
                                  ),
                                ),

                                // 🎯 ប៊ូតុងសម្រាប់ចូលទៅកាន់អេក្រង់ដេញថ្លៃ
                                GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const AuctionMainScreen(),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 7,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors
                                          .amber
                                          .shade600, // ប្ដូរពីបៃតងទៅមាស
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.amber.withOpacity(
                                            0.3,
                                          ), // ប្ដូរស្រមោលឲ្យត្រូវពណ៌មាស
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.trending_up_rounded,
                                          size: 14,
                                          color: Colors.white,
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          _t('ចូលដេញថ្លៃ', 'Auctions'),
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12,
                                            fontFamily: 'Siemreap',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _buildCategoryGrid(),

                          const Divider(thickness: 5, color: Color(0xFFF5F5F5)),

                          // --- ៣. TabBar ---
                          TabBar(
                            labelColor: Colors.green,
                            unselectedLabelColor: Colors.grey,
                            indicatorColor: Colors.green,
                            indicatorWeight: 3,
                            tabs: [
                              Tab(
                                child: Text(
                                  _t('ទំនិញថ្មីៗ', 'New products'),
                                  style: TextStyle(
                                    fontFamily: 'Siemreap',
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Tab(
                                child: Text(
                                  _t('លក់មុន', 'Pre-order'),
                                  style: TextStyle(
                                    fontFamily: 'Siemreap',
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Tab(
                                child: Text(
                                  _t('ប្រកាសទិញ', 'Wanted'),
                                  style: TextStyle(
                                    fontFamily: 'Siemreap',
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ];
                },
                // 🎯 កន្លែងនេះគឺសំខាន់បំផុត វានឹងរីកតាមចំនួនទំនិញដោយស្វ័យប្រវត្តិ
                body: TabBarView(
                  children: [
                    ProductGridView(
                      category: _selectedCategory,
                      searchQuery: _searchQuery,
                      isHome: true,
                    ),
                    PreOrderGridView(searchQuery: _searchQuery), // ✅ ថែម
                    WantedGridView(searchQuery: _searchQuery), // ✅ ថែម
                  ],
                ),
              ),

              // --- ៤. ប៊ូតុងអណ្ដែត (បង្ហាញតែពេលនៅ Tab ប្រកាសទិញ) ---
              // --- ៤. ប៊ូតុងអណ្ដែត (បង្ហាញតែពេលនៅ Tab ប្រកាសទិញ) ---
              AnimatedBuilder(
                animation: tabController,
                builder: (context, child) {
                  return tabController.index == 1
                      ? Positioned(
                          bottom: 20,
                          right: 20,
                          child: FloatingActionButton.extended(
                            heroTag: "wantedBtn",
                            // ✅ កែទីនេះ - ប្រើ SharedPreferences ជំនួស FirebaseAuth
                            onPressed: () async {
                              // ១. ឆែកមើលថាបាន Login ឬនៅ (ប្រើ SharedPreferences)
                              final prefs =
                                  await SharedPreferences.getInstance();
                              String uid = prefs.getString('user_uid') ?? '';

                              if (uid.isEmpty) {
                                _showLoginRequiredDialog(
                                  context,
                                  _t(
                                    'ដើម្បីប្រកាសទិញបាន',
                                    'to post a wanted request',
                                  ),
                                );
                              } else {
                                // ២. បើ Login ហើយ ឱ្យវាបាញ់ទៅ Screen ផុស
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const AddWantedScreen(),
                                  ),
                                );
                              }
                            },
                            label: Text(
                              _t('ប្រកាសទិញ', 'Wanted'),
                              style: const TextStyle(fontFamily: 'Siemreap'),
                            ),
                            icon: const Icon(Icons.campaign),
                            backgroundColor: Colors.blue[700],
                          ),
                        )
                      : const SizedBox.shrink();
                },
              ),
              // --- ប៊ូតុងអណ្ដែតសម្រាប់ "លក់មុន" ---
              AnimatedBuilder(
                animation: tabController,
                builder: (context, child) {
                  if (tabController.index == 2) {
                    return _buildFloatingBtn(
                      _t('ប្រកាសទិញ', 'Wanted'),
                      Icons.campaign,
                      Colors.blue[700]!,
                      const AddWantedScreen(),
                    );
                  } else if (tabController.index == 1) {
                    // 🎯 បង្ហាញប៊ូតុង "ចុះឈ្មោះលក់មុន" ពេលនៅ Tab ទី ៣
                    return _buildFloatingBtn(
                      _t('ចុះឈ្មោះលក់មុន', 'Add pre-order'),
                      Icons.timer_outlined,
                      Colors.orange[800]!,
                      const AddPreOrderScreen(),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
          );
        },
      ),
    );
  }

  // 🎯 បង្កើត function ជំនួយដើម្បីកុំឱ្យកូដវែងពេក
  Widget _buildFloatingBtn(
    String label,
    IconData icon,
    Color color,
    Widget nextScreen,
  ) {
    return Positioned(
      bottom: 20,
      right: 20,
      child: FloatingActionButton.extended(
        onPressed: () async {
          final prefs = await SharedPreferences.getInstance();
          if ((prefs.getString('user_uid') ?? '').isEmpty) {
            _showLoginRequiredDialog(context, "ដើម្បី$labelបាន");
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => nextScreen),
            );
          }
        },
        label: Text(label, style: const TextStyle(fontFamily: 'Siemreap')),
        icon: Icon(icon),
        backgroundColor: color,
      ),
    );
  }

  Widget _buildCategoryGrid() {
    // 🎯 ១. ឆែកមើលទំហំអេក្រង់ជាមុន
    double screenWidth = MediaQuery.of(context).size.width;
    bool isDesktop = screenWidth > 800;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        // 🎯 ២. បើលើ Web ឱ្យចេញ ១០ គ្រាប់ជួរដេកតែម្ដង បើលើ App ឱ្យចេញ ៥ គ្រាប់ដដែល
        crossAxisCount: isDesktop ? 10 : 5,
        childAspectRatio: isDesktop ? 1.0 : 0.8, // លើ Web ឱ្យវាចេញរាងការ៉េស្អាត
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        var item = categories[index];
        return InkWell(
          onTap: () {
            Navigator.push(
              context,
              CupertinoPageRoute(
                builder: (context) =>
                    ProductListV51Screen(category: item['name']),
              ),
            );
          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center, // ឱ្យនៅចំកណ្ដាល
            children: [
              Container(
                // 🎯 ៣. បើលើ Web ឱ្យ Icon រីកធំដល់ ៦០ បើលើ App យក ៤៥ ដដែល
                height: isDesktop ? 65 : 45,
                width: isDesktop ? 65 : 45,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(15), // រាងមូលជាងមុនបន្តិច
                ),
                child: item['isIcon']
                    ? Icon(
                        item['icon'],
                        color: Colors.green,
                        size: isDesktop ? 35 : 24,
                      )
                    : Padding(
                        padding: const EdgeInsets.all(
                          8.0,
                        ), // ថែម Padding ឱ្យរូបភាពនៅកណ្ដាលស្អាត
                        child: Image.asset(item['image'], fit: BoxFit.contain),
                      ),
              ),
              const SizedBox(height: 8),
              Text(
                _categoryLabel(item['name']),
                style: TextStyle(
                  fontSize: isDesktop
                      ? 13
                      : 10, // លើ Web ឱ្យអក្សរធំជាងមុនបន្តិច
                  fontWeight: isDesktop ? FontWeight.w500 : FontWeight.normal,
                  color: Colors.black,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }

  // ✅ ដាក់កូដនេះនៅទីនេះ (ក្នុង class _HomeScreenState)
  void _checkAndRequestPermission() async {
    final prefs = await SharedPreferences.getInstance();
    final bool hasShownDialog =
        prefs.getBool('has_shown_notification_dialog') ?? false;

    if (hasShownDialog) return;

    var status = await Permission.notification.status;
    if (status.isDenied || status.isPermanentlyDenied) {
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Text(_t('បើកការជូនដំណឹង', 'Enable notifications')),
            content: Text(
              "ដើម្បីទទួលបានសារកម្ម៉ង់ភ្លាមៗ សូមមេចុច 'បើក' រួច Switch លើពាក្យ 'Allow notifications' ផង!",
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  prefs.setBool('has_shown_notification_dialog', true);
                },
                child: Text(_t('ក្រោយមក', 'Later')),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  prefs.setBool('has_shown_notification_dialog', true);
                  await openAppSettings();
                },
                child: Text(_t('ទៅបើកឥឡូវនេះ', 'Open settings')),
              ),
            ],
          ),
        );
      }
    }
  }
}
