import AppKit
import SwiftUI

struct NommacStatusLabel: View {
    var body: some View {
        Label("Nommac", systemImage: "hifispeaker")
    }
}

struct NommacMenu: View {
    @Bindable var model: NommacModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if model.isConnected {
                volumeSlider
                Divider()
                equalizer
                Divider()
                powerControls
            } else {
                disconnectedNotice
            }

            Divider()
            footer
        }
        .padding(14)
        .frame(width: 300)
        .onAppear { model.refresh() }
    }

    private var header: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(model.isConnected ? Color.razerGreen : Color.secondary.opacity(0.4))
                .frame(width: 8, height: 8)
            Text("Razer Nommo V2 X")
                .font(.headline)
            Spacer()
            if let error = model.lastErrorDescription {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
                    .help(error)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Razer Nommo V2 X, \(model.isConnected ? "connected" : "not connected")"
        )
    }

    private var disconnectedNotice: some View {
        Text("Speakers not connected")
            .font(.callout)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 48)
    }

    private var volumeSlider: some View {
        HStack(spacing: 10) {
            Image(systemName: "speaker.wave.2.fill")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            Slider(
                value: Binding(
                    get: { Double(model.volume) },
                    set: { model.setVolume(Int($0)) }
                ),
                in: 0 ... 100
            )
            .tint(.razerGreen)
            .accessibilityLabel("Volume")
            .accessibilityValue("\(model.volume) percent")

            Text("\(model.volume)")
                .font(.caption.monospacedDigit())
                .frame(width: 28, alignment: .trailing)
        }
    }

    private var equalizer: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Equalizer")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                presetPicker
            }

            HStack(spacing: 4) {
                ForEach(0 ..< NommoDevice.bandCount, id: \.self) { index in
                    EQBandSlider(
                        label: NommoDevice.bandLabels[index],
                        gainDecibels: model.bandGainsDecibels[index],
                        range: -12 ... 12,
                        onChange: { model.setBandGain(index: index, decibels: $0) }
                    )
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private var presetPicker: some View {
        Menu {
            ForEach(NommoPreset.allCases) { preset in
                Button {
                    model.selectPreset(preset)
                } label: {
                    if !model.isCustomPreset, model.presetRawValue == preset.rawValue {
                        Label(preset.title, systemImage: "checkmark")
                    } else {
                        Text(preset.title)
                    }
                }
            }
            Divider()
            Button {
                model.selectNightPreset()
            } label: {
                if model.isNightPreset {
                    Label("Night", systemImage: "checkmark")
                } else {
                    Text("Night")
                }
            }
        } label: {
            Text(currentPresetTitle)
                .font(.caption)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .accessibilityLabel("Equalizer preset")
        .accessibilityValue(currentPresetTitle)
    }

    private var currentPresetTitle: String {
        if model.isNightPreset { return "Night" }
        if model.isCustomPreset { return "Custom" }
        return NommoPreset(rawValue: model.presetRawValue)?.title ?? "Preset \(model.presetRawValue)"
    }

    private var powerControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Eco Mode")
                Spacer()
                Toggle("Eco Mode", isOn: Binding(
                    get: { model.ecoEnabled },
                    set: model.setEco
                ))
                .toggleStyle(.switch)
                .controlSize(.mini)
                .tint(.razerGreen)
                .labelsHidden()
            }

            HStack {
                Text("Auto Sleep")
                Spacer()
                Picker("Auto Sleep", selection: Binding(
                    get: { model.sleepTimeoutMinutes },
                    set: { model.setSleepTimeout(minutes: $0) }
                )) {
                    Text("Never").tag(0)
                    ForEach([15, 30, 45], id: \.self) { minutes in
                        Text("\(minutes) min").tag(minutes)
                    }
                    if ![0, 15, 30, 45].contains(model.sleepTimeoutMinutes) {
                        Text("\(model.sleepTimeoutMinutes) min").tag(model.sleepTimeoutMinutes)
                    }
                }
                .labelsHidden()
                .fixedSize()
            }
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle("Launch at Login", isOn: Binding(
                get: { model.isLaunchAtLoginEnabled },
                set: model.setLaunchAtLogin
            ))

            HStack {
                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    HStack(alignment: .center, spacing: 4) {
                        Image(systemName: "power")
                            .accessibilityHidden(true)
                        Text("Quit")
                    }
                    .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .keyboardShortcut("Q", modifiers: .command)

                Spacer()

                Link(destination: URL(string: "https://github.com/pablopunk/nommac")!) {
                    Image(systemName: "heart.fill")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .accessibilityLabel("Open Nommac on GitHub")
                .help("Open Nommac on GitHub")
            }
        }
    }
}
