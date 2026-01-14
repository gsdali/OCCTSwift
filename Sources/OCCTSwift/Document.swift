import Foundation
import simd
import OCCTBridge

/// XDE Document for loading STEP files with assembly structure, names, colors, and materials
///
/// Use `Document` when you need to:
/// - Preserve assembly hierarchy from STEP files
/// - Access part names and structure
/// - Read colors and PBR materials
/// - Export with metadata preserved
///
/// For simple geometry-only import, use `Shape.load(from:)` instead.
public final class Document: @unchecked Sendable {
    internal let handle: OCCTDocumentRef

    internal init(handle: OCCTDocumentRef) {
        self.handle = handle
    }

    deinit {
        OCCTDocumentRelease(handle)
    }

    // MARK: - Loading

    /// Load a STEP file with full XDE support (assembly structure, names, colors, materials)
    ///
    /// - Parameter url: URL to the STEP file
    /// - Returns: Document containing the assembly structure
    /// - Throws: `DocumentError` if loading fails
    public static func load(from url: URL) throws -> Document {
        guard let handle = OCCTDocumentLoadSTEP(url.path) else {
            throw DocumentError.loadFailed(url: url)
        }
        return Document(handle: handle)
    }

    /// Create a new empty document
    public static func create() -> Document? {
        guard let handle = OCCTDocumentCreate() else {
            return nil
        }
        return Document(handle: handle)
    }

    // MARK: - Assembly Structure

    /// Get the root nodes (top-level/free shapes) in the document
    public var rootNodes: [AssemblyNode] {
        let count = OCCTDocumentGetRootCount(handle)
        var nodes: [AssemblyNode] = []
        nodes.reserveCapacity(Int(count))

        for i in 0..<count {
            let labelId = OCCTDocumentGetRootLabelId(handle, i)
            if labelId >= 0 {
                nodes.append(AssemblyNode(document: self, labelId: labelId))
            }
        }

        return nodes
    }

    // MARK: - Convenience Methods

    /// Get all shapes from the document as a flat list
    public func allShapes() -> [Shape] {
        var shapes: [Shape] = []
        collectShapes(from: rootNodes, into: &shapes)
        return shapes
    }

    /// Get all shapes with their associated colors
    public func shapesWithColors() -> [(shape: Shape, color: Color?)] {
        var results: [(Shape, Color?)] = []
        collectShapesWithColors(from: rootNodes, into: &results)
        return results
    }

    /// Get all shapes with their associated PBR materials
    public func shapesWithMaterials() -> [(shape: Shape, material: Material?)] {
        var results: [(Shape, Material?)] = []
        collectShapesWithMaterials(from: rootNodes, into: &results)
        return results
    }

    private func collectShapes(from nodes: [AssemblyNode], into shapes: inout [Shape]) {
        for node in nodes {
            if let shape = node.shape {
                shapes.append(shape)
            }
            collectShapes(from: node.children, into: &shapes)
        }
    }

    private func collectShapesWithColors(from nodes: [AssemblyNode], into results: inout [(Shape, Color?)]) {
        for node in nodes {
            if let shape = node.shape {
                results.append((shape, node.color))
            }
            collectShapesWithColors(from: node.children, into: &results)
        }
    }

    private func collectShapesWithMaterials(from nodes: [AssemblyNode], into results: inout [(Shape, Material?)]) {
        for node in nodes {
            if let shape = node.shape {
                results.append((shape, node.material))
            }
            collectShapesWithMaterials(from: node.children, into: &results)
        }
    }

    // MARK: - Writing

    /// Write the document to a STEP file (preserves assembly structure, colors, materials)
    ///
    /// - Parameter url: Output file URL
    /// - Throws: `DocumentError` if writing fails
    public func write(to url: URL) throws {
        if !OCCTDocumentWriteSTEP(handle, url.path) {
            throw DocumentError.writeFailed(url: url)
        }
    }
}

// MARK: - AssemblyNode

/// A node in an XDE assembly tree
///
/// Represents a part or sub-assembly in a STEP file with:
/// - Name (if assigned in CAD software)
/// - Transform (position/rotation relative to parent)
/// - Color (if assigned)
/// - PBR Material (if available)
/// - Children (for assemblies)
/// - Shape (for parts)
public final class AssemblyNode: @unchecked Sendable {
    private let document: Document
    private let labelId: Int64

    internal init(document: Document, labelId: Int64) {
        self.document = document
        self.labelId = labelId
    }

    /// The name of this node (from CAD software)
    public var name: String? {
        guard let cString = OCCTDocumentGetLabelName(document.handle, labelId) else {
            return nil
        }
        let result = String(cString: cString)
        OCCTStringFree(cString)
        return result
    }

    /// Whether this node is an assembly (has children)
    public var isAssembly: Bool {
        OCCTDocumentIsAssembly(document.handle, labelId)
    }

    /// Whether this node is a reference (instance of another shape)
    public var isReference: Bool {
        OCCTDocumentIsReference(document.handle, labelId)
    }

    /// Transform matrix (position/rotation relative to parent)
    public var transform: simd_float4x4 {
        var matrix = [Float](repeating: 0, count: 16)
        OCCTDocumentGetLocation(document.handle, labelId, &matrix)
        return simd_float4x4(
            SIMD4(matrix[0], matrix[1], matrix[2], matrix[3]),
            SIMD4(matrix[4], matrix[5], matrix[6], matrix[7]),
            SIMD4(matrix[8], matrix[9], matrix[10], matrix[11]),
            SIMD4(matrix[12], matrix[13], matrix[14], matrix[15])
        )
    }

    /// Color assigned to this node (if any)
    public var color: Color? {
        // Try surface color first, then generic
        var occtColor = OCCTDocumentGetLabelColor(document.handle, labelId, OCCTColorTypeSurface)
        if !occtColor.isSet {
            occtColor = OCCTDocumentGetLabelColor(document.handle, labelId, OCCTColorTypeGeneric)
        }

        guard occtColor.isSet else { return nil }

        return Color(red: occtColor.r, green: occtColor.g, blue: occtColor.b, alpha: occtColor.a)
    }

    /// PBR material assigned to this node (if any)
    public var material: Material? {
        let occtMat = OCCTDocumentGetLabelMaterial(document.handle, labelId)
        guard occtMat.isSet else { return nil }

        let baseColor = Color(
            red: occtMat.baseColor.r,
            green: occtMat.baseColor.g,
            blue: occtMat.baseColor.b,
            alpha: occtMat.baseColor.a
        )

        var emissive: Color? = nil
        if occtMat.emissive.isSet {
            emissive = Color(
                red: occtMat.emissive.r,
                green: occtMat.emissive.g,
                blue: occtMat.emissive.b,
                alpha: occtMat.emissive.a
            )
        }

        return Material(
            baseColor: baseColor,
            metallic: occtMat.metallic,
            roughness: occtMat.roughness,
            emissive: emissive,
            transparency: occtMat.transparency
        )
    }

    /// Child nodes (for assemblies)
    public var children: [AssemblyNode] {
        let count = OCCTDocumentGetChildCount(document.handle, labelId)
        var nodes: [AssemblyNode] = []
        nodes.reserveCapacity(Int(count))

        for i in 0..<count {
            let childLabelId = OCCTDocumentGetChildLabelId(document.handle, labelId, i)
            if childLabelId >= 0 {
                nodes.append(AssemblyNode(document: document, labelId: childLabelId))
            }
        }

        return nodes
    }

    /// The shape geometry (with transform applied)
    ///
    /// Returns nil for pure assemblies that have no direct geometry
    public var shape: Shape? {
        guard let shapeHandle = OCCTDocumentGetShapeWithLocation(document.handle, labelId) else {
            return nil
        }
        return Shape(handle: shapeHandle)
    }

    /// The shape geometry without transform (original definition)
    public var shapeWithoutTransform: Shape? {
        guard let shapeHandle = OCCTDocumentGetShape(document.handle, labelId) else {
            return nil
        }
        return Shape(handle: shapeHandle)
    }

    /// For references, get the referred node
    public var referredNode: AssemblyNode? {
        guard isReference else { return nil }
        let referredLabelId = OCCTDocumentGetReferredLabelId(document.handle, labelId)
        guard referredLabelId >= 0 else { return nil }
        return AssemblyNode(document: document, labelId: referredLabelId)
    }
}

// MARK: - Errors

/// Errors that can occur when working with XDE documents
public enum DocumentError: Error, LocalizedError {
    case loadFailed(url: URL)
    case writeFailed(url: URL)

    public var errorDescription: String? {
        switch self {
        case .loadFailed(let url):
            return "Failed to load STEP file: \(url.lastPathComponent)"
        case .writeFailed(let url):
            return "Failed to write STEP file: \(url.lastPathComponent)"
        }
    }
}
