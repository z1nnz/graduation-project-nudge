# Graduation Project Nudge

Nudge is a Flutter graduation project focused on self-discipline, habit
formation, health tracking, focus sessions, social accountability rooms, avatar
customization, and a reward shop.

## Competition hardware demo

Orbit and Station use the **Competition Demo Edition v1** work packages.
Start with the [scope adoption and delivery record](docs/competition-demo/scope-adoption.md).
The 2026-11-04 ZIP and its 32 product work packages are **superseded** for
competition hardware work. The only required demo is offline
Home → Focus → Complete on each physical display; App/BLE is optional.

## Project Name

- Chinese: 畢業專題 Nudge
- English: Graduation Project Nudge
- Suggested GitHub repository name: `graduation-project-nudge`

## Core Features

- Weighted task scoring and discipline coin rewards
- Manual, deadline, and auto-tracked tasks
- Focus timer and focus history
- Apple Health / Android Health Connect data integration
- Social discipline rooms with room goals, chat, encouragement, and approval
- Avatar editor, outfit shop, owned-item logic, and public profile display
- Daily records, calendar drill-down, statistics, weekly reports, and badges
- Privacy and data management for sensitive health and activity data

## Development

```sh
flutter pub get
flutter analyze
flutter test
```

## Notes

Cloud sync is prepared conceptually in the app's privacy and data management
screen, but a production backend still needs to be connected before data can be
saved across devices.
