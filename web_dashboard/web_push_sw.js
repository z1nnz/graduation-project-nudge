"use strict";

self.addEventListener("notificationclick", event => {
  if (!event.notification.data?.page) return;
  event.stopImmediatePropagation();
  event.notification.close();
  const url = self.NudgeWebPushCore.townUrl(self.registration.scope, event.notification.data.page);
  event.waitUntil((async () => {
    const windows = await self.clients.matchAll({ type: "window", includeUncontrolled: true });
    const town = windows.find(client => new URL(client.url).pathname === new URL(url).pathname);
    if (!town) {
      await self.clients.openWindow(url);
      return;
    }
    const next = await town.navigate(url);
    await next?.focus();
  })());
});

importScripts(
  "./assets/web_push_core.js",
  "https://www.gstatic.com/firebasejs/9.22.0/firebase-app-compat.js",
  "https://www.gstatic.com/firebasejs/9.22.0/firebase-messaging-compat.js",
);


firebase.initializeApp({
  apiKey: "AIzaSyCsvP-r0EygpkhH0Zwzfrl4uFzy6LcbsTQ",
  projectId: "nudge-discipline-app",
  messagingSenderId: "497972469632",
  appId: "1:497972469632:web:cb87819a70c7cb8f2f6b65"
});

firebase.messaging().onBackgroundMessage(payload => {
  const notice = self.NudgeWebPushCore.notification(payload.data);
  if (notice) return self.registration.showNotification(notice.title, notice);
});
