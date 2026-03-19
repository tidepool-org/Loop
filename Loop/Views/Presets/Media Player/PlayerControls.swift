//
//  PlayerControls.swift
//  Podcast Demo
//
//  Created by Cameron Ingham on 2/27/25.
//

import AVKit
import LoopKit
import SwiftUI

struct PlayerControls: View {
    
    @Namespace var animation

    @State private var totalTime: TimeInterval
    @State private var playbackSpeed: Double
    
    @Binding var height: Double
    @Binding var mini: Bool
    @Binding var isPaused: Bool
    @Binding var currentTime: TimeInterval
    @Binding var captionsEnabled: Bool
    
    let media: MediaContent
    let player: AVAudioPlayer
    
    init(
        player: AVAudioPlayer,
        totalTime: TimeInterval = 0,
        playbackSpeed: Double = 1,
        height: Binding<Double>,
        mini: Binding<Bool>,
        isPaused: Binding<Bool>,
        currentTime: Binding<TimeInterval>,
        captionsEnabled: Binding<Bool>,
        media: MediaContent
    ) {
        self.player = player
        self.totalTime = totalTime
        self.playbackSpeed = playbackSpeed
        self._height = height
        self._mini = mini
        self._isPaused = isPaused
        self._currentTime = currentTime
        self._captionsEnabled = captionsEnabled
        self.media = media
    }
        
    var timeRemaining: TimeInterval {
        totalTime - currentTime
    }
    
    var progress: Double {
        guard totalTime > 0 else {
            return 1.0
        }
        
        let percentage = currentTime / totalTime
        
        return min(max(percentage, 0.0), 1.0)
    }
    
    @ViewBuilder
    func playbackSpeedLabel(_ speed: Double) -> some View {
        ZStack(alignment: .leading) {
            // Added so the menu button takes the width of the largest option so the parent HStack doesn't shift the other elements.
            Group { Text("0.5") + Text(Image(systemName: "xmark")).font(.caption2) }.opacity(0)
            
            switch speed {
            case 0.5: Text("0.5") + Text(Image(systemName: "xmark")).font(.caption2)
            case 1: Text("1") + Text(Image(systemName: "xmark")).font(.caption2)
            case 2: Text("2") + Text(Image(systemName: "xmark")).font(.caption2)
            default:  Text("\(Int(speed))") + Text(Image(systemName: "xmark")).font(.caption2)
            }
        }
    }
    
    @ViewBuilder
    func playbackSpeedText(_ speed: Double) -> some View {
        switch speed {
        case 0.5: Text("0.5x")
        case 1: Text("1x")
        case 2: Text("2x")
        default: Text("\(Int(speed))x")
        }
    }
    
    func playbackSpeedMenuOptions() -> [Double] {
        if playbackSpeed == 1 {
            return [2, 0.5]
        } else if playbackSpeed == 0.5 {
            return [2, 1]
        } else {
            return [1, 0.5]
        }
    }
    
    @ViewBuilder
    var fullMetadata: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(media.metadata.title)
                .multilineTextAlignment(.leading)
                .font(.title3.bold())
                .frame(maxWidth: .infinity, alignment: .leading)
                .matchedGeometryEffect(id: "title", in: animation)
                .fixedSize(horizontal: false, vertical: true)
            
            Text("by \(media.metadata.author)")
                .multilineTextAlignment(.leading)
                .matchedGeometryEffect(id: "subtitle", in: animation)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(.primary)
    }
    
    @ViewBuilder
    var miniMetadata: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(media.metadata.title)
                .multilineTextAlignment(.leading)
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .matchedGeometryEffect(id: "title", in: animation)
                .fixedSize(horizontal: false, vertical: true)
            
            Text("by \(media.metadata.author)")
                .multilineTextAlignment(.leading)
                .matchedGeometryEffect(id: "subtitle", in: animation)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(.white)
    }
    
    @ViewBuilder
    var fullTimeline: some View {
        VStack(spacing: 2) {
            Slider(
                value: Binding(
                    get: {
                        progress
                    },
                    set: { newValue, _ in
                        player.currentTime = min(max(newValue, 0.0), 1.0) * totalTime
                    }
                ),
                in: 0...1
            )
                .onAppear {
                    let size = CGSize(width: 12, height: 12)
                    let image = UIGraphicsImageRenderer(size: size).image { _ in
                        UIImage(systemName: "circle.fill")?.draw(in: CGRect(origin: .zero, size: size))
                    }.withRenderingMode(.alwaysTemplate)
                    
                    UISlider.appearance().setThumbImage(image, for: .normal)
                }
                .matchedGeometryEffect(id: "timeline", in: animation)
            HStack {
                Text(formatTime(currentTime))
                
                Spacer()
                
                Text("-") + Text(formatTime(timeRemaining))
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
    
    @ViewBuilder
    var miniTimeline: some View {
        Color.black.opacity(0.3)
            .frame(height: 4)
            .containerRelativeFrame(.horizontal) { size, axis in
                size * progress
            }
            .matchedGeometryEffect(id: "timeline", in: animation)
    }
    
    @ScaledMetric var skipIconSize: Double = 24
    @ScaledMetric var largePlayPauseIconSize: Double = 48
    @ScaledMetric var miniPlayPauseIconSize: Double = 27
    
    @ViewBuilder
    var fullControls: some View {
        HStack {
            Menu {
                ForEach(playbackSpeedMenuOptions(), id: \.self) { speed in
                    Button {
                        playbackSpeed = speed
                    } label: {
                        playbackSpeedText(speed)
                    }
                }
            } label: {
                playbackSpeedLabel(playbackSpeed)
            }
            .tint(Color(UIColor.systemGray))
            
            Spacer()
            
            HStack(spacing: 32) {
                Button {
                    player.currentTime -= 15
                } label: {
                    Text(Image(systemName: "15.arrow.trianglehead.counterclockwise"))
                        .font(.system(size: skipIconSize))
                }
                .tint(Color(UIColor.systemGray))
                
                Button {
                    isPaused.toggle()
                } label: {
                    Text(Image(systemName: isPaused ? "play.circle.fill" : "pause.circle.fill"))
                        .font(.system(size: largePlayPauseIconSize))
                        .transition(.symbolEffect)
                }
                .matchedGeometryEffect(id: "playButton", in: animation)
                
                Button {
                    player.currentTime += 15
                } label: {
                    Text(Image(systemName: "15.arrow.trianglehead.clockwise"))
                        .font(.system(size: skipIconSize))
                }
                .tint(Color(UIColor.systemGray))
            }
            
            Spacer()
            
            Button {
                withAnimation {
                    captionsEnabled.toggle()
                }
            } label: {
                Image(systemName: "captions.bubble")
            }
            .tint(captionsEnabled ? .accentColor : Color(UIColor.systemGray))
        }
    }
    
    @ViewBuilder
    var miniControls: some View {
        Button {
            isPaused.toggle()
        } label: {
            Text(Image(systemName: isPaused ? "play.circle.fill" : "pause.circle.fill"))
                .font(.system(size: miniPlayPauseIconSize))
                .transition(.symbolEffect)
        }
        .tint(.white)
        .matchedGeometryEffect(id: "playButton", in: animation)
    }
    
    var body: some View {
        Group {
            if mini {
                VStack(alignment: .leading, spacing: 24) {
                    HStack(spacing: 0) {
                        miniMetadata
                        
                        Spacer()
                        
                        miniControls
                    }
                    .padding(.horizontal, 20)
                    
                    miniTimeline
                }
                .padding(.top, 24)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    fullMetadata
                        .padding(.bottom, 16)
                    
                    fullTimeline
                        .padding(.bottom, 4)
                    
                    fullControls
                }
                .padding(20)
                .padding(.bottom, 12)
                .background {
                    GeometryReader { proxy in
                        Color.clear
                            .onAppear {
                                height = proxy.size.height
                            }
                    }
                }
            }
        }
        .background {
            Group {
                mini ? Color.accentColor : Color(UIColor.systemBackground)
            }
            .ignoresSafeArea(edges: .top)
            .shadow(color: .secondary.opacity(0.2) , radius: 3, y: 2)
        }
        .onAppear {
            player.prepareToPlay()
            player.enableRate = true
            try? AVAudioSession.sharedInstance().setCategory(.playback)
            try? AVAudioSession.sharedInstance().setActive(true)
            totalTime = player.duration
        }
        .onChange(of: isPaused) { _, newValue in
            if isPaused {
                player.pause()
            } else {
                player.play()
            }
        }
        .onChange(of: playbackSpeed) { _, newValue in
            player.rate = Float(newValue)
        }
        .onReceive(Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()) { _ in
            currentTime = player.currentTime
            
            if player.isPlaying == false {
                isPaused = true
            }
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let seconds = Int(time) % 60
        let minutes = Int(time) / 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
