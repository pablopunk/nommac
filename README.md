# Nommo Night

A native macOS attenuator for the Razer Nommo V2 X. It never changes the default audio device: processing activates only while macOS has already selected the Nommo.

The included `nommo-audio` probe reports the hardware volume range exposed through CoreAudio. On the tested device, that range is only -28.38 dB to -0.06 dB, which explains the abrupt jump from mute to an overly loud minimum.

## Build

```sh
make test
make run
```

The menu offers -12, -18, -24, and -30 dB attenuation. Nommo Night observes macOS's default output but never changes it.
