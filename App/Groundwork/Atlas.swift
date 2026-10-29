import SpriteKit
import UIKit
import GroundworkView

/// Textures cut from the bundled sprite atlas, always with nearest-neighbour
/// filtering so pixels stay crisp when the low-resolution scene is scaled up.
@MainActor
final class Atlas {
    let manifest: AtlasManifest
    let image: UIImage
    private let base: SKTexture
    private var cache: [String: SKTexture] = [:]

    init(manifest: AtlasManifest) {
        guard let url = Bundle.main.url(forResource: "atlas", withExtension: "png", subdirectory: "generated"),
              let image = UIImage(contentsOfFile: url.path) else {
            fatalError("Art/generated/atlas.png is missing from the app bundle")
        }
        self.manifest = manifest
        self.image = image
        base = SKTexture(image: image)
        base.filteringMode = .nearest
    }

    func texture(_ name: String) -> SKTexture {
        if let cached = cache[name] { return cached }
        let texture: SKTexture
        if let r = manifest.normalizedRect(name) {
            texture = SKTexture(rect: CGRect(x: r.x, y: r.y, width: r.w, height: r.h), in: base)
        } else {
            texture = base   // a missing name shows the whole atlas, which is hard to miss
        }
        texture.filteringMode = .nearest
        cache[name] = texture
        return texture
    }
}
