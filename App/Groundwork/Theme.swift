import SwiftUI
import UIKit
import GroundworkView

/// Colours from Art/palette.json, so the interface matches the pixel art.
enum Palette {
    static let paper = Color(red: 1.0, green: 0.957, blue: 0.839)        // F
    static let ink = Color(red: 0.102, green: 0.110, blue: 0.173)        // K
    static let stone = Color(red: 0.639, green: 0.639, blue: 0.690)      // z
    static let sand = Color(red: 0.788, green: 0.627, blue: 0.420)       // m
    static let gold = Color(red: 0.949, green: 0.757, blue: 0.306)       // D
    static let ember = Color(red: 1.0, green: 0.541, blue: 0.239)        // E
    static let brick = Color(red: 0.557, green: 0.184, blue: 0.165)      // r
    static let grass = Color(red: 0.290, green: 0.604, blue: 0.282)      // c
}

/// Pixel font: the system monospaced font, bold, small, no smoothing tricks.
extension Font {
    static func pixel(_ size: CGFloat) -> Font { .system(size: size, weight: .heavy, design: .monospaced) }
}

/// A paper card with an ink outline, like the ui_panel sprite.
struct PaperCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(10)
            .background(Palette.paper)
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(Palette.ink, lineWidth: 2))
            .clipShape(RoundedRectangle(cornerRadius: 3))
            .shadow(color: Palette.ink.opacity(0.25), radius: 0, x: 2, y: 2)
    }
}

extension View {
    func paperCard() -> some View { modifier(PaperCard()) }
}

/// Sprites cut from the atlas as SwiftUI images, scaled with no smoothing.
@MainActor
final class SpriteImages {
    private let manifest: AtlasManifest
    private let atlas: CGImage?
    private var cache: [String: UIImage] = [:]

    init(manifest: AtlasManifest) {
        self.manifest = manifest
        let url = Bundle.main.url(forResource: "atlas", withExtension: "png", subdirectory: "generated")
        atlas = url.flatMap { UIImage(contentsOfFile: $0.path)?.cgImage }
    }

    func image(_ name: String) -> Image {
        if let cached = cache[name] { return Image(uiImage: cached) }
        guard let atlas, let r = manifest.sprites[name],
              let cropped = atlas.cropping(to: CGRect(x: r.x, y: r.y, width: r.w, height: r.h)) else {
            return Image(systemName: "questionmark.square")
        }
        let image = UIImage(cgImage: cropped, scale: 1, orientation: .up)
        cache[name] = image
        return Image(uiImage: image)
    }
}

struct SpriteIcon: View {
    let images: SpriteImages
    let name: String
    var size: CGFloat = 32

    var body: some View {
        images.image(name)
            .interpolation(.none)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
    }
}
