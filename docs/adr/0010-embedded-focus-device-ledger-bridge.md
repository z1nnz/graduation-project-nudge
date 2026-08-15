# ADR 0010: Embedded focus device uses an App-mediated Ledger bridge

- Status: Accepted for prototype
- Date: 2026-08-15

## Decision

The first Nudge desk device is a personal focus-session controller built on a
Seeed XIAO ESP32-S3, Round Display, I2C push encoder and diffused WS2813 status
light. It does not write Firestore, rewards, characters, family projections or
group projections directly.

The device emits version-1 activity events over BLE. The signed-in App resolves
the canonical `DeviceAssignment`, supplies the trusted actor and consented room
context, converts the event to App-submitted `ActivityEvidence`, and uses the
existing Activity Ledger outbox/Cloud ingestion path. The Cloud source is
therefore `app`, not `device`: the stable source record still includes the
device identity, but the existing user endpoint never trusts a caller-supplied
`deviceId`. Web observes the resulting Cloud state. This preserves the current
authorization, settlement receipt, deduplication and reward rules.

An event ID is deterministic for one device sequence:

```text
{deviceId}:{sessionId}:{eventType}:{sequence}
```

The device persists its next sequence and its unacknowledged queue. The App
acknowledges only after it has durably accepted the event into its own Ledger
outbox. Cloud confirmation remains the point at which formal rewards and room
contributions become visible.

Before `configure`, the App durably enqueues a `started` event, waits for Cloud
to return the canonical Activity Session correlation, and only then sends that
correlation to the device. If an App focus session is already active, its
correlation is flushed and reused. Offline or rejected preparation does not
configure the device, so App and hardware cannot silently create two sessions.

## Authority boundary

- Device ownership and assignment come from Cloud, not from BLE payloads.
- A device event contains no `actorUserId`, family role, group role or room
  authority.
- A parent, manager or room owner cannot use the device to start or complete
  another member's activity.
- The device may display only the assigned user's approved character snapshot
  and safe aggregate context.
- Reset, transfer, Wi-Fi credentials and future OTA require a claimed-owner
  capability; the prototype BLE service is not yet that production claim flow.
  Consequently Cloud rejects every cross-account reassignment, even after
  revoke, until a verified empty queue and hardware-wipe receipt are designed.
  Account deletion removes the user-bearing assignment but atomically leaves a
  PII-free `device_transfer_locks/{deviceId}` wipe requirement, so deletion
  cannot erase this safety boundary.
- Protocol version 1 also rejects room-scope changes on an active assignment
  and rejects reactivation after revoke. Without a queue-empty receipt or
  versioned room-scope history, either operation could retroactively share old
  offline events into a newly allowed room. Revoke is therefore terminal until
  the verified wipe flow exists.

## Transport

BLE exposes separate command, compact state-notification and long event-read
characteristics. A notification announces pending work; the App reads the full
event and acknowledges the queue head. This avoids assuming every phone has a
BLE MTU large enough for the Ledger JSON in one notification.

Android requests a 517-byte MTU and bounds every one-shot command to the actual
negotiated ATT payload (`MTU - 3`, capped at 512 bytes). The peripheral also
advertises a 517-byte local MTU. A smaller negotiated payload fails closed with
an explicit App error; command chunking is not part of protocol version 1.

The App bridge now validates protocol and assignment, durably enqueues, and
only then creates the ACK command. Android now binds that bridge to platform
BLE channels, the App resolves the signed-in user's Cloud assignment, and the
Admin Web surface uses an audited Cloud callable to assign or revoke a device.
The App revalidates the Cloud assignment before every configure, start, pause,
resume and complete command; revocation disconnects the existing BLE control
path before the action reaches hardware.
Firestore denies client writes, while privacy export and account deletion both
cover the assignment lifecycle. Real peripheral connection, reconnect/replay
and Cloud Receipt observation remain hardware-stage acceptance gates. Direct
Wi-Fi Cloud ingestion is delayed
until device claim credentials, secure provisioning, certificate rotation and
server-side device authentication are designed. Adding Wi-Fi earlier would
create a second, weaker authorization boundary.

Version 1 does not contain a device signature. It inherits the signed-in App's
trust boundary, just like a focus session entered directly in the App. Signed
device proof, timestamp-attestation policy and Cloud-side device ingestion are
explicitly not accepted until claim credentials and key rotation exist; this
prototype must not be presented as cryptographically proving physical activity.

## Hardware constraints

Round Display consumes almost every XIAO pin. I2C peripherals share D4/D5.
Prototype LED data reuses D2, therefore microSD is disabled. The selected
WS2813 stick is specified for 3.3 V / 5 V operation; a normal 5 V WS2812
replacement requires a proper level shifter. USB 5 V / 2 A desk power is the
prototype source, with firmware brightness limiting.

## Acceptance boundary

Host C++ tests, Flutter protocol/runtime tests, Cloud assignment tests and
Firestore rules tests are required on every change. Once
parts arrive, the hardware gate adds PlatformIO compilation, USB upload, I2C
scan, display/encoder/LED checks, disconnect/reconnect replay and duplicate ACK
tests. A physical iPhone install is not required; iOS app acceptance remains a
clean Simulator smoke test. Android retains its existing clean
device-or-emulator App gate; embedded BLE itself requires Android hardware or a
desktop BLE client because an emulator cannot exercise the peripheral.

App Attest, APNs receipts, App Store signing, signed OTA, battery operation,
direct Wi-Fi ingestion and family/group shared devices remain explicitly
outside this prototype acceptance.
