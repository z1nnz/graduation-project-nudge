import 'package:shared_preferences/shared_preferences.dart';

/// Remembers on this device that the first-visit cabin tour was finished or
/// skipped, so it only plays once.
class CabinTourMemory {
  static const _key = 'cabin_tour_seen_v1';

  static Future<bool> seen() async =>
      (await SharedPreferences.getInstance()).getBool(_key) ?? false;

  static Future<void> markSeen() async =>
      (await SharedPreferences.getInstance()).setBool(_key, true);
}
