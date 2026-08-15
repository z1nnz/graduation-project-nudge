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
3. Connect the WS2813 stick `VCC` to the 5 V USB rail, `GND` to common ground,
   and data input to `D2`.
4. Do not initialize or insert a microSD card: the Round Display uses `D2` as
   microSD chip-select, and this firmware deliberately reuses it for LED data.
5. Keep LED brightness limited. Do not power the LED stick from an ESP32 GPIO.

The recommended WS2813 stick is specified for 3.3 V / 5 V operation. If it is
replaced with a normal 5 V WS2812/NeoPixel board, add a proper 74AHCT/HCT or
purpose-built pixel level shifter; do not assume a 3.3 V data-high is valid.

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

`lib/services/nudge_device_bridge.dart` is the transport-neutral consumer. The
Cloud user endpoint accepts authenticated App/Web evidence, so this bridge uses
`source=app`; the device-prefixed source record preserves provenance and
deduplication without trusting a BLE-provided Cloud `deviceId`. The production
Android BLE adapter and Cloud-backed assignment resolver are the next
hardware-stage integration step.

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
