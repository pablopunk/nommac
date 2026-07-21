import AppKit

@MainActor
final class GainSliderView: NSView {
    private let slider = NSSlider()
    private let valueLabel = NSTextField(labelWithString: "")
    private let onChange: (Double) -> Void

    init(value: Double, onChange: @escaping (Double) -> Void) {
        self.onChange = onChange
        super.init(frame: NSRect(x: 0, y: 0, width: 236, height: 44))

        slider.minValue = gainDecibelRange.lowerBound
        slider.maxValue = gainDecibelRange.upperBound
        slider.doubleValue = value
        slider.isContinuous = true
        slider.target = self
        slider.action = #selector(sliderChanged)
        slider.setAccessibilityLabel("Attenuation")

        valueLabel.font = .monospacedDigitSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .medium)
        valueLabel.alignment = .right

        slider.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(slider)
        addSubview(valueLabel)

        NSLayoutConstraint.activate([
            slider.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            slider.centerYAnchor.constraint(equalTo: centerYAnchor),
            slider.trailingAnchor.constraint(equalTo: valueLabel.leadingAnchor, constant: -10),
            valueLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            valueLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            valueLabel.widthAnchor.constraint(equalToConstant: 48)
        ])

        setValue(value)
    }

    required init?(coder: NSCoder) {
        nil
    }

    func setValue(_ decibels: Double) {
        let value = clampedGainDecibels(decibels).rounded()
        slider.doubleValue = value
        valueLabel.stringValue = "\(Int(value)) dB"
        slider.setAccessibilityValue("\(Int(value)) decibels")
    }

    @objc private func sliderChanged() {
        let value = slider.doubleValue.rounded()
        setValue(value)
        onChange(value)
    }
}
