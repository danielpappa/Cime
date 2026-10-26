import CoreGraphics
import Foundation
import UIKit

enum ProofValidator {
    /// On-device stand-in for AI proof check (matches web `checkProof` in peaks.ts).
    static func checkProof(pixels: [UInt8], bytesPerPixel: Int = 4) -> (ok: Bool, reason: String?) {
        var sum = 0.0
        var sumSq = 0.0
        var n = 0

        var i = 0
        while i < pixels.count {
            let r = Double(pixels[i])
            let g = Double(pixels[i + 1])
            let b = Double(pixels[i + 2])
            let l = 0.299 * r + 0.587 * g + 0.114 * b
            sum += l
            sumSq += l * l
            n += 1
            i += bytesPerPixel * 4
        }

        guard n > 0 else { return (false, "Couldn't read the image.") }

        let mean = sum / Double(n)
        let variance = sumSq / Double(n) - mean * mean
        let sd = sqrt(max(0, variance))

        if mean < 25 { return (false, "Too dark — we can't see your proof.") }
        if sd < 12 { return (false, "Looks blank. Point the camera at what you did.") }
        return (true, nil)
    }

    static func checkJPEG(_ data: Data) -> (ok: Bool, reason: String?) {
        guard let image = UIImage(data: data), let cg = image.cgImage else {
            return (false, "Couldn't read the image.")
        }
        let width = min(600, cg.width)
        let height = max(1, Int(Double(cg.height) * Double(width) / Double(cg.width)))
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var raw = [UInt8](repeating: 0, count: width * height * 4)
        guard let ctx = CGContext(
            data: &raw,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return (false, "Couldn't read the image.")
        }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))
        return checkProof(pixels: raw, bytesPerPixel: 1)
    }
}
