import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:my_app/upload_controller.dart';
import 'package:my_app/controllers/auth_controller.dart';
import 'package:my_app/localization/app_translations.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
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

  if (!kIsWeb) {
    try {
      await _setupMobileNotifications();
    } catch (e) {
      debugPrint('Notification setup error: $e');
    }
  }
  runApp(const MyApp());
}

Future<void> _setupMobileNotifications() async {
  final messaging = FirebaseMessaging.instance;
  await messaging.requestPermission(alert: true, badge: true, sound: true);
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );

  try {
    await messaging.subscribeToTopic('admin_orders');
    await messaging.subscribeToTopic('all_users');
  } catch (e) {
    debugPrint('Subscribe to topic failed: $e');
  }

  FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
    final RemoteNotification? notification = message.notification;

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
      0,
      notification?.title ?? 'Sesan App',
      notification?.body ?? '',
      details,
      payload: message.data.toString(),
    );
  });
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
      home: const AuthWrapper(),
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

  Future<void> _checkAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUid = prefs.getString('user_uid');
    final savedLoggedIn = prefs.getBool('is_logged_in') ?? false;
    final isGuest = prefs.getBool('is_guest') ?? false;

    User? firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null && !kIsWeb) {
      try {
        firebaseUser = await FirebaseAuth.instance
            .authStateChanges()
            .where((user) => user != null)
            .cast<User>()
            .first
            .timeout(const Duration(seconds: 2));
      } catch (_) {
        firebaseUser = FirebaseAuth.instance.currentUser;
      }
    }

    if (!mounted) return;
    final authController = Get.find<AuthController>();

    if (firebaseUser != null) {
      await prefs.setString('user_uid', firebaseUser.uid);
      await prefs.setBool('is_logged_in', true);
      await prefs.setBool('is_guest', false);
      authController.isLoggedIn = true;
      authController.isGuest = false;
      authController.userId = firebaseUser.uid;
      _cachedScreen = const HomeScreen(guestMode: false);
    } else if (savedLoggedIn && savedUid != null && savedUid.isNotEmpty) {
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
