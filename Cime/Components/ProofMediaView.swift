///  Shows a saved proof (photo, video or voice note) from raw bytes.

import AVKit
import SwiftUI

/// Renders proof media from raw `Data`
struct ProofMediaView: View {
    let data: Data?
    let kind: ProofKind

    var body: some View {
        Group {
            switch kind {
            case .photo:
                PhotoProof(data: data)
            case .video:
                if let data {
                    MediaPlayerView(data: data, ext: "mp4", autoplay: true)
                } else {
                    Theme.secondary
                }
            case .audio:
                VStack(spacing: 4) {
                    Text("♪").displayFont(22).foregroundStyle(Theme.summit)
                    if let data {
                        MediaPlayerView(data: data, ext: "m4a", autoplay: false)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.secondary)
            }
        }
    }
}

private struct PhotoProof: View {
    let data: Data?
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Theme.secondary
            }
        }
        .task(id: data) {                         // re-runs whenever `data` changes
            image = data.flatMap { UIImage(data: $0) }
        }
    }
}

/// Writes bytes to a temp file, gives out an AVPlayer, and deletes the file again
final class TempMediaPlayer {
    let player: AVPlayer
    private let url: URL

    init?(data: Data, ext: String) {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).\(ext)")
        guard (try? data.write(to: url)) != nil else { return nil }
        self.url = url
        // .playback makes sound play even when the phone's silent switch is on
        try? AVAudioSession.sharedInstance().setCategory(.playback)
        self.player = AVPlayer(url: url)
    }

    deinit { try? FileManager.default.removeItem(at: url) }
}

/// Plays video or audio bytes with the system player controls
private struct MediaPlayerView: View {
    let data: Data
    let ext: String              // "mp4" or "m4a"
    var autoplay = false         // start playing as soon as it appears

    @State private var holder: TempMediaPlayer?

    var body: some View {
        Group {
            if let holder {
                VideoPlayer(player: holder.player)
            } else {
                Theme.secondary
            }
        }
        .task {
            guard holder == nil else { return }       // don't write the file again on every appear
            holder = TempMediaPlayer(data: data, ext: ext)
            if autoplay { holder?.player.play() }
        }
        .onDisappear { holder?.player.pause() }
    }
}
