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

            Button("Quit Nommac") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .frame(width: 252)
    }
}
