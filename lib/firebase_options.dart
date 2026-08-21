// File generated for Emtaz-Matrouh / Matrouh Internship Web App
// DO NOT put private server credentials (such as service account private keys) here.
// The fields below are standard public client configuration identifiers for Firebase Web SDK.
//
// PUBLIC CLIENT IDENTIFIERS:
// - apiKey, appId, messagingSenderId, projectId, authDomain, storageBucket, measurementId
// - webVapidKey (Public VAPID key used for browser push subscription)
//
// NEVER EXPOSE ON CLIENT:
// - Firebase Service Account JSON (service-account.json)
// - Private Keys / RSA Private Certificates
// - FCM Legacy Server Keys / OAuth2 Refresh Tokens with admin scopes

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

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
      default:
        return web;
    }
  }

  /// Web App: "Matrouh Internship" | Project: "Emtaz-Matrouh"
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyARdhGJLdx0svHtzA4AlKCNuswy2L0KwSA',
    appId: '1:261034289906:web:006eff87282e76483cbe6b',
    messagingSenderId: '261034289906',
    projectId: 'emtaz-matrouh',
    authDomain: 'emtaz-matrouh.firebaseapp.com',
    storageBucket: 'emtaz-matrouh.firebasestorage.app',
    measurementId: 'G-PRB2CXXCYS',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyARdhGJLdx0svHtzA4AlKCNuswy2L0KwSA',
    appId: '1:261034289906:android:006eff87282e76483cbe6b',
    messagingSenderId: '261034289906',
    projectId: 'emtaz-matrouh',
    storageBucket: 'emtaz-matrouh.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyARdhGJLdx0svHtzA4AlKCNuswy2L0KwSA',
    appId: '1:261034289906:ios:006eff87282e76483cbe6b',
    messagingSenderId: '261034289906',
    projectId: 'emtaz-matrouh',
    storageBucket: 'emtaz-matrouh.firebasestorage.app',
    iosBundleId: 'com.matrouh.nurse',
  );

  /// Real Web Push VAPID Public Key from Firebase Console
  static const String webVapidKey =
      'BChJJ8oMm2eeCgbWQLwndilwlJ010hWJWgp1Cp_1Oh-Q69S3Rn104bslY0jpvh_3n_Z9_syMkpwuHCk0GA1nNNI';
}
