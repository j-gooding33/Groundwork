import Foundation

/// The sprite atlas description written by Tools/make_art.py
/// (Art/generated/atlas.json). Rects are in pixels with a top-left origin.
public struct AtlasManifest: Codable, Equatable, Sendable {
    public struct Rect: Codable, Equatable, Sendable {
        public var x: Int
        public var y: Int
        public var w: Int
        public var h: Int
    }

    public var atlas: String
    public var width: Int
    public var height: Int
    public var tileSize: Int
    public var sprites: [String: Rect]

    public static func load(from url: URL) throws -> AtlasManifest {
        try JSONDecoder().decode(AtlasManifest.self, from: Data(contentsOf: url))
    }

    public func has(_ name: String) -> Bool { sprites[name] != nil }

    /// A sprite's rect as fractions of the atlas with a bottom-left origin,
    /// which is what `SKTexture(rect:in:)` wants.
    public func normalizedRect(_ name: String) -> (x: Double, y: Double, w: Double, h: Double)? {
        guard let r = sprites[name] else { return nil }
        let W = Double(width), H = Double(height)
        return (Double(r.x) / W, 1 - Double(r.y + r.h) / H, Double(r.w) / W, Double(r.h) / H)
    }

    /// How many versions a sprite has: `name`, `name_v1`, `name_v2`...
    public func variantCount(_ name: String) -> Int {
        var count = has(name) ? 1 : 0
        while has("\(name)_v\(count)") { count += 1 }
        return max(count, 1)
    }

    /// Animation frames for a sprite: `name`, `name_f1`, `name_f2`...
    public func frames(_ name: String) -> [String] {
        var frames = [name]
        while has("\(name)_f\(frames.count)") { frames.append("\(name)_f\(frames.count)") }
        return frames
    }
}
