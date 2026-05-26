import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBUQn-TicYCZhfZW0kWkXJfpjZCfctOFfI',
    appId: '1:640634426800:android:157a8224355d4b8a4bf275',
    messagingSenderId: '640634426800',
    projectId: 'moma-f8916',
    storageBucket: 'moma-f8916.firebasestorage.app',
  );
}
