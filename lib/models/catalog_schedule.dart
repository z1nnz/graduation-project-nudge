/// Availability uses a half-open window: start <= now < end, matching Cloud.
class CatalogSchedule {
  const CatalogSchedule({this.startSeconds, this.endSeconds});

  final int? startSeconds;
  final int? endSeconds;

  bool activeAt(int nowSeconds) =>
      (startSeconds == null || startSeconds! <= nowSeconds) &&
      (endSeconds == null || nowSeconds < endSeconds!);

  int? nextBoundaryAfter(int nowSeconds) {
    final candidates = [
      startSeconds,
      endSeconds,
    ].whereType<int>().where((value) => value > nowSeconds).toList()..sort();
    return candidates.isEmpty ? null : candidates.first;
  }
}
