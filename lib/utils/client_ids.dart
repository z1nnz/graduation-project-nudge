import 'dart:math';

final Random _secureRandom = Random.secure();

/// Returns `<prefix>_<utc microseconds>_<8 hex chars>`.
///
/// Timestamps alone are not unique: Windows and Web clocks tick in
/// milliseconds or coarser, so two ids created in the same event loop turn
/// collide. Cloud idempotency treats a repeated request id as a replay, so a
/// collision silently drops the second request. The random suffix prevents
/// that while keeping ids sortable by time and within the Cloud pattern
/// `^[A-Za-z0-9_-]{8,128}$`.
String newClientId(String prefix, {DateTime? at}) {
  final stamp = (at ?? DateTime.now()).toUtc().microsecondsSinceEpoch;
  final nonce = List<String>.generate(
    4,
    (_) => _secureRandom.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
  return '${prefix}_${stamp}_$nonce';
}
