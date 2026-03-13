import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:geolocator/geolocator.dart';

/// Lat / lon plus a reverse-geocoded street address.
class GeoFix {
  const GeoFix({required this.latitude, required this.longitude, this.address});
  final double latitude;
  final double longitude;
  final String? address;
}

/// Wraps geolocator + geocoding into one easy "get me a fix" call.
class LocationService {
  /// Returns the current GPS fix with address, or null on any failure.
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

    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 8),
      ),
    );

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
