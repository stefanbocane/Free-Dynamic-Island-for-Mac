import Foundation
import AppKit
import CoreImage

final class AccentColorExtractor {
    private let context = CIContext(options: [.useSoftwareRenderer: false])

    func dominantAccent(from image: NSImage) -> NSColor? {
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let cg = bitmap.cgImage else { return nil }

        let ci = CIImage(cgImage: cg)
        let downsized = downscale(ci, maxSide: 128) ?? ci

        guard let kmeans = CIFilter(name: "CIKMeans") else {
            return fallbackDominant(from: bitmap)
        }
        kmeans.setValue(downsized, forKey: kCIInputImageKey)
        kmeans.setValue(CIVector(cgRect: downsized.extent), forKey: "inputExtent")
        kmeans.setValue(3, forKey: "inputCount")
        kmeans.setValue(10, forKey: "inputPasses")
        kmeans.setValue(NSNumber(value: true), forKey: "inputPerceptual")

        guard let output = kmeans.outputImage else {
            return fallbackDominant(from: bitmap)
        }

        var buf = [UInt8](repeating: 0, count: 4 * 3)
        context.render(output,
                       toBitmap: &buf,
                       rowBytes: 4 * 3,
                       bounds: CGRect(x: 0, y: 0, width: 3, height: 1),
                       format: .RGBA8,
                       colorSpace: CGColorSpaceCreateDeviceRGB())

        var candidates: [NSColor] = []
        for i in 0..<3 {
            let r = CGFloat(buf[i * 4]) / 255.0
            let g = CGFloat(buf[i * 4 + 1]) / 255.0
            let b = CGFloat(buf[i * 4 + 2]) / 255.0
            candidates.append(NSColor(red: r, green: g, blue: b, alpha: 1))
        }
        return pickVibrant(candidates) ?? fallbackDominant(from: bitmap)
    }

    private func downscale(_ image: CIImage, maxSide: CGFloat) -> CIImage? {
        let extent = image.extent
        let longest = max(extent.width, extent.height)
        guard longest > maxSide else { return image }
        let scale = maxSide / longest
        let xf = CGAffineTransform(scaleX: scale, y: scale)
        return image.transformed(by: xf)
    }

    private func pickVibrant(_ colors: [NSColor]) -> NSColor? {
        var bestColor: NSColor?
        var bestScore: CGFloat = -1
        for color in colors {
            guard let c = color.usingColorSpace(.sRGB) else { continue }
            var h: CGFloat = 0, s: CGFloat = 0, br: CGFloat = 0, a: CGFloat = 0
            c.getHue(&h, saturation: &s, brightness: &br, alpha: &a)
            // Score: prefer saturated, mid-bright colors
            if s < 0.15 { continue } // too gray
            if br < 0.18 || br > 0.95 { continue } // too dark / too bright
            let score = s * (1 - abs(0.55 - br))
            if score > bestScore {
                bestScore = score
                bestColor = c
            }
        }
        return bestColor
    }

    private func fallbackDominant(from bitmap: NSBitmapImageRep) -> NSColor? {
        guard let px = bitmap.colorAt(x: bitmap.pixelsWide / 2, y: bitmap.pixelsHigh / 2) else { return nil }
        return px.usingColorSpace(.sRGB)
    }
}
