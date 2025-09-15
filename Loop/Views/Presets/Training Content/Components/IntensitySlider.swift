//
//  IntensitySlider.swift
//  Loop
//
//  Created by Cameron Ingham on 9/4/25.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//

import SwiftUI

struct IntensitySlider: UIViewRepresentable {
    
    static let thumbnailSize: Double = 32
    static let trackHeight: Double = 8
    
    private struct ThumbnailView: View {
        let color: Color
        
        var body: some View {
            Circle()
                .fill(color)
                .frame(width: IntensitySlider.thumbnailSize, height: IntensitySlider.thumbnailSize)
        }
    }

    private struct TrackView: View {
        var body: some View {
            Rectangle()
                .foregroundColor(.clear)
                .frame(height: IntensitySlider.trackHeight)
                .frame(maxWidth: .infinity)
                .background(DerivedGradientView())
        }
    }
    
    class RoundedSlider: UISlider {
        override func layoutSubviews() {
            super.layoutSubviews()
            self.subviews.first?.subviews.forEach { subview in
                if subview.bounds.height == IntensitySlider.trackHeight {
                    subview.layer.cornerRadius = subview.bounds.height / 2
                    subview.clipsToBounds = true
                }
            }
        }
    }
    
    class Coordinator {
        let minimumValue: Double
        let maximumValue: Double
        
        let value: Binding<Double>
        
        init(value: Binding<Double>, minimumValue: Double = 0, maximumValue: Double = 10) {
            self.value = value
            self.minimumValue = minimumValue
            self.maximumValue = maximumValue
        }
        
        @objc
        func sliderValueChanged(_ slider: UISlider) {
            value.wrappedValue = Double(slider.value)
        }
        
        @objc
        func sliderEditingEnding(_ slider: UISlider) {
            slider.value = Float(Int(value.wrappedValue.rounded()))
        }
    }
    
    @Binding var value: Double
    let snapToInteger: Bool = true
    
    private let trackImage: UIImage? = TrackView().snapshot()
    
    func makeUIView(context: Context) -> RoundedSlider {
        let sliderView = RoundedSlider()
        
        sliderView.minimumValue = Float(context.coordinator.minimumValue)
        sliderView.maximumValue = Float(context.coordinator.maximumValue)
        sliderView.value = Float(value)
        sliderView.setThumbImage(
            ThumbnailView(
                color: thumbColorForValue(
                    value,
                    minimum: context.coordinator.minimumValue,
                    maximum: context.coordinator.maximumValue
                )
            ).snapshot(),
            for: .normal
        )
        sliderView.setMinimumTrackImage(trackImage, for: .normal)
        sliderView.setMaximumTrackImage(trackImage, for: .normal)
        
        sliderView.addTarget(context.coordinator, action: #selector(context.coordinator.sliderValueChanged(_:)), for: .valueChanged)
        
        if snapToInteger {
            sliderView.addTarget(context.coordinator, action: #selector(context.coordinator.sliderEditingEnding(_:)), for: .touchUpInside)
            sliderView.addTarget(context.coordinator, action: #selector(context.coordinator.sliderEditingEnding(_:)), for: .touchUpOutside)
        }
        
        return sliderView
    }
    
    func updateUIView(_ uiView: RoundedSlider, context: Context) {
        uiView.value = Float(value)
        uiView.setThumbImage(
            ThumbnailView(
                color: thumbColorForValue(
                    value,
                    minimum: context.coordinator.minimumValue,
                    maximum: context.coordinator.maximumValue
                )
            ).snapshot(),
            for: .normal
        )
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(value: $value)
    }
    
    private func thumbColorForValue(_ value: Double, minimum: Double, maximum: Double) -> Color {
        DerivedGradientView().color(at: value / (maximum - minimum))
    }
}

extension View {
    func snapshot() -> UIImage? {
        let render = ImageRenderer(content: self)
        render.scale = UIScreen.main.scale
        return render.uiImage
    }
}

private struct DerivedGradientView: View {
    let stops: [Gradient.Stop] = [
        Gradient.Stop(color: Color(red: 0, green: 0.48, blue: 1), location: 0.00),
        Gradient.Stop(color: Color(red: 0.2, green: 0.78, blue: 0.35), location: 0.33),
        Gradient.Stop(color: Color(red: 1, green: 0.58, blue: 0), location: 0.69),
        Gradient.Stop(color: Color(red: 1, green: 0.23, blue: 0.19), location: 1.00),
    ]
    
    let startPoint: UnitPoint = UnitPoint(x: 0, y: 0.5)
    let endPoint: UnitPoint = UnitPoint(x: 1, y: 0.5)
    
    var body: some View {
        LinearGradient(
            stops: stops,
            startPoint: startPoint,
            endPoint: endPoint,
        )
    }
    
    func color(at value: Double) -> Color {
        let clampedLocation = min(max(value, 0.0), 1.0)
        
        guard let upper = stops.first(where: { $0.location >= clampedLocation }) else {
            return stops.last?.color ?? .clear
        }
        
        guard let lower = stops.last(where: { $0.location <= clampedLocation }) else {
            return stops.first?.color ?? .clear
        }
        
        if lower.location == upper.location {
            return lower.color
        }
        
        let progress = (clampedLocation - lower.location) / (upper.location - lower.location)
        
        let lowerUIColor = UIColor(lower.color)
        let upperUIColor = UIColor(upper.color)
        
        var lowerRed: CGFloat = 0
        var lowerGreen: CGFloat = 0
        var lowerBlue: CGFloat = 0
        var lowerAlpha: CGFloat = 0
        
        var upperRed: CGFloat = 0
        var upperGreen: CGFloat = 0
        var upperBlue: CGFloat = 0
        var upperAlpha: CGFloat = 0
        
        lowerUIColor.getRed(&lowerRed, green: &lowerGreen, blue: &lowerBlue, alpha: &lowerAlpha)
        upperUIColor.getRed(&upperRed, green: &upperGreen, blue: &upperBlue, alpha: &upperAlpha)
        
        return Color(
            red: (1 - progress) * lowerRed + progress * upperRed,
            green: (1 - progress) * lowerGreen + progress * upperGreen,
            blue: (1 - progress) * lowerBlue + progress * upperBlue,
            opacity: (1 - progress) * lowerAlpha + progress * upperAlpha
        )
    }
}

struct IntensityInfo: View {
    
    @State private var lastValue: Double = 0
    @State private var value: Double = 0

    var body: some View {
        VStack(spacing: 2) {
            Text(value.rounded().formatted())
                .contentTransition(.numericText(countsDown: lastValue > value))
                .font(.system(size: UIFontMetrics.default.scaledValue(for: 64)).weight(.heavy))
                .padding(.bottom, 16)
            
            HStack {
                Text("0")
                
                Spacer()
                
                Text("10")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            
            IntensitySlider(value: $value.animation(.easeInOut))
            
            HStack {
                Text("Very Easy")
                
                Spacer()
                
                Text("All Out")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .onChange(of: value) { oldValue, _ in
            lastValue = oldValue
        }
        
        InsetContent {
            VStack(spacing: 0) {
                title
                    .font(.title2.bold())
                    .padding(.bottom, 16)
                
                message
                    .padding(.bottom, 8)
                
                glucoseChange
            }
            .multilineTextAlignment(.center)
        }
    }
    
    var title: Text {
        switch Int(value.rounded()) {
        case 0: Text("No Activity")
        case 1...2: Text("Light Intensity (Aerobic)")
        case 3...8: Text("Medium Intensity (Aerobic)")
        case 9: Text("High Intensity (Anaerobic)")
        case 10: Text("Maximum Intensity (Anaerobic)")
        default: Text("Unsupported")
        }
    }
    
    var message: Text {
        switch Int(value.rounded()) {
        case 0: Text("Sitting or laying down, no change in breathing.")
        case 1...2: Text("Easy breath. Can carry on a conversation.")
        case 3...5: Text("Breathing more heavily. Can carry on a conversation, but requires more effort.")
        case 6...8: Text("Breathing is slightly uncomfortable. Conversation requires maximal effort.")
        case 9: Text("Difficulty maintaining exercise or holding a conversation.")
        case 10: Text("Full out effort. No conversation possible.")
        default: Text("Unsupported")
        }
    }
    
    var glucoseChange: Text {
        switch Int(value.rounded()) {
        case 0: Text("No change in glucose.")
        case 1...8: Text("May experience drops in glucose.")
        case 9...10: Text("May experience a rise in glucose.")
        default: Text("Unsupported")
        }
    }
}
