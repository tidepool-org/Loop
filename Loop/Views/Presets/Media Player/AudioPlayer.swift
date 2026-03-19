//
//  AudioPlayer.swift
//  Podcast Demo
//
//  Created by Cameron Ingham on 3/20/25.
//

import AVKit
import LoopKit
import SwiftUI

struct AudioPlayerView: View {
    var fileName: String?
    var url: URL?
    
    @State private var player: AVAudioPlayer?
    @State private var isPlaying = false
    @State private var totalTime: TimeInterval = 0.0
    @State private var currentTime: TimeInterval = 0.0
    
    var body: some View {
        VStack {
            if let player = player {
                Text(fileName ?? "File")
                
                HStack {
                    Button(action: {
                        isPlaying.toggle()
                        if isPlaying {
                            player.play()
                        } else {
                            player.pause()
                        }
                    }) {
                        Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.largeTitle)
                    }
                    .buttonStyle(PlainButtonStyle())

                    Slider(value: Binding(get: {
                        currentTime
                    }, set: { newValue in
                        player.currentTime = newValue
                        currentTime = newValue
                    }), in: 0...totalTime)
                    .accentColor(.blue)
                }
                
                HStack {
                    Text("\(formatTime(currentTime))")
                    Spacer()
                    Text("\(formatTime(totalTime))")
                }
                .padding(.horizontal)
            }
        }
        .onAppear {
            if let url = url {
                setupAudio(withURL: url)
            }
        }
        .onReceive(Timer.publish(every: 0.01, on: .main, in: .common).autoconnect()) { _ in
            updateProgress()
        }
        .onDisappear {
            player?.stop()
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let seconds = Int(time) % 60
        let minutes = Int(time) / 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func setupAudio(withURL url: URL) {
        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.prepareToPlay()
            totalTime = player?.duration ?? 0.0
        } catch {
            print("Error loading audio: \(error)")
        }
    }

    private func updateProgress() {
        guard let player = player, player.isPlaying else { return }
        currentTime = player.currentTime
    }
}
