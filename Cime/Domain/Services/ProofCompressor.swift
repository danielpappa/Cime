//
//  ProofCompressor.swift
//  Cime
//
//  Created by Daniel Pappalardo on 07/11/2026.
//

import AVFoundation
import UIKit

enum ProofCompressor {
    struct Failure: Error {}

    /// video -> 960x540 mp4 (~1.5-2.5 MB for 10 s); audio -> m4a (~250 KB for 30 s).
    static func compress(_ source: URL, kind: ProofKind) async throws -> Data {
        let (preset, type, ext): (String, AVFileType, String) = kind == .audio
            ? (AVAssetExportPresetAppleM4A, .m4a, "m4a")
            : (AVAssetExportPreset960x540, .mp4, "mp4")
        let out = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + "." + ext)
        defer {
            try? FileManager.default.removeItem(at: out)
            try? FileManager.default.removeItem(at: source)
        }
        guard let session = AVAssetExportSession(asset: AVURLAsset(url: source), presetName: preset) else { throw Failure() }
        session.outputURL = out
        session.outputFileType = type
        session.shouldOptimizeForNetworkUse = true
        
        try await session.export(to: out, as: type)
        return try Data(contentsOf: out)
    }

    static func firstFrameJPEG(_ url: URL) async -> Data? {
        let gen = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        gen.appliesPreferredTrackTransform = true
        gen.maximumSize = CGSize(width: 600, height: 600)
        guard let cg = try? await gen.image(at: CMTime(seconds: 0.5, preferredTimescale: 600)).image else { return nil }
        return UIImage(cgImage: cg).jpegData(compressionQuality: 0.7)
    }
}
