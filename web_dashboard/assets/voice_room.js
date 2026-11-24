(() => {
  "use strict";

  const core = window.NudgeVoiceRoomCore;
  const panel = document.querySelector("[data-voice-room]");
  const setting = document.querySelector("[data-voice-setting]");
  const by = name => panel.querySelector("[data-voice-" + name + "]");
  const timestamp = () => firebase.firestore.FieldValue.serverTimestamp();
  const rtcConfig = { iceServers: [{ urls: "stun:stun.l.google.com:19302" }] };
  let selected = null;
  let session = null;
  let problem = "";

  function render() {
    panel.hidden = !selected;
    setting.hidden = !selected?.owner;
    setting.setAttribute("aria-pressed", String(selected?.enabled === true));
    setting.textContent = selected?.enabled ? "關閉語音自習室" : "開啟語音自習室";
    if (!selected) return;
    const joined = session?.joined === true;
    by("join").disabled = !selected.enabled || Boolean(session);
    for (const key of ["mic", "hold", "hand", "leave"]) by(key).disabled = !joined;
    by("mic").setAttribute("aria-pressed", String(joined && !session.muted));
    by("mic").textContent = joined && !session.muted ? "麥克風開啟" : "麥克風靜音";
    by("hand").setAttribute("aria-pressed", String(joined && session.handRaised));
    by("hand").textContent = joined && session.handRaised ? "放下手" : "舉手";
    if (!joined) by("play").hidden = true;
    by("request-mute").hidden = !selected.owner || !selected.enabled;
    const peers = session ? [...session.peers.values()] : [];
    const connected = peers.filter(peer => peer.connection.connectionState === "connected").length;
    const failed = peers.some(peer => peer.failed);
    const state = problem || (!selected.enabled ? "此房間尚未開啟語音。" :
      !session ? "加入時才會請求麥克風權限。" :
      !joined ? "正在加入語音…" :
      failed ? "無法建立語音連線。部分網路不支援直接連線。" :
      connected ? "已連線 · " + (connected + 1) + " 人" :
      peers.length ? "正在建立語音連線…" : "已加入，等待其他夥伴。");
    if (by("status").textContent !== state) by("status").textContent = state;
    const raised = joined
      ? [...session.participants.values()].filter(item => item.uid !== session.uid && item.handRaised)
        .map(item => selected.names(item.uid))
      : [];
    by("hands").textContent = raised.length ? "舉手：" + raised.join("、") : "";
  }

  function participantRef(state) {
    return state.room.collection("voice_participants").doc(state.uid);
  }

  function capacityRef(state) {
    return state.room.collection("voice_state").doc("capacity");
  }

  async function reserve(state) {
    await state.db.runTransaction(async transaction => {
      const capacity = await transaction.get(capacityRef(state));
      const own = await transaction.get(participantRef(state));
      const uids = capacity.data()?.uids || [];
      if (own.exists || uids.includes(state.uid)) throw new Error("你已在另一個分頁加入語音。");
      if (uids.length >= core.maxParticipants) throw new Error("語音自習室已滿 8 人。");
      transaction.set(capacityRef(state), { uids: [...uids, state.uid] });
      transaction.set(participantRef(state), {
        uid: state.uid, joinedAt: state.joinedAt, muted: true, handRaised: false, updatedAt: timestamp(),
      });
    });
  }

  async function release(state) {
    try {
      await state.db.runTransaction(async transaction => {
        const own = await transaction.get(participantRef(state));
        if (!own.exists || own.data().joinedAt !== state.joinedAt) return;
        const capacity = await transaction.get(capacityRef(state));
        const uids = capacity.data()?.uids || [];
        transaction.set(capacityRef(state), { uids: uids.filter(uid => uid !== state.uid) });
        transaction.delete(participantRef(state));
      });
    } catch (error) {
      console.warn("Voice presence cleanup deferred:", error.code);
    }
  }

  function releaseOnPageHide(state) {
    if (!state.deletionToken) return;
    const loopback = ["127.0.0.1", "localhost"].includes(window.location.hostname);
    const emulator = loopback && window.NUDGE_RUNTIME_CONFIG?.useLocalEmulators === true;
    const project = firebase.app().options.projectId;
    const endpoint = emulator
      ? "http://127.0.0.1:5001/" + project + "/asia-east1/leaveRoomVoice"
      : "https://asia-east1-" + project + ".cloudfunctions.net/leaveRoomVoice";
    void fetch(endpoint, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: "Bearer " + state.deletionToken,
      },
      keepalive: true,
      body: JSON.stringify({ data: { roomId: state.room.id, joinedAt: state.joinedAt } }),
    }).catch(() => {});
  }

  function disconnectPeer(state, uid) {
    const peer = state.peers.get(uid);
    if (!peer) return;
    state.peers.delete(uid);
    clearTimeout(peer.timeout);
    peer.connection.close();
    peer.audio?.remove();
    peer.source?.disconnect();
  }

  function close(message = "", pagehide = false) {
    const state = session;
    session = null;
    problem = message;
    if (state) {
      for (const unsubscribe of state.listeners) unsubscribe();
      clearInterval(state.heartbeat);
      clearInterval(state.meter);
      clearInterval(state.peerExpiry);
      for (const uid of state.peers.keys()) disconnectPeer(state, uid);
      state.stream?.getTracks().forEach(track => track.stop());
      state.context?.close().catch(() => {});
      if (state.joined) {
        if (pagehide) releaseOnPageHide(state);
        void release(state);
      }
    }
    by("notice").textContent = "";
    for (const seat of document.querySelectorAll("[data-voice-speaking]")) delete seat.dataset.voiceSpeaking;
    render();
  }

  function meter(state, stream) {
    if (!state.context) return {};
    const source = state.context.createMediaStreamSource(stream);
    const analyser = state.context.createAnalyser();
    analyser.fftSize = 256;
    source.connect(analyser);
    return { source, analyser, samples: new Float32Array(analyser.fftSize) };
  }

  function speaking(record) {
    if (!record?.analyser) return false;
    record.analyser.getFloatTimeDomainData(record.samples);
    const power = record.samples.reduce((sum, sample) => sum + sample * sample, 0) / record.samples.length;
    return power > 0.00018;
  }

  function updateIndicators(state) {
    for (const seat of document.querySelectorAll("[data-room-stage-member]")) {
      const uid = seat.dataset.roomStageMember;
      const audible = uid === state.uid
        ? state.stream.getAudioTracks()[0]?.enabled && speaking(state.localMeter)
        : state.participants.get(uid)?.muted === false && speaking(state.peers.get(uid));
      if (audible) seat.dataset.voiceSpeaking = "true";
      else delete seat.dataset.voiceSpeaking;
    }
  }

  function failPeer(peer) {
    if (session !== peer.state || peer.connection.connectionState === "closed") return;
    peer.failed = true;
    render();
  }

  async function send(state, uid, type, data) {
    if (session !== state) return;
    const payload = JSON.stringify(data);
    if (!payload || payload.length > 8000) throw new Error("語音連線資料超過限制。");
    await state.room.collection("voice_signals").add({
      from: state.uid, to: uid, type, payload, createdAt: timestamp(),
    });
  }

  function connect(state, uid) {
    const connection = new RTCPeerConnection(rtcConfig);
    const peer = {
      state, connection, joinedAt: state.participants.get(uid).joinedAt, candidates: [], failed: false, queue: Promise.resolve(),
    };
    state.peers.set(uid, peer);
    peer.timeout = setTimeout(() => failPeer(peer), 15_000);
    for (const track of state.stream.getAudioTracks()) connection.addTrack(track, state.stream);
    connection.onicecandidate = event => {
      if (event.candidate) send(state, uid, "ice", event.candidate.toJSON()).catch(() => failPeer(peer));
    };
    connection.ontrack = event => {
      if (session !== state || state.peers.get(uid) !== peer) return;
      const stream = event.streams[0] || new MediaStream([event.track]);
      const node = document.createElement("audio");
      node.autoplay = true;
      node.playsInline = true;
      node.srcObject = stream;
      panel.append(node);
      peer.audio = node;
      Object.assign(peer, meter(state, stream));
      node.play().catch(() => { by("play").hidden = false; });
    };
    connection.onconnectionstatechange = () => {
      if (connection.connectionState === "connected") {
        clearTimeout(peer.timeout);
        peer.failed = false;
      } else if (["failed", "disconnected"].includes(connection.connectionState)) {
        failPeer(peer);
      }
      render();
    };
    return peer;
  }

  function addPeer(state, uid) {
    if (state.peers.has(uid)) return state.peers.get(uid);
    const peer = connect(state, uid);
    if (core.shouldOffer(state.uid, uid)) {
      peer.queue = peer.queue.then(async () => {
        const offer = await peer.connection.createOffer();
        await peer.connection.setLocalDescription(offer);
        await send(state, uid, "offer", offer);
      }).catch(() => failPeer(peer));
    }
    return peer;
  }

  function readSignal(state, doc) {
    const data = doc.data();
    if (data.from === state.uid || data.to !== state.uid || data.payload.length > 8000) return;
    const peer = state.peers.get(data.from);
    if (!peer || !validPeer(state, data.from)) {
      state.pendingSignals.set(doc.id, doc);
      return;
    }
    state.pendingSignals.delete(doc.id);
    peer.queue = peer.queue.then(async () => {
      if (session !== state || state.peers.get(data.from) !== peer || !validPeer(state, data.from)) return;
      const payload = JSON.parse(data.payload);
      const connection = peer.connection;
      if (data.type === "ice") {
        if (connection.remoteDescription) await connection.addIceCandidate(payload);
        else peer.candidates.push(payload);
      } else {
        const offer = data.type === "offer";
        if (payload.type !== data.type || offer === core.shouldOffer(state.uid, data.from)) return;
        await connection.setRemoteDescription(payload);
        for (const ice of peer.candidates.splice(0)) await connection.addIceCandidate(ice);
        if (offer) {
          const answer = await connection.createAnswer();
          await connection.setLocalDescription(answer);
          await send(state, data.from, "answer", answer);
        }
      }
    }).catch(() => failPeer(peer)).finally(() => doc.ref.delete().catch(() => {}));
  }

  function validPeer(state, uid) {
    const participant = state.participants.get(uid);
    return state.eligible(uid) && participant && !core.heartbeatExpired(
      participant.updatedAt, Date.now() + state.clockOffset,
    );
  }

  function refreshPeers(state) {
    for (const [uid, peer] of state.peers) {
      if (!validPeer(state, uid) || state.participants.get(uid).joinedAt !== peer.joinedAt) {
        disconnectPeer(state, uid);
      }
    }
    for (const uid of state.participants.keys()) {
      if (uid !== state.uid && validPeer(state, uid)) addPeer(state, uid);
    }
    for (const signal of state.pendingSignals.values()) {
      if (validPeer(state, signal.data().from)) readSignal(state, signal);
    }
  }

  async function writePresence(state) {
    await state.db.runTransaction(async transaction => {
      const ref = participantRef(state);
      const snapshot = await transaction.get(ref);
      if (session !== state || snapshot.data()?.joinedAt !== state.joinedAt) {
        throw new Error("Voice presence no longer belongs to this tab.");
      }
      transaction.update(ref, {
        muted: state.muted && !state.holding, handRaised: state.handRaised, updatedAt: timestamp(),
      });
    });
  }

  function updateMic(state) {
    for (const track of state.stream.getAudioTracks()) track.enabled = !state.muted || state.holding;
    render();
    writePresence(state).catch(() => {
      if (session === state) close("語音資格已失效或無法同步。");
    });
  }

  function listen(state) {
    const lost = () => { if (session === state) close("語音資格已失效或無法同步。"); };
    state.listeners.push(state.room.collection("voice_participants").onSnapshot({ includeMetadataChanges: true }, snapshot => {
      if (session !== state || snapshot.metadata.fromCache) return;
      state.participants = new Map(snapshot.docs.map(doc => [doc.id, doc.data()]));
      if (!state.participants.has(state.uid)) return lost();
      refreshPeers(state);
      render();
    }, lost));
    state.listeners.push(state.room.collection("voice_signals").where("to", "==", state.uid)
      .onSnapshot(snapshot => {
        if (session !== state) return;
        for (const change of snapshot.docChanges()) {
          if (change.type === "removed") state.pendingSignals.delete(change.doc.id);
          if (change.type !== "added") continue;
          const signal = change.doc.data();
          const createdAt = signal.createdAt?.toMillis?.();
          if (!Number.isFinite(createdAt) || createdAt < state.started) {
            void change.doc.ref.delete().catch(() => {});
          } else {
            readSignal(state, change.doc);
          }
        }
      }, lost));
    let lastMute = state.started;
    state.listeners.push(state.room.collection("voice_mute").doc("current").onSnapshot({ includeMetadataChanges: true }, snapshot => {
      if (session !== state || snapshot.metadata.fromCache) return;
      const requestedAt = snapshot.data()?.createdAt?.toMillis?.();
      if (!snapshot.metadata.hasPendingWrites && requestedAt > lastMute) {
        lastMute = requestedAt;
        state.muted = true;
        state.holding = false;
        updateMic(state);
        by("notice").textContent = "房主已請大家靜音。";
      }
    }, lost));
    const cacheDeletionToken = user => {
      if (user?.uid === state.uid) user.getIdToken()
        .then(token => { if (session === state) state.deletionToken = token; })
        .catch(() => {});
    };
    state.listeners.push(firebase.auth().onIdTokenChanged(cacheDeletionToken));
    state.heartbeat = setInterval(() => writePresence(state).catch(lost), 25_000);
    state.peerExpiry = setInterval(() => { refreshPeers(state); render(); }, 2_000);
    state.meter = setInterval(() => updateIndicators(state), 140);
  }

  by("join").addEventListener("click", async () => {
    if (!selected?.enabled || session) return;
    if (!navigator.mediaDevices?.getUserMedia || !window.RTCPeerConnection) {
      problem = "這個瀏覽器無法使用語音。";
      render();
      return;
    }
    const state = session = {
      ...selected, started: Date.now(), joinedAt: new Date().toISOString(),
      joined: false, muted: true, holding: false, handRaised: false, listeners: [],
      peers: new Map(), participants: new Map(), pendingSignals: new Map(),
    };
    problem = "";
    render();
    try {
      if (window.AudioContext) {
        state.context = new AudioContext();
        await state.context.resume();
      }
      if (window.NudgeSafety && !(await window.NudgeSafety.voiceAllowed())) {
        throw new Error("你的語音保護設定目前關閉麥克風。");
      }
      if (session !== state) return;
      const stream = state.stream = await navigator.mediaDevices.getUserMedia({ audio: true, video: false });
      if (session !== state) {
        stream.getTracks().forEach(track => track.stop());
        return;
      }
      stream.getAudioTracks().forEach(track => { track.enabled = false; });
      await reserve(state);
      if (session !== state) return void release(state);
      state.joined = true;
      const presence = await participantRef(state).get({ source: "server" });
      if (session !== state) return;
      state.started = presence.data().updatedAt.toMillis();
      state.clockOffset = state.started - Date.now();
      state.localMeter = meter(state, stream);
      listen(state);
      render();
    } catch (error) {
      if (session === state) close(error.name === "NotAllowedError"
        ? "需要麥克風授權才能加入。"
        : error.message || "無法加入語音。");
    }
  });

  by("mic").addEventListener("click", () => {
    if (!session?.joined) return;
    problem = "";
    session.muted = !session.muted;
    updateMic(session);
  });
  function hold(active) {
    if (!session?.joined || session.holding === active) return;
    if (active) problem = "";
    session.holding = active;
    updateMic(session);
  }

  const push = by("hold");
  push.addEventListener("pointerdown", event => {
    if (event.button !== 0) return;
    push.setPointerCapture(event.pointerId);
    hold(true);
  });
  for (const event of ["pointerup", "pointercancel", "lostpointercapture", "blur"]) {
    push.addEventListener(event, () => hold(false));
  }
  push.addEventListener("keydown", event => {
    if (event.key === " " || event.key === "Enter") {
      event.preventDefault();
      hold(true);
    }
  });
  push.addEventListener("keyup", event => {
    if (event.key === " " || event.key === "Enter") hold(false);
  });
  window.addEventListener("blur", () => hold(false));
  by("hand").addEventListener("click", () => {
    if (!session?.joined) return;
    session.handRaised = !session.handRaised;
    updateMic(session);
  });
  by("leave").addEventListener("click", () => close());
  by("play").addEventListener("click", async () => {
    const nodes = [...panel.querySelectorAll("audio")];
    await Promise.allSettled(nodes.map(node => node.play()));
    by("play").hidden = nodes.every(node => !node.paused);
  });
  by("request-mute").addEventListener("click", async () => {
    if (!selected?.owner || !selected.enabled) return;
    try {
      await selected.room.collection("voice_mute").doc("current").set({ requestedBy: selected.uid, createdAt: timestamp() });
    } catch {
      problem = "無法送出靜音要求。";
      render();
    }
  });
  setting.addEventListener("click", async () => {
    if (!selected?.owner) return;
    try {
      await selected.room.update({ voiceEnabled: !selected.enabled, updatedAt: new Date().toISOString() });
    } catch {
      problem = "無法更新語音設定。";
      render();
    }
  });
  window.addEventListener("pagehide", () => close("", true));
  window.NudgeVoiceRoom = Object.freeze({
    sync(options) {
      const shouldClose = session && (!options?.enabled || options.room.id !== session.room.id ||
        options.uid !== session.uid);
      selected = options;
      if (shouldClose) close();
      else {
        if (session?.joined) refreshPeers(session);
        render();
      }
    },
  });
})();
