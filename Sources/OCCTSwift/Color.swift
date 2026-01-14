import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// RGBA color for XDE document support
public struct Color: Sendable, Equatable, Hashable {
    /// Red component (0.0-1.0)
    public var red: Double

    /// Green component (0.0-1.0)
    public var green: Double

    /// Blue component (0.0-1.0)
    public var blue: Double

    /// Alpha component (0.0-1.0, where 1.0 is fully opaque)
    public var alpha: Double

    /// Create a color with RGBA components
    public init(red: Double, green: Double, blue: Double, alpha: Double = 1.0) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    /// Create a color from RGB values (0-255 range)
    public init(red255: Int, green255: Int, blue255: Int, alpha255: Int = 255) {
        self.red = Double(red255) / 255.0
        self.green = Double(green255) / 255.0
        self.blue = Double(blue255) / 255.0
        self.alpha = Double(alpha255) / 255.0
    }

    #if canImport(CoreGraphics)
    /// Convert to CGColor
    public var cgColor: CGColor {
        CGColor(red: red, green: green, blue: blue, alpha: alpha)
    }

    /// Create from CGColor
    public init?(_ cgColor: CGColor) {
        guard let components = cgColor.components, components.count >= 3 else {
            return nil
        }
        self.red = Double(components[0])
        self.green = Double(components[1])
        self.blue = Double(components[2])
        self.alpha = components.count >= 4 ? Double(components[3]) : 1.0
    }
    #endif

    // MARK: - Predefined Colors

    /// Black color
    public static let black = Color(red: 0, green: 0, blue: 0)

    /// White color
    public static let white = Color(red: 1, green: 1, blue: 1)

    /// Red color
    public static let red = Color(red: 1, green: 0, blue: 0)

    /// Green color
    public static let green = Color(red: 0, green: 1, blue: 0)

    /// Blue color
    public static let blue = Color(red: 0, green: 0, blue: 1)

    /// Gray color (50%)
    public static let gray = Color(red: 0.5, green: 0.5, blue: 0.5)

    /// Clear (fully transparent)
    public static let clear = Color(red: 0, green: 0, blue: 0, alpha: 0)
}
