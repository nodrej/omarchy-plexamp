# Changelog

## Unreleased

- Reduce CPU use during playback by updating the position once a second and
  advancing the bar's progress hairline without animation.

## 0.2.0 — 2026-09-20

- Add a hairline playback progress bar under the chip (`showProgress`), driven
  by the position the panel's seek bar already interpolates.
- Add `labelFormat`, a template over `{title}` / `{artist}` / `{album}`. A
  separator stranded by an empty field is dropped, while a hyphen inside a
  name is left alone.
- Add `monitorMode` (`all` / `focused` / `named`) with a `monitors` list, so
  the chip need not appear on every monitor's bar.
- Make middle click configurable (`middleClick`); it was hardcoded to next.
- Fix a `TypeError` on every shell restart: the 250 ms position timer fired
  against a null root while the service was being torn down.
- Add a settings gear to the top-right of the player panel. It flips the panel
  to a settings view with the long-track-name control, and writes the choice
  back through `omarchy bar set` — `settings` itself is read-only.
- Add `labelMode` (`full` / `scroll` / `truncate`). `full` drops the width cap
  so the whole `title · artist` shows — the setting worth having on a wide
  monitor. `scrollLabel` is still honoured when `labelMode` is unset.
- Fix the marquee: it ran from fully off-right to fully off-left, so the label
  was never aligned and any glance caught a fragment mid-flight. It now holds
  at the start, scrolls only far enough to expose the tail, then holds again.

## 0.1.0 — 2026-09-20

First release.

- Bar chip with cover art, play state, and a scrolling `title · artist` label
- Player panel: large cover, seek bar with drag-to-scrub, transport, shuffle,
  repeat, volume, and an Open Plexamp button
- Launcher state when Plexamp is closed
- One `plexamp` IPC target covering playback, the panel, and launching
- Nine inline settings covering visibility, click and scroll mapping, label
  width and scrolling, seek step, and the launch command
