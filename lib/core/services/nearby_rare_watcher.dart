import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/public_sighting.dart';
import '../models/species.dart';
import 'auth_service.dart';
import 'firestore_service.dart';
import 'notifications_service.dart';

/// Watches the public sightings stream and pings the user when a new
/// rare or legendary plant shows up nearby. The first snapshot is treated
/// as old data, so we only notify for things that come in after.
class NearbyRareWatcher {
  NearbyRareWatcher({
    required this.firestore,
    required this.notifications,
    required this.uid,
  });

  final FirestoreService firestore;
  final NotificationsService notifications;
  final String uid;

  static const double _maxDistanceMeters = 10000; // 10 km radius
  static const String _notifiedKey = 'rare_notified_ids';

  StreamSubscription<List<PublicSighting>>? _sub;
  Position? _myPos;
  Set<String> _seenIds = <String>{};
  Set<String> _notifiedIds = <String>{};
  bool _firstReceived = false;

  Future<void> start() async {
    final prefs = await SharedPreferences.getInstance();
    _notifiedIds = prefs.getStringList(_notifiedKey)?.toSet() ?? <String>{};

    // best-effort: if location is off we still notify, just no distance
    try {
      final ok = await Geolocator.isLocationServiceEnabled();
      if (ok) {
        var perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.denied) {
          perm = await Geolocator.requestPermission();
        }
        if (perm == LocationPermission.always ||
            perm == LocationPermission.whileInUse) {
          _myPos = await Geolocator.getLastKnownPosition() ??
              await Geolocator.getCurrentPosition(
                locationSettings: const LocationSettings(
                  accuracy: LocationAccuracy.low,
                  timeLimit: Duration(seconds: 5),
                ),
              );
        }
      }
    } on Object catch (e) {
      debugPrint('[NearbyRareWatcher] location lookup failed: $e');
    }

    _sub = firestore.recentPublicSightings(limit: 50).listen(
      _onSnapshot,
      onError: (e) => debugPrint('[NearbyRareWatcher] stream error: $e'),
    );
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
  }

  void _onSnapshot(List<PublicSighting> sightings) {
    if (!_firstReceived) {
      _firstReceived = true;
      _seenIds = sightings.map((s) => s.id).toSet();
      return;
    }

    for (final s in sightings) {
      if (_seenIds.contains(s.id)) continue;
      _seenIds.add(s.id);
      _maybeNotify(s);
    }
  }

  Future<void> _maybeNotify(PublicSighting s) async {
    if (s.ownerUid == uid) return;
    if (_notifiedIds.contains(s.id)) return;
    if (s.rarity != Rarity.rare && s.rarity != Rarity.legendary) return;

    String distLabel = '';
    if (_myPos != null) {
      final m = Geolocator.distanceBetween(
        _myPos!.latitude,
        _myPos!.longitude,
        s.latitude,
        s.longitude,
      );
      if (m > _maxDistanceMeters) return;
      distLabel = m < 1000
          ? ' • ${m.round()} m away'
          : ' • ${(m / 1000).toStringAsFixed(1)} km away';
    }

    final tier = s.rarity == Rarity.legendary ? 'Legendary' : 'Rare';
    final commonName = s.commonName.isEmpty ? s.scientificName : s.commonName;
    await notifications.showRareBloom(
      id: s.id.hashCode & 0x7FFFFFFF, // positive 32-bit int
      title: '$tier bloom spotted nearby',
      body: '${s.capturerNickname} just found $commonName$distLabel',
    );

    _notifiedIds.add(s.id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_notifiedKey, _notifiedIds.toList());
  }
}

// Watcher provider — starts when the user signs in, stops on sign-out.
final nearbyRareWatcherProvider = Provider.autoDispose<NearbyRareWatcher?>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return null;

  final watcher = NearbyRareWatcher(
    firestore: ref.watch(firestoreServiceProvider),
    notifications: ref.watch(notificationsServiceProvider),
    uid: user.uid,
  );
  // fire and forget
  watcher.start();
  ref.onDispose(watcher.stop);
  return watcher;
});
