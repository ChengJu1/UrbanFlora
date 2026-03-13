import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Streams compass heading in degrees (0 = North).
class CompassService {
  /// Empty stream on devices without a magnetometer.
  Stream<double?> heading() {
    final events = FlutterCompass.events;
    if (events == null) {
      return const Stream<double?>.empty();
    }
    return events.map((e) => e.heading);
  }
}

final compassServiceProvider = Provider<CompassService>((_) => CompassService());

final compassHeadingProvider = StreamProvider.autoDispose<double?>((ref) {
  return ref.watch(compassServiceProvider).heading();
});
