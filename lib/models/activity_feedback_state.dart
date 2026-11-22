import 'confirmed_activity_feedback.dart';

/// Account-scoped receipt presentation. Beginning a switch clears synchronously.
class ActivityFeedbackState {
  int _generation = 0;
  String? _actor;
  ConfirmedActivityFeedback? feedback;
  String status = '登入後查看雲端活動確認';

  int begin(String? actor) {
    ++_generation;
    _actor = actor;
    feedback = null;
    status = actor == null ? '登入後查看雲端活動確認' : '正在讀取活動確認';
    return _generation;
  }

  bool isCurrent(int generation) => generation == _generation;

  void update(
    int generation, {
    String? id,
    Map<String, dynamic>? data,
    required bool fromCache,
    required bool pendingWrites,
  }) {
    if (!isCurrent(generation) || _actor == null) return;
    feedback = !pendingWrites && id != null && data != null
        ? ConfirmedActivityFeedback.parse(id, data, _actor!)
        : null;
    status = fromCache
        ? '快取活動確認，等待網路更新'
        : feedback == null
        ? '尚無可顯示的活動確認'
        : '僅顯示活動確認；獎勵以獎勵帳本為準';
  }

  void fail(int generation) {
    if (!isCurrent(generation)) return;
    feedback = null;
    status = '活動確認暫時無法讀取';
  }
}
