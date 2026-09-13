import 'dart:convert';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_app/upload_controller.dart';
import 'package:my_app/controllers/auth_controller.dart';
import 'package:my_app/localization/app_translations.dart';
import 'package:my_app/product_detail.dart';
import 'package:my_app/chat_screen.dart';
import 'package:my_app/auction_detail_screen.dart';
import 'package:my_app/seller_profile_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_update_gate.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'signup_screen.dart';
import 'package:get/get.dart';
import 'package:flutter/foundation.dart';
import 'firebase_options.dart';

const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'order_channel',
  'ការកម្ម៉ង់ទំនិញថ្មី',
  description: 'ជូនដំណឹងដល់ម្ចាស់ហាងពេលមានភ្ញៀវកម្ម៉ង់',
  importance: Importance.max,
  playSound: true,
  sound: RawResourceAndroidNotificationSound('order_sound'),
);

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  }
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    if (kIsWeb) {
      await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
    }
  } catch (e) {
    debugPrint('Firebase init error: $e');
  }

  final languageController = await LanguageController.create();
  Get.put(languageController);
  Get.put(UploadController());
  final authController = Get.put(AuthController());
  await authController.checkLoginStatus();

  runApp(const MyApp());

  if (!kIsWeb) {
    try {
      await _setupMobileNotifications();
    } catch (e) {
      debugPrint('Notification setup error: $e');
    }
  }

  try {
    await _setupDeepLinks();
  } catch (e) {
    debugPrint('Deep link setup error: $e');
  }
}

Future<void> _setupMobileNotifications() async {
  const initializationSettings = InitializationSettings(
    android: AndroidInitializationSettings('ic_stat_sesan'),
    iOS: DarwinInitializationSettings(),
  );

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (response) {
      final payload = response.payload;
      if (payload == null || payload.isEmpty) return;
      try {
        final decoded = jsonDecode(payload);
        if (decoded is Map) {
          _handleNotificationData(Map<String, dynamic>.from(decoded));
        }
      } catch (e) {
        debugPrint('Notification payload error: $e');
      }
    },
  );

  final messaging = FirebaseMessaging.instance;
  await messaging.requestPermission(alert: true, badge: true, sound: true);
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await messaging.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );

  try {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getString('user_uid');
    const adminUid = 'WBdQVvrgEIPBTcgIlumu6bAZGUl2';
    if (uid == adminUid) {
      await messaging.subscribeToTopic('admin_orders');
    }
    await messaging.subscribeToTopic('all_users');
  } catch (e) {
    debugPrint('Subscribe to topic failed: $e');
  }

  FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'order_channel',
      'ការកម្ម៉ង់ទំនិញថ្មី',
      channelDescription: 'ជូនដំណឹងដល់ម្ចាស់ហាងពេលមានភ្ញៀវកម្ម៉ង់',
      importance: Importance.max,
      priority: Priority.high,
      icon: 'ic_stat_sesan',
      sound: RawResourceAndroidNotificationSound('order_sound'),
    );
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await flutterLocalNotificationsPlugin.show(
      notification.hashCode,
      notification.title ?? 'Sesan App',
      notification.body ?? '',
      details,
      payload: jsonEncode(message.data),
    );
  });

  FirebaseMessaging.onMessageOpenedApp.listen((message) {
    _handleNotificationData(message.data);
  });

  final initialMessage = await messaging.getInitialMessage();
  if (initialMessage != null) {
    Future.delayed(
      const Duration(milliseconds: 900),
      () => _handleNotificationData(initialMessage.data),
    );
  }
}

void _handleNotificationData(Map<String, dynamic> data) {
  final type = data['type']?.toString() ?? '';
  final productId =
      data['productId']?.toString() ?? data['product_id']?.toString() ?? '';

  Future.delayed(const Duration(milliseconds: 350), () {
    if (type == 'new_chat' || type == 'chat') {
      _navigateToChat(data);
    } else if ((type == 'auction_started' ||
            type == 'auction_approved' ||
            type == 'auction_approved_all' ||
            type == 'new_auction_pending') &&
        productId.isNotEmpty) {
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => AuctionDetailScreen(productId: productId),
        ),
      );
    } else if ((type == 'new_comment' ||
            type == 'comment_reply' ||
            type == 'new_rating') &&
        productId.isNotEmpty) {
      _navigateToProduct(productId);
    }
  });
}

Future<void> _navigateToChat(Map<String, dynamic> data) async {
  final senderId = data['senderId']?.toString() ?? '';
  if (senderId.isEmpty) return;

  final productId =
      data['productId']?.toString() ?? data['product_id']?.toString() ?? '';
  var productName = data['productName']?.toString() ?? '';
  var sellerId = data['sellerId']?.toString() ?? '';

  if (productId.isNotEmpty) {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('products')
          .doc(productId)
          .get();
      if (doc.exists) {
        final product = doc.data()!;
        productName = productName.isNotEmpty
            ? productName
            : (product['product_name']?.toString() ?? '');
        sellerId = sellerId.isNotEmpty
            ? sellerId
            : (product['seller_id']?.toString() ?? '');
      }
    } catch (e) {
      debugPrint('Load chat product error: $e');
    }
  }

  navigatorKey.currentState?.push(
    MaterialPageRoute(
      builder: (_) => ChatScreen(
        productId: productId,
        productName: productName,
        seller_id: sellerId.isNotEmpty ? sellerId : senderId,
        receiver_id: senderId,
      ),
    ),
  );
}

Future<void> _setupDeepLinks() async {
  if (kIsWeb) {
    final uri = Uri.base;
    if (uri.pathSegments.isNotEmpty) _handleDeepLink(uri);
    return;
  }

  final appLinks = AppLinks();
  try {
    final initialUri = await appLinks.getInitialLink();
    if (initialUri != null) _handleDeepLink(initialUri);
  } catch (e) {
    debugPrint('Initial link error: $e');
  }

  appLinks.uriLinkStream.listen((Uri uri) {
    _handleDeepLink(uri);
  });
}

void _handleDeepLink(Uri deepLink) {
  debugPrint('Deep Link received: $deepLink');
  final segments = deepLink.pathSegments;
  if (segments.isEmpty) return;

  Future.delayed(const Duration(milliseconds: 500), () {
    if (segments.contains('product')) {
      _navigateToProduct(segments.last);
    } else if (segments.contains('shop')) {
      _navigateToShop(segments.last);
    }
  });
}

Future<void> _navigateToProduct(String productId) async {
  try {
    final doc = await FirebaseFirestore.instance
        .collection('products')
        .doc(productId)
        .get();
    if (!doc.exists) return;

    final product = Map<String, dynamic>.from(doc.data()!);
    product['id'] = productId;
    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(product: product),
      ),
    );
  } catch (e) {
    debugPrint('Navigate to product error: $e');
  }
}

Future<void> _navigateToShop(String sellerId) async {
  try {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(sellerId)
        .get();
    if (!doc.exists) return;

    final userData = Map<String, dynamic>.from(doc.data()!);
    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => SellerProfileScreen(
          sellerId: sellerId,
          sellerName: (userData['name'] ?? 'មិនស្គាល់').toString(),
        ),
      ),
    );
  } catch (e) {
    debugPrint('Navigate to shop error: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Sesan Marketplace',
      translations: AppTranslations(),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('km', 'KH'),
        Locale('en', 'US'),
      ],
      locale: Get.find<LanguageController>().currentLocale,
      fallbackLocale: const Locale('km', 'KH'),
      theme: ThemeData(
        useMaterial3: true,
        primarySwatch: Colors.green,
        fontFamily: 'Siemreap',
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        platform: TargetPlatform.iOS,
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),
      home: const AppUpdateGate(child: AuthWrapper()),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(guestMode: false),
        '/home-guest': (context) => const HomeScreen(guestMode: true),
        '/signup': (context) => const SignUpScreen(),
      },
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  Widget? _cachedScreen;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<User?> _restoreFirebaseUser() async {
    final auth = FirebaseAuth.instance;
    final cachedUser = auth.currentUser;
    if (cachedUser != null) return cachedUser;

    try {
      return await auth
          .authStateChanges()
          .firstWhere((user) => user != null)
          .timeout(const Duration(seconds: 30));
    } catch (e) {
      debugPrint('Firebase session restore delayed at startup: $e');
      return auth.currentUser;
    }
  }

  Future<void> _checkAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUid = prefs.getString('user_uid');
    final savedLoggedIn = prefs.getBool('is_logged_in') ?? false;
    final isGuest = prefs.getBool('is_guest') ?? false;

    final firebaseUser = await _restoreFirebaseUser();
    if (!mounted) return;

    final authController = Get.find<AuthController>();

    if (firebaseUser != null) {
      if (savedUid != null &&
          savedUid.isNotEmpty &&
          savedUid != firebaseUser.uid) {
        await FirebaseAuth.instance.signOut();
        await prefs.setBool('is_logged_in', false);
        await prefs.remove('user_uid');
        authController.isLoggedIn = false;
        authController.isGuest = false;
        authController.userId = '';
        _cachedScreen = const LoginScreen();
      } else {
        await prefs.setString('user_uid', firebaseUser.uid);
        await prefs.setBool('is_logged_in', true);
        await prefs.setBool('is_guest', false);
        authController.isLoggedIn = true;
        authController.isGuest = false;
        authController.userId = firebaseUser.uid;
        _cachedScreen = const HomeScreen(guestMode: false);
      }
    } else if (savedLoggedIn && savedUid != null && savedUid.isNotEmpty) {
      // A slow Firebase restore must not log the user out on cold start.
      // Authenticated features independently wait for FirebaseAuth and can ask
      // for sign-in only if the Firebase session is genuinely unavailable.
      authController.isLoggedIn = true;
      authController.isGuest = false;
      authController.userId = savedUid;
      _cachedScreen = const HomeScreen(guestMode: false);
    } else if (isGuest) {
      authController.isLoggedIn = false;
      authController.isGuest = true;
      authController.userId = '';
      _cachedScreen = const HomeScreen(guestMode: true);
    } else {
      authController.isLoggedIn = false;
      authController.isGuest = false;
      authController.userId = '';
      _cachedScreen = const LoginScreen();
    }

    if (mounted) setState(() => _initialized = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return _cachedScreen!;
  }
}
