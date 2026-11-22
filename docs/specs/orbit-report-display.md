# Orbit report display

Build on the existing package 07/08 firmware, without merging unrelated demo
packages or changing App/Cloud authority.

- Improve the 240x240 round display Home, Focus and Complete scenes.
- Show a companion, a clear countdown and perimeter progress, and an offline
  completion feedback label. Keep DEMO visible. Do not claim real XP or sync.
- Generate a report SVG from exactly the same Painter used by the ESP32;
  identify it as software rendering, not a device photograph. Host font metrics
  are approximate. The ASCII labels deliberately avoid missing Chinese glyphs.
- Compile the existing Seeed Round Display/XIAO ESP32S3 environment. Compilation
  is not physical acceptance and must not imply touch support.
- Keep display/color diagnostics and existing scenario tests working.

## Run and acceptance

From `firmware/nudge_competition_demo`:

```sh
make test report-preview
pio run -e orbit_p0a
pio device list
```

The report image is `build/native/orbit-report-preview.svg`. P0-A automatically
loops Home (5 seconds), Focus (20 seconds) and Complete (5 seconds), following
Boot. These are compressed demo times, not a real 25-minute activity.

Only after confirming the physical board is XIAO ESP32S3 with Seeed Round
Display (BOARD_SCREEN_COMBO=501), upload with
`pio run -e orbit_p0a -t upload --upload-port <confirmed USB port>`.
Do not guess the port or alter wiring while powered. If the display is another
model, stop and confirm its driver/pinout before uploading.

Physical acceptance: verify full-screen colors, orientation, the three scenes,
countdown updates, ten repeat cycles and reset recovery. Photograph each scene
with DEMO visible for the report. No USB board was detected during development;
this delivery does not claim flashing or real-panel acceptance.
