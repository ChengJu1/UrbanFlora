/// App-wide constants.
class AppConstants {
  const AppConstants._();

  static const String plantNetEndpoint =
      'https://my-api.plantnet.org/v2/identify/the-plant-list';

  static const String openWeatherEndpoint =
      'https://api.openweathermap.org/data/2.5/weather';

  static const String usersCollection = 'users';
  static const String observationsCollection = 'observations';
  static const String publicSightingsCollection = 'public_sightings';

  // round coords to ~10 m for privacy
  static const int publicSightingPrecision = 4;

  // 10 km
  static const double communityRadiusMetres = 10000;

  static const String onboardedKey = 'has_onboarded_v1';
}
