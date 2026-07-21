# Nommac agent guide

## Product principles

- Nommac is a small native macOS menu-bar utility for quieter audio.
- Attenuation belongs to the currently selected output and is remembered independently for each device.
- New outputs must start at `0 dB` bypass. Never carry one device's attenuation onto another.
- Follow macOS output selection; never take over device switching.

## Experience

- Keep the menu minimal, native, and immediately understandable.
- Preserve accessibility labels, keyboard operation, and familiar macOS shortcuts.
- Prefer system controls and SF Symbols over custom UI where they fit.

## Safety and privacy

- Never change the user's system output, hardware volume, or mute state during testing without explicit permission.
- Do not move the pointer or automate visible UI without telling the user first.
- Nommac processes audio in memory. Do not add recording, analytics, telemetry, or network behavior.

## Working in this repository

- Keep files and changes small and focused.
- Run `make test` for logic changes and `make ci-build` for packaging changes.
- Treat `Resources/Nommac.icon` as the only app-icon source.
- Preserve unrelated local changes and never commit credentials or signing material.

## Releases

- Semantic version tags such as `v1.0.0` trigger signed, notarized GitHub releases.
- Do not create or push a release tag unless the user explicitly requests that release.
- Keep release secrets in GitHub Actions and local `.env.release` files only.
