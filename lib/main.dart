import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:my_app/upload_controller.dart';
import 'package:my_app/controllers/auth_controller.dart';
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
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // ✅ លុប setPersistence ចេញ (មិនចាំបាច់ ព្រោះ Firebase Auth រក្សា session ដោយស្វ័យប្រវត្តិ)
  } catch (e) {
    debugPrint("Firebase init error: $e");
  }

  Get.put(UploadController());
  final authController = Get.put(AuthController());
  await authController.checkLoginStatus();

// ✅ ហៅ setup notifications តែនៅពេលមិនមែន Web
  if (!kIsWeb) {
    // រុំក្នុង try-catch ដើម្បីកុំឲ្យ App គាំងបើមាន error (ឧ. Free Account)
    try {
      await _setupMobileNotifications();
    } catch (e) {
      debugPrint("Notification setup error (Free Account likely): $e");
    }
  }

  runApp(const MyApp());
}

// បំបែក Function នេះចេញដើម្បីកុំឱ្យកូដធំពេក
Future<void> _setupMobileNotifications() async {
  FirebaseMessaging messaging = FirebaseMessaging.instance;
  await messaging.requestPermission(alert: true, badge: true, sound: true);
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );

  // Subscribe ទៅកាន់ Topic
  // ប្រសិនបើអ្នកកំពុងប្រើ Free Account, subscribeToTopic នឹងបរាជ័យ
  // ប៉ុន្តែវាមិនប៉ះពាល់ដល់មុខងារដទៃទេ
  try {
    await messaging.subscribeToTopic('admin_orders');
    await messaging.subscribeToTopic('all_users');
  } catch (e) {
    debugPrint("Subscribe to topic failed (Free Account): $e");
  }

  FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
    final RemoteNotification? notification = message.notification;

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
    AndroidNotificationDetails(
      'order_channel',
      'ការកម្ម៉ង់ទំនិញថ្មី',
      channelDescription: 'ជូនដំណឹងដល់ម្ចាស់ហាងពេលមានភ្ញៀវកម្ម៉ង់',
      importance: Importance.max,
      priority: Priority.high,
      icon: 'ic_stat_sesan',
      sound: RawResourceAndroidNotificationSound('order_sound'),
    );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
    DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );await flutterLocalNotificationsPlugin.show(
      0,
      notification?.title ?? 'គ្មានចំណងជើង',
      notification?.body ?? 'គ្មានខ្លឹមសារ',
      platformChannelSpecifics,
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
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('km', 'KH')],
      locale: const Locale('km', 'KH'),
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
      // ✅ FIXED: ប្រើ Widget ធម្មតាជំនួស Obx ដើម្បីចៀសវាង loop
      home: const AuthWrapper(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(guestMode: false),
        '/home-guest': (context) =>
        const HomeScreen(guestMode: true), // ✅ បន្ថែម
        '/signup': (context) => const SignUpScreen(),
      },
    );
  }
}


// ✅ បន្ថែម Widget នេះ (ដាក់ក្នុង main.dart ឬ file ផ្សេង)
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
    final uid = prefs.getString('user_uid');
    final isGuest = prefs.getBool('is_guest') ?? false;


    // ✅ កុំ set AuthController state នៅទីនេះ
    // ទុកតែជា local variable
    final bool loggedIn = uid != null && uid.isNotEmpty;
    final bool guest = isGuest;


    if (mounted) {
      setState(() {
        if (loggedIn) {
          _cachedScreen = const HomeScreen(guestMode: false);
        } else if (guest) {
          _cachedScreen = const HomeScreen(guestMode: true);
        } else {
          _cachedScreen = const LoginScreen();
        }
        _initialized = true;
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return _cachedScreen!;
  }
}



