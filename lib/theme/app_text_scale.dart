/// App-wide text size. Phones used to shrink text to 90–96%, which read too
/// small; now small phones stay at 100% and roomier screens get a gentle
/// bump. The user's system font size still applies, clamped so layouts hold.
double appTextScale({
  required double width,
  required double height,
  required double system,
}) {
  final double base = width <= 400 || height <= 760
      ? 1.0
      : width <= 430
      ? 1.04
      : 1.08;
  return base * system.clamp(0.85, 1.15);
}
