/// Reproduces the legacy 63-bit FNV-1a request hash on every Dart runtime.
///
/// The previous implementation used integer literals that Flutter Web could
/// not represent safely. BigInt preserves the exact legacy output, keeping
/// already-issued idempotency keys valid across an app upgrade.
String stableRequestHash(String canonicalValue) {
  var hash = BigInt.parse('cbf29ce484222325', radix: 16);
  final prime = BigInt.parse('100000001b3', radix: 16);
  final mask = (BigInt.one << 63) - BigInt.one;
  for (final codeUnit in canonicalValue.codeUnits) {
    hash ^= BigInt.from(codeUnit);
    hash = (hash * prime) & mask;
  }
  return hash.toRadixString(16);
}
