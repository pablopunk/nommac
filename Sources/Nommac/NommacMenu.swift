import AppKit
import SwiftUI

struct NommacStatusLabel: View {
    var body: some View {
        Label("Nommac", systemImage: "hifispeaker")
    }
}

struct NommacMenu: View {
    let model: NommacModel

    private var gainBinding: Binding<Double> {
        Binding(
            get: { model.gainDecibels },
            set: model.setGain
        )
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { model.isLaunchAtLoginEnabled },
            set: model.setLaunchAtLogin
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(model.statusTitle)
                .font(.headline)

            HStack(spacing: 10) {
                Slider(value: gainBinding, in: gainDecibelRange, step: 1)
                    .disabled(model.outputName == nil)
                    .accessibilityLabel("Attenuation")
                    .accessibilityValue("\(Int(model.gainDecibels)) decibels")

                Text("\(Int(model.gainDecibels)) dB")
                    .font(.caption.monospacedDigit())
                    .frame(width: 46, alignment: .trailing)
            }

            Divider()

            Toggle("Launch at Login", isOn: launchAtLoginBinding)

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
        .padding(14)
        .frame(width: 252)
    }
}
