# Nudge Web Dashboard and Notification Plan

## Web Dashboard

The web dashboard should not duplicate the mobile app. Its job is to make Nudge useful for longer review, class/team management, and project demonstrations.

### Current Static Prototype

- `web_dashboard/index.html`: Web Center entry point.
- `web_dashboard/personal.html`: monthly/yearly trends, pressure radar, discipline weather, time capsule, future letter, and life skill tree.
- `web_dashboard/guardian.html`: guardian companion center with trend-only child data, encouragement cards, shared goals, weekly reports, permission levels, and unlinking.
- `web_dashboard/groups.html`: enterprise/team challenges, study-group and cram-school management, rankings, review reminders, and group rooms.
- `web_dashboard/operations.html`: public room approvals, event rooms, shop item publishing, rarity, price ranges, and activity windows.
- `web_dashboard/research.html`: anonymized analysis, relationship demos, score logic explanation, and presentation demo controls.
- `web_dashboard/planet.html`: self-discipline city/planet that turns focus, health, sleep, room, and deadline progress into buildings.
- `web_dashboard/presentation.html`: graduation demo flow that guides the presentation through problem framing, app actions, score/coin logic, social/avatar value, web extensions, and the discipline planet.
- All pages share `web_dashboard/assets/styles.css` and `web_dashboard/assets/app.js`. The script injects a module selector into the sidebar so features are selected from a menu instead of being crowded into one page, and it provides a presentation display mode that hides navigation during demos.

### Core Pages

- Overview: long-term discipline score, coin earning trend, focus minutes, health task completion, and room activity.
- Task Template Manager: create reusable templates for daily tasks, deadline tasks, focus tasks, and health tasks.
- Reports: export weekly and monthly reports as PDF/CSV for project presentation or class use.
- Groups: class/team room rankings, active users, and room participation summary.
- Demo Dashboard: a clean presentation mode for graduation project demos.

### Data Contract

- User profile: id, nickname, avatar profile, title badge.
- Daily summary: date, weighted score, earned coins, task completion, tracked sources.
- Tasks: title, category, type, source type, target value, completion state.
- Health summary: sleep hours, steps, exercise minutes, last sync time.
- Rooms: room id, type, members, current activity, goal progress.
- Shop: owned items, equipped avatar items, coin balance.

### Recommended Stack

- Short term: static HTML prototype that reads exported JSON.
- Mid term: Flutter Web or React dashboard connected to the same backend as the app.
- Backend: Supabase or Firebase for auth, database, storage, and rules.
- Export: server-generated PDF/CSV, or client-generated export for demo stage.

## Notification System

Notifications should be implemented after the core data model is stable, because each notification depends on reliable task, room, and deadline state.

### Notification Types

- Task reminders: daily task time reminders and unfinished task nudges.
- Sleep reminders: based on the user's preferred bedtime.
- Room reminders: room start reminders and friend activity prompts.
- Encouragement notifications: friend encouragement and room chat reactions.
- Deadline reminders: staged reminders for deadline tasks.

### App Settings

- Master notification switch.
- Per-type switches.
- Quiet hours.
- Bedtime reminder time.
- Deadline reminder timing: 3 days before, 1 day before, due day.

### Implementation Notes

- iOS and Android both need notification permission pre-prompts before system permission dialogs.
- Local reminders can use `flutter_local_notifications`.
- Friend and room notifications need backend push notifications through FCM/APNs.
- Do not show raw health data in notifications. Use safe wording such as "你的健康任務還沒同步" instead of exposing sleep or step details.
