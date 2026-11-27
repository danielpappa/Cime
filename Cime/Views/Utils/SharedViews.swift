import SwiftUI
import UIKit

/// Round profile picture. Fallback is first letter of the name
struct AvatarView: View {
    var jpeg: Data? = nil
    var url: URL? = nil
    let letter: String
    let size: CGFloat

    var body: some View {
        Group {
            if let jpeg, let ui = UIImage(data: jpeg) {
                Image(uiImage: ui).resizable().scaledToFill()
            } else if let url {
                AsyncImage(url: url) { phase in           // AsyncImage downloads the image for us
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        initial                           // shown while loading or on failure
                    }
                }
            } else {
                initial
            }
        }
        .frame(width: size, height: size)
        .background(Theme.secondary)
        .clipShape(Circle())
    }

    private var initial: some View {
        Text(String(letter.prefix(1)).uppercased()).displayFont(size * 0.38)
    }
}

/// Square thumbnail for a goal's proof
struct ProofThumb: View {
    @Environment(CimeStore.self) private var store
    let goal: Goal
    @State private var url: URL?

    var body: some View {
        Group {
            if let jpeg = goal.proofJPEG, let ui = UIImage(data: jpeg) {
                Image(uiImage: ui).resizable().scaledToFill()
            } else if let url, (goal.proofKind ?? .photo) == .photo {
                AsyncImage(url: url) { phase in
                    if let image = phase.image { image.resizable().scaledToFill() }
                    else { Theme.secondary }
                }
            } else {
                ZStack {
                    Theme.primary.opacity(0.5)
                    Image(systemName: icon).resizable().scaledToFit().padding(12).foregroundStyle(Theme.mutedForeground)
                }
            }
        }
        .task(id: goal.proofPath) {
            url = nil
            guard goal.proofJPEG == nil, let path = goal.proofPath else { return }
            url = await store.proofURL(path: path)
        }
    }

    private var icon: String {
        switch goal.proofKind {
        case .video: "video"
        case .audio: "waveform"
        default: "photo"
        }
    }
}

extension Data {
    /// Shrinks image data so the longest side is at most `maxSide` points and re-encodes it as JPEG
    nonisolated func jpegDownscaled(maxSide: CGFloat = 1024, quality: CGFloat = 0.8) -> Data? {
        guard let image = UIImage(data: self) else { return nil }
        let scale = Swift.min(1, maxSide / Swift.max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1                                  // 1 pixel per point, otherwise it renders 2–3x bigger
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return resized.jpegData(compressionQuality: quality)
    }
}
