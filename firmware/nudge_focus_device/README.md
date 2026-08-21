# Nudge Focus Device firmware

First firmware slice for the XIAO ESP32-S3 desk companion. It targets:

- Seeed Studio XIAO ESP32-S3 with soldered headers;
- Seeed Round Display for XIAO, board combo `501`;
- Adafruit PID 5880 I2C push encoder at address `0x36`;
- Grove RGB LED Stick with 10 WS2813 Mini LEDs;
- USB 5 V / 2 A desk power.

The portable C++ core is intentionally independent of Arduino. It owns the
focus-session state machine, monotonic elapsed-time accounting, stable event
sequence and canonical Activity Ledger JSON. Flutter parses the same protocol
in `lib/services/nudge_device_protocol.dart`.

## What works in this slice

- configure, start, pause, resume, manual completion and timed completion;
- paused time is excluded from the accepted focus metric;
- stable event IDs: `{deviceId}:{sessionId}:{eventType}:{sequence}`;
- sequence and up to eight unacknowledged events persisted in ESP32 NVS;
- BLE command, state and event characteristics;
- an event remains queued until the App sends an ACK for the queue head;
- short encoder press toggles start/pause/resume; long press completes;
- display countdown and pending-sync state;
- limited-brightness LED progress/status output.
- Cloud-filtered room, personal-goal and character context in one BLE frame;
- encoder room selection and NVS-persisted presentation snapshot;
- six LED presentation states: offline, ready, active, paused, complete and rest;
- VEML7700 smoothed auto-brightness with a fixed-level sensor fallback;
- low-volume Qwiic Buzzer cues with an App-controlled quiet setting.

This is a development firmware. Device claim authorization, encrypted Wi-Fi
provisioning, signed OTA and Cloud-managed firmware policy are still required
before treating it as a production device.

## Host verification

No embedded toolchain or physical board is needed for the state-machine tests:

```sh
make -C firmware/nudge_focus_device test
flutter test test/nudge_device_protocol_test.dart
```

The optional CMake file provides the same native target when CMake is present.

## PlatformIO build and upload

Install PlatformIO, connect the XIAO over a data-capable USB-C cable, then run:

```sh
pio run --project-dir firmware/nudge_focus_device
pio run --project-dir firmware/nudge_focus_device --target upload
pio device monitor --baud 115200
```

The current workstation compiled this target successfully with PlatformIO
6.1.19 and Espressif32 platform 7.0.1. A physical upload and peripheral check
still require the purchased board.

## Wiring

1. Plug the soldered XIAO into the Round Display with the XIAO USB-C connector
   facing outward, as required by Seeed's guide.
2. Connect the encoder to `3V3`, `GND`, `D4/SDA`, `D5/SCL` using the Qwiic to
   female-jumper cable.
3. Connect `D2` through a 5 V-powered 74AHCT125/74HCT logic-level converter,
   then connect its output to the WS2813 stick data input. Power the stick from
   the 5 V USB rail and use common ground.
4. Do not initialize or insert a microSD card: the Round Display uses `D2` as
   microSD chip-select, and this firmware deliberately reuses it for LED data.
5. Keep LED brightness limited. Do not power the LED stick from an ESP32 GPIO.

The module page lists 3.3 V / 5 V operation, but the linked WS2813-Mini data
sheet requires a 0.7 x VDD input high. At 5 V that is 3.5 V, so the level
shifter is mandatory for this build; do not assume ESP32 3.3 V data is valid.

## BLE contract

Service UUID: `7df10000-4e55-4447-4500-4e5544474531`

| Characteristic | UUID suffix | Properties | Purpose |
|---|---|---|---|
| command | `0001` | write | configure and transition commands; ACK queue head |
| state | `0002` | read, notify | small phase/remaining/pending signal |
| event | `0003` | read | full JSON for the oldest unacknowledged event |

The state notification stays small enough for conservative BLE MTUs. When
`pending > 0`, the App reads the event characteristic, validates the active
assignment, durably queues App-submitted Activity Ledger evidence, then writes:

```json
{
  "protocolVersion": 1,
  "type": "ack",
  "eventId": "nudge-a1b2c3:focus-42:started:1"
}
```

Only the queue head can be acknowledged. A lost ACK causes the same stable
event to be read again, so Cloud idempotency prevents duplicate rewards.

Android requests MTU 517 and limits each command to the negotiated ATT payload
(`MTU - 3`, at most 512 bytes). Firmware sets its local MTU to 517. If the phone
negotiates less than a complete command, the App rejects that command instead
of reporting a partial write; protocol v1 does not chunk command JSON.

`lib/services/nudge_device_bridge.dart` is the transport-neutral consumer. The
Cloud user endpoint accepts authenticated App/Web evidence, so this bridge uses
`source=app`; the unauthenticated device-prefixed source record preserves
correlation and idempotency, not cryptographic provenance. Android now provides
the characteristic adapter, while the App resolves the Cloud-backed assignment
and writes through its durable Activity Ledger outbox. The Admin Web surface
provisions or revokes assignments through an audited Cloud callable; clients
cannot write assignment documents directly. These paths are code- and
emulator-verified, but still require the purchased peripheral for real BLE
acceptance.

The App also waits for Cloud to accept or recognize the focus start and returns
the canonical session correlation before sending `configure`. If Cloud is
offline or rejects the start, the device remains unconfigured. Admin Web can
read the current canonical assignment after refresh. Cross-account transfer is
blocked until a verified device queue wipe/reset receipt exists; revoke plus a
new UID is deliberately insufficient. Account deletion replaces the
user-bearing assignment with a PII-free wipe-required lock, so deleting the old
account cannot make the same physical device transferable. The App also
revalidates assignment before every lifecycle command and disconnects when a
revocation is observed.

Protocol v1 permits an idempotent update only when the active assignment keeps
the same room set. Adding/removing rooms and reactivating a revoked assignment
are rejected until Cloud can verify an empty device queue and preserve
time-versioned room scope. This prevents yesterday's offline event from being
shared to a room added today.

## Named hardware gates still open

- real Android-to-peripheral BLE connection, reconnect/replay and Receipt
  observation;
- physical validation of D6 backlight PWM, ambient-light placement, buzzer
  rail stability, 74AHCT/HCT level shifting and the final enclosure;
- CJK glyph validation on the purchased Round Display (the payload is UTF-8
  bounded, but the final embedded font must be proven on-device);
- signed device claim, timestamp proof and Wi-Fi/Cloud device ingestion.

These are not implied by the successful host or PlatformIO build.

Configure before allowing local controls:

```json
{
  "protocolVersion": 1,
  "type": "configure",
  "sessionId": "focus-42",
  "activityCorrelationId": "cloud-focus-42",
  "durationSeconds": 1500,
  "clockEpochMs": 1786759200000
}
```

The device never supplies an actor or family/group/room authorization. The App
must resolve the active backend `DeviceAssignment`, attach the assigned actor
and consented rooms, and then send the event through the canonical Ledger.
