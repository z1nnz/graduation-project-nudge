(function (root) {
  'use strict';
  const doc = root.document;
  const core = root.NudgeWeeklyPlannerCore;
  if (!doc || !core || doc.body?.dataset.page !== 'weekly-planner') return;
  const byId = id => doc.getElementById(id);
  const start = core.weekStart(new Date());
  const days = core.weekDays(start);
  const labels = ['週一', '週二', '週三', '週四', '週五', '週六', '週日'];
  const status = byId('plannerStatus');
  const saveButton = byId('plannerSave');
  let connected = false;
  let generation = 0;
  let user = null;
  let tasks = [];
  let draftTasks = [];
  let slots = {};
  let revision = 0;
  let saving = false;
  let loaded = false;
  byId('plannerWeek').textContent = `${start} — ${days[6]}`;
  function setStatus(message, kind = '') { status.textContent = message; status.dataset.kind = kind; }
  function taskCard(task) {
    const card = doc.createElement('div');
    card.className = 'planner-task';
    card.draggable = true;
    card.dataset.taskId = task.id;
    card.addEventListener('dragstart', event => event.dataTransfer.setData('text/plain', task.id));
    const title = doc.createElement('strong');
    title.textContent = task.title;
    const label = doc.createElement('label');
    label.textContent = '安排日期';
    const select = doc.createElement('select');
    select.setAttribute('aria-label', `安排「${task.title}」的日期`);
    const assigned = days.find(day => (slots[day] || []).includes(task.id)) || '';
    for (const [value, name] of [['', '待安排'], ...days.map((day, index) => [day, `${labels[index]} ${day.slice(5)}`])]) {
      const option = doc.createElement('option');
      option.value = value;
      option.textContent = name;
      select.append(option);
    }
    select.value = assigned;
    select.addEventListener('change', () => {
      try {
        if (select.value) slots = core.assign(slots, task.id, select.value, start);
        else slots = Object.fromEntries(Object.entries(slots).map(([day, ids]) => [day, ids.filter(id => id !== task.id)]));
        render();
        setStatus('草稿已更新；按「儲存本週計畫」才會同步。', 'draft');
      } catch (error) { setStatus(error.message, 'error'); render(); }
    });
    label.append(select);
    card.append(title, label);
    if (task._draft) { const note = doc.createElement('small'); note.textContent = '每日固定任務 · 尚未儲存'; card.append(note); }
    return card;
  }
  function render() {
    const tray = byId('plannerTasks');
    const board = byId('plannerDays');
    byId('plannerTaskTitle').disabled = !loaded;
    byId('plannerAddTask').disabled = !loaded;
    tray.replaceChildren(); board.replaceChildren();
    const all = [...tasks, ...draftTasks];
    if (!all.length) { const empty = doc.createElement('p'); empty.className = 'story-empty'; empty.textContent = '還沒有待完成任務。從上方新增一件小事。'; tray.append(empty); }
    const assigned = new Set(Object.values(slots).flat());
    for (const task of all.filter(task => !assigned.has(task.id))) tray.append(taskCard(task));
    const loads = core.workload(slots, start);
    for (const [index, load] of loads.entries()) {
      const day = doc.createElement('section');
      day.className = 'planner-day'; day.dataset.day = load.day;
      const heading = doc.createElement('h3'); heading.textContent = `${labels[index]} · ${load.day.slice(5)}`;
      const count = doc.createElement('p'); count.textContent = `${load.count} 件任務`;
      if (load.warning) { count.className = 'planner-warning'; count.textContent += ' · 記得留白'; }
      const list = doc.createElement('div'); list.className = 'planner-day-list';
      for (const task of all.filter(item => (slots[load.day] || []).includes(item.id))) list.append(taskCard(task));
      day.append(heading, count, list);
      day.addEventListener('dragover', event => { event.preventDefault(); day.classList.add('is-dragover'); });
      day.addEventListener('dragleave', () => day.classList.remove('is-dragover'));
      day.addEventListener('drop', event => {
        event.preventDefault(); day.classList.remove('is-dragover');
        const id = event.dataTransfer.getData('text/plain');
        if (!all.some(task => task.id === id)) return;
        try { slots = core.assign(slots, id, load.day, start); render(); setStatus('草稿已更新；記得儲存。', 'draft'); }
        catch (error) { setStatus(error.message, 'error'); }
      });
      board.append(day);
    }
    saveButton.disabled = !user || saving || !loaded;
  }
  async function load() {
    const request = ++generation;
    loaded = false;
    render();
    if (!user || user.isAnonymous) { setStatus('請登入自己的帳號來安排任務。', 'guest'); return; }
    setStatus('正在讀取本週任務…', 'loading');
    try {
      const snap = await root.firebase.firestore().collection('users').doc(user.uid).get({ source: 'server' });
      if (request !== generation) return;
      if (!snap.exists) throw new Error('找不到使用者資料，請先完成帳號設定。');
      const data = snap.data();
      tasks = core.availableTasks(data.tasks, user.uid);
      draftTasks = [];
      const plan = data.webWeeklyPlans?.[start];
      revision = Number.isSafeInteger(plan?.revision) ? plan.revision : 0;
      slots = core.normalizeSlots(plan?.slots, tasks.map(task => task.id), start);
      loaded = true;
      render(); setStatus('已載入雲端計畫。新增或調整後，請按儲存。', 'ready');
    } catch (error) { if (request === generation) setStatus(error.message || '讀取失敗，請稍後重試。', 'error'); }
  }
  byId('plannerNewTask').addEventListener('submit', event => {
    event.preventDefault();
    const input = byId('plannerTaskTitle');
    const title = input.value.trim();
    if (!loaded || !user || user.isAnonymous || !title || title.length > 80) return;
    if (draftTasks.length >= 12) { setStatus('一次最多新增 12 件任務，請先儲存。', 'error'); return; }
    const id = root.crypto?.randomUUID?.();
    if (!id) { setStatus('瀏覽器無法建立安全的任務識別碼，請更新瀏覽器。', 'error'); return; }
    draftTasks.push({ id, userId: user.uid, title, _draft: true });
    input.value = ''; render(); setStatus('每日固定任務已加入草稿；儲存後才會同步到 App。', 'draft');
  });
  saveButton.addEventListener('click', async () => {
    if (saving || !loaded || !user || user.isAnonymous) return;
    const uid = user.uid;
    const request = generation;
    const pending = draftTasks.map(({ id, title }) => ({ id, title }));
    const proposed = JSON.parse(JSON.stringify(slots));
    const expected = revision;
    saving = true; render(); setStatus('正在儲存到雲端…', 'loading');
    try {
      const db = root.firebase.firestore();
      const ref = db.collection('users').doc(uid);
      await db.runTransaction(async transaction => {
        const snap = await transaction.get(ref);
        if (!snap.exists) throw new Error('找不到使用者資料。');
        const data = snap.data();
        const remotePlan = data.webWeeklyPlans?.[start];
        const remoteRevision = Number.isSafeInteger(remotePlan?.revision) ? remotePlan.revision : 0;
        if (remoteRevision !== expected) throw new Error('另一個裝置已更新本週計畫。請重新整理頁面後再安排。');
        const remoteTasks = Array.isArray(data.tasks) ? data.tasks : [];
        const existingIds = new Set(core.availableTasks(remoteTasks, uid).map(task => task.id));
        const now = new Date().toISOString();
        const additions = pending.map(task => ({ id: task.id, userId: uid, title: task.title,
          category: '自定義', taskType: 'fixed', priority: 'medium', isDone: false,
          isSystemTask: false, isAutoTracked: false, sourceType: 'manual', createdAt: now, updatedAt: now }));
        if (additions.some(task => remoteTasks.some(other => other?.id === task.id))) throw new Error('任務識別碼已存在，請重新整理頁面。');
        const validIds = [...existingIds, ...additions.map(task => task.id)];
        const safeSlots = core.normalizeSlots(proposed, validIds, start);
        transaction.update(ref, {
          ...(additions.length ? { tasks: [...remoteTasks, ...additions] } : {}),
          [`webWeeklyPlans.${start}`]: { revision: expected + 1, slots: safeSlots, updatedAt: now },
        });
      });
      if (request !== generation) return;
      revision += 1; tasks.push(...draftTasks.map(({ _draft, ...task }) => task));
      draftTasks = []; render(); setStatus('本週計畫已儲存到雲端；新增任務會出現在 App。', 'ready');
    } catch (error) { if (request === generation) setStatus(error.message || '儲存失敗，草稿還在此頁。', 'error'); }
    finally { saving = false; render(); }
  });
  function connect() {
    if (connected || !root.firebase?.apps?.length) return;
    connected = true;
    root.firebase.auth().onAuthStateChanged(next => { user = next; loaded = false; tasks = []; draftTasks = []; slots = {}; render(); load(); });
  }
  doc.addEventListener('firebase-ready', connect); connect(); render();
})(typeof globalThis !== 'undefined' ? globalThis : this);
