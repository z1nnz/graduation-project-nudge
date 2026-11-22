class ConfirmedActivityFeedback {
  const ConfirmedActivityFeedback(this.receiptId, this.label);
  final String receiptId;
  final String label;

  static ConfirmedActivityFeedback? parse(
    String id,
    Map<String, dynamic> data,
    String userId,
  ) {
    const labels = {
      'focus': '專注',
      'study': '學習',
      'exercise': '運動',
      'steps': '步數',
      'sleep': '睡眠',
      'task': '任務',
      'custom': '活動',
    };
    final label = labels[data['activityType']];
    final metric = data['acceptedMetric'];
    final verifiedAt = data['verifiedAt'];
    final verifiedDate = verifiedAt is String
        ? DateTime.tryParse(verifiedAt)
        : null;
    if (id.isEmpty ||
        userId.isEmpty ||
        data['receiptId'] != id ||
        data['actorUserId'] != userId ||
        label == null ||
        metric is! num ||
        !metric.isFinite ||
        metric < 0 ||
        verifiedAt is! String ||
        verifiedDate == null ||
        verifiedDate.toUtc().toIso8601String() != verifiedAt) {
      return null;
    }
    return ConfirmedActivityFeedback(id, '$label紀錄已由雲端確認');
  }
}
