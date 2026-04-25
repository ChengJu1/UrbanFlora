import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:geolocator/geolocator.dart';

/// Lat / lon plus a street address from reverse geocoding.
class GeoFix {
  const GeoFix({required this.latitude, required this.longitude, this.address});
  final double latitude;
  final double longitude;
  final String? address;
}

/// Small helper around geolocator + geocoding.
class LocationService {
  /// Get the current location + address, or null if anything goes wrong.
  Future<GeoFix?> currentFix() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) return null;

    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      return null;
    }

    Position? pos;
    try {
      pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
    } on Object {
      // gps failed (often happens indoors), try the last known position
      try {
        pos = await Geolocator.getLastKnownPosition();
      } on Object {
        pos = null;
      }
    }
    if (pos == null) return null;

    String? address;
    try {
      final placemarks = await geo.placemarkFromCoordinates(
        pos.latitude,
        pos.longitude,
      );
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        address = [
          p.thoroughfare,
          p.subLocality,
          p.locality,
          p.country,
        ].where((e) => e != null && e.isNotEmpty).join(', ');
      }
    } on Object {
      // best-effort
    }

    return GeoFix(
      latitude: pos.latitude,
      longitude: pos.longitude,
      address: address,
    );
  }
}

final locationServiceProvider =
    Provider<LocationService>((_) => LocationService());
