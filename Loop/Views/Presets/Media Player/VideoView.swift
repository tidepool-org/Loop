//
//  VideoView.swift
//  Podcast Demo
//
//  Created by Cameron Ingham on 3/20/25.
//

import AVKit
import LoopKit
import SwiftUI

struct VideoView: View {
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    @Binding var isPaused: Bool
    
    let media: MediaContent

    var body: some View {
        _VideoPlayer(media: media, isPaused: $isPaused)
    }
}

struct _VideoPlayer : UIViewControllerRepresentable {
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    private let player: AVPlayer
    
    @Binding private var isPaused: Bool
    
    init(media: MediaContent, isPaused: Binding<Bool>) {
        self.player = AVPlayer(url: media.animation)
        self._isPaused = .init(projectedValue: isPaused)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(player: player, reduceMotion: reduceMotion)
    }
   
    func makeUIViewController(context: UIViewControllerRepresentableContext<_VideoPlayer>) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = false
        controller.videoGravity = .resizeAspectFill
        controller.allowsPictureInPicturePlayback = false
        return controller
    }
   
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: UIViewControllerRepresentableContext<_VideoPlayer>) {
        if !reduceMotion {
            if isPaused {
                uiViewController.player?.pause()
            } else {
                uiViewController.player?.play()
            }
        } else {
            uiViewController.player?.pause()
        }
    }
    
    class Coordinator: NSObject {
        
        private let player: AVPlayer
        private let reduceMotion: Bool
        
        init(player: AVPlayer, reduceMotion: Bool) {
            self.player = player
            self.reduceMotion = reduceMotion
            
            super.init()
            
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(playerItemDidReachEnd(notification:)),
                name: AVPlayerItem.didPlayToEndTimeNotification,
                object: player.currentItem
            )
        }
        
        @objc
        private func playerItemDidReachEnd(notification: Notification) {
            if let playerItem: AVPlayerItem = notification.object as? AVPlayerItem {
                playerItem.seek(to: .zero) { _ in }
                
                if !reduceMotion {
                    player.play()
                }
            }
        }
    }
}
