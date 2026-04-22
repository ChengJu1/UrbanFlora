import 'package:cloud_firestore/cloud_firestore.dart';

import 'species.dart';

/// A find shared to the community map. Coordinates are rounded to ~10 m.
class PublicSighting {
  const PublicSighting({
    required this.id,
    required this.ownerUid,
    required this.scientificName,
    required this.commonName,
    required this.family,
    required this.rarity,
    required this.thumbUrl,
    required this.photoUrl,
    required this.capturedAt,
    required this.latitude,
    required this.longitude,
    required this.capturerNickname,
  });

  final String id;
  final String ownerUid;
  final String scientificName;
  final String commonName;
  final String family;
  final Rarity rarity;
  final String thumbUrl;
  final String photoUrl;
  final DateTime capturedAt;
  final double latitude;
  final double longitude;
  final String capturerNickname;

  Map<String, dynamic> toMap() => {
        'ownerUid': ownerUid,
        'scientificName': scientificName,
        'commonName': commonName,
        'family': family,
        'rarity': rarity.index,
        'thumbUrl': thumbUrl,
        'photoUrl': photoUrl,
        'capturedAt': Timestamp.fromDate(capturedAt),
        'approxLat': latitude,
        'approxLng': longitude,
        'capturerNickname': capturerNickname,
      };

  factory PublicSighting.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snap,
  ) {
    final data = snap.data() ?? const <String, dynamic>{};
    final rarityIdx = (data['rarity'] as num?)?.toInt() ?? 0;
    return PublicSighting(
      id: snap.id,
      ownerUid: data['ownerUid'] as String? ?? '',
      scientificName: data['scientificName'] as String? ?? 'Unknown',
      commonName: data['commonName'] as String? ?? '',
      family: data['family'] as String? ?? '',
      rarity: Rarity.values[rarityIdx.clamp(0, Rarity.values.length - 1)],
      thumbUrl: data['thumbUrl'] as String? ?? '',
      photoUrl: data['photoUrl'] as String? ?? '',
      capturedAt:
          (data['capturedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      latitude: (data['approxLat'] as num?)?.toDouble() ?? 0,
      longitude: (data['approxLng'] as num?)?.toDouble() ?? 0,
      capturerNickname: data['capturerNickname'] as String? ?? 'Anonymous',
    );
  }
}
