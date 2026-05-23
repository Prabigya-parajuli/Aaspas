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
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
              'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
              'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyD3UWiaUVatCfSaLArAeu9Qh5mAyE88vVY',
    appId: '1:693049055577:android:d5bf66b734815eb3dcd448',
    messagingSenderId: '693049055577',
    projectId: 'aaspas-9d40e',
    storageBucket: 'aaspas-9d40e.firebasestorage.app',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyD3UWiaUVatCfSaLArAeu9Qh5mAyE88vVY',
    appId: '1:693049055577:web:abcdef1234567890',
    messagingSenderId: '693049055577',
    projectId: 'aaspas-9d40e',
    authDomain: 'aaspas-9d40e.firebaseapp.com',
    storageBucket: 'aaspas-9d40e.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyD3UWiaUVatCfSaLArAeu9Qh5mAyE88vVY',
    appId: '1:693049055577:ios:abcdef1234567890',
    messagingSenderId: '693049055577',
    projectId: 'aaspas-9d40e',
    storageBucket: 'aaspas-9d40e.firebasestorage.app',
    iosBundleId: 'com.example.aaspas',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyD3UWiaUVatCfSaLArAeu9Qh5mAyE88vVY',
    appId: '1:693049055577:macos:abcdef1234567890',
    messagingSenderId: '693049055577',
    projectId: 'aaspas-9d40e',
    storageBucket: 'aaspas-9d40e.firebasestorage.app',
    iosBundleId: 'com.example.aaspas',
  );
}