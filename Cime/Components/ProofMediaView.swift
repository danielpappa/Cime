import AVKit
import SwiftUI

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
                    VideoView(data: jpeg)
                } else {
                    Theme.secondary
                }
            case .audio:
                VStack(spacing: 4) {
                    Text("♪").displayFont(22).foregroundStyle(Theme.summit)
                    if let jpeg {
                        AudioProofView(data: jpeg)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.secondary)
            }
        }
    }
}

private struct VideoView: View {
    let data: Data
    @State private var player: AVPlayer?

    var body: some View {
        VideoPlayer(player: player)
            .onAppear {
                let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mp4")
                try? data.write(to: url)
                let p = AVPlayer(url: url)
                player = p
                p.play()
            }
    }
}

private struct AudioProofView: View {
    let data: Data
    @State private var player: AVPlayer?

    var body: some View {
        VideoPlayer(player: player)
            .frame(height: 44)
            .onAppear {
                let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".m4a")
                try? data.write(to: url)
                player = AVPlayer(url: url)
            }
    }
}
