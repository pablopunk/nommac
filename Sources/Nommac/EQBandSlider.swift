import SwiftUI

extension Color {
    static let razerGreen = Color(red: 0x44 / 255, green: 0xD6 / 255, blue: 0x2C / 255)
}

/// Vertical gain bar for one EQ band. Fills from the 0 dB center line,
/// drag to set, double-tap to reset the band.
struct EQBandSlider: View {
    let label: String
    let gainDecibels: Int
    let range: ClosedRange<Int>
    let onChange: (Int) -> Void

    private let trackWidth: CGFloat = 6
    private let trackHeight: CGFloat = 96

    var body: some View {
        VStack(spacing: 5) {
            track
                .frame(width: 18, height: trackHeight)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { onChange(gain(atY: $0.location.y)) }
                )
                .onTapGesture(count: 2) { onChange(0) }

            Text(label)
                .font(.system(size: 8.5, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .accessibilityElement()
        .accessibilityLabel("\(label) hertz band")
        .accessibilityValue("\(gainDecibels) decibels")
        .accessibilityAdjustableAction { direction in
            let step = direction == .increment ? 1 : -1
            onChange((gainDecibels + step).clamped(to: range))
        }
    }

    private var track: some View {
        ZStack {
            Capsule()
                .fill(.quaternary)
                .frame(width: trackWidth)

            Capsule()
                .fill(Color.razerGreen.gradient)
                .frame(width: trackWidth, height: max(fillHeight, trackWidth))
                .offset(y: fillOffset)

            Circle()
                .fill(.white)
                .frame(width: 11, height: 11)
                .shadow(radius: 1, y: 0.5)
                .offset(y: knobOffset)
        }
    }

    private var unitHeight: CGFloat {
        (trackHeight / 2) / CGFloat(range.upperBound)
    }

    private var fillHeight: CGFloat {
        CGFloat(abs(gainDecibels)) * unitHeight
    }

    private var fillOffset: CGFloat {
        CGFloat(-gainDecibels) * unitHeight / 2
    }

    private var knobOffset: CGFloat {
        CGFloat(-gainDecibels) * unitHeight
    }

    private func gain(atY y: CGFloat) -> Int {
        let decibels = Int(((trackHeight / 2 - y) / unitHeight).rounded())
        return decibels.clamped(to: range)
    }
}

extension Int {
    func clamped(to range: ClosedRange<Int>) -> Int {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
