import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/api_keys.dart';
import '../constants/app_constants.dart';
import '../models/weather_snapshot.dart';

/// Looks up current weather from OpenWeatherMap by lat/lon.
class WeatherService {
  WeatherService({Dio? dio}) : _dio = dio ?? Dio();
  final Dio _dio;

  /// Returns null if no API key or the request fails — weather is optional.
  Future<WeatherSnapshot?> currentWeather({
    required double lat,
    required double lon,
  }) async {
    if (ApiKeys.openWeather == 'YOUR_OPENWEATHER_API_KEY') {
      return null;
    }
    try {
      final resp = await _dio.get<Map<String, dynamic>>(
        AppConstants.openWeatherEndpoint,
        queryParameters: {
          'lat': lat,
          'lon': lon,
          'units': 'metric',
          'appid': ApiKeys.openWeather,
        },
      );
      final data = resp.data;
      if (data == null) return null;
      return WeatherSnapshot.fromOpenWeather(data);
    } on DioException {
      return null;
    }
  }
}

final weatherServiceProvider = Provider<WeatherService>((_) => WeatherService());
