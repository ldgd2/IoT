// File generated / customized for Firebase project: si2parcial-9e9e9
// ignore_for_file: type=lint
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
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyC_MockApiKeyForWebsi2parcial9e9e9',
    appId: '1:76539049876:web:si2parcial9e9e9',
    messagingSenderId: '76539049876',
    projectId: 'si2parcial-9e9e9',
    authDomain: 'si2parcial-9e9e9.firebaseapp.com',
    storageBucket: 'si2parcial-9e9e9.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyC6YfEqFoSld9rscnMv_BLYUT2d65r6jro',
    appId: '1:76539049876:android:670d903356b8dcdd51c181',
    messagingSenderId: '76539049876',
    projectId: 'si2parcial-9e9e9',
    storageBucket: 'si2parcial-9e9e9.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyC_MockApiKeyForIOSsi2parcial9e9e9',
    appId: '1:76539049876:ios:si2parcial9e9e9',
    messagingSenderId: '76539049876',
    projectId: 'si2parcial-9e9e9',
    storageBucket: 'si2parcial-9e9e9.firebasestorage.app',
    iosBundleId: 'com.example.bthapp',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyC_MockApiKeyForMacOSsi2parcial',
    appId: '1:76539049876:ios:si2parcial9e9e9',
    messagingSenderId: '76539049876',
    projectId: 'si2parcial-9e9e9',
    storageBucket: 'si2parcial-9e9e9.firebasestorage.app',
    iosBundleId: 'com.example.bthapp',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyC_MockApiKeyForWindowssi2parcial',
    appId: '1:76539049876:web:si2parcial9e9e9',
    messagingSenderId: '76539049876',
    projectId: 'si2parcial-9e9e9',
    authDomain: 'si2parcial-9e9e9.firebaseapp.com',
    storageBucket: 'si2parcial-9e9e9.firebasestorage.app',
  );
}
