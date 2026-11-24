import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/models/cabin_sky.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('time of day follows the local clock', () {
    CabinTime at(int h) => CabinSky.timeOf(DateTime(2026, 11, 24, h, 30));
    expect(at(4), CabinTime.night);
    expect(at(5), CabinTime.dusk);
    expect(at(7), CabinTime.day);
    expect(at(16), CabinTime.day);
    expect(at(17), CabinTime.dusk);
    expect(at(19), CabinTime.night);
    expect(at(23), CabinTime.night);
  });

  test('WMO weather codes map to three looks', () {
    expect(CabinSky.weatherOf(0), CabinWeather.clear);
    expect(CabinSky.weatherOf(1), CabinWeather.clear);
    expect(CabinSky.weatherOf(3), CabinWeather.cloudy);
    expect(CabinSky.weatherOf(45), CabinWeather.cloudy);
    expect(CabinSky.weatherOf(61), CabinWeather.rain);
    expect(CabinSky.weatherOf(81), CabinWeather.rain);
    expect(CabinSky.weatherOf(95), CabinWeather.rain);
    expect(CabinSky.weatherOf(73), CabinWeather.cloudy); // snow: grey sky
    expect(CabinSky.weatherOf(null), CabinWeather.clear);
  });

  test('clear dusk keeps the painted window; others swap the view', () {
    expect(CabinSky.windowAsset(CabinTime.dusk, CabinWeather.clear), isNull);
    expect(
      CabinSky.windowAsset(CabinTime.night, CabinWeather.rain),
      'assets/home/window/window_night_rain.png',
    );
    expect(
      CabinSky.windowAsset(CabinTime.day, CabinWeather.clear),
      'assets/home/window/window_day_clear.png',
    );
  });

  test('forecast URL asks only for the current weather code', () {
    final city = CabinSky.cities.first;
    final uri = CabinSky.forecastUri(city);
    expect(uri.host, 'api.open-meteo.com');
    expect(uri.queryParameters['current'], 'weather_code');
    expect(uri.queryParameters['latitude'], city.latitude.toString());
  });

  test('companion has a rainy-day line', () {
    expect(CabinSky.companionLine(CabinWeather.rain), '下雨天最適合讀書了');
    expect(CabinSky.companionLine(CabinWeather.clear), isNull);
  });

  group('controller', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('weather is off until a city is chosen', () async {
      var calls = 0;
      final c = CabinSkyController(
        fetch: (_) async {
          calls++;
          return 61;
        },
        clock: () => DateTime(2026, 11, 24, 10),
      );
      await c.refresh();
      expect(calls, 0);
      expect(c.weather, CabinWeather.clear);
      expect(c.time, CabinTime.day);
    });

    test('choosing a city fetches and remembers it', () async {
      final c = CabinSkyController(
        fetch: (_) async => 61,
        clock: () => DateTime(2026, 11, 24, 21),
      );
      await c.chooseCity(CabinSky.cities[1]);
      expect(c.city?.name, CabinSky.cities[1].name);
      expect(c.weather, CabinWeather.rain);
      expect(c.time, CabinTime.night);

      final again = CabinSkyController(
        fetch: (_) async => 0,
        clock: () => DateTime(2026, 11, 24, 21),
      );
      await again.refresh();
      expect(again.city?.name, CabinSky.cities[1].name);
      // Fetched under 30 minutes ago: the saved weather is reused.
      expect(again.weather, CabinWeather.rain);
    });

    test('a failed fetch keeps the last known weather', () async {
      var fail = false;
      final c = CabinSkyController(
        fetch: (_) async => fail ? throw Exception('offline') : 3,
        clock: () => DateTime(2026, 11, 24, 10),
      );
      await c.chooseCity(CabinSky.cities.first);
      expect(c.weather, CabinWeather.cloudy);
      fail = true;
      await c.refresh(force: true);
      expect(c.weather, CabinWeather.cloudy);
    });

    test('turning weather off forgets the city', () async {
      final c = CabinSkyController(
        fetch: (_) async => 61,
        clock: () => DateTime(2026, 11, 24, 10),
      );
      await c.chooseCity(CabinSky.cities.first);
      await c.chooseCity(null);
      expect(c.city, isNull);
      expect(c.weather, CabinWeather.clear);
    });
  });

  testWidgets('night tint only appears at night', (tester) async {
    expect(CabinSky.roomTint(CabinTime.day), isNull);
    expect(CabinSky.roomTint(CabinTime.night), isA<Color>());
  });
}
