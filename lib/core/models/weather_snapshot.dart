/// Weather at the moment a photo was taken (from OpenWeatherMap).
class WeatherSnapshot {
  const WeatherSnapshot({
    required this.tempC,
    required this.description,
    required this.icon,
    required this.humidity,
  });

  final double tempC;
  final String description;
  final String icon;
  final int humidity;

  factory WeatherSnapshot.fromOpenWeather(Map<String, dynamic> json) {
    final main = (json['main'] as Map<String, dynamic>?) ?? const {};
    final weatherList = (json['weather'] as List?) ?? const [];
    final w = weatherList.isNotEmpty ? weatherList.first as Map<String, dynamic> : const {};
    return WeatherSnapshot(
      tempC: (main['temp'] as num?)?.toDouble() ?? 0,
      description: w['description'] as String? ?? 'unknown',
      icon: w['icon'] as String? ?? '01d',
      humidity: (main['humidity'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'tempC': tempC,
        'description': description,
        'icon': icon,
        'humidity': humidity,
      };

  factory WeatherSnapshot.fromMap(Map<String, dynamic> map) => WeatherSnapshot(
        tempC: (map['tempC'] as num?)?.toDouble() ?? 0,
        description: map['description'] as String? ?? '',
        icon: map['icon'] as String? ?? '01d',
        humidity: (map['humidity'] as num?)?.toInt() ?? 0,
      );
}
