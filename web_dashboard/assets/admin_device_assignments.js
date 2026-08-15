(function attachAdminDeviceAssignments(root, factory) {
  const api = factory();

  if (typeof module === 'object' && module.exports) {
    module.exports = api;
  }

  root.NudgeAdminDeviceAssignments = api;
})(typeof globalThis !== 'undefined' ? globalThis : this, function createAdminDeviceAssignments() {
  const DEVICE_PATTERN = /^nudge-[A-Za-z0-9._-]{2,90}$/;
  const IDENTIFIER_PATTERN = /^[A-Za-z0-9][A-Za-z0-9._-]{1,95}$/;
  const REQUEST_PATTERN = /^[A-Za-z0-9_-]{8,128}$/;

  function text(value) {
    return String(value == null ? '' : value).trim();
  }

  function roomIds(value) {
    const source = Array.isArray(value) ? value : text(value).split(/[\s,]+/);
    return source.map(text).filter(Boolean);
  }

  function validateDeviceAssignmentDraft(draft) {
    const source = draft || {};
    const errors = [];
    const action = text(source.action);
    const rooms = roomIds(source.allowedRoomIds);
    if (!['assign', 'revoke'].includes(action)) {
      errors.push('請選擇指派或撤銷');
    }
    if (!DEVICE_PATTERN.test(text(source.deviceId))) {
      errors.push('裝置 ID 必須以 nudge- 開頭，且只能使用英數、點、底線與連字號');
    }
    if (!IDENTIFIER_PATTERN.test(text(source.assignedUserId))) {
      errors.push('請輸入有效的 Firebase 使用者 UID');
    }
    if (!REQUEST_PATTERN.test(text(source.clientRequestId))) {
      errors.push('請求 ID 必須是 8–128 字元的穩定識別碼');
    }
    if (rooms.length > 20) {
      errors.push('單一裝置最多允許 20 個房間');
    }
    if (rooms.some(roomId => !IDENTIFIER_PATTERN.test(roomId))) {
      errors.push('房間 ID 格式不正確');
    }
    if (new Set(rooms).size !== rooms.length) {
      errors.push('房間 ID 不可重複');
    }
    return errors;
  }

  function buildDeviceAssignmentCommand(draft) {
    const errors = validateDeviceAssignmentDraft(draft);
    if (errors.length) throw new Error(errors.join('\n'));
    const action = text(draft.action);
    return {
      action,
      deviceId: text(draft.deviceId),
      assignedUserId: text(draft.assignedUserId),
      allowedRoomIds: action === 'assign' ? roomIds(draft.allowedRoomIds) : [],
      clientRequestId: text(draft.clientRequestId),
      sourceSurface: 'admin_web',
    };
  }

  function timestampIso(value, field, nullable) {
    if (value == null && nullable) return null;
    const date = value && typeof value.toDate === 'function'
      ? value.toDate()
      : value instanceof Date
      ? value
      : new Date(value);
    if (!(date instanceof Date) || Number.isNaN(date.getTime())) {
      throw new Error(`Cloud 裝置指派的 ${field} 時間無效`);
    }
    return date.toISOString();
  }

  function normalizeDeviceAssignmentRecord(raw, expectedDeviceId) {
    const source = raw || {};
    const assignmentId = text(source.assignmentId);
    const deviceId = text(source.deviceId);
    const assignedUserId = text(source.assignedUserId);
    const status = text(source.status);
    if (!Array.isArray(source.allowedRoomIds)) {
      throw new Error('Cloud 裝置指派的房間清單無效');
    }
    const rooms = roomIds(source.allowedRoomIds);
    if (
      source.schemaVersion !== 1 ||
      assignmentId !== deviceId ||
      !DEVICE_PATTERN.test(deviceId) ||
      deviceId !== text(expectedDeviceId)
    ) {
      throw new Error('Cloud 裝置指派與查詢的裝置 ID 不一致');
    }
    if (!IDENTIFIER_PATTERN.test(assignedUserId)) {
      throw new Error('Cloud 裝置指派的使用者 UID 無效');
    }
    if (!['active', 'revoked'].includes(status)) {
      throw new Error('Cloud 裝置指派的狀態無效');
    }
    if (
      rooms.length > 20 ||
      new Set(rooms).size !== rooms.length ||
      rooms.some(roomId => !IDENTIFIER_PATTERN.test(roomId))
    ) {
      throw new Error('Cloud 裝置指派的房間清單無效');
    }
    const validFrom = timestampIso(source.validFrom, 'validFrom', false);
    const validUntil = timestampIso(source.validUntil, 'validUntil', true);
    const updatedAt = timestampIso(source.updatedAt, 'updatedAt', false);
    if (
      (validUntil && Date.parse(validUntil) < Date.parse(validFrom)) ||
      Date.parse(updatedAt) < Date.parse(validFrom)
    ) {
      throw new Error('Cloud 裝置指派的有效時間順序無效');
    }
    return {
      deviceId,
      assignedUserId,
      status,
      allowedRoomIds: rooms,
      validFrom,
      validUntil,
      updatedAt,
    };
  }

  return {
    buildDeviceAssignmentCommand,
    normalizeDeviceAssignmentRecord,
    validateDeviceAssignmentDraft,
  };
});
