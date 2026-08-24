# Nommac agent guide

## Product principles

- Nommac is a small native macOS menu-bar control panel for Razer Nommo V2 X speakers (USB 1532:055E).
- It replaces Razer Synapse on macOS: volume, 10-band EQ, presets, eco mode, and auto-sleep timeout over USB HID feature reports.
- Settings live in the speaker firmware, not the app. Always read state from the device; never cache it as the source of truth.
- The protocol is documented in `Sources/Nommac/RazerReport.swift` and https://github.com/openrazer/openrazer/issues/2758.
- Firmware quirk: writing the sleep timeout forces eco mode back on. `setSleepTimeout` must keep saving and restoring the eco flag.

## Experience

- Keep the menu minimal and native, with Razer green (`Color.razerGreen`) used only as an accent — never recreate Synapse's look.
- Preserve accessibility labels, keyboard operation, and familiar macOS shortcuts.
- Prefer system controls and SF Symbols over custom UI where they fit.

## Safety and privacy

- All device writes are user-initiated. Never change speaker state during testing without explicit permission.
- Do not add recording, analytics, telemetry, or network behavior. The app needs no macOS privacy permissions; keep it that way.

## Working in this repository

- Keep files and changes small and focused.
- Run `make test` for logic changes and `make ci-build` for packaging changes.
- Treat `Resources/Nommac.icon` as the only app-icon source.
- Preserve unrelated local changes and never commit credentials or signing material.

## Releases

- Semantic version tags such as `v1.0.0` trigger signed, notarized GitHub releases.
- Do not create or push a release tag unless the user explicitly requests that release.
- Keep release secrets in GitHub Actions and local `.env.release` files only.
