# Web companion installation seam

Add a relative-scope Web manifest and dashboard installation/help panel. Use the
existing 1024px brand icon without inventing icon dimensions. Availability is
browser-dependent; do not claim automatic installability or offline acceptance.

- Only retain a real beforeinstallprompt event; prompt on explicit click and
  consume it once. Handle accepted, dismissed and thrown prompt results.
- Manual browser-menu/bookmark guidance remains available without the event.
- Standalone mode hides the install action; browser appinstalled is evidence of
  completion, not userChoice alone.
- Network state is a browser hint, never proof of Cloud synchronization and
  never a reason to disable task actions.
- No service worker, private response cache, notification permission request,
  analytics or persisted installation state in this slice.
- Do not modify App/Cloud data, reward authority or the existing #68 branch.

Acceptance: VM lifecycle tests and manifest path checks, followed by manual
browser installation testing on the deployed HTTPS site. This is a progressive
installation seam, not a complete offline PWA.

References checked during implementation:
- https://developer.mozilla.org/en-US/docs/Web/API/Window/beforeinstallprompt_event
- https://developer.mozilla.org/en-US/docs/Web/API/Navigator/onLine
