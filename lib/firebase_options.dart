import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        return android;
    }
  }

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDLsDlVcQY9ZIb-MjHjwYG-hwikWQ1sXwc',
    appId: '1:220834653903:ios:7fdc09b89f188a716a39ba',
    messagingSenderId: '220834653903',
    projectId: 'sesan-my-app',
    storageBucket: 'sesan-my-app.firebasestorage.app',
    iosBundleId: 'sesan.agri.app', // ✅ កែត្រង់នេះ!
    iosClientId: '220834653903-mq8ch6u003cotj74f5nqvfer4of6f6qs.apps.googleusercontent.com',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDLsDlVcQY9ZIb-MjHjwYG-hwikWQ1sXwc',
    appId: '1:220834653903:android:7fdc09b89f188a716a39ba',
    messagingSenderId: '220834653903',
    projectId: 'sesan-my-app',
    storageBucket: 'sesan-my-app.firebasestorage.app',
    androidClientId: '220834653903-386rmkiuvdnaqokp7o77v64fp09htiva.apps.googleusercontent.com',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDLsDlVcQY9ZIb-MjHjwYG-hwikWQ1sXwc',
    appId: '1:220834653903:web:7fdc09b89f188a716a39ba',
    messagingSenderId: '220834653903',
    projectId: 'sesan-my-app',
    storageBucket: 'sesan-my-app.firebasestorage.app',
  );
}