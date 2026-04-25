import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_constants.dart';
import '../models/observation.dart';
import '../models/public_sighting.dart';
import '../models/user_profile.dart';

/// All Firestore reads/writes live here.
class FirestoreService {
  FirestoreService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _db.collection(AppConstants.usersCollection).doc(uid);

  CollectionReference<Map<String, dynamic>> _observations(String uid) =>
      _userDoc(uid).collection(AppConstants.observationsCollection);

  CollectionReference<Map<String, dynamic>> _publicSightings() =>
      _db.collection(AppConstants.publicSightingsCollection);

  // ---- profile ----

  /// Watch the user's profile.
  Stream<UserProfile> profileStream(String uid) {
    return _userDoc(uid).snapshots().map((snap) {
      return snap.exists
          ? UserProfile.fromSnapshot(snap)
          : UserProfile.initial(uid);
    });
  }

  /// Get the profile, or make a fresh one if it doesn't exist yet.
  Future<UserProfile> ensureProfile(String uid) async {
    final ref = _userDoc(uid);
    final snap = await ref.get();
    if (snap.exists) return UserProfile.fromSnapshot(snap);
    final initial = UserProfile.initial(uid);
    await ref.set(initial.toMap());
    return initial;
  }

  Future<void> updateNickname({
    required String uid,
    required String nickname,
  }) async {
    await _userDoc(uid).set(
      {'nickname': nickname.trim()},
      SetOptions(merge: true),
    );
  }

  // ---- observations ----

  DocumentReference<Map<String, dynamic>> newObservationRef(String uid) =>
      _observations(uid).doc();

  /// Save one observation for this user.
  Future<void> saveObservation(Observation obs) async {
    await _observations(obs.userId).doc(obs.id).set(obs.toMap());
  }

  /// Watch this user's most recent observations.
  Stream<List<Observation>> recentObservations(String uid, {int limit = 20}) {
    return _observations(uid)
        .orderBy('capturedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((q) => q.docs.map(Observation.fromSnapshot).toList());
  }

  // ---- community ----

  /// Push a public copy with coords rounded to ~10 m.
  Future<void> publishSighting({
    required Observation obs,
    required String capturerNickname,
  }) async {
    if (!obs.hasLocation) return;
    final sighting = PublicSighting(
      id: obs.id,
      ownerUid: obs.userId,
      scientificName: obs.chosenSpecies.scientificName,
      commonName: obs.chosenSpecies.commonName,
      family: obs.chosenSpecies.family,
      rarity: obs.chosenSpecies.rarity,
      thumbUrl: obs.thumbUrl,
      photoUrl: obs.photoUrl,
      capturedAt: obs.capturedAt,
      latitude: _round(obs.latitude!),
      longitude: _round(obs.longitude!),
      capturerNickname: capturerNickname,
    );
    await _publicSightings().doc(sighting.id).set(sighting.toMap());
  }

  /// Take a sighting back off the community map.
  Future<void> retractSighting(String observationId) async {
    await _publicSightings().doc(observationId).delete();
  }

  /// Watch recent community sightings from everyone.
  Stream<List<PublicSighting>> recentPublicSightings({int limit = 200}) {
    return _publicSightings()
        .orderBy('capturedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((q) => q.docs.map(PublicSighting.fromSnapshot).toList());
  }

  static double _round(double v) {
    final f = math.pow(10, AppConstants.publicSightingPrecision).toDouble();
    return (v * f).round() / f;
  }

  /// Bump streak + totals after a save. Uses a transaction so two quick
  /// saves don't fight each other.
  Future<void> bumpStatsOnNewObservation({
    required String uid,
    required DateTime capturedAt,
  }) async {
    final ref = _userDoc(uid);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final current = snap.exists
          ? UserProfile.fromSnapshot(snap)
          : UserProfile.initial(uid);

      final last = current.lastObservationAt;
      var streak = current.streak;
      if (last == null) {
        streak = 1;
      } else {
        final dayDiff = DateTime(capturedAt.year, capturedAt.month, capturedAt.day)
            .difference(DateTime(last.year, last.month, last.day))
            .inDays;
        if (dayDiff == 0) {
          streak = current.streak.clamp(1, 1000);
        } else if (dayDiff == 1) {
          streak = current.streak + 1;
        } else {
          streak = 1;
        }
      }

      final badges = List<String>.from(current.badges);
      if (!badges.contains('first_bloom')) badges.add('first_bloom');
      if (streak >= 3 && !badges.contains('streak_3')) badges.add('streak_3');

      final updated = current.copyWith(
        streak: streak,
        totalObservations: current.totalObservations + 1,
        badges: badges,
        lastObservationAt: capturedAt,
      );
      tx.set(ref, updated.toMap());
    });
  }
}

final firestoreServiceProvider =
    Provider<FirestoreService>((_) => FirestoreService());

// autoDispose so signing out drops the old listeners
final userProfileProvider =
    StreamProvider.autoDispose.family<UserProfile, String>((ref, uid) {
  return ref.watch(firestoreServiceProvider).profileStream(uid);
});

final recentObservationsProvider =
    StreamProvider.autoDispose.family<List<Observation>, String>((ref, uid) {
  return ref.watch(firestoreServiceProvider).recentObservations(uid);
});

final recentPublicSightingsProvider =
    StreamProvider.autoDispose<List<PublicSighting>>((ref) {
  return ref.watch(firestoreServiceProvider).recentPublicSightings();
});
