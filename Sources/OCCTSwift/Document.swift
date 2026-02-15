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
    unowned let document: Document
    internal let labelId: Int64

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

// MARK: - GD&T / Dimensions and Tolerances (v0.21.0)

/// Dimension information from STEP GD&T data
public struct DimensionInfo: Sendable {
    /// Dimension type (maps to XCAFDimTolObjects_DimensionType)
    public let type: Int32
    /// Primary dimension value
    public let value: Double
    /// Lower tolerance
    public let lowerTolerance: Double
    /// Upper tolerance
    public let upperTolerance: Double
}

/// Geometric tolerance information from STEP GD&T data
public struct GeomToleranceInfo: Sendable {
    /// Tolerance type (maps to XCAFDimTolObjects_GeomToleranceType)
    public let type: Int32
    /// Tolerance value
    public let value: Double
}

/// Datum reference information from STEP GD&T data
public struct DatumInfo: Sendable {
    /// Datum identifier (e.g. "A", "B", "C")
    public let name: String
}

extension Document {
    /// Number of dimensions defined in this document
    public var dimensionCount: Int {
        Int(OCCTDocumentGetDimensionCount(handle))
    }

    /// Number of geometric tolerances defined in this document
    public var geomToleranceCount: Int {
        Int(OCCTDocumentGetGeomToleranceCount(handle))
    }

    /// Number of datums defined in this document
    public var datumCount: Int {
        Int(OCCTDocumentGetDatumCount(handle))
    }

    /// Get dimension info at the given index
    public func dimension(at index: Int) -> DimensionInfo? {
        let info = OCCTDocumentGetDimensionInfo(handle, Int32(index))
        guard info.isValid else { return nil }
        return DimensionInfo(type: info.type, value: info.value,
                             lowerTolerance: info.lowerTol,
                             upperTolerance: info.upperTol)
    }

    /// Get geometric tolerance info at the given index
    public func geomTolerance(at index: Int) -> GeomToleranceInfo? {
        let info = OCCTDocumentGetGeomToleranceInfo(handle, Int32(index))
        guard info.isValid else { return nil }
        return GeomToleranceInfo(type: info.type, value: info.value)
    }

    /// Get datum info at the given index
    public func datum(at index: Int) -> DatumInfo? {
        var info = OCCTDocumentGetDatumInfo(handle, Int32(index))
        guard info.isValid else { return nil }
        let name = withUnsafeBytes(of: &info.name) { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress else { return "" }
            let charPtr = baseAddress.assumingMemoryBound(to: CChar.self)
            return String(cString: charPtr)
        }
        return DatumInfo(name: name)
    }

    /// All dimensions in this document
    public var dimensions: [DimensionInfo] {
        (0..<dimensionCount).compactMap { dimension(at: $0) }
    }

    /// All geometric tolerances in this document
    public var geomTolerances: [GeomToleranceInfo] {
        (0..<geomToleranceCount).compactMap { geomTolerance(at: $0) }
    }

    /// All datums in this document
    public var datums: [DatumInfo] {
        (0..<datumCount).compactMap { datum(at: $0) }
    }
}

// MARK: - TNaming: Topological Naming (v0.25.0)

/// Evolution type for topological naming history
public enum NamingEvolution: Int32, Sendable {
    /// Shape created from scratch (no predecessor)
    case primitive = 0
    /// Shape generated from another shape (e.g. face from edge extrusion)
    case generated = 1
    /// Shape modified (e.g. filleted edge)
    case modify = 2
    /// Shape deleted
    case delete = 3
    /// Named selection for persistent identification
    case selected = 4
}

/// A single entry in the naming history of a label
public struct NamingHistoryEntry: Sendable {
    /// The type of evolution this entry represents
    public let evolution: NamingEvolution
    /// Whether this entry has an old (input) shape
    public let hasOldShape: Bool
    /// Whether this entry has a new (result) shape
    public let hasNewShape: Bool
    /// Whether this is a modification operation
    public let isModification: Bool
}

extension Document {

    /// Create a new label for naming history tracking
    ///
    /// - Parameter parent: Parent node (nil for document root)
    /// - Returns: Assembly node representing the new label, or nil on failure
    public func createLabel(parent: AssemblyNode? = nil) -> AssemblyNode? {
        let parentId = parent?.labelId ?? -1
        let labelId = OCCTDocumentCreateLabel(handle, parentId)
        guard labelId >= 0 else { return nil }
        return AssemblyNode(document: self, labelId: labelId)
    }

    /// Record a naming evolution on a label
    ///
    /// - Parameters:
    ///   - node: The label to record on
    ///   - evolution: Type of topological evolution
    ///   - oldShape: Previous shape (nil for primitive)
    ///   - newShape: Result shape (nil for delete)
    /// - Returns: true if recording succeeded
    @discardableResult
    public func recordNaming(on node: AssemblyNode, evolution: NamingEvolution,
                             oldShape: Shape? = nil, newShape: Shape? = nil) -> Bool {
        OCCTDocumentNamingRecord(handle, node.labelId,
                                OCCTNamingEvolution(UInt32(evolution.rawValue)),
                                oldShape?.handle, newShape?.handle)
    }

    /// Get the current (most recent) shape on a label
    public func currentShape(on node: AssemblyNode) -> Shape? {
        guard let h = OCCTDocumentNamingGetCurrentShape(handle, node.labelId) else { return nil }
        return Shape(handle: h)
    }

    /// Get the stored shape on a label
    public func storedShape(on node: AssemblyNode) -> Shape? {
        guard let h = OCCTDocumentNamingGetShape(handle, node.labelId) else { return nil }
        return Shape(handle: h)
    }

    /// Get the naming evolution type on a label
    public func namingEvolution(on node: AssemblyNode) -> NamingEvolution? {
        let raw = OCCTDocumentNamingGetEvolution(handle, node.labelId)
        guard raw >= 0 else { return nil }
        return NamingEvolution(rawValue: raw)
    }

    /// Get the full naming history on a label
    public func namingHistory(on node: AssemblyNode) -> [NamingHistoryEntry] {
        let count = OCCTDocumentNamingHistoryCount(handle, node.labelId)
        guard count > 0 else { return [] }

        var entries: [NamingHistoryEntry] = []
        entries.reserveCapacity(Int(count))

        for i in 0..<count {
            var entry = OCCTNamingHistoryEntry()
            if OCCTDocumentNamingGetHistoryEntry(handle, node.labelId, i, &entry) {
                entries.append(NamingHistoryEntry(
                    evolution: NamingEvolution(rawValue: Int32(entry.evolution.rawValue)) ?? .primitive,
                    hasOldShape: entry.hasOldShape,
                    hasNewShape: entry.hasNewShape,
                    isModification: entry.isModification
                ))
            }
        }

        return entries
    }

    /// Get the old (input) shape from a history entry
    public func oldShape(on node: AssemblyNode, at index: Int) -> Shape? {
        guard let h = OCCTDocumentNamingGetOldShape(handle, node.labelId, Int32(index)) else { return nil }
        return Shape(handle: h)
    }

    /// Get the new (result) shape from a history entry
    public func newShape(on node: AssemblyNode, at index: Int) -> Shape? {
        guard let h = OCCTDocumentNamingGetNewShape(handle, node.labelId, Int32(index)) else { return nil }
        return Shape(handle: h)
    }

    /// Trace forward: find shapes generated/modified from the given shape
    ///
    /// - Parameters:
    ///   - shape: The source shape to trace from
    ///   - scope: A label providing document scope for the search
    /// - Returns: Array of shapes that were generated/modified from the source
    public func tracedForward(from shape: Shape, scope: AssemblyNode) -> [Shape] {
        let maxCount: Int32 = 64
        var handles = [OCCTShapeRef?](repeating: nil, count: Int(maxCount))
        let count = OCCTDocumentNamingTraceForward(handle, scope.labelId, shape.handle,
                                                    &handles, maxCount)
        return (0..<Int(count)).compactMap { handles[$0].map { Shape(handle: $0) } }
    }

    /// Trace backward: find shapes that generated/preceded the given shape
    ///
    /// - Parameters:
    ///   - shape: The shape to trace back from
    ///   - scope: A label providing document scope for the search
    /// - Returns: Array of shapes that preceded the given shape
    public func tracedBackward(from shape: Shape, scope: AssemblyNode) -> [Shape] {
        let maxCount: Int32 = 64
        var handles = [OCCTShapeRef?](repeating: nil, count: Int(maxCount))
        let count = OCCTDocumentNamingTraceBackward(handle, scope.labelId, shape.handle,
                                                     &handles, maxCount)
        return (0..<Int(count)).compactMap { handles[$0].map { Shape(handle: $0) } }
    }

    /// Create a persistent named selection
    ///
    /// - Parameters:
    ///   - selection: The shape to select
    ///   - context: The context shape containing the selection
    ///   - node: The label to store the selection on
    /// - Returns: true if selection succeeded
    @discardableResult
    public func selectShape(_ selection: Shape, context: Shape, on node: AssemblyNode) -> Bool {
        OCCTDocumentNamingSelect(handle, node.labelId, selection.handle, context.handle)
    }

    /// Resolve a previously selected shape after modifications
    ///
    /// - Parameter node: The label containing the selection
    /// - Returns: The resolved shape, or nil on failure
    public func resolveShape(on node: AssemblyNode) -> Shape? {
        guard let h = OCCTDocumentNamingResolve(handle, node.labelId) else { return nil }
        return Shape(handle: h)
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
