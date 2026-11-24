import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

enum CabinTime { day, dusk, night }

enum CabinWeather { clear, cloudy, rain }

class CabinCity {
  const CabinCity(this.name, this.latitude, this.longitude);
  final String name;
  final double latitude;
  final double longitude;
}

/// What the cabin window shows: the real time of day, and (only if the user
/// picks a city) the real weather. No device location is ever read.
class CabinSky {
  CabinSky._();

  static const cities = [
    CabinCity('台北', 25.04, 121.56),
    CabinCity('新北', 25.01, 121.46),
    CabinCity('桃園', 24.99, 121.30),
    CabinCity('新竹', 24.80, 120.97),
    CabinCity('台中', 24.15, 120.67),
    CabinCity('嘉義', 23.48, 120.45),
    CabinCity('台南', 22.99, 120.21),
    CabinCity('高雄', 22.63, 120.30),
    CabinCity('宜蘭', 24.75, 121.75),
    CabinCity('花蓮', 23.99, 121.60),
    CabinCity('台東', 22.76, 121.14),
  ];

  static CabinTime timeOf(DateTime now) {
    final h = now.hour;
    if (h >= 7 && h < 17) return CabinTime.day;
    if ((h >= 17 && h < 19) || (h >= 5 && h < 7)) return CabinTime.dusk;
    return CabinTime.night;
  }

  /// WMO weather interpretation codes, as returned by Open-Meteo.
  static CabinWeather weatherOf(int? code) {
    if (code == null || code <= 1) return CabinWeather.clear;
    if ((code >= 51 && code <= 67) ||
        (code >= 80 && code <= 82) ||
        code >= 95) {
      return CabinWeather.rain;
    }
    return CabinWeather.cloudy;
  }

  /// Null keeps the painted (clear dusk) view.
  static String? windowAsset(CabinTime time, CabinWeather weather) {
    if (time == CabinTime.dusk && weather == CabinWeather.clear) return null;
    return 'assets/home/window/window_${time.name}_${weather.name}.png';
  }

  static Uri forecastUri(CabinCity city) =>
      Uri.https('api.open-meteo.com', '/v1/forecast', {
        'latitude': city.latitude.toString(),
        'longitude': city.longitude.toString(),
        'current': 'weather_code',
      });

  static String? companionLine(CabinWeather weather) => switch (weather) {
    CabinWeather.rain => '下雨天最適合讀書了',
    _ => null,
  };

  /// Soft dusk/night light over the room; null in daytime.
  static Color? roomTint(CabinTime time) => switch (time) {
    CabinTime.day => null,
    CabinTime.dusk => const Color(0x14FF9A5A),
    CabinTime.night => const Color(0x2E141038),
  };

  /// Window glass, as a fraction of the room image.
  static const windowRect = Rect.fromLTWH(0.35556, 0.09851, 0.3, 0.16732);
}

typedef WeatherFetch = Future<int?> Function(CabinCity city);

Future<int?> _openMeteo(CabinCity city) async {
  final response = await http
      .get(CabinSky.forecastUri(city))
      .timeout(const Duration(seconds: 8));
  if (response.statusCode != 200) {
    throw Exception('weather ${response.statusCode}');
  }
  final data = jsonDecode(response.body) as Map<String, dynamic>;
  return ((data['current'] as Map?)?['weather_code'] as num?)?.toInt();
}

class CabinSkyController extends ChangeNotifier {
  CabinSkyController({WeatherFetch? fetch, DateTime Function()? clock})
    : _fetch = fetch ?? _openMeteo,
      _clock = clock ?? DateTime.now;

  static final instance = CabinSkyController();

  static const _cityKey = 'cabin_weather_city';
  static const _codeKey = 'cabin_weather_code';
  static const _atKey = 'cabin_weather_at';
  static const _maxAge = Duration(minutes: 30);

  final WeatherFetch _fetch;
  final DateTime Function() _clock;
  CabinCity? _city;
  CabinWeather _weather = CabinWeather.clear;
  bool _loaded = false;

  CabinCity? get city => _city;
  CabinWeather get weather => _city == null ? CabinWeather.clear : _weather;
  CabinTime get time => CabinSky.timeOf(_clock());

  Future<void> _load(SharedPreferences prefs) async {
    if (_loaded) return;
    _loaded = true;
    final name = prefs.getString(_cityKey);
    _city = CabinSky.cities.where((c) => c.name == name).firstOrNull;
    _weather = CabinSky.weatherOf(prefs.getInt(_codeKey));
  }

  Future<void> refresh({bool force = false}) async {
    final prefs = await SharedPreferences.getInstance();
    await _load(prefs);
    final city = _city;
    if (city == null) {
      notifyListeners();
      return;
    }
    final at = DateTime.tryParse(prefs.getString(_atKey) ?? '');
    if (!force && at != null && _clock().difference(at) < _maxAge) {
      notifyListeners();
      return;
    }
    try {
      final code = await _fetch(city);
      _weather = CabinSky.weatherOf(code);
      if (code != null) await prefs.setInt(_codeKey, code);
      await prefs.setString(_atKey, _clock().toIso8601String());
    } catch (_) {
      // Offline: keep the last known weather.
    }
    notifyListeners();
  }

  Future<void> chooseCity(CabinCity? city) async {
    final prefs = await SharedPreferences.getInstance();
    await _load(prefs);
    _city = city;
    if (city == null) {
      await prefs.remove(_cityKey);
      await prefs.remove(_codeKey);
      await prefs.remove(_atKey);
      _weather = CabinWeather.clear;
      notifyListeners();
      return;
    }
    await prefs.setString(_cityKey, city.name);
    await refresh(force: true);
  }
}
