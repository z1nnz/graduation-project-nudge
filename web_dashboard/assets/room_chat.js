(() => {
  "use strict";

  const emojis = ["👍", "🔥", "💪", "📚", "😴", "🎉"];
  const stickers = {
    cheer: "歡呼", study: "讀書", sleep: "睡覺", "thumbs-up": "讚",
    "happy-tears": "喜極而泣", flex: "加油", coffee: "喝咖啡", heart: "愛心",
    okay: "沒問題", wave: "打招呼", think: "思考", fire: "火力全開",
  };
  const element = selector => document.querySelector(selector);
  const make = (tag, text) => {
    const node = document.createElement(tag);
    if (text != null) node.textContent = text;
    return node;
  };
  const button = (label, action) => {
    const node = make("button", label);
    node.type = "button";
    node.className = "w-btn";
    node.addEventListener("click", action);
    return node;
  };

  let session = null;
  let reply = null;
  const mention = element("[data-chat-mention]");
  const pin = element("[data-chat-pin]");
  const replyPanel = element("[data-chat-reply]");
  const hiddenPanel = element("[data-chat-hidden]");
  const composer = element("[data-room-message-input]");

  const stickerPicker = element("[data-chat-stickers]");

  function sticker(id) {
    const image = make("img");
    image.src = "assets/chat_stickers/" + id + ".png";
    image.alt = stickers[id];
    image.width = image.height = 96;
    return image;
  }

  function messageText(message) {
    return message.type === "sticker" && Object.hasOwn(stickers, message.text)
      ? stickers[message.text]
      : message.text;
  }

  function roleAction(state, node, action) {
    return async () => {
      if (state !== session || node.disabled) return;
      node.disabled = true;
      try {
        await action();
      } catch (error) {
        if (state === session) state.notify("操作失敗，請確認成員資格或稍後再試");
        console.warn("Room chat action failed:", error.code);
      } finally {
        node.disabled = false;
      }
    };
  }

  function actionButton(state, label, action) {
    const node = button(label, () => roleAction(state, node, action)());
    return node;
  }

  function renderMentions() {
    if (!session) return;
    const selected = mention.value;
    mention.replaceChildren(new Option("不提及", ""));
    for (const member of session.members()) {
      if (member.approvalStatus === "approved" && member.memberId !== session.userId) {
        mention.add(new Option("@" + member.displayName, member.memberId));
      }
    }
    if ([...mention.options].some(option => option.value === selected)) mention.value = selected;
  }

  function updateReply(message) {
    reply = message;
    replyPanel.hidden = !message;
    replyPanel.querySelector("span").textContent = message
      ? "引用 " + message.senderName + "：" + messageText(message)
      : "";
  }

  function messageBox(state, message, byId) {
    const article = make("article");
    article.className = "room-message";
    article.dataset.chatMessage = message.id;
    if (message.senderId === state.userId) article.classList.add("mine");
    article.append(make("strong", message.senderName || "自律夥伴"));
    if (message.replyTo) {
      const quoted = byId.get(message.replyTo);
      const quote = make("blockquote", "引用的訊息已無法顯示");
      article.append(quote);
      const apply = source => {
        if (session === state && source && !state.hidden.has(source.id)) {
          quote.textContent = source.senderName + "：" + messageText(source);
        }
      };
      if (quoted) apply(quoted);
      else state.room.collection("messages").doc(message.replyTo).get({ source: "server" })
        .then(snapshot => {
          if (snapshot.exists) apply({ ...snapshot.data(), id: snapshot.id });
        }).catch(() => {});
    }
    if (message.mentionUid) {
      const member = state.members().find(item => item.memberId === message.mentionUid);
      article.append(make("small", member ? "@" + member.displayName : "@已離開的成員"));
    }
    if (message.type === "sticker" && Object.hasOwn(stickers, message.text)) {
      article.append(sticker(message.text));
    } else {
      article.append(make("p", message.text || ""));
    }
    const actions = make("div");
    actions.className = "chat-actions";
    actions.append(button("回覆", () => {
      updateReply(message);
      composer.focus();
    }));
    actions.append(actionButton(state, "隱藏", () => hiddenRef(state).doc(message.id).set({
      userId: state.userId, messageId: message.id,
    })));
    if (message.senderId !== state.userId) {
      const report = button("檢舉", () => window.NudgeSafety.report(report, "roomMessage", message.id, state.room.id));
      const block = button("封鎖", () => window.NudgeSafety.block(block, message.senderId));
      actions.append(report, block);
    }
    if (state.isOwner() && !message.moderated) {
      const remove = button("移除訊息", () => window.NudgeSafety.removeContent(remove, state.room.id, message.id));
      actions.append(remove);
    }
    if (state.isOwner()) {
      actions.append(actionButton(state, "釘選", () => state.room.collection("chat_pin").doc("current").set({
        userId: state.userId, messageId: message.id,
      })));
    }
    const reactions = make("details");
    reactions.append(make("summary", "表情回應"));
    const choices = make("div");
    choices.className = "chat-actions";
    reactions.append(choices);
    const ref = state.room.collection("chat_reactions").doc(message.id).collection("chat_reactors");
    let unsubscribe;
    let mine;
    const reactionButtons = emojis.map(emoji => {
      const node = actionButton(state, emoji, () => mine === emoji
        ? ref.doc(state.userId).delete()
        : ref.doc(state.userId).set({ userId: state.userId, emoji }));
      node.setAttribute("aria-label", "回應 " + emoji);
      node.setAttribute("aria-pressed", "false");
      choices.append(node);
      return node;
    });
    const stop = () => {
      unsubscribe?.();
      unsubscribe = null;
      state.reactionStops.delete(stop);
    };
    reactions.addEventListener("toggle", () => {
      if (!reactions.open || state !== session || !reactions.isConnected) {
        stop();
        return;
      }
      unsubscribe = ref.onSnapshot(snapshot => {
        mine = snapshot.docs.find(doc => doc.id === state.userId)?.data().emoji;
        reactionButtons.forEach((node, index) => {
          const emoji = emojis[index];
          const count = snapshot.docs.filter(doc => doc.data().emoji === emoji).length;
          node.textContent = emoji + (count ? " " + count : "");
          node.setAttribute("aria-pressed", String(mine === emoji));
        });
      }, () => state.notify("無法同步表情回應"));
      state.reactionStops.add(stop);
    });
    article.append(actions, reactions);
    return article;
  }

  function hiddenRef(state) {
    return state.room.collection("chat_hidden").doc(state.userId).collection("chat_hidden_messages");
  }

  function render(messages) {
    const state = session;
    if (!state) return;
    state.messages = messages;
    if (!state.hiddenReady) return;
    renderMentions();
    for (const stop of state.reactionStops) stop();
    const list = element("[data-room-message-list]");
    const byId = new Map(messages.map(message => [message.id, message]));
    const visible = messages.filter(message => !state.hidden.has(message.id));
    const activeControl = document.activeElement;
    const activeMessage = activeControl?.closest("[data-chat-message]")?.dataset.chatMessage;
    const actionName = activeControl?.getAttribute("aria-label") || activeControl?.textContent;
    const expanded = new Set([...list.querySelectorAll("details[open]")].map(detail =>
      detail.closest("[data-chat-message]").dataset.chatMessage));
    list.replaceChildren(...visible.map(message => messageBox(state, message, byId)));
    if (!visible.length) list.append(make("p", "沒有可顯示的訊息。"));
    for (const article of list.querySelectorAll("[data-chat-message]")) {
      if (expanded.has(article.dataset.chatMessage)) article.querySelector("details").open = true;
    }
    if (activeMessage) {
      const restored = [...list.children].find(node => node.dataset.chatMessage === activeMessage);
      const control = restored && [...restored.querySelectorAll("button, summary")].find(node =>
        (node.getAttribute("aria-label") || node.textContent) === actionName);
      (control || list).focus();
    }
    hiddenPanel.hidden = state.hidden.size === 0;
    hiddenPanel.querySelector("div").replaceChildren(...[...state.hidden].map(id => {
      const message = byId.get(id);
      return actionButton(state, message ? "還原 " + message.senderName + " 的訊息" : "還原先前隱藏的訊息",
        () => hiddenRef(state).doc(id).delete());
    }));
    renderPin(state);
  }

  function renderPin(state) {
    pin.hidden = !state.pinned || state.hidden.has(state.pinned.id) || !state.hiddenReady;
    pin.replaceChildren();
    if (!pin.hidden) {
      pin.append(make("strong", "置頂公告"), make("p", messageText(state.pinned)));
      if (state.isOwner()) pin.append(actionButton(state, "取消釘選", () =>
        state.room.collection("chat_pin").doc("current").delete()));
    }
  }

  function stop() {
    if (!session) return;
    for (const unsubscribe of session.listeners) unsubscribe();
    for (const close of session.reactionStops) close();
    session = null;

    stickerPicker.replaceChildren();
    mention.disabled = true;
    mention.replaceChildren(new Option("不提及", ""));
    pin.hidden = true;
    pin.replaceChildren();
    hiddenPanel.hidden = true;
    hiddenPanel.querySelector("div").replaceChildren();
    updateReply(null);
    composer.value = "";
  }

  function start(options) {
    stop();
    const state = session = {
      ...options, messages: [], hidden: new Set(), hiddenReady: false, listeners: [], reactionStops: new Set(),
    };
    mention.disabled = false;
    for (const [id, label] of Object.entries(stickers)) {
      const node = button("", () => state.send(id, "sticker"));
      node.setAttribute("aria-label", "傳送" + label + "貼圖");
      node.dataset.roomSticker = id;
      node.dataset.bound = "true";
      node.append(sticker(id));
      stickerPicker.append(node);
    }
    state.listeners.push(hiddenRef(state).onSnapshot(snapshot => {
      state.hidden = new Set(snapshot.docs.map(doc => doc.id));
      state.hiddenReady = true;
      render(state.messages);
    }, () => {
      const list = element("[data-room-message-list]");
      list.replaceChildren(make("p", "無法確認隱藏設定，請重新載入聊天室。"));
    }));
    let stopPinnedMessage = () => {};
    state.listeners.push(() => stopPinnedMessage());
    state.listeners.push(state.room.collection("chat_pin").doc("current").onSnapshot(snapshot => {
      stopPinnedMessage();
      state.pinned = null;
      renderPin(state);
      if (!snapshot.exists) return;
      stopPinnedMessage = state.room.collection("messages").doc(snapshot.data().messageId)
        .onSnapshot(message => {
          state.pinned = message.exists ? { ...message.data(), id: message.id } : null;
          renderPin(state);
        }, () => {
          state.pinned = null;
          renderPin(state);
        });
    }, () => {
      stopPinnedMessage();
      state.pinned = null;
      renderPin(state);
      state.notify("無法同步置頂公告");
    }));
  }

  replyPanel.querySelector("button").addEventListener("click", () => {
    updateReply(null);
    composer.focus();
  });
  mention.addEventListener("focus", renderMentions);
  window.NudgeChat = {
    start, stop, render,
    messageContext: () => ({
      ...(reply ? { replyTo: reply.id } : {}),
      ...(mention.value ? { mentionUid: mention.value } : {}),
    }),
    clearComposer(roomId) {
      if (session?.room.id === roomId) {
        updateReply(null);
        mention.value = "";
      }
    },
  };
})();
