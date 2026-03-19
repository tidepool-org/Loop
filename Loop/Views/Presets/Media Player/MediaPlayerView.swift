//
//  MediaPlayerView.swift
//  Podcast Demo
//
//  Created by Cameron Ingham on 3/11/25.
//

import AVKit
import LoopKit
import SwiftUI

struct MediaPlayerView: View {
    
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(\.dismiss) var dismiss
    
    @State var player: AVAudioPlayer
    
    let media: MediaContent
    
    @State private var minHeight: Double
    @State private var sheetHeight: Double
    @State private var miniPlayer: Bool

    @State var captionsEnabled: Bool
    
    @State var isPaused: Bool
    @State var currentTime: TimeInterval
    
    init(
        media: MediaContent,
        minHeight: Double = 0,
        sheetHeight: Double = 0,
        miniPlayer: Bool = false,
        captionsEnabled: Bool = false
    ) {
        self.player = try! AVAudioPlayer(contentsOf: media.audio)
        self.media = media
        self.minHeight = minHeight
        self.sheetHeight = sheetHeight
        self.miniPlayer = miniPlayer
        self.captionsEnabled = captionsEnabled
        self.isPaused = true
        self.currentTime = 0
    }
    
    var dragGesture: some Gesture {
        DragGesture(coordinateSpace: .global)
            .onChanged { value in
                withAnimation(.default.speed(10)) {
                    sheetHeight = max(minHeight, UIScreen.main.bounds.height - value.location.y)
                }
            }
            .onEnded { value in
                withAnimation(reduceMotion ? nil : .default) {
                    sheetHeight = (UIScreen.main.bounds.height - value.location.y).findClosest(in: [minHeight, UIScreen.main.bounds.height / 2, UIScreen.main.bounds.height])
                }
            }
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                ZStack(alignment: .topTrailing) {
                    Group {
                        VideoView(isPaused: $isPaused, media: media)
                            .centerCropped()
                    }
                    .edgesIgnoringSafeArea(.all)
                    .padding(.bottom, sheetHeight)

                    Button {
                        dismiss()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.secondary)
                                .frame(width: 24, height: 24)
                            
                            Image(systemName: "xmark")
                                .font(.caption.weight(.semibold))
                                .fontDesign(.rounded)
                                .foregroundColor(Color(UIColor.secondarySystemBackground))
                        }
                        .padding(20)
                        .contentShape(Circle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .accessibilityLabel(Text("Close"))
                    .opacity(sheetHeight <= UIScreen.main.bounds.height - 130 ? 1 : 0)
                    .animation(.default, value: sheetHeight)
                    .padding(.top, -16)
                }
                
                VStack(spacing: 16) {
                    if captionsEnabled && sheetHeight <= UIScreen.main.bounds.height - 190 {
                        CaptionsView(currentTime: $currentTime, captions: media.closedCaptions)
                            .padding(.horizontal)
                    }
                    
                    SheetView(
                        minHeight: $minHeight,
                        sheetHeight: $sheetHeight,
                        miniPlayer: $miniPlayer,
                        isPaused: $isPaused,
                        currentTime: $currentTime,
                        captionsEnabled: $captionsEnabled,
                        media: media,
                        player: player,
                        topSafeAreaInset: miniPlayer ? geometry.safeAreaInsets.top : 0
                    )
                    .frame(height: sheetHeight)
                    .gesture(media.transcript != nil ? dragGesture : nil)
                }
            }
            .onChange(of: minHeight) { _, newValue in
                if sheetHeight == 0 {
                    sheetHeight = newValue
                }
            }
            .onChange(of: sheetHeight) { _, newValue in
                withAnimation(reduceMotion ? nil : .default) {
                    miniPlayer = newValue >= (UIScreen.main.bounds.height - geometry.safeAreaInsets.top)
                }
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

struct SheetView: View {
    
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    
    @Binding var minHeight: Double
    @Binding var sheetHeight: Double
    @Binding var miniPlayer: Bool
    @Binding var isPaused: Bool
    @Binding var currentTime: TimeInterval
    @Binding var captionsEnabled: Bool
    
    @State var scrollPosition: TranscriptExcerpt?
    
    let media: MediaContent
    let player: AVAudioPlayer
    let topSafeAreaInset: Double
    
    init(
        minHeight: Binding<Double>,
        sheetHeight: Binding<Double>,
        miniPlayer: Binding<Bool>,
        isPaused: Binding<Bool>,
        currentTime: Binding<TimeInterval>,
        captionsEnabled: Binding<Bool>,
        media: MediaContent,
        player: AVAudioPlayer,
        topSafeAreaInset: Double
    ) {
        self._minHeight = minHeight
        self._sheetHeight = sheetHeight
        self._miniPlayer = miniPlayer
        self._isPaused = isPaused
        self._currentTime = currentTime
        self._captionsEnabled = captionsEnabled
        self.media = media
        self.player = player
        self.topSafeAreaInset = topSafeAreaInset
    }
    
    var body: some View {
        VStack(spacing: 0) {
            PlayerControls(player: player, height: $minHeight, mini: $miniPlayer, isPaused: $isPaused, currentTime: $currentTime, captionsEnabled: $captionsEnabled, media: media)
                .onTapGesture {
                    if miniPlayer {
                        withAnimation(reduceMotion ? nil : .default) {
                            sheetHeight = UIScreen.main.bounds.height / 2
                        }
                    }
                }
            
            if let transcript = media.transcript {
                ScrollViewReader { proxy in
                    ScrollView {
                        TranscriptView(
                            currentTime: $currentTime,
                            transcript: transcript,
                            onExcerptTap: {
                                player.currentTime = $0.startTime
                            },
                            onExcerptChanged: {
                                proxy.scrollTo($0.text, anchor: .top)
                            }
                        )
                        .padding(.horizontal, 20)
                        .padding(.top, 32)
                        .padding(.bottom, topSafeAreaInset + 32)
                    }
                }
            }
        }
        .onDisappear {
            isPaused = true
        }
        .persistentSystemOverlays(.hidden)
    }
}
