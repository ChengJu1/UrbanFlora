import '../../core/services/location_service.dart';

/// Bundle of data passed from the capture screen to the identification screen.
class IdentificationArgs {
  const IdentificationArgs({
    required this.imagePath,
    required this.capturedAt,
    this.fix,
    this.heading,
  });

  final String imagePath;
  final DateTime capturedAt;
  final GeoFix? fix;
  final double? heading;
}
