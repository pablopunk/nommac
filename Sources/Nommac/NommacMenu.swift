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

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "power")
                    Text("Quit")
                    Text("⌘Q")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 7)
                .background(.quaternary.opacity(0.5))
                .clipShape(.rect(cornerRadius: 7))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .keyboardShortcut("Q", modifiers: .command)
        }
        .padding(14)
        .frame(width: 252)
    }
}
