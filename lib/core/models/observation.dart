import 'package:cloud_firestore/cloud_firestore.dart';

import 'species.dart';
import 'weather_snapshot.dart';

/// One photo + identification result the user saved to their codex.
class Observation {
  const Observation({
    required this.id,
    required this.userId,
    required this.photoUrl,
    required this.thumbUrl,
    required this.capturedAt,
    required this.candidates,
    required this.chosenSpecies,
    this.latitude,
    this.longitude,
    this.address,
    this.heading,
    this.weather,
    this.notes = '',
  });

  final String id;
  final String userId;
  final String photoUrl;
  final String thumbUrl;
  final DateTime capturedAt;
  final List<SpeciesCandidate> candidates;
  final SpeciesCandidate chosenSpecies;
  final double? latitude;
  final double? longitude;
  final String? address;

  // 0 = north
  final double? heading;
  final WeatherSnapshot? weather;
  final String notes;

  bool get hasLocation => latitude != null && longitude != null;

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'photoUrl': photoUrl,
        'thumbUrl': thumbUrl,
        'capturedAt': Timestamp.fromDate(capturedAt),
        'candidates': candidates.map((c) => c.toMap()).toList(),
        'chosenSpecies': chosenSpecies.toMap(),
        'latitude': latitude,
        'longitude': longitude,
        'address': address,
        'heading': heading,
        'weather': weather?.toMap(),
        'notes': notes,
      };

  factory Observation.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snap) {
    final data = snap.data() ?? const <String, dynamic>{};
    return Observation(
      id: snap.id,
      userId: data['userId'] as String? ?? '',
      photoUrl: data['photoUrl'] as String? ?? '',
      thumbUrl: data['thumbUrl'] as String? ?? '',
      capturedAt:
          (data['capturedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      candidates: ((data['candidates'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(SpeciesCandidate.fromMap)
          .toList(),
      chosenSpecies: SpeciesCandidate.fromMap(
        (data['chosenSpecies'] as Map<String, dynamic>?) ?? const {},
      ),
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      address: data['address'] as String?,
      heading: (data['heading'] as num?)?.toDouble(),
      weather: data['weather'] is Map<String, dynamic>
          ? WeatherSnapshot.fromMap(data['weather'] as Map<String, dynamic>)
          : null,
      notes: data['notes'] as String? ?? '',
    );
  }
}
