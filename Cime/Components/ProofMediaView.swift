import AVKit
import SwiftUI

/// Renders proof media (photo, video, or audio) from raw bytes.
struct ProofMediaView: View {
    let jpeg: Data?
    let kind: ProofKind

    var body: some View {
        Group {
            switch kind {
            case .photo:
                if let jpeg, let ui = UIImage(data: jpeg) {
                    Image(uiImage: ui).resizable().scaledToFill()
                } else {
                    Theme.secondary
                }
            case .video:
                if let jpeg {
                    MediaPlayerView(data: jpeg, ext: "mp4", autoplay: true)
                } else {
                    Theme.secondary
                }
            case .audio:
                VStack(spacing: 4) {
                    Text("♪").displayFont(22).foregroundStyle(Theme.summit)
                    if let jpeg {
                        MediaPlayerView(data: jpeg, ext: "m4a", autoplay: false)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.secondary)
            }
        }
    }
}

/// Writes media bytes to a temp file and plays them with `AVPlayer`
private struct MediaPlayerView: View {
    let data: Data
    let ext: String         // file extension (mp4 or m4a)
    var autoplay = false    // for automatic playback when visible

    @State private var player: AVPlayer?

    var body: some View {
        VideoPlayer(player: player)
            .onAppear(perform: setupPlayer)
            .onDisappear { player?.pause() }
    }

    /// Creates a temporary file for `data` and prepares the `AVPlayer`
    private func setupPlayer() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).\(ext)")
        try? data.write(to: url)
        let newPlayer = AVPlayer(url: url)
        player = newPlayer
        if autoplay {
            newPlayer.play()
        }
    }
}
