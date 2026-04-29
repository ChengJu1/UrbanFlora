import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/services/notifications_service.dart';
import 'core/services/species_catalog.dart';
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

  // load the bundled species seed so rarity lookups are ready before
  // the first frame; if the asset is missing for any reason we just keep
  // running with an empty catalog (every species will fall back to common).
  try {
    await SpeciesCatalog.load();
  } on Object catch (e) {
    debugPrint('[UrbanFlora] species catalog load failed: $e');
  }

  runApp(const ProviderScope(child: UrbanFloraApp()));
}
