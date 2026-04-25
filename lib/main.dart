import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/services/notifications_service.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // try firebase, but don't crash if it's not set up yet
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } on Object catch (_) {
    debugPrint('[UrbanFlora] Firebase not configured yet — see README.');
  }

  // set up local notifications (used for rare bloom alerts)
  try {
    await NotificationsService().init();
  } on Object catch (e) {
    debugPrint('[UrbanFlora] notifications init failed: $e');
  }

  runApp(const ProviderScope(child: UrbanFloraApp()));
}
