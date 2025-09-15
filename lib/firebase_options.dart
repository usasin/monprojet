import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;      // <— on renvoie la config web ici
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        throw UnsupportedError('Platform not supported');
      default:
        throw UnsupportedError('Platform not supported');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBA3GpdMujbxxea9QzKYosJrtF1n6OAKX4',
    appId: '1:163745254135:android:362ce9ce98edddcd3461f2',
    messagingSenderId: '163745254135',
    projectId: 'quiz-commercial',
    databaseURL: 'https://quiz-commercial-default-rtdb.europe-west1.firebasedatabase.app',
    storageBucket: 'quiz-commercial.appspot.com',
  );

static const FirebaseOptions ios = FirebaseOptions(
  apiKey: 'AIzaSyCWE5qSeyBDrZIXWiNrt_-I4GAyQk20F6M', // <-- même que le plist
  appId: '1:163745254135:ios:f1efd3b30f315ed73461f2',
  messagingSenderId: '163745254135',
  projectId: 'quiz-commercial',
  databaseURL: 'https://quiz-commercial-default-rtdb.europe-west1.firebasedatabase.app',
  storageBucket: 'quiz-commercial.appspot.com',
  androidClientId: '163745254135-80hm56i1bkil3a3rl5ls6p6miks7cu6l.apps.googleusercontent.com',
  iosClientId: '163745254135-3q1q92pq15663uc2gkg4nqvfk8jkjdfp.apps.googleusercontent.com', // <-- même que le plist
  iosBundleId: 'com.ainego.aiProspectGps',
);


  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyA6BxVTOmWxDIX3UzaA6GFhIa-YbdCvbmo',
    appId: '1:163745254135:web:16c8cc8ed0b40f703461f2',
    messagingSenderId: '163745254135',
    projectId: 'quiz-commercial',
    authDomain: 'quiz-commercial.firebaseapp.com',
    databaseURL: 'https://quiz-commercial-default-rtdb.europe-west1.firebasedatabase.app',
    storageBucket: 'quiz-commercial.appspot.com',
    measurementId: 'G-GWKFE275LR',
  );

}
