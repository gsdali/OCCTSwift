import Foundation

/// PBR (Physically Based Rendering) material for XDE document support
///
/// This struct represents material properties compatible with glTF and modern rendering pipelines.
public struct Material: Sendable, Equatable {
    /// Base color (albedo) of the material
    public var baseColor: Color

    /// Metallic factor (0.0 = dielectric, 1.0 = metal)
    public var metallic: Double

    /// Roughness factor (0.0 = smooth/glossy, 1.0 = rough/matte)
    public var roughness: Double

    /// Emissive color (light emitted by the material)
    public var emissive: Color?

    /// Transparency (0.0 = opaque, 1.0 = fully transparent)
    public var transparency: Double

    /// Create a PBR material
    ///
    /// - Parameters:
    ///   - baseColor: The base color (albedo) of the material
    ///   - metallic: Metallic factor, 0.0-1.0 (default 0.0 for non-metals)
    ///   - roughness: Roughness factor, 0.0-1.0 (default 0.5)
    ///   - emissive: Optional emissive color for glowing materials
    ///   - transparency: Transparency factor, 0.0-1.0 (default 0.0 for opaque)
    public init(
        baseColor: Color,
        metallic: Double = 0.0,
        roughness: Double = 0.5,
        emissive: Color? = nil,
        transparency: Double = 0.0
    ) {
        self.baseColor = baseColor
        self.metallic = max(0, min(1, metallic))
        self.roughness = max(0, min(1, roughness))
        self.emissive = emissive
        self.transparency = max(0, min(1, transparency))
    }

    // MARK: - Common Materials

    /// Default material (white, non-metallic, medium roughness)
    public static let `default` = Material(baseColor: .white)

    /// Polished metal (highly metallic, low roughness)
    public static let polishedMetal = Material(
        baseColor: Color(red: 0.8, green: 0.8, blue: 0.8),
        metallic: 1.0,
        roughness: 0.1
    )

    /// Brushed metal (metallic with medium roughness)
    public static let brushedMetal = Material(
        baseColor: Color(red: 0.7, green: 0.7, blue: 0.7),
        metallic: 1.0,
        roughness: 0.4
    )

    /// Plastic (non-metallic, medium roughness)
    public static let plastic = Material(
        baseColor: Color(red: 0.8, green: 0.8, blue: 0.8),
        metallic: 0.0,
        roughness: 0.4
    )

    /// Rubber (non-metallic, high roughness)
    public static let rubber = Material(
        baseColor: Color(red: 0.1, green: 0.1, blue: 0.1),
        metallic: 0.0,
        roughness: 0.9
    )

    /// Glass (transparent, smooth)
    public static let glass = Material(
        baseColor: Color(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.1),
        metallic: 0.0,
        roughness: 0.0,
        transparency: 0.9
    )
}
