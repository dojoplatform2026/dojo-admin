import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }

    throw UnsupportedError(
      'Firebase options are configured only for Web.',
    );
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBgKva52MnBMmclLW_g3D6yHYfDrxqqmiU',
    appId: '1:177087606182:web:3e3695044e6670e6683367',
    messagingSenderId: '177087606182',
    projectId: 'dojo-platform-b68a3',
    authDomain: 'dojo-platform-b68a3.firebaseapp.com',
    storageBucket: 'dojo-platform-b68a3.firebasestorage.app',
    measurementId: 'G-LMY82ERE15',
  );
}
