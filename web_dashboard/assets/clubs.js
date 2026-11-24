(() => {
  "use strict";
  const get = id => document.getElementById(id);
  const state = { uid:null, selected:null, reply:null, action:null };
  const status = get("clubStatus");
  const directory = get("clubDirectory");
  const detail = get("clubDetail");
  const apply = get("clubApply");
  const form = get("clubPost");
  const dialog = get("clubDialog");
  const moderation = get("clubAction");
  const emblems = {sunrise:"日出",book:"書本",run:"跑鞋",pencil:"鉛筆",music:"音符",leaf:"樹葉",moon:"月亮",globe:"地球"};
  const stickers = {cheer:"歡呼",study:"讀書",sleep:"睡覺","thumbs-up":"讚","happy-tears":"喜極而泣",flex:"加油",coffee:"喝咖啡",heart:"愛心",okay:"沒問題",wave:"打招呼",think:"思考",fire:"火力全開"};
  const emojis = ["👍","🔥","💪","📚","😴","🎉"];
  let subscription, busy;
  function ask(action, input = {}) {
    return functions.httpsCallable("manageClubs")({ action, clubId: state.selected?.id, ...input }).then(result => result.data);
  }
  function node(tag, content) {
    const element = document.createElement(tag);
    if (content) element.textContent = content;
    return element;
  }
  function button(label, onClick) {
    const element = node("button", label);
    element.type = "button";
    element.className = "w-btn";
    element.addEventListener("click", () => onClick(element));
    return element;
  }
  function choose(club) {
    state.selected = club;
    resetReply();
    return run(async () => { await read(); get("clubName").focus(); });
  }
  function resetReply() {
    state.reply = null;
    get("clubReply").hidden = get("clubCancelReply").hidden = true;
  }
  function card(item, actions) {
    const element = node("article");
    element.className = "w-parchment club-card";
    const badge = new Image(64, 64);
    badge.alt = emblems[item.emblem] || "社徽";
    badge.src = "assets/clubs/" + (Object.hasOwn(emblems,item.emblem) ? item.emblem : "book") + ".png";
    const controls = node("div");
    controls.className = "club-actions";
    controls.append(...actions);
    element.append(badge, node("h3", item.name), node("p", item.introduction), controls);
    return element;
  }
  async function load() {
    const account = state.uid;
    const model = await ask("directory");
    if (account !== state.uid) return;
    apply.inert = false;
    apply.querySelector("button").disabled = false;
    directory.replaceChildren(...model.clubs.map(item => card(item, [button("查看社團", () => choose(item))])));
    if (!directory.childElementCount) directory.append(node("p", "目前沒有已通過審核的社團。"));
    get("clubRequests").replaceChildren(...model.requests.map(item => node("li", item.name + " · " +
      ({pending:"待審核",approved:"已通過",rejected:"未通過"}[item.status] || ""))));
    get("clubReview").hidden = !model.review.length;
    get("clubQueue").replaceChildren(...model.review.map(item => card(item, [
      button("核准", () => run(async () => { await ask("review", { clubId:item.id, status:"approved" }); await load(); })),
      button("退回", () => run(async () => { await ask("review", { clubId:item.id, status:"rejected" }); await load(); })),
    ])));
  }
  async function read() {
    const club = state.selected;
    const account = state.uid;
    if (!club) return;
    const model = await ask("view");
    if (account !== state.uid || state.selected?.id !== club.id) return;
    detail.hidden = false;
    get("clubName").textContent = club.name;
    get("clubIntroduction").textContent = club.introduction;
    get("clubInterior").hidden = !model.joined;
    get("clubJoin").hidden = model.joined;
    if (!model.joined) return;
    get("clubVisible").checked = model.public;
    get("clubChallenge").textContent = model.challenge.title + " · " + model.challenge.participants +
      " 人參與 · " + model.challenge.completed + " 人完成";
    get("clubChallengeJoin").disabled = model.challenge.joined;
    get("clubChallengeJoin").textContent = model.challenge.joined ? "已參與挑戰" : "參與挑戰";
    get("clubRoom").disabled = !model.hasRoom && !model.manager;
    get("clubRoom").textContent = model.hasRoom ? "進入社團自律房" : model.manager ? "開設社團自律房" : "等待管理者開房";
    get("clubVoiceOption").hidden = model.hasRoom || !model.manager;
    get("clubLeave").hidden = model.manager;
    const published = model.members.filter(member => member.public);
    get("clubMembers").replaceChildren(...published.map(member => node("li", member.name)));
    const management = get("clubManagement");
    management.hidden = !model.manager;
    management.replaceChildren();
    if (model.manager) {
      management.append(node("h3", "社團管理"));
      for (const member of model.members.filter(member => member.id !== account)) {
        const controls = node("p", member.name + " ");
        controls.append(button("禁言", opener => openDialog(opener, "mute", member.id)),
          button("移出", opener => openDialog(opener, "remove", member.id)));
        management.append(controls);
      }
    }
    const posts = new Map(model.posts.map(post => [post.id, post]));
    get("clubPosts").replaceChildren(...model.posts.map(post => showPost(post, posts, model.manager)));
  }
  function showPost(post, posts, manager) {
    const entry = node("article");
    entry.className = "club-post";
    entry.append(node("strong", post.authorName), node("time", new Date(post.createdAt).toLocaleString("zh-TW")));
    if (post.replyTo) entry.append(node("p", "回覆 " + (posts.get(post.replyTo)?.authorName || "較早的貼文")));
    entry.append(node("p", post.body));
    if (Object.hasOwn(stickers, post.sticker)) {
      const image = new Image(48,48);
      image.className = "club-sticker";
      image.src = "assets/chat_stickers/" + post.sticker + ".png";
      image.alt = stickers[post.sticker];
      entry.append(image);
    }
    const actions = node("div");
    actions.className = "club-actions";
    emojis.forEach(emoji => actions.append(button(emoji + " " + (post.totals[emoji] || 0), () => change("react",{postId:post.id,emoji}))));
    actions.append(button("留言", () => {
      state.reply = post.id; get("clubReply").hidden = get("clubCancelReply").hidden = false;
      get("clubReply").textContent = "回覆 " + post.authorName; form.elements.body.focus();
    }));
    if (post.authorId !== state.uid) actions.append(button("檢舉", opener => openDialog(opener,"report",post.id)));
    if (manager) actions.append(button("移除貼文", opener => openDialog(opener,"deleteMessage",post.id)));
    entry.append(actions);
    return entry;
  }
  async function run(operation) {
    if (busy || !state.uid) return false;
    const account = state.uid;
    busy = true;
    const postSubmit = form.querySelector("button[type=submit]");
    postSubmit.disabled = true;
    status.textContent = "正在同步社團…";
    try {
      await operation();
      if (account === state.uid) status.textContent = "";
      return account === state.uid;
    } catch (error) {
      if (account === state.uid) status.textContent = error.code === "functions/resource-exhausted" ?
        "操作已達上限。每位成員每小時最多 10 則貼文與留言。" : "操作未確認，請檢查資格或稍後再試。";
      return false;
    } finally {
      busy = false;
      postSubmit.disabled = !state.uid || get("clubInterior").hidden;
    }
  }
  const change = (action, payload) => run(async () => { await ask(action, payload); await read(); });
  function openDialog(opener, action, target) {
    state.action = { action, target, clubId:state.selected.id };
    moderation.reset();
    get("clubDialogTitle").textContent = {report:"檢舉貼文",mute:"禁言",remove:"移出社團",deleteMessage:"移除貼文",leave:"離開社團"}[action];
    get("clubReasonLabel").hidden = action !== "report";
    get("clubDurationLabel").hidden = action !== "mute";
    get("clubDetailsLabel").hidden = action === "leave";
    moderation.elements.details.required = action !== "report" && action !== "leave";
    get("clubDialogStatus").textContent = "";
    dialog.addEventListener("close", () => { if (opener.isConnected) opener.focus(); else get("clubName").focus(); }, {once:true});
    dialog.showModal();
  }
  moderation.addEventListener("submit", async event => {
    event.preventDefault();
    const item = state.action;
    if (!item) return;
    const ok = await run(async () => {
      if (item.action === "report") {
        await functions.httpsCallable("manageSocialSafety")({ action:"report", type:"clubPost",
          targetId:item.target, reason:moderation.elements.reason.value, details:moderation.elements.details.value });
      } else if (item.action === "leave") await ask("leave", {clubId:item.clubId});
      else await ask("moderate", { clubId:item.clubId, operation:item.action, targetId:item.target,
        minutes:Number(moderation.elements.minutes.value),reason:moderation.elements.details.value });
      await read();
    });
    if (ok) dialog.close(); else get("clubDialogStatus").textContent = "尚未確認，請再試一次。";
  });
  get("clubCancel").addEventListener("click", () => dialog.close());
  get("clubCancelReply").addEventListener("click", resetReply);
  get("clubJoin").addEventListener("click", () => change("join"));
  get("clubLeave").addEventListener("click", event => openDialog(event.currentTarget,"leave"));
  get("clubVisible").addEventListener("change", event => change("visibility",{enabled:event.currentTarget.checked}));
  get("clubChallengeJoin").addEventListener("click", () => change("challenge"));
  get("clubRoom").addEventListener("click", () => run(async () => {
    const {roomId} = await ask("room",{voiceEnabled:get("clubVoice").checked});
    location.assign("rooms.html?room=" + encodeURIComponent(roomId));
  }));
  Object.entries(emblems).forEach(([key,label]) => apply.elements.emblem.add(new Option(label,key)));
  form.elements.sticker.add(new Option("不加貼圖",""));
  Object.entries(stickers).forEach(([key,label]) => form.elements.sticker.add(new Option(label,key)));
  apply.addEventListener("submit", async event => {
    event.preventDefault();
    if (await run(async () => {
      await ask("apply",{name:apply.elements.label.value,introduction:apply.elements.introduction.value,emblem:apply.elements.emblem.value});
      await load();
    })) apply.reset();
  });
  form.addEventListener("submit", async event => {
    event.preventDefault();
    if (await change("post",{body:form.elements.body.value,sticker:form.elements.sticker.value,replyTo:state.reply})) {
      form.reset(); resetReply();
    }
  });
  function start() {
    if (subscription || typeof firebase === "undefined" || !firebase.apps.length) return;
    subscription = firebase.auth().onAuthStateChanged(user => {
      const next = user?.uid;
      if (next && next === state.uid) return;
      state.uid = next;
      state.selected = null;
      resetReply();
      detail.hidden = get("clubReview").hidden = true;
      if (dialog.open) dialog.close();
      apply.reset(); form.reset();
      directory.replaceChildren(); get("clubRequests").replaceChildren();
      apply.inert = true;
      apply.querySelector("button").disabled = true;
      if (state.uid) void run(load);
    });
  }
  document.addEventListener("firebase-ready", start);
  start();
})();
