import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Firebase configuration for schoolconnect-ad414.
///
/// Generated from google-services.json (Android) and GoogleService-Info.plist (iOS).
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCgtiv_2QpmLceuMT-rg-dgKVoO4M3VT_U',
    appId: '1:155845572567:android:161c511c5735d90211fd92',
    messagingSenderId: '155845572567',
    projectId: 'schoolconnect-ad414',
    storageBucket: 'schoolconnect-ad414.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAf7dexjmfqSFL6bSMSdTcGDIYe49ovhYs',
    appId: '1:155845572567:ios:3fe5af788e42192b11fd92',
    messagingSenderId: '155845572567',
    projectId: 'schoolconnect-ad414',
    storageBucket: 'schoolconnect-ad414.firebasestorage.app',
    iosBundleId: 'com.ranbrosglobal.schoolconnect',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyAf7dexjmfqSFL6bSMSdTcGDIYe49ovhYs',
    appId: '1:155845572567:ios:3fe5af788e42192b11fd92',
    messagingSenderId: '155845572567',
    projectId: 'schoolconnect-ad414',
    storageBucket: 'schoolconnect-ad414.firebasestorage.app',
    iosBundleId: 'com.ranbrosglobal.schoolconnect',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'YOUR_WEB_API_KEY',
    appId: 'YOUR_WEB_APP_ID',
    messagingSenderId: '155845572567',
    projectId: 'schoolconnect-ad414',
    storageBucket: 'schoolconnect-ad414.firebasestorage.app',
    authDomain: 'schoolconnect-ad414.firebaseapp.com',
  );
}
