(function(root) {
  'use strict';
  function parse(id, data, userId) {
    const labels = { focus: '專注', study: '學習', exercise: '運動', steps: '步數', sleep: '睡眠', task: '任務', custom: '活動' };
    if (!data || !id || !userId || data.receiptId !== id || data.actorUserId !== userId ||
        !Object.hasOwn(labels, data.activityType) || typeof data.acceptedMetric !== 'number' ||
        !Number.isFinite(data.acceptedMetric) || data.acceptedMetric < 0 ||
        typeof data.verifiedAt !== 'string' || !Number.isFinite(Date.parse(data.verifiedAt))) return null;
    return { receiptId: id, label: `${labels[data.activityType]}紀錄已由雲端確認` };
  }
  if (typeof module === 'object' && module.exports) module.exports = { parse };
  else root.NudgeConfirmedActivityFeedback = { parse };
})(typeof globalThis !== 'undefined' ? globalThis : this);
