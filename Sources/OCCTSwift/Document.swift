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

    /// Set the surface color on this node.
    ///
    /// - Parameter color: The color to assign
    public func setColor(_ color: Color) {
        OCCTDocumentSetLabelColor(document.handle, labelId, OCCTColorTypeSurface,
                                  color.red, color.green, color.blue)
    }

    /// Set the color on this node with a specific color type.
    ///
    /// - Parameters:
    ///   - color: The color to assign
    ///   - type: Color type — generic (0), surface (1), or curve (2)
    public func setColor(_ color: Color, type: OCCTColorType) {
        OCCTDocumentSetLabelColor(document.handle, labelId, type,
                                  color.red, color.green, color.blue)
    }

    /// Set the PBR material on this node.
    ///
    /// - Parameter material: The material properties to assign
    public func setMaterial(_ material: Material) {
        var occtMat = OCCTMaterial()
        occtMat.baseColor = OCCTColor(r: material.baseColor.red, g: material.baseColor.green,
                                       b: material.baseColor.blue, a: material.baseColor.alpha, isSet: true)
        occtMat.metallic = material.metallic
        occtMat.roughness = material.roughness
        if let emissive = material.emissive {
            occtMat.emissive = OCCTColor(r: emissive.red, g: emissive.green,
                                          b: emissive.blue, a: emissive.alpha, isSet: true)
        } else {
            occtMat.emissive = OCCTColor(r: 0, g: 0, b: 0, a: 1, isSet: false)
        }
        occtMat.transparency = material.transparency
        occtMat.isSet = true
        OCCTDocumentSetLabelMaterial(document.handle, labelId, occtMat)
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

// MARK: - Length Unit (v0.30.0)

/// Length unit information from a document.
public struct LengthUnit: Sendable {
    /// Scale factor (e.g., 1.0 for mm, 25.4 for inch)
    public let scale: Double
    /// Unit name (e.g., "mm", "inch", "m")
    public let name: String
}

extension Document {
    /// Get the length unit of this document.
    ///
    /// Returns the unit scale and name stored in the STEP file.
    /// Common values: 1.0 = mm, 10.0 = cm, 1000.0 = m, 25.4 = inch.
    public var lengthUnit: LengthUnit? {
        var scale: Double = 0
        var nameBuf = [CChar](repeating: 0, count: 64)
        guard OCCTDocumentGetLengthUnit(handle, &scale, &nameBuf, 64) else { return nil }
        let name = nameBuf.withUnsafeBufferPointer { buf in
            String(decoding: buf.prefix(while: { $0 != 0 }).map { UInt8(bitPattern: $0) }, as: UTF8.self)
        }
        return LengthUnit(scale: scale, name: name)
    }
}

// MARK: - Layers (v0.31.0)

extension Document {
    /// Number of layers in this document.
    public var layerCount: Int {
        Int(OCCTDocumentGetLayerCount(handle))
    }

    /// Get the name of a layer by index.
    ///
    /// - Parameter index: Zero-based layer index
    /// - Returns: Layer name, or nil if index is out of range
    public func layerName(at index: Int) -> String? {
        var buf = [CChar](repeating: 0, count: 256)
        guard OCCTDocumentGetLayerName(handle, Int32(index), &buf, 256) else { return nil }
        return buf.withUnsafeBufferPointer { ptr in
            String(decoding: ptr.prefix(while: { $0 != 0 }).map { UInt8(bitPattern: $0) }, as: UTF8.self)
        }
    }

    /// All layer names in this document.
    public var layerNames: [String] {
        (0..<layerCount).compactMap { layerName(at: $0) }
    }
}

// MARK: - Materials (v0.31.0)

/// Material information from a document.
public struct MaterialInfo: Sendable {
    /// Material name
    public let name: String
    /// Material description
    public let description: String
    /// Material density
    public let density: Double
}

extension Document {
    /// Number of materials in this document.
    public var materialCount: Int {
        Int(OCCTDocumentGetMaterialCount(handle))
    }

    /// Get material info by index.
    ///
    /// - Parameter index: Zero-based material index
    /// - Returns: Material info, or nil if index is out of range
    public func materialInfo(at index: Int) -> MaterialInfo? {
        var info = OCCTMaterialInfo()
        guard OCCTDocumentGetMaterialInfo(handle, Int32(index), &info) else { return nil }
        let name = withUnsafePointer(to: info.name) { ptr in
            ptr.withMemoryRebound(to: CChar.self, capacity: 128) { buf in
                String(cString: buf)
            }
        }
        let desc = withUnsafePointer(to: info.description) { ptr in
            ptr.withMemoryRebound(to: CChar.self, capacity: 256) { buf in
                String(cString: buf)
            }
        }
        return MaterialInfo(name: name, description: desc, density: info.density)
    }

    /// All materials in this document.
    public var materials: [MaterialInfo] {
        (0..<materialCount).compactMap { materialInfo(at: $0) }
    }
}

// MARK: - TDF Label Properties (v0.54.0)

extension AssemblyNode {
    /// The tag integer identifying this label among its siblings.
    public var tag: Int32 {
        OCCTDocumentLabelTag(document.handle, labelId)
    }

    /// The depth of this label in the tree (root=0, main=1, etc.).
    public var depth: Int32 {
        OCCTDocumentLabelDepth(document.handle, labelId)
    }

    /// Whether this label is null.
    public var isNull: Bool {
        OCCTDocumentLabelIsNull(document.handle, labelId)
    }

    /// Whether this label is the root label (0:).
    public var isRoot: Bool {
        OCCTDocumentLabelIsRoot(document.handle, labelId)
    }

    /// The parent (father) node of this label, or nil if root.
    public var father: AssemblyNode? {
        let fatherId = OCCTDocumentLabelFather(document.handle, labelId)
        guard fatherId >= 0 else { return nil }
        return AssemblyNode(document: document, labelId: fatherId)
    }

    /// The root node of the data framework.
    public var root: AssemblyNode? {
        let rootId = OCCTDocumentLabelRoot(document.handle, labelId)
        guard rootId >= 0 else { return nil }
        return AssemblyNode(document: document, labelId: rootId)
    }

    /// Whether this label has any attributes.
    public var hasAttribute: Bool {
        OCCTDocumentLabelHasAttribute(document.handle, labelId)
    }

    /// The number of attributes on this label.
    public var attributeCount: Int32 {
        OCCTDocumentLabelNbAttributes(document.handle, labelId)
    }

    /// Whether this label has any child labels.
    public var hasChild: Bool {
        OCCTDocumentLabelHasChild(document.handle, labelId)
    }

    /// The number of direct child labels.
    public var childCount: Int32 {
        OCCTDocumentLabelNbChildren(document.handle, labelId)
    }

    /// Find or create a child label by tag.
    ///
    /// - Parameters:
    ///   - tag: The tag to search for
    ///   - create: If true, create the child if it doesn't exist
    /// - Returns: The child node, or nil if not found and create is false
    public func findChild(tag: Int32, create: Bool = false) -> AssemblyNode? {
        let childId = OCCTDocumentLabelFindChild(document.handle, labelId, tag, create)
        guard childId >= 0 else { return nil }
        return AssemblyNode(document: document, labelId: childId)
    }

    /// Remove all attributes from this label.
    ///
    /// - Parameter clearChildren: If true, also clear attributes from child labels
    public func forgetAllAttributes(clearChildren: Bool = true) {
        OCCTDocumentLabelForgetAllAttributes(document.handle, labelId, clearChildren)
    }

    /// Get all descendant labels.
    ///
    /// - Parameter allLevels: If true, recurse all descendants; if false, direct children only
    /// - Returns: Array of descendant nodes
    public func descendants(allLevels: Bool = false) -> [AssemblyNode] {
        let maxCount: Int32 = 1024
        var labelIds = [Int64](repeating: -1, count: Int(maxCount))
        let count = OCCTDocumentGetDescendantLabels(document.handle, labelId,
                                                      allLevels, &labelIds, maxCount)
        return (0..<Int(count)).map { AssemblyNode(document: document, labelId: labelIds[$0]) }
    }

    /// Set the name (TDataStd_Name) on this label.
    ///
    /// - Parameter name: The name to set
    /// - Returns: true if the name was set successfully
    @discardableResult
    public func setName(_ name: String) -> Bool {
        OCCTDocumentSetLabelName(document.handle, labelId, name)
    }
}

// MARK: - TDF Reference (v0.54.0)

extension AssemblyNode {
    /// Set a TDF_Reference from this label to another label.
    ///
    /// - Parameter target: The target label to reference
    /// - Returns: true if the reference was set
    @discardableResult
    public func setReference(to target: AssemblyNode) -> Bool {
        OCCTDocumentLabelSetReference(document.handle, labelId, target.labelId)
    }

    /// Get the label referenced by a TDF_Reference attribute on this label.
    ///
    /// - Returns: The referenced node, or nil if no reference exists
    public var referencedLabel: AssemblyNode? {
        let targetId = OCCTDocumentLabelGetReference(document.handle, labelId)
        guard targetId >= 0 else { return nil }
        return AssemblyNode(document: document, labelId: targetId)
    }
}

// MARK: - TDF CopyLabel (v0.54.0)

extension Document {
    /// Copy a label and all its attributes to a destination label.
    ///
    /// - Parameters:
    ///   - source: The source label to copy from
    ///   - destination: The destination label to copy to
    /// - Returns: true if the copy succeeded
    @discardableResult
    public func copyLabel(from source: AssemblyNode, to destination: AssemblyNode) -> Bool {
        OCCTDocumentCopyLabel(handle, source.labelId, destination.labelId)
    }
}

// MARK: - Document Main Label (v0.54.0)

extension Document {
    /// The main label (0:1) of the document — the root of the user data tree.
    public var mainLabel: AssemblyNode? {
        let labelId = OCCTDocumentGetMainLabel(handle)
        guard labelId >= 0 else { return nil }
        return AssemblyNode(document: self, labelId: labelId)
    }
}

// MARK: - Document Transactions (v0.54.0)

extension Document {
    /// Open a new transaction (command) on the document.
    ///
    /// All changes made after this call can be committed or aborted.
    public func openTransaction() {
        OCCTDocumentOpenTransaction(handle)
    }

    /// Commit the current transaction.
    ///
    /// - Returns: true if committed successfully
    @discardableResult
    public func commitTransaction() -> Bool {
        OCCTDocumentCommitTransaction(handle)
    }

    /// Abort the current transaction, undoing all changes since openTransaction().
    public func abortTransaction() {
        OCCTDocumentAbortTransaction(handle)
    }

    /// Whether a transaction is currently open.
    public var hasOpenTransaction: Bool {
        OCCTDocumentHasOpenTransaction(handle)
    }
}

// MARK: - Document Undo/Redo (v0.54.0)

extension Document {
    /// Set the maximum number of undo steps.
    ///
    /// Must be called before any transactions. Set to 0 to disable undo.
    public func setUndoLimit(_ limit: Int) {
        OCCTDocumentSetUndoLimit(handle, Int32(limit))
    }

    /// The maximum number of undo steps.
    public var undoLimit: Int {
        Int(OCCTDocumentGetUndoLimit(handle))
    }

    /// Perform undo (reverses the last committed transaction).
    ///
    /// - Returns: true if undo was performed
    @discardableResult
    public func undo() -> Bool {
        OCCTDocumentUndo(handle)
    }

    /// Perform redo (reapplies the last undone transaction).
    ///
    /// - Returns: true if redo was performed
    @discardableResult
    public func redo() -> Bool {
        OCCTDocumentRedo(handle)
    }

    /// The number of available undo steps.
    public var availableUndos: Int {
        Int(OCCTDocumentGetAvailableUndos(handle))
    }

    /// The number of available redo steps.
    public var availableRedos: Int {
        Int(OCCTDocumentGetAvailableRedos(handle))
    }
}

// MARK: - Document Modified Labels (v0.54.0)

extension Document {
    /// Mark a label as modified.
    public func setModified(_ node: AssemblyNode) {
        OCCTDocumentSetModified(handle, node.labelId)
    }

    /// Clear all modification marks.
    public func clearModified() {
        OCCTDocumentClearModified(handle)
    }

    /// Check if a label is marked as modified.
    public func isModified(_ node: AssemblyNode) -> Bool {
        OCCTDocumentIsLabelModified(handle, node.labelId)
    }
}

// MARK: - TDataStd Scalar Attributes (v0.55.0)

extension AssemblyNode {
    /// Set an integer attribute (TDataStd_Integer) on this label.
    @discardableResult
    public func setInteger(_ value: Int32) -> Bool {
        OCCTDocumentSetIntegerAttr(document.handle, labelId, value)
    }

    /// Get the integer attribute from this label.
    public var integer: Int32? {
        var value: Int32 = 0
        guard OCCTDocumentGetIntegerAttr(document.handle, labelId, &value) else { return nil }
        return value
    }

    /// Set a real attribute (TDataStd_Real) on this label.
    @discardableResult
    public func setReal(_ value: Double) -> Bool {
        OCCTDocumentSetRealAttr(document.handle, labelId, value)
    }

    /// Get the real attribute from this label.
    public var real: Double? {
        var value: Double = 0
        guard OCCTDocumentGetRealAttr(document.handle, labelId, &value) else { return nil }
        return value
    }

    /// Set an ASCII string attribute (TDataStd_AsciiString) on this label.
    @discardableResult
    public func setAsciiString(_ value: String) -> Bool {
        OCCTDocumentSetAsciiStringAttr(document.handle, labelId, value)
    }

    /// Get the ASCII string attribute from this label.
    public var asciiString: String? {
        guard let cStr = OCCTDocumentGetAsciiStringAttr(document.handle, labelId) else { return nil }
        let result = String(cString: cStr)
        OCCTStringFree(cStr)
        return result
    }

    /// Set a comment attribute (TDataStd_Comment) on this label.
    @discardableResult
    public func setComment(_ value: String) -> Bool {
        OCCTDocumentSetCommentAttr(document.handle, labelId, value)
    }

    /// Get the comment attribute from this label.
    public var comment: String? {
        guard let cStr = OCCTDocumentGetCommentAttr(document.handle, labelId) else { return nil }
        let result = String(cString: cStr)
        OCCTStringFree(cStr)
        return result
    }
}

// MARK: - TDataStd Integer Array (v0.55.0)

extension AssemblyNode {
    /// Initialize an integer array attribute on this label.
    ///
    /// - Parameters:
    ///   - lower: Lower bound index
    ///   - upper: Upper bound index
    @discardableResult
    public func initIntegerArray(lower: Int32, upper: Int32) -> Bool {
        OCCTDocumentInitIntegerArray(document.handle, labelId, lower, upper)
    }

    /// Set a value in the integer array attribute.
    @discardableResult
    public func setIntegerArrayValue(at index: Int32, value: Int32) -> Bool {
        OCCTDocumentSetIntegerArrayValue(document.handle, labelId, index, value)
    }

    /// Get a value from the integer array attribute.
    public func integerArrayValue(at index: Int32) -> Int32? {
        var value: Int32 = 0
        guard OCCTDocumentGetIntegerArrayValue(document.handle, labelId, index, &value) else { return nil }
        return value
    }

    /// Get the bounds of the integer array attribute.
    public var integerArrayBounds: (lower: Int32, upper: Int32)? {
        var lower: Int32 = 0, upper: Int32 = 0
        guard OCCTDocumentGetIntegerArrayBounds(document.handle, labelId, &lower, &upper) else { return nil }
        return (lower, upper)
    }
}

// MARK: - TDataStd Real Array (v0.55.0)

extension AssemblyNode {
    /// Initialize a real array attribute on this label.
    ///
    /// - Parameters:
    ///   - lower: Lower bound index
    ///   - upper: Upper bound index
    @discardableResult
    public func initRealArray(lower: Int32, upper: Int32) -> Bool {
        OCCTDocumentInitRealArray(document.handle, labelId, lower, upper)
    }

    /// Set a value in the real array attribute.
    @discardableResult
    public func setRealArrayValue(at index: Int32, value: Double) -> Bool {
        OCCTDocumentSetRealArrayValue(document.handle, labelId, index, value)
    }

    /// Get a value from the real array attribute.
    public func realArrayValue(at index: Int32) -> Double? {
        var value: Double = 0
        guard OCCTDocumentGetRealArrayValue(document.handle, labelId, index, &value) else { return nil }
        return value
    }

    /// Get the bounds of the real array attribute.
    public var realArrayBounds: (lower: Int32, upper: Int32)? {
        var lower: Int32 = 0, upper: Int32 = 0
        guard OCCTDocumentGetRealArrayBounds(document.handle, labelId, &lower, &upper) else { return nil }
        return (lower, upper)
    }
}

// MARK: - TDataStd TreeNode (v0.55.0)

extension AssemblyNode {
    /// Set a tree node attribute (TDataStd_TreeNode) on this label.
    @discardableResult
    public func setTreeNode() -> Bool {
        OCCTDocumentSetTreeNode(document.handle, labelId)
    }

    /// Append a child to this tree node.
    @discardableResult
    public func appendTreeChild(_ child: AssemblyNode) -> Bool {
        OCCTDocumentAppendTreeChild(document.handle, labelId, child.labelId)
    }

    /// The father (parent) of this tree node.
    public var treeNodeFather: AssemblyNode? {
        let fatherId = OCCTDocumentTreeNodeFather(document.handle, labelId)
        guard fatherId >= 0 else { return nil }
        return AssemblyNode(document: document, labelId: fatherId)
    }

    /// The first child of this tree node.
    public var treeNodeFirstChild: AssemblyNode? {
        let firstId = OCCTDocumentTreeNodeFirst(document.handle, labelId)
        guard firstId >= 0 else { return nil }
        return AssemblyNode(document: document, labelId: firstId)
    }

    /// The next sibling of this tree node.
    public var treeNodeNext: AssemblyNode? {
        let nextId = OCCTDocumentTreeNodeNext(document.handle, labelId)
        guard nextId >= 0 else { return nil }
        return AssemblyNode(document: document, labelId: nextId)
    }

    /// Whether this tree node has a father.
    public var treeNodeHasFather: Bool {
        OCCTDocumentTreeNodeHasFather(document.handle, labelId)
    }

    /// The depth of this tree node (root=0).
    public var treeNodeDepth: Int32 {
        OCCTDocumentTreeNodeDepth(document.handle, labelId)
    }

    /// The number of children of this tree node.
    public var treeNodeChildCount: Int32 {
        OCCTDocumentTreeNodeNbChildren(document.handle, labelId)
    }
}

// MARK: - TDataStd NamedData (v0.55.0)

extension AssemblyNode {
    /// Set a named integer value on this label.
    @discardableResult
    public func setNamedInteger(_ name: String, value: Int32) -> Bool {
        OCCTDocumentNamedDataSetInteger(document.handle, labelId, name, value)
    }

    /// Get a named integer value from this label.
    public func namedInteger(_ name: String) -> Int32? {
        var value: Int32 = 0
        guard OCCTDocumentNamedDataGetInteger(document.handle, labelId, name, &value) else { return nil }
        return value
    }

    /// Check if a named integer exists on this label.
    public func hasNamedInteger(_ name: String) -> Bool {
        OCCTDocumentNamedDataHasInteger(document.handle, labelId, name)
    }

    /// Set a named real value on this label.
    @discardableResult
    public func setNamedReal(_ name: String, value: Double) -> Bool {
        OCCTDocumentNamedDataSetReal(document.handle, labelId, name, value)
    }

    /// Get a named real value from this label.
    public func namedReal(_ name: String) -> Double? {
        var value: Double = 0
        guard OCCTDocumentNamedDataGetReal(document.handle, labelId, name, &value) else { return nil }
        return value
    }

    /// Check if a named real exists on this label.
    public func hasNamedReal(_ name: String) -> Bool {
        OCCTDocumentNamedDataHasReal(document.handle, labelId, name)
    }

    /// Set a named string value on this label.
    @discardableResult
    public func setNamedString(_ name: String, value: String) -> Bool {
        OCCTDocumentNamedDataSetString(document.handle, labelId, name, value)
    }

    /// Get a named string value from this label.
    public func namedString(_ name: String) -> String? {
        guard let cStr = OCCTDocumentNamedDataGetString(document.handle, labelId, name) else { return nil }
        let result = String(cString: cStr)
        OCCTStringFree(cStr)
        return result
    }

    /// Check if a named string exists on this label.
    public func hasNamedString(_ name: String) -> Bool {
        OCCTDocumentNamedDataHasString(document.handle, labelId, name)
    }
}

// MARK: - TDataXtd Shape Attribute (v0.56.0)

/// Geometry type for TDataXtd_Geometry attributes.
public enum GeometryType: Int32 {
    case anyGeom = 0
    case point = 1
    case line = 2
    case circle = 3
    case ellipse = 4
    case spline = 5
    case plane = 6
    case cylinder = 7
}

/// Execution status for TFunction graph nodes.
public enum ExecutionStatus: Int32 {
    case wrongDefinition = 0
    case notExecuted = 1
    case executing = 2
    case succeeded = 3
    case failed = 4
}

extension AssemblyNode {

    // MARK: - TDataXtd Shape Attribute

    /// Set a shape attribute on this label (stores shape via TNaming).
    @discardableResult
    public func setShapeAttribute(_ shape: Shape) -> Bool {
        OCCTDocumentSetShapeAttr(document.handle, labelId, shape.handle)
    }

    /// Get the shape stored in a TDataXtd_Shape attribute on this label.
    public func shapeAttribute() -> Shape? {
        guard let ref = OCCTDocumentGetShapeAttr(document.handle, labelId) else { return nil }
        return Shape(handle: ref)
    }

    /// Check if this label has a TDataXtd_Shape attribute.
    public var hasShapeAttribute: Bool {
        OCCTDocumentHasShapeAttr(document.handle, labelId)
    }

    // MARK: - TDataXtd Position Attribute

    /// Set a position (3D point) attribute on this label.
    @discardableResult
    public func setPositionAttribute(x: Double, y: Double, z: Double) -> Bool {
        OCCTDocumentSetPositionAttr(document.handle, labelId, x, y, z)
    }

    /// Get the position attribute from this label.
    public func positionAttribute() -> (x: Double, y: Double, z: Double)? {
        var x: Double = 0, y: Double = 0, z: Double = 0
        guard OCCTDocumentGetPositionAttr(document.handle, labelId, &x, &y, &z) else { return nil }
        return (x, y, z)
    }

    /// Check if this label has a TDataXtd_Position attribute.
    public var hasPositionAttribute: Bool {
        OCCTDocumentHasPositionAttr(document.handle, labelId)
    }

    // MARK: - TDataXtd Geometry Attribute

    /// Set a geometry type attribute on this label.
    @discardableResult
    public func setGeometryType(_ type: GeometryType) -> Bool {
        OCCTDocumentSetGeometryAttr(document.handle, labelId, type.rawValue)
    }

    /// Get the geometry type from this label.
    public func geometryType() -> GeometryType? {
        let raw = OCCTDocumentGetGeometryType(document.handle, labelId)
        guard raw >= 0 else { return nil }
        return GeometryType(rawValue: raw)
    }

    /// Check if this label has a TDataXtd_Geometry attribute.
    public var hasGeometryAttribute: Bool {
        OCCTDocumentHasGeometryAttr(document.handle, labelId)
    }

    // MARK: - TDataXtd Triangulation Attribute

    /// Set a triangulation attribute on this label by meshing a shape.
    @discardableResult
    public func setTriangulationFromShape(_ shape: Shape, deflection: Double = 1.0) -> Bool {
        OCCTDocumentSetTriangulationFromShape(document.handle, labelId, shape.handle, deflection)
    }

    /// Get the number of nodes in the triangulation attribute.
    public var triangulationNodeCount: Int32 {
        OCCTDocumentTriangulationNbNodes(document.handle, labelId)
    }

    /// Get the number of triangles in the triangulation attribute.
    public var triangulationTriangleCount: Int32 {
        OCCTDocumentTriangulationNbTriangles(document.handle, labelId)
    }

    /// Get the deflection of the triangulation attribute.
    public var triangulationDeflection: Double {
        OCCTDocumentTriangulationDeflection(document.handle, labelId)
    }

    // MARK: - TDataXtd Point/Axis/Plane Attributes

    /// Set a point attribute on this label.
    @discardableResult
    public func setPointAttribute(x: Double, y: Double, z: Double) -> Bool {
        OCCTDocumentSetPointAttr(document.handle, labelId, x, y, z)
    }

    /// Set an axis attribute on this label (origin + direction).
    @discardableResult
    public func setAxisAttribute(originX: Double, originY: Double, originZ: Double,
                                  directionX: Double, directionY: Double, directionZ: Double) -> Bool {
        OCCTDocumentSetAxisAttr(document.handle, labelId, originX, originY, originZ, directionX, directionY, directionZ)
    }

    /// Set a plane attribute on this label (origin + normal).
    @discardableResult
    public func setPlaneAttribute(originX: Double, originY: Double, originZ: Double,
                                   normalX: Double, normalY: Double, normalZ: Double) -> Bool {
        OCCTDocumentSetPlaneAttr(document.handle, labelId, originX, originY, originZ, normalX, normalY, normalZ)
    }
}

// MARK: - TFunction Logbook (v0.56.0)

extension AssemblyNode {

    /// Create a TFunction_Logbook attribute on this label.
    @discardableResult
    public func setLogbook() -> Bool {
        OCCTDocumentSetLogbook(document.handle, labelId)
    }

    /// Mark a target label as touched in this label's logbook.
    @discardableResult
    public func logbookSetTouched(_ target: AssemblyNode) -> Bool {
        OCCTDocumentLogbookSetTouched(document.handle, labelId, target.labelId)
    }

    /// Mark a target label as impacted in this label's logbook.
    @discardableResult
    public func logbookSetImpacted(_ target: AssemblyNode) -> Bool {
        OCCTDocumentLogbookSetImpacted(document.handle, labelId, target.labelId)
    }

    /// Check if a target label is modified (touched) in this label's logbook.
    public func logbookIsModified(_ target: AssemblyNode) -> Bool {
        OCCTDocumentLogbookIsModified(document.handle, labelId, target.labelId)
    }

    /// Clear this label's logbook.
    @discardableResult
    public func logbookClear() -> Bool {
        OCCTDocumentLogbookClear(document.handle, labelId)
    }

    /// Check if this label's logbook is empty.
    public var logbookIsEmpty: Bool {
        OCCTDocumentLogbookIsEmpty(document.handle, labelId)
    }
}

// MARK: - TFunction GraphNode (v0.56.0)

extension AssemblyNode {

    /// Create a TFunction_GraphNode attribute on this label.
    @discardableResult
    public func setGraphNode() -> Bool {
        OCCTDocumentSetGraphNode(document.handle, labelId)
    }

    /// Add a previous dependency to this graph node (by tag ID).
    @discardableResult
    public func graphNodeAddPrevious(tag: Int32) -> Bool {
        OCCTDocumentGraphNodeAddPrevious(document.handle, labelId, tag)
    }

    /// Add a next dependency to this graph node (by tag ID).
    @discardableResult
    public func graphNodeAddNext(tag: Int32) -> Bool {
        OCCTDocumentGraphNodeAddNext(document.handle, labelId, tag)
    }

    /// Set the execution status of this graph node.
    @discardableResult
    public func setGraphNodeStatus(_ status: ExecutionStatus) -> Bool {
        OCCTDocumentGraphNodeSetStatus(document.handle, labelId, status.rawValue)
    }

    /// Get the execution status of this graph node.
    public func graphNodeStatus() -> ExecutionStatus? {
        let raw = OCCTDocumentGraphNodeGetStatus(document.handle, labelId)
        guard raw >= 0 else { return nil }
        return ExecutionStatus(rawValue: raw)
    }

    /// Remove all previous dependencies from this graph node.
    @discardableResult
    public func graphNodeRemoveAllPrevious() -> Bool {
        OCCTDocumentGraphNodeRemoveAllPrevious(document.handle, labelId)
    }

    /// Remove all next dependencies from this graph node.
    @discardableResult
    public func graphNodeRemoveAllNext() -> Bool {
        OCCTDocumentGraphNodeRemoveAllNext(document.handle, labelId)
    }
}

// MARK: - TFunction Function Attribute (v0.56.0)

extension AssemblyNode {

    /// Create a TFunction_Function attribute on this label.
    @discardableResult
    public func setFunctionAttribute() -> Bool {
        OCCTDocumentSetFunctionAttr(document.handle, labelId)
    }

    /// Check if the function attribute on this label has failed.
    public var functionIsFailed: Bool {
        OCCTDocumentFunctionIsFailed(document.handle, labelId)
    }

    /// Get the failure mode of the function attribute on this label.
    public var functionFailure: Int32? {
        let raw = OCCTDocumentFunctionGetFailure(document.handle, labelId)
        guard raw >= 0 else { return nil }
        return raw
    }

    /// Set the failure mode of the function attribute on this label.
    @discardableResult
    public func setFunctionFailure(_ mode: Int32) -> Bool {
        OCCTDocumentFunctionSetFailure(document.handle, labelId, mode)
    }
}

// MARK: - TNaming CopyShape (v0.56.0)

extension Shape {

    /// Create a deep copy of this shape (independent copy with new topology).
    public func deepCopy() -> Shape? {
        guard let ref = OCCTShapeDeepCopy(handle) else { return nil }
        return Shape(handle: ref)
    }
}

// MARK: - PCDM Status Enums (v0.57.0)

/// Status returned by OCAF document save operations.
public enum StoreStatus: Int32 {
    case ok = 0
    case driverFailure = 1
    case writeFailure = 2
    case failure = 3
    case docIsNull = 4
    case noObj = 5
    case infoSectionError = 6
    case userBreak = 7
    case unrecognizedFormat = 8
}

/// Status returned by OCAF document load operations.
public enum ReaderStatus: Int32 {
    case ok = 0
    case noDriver = 1
    case unknownFileDriver = 2
    case openError = 3
    case noVersion = 4
    case noSchema = 5
    case noDocument = 6
    case extensionFailure = 7
    case wrongStreamMode = 8
    case formatFailure = 9
    case typeFailure = 10
    case typeNotFoundInSchema = 11
    case unrecognizedFileFormat = 12
    case makeFailure = 13
    case permissionDenied = 14
    case driverFailure = 15
    case alreadyRetrievedAndModified = 16
    case alreadyRetrieved = 17
    case unknownDocument = 18
    case wrongResource = 19
    case readerException = 20
    case noModel = 21
    case userBreak = 22
}

// MARK: - OCAF Persistence (v0.57.0)

extension Document {

    // MARK: - Format Registration

    /// Register binary OCAF format drivers (BinOcaf).
    public func defineFormatBin() {
        OCCTDocumentDefineFormatBin(handle)
    }

    /// Register lite binary OCAF format drivers (BinLOcaf).
    public func defineFormatBinL() {
        OCCTDocumentDefineFormatBinL(handle)
    }

    /// Register XML OCAF format drivers (XmlOcaf).
    public func defineFormatXml() {
        OCCTDocumentDefineFormatXml(handle)
    }

    /// Register lite XML OCAF format drivers (XmlLOcaf).
    public func defineFormatXmlL() {
        OCCTDocumentDefineFormatXmlL(handle)
    }

    /// Register binary XCAF format drivers (BinXCAF).
    public func defineFormatBinXCAF() {
        OCCTDocumentDefineFormatBinXCAF(handle)
    }

    /// Register XML XCAF format drivers (XmlXCAF).
    public func defineFormatXmlXCAF() {
        OCCTDocumentDefineFormatXmlXCAF(handle)
    }

    /// Register all available persistence format drivers.
    public func defineAllFormats() {
        defineFormatBin()
        defineFormatBinL()
        defineFormatXml()
        defineFormatXmlL()
        defineFormatBinXCAF()
        defineFormatXmlXCAF()
    }

    // MARK: - Save/Load

    /// Save the OCAF document to a file. Format is determined by storage format.
    /// Call `defineAllFormats()` or specific format registration before saving.
    public func saveOCAF(to path: String) -> StoreStatus {
        let raw = OCCTDocumentSaveOCAF(handle, path)
        return StoreStatus(rawValue: raw) ?? .failure
    }

    /// Save the OCAF document to the path it was previously saved to.
    public func saveOCAFInPlace() -> StoreStatus {
        let raw = OCCTDocumentSaveOCAFInPlace(handle)
        return StoreStatus(rawValue: raw) ?? .failure
    }

    /// Load an OCAF document from a file. Registers all format drivers automatically.
    public static func loadOCAF(from path: String) -> (document: Document?, status: ReaderStatus) {
        var statusRaw: Int32 = -1
        guard let ref = OCCTDocumentLoadOCAF(path, &statusRaw) else {
            return (nil, ReaderStatus(rawValue: statusRaw) ?? .openError)
        }
        return (Document(handle: ref), ReaderStatus(rawValue: statusRaw) ?? .ok)
    }

    /// Create a new document with a specific OCAF format.
    /// Supported: "BinOcaf", "XmlOcaf", "BinLOcaf", "XmlLOcaf", "BinXCAF", "XmlXCAF".
    public static func create(format: String) -> Document? {
        guard let ref = OCCTDocumentCreateWithFormat(format) else { return nil }
        return Document(handle: ref)
    }

    // MARK: - Document Metadata

    /// Whether the document has been previously saved.
    public var isSaved: Bool {
        OCCTDocumentIsSaved(handle)
    }

    /// The storage format of the document (e.g. "MDTV-XCAF", "BinOcaf").
    public var storageFormat: String? {
        guard let cStr = OCCTDocumentGetStorageFormat(handle) else { return nil }
        let result = String(cString: cStr)
        OCCTStringFree(cStr)
        return result
    }

    /// Change the storage format of the document.
    @discardableResult
    public func setStorageFormat(_ format: String) -> Bool {
        OCCTDocumentSetStorageFormat(handle, format)
    }

    /// Number of documents in the application session.
    public var documentCount: Int32 {
        OCCTDocumentNbDocuments(handle)
    }

    /// Get the list of available reading formats.
    public var readingFormats: [String] {
        var buffers = [UnsafePointer<CChar>?](repeating: nil, count: 20)
        let count = OCCTDocumentReadingFormats(handle, &buffers, 20)
        var result: [String] = []
        for i in 0..<Int(count) {
            if let cStr = buffers[i] {
                result.append(String(cString: cStr))
                OCCTStringFree(cStr)
            }
        }
        return result
    }

    /// Get the list of available writing formats.
    public var writingFormats: [String] {
        var buffers = [UnsafePointer<CChar>?](repeating: nil, count: 20)
        let count = OCCTDocumentWritingFormats(handle, &buffers, 20)
        var result: [String] = []
        for i in 0..<Int(count) {
            if let cStr = buffers[i] {
                result.append(String(cString: cStr))
                OCCTStringFree(cStr)
            }
        }
        return result
    }

    // MARK: - STEP Mode-Controlled Import/Export (v0.58.0)

    /// Load a STEP file with individual mode control for what data to import.
    ///
    /// Unlike `Document.load(from:)` which enables all modes, this allows fine-grained
    /// control over which data types are imported from the STEP file.
    ///
    /// - Parameters:
    ///   - url: URL to the STEP file
    ///   - modes: Reader mode flags controlling which data to import
    /// - Returns: Document with the requested data, or nil on failure
    public static func loadSTEP(from url: URL, modes: STEPReaderModes) -> Document? {
        guard let ref = OCCTDocumentLoadSTEPWithModes(url.path,
            modes.color, modes.name, modes.layer,
            modes.props, modes.gdt, modes.material) else { return nil }
        return Document(handle: ref)
    }

    /// Load a STEP file with individual mode control for what data to import.
    public static func loadSTEP(fromPath path: String, modes: STEPReaderModes) -> Document? {
        guard let ref = OCCTDocumentLoadSTEPWithModes(path,
            modes.color, modes.name, modes.layer,
            modes.props, modes.gdt, modes.material) else { return nil }
        return Document(handle: ref)
    }

    /// Write the document to a STEP file with model type and mode control.
    ///
    /// - Parameters:
    ///   - url: Output file URL
    ///   - modelType: STEP representation type (default: .asIs)
    ///   - modes: Writer mode flags controlling which data to export
    /// - Returns: true on success
    @discardableResult
    public func writeSTEP(to url: URL, modelType: StepModelType = .asIs, modes: STEPWriterModes = STEPWriterModes()) -> Bool {
        OCCTDocumentWriteSTEPWithModes(handle, url.path,
            modelType.rawValue,
            modes.color, modes.name, modes.layer,
            modes.dimTol, modes.material)
    }

    /// Write the document to a STEP file with model type and mode control.
    @discardableResult
    public func writeSTEP(toPath path: String, modelType: StepModelType = .asIs, modes: STEPWriterModes = STEPWriterModes()) -> Bool {
        OCCTDocumentWriteSTEPWithModes(handle, path,
            modelType.rawValue,
            modes.color, modes.name, modes.layer,
            modes.dimTol, modes.material)
    }
}

// MARK: - STEP Model Type (v0.58.0)

/// STEP representation type for controlling how shapes are written.
public enum StepModelType: Int32, Sendable {
    /// Write shape as-is (automatic selection)
    case asIs = 0
    /// Write as manifold solid B-rep
    case manifoldSolidBrep = 1
    /// Write as B-rep with voids
    case brepWithVoids = 2
    /// Write as faceted B-rep
    case facetedBrep = 3
    /// Write as faceted B-rep and B-rep with voids
    case facetedBrepAndBrepWithVoids = 4
    /// Write as shell-based surface model
    case shellBasedSurfaceModel = 5
    /// Write as geometric curve set
    case geometricCurveSet = 6
}

// MARK: - STEP Reader/Writer Modes (v0.58.0)

/// Mode flags for STEPCAFControl_Reader controlling which data to import from STEP files.
public struct STEPReaderModes: Sendable {
    /// Import color information (default: true)
    public var color: Bool
    /// Import name/label information (default: true)
    public var name: Bool
    /// Import layer information (default: true)
    public var layer: Bool
    /// Import validation properties (default: true)
    public var props: Bool
    /// Import GD&T data (default: false)
    public var gdt: Bool
    /// Import material data (default: true)
    public var material: Bool

    public init(color: Bool = true, name: Bool = true, layer: Bool = true,
                props: Bool = true, gdt: Bool = false, material: Bool = true) {
        self.color = color
        self.name = name
        self.layer = layer
        self.props = props
        self.gdt = gdt
        self.material = material
    }
}

/// Mode flags for STEPCAFControl_Writer controlling which data to export to STEP files.
public struct STEPWriterModes: Sendable {
    /// Export color information (default: true)
    public var color: Bool
    /// Export name/label information (default: true)
    public var name: Bool
    /// Export layer information (default: true)
    public var layer: Bool
    /// Export dimension/tolerance data (default: false)
    public var dimTol: Bool
    /// Export material data (default: true)
    public var material: Bool

    public init(color: Bool = true, name: Bool = true, layer: Bool = true,
                dimTol: Bool = false, material: Bool = true) {
        self.color = color
        self.name = name
        self.layer = layer
        self.dimTol = dimTol
        self.material = material
    }
}

// MARK: - OBJ/PLY Document I/O (v0.59.0)

extension Document {

    /// Load an OBJ file into an XDE document (preserves materials, names).
    public static func loadOBJ(from url: URL) -> Document? {
        guard let ref = OCCTDocumentLoadOBJ(url.path) else { return nil }
        return Document(handle: ref)
    }

    /// Load an OBJ file into an XDE document (preserves materials, names).
    public static func loadOBJ(fromPath path: String) -> Document? {
        guard let ref = OCCTDocumentLoadOBJ(path) else { return nil }
        return Document(handle: ref)
    }

    /// Load an OBJ file with options.
    ///
    /// - Parameters:
    ///   - url: URL to the OBJ file
    ///   - singlePrecision: Use single precision for vertex data (default: false)
    ///   - systemLengthUnit: System length unit in meters (e.g. 0.001 for mm). 0 = default.
    public static func loadOBJ(from url: URL, singlePrecision: Bool, systemLengthUnit: Double = 0) -> Document? {
        guard let ref = OCCTDocumentLoadOBJWithOptions(url.path, singlePrecision, systemLengthUnit) else { return nil }
        return Document(handle: ref)
    }

    /// Load an OBJ file with coordinate system conversion.
    ///
    /// - Parameters:
    ///   - url: URL to the OBJ file
    ///   - inputCS: Input coordinate system
    ///   - outputCS: Output coordinate system
    ///   - inputLengthUnit: Input length unit in meters (0 = default)
    ///   - outputLengthUnit: Output length unit in meters (0 = default)
    public static func loadOBJ(from url: URL, inputCS: MeshCoordinateSystem, outputCS: MeshCoordinateSystem,
                                inputLengthUnit: Double = 0, outputLengthUnit: Double = 0) -> Document? {
        guard let ref = OCCTDocumentLoadOBJWithCS(url.path,
            inputCS.rawValue, outputCS.rawValue,
            inputLengthUnit, outputLengthUnit) else { return nil }
        return Document(handle: ref)
    }

    /// Write the document to an OBJ file.
    ///
    /// - Parameters:
    ///   - url: Output file URL
    ///   - deflection: Mesh deflection for tessellation (0 = skip re-meshing)
    /// - Returns: true on success
    @discardableResult
    public func writeOBJ(to url: URL, deflection: Double = 1.0) -> Bool {
        OCCTDocumentWriteOBJ(handle, url.path, deflection)
    }

    /// Write the document to a PLY file with options.
    ///
    /// - Parameters:
    ///   - url: Output file URL
    ///   - deflection: Mesh deflection for tessellation (0 = skip re-meshing)
    ///   - normals: Include normals (default: true)
    ///   - colors: Include colors (default: false)
    ///   - texCoords: Include texture coordinates (default: false)
    /// - Returns: true on success
    @discardableResult
    public func writePLY(to url: URL, deflection: Double = 1.0,
                          normals: Bool = true, colors: Bool = false, texCoords: Bool = false) -> Bool {
        OCCTDocumentWritePLY(handle, url.path, deflection, normals, colors, texCoords)
    }
}

// MARK: - Mesh Coordinate System (v0.59.0)

/// Coordinate system for mesh import/export.
public enum MeshCoordinateSystem: Int32, Sendable {
    /// Undefined coordinate system
    case undefined = -1
    /// +Y forward, +Z up (Blender convention)
    case zUp = 0
    /// -Z forward, +Y up (glTF convention)
    case yUp = 1

    /// Blender coordinate system (alias for zUp)
    public static let blender = MeshCoordinateSystem.zUp
    /// glTF coordinate system (alias for yUp)
    public static let gltf = MeshCoordinateSystem.yUp
}

// MARK: - XDE ShapeTool Expansion (v0.60.0)

extension Document {
    /// Total number of shapes in the document (all levels).
    public var shapeCount: Int32 {
        OCCTDocumentGetShapeCount(handle)
    }

    /// Get label ID for a shape at index (from all shapes).
    public func shapeLabelId(at index: Int32) -> Int64 {
        OCCTDocumentGetShapeLabelId(handle, index)
    }

    /// Number of free (top-level) shapes.
    public var freeShapeCount: Int32 {
        OCCTDocumentGetFreeShapeCount(handle)
    }

    /// Get label ID for a free shape at index.
    public func freeShapeLabelId(at index: Int32) -> Int64 {
        OCCTDocumentGetFreeShapeLabelId(handle, index)
    }

    /// Add a shape to the document.
    /// - Parameters:
    ///   - shape: The shape to add
    ///   - makeAssembly: If true, compound shapes become assemblies
    /// - Returns: Label ID of the added shape, or -1 on failure
    @discardableResult
    public func addShape(_ shape: Shape, makeAssembly: Bool = true) -> Int64 {
        OCCTDocumentAddShape(handle, shape.handle, makeAssembly)
    }

    /// Create a new empty shape label.
    /// - Returns: Label ID of the new label, or -1 on failure
    public func newShapeLabel() -> Int64 {
        OCCTDocumentNewShape(handle)
    }

    /// Remove a shape from the document.
    /// - Parameter labelId: Label ID of the shape to remove
    /// - Returns: true if removed successfully
    @discardableResult
    public func removeShape(labelId: Int64) -> Bool {
        OCCTDocumentRemoveShape(handle, labelId)
    }

    /// Find label ID for a given shape in the document.
    /// - Returns: Label ID, or -1 if not found
    public func findShape(_ shape: Shape) -> Int64 {
        OCCTDocumentFindShape(handle, shape.handle)
    }

    /// Search for a shape in the document (including sub-shapes).
    /// - Returns: Label ID, or -1 if not found
    public func searchShape(_ shape: Shape) -> Int64 {
        OCCTDocumentSearchShape(handle, shape.handle)
    }

    /// Add a component to an assembly with translation.
    /// - Parameters:
    ///   - assemblyLabelId: Assembly label ID
    ///   - shapeLabelId: Shape to add as component
    ///   - translation: Translation (tx, ty, tz)
    /// - Returns: Component label ID, or -1 on failure
    @discardableResult
    public func addComponent(assemblyLabelId: Int64, shapeLabelId: Int64,
                              translation: (Double, Double, Double) = (0, 0, 0)) -> Int64 {
        OCCTDocumentAddComponent(handle, assemblyLabelId, shapeLabelId,
                                  translation.0, translation.1, translation.2)
    }

    /// Remove a component from an assembly.
    public func removeComponent(labelId: Int64) {
        OCCTDocumentRemoveComponent(handle, labelId)
    }

    /// Get number of components in an assembly.
    public func componentCount(assemblyLabelId: Int64) -> Int32 {
        OCCTDocumentGetComponentCount(handle, assemblyLabelId)
    }

    /// Get component label ID at index.
    public func componentLabelId(assemblyLabelId: Int64, at index: Int32) -> Int64 {
        OCCTDocumentGetComponentLabelId(handle, assemblyLabelId, index)
    }

    /// Get the referred (original) shape label for a component.
    /// - Returns: Referred label ID, or -1 if not a reference
    public func componentReferredLabelId(_ componentLabelId: Int64) -> Int64 {
        OCCTDocumentGetComponentReferredLabelId(handle, componentLabelId)
    }

    /// Get number of labels that reference a given shape.
    public func shapeUserCount(shapeLabelId: Int64) -> Int32 {
        OCCTDocumentGetShapeUserCount(handle, shapeLabelId)
    }

    /// Update all assemblies (recompute compounds from components).
    public func updateAssemblies() {
        OCCTDocumentUpdateAssemblies(handle)
    }

    /// Expand a compound shape into an assembly (ShapeTool::Expand).
    @discardableResult
    public func expandShape(labelId: Int64) -> Bool {
        OCCTDocumentExpandShape(handle, labelId)
    }
}

// MARK: - XDE Label Queries (v0.60.0)

extension AssemblyNode {
    /// Whether this label is top-level.
    public var isTopLevel: Bool {
        OCCTDocumentIsTopLevel(document.handle, labelId)
    }

    /// Whether this label is a component (instance inside an assembly).
    public var isComponent: Bool {
        OCCTDocumentIsComponent(document.handle, labelId)
    }

    /// Whether this label represents a compound shape.
    public var isCompound: Bool {
        OCCTDocumentIsCompound(document.handle, labelId)
    }

    /// Whether this label represents a sub-shape.
    public var isSubShape: Bool {
        OCCTDocumentIsSubShape(document.handle, labelId)
    }

    /// Number of sub-shapes for this label.
    public var subShapeCount: Int32 {
        OCCTDocumentGetSubShapeCount(document.handle, labelId)
    }

    /// Get sub-shape label at index.
    public func subShapeNode(at index: Int32) -> AssemblyNode? {
        let subId = OCCTDocumentGetSubShapeLabelId(document.handle, labelId, index)
        guard subId >= 0 else { return nil }
        return AssemblyNode(document: document, labelId: subId)
    }

    /// Number of labels that reference (use) this shape.
    public var userCount: Int32 {
        OCCTDocumentGetShapeUserCount(document.handle, labelId)
    }

    /// Visibility of this label.
    public var isVisible: Bool {
        get { OCCTDocumentGetLabelVisibility(document.handle, labelId) }
        set { OCCTDocumentSetLabelVisibility(document.handle, labelId, newValue) }
    }
}

// MARK: - XDE ColorTool by Shape (v0.60.0)

extension Document {
    /// Set color on a shape directly (not by label).
    /// - Parameters:
    ///   - shape: The shape to color
    ///   - color: The color to set
    ///   - type: Color type — generic (0), surface (1), or curve (2)
    public func setShapeColor(_ shape: Shape, color: Color, type: OCCTColorType = OCCTColorTypeSurface) {
        OCCTDocumentSetShapeColor(handle, shape.handle, Int32(type.rawValue),
                                   color.red, color.green, color.blue)
    }

    /// Get color for a shape (not by label).
    /// - Parameters:
    ///   - shape: The shape to query
    ///   - type: Color type — generic (0), surface (1), or curve (2)
    /// - Returns: Color if set, nil otherwise
    public func shapeColor(_ shape: Shape, type: OCCTColorType = OCCTColorTypeSurface) -> Color? {
        let c = OCCTDocumentGetShapeColor(handle, shape.handle, Int32(type.rawValue))
        guard c.isSet else { return nil }
        return Color(red: c.r, green: c.g, blue: c.b, alpha: c.a)
    }

    /// Check if color is set on a shape.
    public func isShapeColorSet(_ shape: Shape, type: OCCTColorType = OCCTColorTypeSurface) -> Bool {
        OCCTDocumentIsShapeColorSet(handle, shape.handle, Int32(type.rawValue))
    }
}

// MARK: - XDE Area / Volume / Centroid (v0.60.0)

extension AssemblyNode {
    /// Set area attribute on this label.
    public func setArea(_ area: Double) {
        OCCTDocumentSetArea(document.handle, labelId, area)
    }

    /// Get area attribute from this label.
    /// - Returns: Area value, or nil if not set
    public var area: Double? {
        let val = OCCTDocumentGetArea(document.handle, labelId)
        return val < 0 ? nil : val
    }

    /// Set volume attribute on this label.
    public func setVolume(_ volume: Double) {
        OCCTDocumentSetVolume(document.handle, labelId, volume)
    }

    /// Get volume attribute from this label.
    /// - Returns: Volume value, or nil if not set
    public var volume: Double? {
        let val = OCCTDocumentGetVolume(document.handle, labelId)
        return val < 0 ? nil : val
    }

    /// Set centroid attribute on this label.
    public func setCentroid(x: Double, y: Double, z: Double) {
        OCCTDocumentSetCentroid(document.handle, labelId, x, y, z)
    }

    /// Get centroid attribute from this label.
    /// - Returns: Centroid as (x, y, z), or nil if not set
    public var centroid: (x: Double, y: Double, z: Double)? {
        var x: Double = 0, y: Double = 0, z: Double = 0
        if OCCTDocumentGetCentroid(document.handle, labelId, &x, &y, &z) {
            return (x, y, z)
        }
        return nil
    }
}

// MARK: - XDE LayerTool Expansion (v0.60.0)

extension AssemblyNode {
    /// Set a named layer on this label.
    public func setLayer(_ name: String) {
        OCCTDocumentSetLayer(document.handle, labelId, name)
    }

    /// Check if a specific layer is set on this label.
    public func isLayerSet(_ name: String) -> Bool {
        OCCTDocumentIsLayerSet(document.handle, labelId, name)
    }

    /// Get layer names assigned to this label.
    public var layers: [String] {
        let maxNames: Int32 = 16
        let maxLen: Int32 = 256
        // Allocate C string buffers
        let buffers = UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>.allocate(capacity: Int(maxNames))
        defer { buffers.deallocate() }
        for i in 0..<Int(maxNames) {
            let buf = UnsafeMutablePointer<CChar>.allocate(capacity: Int(maxLen))
            buf[0] = 0
            buffers[i] = buf
        }
        let count = OCCTDocumentGetLabelLayers(document.handle, labelId, buffers, maxNames, maxLen)
        var result: [String] = []
        for i in 0..<Int(count) {
            if let buf = buffers[i] {
                result.append(String(cString: buf))
            }
        }
        for i in 0..<Int(maxNames) {
            buffers[i]?.deallocate()
        }
        return result
    }
}

extension Document {
    /// Find a layer label by name.
    /// - Returns: Label ID, or -1 if not found
    public func findLayer(_ name: String) -> Int64 {
        OCCTDocumentFindLayer(handle, name)
    }

    /// Set visibility for a layer label.
    public func setLayerVisibility(layerLabelId: Int64, visible: Bool) {
        OCCTDocumentSetLayerVisibility(handle, layerLabelId, visible)
    }

    /// Get visibility for a layer label.
    public func layerVisibility(layerLabelId: Int64) -> Bool {
        OCCTDocumentGetLayerVisibility(handle, layerLabelId)
    }
}

// MARK: - XDE Editor (v0.60.0)

extension Document {
    /// Expand a compound shape label into an assembly using XCAFDoc_Editor.
    /// - Parameters:
    ///   - labelId: Label of the compound to expand
    ///   - recursively: If true, expand recursively
    /// - Returns: true if expanded successfully
    @discardableResult
    public func editorExpand(labelId: Int64, recursively: Bool = true) -> Bool {
        OCCTDocumentEditorExpand(handle, labelId, recursively)
    }

    /// Rescale geometry on a label.
    /// - Parameters:
    ///   - labelId: Label to rescale
    ///   - scaleFactor: Scale factor
    ///   - forceIfNotRoot: Force rescale even if label is not root
    /// - Returns: true on success
    @discardableResult
    public func rescaleGeometry(labelId: Int64, scaleFactor: Double, forceIfNotRoot: Bool = false) -> Bool {
        OCCTDocumentEditorRescaleGeometry(handle, labelId, scaleFactor, forceIfNotRoot)
    }
}

// MARK: - XCAFDoc_Location (v0.83.0)

extension AssemblyNode {
    /// Set a TopLoc_Location (translation) on this label.
    @discardableResult
    public func setLocationTranslation(x: Double, y: Double, z: Double) -> Bool {
        OCCTDocumentSetLocation(document.handle, labelId, x, y, z)
    }

    /// Get the TopLoc_Location translation from this label.
    public var locationTranslation: (x: Double, y: Double, z: Double)? {
        var x: Double = 0, y: Double = 0, z: Double = 0
        guard OCCTDocumentGetLocationTranslation(document.handle, labelId, &x, &y, &z) else { return nil }
        return (x, y, z)
    }

    /// Whether this label has an XCAFDoc_Location attribute.
    public var hasLocationAttribute: Bool {
        OCCTDocumentHasLocation(document.handle, labelId)
    }
}

// MARK: - XCAFDoc_GraphNode (v0.83.0)

extension AssemblyNode {
    /// Set an XCAFDoc_GraphNode attribute on this label.
    @discardableResult
    public func setXCAFGraphNode() -> Bool {
        OCCTDocumentSetGraphNodeAttr(document.handle, labelId)
    }

    /// Set a child relationship: this node's graph node gets the child's graph node.
    @discardableResult
    public func xcafGraphNodeSetChild(_ child: AssemblyNode) -> Bool {
        OCCTDocumentGraphNodeSetChild(document.handle, labelId, child.labelId)
    }

    /// Set a father relationship: this node's graph node gets the parent's graph node as father.
    @discardableResult
    public func xcafGraphNodeSetFather(_ parent: AssemblyNode) -> Bool {
        OCCTDocumentGraphNodeSetFather(document.handle, labelId, parent.labelId)
    }

    /// Unset a child relationship.
    @discardableResult
    public func xcafGraphNodeUnSetChild(_ child: AssemblyNode) -> Bool {
        OCCTDocumentGraphNodeUnSetChild(document.handle, labelId, child.labelId)
    }

    /// Unset a father relationship.
    @discardableResult
    public func xcafGraphNodeUnSetFather(_ parent: AssemblyNode) -> Bool {
        OCCTDocumentGraphNodeUnSetFather(document.handle, labelId, parent.labelId)
    }

    /// Number of children in the XCAFDoc_GraphNode.
    public var xcafGraphNodeChildCount: Int32 {
        OCCTDocumentGraphNodeNbChildren(document.handle, labelId)
    }

    /// Number of fathers in the XCAFDoc_GraphNode.
    public var xcafGraphNodeFatherCount: Int32 {
        OCCTDocumentGraphNodeNbFathers(document.handle, labelId)
    }

    /// Check if this node is a father of another node in the XCAFDoc_GraphNode.
    public func xcafGraphNodeIsFather(of other: AssemblyNode) -> Bool {
        OCCTDocumentGraphNodeIsFather(document.handle, labelId, other.labelId)
    }

    /// Check if this node is a child of another node in the XCAFDoc_GraphNode.
    public func xcafGraphNodeIsChild(of other: AssemblyNode) -> Bool {
        OCCTDocumentGraphNodeIsChild(document.handle, labelId, other.labelId)
    }
}

// MARK: - XCAFDoc_Color (v0.83.0)

extension AssemblyNode {
    /// Set an XCAFDoc_Color attribute from RGB.
    @discardableResult
    public func setColorAttribute(red: Double, green: Double, blue: Double) -> Bool {
        OCCTDocumentSetColorAttr(document.handle, labelId, red, green, blue)
    }

    /// Set an XCAFDoc_Color attribute from RGBA.
    @discardableResult
    public func setColorAttribute(red: Double, green: Double, blue: Double, alpha: Float) -> Bool {
        OCCTDocumentSetColorRGBAAttr(document.handle, labelId, red, green, blue, alpha)
    }

    /// Set an XCAFDoc_Color attribute from a named color.
    @discardableResult
    public func setColorAttribute(namedColor noc: Int32) -> Bool {
        OCCTDocumentSetColorNOCAttr(document.handle, labelId, noc)
    }

    /// Get the RGB color from an XCAFDoc_Color attribute.
    public var colorAttribute: (red: Double, green: Double, blue: Double)? {
        var r: Double = 0, g: Double = 0, b: Double = 0
        guard OCCTDocumentGetColorAttr(document.handle, labelId, &r, &g, &b) else { return nil }
        return (r, g, b)
    }

    /// Get the RGBA color from an XCAFDoc_Color attribute.
    public var colorRGBAAttribute: (red: Double, green: Double, blue: Double, alpha: Float)? {
        var r: Double = 0, g: Double = 0, b: Double = 0
        var a: Float = 1.0
        guard OCCTDocumentGetColorRGBAAttr(document.handle, labelId, &r, &g, &b, &a) else { return nil }
        return (r, g, b, a)
    }

    /// Get the alpha value from an XCAFDoc_Color attribute.
    public var colorAlphaAttribute: Float {
        OCCTDocumentGetColorAlphaAttr(document.handle, labelId)
    }

    /// Get the named color (NOC) from an XCAFDoc_Color attribute, or -1 if not set.
    public var colorNOCAttribute: Int32 {
        OCCTDocumentGetColorNOCAttr(document.handle, labelId)
    }
}

// MARK: - XCAFDoc_Material (v0.83.0)

extension AssemblyNode {
    /// Set an XCAFDoc_Material attribute on this label.
    @discardableResult
    public func setMaterialAttribute(name: String, description: String, density: Double,
                                      densityName: String, densityValueType: String) -> Bool {
        OCCTDocumentSetMaterialAttr(document.handle, labelId, name, description, density, densityName, densityValueType)
    }

    /// Get the material name from an XCAFDoc_Material attribute.
    public var materialAttributeName: String? {
        guard let cStr = OCCTDocumentGetMaterialAttrName(document.handle, labelId) else { return nil }
        let result = String(cString: cStr)
        OCCTStringFree(cStr)
        return result
    }

    /// Get the material description from an XCAFDoc_Material attribute.
    public var materialAttributeDescription: String? {
        guard let cStr = OCCTDocumentGetMaterialAttrDescription(document.handle, labelId) else { return nil }
        let result = String(cString: cStr)
        OCCTStringFree(cStr)
        return result
    }

    /// Get the material density from an XCAFDoc_Material attribute.
    public var materialAttributeDensity: Double? {
        var density: Double = 0
        guard OCCTDocumentGetMaterialAttrDensity(document.handle, labelId, &density) else { return nil }
        return density
    }

    /// Whether this label has an XCAFDoc_Material attribute.
    public var hasMaterialAttribute: Bool {
        OCCTDocumentHasMaterialAttr(document.handle, labelId)
    }
}

// MARK: - XCAFDoc_NoteComment / NoteBalloon / NoteBinData (v0.83.0)

extension AssemblyNode {
    /// Set an XCAFDoc_NoteComment attribute on this label.
    @discardableResult
    public func setNoteComment(userName: String, timeStamp: String, comment: String) -> Bool {
        OCCTDocumentSetNoteComment(document.handle, labelId, userName, timeStamp, comment)
    }

    /// Get the comment text from an XCAFDoc_NoteComment attribute.
    public var noteCommentText: String? {
        guard let cStr = OCCTDocumentGetNoteCommentText(document.handle, labelId) else { return nil }
        let result = String(cString: cStr)
        OCCTStringFree(cStr)
        return result
    }

    /// Get the user name from a note attribute.
    public var noteUserName: String? {
        guard let cStr = OCCTDocumentGetNoteUserName(document.handle, labelId) else { return nil }
        let result = String(cString: cStr)
        OCCTStringFree(cStr)
        return result
    }

    /// Set an XCAFDoc_NoteBalloon attribute on this label.
    @discardableResult
    public func setNoteBalloon(userName: String, timeStamp: String, comment: String) -> Bool {
        OCCTDocumentSetNoteBalloon(document.handle, labelId, userName, timeStamp, comment)
    }

    /// Set an XCAFDoc_NoteBinData attribute on this label.
    @discardableResult
    public func setNoteBinData(userName: String, timeStamp: String, title: String,
                                mimeType: String, data: [UInt8]) -> Bool {
        data.withUnsafeBufferPointer { buf in
            OCCTDocumentSetNoteBinData(document.handle, labelId, userName, timeStamp,
                                       title, mimeType, buf.baseAddress!, Int32(data.count))
        }
    }

    /// Get the size of binary data from an XCAFDoc_NoteBinData attribute.
    public var noteBinDataSize: Int32 {
        OCCTDocumentGetNoteBinDataSize(document.handle, labelId)
    }
}

// MARK: - XCAFDoc_NotesTool (v0.83.0)

extension Document {
    /// Get the number of notes via NotesTool.
    public var notesToolNoteCount: Int32 {
        OCCTDocumentNotesToolNbNotes(handle)
    }

    /// Create a comment note via NotesTool. Returns the note label node.
    public func notesToolCreateComment(userName: String, timeStamp: String, comment: String) -> AssemblyNode? {
        let labelId = OCCTDocumentNotesToolCreateComment(handle, userName, timeStamp, comment)
        guard labelId >= 0 else { return nil }
        return AssemblyNode(document: self, labelId: labelId)
    }

    /// Create a balloon note via NotesTool. Returns the note label node.
    public func notesToolCreateBalloon(userName: String, timeStamp: String, comment: String) -> AssemblyNode? {
        let labelId = OCCTDocumentNotesToolCreateBalloon(handle, userName, timeStamp, comment)
        guard labelId >= 0 else { return nil }
        return AssemblyNode(document: self, labelId: labelId)
    }

    /// Create a binary data note via NotesTool. Returns the note label node.
    public func notesToolCreateBinData(userName: String, timeStamp: String, title: String,
                                        mimeType: String, data: [UInt8]) -> AssemblyNode? {
        let labelId = data.withUnsafeBufferPointer { buf in
            OCCTDocumentNotesToolCreateBinData(handle, userName, timeStamp,
                                                title, mimeType, buf.baseAddress!, Int32(data.count))
        }
        guard labelId >= 0 else { return nil }
        return AssemblyNode(document: self, labelId: labelId)
    }

    /// Delete a note by its label node.
    @discardableResult
    public func notesToolDeleteNote(_ node: AssemblyNode) -> Bool {
        OCCTDocumentNotesToolDeleteNote(handle, node.labelId)
    }

    /// Delete all notes. Returns the number of deleted notes.
    @discardableResult
    public func notesToolDeleteAllNotes() -> Int32 {
        OCCTDocumentNotesToolDeleteAllNotes(handle)
    }

    /// Get the number of orphan notes.
    public var notesToolOrphanNoteCount: Int32 {
        OCCTDocumentNotesToolNbOrphanNotes(handle)
    }

    /// Delete all orphan notes. Returns the number of deleted notes.
    @discardableResult
    public func notesToolDeleteOrphanNotes() -> Int32 {
        OCCTDocumentNotesToolDeleteOrphanNotes(handle)
    }
}

// MARK: - XCAFDoc_ClippingPlaneTool (v0.83.0)

extension Document {
    /// Add a clipping plane. Returns the clipping plane label node.
    public func clippingPlaneToolAdd(originX: Double, originY: Double, originZ: Double,
                                      normalX: Double, normalY: Double, normalZ: Double,
                                      name: String, capping: Bool) -> AssemblyNode? {
        let labelId = OCCTDocumentClipPlaneToolAdd(handle,
                                                     originX, originY, originZ,
                                                     normalX, normalY, normalZ,
                                                     name, capping)
        guard labelId >= 0 else { return nil }
        return AssemblyNode(document: self, labelId: labelId)
    }

    /// Get a clipping plane from a label.
    public func clippingPlaneToolGet(_ node: AssemblyNode) -> (originX: Double, originY: Double, originZ: Double,
                                                                normalX: Double, normalY: Double, normalZ: Double,
                                                                capping: Bool)? {
        var ox: Double = 0, oy: Double = 0, oz: Double = 0
        var nx: Double = 0, ny: Double = 0, nz: Double = 0
        var cap = false
        guard OCCTDocumentClipPlaneToolGet(handle, node.labelId, &ox, &oy, &oz, &nx, &ny, &nz, &cap) else { return nil }
        return (ox, oy, oz, nx, ny, nz, cap)
    }

    /// Check if a label is a clipping plane.
    public func clippingPlaneToolIsClipPlane(_ node: AssemblyNode) -> Bool {
        OCCTDocumentClipPlaneToolIsClipPlane(handle, node.labelId)
    }

    /// Remove a clipping plane.
    @discardableResult
    public func clippingPlaneToolRemove(_ node: AssemblyNode) -> Bool {
        OCCTDocumentClipPlaneToolRemove(handle, node.labelId)
    }
}

// MARK: - XCAFDoc_ShapeMapTool (v0.83.0)

extension AssemblyNode {
    /// Set a ShapeMapTool attribute on this label.
    @discardableResult
    public func setShapeMapTool() -> Bool {
        OCCTDocumentSetShapeMapTool(document.handle, labelId)
    }

    /// Set a shape on the ShapeMapTool.
    @discardableResult
    public func shapeMapToolSetShape(_ shape: Shape) -> Bool {
        OCCTDocumentShapeMapToolSetShape(document.handle, labelId, shape.handle)
    }

    /// Check if a shape is a sub-shape in the ShapeMapTool.
    public func shapeMapToolIsSubShape(_ shape: Shape) -> Bool {
        OCCTDocumentShapeMapToolIsSubShape(document.handle, labelId, shape.handle)
    }

    /// Get the extent (number of entries) of the ShapeMapTool's map.
    public var shapeMapToolExtent: Int32 {
        OCCTDocumentShapeMapToolExtent(document.handle, labelId)
    }
}

// MARK: - XCAFDoc_AssemblyGraph (v0.83.0)

/// Wrapper for XCAFDoc_AssemblyGraph — read-only graph of assembly structure.
public final class AssemblyGraph: @unchecked Sendable {
    private let handle: OCCTAssemblyGraphRef

    /// Create an assembly graph from a document.
    public init?(document: Document) {
        guard let h = OCCTAssemblyGraphCreate(document.handle) else { return nil }
        self.handle = h
    }

    deinit {
        OCCTAssemblyGraphRelease(handle)
    }

    /// Number of nodes in the graph.
    public var nodeCount: Int32 {
        OCCTAssemblyGraphNbNodes(handle)
    }

    /// Number of links in the graph.
    public var linkCount: Int32 {
        OCCTAssemblyGraphNbLinks(handle)
    }

    /// Number of root nodes.
    public var rootCount: Int32 {
        OCCTAssemblyGraphNbRoots(handle)
    }

    /// Assembly graph node type.
    public enum NodeType: Int32 {
        case node = 0
        case occurrence = 1
        case part = 2
        case instance = 3
        case subshape = 4
        case free = 5
    }

    /// Get the type of a node by 1-based index.
    public func nodeType(at index: Int32) -> NodeType? {
        let raw = OCCTAssemblyGraphGetNodeType(handle, index)
        guard raw >= 0 else { return nil }
        return NodeType(rawValue: raw)
    }
}

// MARK: - XCAFDoc_AssemblyItemId (v0.83.0)

/// Value-type wrapper for XCAFDoc_AssemblyItemId (represented as a string path).
public struct AssemblyItemId: Sendable {
    /// The string representation (e.g. "0:1:1:1/0:1:1:2")
    public let path: String

    public init(_ path: String) {
        self.path = path
    }

    /// Whether this item ID is valid (non-null).
    public var isValid: Bool {
        OCCTAssemblyItemIdIsValid(path)
    }

    /// Number of path entries.
    public var pathCount: Int32 {
        OCCTAssemblyItemIdPathCount(path)
    }

    /// Check equality with another item ID.
    public func isEqual(to other: AssemblyItemId) -> Bool {
        OCCTAssemblyItemIdIsEqual(path, other.path)
    }
}

// MARK: - XCAFView_Object (v0.83.0)

/// Wrapper for XCAFView_Object — standalone view definition.
public final class ViewObject: @unchecked Sendable {
    private let handle: OCCTViewObjectRef

    /// Create a new empty view object.
    public init?() {
        guard let h = OCCTViewObjectCreate() else { return nil }
        self.handle = h
    }

    deinit {
        OCCTViewObjectRelease(handle)
    }

    /// Projection type.
    public enum ProjectionType: Int32 {
        case central = 0
        case parallel = 1
    }

    /// Set the projection type.
    public func setType(_ type: ProjectionType) {
        OCCTViewObjectSetType(handle, type.rawValue)
    }

    /// Get the projection type.
    public var type: ProjectionType {
        ProjectionType(rawValue: OCCTViewObjectGetType(handle)) ?? .central
    }

    /// Set the view direction.
    public func setViewDirection(x: Double, y: Double, z: Double) {
        OCCTViewObjectSetViewDirection(handle, x, y, z)
    }

    /// Get the view direction.
    public var viewDirection: (x: Double, y: Double, z: Double) {
        var x: Double = 0, y: Double = 0, z: Double = 0
        OCCTViewObjectGetViewDirection(handle, &x, &y, &z)
        return (x, y, z)
    }

    /// Set the up direction.
    public func setUpDirection(x: Double, y: Double, z: Double) {
        OCCTViewObjectSetUpDirection(handle, x, y, z)
    }

    /// Get the up direction.
    public var upDirection: (x: Double, y: Double, z: Double) {
        var x: Double = 0, y: Double = 0, z: Double = 0
        OCCTViewObjectGetUpDirection(handle, &x, &y, &z)
        return (x, y, z)
    }

    /// Set the window horizontal size.
    public func setWindowHorizontalSize(_ size: Double) {
        OCCTViewObjectSetWindowHSize(handle, size)
    }

    /// Get the window horizontal size.
    public var windowHorizontalSize: Double {
        OCCTViewObjectGetWindowHSize(handle)
    }

    /// Set the window vertical size.
    public func setWindowVerticalSize(_ size: Double) {
        OCCTViewObjectSetWindowVSize(handle, size)
    }

    /// Get the window vertical size.
    public var windowVerticalSize: Double {
        OCCTViewObjectGetWindowVSize(handle)
    }

    /// Set the front plane distance (enables front clipping).
    public func setFrontPlaneDistance(_ dist: Double) {
        OCCTViewObjectSetFrontPlaneDistance(handle, dist)
    }

    /// Get the front plane distance.
    public var frontPlaneDistance: Double {
        OCCTViewObjectGetFrontPlaneDistance(handle)
    }

    /// Whether front plane clipping is enabled.
    public var hasFrontPlaneClipping: Bool {
        OCCTViewObjectHasFrontPlaneClipping(handle)
    }

    /// Unset front plane clipping.
    public func unsetFrontPlaneClipping() {
        OCCTViewObjectUnsetFrontPlaneClipping(handle)
    }

    /// Set the back plane distance (enables back clipping).
    public func setBackPlaneDistance(_ dist: Double) {
        OCCTViewObjectSetBackPlaneDistance(handle, dist)
    }

    /// Get the back plane distance.
    public var backPlaneDistance: Double {
        OCCTViewObjectGetBackPlaneDistance(handle)
    }

    /// Whether back plane clipping is enabled.
    public var hasBackPlaneClipping: Bool {
        OCCTViewObjectHasBackPlaneClipping(handle)
    }

    /// Unset back plane clipping.
    public func unsetBackPlaneClipping() {
        OCCTViewObjectUnsetBackPlaneClipping(handle)
    }

    /// Set the name of this view.
    public func setName(_ name: String) {
        OCCTViewObjectSetName(handle, name)
    }

    /// Get the name of this view.
    public var name: String? {
        guard let cStr = OCCTViewObjectGetName(handle) else { return nil }
        let result = String(cString: cStr)
        OCCTStringFree(cStr)
        return result
    }
}

// MARK: - XCAFNoteObjects_NoteObject (v0.83.0)

/// Wrapper for XCAFNoteObjects_NoteObject — note annotation data.
public final class NoteObject: @unchecked Sendable {
    private let handle: OCCTNoteObjectRef

    /// Create a new empty note object.
    public init?() {
        guard let h = OCCTNoteObjectCreate() else { return nil }
        self.handle = h
    }

    deinit {
        OCCTNoteObjectRelease(handle)
    }

    /// Whether a plane is set.
    public var hasPlane: Bool {
        OCCTNoteObjectHasPlane(handle)
    }

    /// Whether a point is set.
    public var hasPoint: Bool {
        OCCTNoteObjectHasPoint(handle)
    }

    /// Whether a point text is set.
    public var hasPointText: Bool {
        OCCTNoteObjectHasPointText(handle)
    }

    /// Set the plane (origin + normal).
    public func setPlane(originX: Double, originY: Double, originZ: Double,
                          normalX: Double, normalY: Double, normalZ: Double) {
        OCCTNoteObjectSetPlane(handle, originX, originY, originZ, normalX, normalY, normalZ)
    }

    /// Get the plane origin.
    public var planeOrigin: (x: Double, y: Double, z: Double) {
        var x: Double = 0, y: Double = 0, z: Double = 0
        OCCTNoteObjectGetPlane(handle, &x, &y, &z)
        return (x, y, z)
    }

    /// Set a point.
    public func setPoint(x: Double, y: Double, z: Double) {
        OCCTNoteObjectSetPoint(handle, x, y, z)
    }

    /// Get the point.
    public var point: (x: Double, y: Double, z: Double) {
        var x: Double = 0, y: Double = 0, z: Double = 0
        OCCTNoteObjectGetPoint(handle, &x, &y, &z)
        return (x, y, z)
    }

    /// Set a presentation shape.
    public func setPresentation(_ shape: Shape) {
        OCCTNoteObjectSetPresentation(handle, shape.handle)
    }

    /// Get the presentation shape.
    public var presentation: Shape? {
        guard let ref = OCCTNoteObjectGetPresentation(handle) else { return nil }
        return Shape(handle: ref)
    }

    /// Reset all data.
    public func reset() {
        OCCTNoteObjectReset(handle)
    }
}

// MARK: - XCAFPrs_Style (v0.83.0)

/// Value-type wrapper for XCAFPrs_Style — visual presentation style.
public struct PresentationStyle: Sendable {
    /// Surface color (RGB).
    public var surfaceColor: (red: Double, green: Double, blue: Double)?
    /// Surface alpha.
    public var surfaceAlpha: Float
    /// Curve color (RGB).
    public var curveColor: (red: Double, green: Double, blue: Double)?
    /// Whether the style is visible.
    public var isVisible: Bool

    /// Create an empty style.
    public init() {
        self.surfaceColor = nil
        self.surfaceAlpha = 1.0
        self.curveColor = nil
        self.isVisible = true
    }

    /// Create a style with a surface color.
    public init(surfaceRed: Double, surfaceGreen: Double, surfaceBlue: Double, surfaceAlpha: Float = 1.0) {
        self.surfaceColor = (surfaceRed, surfaceGreen, surfaceBlue)
        self.surfaceAlpha = surfaceAlpha
        self.curveColor = nil
        self.isVisible = true
    }

    /// Whether the style is empty (no colors set, visible).
    public var isEmpty: Bool {
        let s = toOCCT()
        return s.isEmpty
    }

    /// Check equality with another style.
    public func isEqual(to other: PresentationStyle) -> Bool {
        var s1 = toOCCT()
        var s2 = other.toOCCT()
        return OCCTXCAFPrsStyleIsEqual(&s1, &s2)
    }

    private func toOCCT() -> OCCTXCAFPrsStyle {
        if let sc = surfaceColor, let cc = curveColor {
            return OCCTXCAFPrsStyleCreateFull(sc.red, sc.green, sc.blue, surfaceAlpha,
                                               cc.red, cc.green, cc.blue, isVisible)
        } else if let sc = surfaceColor {
            var s = OCCTXCAFPrsStyleCreateWithSurfColor(sc.red, sc.green, sc.blue, surfaceAlpha)
            s.isVisible = isVisible
            return s
        } else {
            var s = OCCTXCAFPrsStyleCreate()
            s.isVisible = isVisible
            return s
        }
    }
}

// MARK: - XCAFDoc_VisMaterialCommon (v0.83.0)

/// Phong material properties (diffuse, ambient, specular, emissive, shininess, transparency).
public struct VisMaterialCommon: Sendable {
    public var diffuseColor: (red: Double, green: Double, blue: Double)
    public var ambientColor: (red: Double, green: Double, blue: Double)
    public var specularColor: (red: Double, green: Double, blue: Double)
    public var emissiveColor: (red: Double, green: Double, blue: Double)
    public var shininess: Float
    public var transparency: Float
    public var isDefined: Bool

    /// Create with default values (from OCCT defaults).
    public init() {
        let d = OCCTVisMaterialCommonDefault()
        self.diffuseColor = (d.diffuseR, d.diffuseG, d.diffuseB)
        self.ambientColor = (d.ambientR, d.ambientG, d.ambientB)
        self.specularColor = (d.specularR, d.specularG, d.specularB)
        self.emissiveColor = (d.emissiveR, d.emissiveG, d.emissiveB)
        self.shininess = d.shininess
        self.transparency = d.transparency
        self.isDefined = d.isDefined
    }

    /// Check equality with another VisMaterialCommon.
    public func isEqual(to other: VisMaterialCommon) -> Bool {
        var a = toOCCT()
        var b = other.toOCCT()
        return OCCTVisMaterialCommonIsEqual(&a, &b)
    }

    private func toOCCT() -> OCCTVisMaterialCommon {
        var m = OCCTVisMaterialCommon()
        m.diffuseR = diffuseColor.red; m.diffuseG = diffuseColor.green; m.diffuseB = diffuseColor.blue
        m.ambientR = ambientColor.red; m.ambientG = ambientColor.green; m.ambientB = ambientColor.blue
        m.specularR = specularColor.red; m.specularG = specularColor.green; m.specularB = specularColor.blue
        m.emissiveR = emissiveColor.red; m.emissiveG = emissiveColor.green; m.emissiveB = emissiveColor.blue
        m.shininess = shininess
        m.transparency = transparency
        m.isDefined = isDefined
        return m
    }
}

// MARK: - XCAFDoc_VisMaterialPBR (v0.83.0)

/// PBR material properties (base color, metallic, roughness, IOR, emission).
public struct VisMaterialPBR: Sendable {
    public var baseColor: (red: Double, green: Double, blue: Double)
    public var baseColorAlpha: Float
    public var metallic: Float
    public var roughness: Float
    public var refractionIndex: Float
    public var emissionColor: (red: Double, green: Double, blue: Double)
    public var isDefined: Bool

    /// Create with default values (from OCCT defaults).
    public init() {
        let d = OCCTVisMaterialPBRDefault()
        self.baseColor = (d.baseColorR, d.baseColorG, d.baseColorB)
        self.baseColorAlpha = d.baseColorAlpha
        self.metallic = d.metallic
        self.roughness = d.roughness
        self.refractionIndex = d.refractionIndex
        self.emissionColor = (d.emissionR, d.emissionG, d.emissionB)
        self.isDefined = d.isDefined
    }

    /// Check equality with another VisMaterialPBR.
    public func isEqual(to other: VisMaterialPBR) -> Bool {
        var a = toOCCT()
        var b = other.toOCCT()
        return OCCTVisMaterialPBRIsEqual(&a, &b)
    }

    private func toOCCT() -> OCCTVisMaterialPBR {
        var m = OCCTVisMaterialPBR()
        m.baseColorR = baseColor.red; m.baseColorG = baseColor.green; m.baseColorB = baseColor.blue
        m.baseColorAlpha = baseColorAlpha
        m.metallic = metallic
        m.roughness = roughness
        m.refractionIndex = refractionIndex
        m.emissionR = emissionColor.red; m.emissionG = emissionColor.green; m.emissionB = emissionColor.blue
        m.isDefined = isDefined
        return m
    }
}

// =============================================================================
// MARK: - v0.84.0: VrmlAPI, Directory, Variable, Expression, XLink, DimTol, DriverTable, TObj
// =============================================================================

// MARK: - VrmlAPI_Writer

/// VRML representation mode for export.
public enum VrmlRepresentation: Int32, Sendable {
    case shaded = 0
    case wireFrame = 1
    case both = 2
}

extension Shape {
    /// Write shape to VRML file.
    /// - Parameters:
    ///   - url: File URL to write to (.wrl extension)
    ///   - version: VRML version (1 or 2, default 2)
    ///   - deflection: Mesh deflection for triangulation (default 0.01)
    ///   - representation: Visual representation mode (default .shaded)
    /// - Returns: true if successful
    @discardableResult
    public func writeVRML(to url: URL,
                          version: Int = 2,
                          deflection: Double = 0.01,
                          representation: VrmlRepresentation = .shaded) -> Bool {
        OCCTVrmlWriteShape(handle, url.path, Int32(version), deflection, representation.rawValue)
    }
}

extension Document {
    /// Write XDE document to VRML file with scale.
    /// - Parameters:
    ///   - url: File URL to write to (.wrl extension)
    ///   - scale: Scale factor (default 1.0)
    /// - Returns: true if successful
    @discardableResult
    public func writeVRML(to url: URL, scale: Double = 1.0) -> Bool {
        OCCTVrmlWriteDocument(handle, url.path, scale)
    }
}

// MARK: - TDataStd_Directory

extension Document {
    /// Create a new directory attribute on a label.
    /// - Parameter labelTag: Label child tag (0 = main label)
    @discardableResult
    public func createDirectory(at labelTag: Int = 0) -> Bool {
        OCCTDocumentDirectoryNew(handle, Int32(labelTag))
    }

    /// Check if a directory attribute exists on a label.
    public func hasDirectory(at labelTag: Int = 0) -> Bool {
        OCCTDocumentDirectoryFind(handle, Int32(labelTag))
    }

    /// Add a sub-directory under an existing directory.
    /// - Returns: Child label tag, or nil if failed
    public func addSubDirectory(under parentLabelTag: Int = 0) -> Int? {
        let tag = OCCTDocumentDirectoryAddSubDirectory(handle, Int32(parentLabelTag))
        return tag >= 0 ? Int(tag) : nil
    }

    /// Make an object label under a directory.
    /// - Returns: Child label tag, or nil if failed
    public func makeObjectLabel(under parentLabelTag: Int = 0) -> Int? {
        let tag = OCCTDocumentDirectoryMakeObjectLabel(handle, Int32(parentLabelTag))
        return tag >= 0 ? Int(tag) : nil
    }
}

// MARK: - TDataStd_Variable

extension Document {
    /// Set a variable attribute on a label.
    @discardableResult
    public func setVariable(at labelTag: Int) -> Bool {
        OCCTDocumentVariableSet(handle, Int32(labelTag))
    }

    /// Set variable name.
    @discardableResult
    public func setVariableName(_ name: String, at labelTag: Int) -> Bool {
        OCCTDocumentVariableSetName(handle, Int32(labelTag), name)
    }

    /// Get variable name.
    public func variableName(at labelTag: Int) -> String? {
        guard let cStr = OCCTDocumentVariableGetName(handle, Int32(labelTag)) else { return nil }
        let result = String(cString: cStr)
        OCCTGeomToolsFreeString(UnsafeMutablePointer(mutating: cStr))
        return result
    }

    /// Set variable value.
    @discardableResult
    public func setVariableValue(_ value: Double, at labelTag: Int) -> Bool {
        OCCTDocumentVariableSetValue(handle, Int32(labelTag), value)
    }

    /// Get variable value.
    public func variableValue(at labelTag: Int) -> Double {
        OCCTDocumentVariableGetValue(handle, Int32(labelTag))
    }

    /// Check if variable has a value.
    public func variableIsValued(at labelTag: Int) -> Bool {
        OCCTDocumentVariableIsValued(handle, Int32(labelTag))
    }

    /// Set variable unit string.
    @discardableResult
    public func setVariableUnit(_ unit: String, at labelTag: Int) -> Bool {
        OCCTDocumentVariableSetUnit(handle, Int32(labelTag), unit)
    }

    /// Get variable unit string.
    public func variableUnit(at labelTag: Int) -> String? {
        guard let cStr = OCCTDocumentVariableGetUnit(handle, Int32(labelTag)) else { return nil }
        let result = String(cString: cStr)
        OCCTGeomToolsFreeString(UnsafeMutablePointer(mutating: cStr))
        return result
    }

    /// Set variable constant flag.
    @discardableResult
    public func setVariableConstant(_ isConstant: Bool, at labelTag: Int) -> Bool {
        OCCTDocumentVariableSetConstant(handle, Int32(labelTag), isConstant)
    }

    /// Check if variable is constant.
    public func variableIsConstant(at labelTag: Int) -> Bool {
        OCCTDocumentVariableIsConstant(handle, Int32(labelTag))
    }

    /// Assign expression to variable on same label.
    @discardableResult
    public func assignExpression(at labelTag: Int) -> Bool {
        OCCTDocumentVariableAssignExpression(handle, Int32(labelTag))
    }

    /// Remove expression from variable.
    @discardableResult
    public func desassignExpression(at labelTag: Int) -> Bool {
        OCCTDocumentVariableDesassignExpression(handle, Int32(labelTag))
    }

    /// Check if variable has an assigned expression.
    public func variableIsAssigned(at labelTag: Int) -> Bool {
        OCCTDocumentVariableIsAssigned(handle, Int32(labelTag))
    }
}

// MARK: - TDataStd_Expression

extension Document {
    /// Set an expression attribute on a label.
    @discardableResult
    public func setExpression(at labelTag: Int) -> Bool {
        OCCTDocumentExpressionSet(handle, Int32(labelTag))
    }

    /// Set expression string.
    @discardableResult
    public func setExpressionString(_ expression: String, at labelTag: Int) -> Bool {
        OCCTDocumentExpressionSetString(handle, Int32(labelTag), expression)
    }

    /// Get expression string.
    public func expressionString(at labelTag: Int) -> String? {
        guard let cStr = OCCTDocumentExpressionGetString(handle, Int32(labelTag)) else { return nil }
        let result = String(cString: cStr)
        OCCTGeomToolsFreeString(UnsafeMutablePointer(mutating: cStr))
        return result
    }

    /// Get expression name.
    public func expressionName(at labelTag: Int) -> String? {
        guard let cStr = OCCTDocumentExpressionGetName(handle, Int32(labelTag)) else { return nil }
        let result = String(cString: cStr)
        OCCTGeomToolsFreeString(UnsafeMutablePointer(mutating: cStr))
        return result
    }
}

// MARK: - TDocStd_XLink

extension Document {
    /// Set an external link attribute on a label.
    @discardableResult
    public func setXLink(at labelTag: Int) -> Bool {
        OCCTDocumentXLinkSet(handle, Int32(labelTag))
    }

    /// Set XLink document entry path.
    @discardableResult
    public func setXLinkDocumentEntry(_ entry: String, at labelTag: Int) -> Bool {
        OCCTDocumentXLinkSetDocumentEntry(handle, Int32(labelTag), entry)
    }

    /// Get XLink document entry path.
    public func xLinkDocumentEntry(at labelTag: Int) -> String? {
        guard let cStr = OCCTDocumentXLinkGetDocumentEntry(handle, Int32(labelTag)) else { return nil }
        let result = String(cString: cStr)
        OCCTGeomToolsFreeString(UnsafeMutablePointer(mutating: cStr))
        return result
    }

    /// Set XLink label entry string.
    @discardableResult
    public func setXLinkLabelEntry(_ entry: String, at labelTag: Int) -> Bool {
        OCCTDocumentXLinkSetLabelEntry(handle, Int32(labelTag), entry)
    }

    /// Get XLink label entry string.
    public func xLinkLabelEntry(at labelTag: Int) -> String? {
        guard let cStr = OCCTDocumentXLinkGetLabelEntry(handle, Int32(labelTag)) else { return nil }
        let result = String(cString: cStr)
        OCCTGeomToolsFreeString(UnsafeMutablePointer(mutating: cStr))
        return result
    }
}

// MARK: - XCAFDimTolObjects_Tool

extension Document {
    /// Count of dimension objects via XCAFDimTolObjects_Tool.
    public var dimTolToolDimensionCount: Int {
        Int(OCCTDocumentDimTolDimensionCount(handle))
    }

    /// Count of geometric tolerance objects via XCAFDimTolObjects_Tool.
    public var dimTolToolToleranceCount: Int {
        Int(OCCTDocumentDimTolToleranceCount(handle))
    }
}

// MARK: - TPrsStd_DriverTable

/// Presentation driver table (global singleton for OCAF presentation drivers).
public enum DriverTable: Sendable {
    /// Initialize the global driver table with standard drivers.
    public static func initStandard() {
        OCCTDriverTableInitStandard()
    }

    /// Check if the global driver table exists.
    public static var exists: Bool {
        OCCTDriverTableExists()
    }

    /// Clear all drivers from the global table.
    public static func clear() {
        OCCTDriverTableClear()
    }
}

// MARK: - TObj_Application

/// TObj application singleton for OCAF-based document management.
public final class TObjApplication: @unchecked Sendable {
    private let ref: OCCTTObjAppRef

    private init(ref: OCCTTObjAppRef) {
        self.ref = ref
    }

    /// Get the singleton TObj_Application instance.
    public static var shared: TObjApplication? {
        guard let ref = OCCTTObjApplicationGetInstance() else { return nil }
        return TObjApplication(ref: ref)
    }

    /// Whether verbose logging is enabled.
    public var isVerbose: Bool {
        get { OCCTTObjApplicationIsVerbose(ref) }
        set { OCCTTObjApplicationSetVerbose(ref, newValue) }
    }

    /// Create a new document via TObj_Application.
    public func createDocument() -> Document? {
        guard let docRef = OCCTTObjApplicationCreateDocument(ref) else { return nil }
        return Document(handle: docRef)
    }
}

// =============================================================================
// MARK: - v0.85.0: UnitsAPI, BinTools, Message, CoordSystem, IDFilter
// =============================================================================

// MARK: - UnitsAPI

/// Unit conversion utilities wrapping OCCT UnitsAPI.
public enum Units: Sendable {
    /// Convert a value between any two units (e.g., "mm" to "m", "deg" to "rad").
    public static func convert(_ value: Double, from fromUnit: String, to toUnit: String) -> Double {
        OCCTUnitsAnyToAny(value, fromUnit, toUnit)
    }

    /// Convert a value from any unit to SI base unit.
    public static func toSI(_ value: Double, from unit: String) -> Double {
        OCCTUnitsAnyToSI(value, unit)
    }

    /// Convert a value from SI base unit to any unit.
    public static func fromSI(_ value: Double, to unit: String) -> Double {
        OCCTUnitsAnyFromSI(value, unit)
    }

    /// Convert a value from any unit to local system.
    public static func toLocalSystem(_ value: Double, from unit: String) -> Double {
        OCCTUnitsAnyToLS(value, unit)
    }

    /// Convert a value from local system to any unit.
    public static func fromLocalSystem(_ value: Double, to unit: String) -> Double {
        OCCTUnitsAnyFromLS(value, unit)
    }

    /// Unit system type.
    public enum SystemType: Int32, Sendable {
        case defaultSystem = 0
        case si = 1
        case mdtv = 2
    }

    /// Set the local unit system.
    public static func setLocalSystem(_ system: SystemType) {
        OCCTUnitsSetLocalSystem(system.rawValue)
    }

    /// Get the current local unit system.
    public static var localSystem: SystemType {
        SystemType(rawValue: OCCTUnitsGetLocalSystem()) ?? .defaultSystem
    }
}

// MARK: - BinTools Shape I/O

extension Shape {
    /// Write shape to binary data.
    public func toBinaryData() -> Data? {
        var length: Int32 = 0
        guard let ptr = OCCTBinToolsWriteShape(handle, &length) else { return nil }
        let data = Data(bytes: ptr, count: Int(length))
        free(UnsafeMutableRawPointer(mutating: ptr))
        return data
    }

    /// Read shape from binary data.
    public static func fromBinaryData(_ data: Data) -> Shape? {
        data.withUnsafeBytes { rawBuffer in
            guard let ptr = rawBuffer.baseAddress else { return nil }
            guard let ref = OCCTBinToolsReadShape(ptr, Int32(data.count)) else { return nil }
            return Shape(handle: ref)
        }
    }

    /// Write shape to binary file.
    @discardableResult
    public func writeBinary(to url: URL) -> Bool {
        OCCTBinToolsWriteShapeToFile(handle, url.path)
    }

    /// Read shape from binary file.
    public static func loadBinary(from url: URL) -> Shape? {
        guard let ref = OCCTBinToolsReadShapeFromFile(url.path) else { return nil }
        return Shape(handle: ref)
    }
}

// MARK: - Message_Messenger

/// OCCT messaging system for dispatching messages to printers.
public final class Messenger: @unchecked Sendable {
    internal let ref: OCCTMessengerRef

    /// Message gravity/severity level.
    public enum Gravity: Int32, Sendable {
        case trace = 0
        case info = 1
        case warning = 2
        case alarm = 3
        case fail = 4
    }

    private init(ref: OCCTMessengerRef) {
        self.ref = ref
    }

    deinit {
        OCCTMessengerRelease(ref)
    }

    /// Create a new messenger with default stdout printer.
    public init?() {
        guard let ref = OCCTMessengerCreate() else { return nil }
        self.ref = ref
    }

    /// Number of attached printers.
    public var printerCount: Int {
        Int(OCCTMessengerPrinterCount(ref))
    }

    /// Send a message with given gravity.
    public func send(_ message: String, gravity: Gravity = .info) {
        OCCTMessengerSend(ref, message, gravity.rawValue)
    }

    /// Add a file printer.
    @discardableResult
    public func addFilePrinter(path: String, gravity: Gravity = .info) -> Bool {
        OCCTMessengerAddFilePrinter(ref, path, gravity.rawValue)
    }

    /// Remove all printers.
    public func removeAllPrinters() {
        OCCTMessengerRemoveAllPrinters(ref)
    }
}

// MARK: - Message_Report

/// Collection of alerts/messages for status reporting.
public final class Report: @unchecked Sendable {
    internal let ref: OCCTReportRef

    private init(ref: OCCTReportRef) {
        self.ref = ref
    }

    deinit {
        OCCTReportRelease(ref)
    }

    /// Create a new empty report.
    public init?() {
        guard let ref = OCCTReportCreate() else { return nil }
        self.ref = ref
    }

    /// Maximum number of alerts to collect.
    public var limit: Int {
        get { Int(OCCTReportGetLimit(ref)) }
        set { OCCTReportSetLimit(ref, Int32(newValue)) }
    }

    /// Clear all alerts.
    public func clear() {
        OCCTReportClear(ref)
    }

    /// Clear alerts of a specific gravity.
    public func clear(gravity: Messenger.Gravity) {
        OCCTReportClearByGravity(ref, gravity.rawValue)
    }

    /// Dump report contents to string.
    public func dump() -> String {
        guard let cStr = OCCTReportDump(ref) else { return "" }
        let result = String(cString: cStr)
        OCCTGeomToolsFreeString(UnsafeMutablePointer(mutating: cStr))
        return result
    }

    /// Dump report contents filtered by gravity.
    public func dump(gravity: Messenger.Gravity) -> String {
        guard let cStr = OCCTReportDumpByGravity(ref, gravity.rawValue) else { return "" }
        let result = String(cString: cStr)
        OCCTGeomToolsFreeString(UnsafeMutablePointer(mutating: cStr))
        return result
    }
}

// MARK: - RWMesh_CoordinateSystemConverter

/// Coordinate system for mesh I/O.
public enum CoordinateSystem: Int32, Sendable {
    case zUp = 0
    case yUp = 1
}

/// Convert a 3D point between coordinate systems with unit scaling.
public func convertCoordinateSystem(x: Double, y: Double, z: Double,
                                     from inputSystem: CoordinateSystem,
                                     inputUnit: Double,
                                     to outputSystem: CoordinateSystem,
                                     outputUnit: Double) -> SIMD3<Double> {
    let r = OCCTCoordSystemConvert(x, y, z, inputSystem.rawValue, inputUnit,
                                    outputSystem.rawValue, outputUnit)
    return SIMD3(r.x, r.y, r.z)
}

/// Get the up direction for a coordinate system.
public func coordinateSystemUpDirection(_ system: CoordinateSystem) -> SIMD3<Double> {
    let r = OCCTCoordSystemUpDirection(system.rawValue)
    return SIMD3(r.x, r.y, r.z)
}

// MARK: - TDF_IDFilter

/// Attribute ID filter for OCAF document operations.
public final class IDFilter: @unchecked Sendable {
    internal let ref: OCCTIDFilterRef

    /// Create an ID filter.
    /// - Parameter ignoreAll: If true, all IDs are ignored except those explicitly kept.
    ///   If false, all IDs are kept except those explicitly ignored.
    public init?(ignoreAll: Bool = true) {
        guard let ref = OCCTIDFilterCreate(ignoreAll) else { return nil }
        self.ref = ref
    }

    deinit {
        OCCTIDFilterRelease(ref)
    }

    /// Whether the filter is in ignore-all mode.
    public var isIgnoreAll: Bool {
        get { OCCTIDFilterIgnoreAll(ref) }
        set { OCCTIDFilterSetIgnoreAll(ref, newValue) }
    }

    /// Mark a GUID as kept (relevant in ignore-all mode).
    public func keep(_ guidString: String) {
        OCCTIDFilterKeep(ref, guidString)
    }

    /// Mark a GUID as ignored (relevant in keep-all mode).
    public func ignore(_ guidString: String) {
        OCCTIDFilterIgnore(ref, guidString)
    }

    /// Check if a GUID is kept by the filter.
    public func isKept(_ guidString: String) -> Bool {
        OCCTIDFilterIsKept(ref, guidString)
    }

    /// Check if a GUID is ignored by the filter.
    public func isIgnored(_ guidString: String) -> Bool {
        OCCTIDFilterIsIgnored(ref, guidString)
    }
}

// MARK: - TDataStd_BooleanArray

public extension Document {
    /// Set a boolean array attribute on a label.
    func setBooleanArray(tag: Int, values: [Bool]) -> Bool {
        let cValues = values.map { $0 }
        return cValues.withUnsafeBufferPointer { buf in
            OCCTDocumentSetBooleanArray(handle, Int32(tag), 1, Int32(values.count),
                                         buf.baseAddress!, Int32(values.count))
        }
    }

    /// Get a boolean array attribute from a label.
    func booleanArray(tag: Int) -> [Bool]? {
        let count = OCCTDocumentGetBooleanArray(handle, Int32(tag), nil, 0)
        if count < 0 { return nil }
        if count == 0 { return [] }
        var values = [Bool](repeating: false, count: Int(count))
        _ = values.withUnsafeMutableBufferPointer { buf in
            OCCTDocumentGetBooleanArray(handle, Int32(tag), buf.baseAddress!, count)
        }
        return values
    }

    /// Check if a label has a boolean array attribute.
    func hasBooleanArray(tag: Int) -> Bool {
        OCCTDocumentHasBooleanArray(handle, Int32(tag))
    }
}

// MARK: - TDataStd_BooleanList

public extension Document {
    /// Set a boolean list attribute on a label.
    func setBooleanList(tag: Int, values: [Bool]) -> Bool {
        values.withUnsafeBufferPointer { buf in
            OCCTDocumentSetBooleanList(handle, Int32(tag), buf.baseAddress!, Int32(values.count))
        }
    }

    /// Get a boolean list attribute from a label.
    func booleanList(tag: Int) -> [Bool]? {
        let count = OCCTDocumentGetBooleanList(handle, Int32(tag), nil, 0)
        if count < 0 { return nil }
        if count == 0 { return [] }
        var values = [Bool](repeating: false, count: Int(count))
        _ = values.withUnsafeMutableBufferPointer { buf in
            OCCTDocumentGetBooleanList(handle, Int32(tag), buf.baseAddress!, count)
        }
        return values
    }

    /// Append a value to a boolean list attribute.
    func booleanListAppend(tag: Int, value: Bool) -> Bool {
        OCCTDocumentBooleanListAppend(handle, Int32(tag), value)
    }

    /// Clear a boolean list attribute.
    func booleanListClear(tag: Int) -> Bool {
        OCCTDocumentBooleanListClear(handle, Int32(tag))
    }

    /// Check if a label has a boolean list attribute.
    func hasBooleanList(tag: Int) -> Bool {
        OCCTDocumentHasBooleanList(handle, Int32(tag))
    }
}

// MARK: - TDataStd_ByteArray

public extension Document {
    /// Set a byte array attribute on a label.
    func setByteArray(tag: Int, values: [UInt8]) -> Bool {
        values.withUnsafeBufferPointer { buf in
            OCCTDocumentSetByteArray(handle, Int32(tag), 0, Int32(values.count - 1),
                                      buf.baseAddress!, Int32(values.count))
        }
    }

    /// Get a byte array attribute from a label.
    func byteArray(tag: Int) -> [UInt8]? {
        let count = OCCTDocumentGetByteArray(handle, Int32(tag), nil, 0)
        if count < 0 { return nil }
        if count == 0 { return [] }
        var values = [UInt8](repeating: 0, count: Int(count))
        _ = values.withUnsafeMutableBufferPointer { buf in
            OCCTDocumentGetByteArray(handle, Int32(tag), buf.baseAddress!, count)
        }
        return values
    }

    /// Check if a label has a byte array attribute.
    func hasByteArray(tag: Int) -> Bool {
        OCCTDocumentHasByteArray(handle, Int32(tag))
    }
}

// MARK: - TDataStd_IntegerList

public extension Document {
    /// Set an integer list attribute on a label.
    func setIntegerList(tag: Int, values: [Int32]) -> Bool {
        values.withUnsafeBufferPointer { buf in
            OCCTDocumentSetIntegerList(handle, Int32(tag), buf.baseAddress!, Int32(values.count))
        }
    }

    /// Get an integer list attribute from a label.
    func integerList(tag: Int) -> [Int32]? {
        let count = OCCTDocumentGetIntegerList(handle, Int32(tag), nil, 0)
        if count < 0 { return nil }
        if count == 0 { return [] }
        var values = [Int32](repeating: 0, count: Int(count))
        _ = values.withUnsafeMutableBufferPointer { buf in
            OCCTDocumentGetIntegerList(handle, Int32(tag), buf.baseAddress!, count)
        }
        return values
    }

    /// Append a value to an integer list attribute.
    func integerListAppend(tag: Int, value: Int32) -> Bool {
        OCCTDocumentIntegerListAppend(handle, Int32(tag), value)
    }

    /// Clear an integer list attribute.
    func integerListClear(tag: Int) -> Bool {
        OCCTDocumentIntegerListClear(handle, Int32(tag))
    }

    /// Check if a label has an integer list attribute.
    func hasIntegerList(tag: Int) -> Bool {
        OCCTDocumentHasIntegerList(handle, Int32(tag))
    }
}

// MARK: - TDataStd_RealList

public extension Document {
    /// Set a real list attribute on a label.
    func setRealList(tag: Int, values: [Double]) -> Bool {
        values.withUnsafeBufferPointer { buf in
            OCCTDocumentSetRealList(handle, Int32(tag), buf.baseAddress!, Int32(values.count))
        }
    }

    /// Get a real list attribute from a label.
    func realList(tag: Int) -> [Double]? {
        let count = OCCTDocumentGetRealList(handle, Int32(tag), nil, 0)
        if count < 0 { return nil }
        if count == 0 { return [] }
        var values = [Double](repeating: 0, count: Int(count))
        _ = values.withUnsafeMutableBufferPointer { buf in
            OCCTDocumentGetRealList(handle, Int32(tag), buf.baseAddress!, count)
        }
        return values
    }

    /// Append a value to a real list attribute.
    func realListAppend(tag: Int, value: Double) -> Bool {
        OCCTDocumentRealListAppend(handle, Int32(tag), value)
    }

    /// Clear a real list attribute.
    func realListClear(tag: Int) -> Bool {
        OCCTDocumentRealListClear(handle, Int32(tag))
    }

    /// Check if a label has a real list attribute.
    func hasRealList(tag: Int) -> Bool {
        OCCTDocumentHasRealList(handle, Int32(tag))
    }
}

// MARK: - TDataStd_ExtStringArray

public extension Document {
    /// Set an extended string array attribute on a label.
    func setExtStringArray(tag: Int, values: [String]) -> Bool {
        var result = false
        let count = values.count
        let cStrings: [UnsafePointer<CChar>] = values.map { str in
            (str as NSString).utf8String!
        }
        cStrings.withUnsafeBufferPointer { buf in
            result = OCCTDocumentSetExtStringArray(handle, Int32(tag), 1, Int32(count),
                                                    buf.baseAddress!, Int32(count))
        }
        return result
    }

    /// Get an extended string array element by index (1-based).
    func extStringArrayValue(tag: Int, index: Int) -> String? {
        guard let cStr = OCCTDocumentGetExtStringArrayValue(handle, Int32(tag), Int32(index)) else { return nil }
        defer { free(cStr) }
        return String(cString: cStr)
    }

    /// Get the length of an extended string array.
    func extStringArrayLength(tag: Int) -> Int? {
        let len = OCCTDocumentGetExtStringArrayLength(handle, Int32(tag))
        return len >= 0 ? Int(len) : nil
    }

    /// Check if a label has an extended string array attribute.
    func hasExtStringArray(tag: Int) -> Bool {
        OCCTDocumentHasExtStringArray(handle, Int32(tag))
    }
}

// MARK: - TDataStd_ExtStringList

public extension Document {
    /// Set an extended string list attribute on a label.
    func setExtStringList(tag: Int, values: [String]) -> Bool {
        var result = false
        let count = values.count
        let cStrings: [UnsafePointer<CChar>] = values.map { str in
            (str as NSString).utf8String!
        }
        cStrings.withUnsafeBufferPointer { buf in
            result = OCCTDocumentSetExtStringList(handle, Int32(tag),
                                                   buf.baseAddress!, Int32(count))
        }
        return result
    }

    /// Get the count of an extended string list.
    func extStringListCount(tag: Int) -> Int? {
        let count = OCCTDocumentGetExtStringListCount(handle, Int32(tag))
        return count >= 0 ? Int(count) : nil
    }

    /// Get an extended string list element by index (0-based).
    func extStringListValue(tag: Int, index: Int) -> String? {
        guard let cStr = OCCTDocumentGetExtStringListValue(handle, Int32(tag), Int32(index)) else { return nil }
        defer { free(cStr) }
        return String(cString: cStr)
    }

    /// Append a string to an extended string list attribute.
    func extStringListAppend(tag: Int, value: String) -> Bool {
        OCCTDocumentExtStringListAppend(handle, Int32(tag), value)
    }

    /// Clear an extended string list attribute.
    func extStringListClear(tag: Int) -> Bool {
        OCCTDocumentExtStringListClear(handle, Int32(tag))
    }

    /// Check if a label has an extended string list attribute.
    func hasExtStringList(tag: Int) -> Bool {
        OCCTDocumentHasExtStringList(handle, Int32(tag))
    }
}

// MARK: - TDataStd_ReferenceArray

public extension Document {
    /// Set a reference array attribute on a label (array of label tags).
    func setReferenceArray(tag: Int, refTags: [Int32]) -> Bool {
        refTags.withUnsafeBufferPointer { buf in
            OCCTDocumentSetReferenceArray(handle, Int32(tag), 1, Int32(refTags.count),
                                           buf.baseAddress!, Int32(refTags.count))
        }
    }

    /// Get a reference array from a label (array of label tags).
    func referenceArray(tag: Int) -> [Int32]? {
        let count = OCCTDocumentGetReferenceArray(handle, Int32(tag), nil, 0)
        if count < 0 { return nil }
        if count == 0 { return [] }
        var tags = [Int32](repeating: 0, count: Int(count))
        _ = tags.withUnsafeMutableBufferPointer { buf in
            OCCTDocumentGetReferenceArray(handle, Int32(tag), buf.baseAddress!, count)
        }
        return tags
    }

    /// Check if a label has a reference array attribute.
    func hasReferenceArray(tag: Int) -> Bool {
        OCCTDocumentHasReferenceArray(handle, Int32(tag))
    }
}

// MARK: - TDataStd_ReferenceList

public extension Document {
    /// Set a reference list attribute on a label (list of label tags).
    func setReferenceList(tag: Int, refTags: [Int32]) -> Bool {
        refTags.withUnsafeBufferPointer { buf in
            OCCTDocumentSetReferenceList(handle, Int32(tag),
                                          buf.baseAddress!, Int32(refTags.count))
        }
    }

    /// Get a reference list from a label (list of label tags).
    func referenceList(tag: Int) -> [Int32]? {
        let count = OCCTDocumentGetReferenceList(handle, Int32(tag), nil, 0)
        if count < 0 { return nil }
        if count == 0 { return [] }
        var tags = [Int32](repeating: 0, count: Int(count))
        _ = tags.withUnsafeMutableBufferPointer { buf in
            OCCTDocumentGetReferenceList(handle, Int32(tag), buf.baseAddress!, count)
        }
        return tags
    }

    /// Append a reference to a reference list attribute.
    func referenceListAppend(tag: Int, refTag: Int32) -> Bool {
        OCCTDocumentReferenceListAppend(handle, Int32(tag), refTag)
    }

    /// Clear a reference list attribute.
    func referenceListClear(tag: Int) -> Bool {
        OCCTDocumentReferenceListClear(handle, Int32(tag))
    }

    /// Check if a label has a reference list attribute.
    func hasReferenceList(tag: Int) -> Bool {
        OCCTDocumentHasReferenceList(handle, Int32(tag))
    }
}

// MARK: - TDataStd_Relation

public extension Document {
    /// Set a relation string on a label.
    func setRelation(tag: Int, relation: String) -> Bool {
        OCCTDocumentSetRelation(handle, Int32(tag), relation)
    }

    /// Get a relation string from a label.
    func relation(tag: Int) -> String? {
        guard let cStr = OCCTDocumentGetRelation(handle, Int32(tag)) else { return nil }
        defer { free(cStr) }
        return String(cString: cStr)
    }

    /// Check if a label has a relation attribute.
    func hasRelation(tag: Int) -> Bool {
        OCCTDocumentHasRelation(handle, Int32(tag))
    }
}

// MARK: - ShapeFix_Solid

public extension Shape {
    /// Fix a solid shape (topology and orientation).
    func fixSolid() -> Shape? {
        guard let ref = OCCTShapeFixSolid(handle) else { return nil }
        return Shape(handle: ref)
    }

    /// Create a solid from a shell shape using ShapeFix_Solid.
    func solidFromShellFixed() -> Shape? {
        guard let ref = OCCTShapeSolidFromShell(handle) else { return nil }
        return Shape(handle: ref)
    }
}

// MARK: - ShapeFix_EdgeConnect

public extension Shape {
    /// Connect edges in a shape by extending/trimming to match.
    func fixEdgeConnect() -> Shape? {
        guard let ref = OCCTShapeFixEdgeConnect(handle) else { return nil }
        return Shape(handle: ref)
    }
}

// MARK: - BRepOffsetAPI_FindContigousEdges

public extension Shape {
    /// Result of contiguous edge finding.
    struct ContigousEdgeResult: Sendable {
        public let contigousEdgeCount: Int
        public let degeneratedShapeCount: Int
    }

    /// Find contiguous edges in a shape.
    func findContigousEdges(tolerance: Double = 1.0e-6) -> ContigousEdgeResult {
        let result = OCCTShapeFindContigousEdges(handle, tolerance)
        return ContigousEdgeResult(
            contigousEdgeCount: Int(result.contigousEdgeCount),
            degeneratedShapeCount: Int(result.degeneratedShapeCount)
        )
    }
}

// MARK: - TDataStd_Tick

public extension Document {
    /// Set a tick (boolean flag) attribute on a label.
    func setTick(tag: Int) -> Bool {
        OCCTDocumentSetTick(handle, Int32(tag))
    }

    /// Check if a label has a tick attribute.
    func hasTick(tag: Int) -> Bool {
        OCCTDocumentHasTick(handle, Int32(tag))
    }

    /// Remove a tick attribute from a label.
    func removeTick(tag: Int) -> Bool {
        OCCTDocumentRemoveTick(handle, Int32(tag))
    }
}

// MARK: - TDataStd_Current

public extension Document {
    /// Set a label as the current label in the document.
    func setCurrentLabel(tag: Int) -> Bool {
        OCCTDocumentSetCurrentLabel(handle, Int32(tag))
    }

    /// Get the current label tag, or nil if none set.
    func currentLabel() -> Int? {
        let tag = OCCTDocumentGetCurrentLabel(handle)
        return tag >= 0 ? Int(tag) : nil
    }

    /// Check if the document has a current label set.
    func hasCurrentLabel() -> Bool {
        OCCTDocumentHasCurrentLabel(handle)
    }
}

// MARK: - ShapeAnalysis_Shell

public extension Shape {
    /// Result of shell analysis.
    struct ShellAnalysisResult: Sendable {
        public let hasOrientationProblems: Bool
        public let hasFreeEdges: Bool
        public let hasBadEdges: Bool
        public let hasConnectedEdges: Bool
        public let freeEdgeCount: Int
    }

    /// Analyze shell orientation and edge connectivity.
    func analyzeShell() -> ShellAnalysisResult {
        let r = OCCTShapeAnalyzeShell(handle)
        return ShellAnalysisResult(
            hasOrientationProblems: r.hasOrientationProblems,
            hasFreeEdges: r.hasFreeEdges,
            hasBadEdges: r.hasBadEdges,
            hasConnectedEdges: r.hasConnectedEdges,
            freeEdgeCount: Int(r.freeEdgeCount)
        )
    }
}

// MARK: - ShapeAnalysis_CanonicalRecognition (detailed)

public extension Shape {
    /// Canonical geometry type for detailed recognition.
    enum CanonicalGeometryType: Int, Sendable {
        case none = 0
        case plane = 1
        case cylinder = 2
        case cone = 3
        case sphere = 4
        case line = 5
        case circle = 6
        case ellipse = 7
    }

    /// Detailed canonical recognition result with geometry parameters.
    struct CanonicalRecognitionResult: Sendable {
        public let type: CanonicalGeometryType
        public let gap: Double
        public let origin: (x: Double, y: Double, z: Double)
        public let direction: (x: Double, y: Double, z: Double)
        public let param1: Double
        public let param2: Double
    }

    /// Recognize canonical surface geometry from a face with detailed parameters.
    func recognizeCanonicalSurface(tolerance: Double = 0.01) -> CanonicalRecognitionResult {
        let r = OCCTShapeRecognizeCanonicalSurface(handle, tolerance)
        return CanonicalRecognitionResult(
            type: CanonicalGeometryType(rawValue: Int(r.type.rawValue)) ?? .none,
            gap: r.gap,
            origin: (r.originX, r.originY, r.originZ),
            direction: (r.dirX, r.dirY, r.dirZ),
            param1: r.param1,
            param2: r.param2
        )
    }

    /// Recognize canonical curve geometry from an edge with detailed parameters.
    func recognizeCanonicalCurve(tolerance: Double = 0.01) -> CanonicalRecognitionResult {
        let r = OCCTShapeRecognizeCanonicalCurve(handle, tolerance)
        return CanonicalRecognitionResult(
            type: CanonicalGeometryType(rawValue: Int(r.type.rawValue)) ?? .none,
            gap: r.gap,
            origin: (r.originX, r.originY, r.originZ),
            direction: (r.dirX, r.dirY, r.dirZ),
            param1: r.param1,
            param2: r.param2
        )
    }
}

// MARK: - Geom_Transformation

/// 3D geometric transformation (Handle-wrapped).
public final class GeomTransformation: @unchecked Sendable {
    internal let ref: OCCTGeomTransformRef

    /// Create an identity transformation.
    public init?() {
        guard let r = OCCTGeomTransformCreate() else { return nil }
        self.ref = r
    }

    internal init(ref: OCCTGeomTransformRef) {
        self.ref = ref
    }

    deinit {
        OCCTGeomTransformRelease(ref)
    }

    /// Set translation by vector.
    public func setTranslation(dx: Double, dy: Double, dz: Double) {
        OCCTGeomTransformSetTranslation(ref, dx, dy, dz)
    }

    /// Set rotation about an axis.
    public func setRotation(originX: Double, originY: Double, originZ: Double,
                            dirX: Double, dirY: Double, dirZ: Double,
                            angle: Double) {
        OCCTGeomTransformSetRotation(ref, originX, originY, originZ, dirX, dirY, dirZ, angle)
    }

    /// Set scale about a point.
    public func setScale(centerX: Double, centerY: Double, centerZ: Double, factor: Double) {
        OCCTGeomTransformSetScale(ref, centerX, centerY, centerZ, factor)
    }

    /// Set point mirror.
    public func setMirrorPoint(x: Double, y: Double, z: Double) {
        OCCTGeomTransformSetMirrorPoint(ref, x, y, z)
    }

    /// Set axis mirror.
    public func setMirrorAxis(originX: Double, originY: Double, originZ: Double,
                              dirX: Double, dirY: Double, dirZ: Double) {
        OCCTGeomTransformSetMirrorAxis(ref, originX, originY, originZ, dirX, dirY, dirZ)
    }

    /// Get scale factor.
    public var scaleFactor: Double {
        OCCTGeomTransformScaleFactor(ref)
    }

    /// Check if negative (reflection).
    public var isNegative: Bool {
        OCCTGeomTransformIsNegative(ref)
    }

    /// Transform a point and return the result.
    public func apply(x: Double, y: Double, z: Double) -> (x: Double, y: Double, z: Double) {
        var px = x, py = y, pz = z
        OCCTGeomTransformApply(ref, &px, &py, &pz)
        return (px, py, pz)
    }

    /// Get matrix value (row 1-3, col 1-4).
    public func value(row: Int, col: Int) -> Double {
        OCCTGeomTransformValue(ref, Int32(row), Int32(col))
    }

    /// Multiply with another transformation, return new.
    public func multiplied(by other: GeomTransformation) -> GeomTransformation? {
        guard let r = OCCTGeomTransformMultiplied(ref, other.ref) else { return nil }
        return GeomTransformation(ref: r)
    }

    /// Return inverse transformation.
    public func inverted() -> GeomTransformation? {
        guard let r = OCCTGeomTransformInverted(ref) else { return nil }
        return GeomTransformation(ref: r)
    }
}

// MARK: - Geom_OffsetCurve

public extension Curve3D {
    /// Create an offset curve.
    static func offset(basis: Curve3D, offset: Double,
                       dirX: Double, dirY: Double, dirZ: Double) -> Curve3D? {
        guard let ref = OCCTCurve3DCreateOffset(basis.handle, offset, dirX, dirY, dirZ) else { return nil }
        return Curve3D(handle: ref)
    }

    /// Get the offset value (returns 0 if not an offset curve).
    var offsetValue: Double {
        OCCTCurve3DOffsetValue(handle)
    }

    /// Get the offset direction (returns nil if not an offset curve).
    var offsetDirection: (x: Double, y: Double, z: Double)? {
        var dx: Double = 0, dy: Double = 0, dz: Double = 0
        if OCCTCurve3DOffsetDirection(handle, &dx, &dy, &dz) {
            return (dx, dy, dz)
        }
        return nil
    }
}

// MARK: - Geom_RectangularTrimmedSurface

public extension Surface {
    /// Create a rectangular trimmed surface.
    static func rectangularTrimmed(basis: Surface,
                                    u1: Double, u2: Double,
                                    v1: Double, v2: Double) -> Surface? {
        guard let ref = OCCTSurfaceCreateRectangularTrimmed(basis.handle, u1, u2, v1, v2) else { return nil }
        return Surface(handle: ref)
    }

    /// Create a surface trimmed in U direction only.
    static func trimmedInU(basis: Surface, param1: Double, param2: Double) -> Surface? {
        guard let ref = OCCTSurfaceCreateTrimmedInU(basis.handle, param1, param2) else { return nil }
        return Surface(handle: ref)
    }

    /// Create a surface trimmed in V direction only.
    static func trimmedInV(basis: Surface, param1: Double, param2: Double) -> Surface? {
        guard let ref = OCCTSurfaceCreateTrimmedInV(basis.handle, param1, param2) else { return nil }
        return Surface(handle: ref)
    }
}

// MARK: - TNaming Extensions (v0.88.0)

extension Document {

    /// Check if a TNaming_NamedShape on a label is empty
    public func namingIsEmpty(on node: AssemblyNode) -> Bool {
        OCCTNamingIsEmpty(handle, node.labelId)
    }

    /// Get the version of a TNaming_NamedShape attribute
    public func namingVersion(on node: AssemblyNode) -> Int {
        Int(OCCTNamingGetVersion(handle, node.labelId))
    }

    /// Set the version of a TNaming_NamedShape attribute
    @discardableResult
    public func setNamingVersion(on node: AssemblyNode, version: Int) -> Bool {
        OCCTNamingSetVersion(handle, node.labelId, Int32(version))
    }

    /// Get the original (old) shape from a named shape attribute
    public func namingOriginalShape(on node: AssemblyNode) -> Shape? {
        guard let h = OCCTNamingOriginalShape(handle, node.labelId) else { return nil }
        return Shape(handle: h)
    }

    /// Check if a shape has a label in the document's naming framework
    public func namingHasLabel(shape: Shape) -> Bool {
        OCCTNamingHasLabel(handle, shape.handle)
    }

    /// Find the label for a shape in the document's naming framework
    public func namingFindLabel(shape: Shape) -> AssemblyNode? {
        let labelId = OCCTNamingFindLabel(handle, shape.handle)
        guard labelId >= 0 else { return nil }
        return AssemblyNode(document: self, labelId: labelId)
    }

    /// Get the valid-until transaction number for a shape
    public func namingValidUntil(shape: Shape) -> Int {
        Int(OCCTNamingValidUntil(handle, shape.handle))
    }

    /// Get count of labels containing the same shape
    public func sameShapeCount(shape: Shape) -> Int {
        Int(OCCTNamingSameShapeCount(handle, shape.handle))
    }

    /// Get all labels containing the same shape
    public func sameShapeLabels(shape: Shape) -> [AssemblyNode] {
        let count = OCCTNamingSameShapeCount(handle, shape.handle)
        guard count > 0 else { return [] }
        var ids = [Int64](repeating: 0, count: Int(count))
        let actual = OCCTNamingSameShapeLabels(handle, shape.handle, &ids, count)
        return (0..<Int(actual)).map { AssemblyNode(document: self, labelId: ids[$0]) }
    }
}

// MARK: - TDataStd_IntPackedMap (v0.88.0)

extension Document {

    /// Set (create) an IntPackedMap attribute on a label
    @discardableResult
    public func setIntPackedMap(tag: Int, isDelta: Bool = false) -> Bool {
        OCCTIntPackedMapSet(handle, Int32(tag), isDelta)
    }

    /// Add a value to the IntPackedMap
    @discardableResult
    public func intPackedMapAdd(tag: Int, value: Int) -> Bool {
        OCCTIntPackedMapAdd(handle, Int32(tag), Int32(value))
    }

    /// Remove a value from the IntPackedMap
    @discardableResult
    public func intPackedMapRemove(tag: Int, value: Int) -> Bool {
        OCCTIntPackedMapRemove(handle, Int32(tag), Int32(value))
    }

    /// Check if the IntPackedMap contains a value
    public func intPackedMapContains(tag: Int, value: Int) -> Bool {
        OCCTIntPackedMapContains(handle, Int32(tag), Int32(value))
    }

    /// Get the count of elements in the IntPackedMap
    public func intPackedMapCount(tag: Int) -> Int {
        Int(OCCTIntPackedMapExtent(handle, Int32(tag)))
    }

    /// Clear all elements from the IntPackedMap
    @discardableResult
    public func intPackedMapClear(tag: Int) -> Bool {
        OCCTIntPackedMapClear(handle, Int32(tag))
    }

    /// Check if the IntPackedMap is empty
    public func intPackedMapIsEmpty(tag: Int) -> Bool {
        OCCTIntPackedMapIsEmpty(handle, Int32(tag))
    }

    /// Get all values from the IntPackedMap
    public func intPackedMapValues(tag: Int) -> [Int] {
        var ptr: UnsafeMutablePointer<Int32>?
        let count = OCCTIntPackedMapGetValues(handle, Int32(tag), &ptr)
        guard count > 0, let ptr = ptr else { return [] }
        defer { OCCTIntPackedMapFreeValues(ptr) }
        return (0..<Int(count)).map { Int(ptr[$0]) }
    }

    /// Replace all values in the IntPackedMap
    @discardableResult
    public func intPackedMapSetValues(tag: Int, values: [Int]) -> Bool {
        let int32Values = values.map { Int32($0) }
        return int32Values.withUnsafeBufferPointer { buf in
            OCCTIntPackedMapChangeValues(handle, Int32(tag), buf.baseAddress!, Int32(values.count))
        }
    }
}

// MARK: - TDataStd_NoteBook (v0.88.0)

extension Document {

    /// Create a NoteBook attribute on a label
    @discardableResult
    public func setNoteBook(tag: Int) -> Bool {
        OCCTNoteBookNew(handle, Int32(tag))
    }

    /// Append a real value to the NoteBook, returns the child label tag or nil
    public func noteBookAppendReal(tag: Int, value: Double) -> Int? {
        let result = OCCTNoteBookAppendReal(handle, Int32(tag), value)
        return result >= 0 ? Int(result) : nil
    }

    /// Append an integer value to the NoteBook, returns the child label tag or nil
    public func noteBookAppendInteger(tag: Int, value: Int) -> Int? {
        let result = OCCTNoteBookAppendInteger(handle, Int32(tag), Int32(value))
        return result >= 0 ? Int(result) : nil
    }

    /// Check if a NoteBook exists on a label (searches up hierarchy)
    public func noteBookExists(tag: Int) -> Bool {
        OCCTNoteBookFind(handle, Int32(tag))
    }
}

// MARK: - TDataStd_UAttribute (v0.88.0)

extension Document {

    /// Set a UAttribute with a GUID string on a label
    @discardableResult
    public func setUAttribute(tag: Int, guid: String) -> Bool {
        OCCTUAttributeSet(handle, Int32(tag), guid)
    }

    /// Check if a UAttribute with a given GUID exists on a label
    public func hasUAttribute(tag: Int, guid: String) -> Bool {
        OCCTUAttributeHas(handle, Int32(tag), guid)
    }

    /// Get the GUID string of a UAttribute on a label
    public func uAttributeID(tag: Int, guid: String) -> String? {
        guard let ptr = OCCTUAttributeGetID(handle, Int32(tag), guid) else { return nil }
        defer { OCCTUAttributeFreeGUID(ptr) }
        return String(cString: ptr)
    }
}

// MARK: - TDataStd_ChildNodeIterator (v0.88.0)

extension Document {

    /// Get count of child tree nodes on a label
    public func childNodeCount(tag: Int, allLevels: Bool = false) -> Int {
        Int(OCCTChildNodeIteratorCount(handle, Int32(tag), allLevels))
    }
}

// MARK: - TDF_Transaction Named (v0.89.0)

extension Document {

    /// Open a named transaction on the document.
    /// - Parameter name: Transaction name for identification
    /// - Returns: Transaction number (>= 1 on success), or 0 on error
    @discardableResult
    public func openNamedTransaction(_ name: String) -> Int {
        Int(OCCTDocumentOpenNamedTransaction(handle, name))
    }

    /// Get the current transaction number.
    public var transactionNumber: Int {
        Int(OCCTDocumentGetTransactionNumber(handle))
    }

    /// Commit the current transaction and return a delta for inspection.
    /// The delta must be released when no longer needed.
    /// - Returns: An opaque delta handle, or nil if no changes
    public func commitWithDelta() -> TransactionDelta? {
        guard let ptr = OCCTDocumentCommitWithDelta(handle) else { return nil }
        return TransactionDelta(handle: ptr)
    }
}

/// Represents an undo delta from a committed transaction.
/// Provides information about what changed during the transaction.
public final class TransactionDelta: @unchecked Sendable {
    let handle: UnsafeMutableRawPointer

    init(handle: UnsafeMutableRawPointer) {
        self.handle = handle
    }

    deinit {
        OCCTDeltaRelease(handle)
    }

    /// Whether the delta is empty (no changes recorded).
    public var isEmpty: Bool {
        OCCTDeltaIsEmpty(handle)
    }

    /// The begin time of the delta.
    public var beginTime: Int {
        Int(OCCTDeltaBeginTime(handle))
    }

    /// The end time of the delta.
    public var endTime: Int {
        Int(OCCTDeltaEndTime(handle))
    }

    /// Number of attribute deltas (individual attribute changes).
    public var attributeDeltaCount: Int {
        Int(OCCTDeltaAttributeDeltaCount(handle))
    }

    /// Set the name of the delta.
    public func setName(_ name: String) {
        OCCTDeltaSetName(handle, name)
    }

    /// Get the name of the delta.
    public var name: String? {
        guard let ptr = OCCTDeltaGetName(handle) else { return nil }
        defer { OCCTDeltaFreeName(ptr) }
        return String(cString: ptr)
    }
}

// MARK: - TDF_ComparisonTool (v0.89.0)

extension Document {

    /// Check if a label's references are all contained within its descendants.
    /// - Parameter labelId: The label to check
    /// - Returns: true if self-contained
    public func isSelfContained(labelId: Int64) -> Bool {
        OCCTDocumentIsSelfContained(handle, labelId)
    }
}

// MARK: - TDocStd_XLinkTool (v0.89.0)

extension Document {

    /// Copy a label and its attributes to another label (simple copy).
    /// - Parameters:
    ///   - targetLabelId: Destination label
    ///   - sourceLabelId: Source label
    /// - Returns: true on success
    @discardableResult
    public func xlinkCopy(targetLabelId: Int64, sourceLabelId: Int64) -> Bool {
        OCCTDocumentXLinkCopy(handle, targetLabelId, sourceLabelId)
    }

    /// Copy a label with an XLink attribute for cross-document reference tracking.
    /// - Parameters:
    ///   - targetLabelId: Destination label
    ///   - sourceLabelId: Source label
    /// - Returns: true on success
    @discardableResult
    public func xlinkCopyWithLink(targetLabelId: Int64, sourceLabelId: Int64) -> Bool {
        OCCTDocumentXLinkCopyWithLink(handle, targetLabelId, sourceLabelId)
    }
}

// MARK: - TFunction_IFunction (v0.89.0)

extension Document {

    /// Execution status for a function in the function mechanism.
    public enum FunctionExecutionStatus: Int32 {
        case wrongDefinition = 0
        case notExecuted = 1
        case executing = 2
        case succeeded = 3
        case failed = 4
    }

    /// Create a new function at a label with a given GUID.
    /// Automatically creates a TFunction_Scope if not present.
    /// - Parameters:
    ///   - labelId: Label to attach the function to
    ///   - guid: GUID string identifying the function type
    /// - Returns: true on success
    @discardableResult
    public func newFunction(labelId: Int64, guid: String) -> Bool {
        OCCTDocumentNewFunction(handle, labelId, guid)
    }

    /// Delete a function from a label.
    /// - Parameter labelId: Label with the function
    /// - Returns: true on success
    @discardableResult
    public func deleteFunction(labelId: Int64) -> Bool {
        OCCTDocumentDeleteFunction(handle, labelId)
    }

    /// Get the execution status of a function.
    /// - Parameter labelId: Label with the function
    /// - Returns: The execution status, or nil if no function found
    public func functionExecStatus(labelId: Int64) -> FunctionExecutionStatus? {
        let raw = OCCTDocumentFunctionGetExecStatus(handle, labelId)
        if raw < 0 { return nil }
        return FunctionExecutionStatus(rawValue: raw)
    }

    /// Set the execution status of a function.
    /// - Parameters:
    ///   - labelId: Label with the function
    ///   - status: The new execution status
    /// - Returns: true on success
    @discardableResult
    public func setFunctionExecStatus(labelId: Int64, status: FunctionExecutionStatus) -> Bool {
        OCCTDocumentFunctionSetExecStatus(handle, labelId, status.rawValue)
    }
}

// MARK: - TFunction_Scope (v0.89.0)

extension Document {

    /// Set (find or create) a function scope on the document root.
    /// Required before using function mechanism operations.
    /// - Returns: true on success
    @discardableResult
    public func setFunctionScope() -> Bool {
        OCCTDocumentSetFunctionScope(handle)
    }

    /// Add a label to the function scope.
    /// - Parameter labelId: Label to register as a function
    /// - Returns: true on success
    @discardableResult
    public func functionScopeAdd(labelId: Int64) -> Bool {
        OCCTDocumentFunctionScopeAdd(handle, labelId)
    }

    /// Remove a label from the function scope.
    /// - Parameter labelId: Label to unregister
    /// - Returns: true on success
    @discardableResult
    public func functionScopeRemove(labelId: Int64) -> Bool {
        OCCTDocumentFunctionScopeRemove(handle, labelId)
    }

    /// Check if a label is registered in the function scope.
    /// - Parameter labelId: Label to check
    /// - Returns: true if in scope
    public func functionScopeHas(labelId: Int64) -> Bool {
        OCCTDocumentFunctionScopeHas(handle, labelId)
    }

    /// Remove all functions from the scope.
    /// - Returns: true on success
    @discardableResult
    public func functionScopeRemoveAll() -> Bool {
        OCCTDocumentFunctionScopeRemoveAll(handle)
    }

    /// Number of functions in the scope.
    public var functionScopeCount: Int {
        Int(OCCTDocumentFunctionScopeCount(handle))
    }

    /// The next available function ID in the scope.
    public var functionScopeFreeID: Int {
        Int(OCCTDocumentFunctionScopeGetFreeID(handle))
    }
}

// MARK: - TDF_AttributeIterator (v0.89.0)

extension Document {

    /// Count the number of attributes on a label.
    /// - Parameters:
    ///   - labelId: Label to inspect
    ///   - withoutForgotten: If true (default), skip forgotten attributes
    /// - Returns: Number of attributes
    public func attributeCount(labelId: Int64, withoutForgotten: Bool = true) -> Int {
        Int(OCCTDocumentAttributeCount(handle, labelId, withoutForgotten))
    }

    /// Check if a label has any content in a DataSet context.
    /// Returns false if the label is not empty (has been added to the data framework).
    public func dataSetIsEmpty(labelId: Int64) -> Bool {
        OCCTDocumentDataSetIsEmpty(handle, labelId)
    }
}

// MARK: - TDF_ChildIDIterator (v0.90.0)

extension Document {

    /// Count child labels that have an attribute with the given GUID.
    /// - Parameters:
    ///   - labelId: Parent label to search
    ///   - guid: GUID string of the attribute type
    ///   - allLevels: If true, recurse into all descendants
    /// - Returns: Number of matching children
    public func childIDCount(labelId: Int64, guid: String, allLevels: Bool = false) -> Int {
        Int(OCCTDocumentChildIDCount(handle, labelId, guid, allLevels))
    }
}

// MARK: - TDocStd_PathParser (v0.90.0)

/// Utility for parsing file paths into components.
public enum PathParser {

    /// Parse a file path and return the directory (trek) component.
    public static func trek(_ path: String) -> String? {
        guard let ptr = OCCTPathParserTrek(path) else { return nil }
        defer { OCCTPathParserFreeString(ptr) }
        return String(cString: ptr)
    }

    /// Parse a file path and return the filename (without extension).
    public static func name(_ path: String) -> String? {
        guard let ptr = OCCTPathParserName(path) else { return nil }
        defer { OCCTPathParserFreeString(ptr) }
        return String(cString: ptr)
    }

    /// Parse a file path and return the file extension.
    public static func fileExtension(_ path: String) -> String? {
        guard let ptr = OCCTPathParserExtension(path) else { return nil }
        defer { OCCTPathParserFreeString(ptr) }
        return String(cString: ptr)
    }
}

// MARK: - TFunction_DriverTable (v0.90.0)

/// Global function driver registry.
public enum FunctionDriverTable {

    /// Check if a function driver with the given GUID is registered.
    public static func hasDriver(guid: String) -> Bool {
        OCCTFunctionDriverTableHasDriver(guid)
    }

    /// Clear all registered function drivers.
    public static func clear() {
        OCCTFunctionDriverTableClear()
    }
}

// MARK: - TNaming_Scope (v0.90.0)

extension Document {

    /// Mark a label as valid in the naming scope.
    @discardableResult
    public func namingScopeValid(labelId: Int64) -> Bool {
        OCCTDocumentNamingScopeValid(handle, labelId)
    }

    /// Mark a label and its children as valid in the naming scope.
    @discardableResult
    public func namingScopeValidChildren(labelId: Int64, withRoot: Bool = true) -> Bool {
        OCCTDocumentNamingScopeValidChildren(handle, labelId, withRoot)
    }

    /// Check if a label is valid in the naming scope.
    public func namingScopeIsValid(labelId: Int64) -> Bool {
        OCCTDocumentNamingScopeIsValid(handle, labelId)
    }

    /// Remove a label from the valid set in the naming scope.
    @discardableResult
    public func namingScopeUnvalid(labelId: Int64) -> Bool {
        OCCTDocumentNamingScopeUnvalid(handle, labelId)
    }

    /// Clear all valid labels in the naming scope.
    public func namingScopeClear() {
        OCCTDocumentNamingScopeClear(handle)
    }

    /// Number of valid labels in the naming scope.
    public var namingScopeValidCount: Int {
        Int(OCCTDocumentNamingScopeValidCount(handle))
    }
}

// MARK: - TNaming_Translator (v0.90.0)

extension Shape {

    /// Create a deep copy of this shape using TNaming_Translator.
    /// The copy has independent topology (different TShape pointers).
    public func translatorCopy() -> Shape? {
        guard let ref = OCCTShapeTranslatorCopy(handle) else { return nil }
        return Shape(handle: ref)
    }

    /// Check if two shapes share the same underlying TShape.
    public func isSame(as other: Shape) -> Bool {
        OCCTShapeIsSame(handle, other.handle)
    }
}

// MARK: - TDataXtd_Placement (v0.90.0)

extension Document {

    /// Set a placement marker attribute on a label.
    @discardableResult
    public func setPlacement(labelId: Int64) -> Bool {
        OCCTDocumentSetPlacement(handle, labelId)
    }

    /// Check if a label has a placement marker attribute.
    public func hasPlacement(labelId: Int64) -> Bool {
        OCCTDocumentHasPlacement(handle, labelId)
    }
}

// MARK: - TDataXtd_Presentation (v0.90.0)

extension Document {

    /// Set a presentation attribute on a label with a driver GUID.
    @discardableResult
    public func setPresentation(labelId: Int64, driverGUID: String) -> Bool {
        OCCTDocumentSetPresentation(handle, labelId, driverGUID)
    }

    /// Remove a presentation attribute from a label.
    public func unsetPresentation(labelId: Int64) {
        OCCTDocumentUnsetPresentation(handle, labelId)
    }

    /// Check if a label has a presentation attribute.
    public func hasPresentation(labelId: Int64) -> Bool {
        OCCTDocumentHasPresentation(handle, labelId)
    }

    /// Set the display state of a presentation.
    @discardableResult
    public func presentationSetDisplayed(labelId: Int64, displayed: Bool) -> Bool {
        OCCTDocumentPresentationSetDisplayed(handle, labelId, displayed)
    }

    /// Get the display state of a presentation.
    public func presentationIsDisplayed(labelId: Int64) -> Bool {
        OCCTDocumentPresentationIsDisplayed(handle, labelId)
    }

    /// Set the color of a presentation (Quantity_NameOfColor index).
    @discardableResult
    public func presentationSetColor(labelId: Int64, colorIndex: Int32) -> Bool {
        OCCTDocumentPresentationSetColor(handle, labelId, colorIndex)
    }

    /// Get the color of a presentation. Returns nil if no own color.
    public func presentationGetColor(labelId: Int64) -> Int32? {
        let v = OCCTDocumentPresentationGetColor(handle, labelId)
        return v >= 0 ? v : nil
    }

    /// Set the transparency of a presentation [0.0, 1.0].
    @discardableResult
    public func presentationSetTransparency(labelId: Int64, value: Double) -> Bool {
        OCCTDocumentPresentationSetTransparency(handle, labelId, value)
    }

    /// Get the transparency. Returns nil if no own transparency.
    public func presentationGetTransparency(labelId: Int64) -> Double? {
        let v = OCCTDocumentPresentationGetTransparency(handle, labelId)
        return v >= 0 ? v : nil
    }

    /// Set the line width of a presentation.
    @discardableResult
    public func presentationSetWidth(labelId: Int64, width: Double) -> Bool {
        OCCTDocumentPresentationSetWidth(handle, labelId, width)
    }

    /// Get the line width. Returns nil if no own width.
    public func presentationGetWidth(labelId: Int64) -> Double? {
        let v = OCCTDocumentPresentationGetWidth(handle, labelId)
        return v >= 0 ? v : nil
    }

    /// Set the display mode of a presentation (0=wireframe, 1=shaded, etc.).
    @discardableResult
    public func presentationSetMode(labelId: Int64, mode: Int32) -> Bool {
        OCCTDocumentPresentationSetMode(handle, labelId, mode)
    }

    /// Get the display mode. Returns nil if no own mode.
    public func presentationGetMode(labelId: Int64) -> Int32? {
        let v = OCCTDocumentPresentationGetMode(handle, labelId)
        return v >= 0 ? v : nil
    }
}

// MARK: - XCAFDoc_AssemblyIterator (v0.90.0)

extension Document {

    /// Count the number of assembly items in the document.
    /// - Parameter maxDepth: Maximum traversal depth (0 = unlimited)
    public func assemblyItemCount(maxDepth: Int = 0) -> Int {
        Int(OCCTDocumentAssemblyItemCount(handle, Int32(maxDepth)))
    }
}

// MARK: - XCAFDoc_DimTol (v0.90.0)

extension Document {

    /// Set a dimension/tolerance attribute on a label.
    /// - Parameters:
    ///   - labelId: Label to set on
    ///   - kind: Dimension/tolerance type code
    ///   - values: Array of numeric values
    ///   - name: Name string
    ///   - description: Description string
    @discardableResult
    public func setDimTol(labelId: Int64, kind: Int32, values: [Double],
                          name: String, description: String) -> Bool {
        values.withUnsafeBufferPointer { buf in
            OCCTDocumentSetDimTol(handle, labelId, kind,
                                  buf.baseAddress!, Int32(values.count),
                                  name, description)
        }
    }

    /// Get the kind of a DimTol attribute. Returns nil if not found.
    public func dimTolKind(labelId: Int64) -> Int32? {
        let v = OCCTDocumentGetDimTolKind(handle, labelId)
        return v >= 0 ? v : nil
    }

    /// Get the name of a DimTol attribute.
    public func dimTolName(labelId: Int64) -> String? {
        guard let ptr = OCCTDocumentGetDimTolName(handle, labelId) else { return nil }
        defer { OCCTDocumentFreeDimTolString(ptr) }
        return String(cString: ptr)
    }

    /// Get the description of a DimTol attribute.
    public func dimTolDescription(labelId: Int64) -> String? {
        guard let ptr = OCCTDocumentGetDimTolDescription(handle, labelId) else { return nil }
        defer { OCCTDocumentFreeDimTolString(ptr) }
        return String(cString: ptr)
    }

    /// Get the values of a DimTol attribute.
    public func dimTolValues(labelId: Int64) -> [Double]? {
        var buffer = [Double](repeating: 0, count: 32)
        let count = buffer.withUnsafeMutableBufferPointer { buf in
            OCCTDocumentGetDimTolValues(handle, labelId, buf.baseAddress!, 32)
        }
        if count <= 0 { return nil }
        return Array(buffer.prefix(Int(count)))
    }
}

// MARK: - IntTools_Tools (v0.90.0)

/// Static utility functions for intersection computations.
public enum IntTools {

    /// Check if two vertex shapes are coincident (within tolerance).
    /// - Returns: 0 if coincident, non-zero otherwise
    public static func computeVV(_ vertex1: Shape, _ vertex2: Shape) -> Int {
        Int(OCCTIntToolsComputeVV(vertex1.handle, vertex2.handle))
    }

    /// Compute an intermediate parameter between two values.
    public static func intermediatePoint(first: Double, last: Double) -> Double {
        OCCTIntToolsIntermediatePoint(first, last)
    }

    /// Check if two directions are coincident (parallel or anti-parallel).
    public static func isDirsCoinside(dx1: Double, dy1: Double, dz1: Double,
                                       dx2: Double, dy2: Double, dz2: Double) -> Bool {
        OCCTIntToolsIsDirsCoinside(dx1, dy1, dz1, dx2, dy2, dz2)
    }

    /// Check if two directions are coincident within a tolerance.
    public static func isDirsCoinside(dx1: Double, dy1: Double, dz1: Double,
                                       dx2: Double, dy2: Double, dz2: Double,
                                       tolerance: Double) -> Bool {
        OCCTIntToolsIsDirsCoinisdeWithTol(dx1, dy1, dz1, dx2, dy2, dz2, tolerance)
    }

    /// Compute intersection range from tolerances and angle.
    public static func computeIntRange(tol1: Double, tol2: Double, angle: Double) -> Double {
        OCCTIntToolsComputeIntRange(tol1, tol2, angle)
    }
}

// MARK: - ElCLib — Elementary Curve Library (v0.91.0)

/// Static utility for evaluating elementary curves (line, circle, ellipse) at parameters.
public enum ElCLib {

    /// Evaluate point on a line at parameter u.
    public static func valueOnLine(u: Double, origin: SIMD3<Double>, direction: SIMD3<Double>) -> SIMD3<Double> {
        var x = 0.0, y = 0.0, z = 0.0
        OCCTElCLibValueOnLine(u, origin.x, origin.y, origin.z, direction.x, direction.y, direction.z, &x, &y, &z)
        return SIMD3(x, y, z)
    }

    /// Evaluate point on a circle at parameter u.
    public static func valueOnCircle(u: Double, center: SIMD3<Double>, normal: SIMD3<Double>, radius: Double) -> SIMD3<Double> {
        var x = 0.0, y = 0.0, z = 0.0
        OCCTElCLibValueOnCircle(u, center.x, center.y, center.z, normal.x, normal.y, normal.z, radius, &x, &y, &z)
        return SIMD3(x, y, z)
    }

    /// Evaluate point on an ellipse at parameter u.
    public static func valueOnEllipse(u: Double, center: SIMD3<Double>, normal: SIMD3<Double>,
                                       majorRadius: Double, minorRadius: Double) -> SIMD3<Double> {
        var x = 0.0, y = 0.0, z = 0.0
        OCCTElCLibValueOnEllipse(u, center.x, center.y, center.z, normal.x, normal.y, normal.z,
                                  majorRadius, minorRadius, &x, &y, &z)
        return SIMD3(x, y, z)
    }

    /// Evaluate point + tangent on a line at parameter u.
    public static func d1OnLine(u: Double, origin: SIMD3<Double>, direction: SIMD3<Double>) -> (point: SIMD3<Double>, tangent: SIMD3<Double>) {
        var px = 0.0, py = 0.0, pz = 0.0, vx = 0.0, vy = 0.0, vz = 0.0
        OCCTElCLibD1OnLine(u, origin.x, origin.y, origin.z, direction.x, direction.y, direction.z,
                           &px, &py, &pz, &vx, &vy, &vz)
        return (SIMD3(px, py, pz), SIMD3(vx, vy, vz))
    }

    /// Evaluate point + tangent on a circle at parameter u.
    public static func d1OnCircle(u: Double, center: SIMD3<Double>, normal: SIMD3<Double>, radius: Double) -> (point: SIMD3<Double>, tangent: SIMD3<Double>) {
        var px = 0.0, py = 0.0, pz = 0.0, vx = 0.0, vy = 0.0, vz = 0.0
        OCCTElCLibD1OnCircle(u, center.x, center.y, center.z, normal.x, normal.y, normal.z, radius,
                             &px, &py, &pz, &vx, &vy, &vz)
        return (SIMD3(px, py, pz), SIMD3(vx, vy, vz))
    }

    /// Get parameter of nearest point on line.
    public static func parameterOnLine(origin: SIMD3<Double>, direction: SIMD3<Double>, point: SIMD3<Double>) -> Double {
        OCCTElCLibParameterOnLine(origin.x, origin.y, origin.z, direction.x, direction.y, direction.z,
                                   point.x, point.y, point.z)
    }

    /// Get parameter of nearest point on circle.
    public static func parameterOnCircle(center: SIMD3<Double>, normal: SIMD3<Double>, radius: Double, point: SIMD3<Double>) -> Double {
        OCCTElCLibParameterOnCircle(center.x, center.y, center.z, normal.x, normal.y, normal.z, radius,
                                     point.x, point.y, point.z)
    }

    /// Normalize parameter to periodic range [uFirst, uLast).
    public static func inPeriod(u: Double, uFirst: Double, uLast: Double) -> Double {
        OCCTElCLibInPeriod(u, uFirst, uLast)
    }
}

// MARK: - ElSLib — Elementary Surface Library (v0.91.0)

/// Static utility for evaluating elementary surfaces at (u,v) parameters.
public enum ElSLib {

    /// Evaluate point on a plane at (u,v).
    public static func valueOnPlane(u: Double, v: Double, origin: SIMD3<Double>, normal: SIMD3<Double>) -> SIMD3<Double> {
        var x = 0.0, y = 0.0, z = 0.0
        OCCTElSLibValueOnPlane(u, v, origin.x, origin.y, origin.z, normal.x, normal.y, normal.z, &x, &y, &z)
        return SIMD3(x, y, z)
    }

    /// Evaluate point on a cylinder at (u,v).
    public static func valueOnCylinder(u: Double, v: Double, origin: SIMD3<Double>, axis: SIMD3<Double>, radius: Double) -> SIMD3<Double> {
        var x = 0.0, y = 0.0, z = 0.0
        OCCTElSLibValueOnCylinder(u, v, origin.x, origin.y, origin.z, axis.x, axis.y, axis.z, radius, &x, &y, &z)
        return SIMD3(x, y, z)
    }

    /// Evaluate point on a cone at (u,v).
    public static func valueOnCone(u: Double, v: Double, origin: SIMD3<Double>, axis: SIMD3<Double>,
                                    refRadius: Double, semiAngle: Double) -> SIMD3<Double> {
        var x = 0.0, y = 0.0, z = 0.0
        OCCTElSLibValueOnCone(u, v, origin.x, origin.y, origin.z, axis.x, axis.y, axis.z,
                              refRadius, semiAngle, &x, &y, &z)
        return SIMD3(x, y, z)
    }

    /// Evaluate point on a sphere at (u,v).
    public static func valueOnSphere(u: Double, v: Double, origin: SIMD3<Double>, axis: SIMD3<Double>, radius: Double) -> SIMD3<Double> {
        var x = 0.0, y = 0.0, z = 0.0
        OCCTElSLibValueOnSphere(u, v, origin.x, origin.y, origin.z, axis.x, axis.y, axis.z, radius, &x, &y, &z)
        return SIMD3(x, y, z)
    }

    /// Evaluate point on a torus at (u,v).
    public static func valueOnTorus(u: Double, v: Double, origin: SIMD3<Double>, axis: SIMD3<Double>,
                                     majorRadius: Double, minorRadius: Double) -> SIMD3<Double> {
        var x = 0.0, y = 0.0, z = 0.0
        OCCTElSLibValueOnTorus(u, v, origin.x, origin.y, origin.z, axis.x, axis.y, axis.z,
                               majorRadius, minorRadius, &x, &y, &z)
        return SIMD3(x, y, z)
    }

    /// Get (u,v) parameters of nearest point on sphere.
    public static func parametersOnSphere(origin: SIMD3<Double>, axis: SIMD3<Double>, radius: Double,
                                           point: SIMD3<Double>) -> (u: Double, v: Double) {
        var u = 0.0, v = 0.0
        OCCTElSLibParametersOnSphere(origin.x, origin.y, origin.z, axis.x, axis.y, axis.z, radius,
                                      point.x, point.y, point.z, &u, &v)
        return (u, v)
    }

    /// Evaluate point + partial derivatives on sphere at (u,v).
    public static func d1OnSphere(u: Double, v: Double, origin: SIMD3<Double>, axis: SIMD3<Double>,
                                   radius: Double) -> (point: SIMD3<Double>, dU: SIMD3<Double>, dV: SIMD3<Double>) {
        var px = 0.0, py = 0.0, pz = 0.0
        var ux = 0.0, uy = 0.0, uz = 0.0
        var vx = 0.0, vy = 0.0, vz = 0.0
        OCCTElSLibD1OnSphere(u, v, origin.x, origin.y, origin.z, axis.x, axis.y, axis.z, radius,
                             &px, &py, &pz, &ux, &uy, &uz, &vx, &vy, &vz)
        return (SIMD3(px, py, pz), SIMD3(ux, uy, uz), SIMD3(vx, vy, vz))
    }
}

// MARK: - gp_Quaternion (v0.91.0)

/// Quaternion for 3D rotation representation.
public final class Quaternion: @unchecked Sendable {
    let handle: OCCTQuaternionRef

    init(handle: OCCTQuaternionRef) {
        self.handle = handle
    }

    deinit {
        OCCTQuaternionRelease(handle)
    }

    /// Create a quaternion from components.
    public convenience init(x: Double = 0, y: Double = 0, z: Double = 0, w: Double = 1) {
        self.init(handle: OCCTQuaternionCreate(x, y, z, w))
    }

    /// Create a quaternion from axis-angle rotation.
    public static func fromAxisAngle(axis: SIMD3<Double>, angle: Double) -> Quaternion {
        Quaternion(handle: OCCTQuaternionCreateFromAxisAngle(axis.x, axis.y, axis.z, angle))
    }

    /// Create a quaternion from two vectors (shortest arc rotation).
    public static func fromVectors(from: SIMD3<Double>, to: SIMD3<Double>) -> Quaternion {
        Quaternion(handle: OCCTQuaternionCreateFromVectors(from.x, from.y, from.z, to.x, to.y, to.z))
    }

    /// Get components as (x, y, z, w).
    public var components: (x: Double, y: Double, z: Double, w: Double) {
        var x = 0.0, y = 0.0, z = 0.0, w = 0.0
        OCCTQuaternionGetComponents(handle, &x, &y, &z, &w)
        return (x, y, z, w)
    }

    /// Set Euler angles. Order: 0=Intrinsic_XYZ, etc.
    public func setEulerAngles(order: Int32, alpha: Double, beta: Double, gamma: Double) {
        OCCTQuaternionSetEulerAngles(handle, order, alpha, beta, gamma)
    }

    /// Get Euler angles.
    public func getEulerAngles(order: Int32) -> (alpha: Double, beta: Double, gamma: Double) {
        var a = 0.0, b = 0.0, g = 0.0
        OCCTQuaternionGetEulerAngles(handle, order, &a, &b, &g)
        return (a, b, g)
    }

    /// Get rotation matrix as 9 doubles (row-major).
    public var matrix: [Double] {
        var m = [Double](repeating: 0, count: 9)
        m.withUnsafeMutableBufferPointer { buf in
            OCCTQuaternionGetMatrix(handle, buf.baseAddress!)
        }
        return m
    }

    /// Rotate a vector by this quaternion.
    public func rotate(_ vector: SIMD3<Double>) -> SIMD3<Double> {
        var x = 0.0, y = 0.0, z = 0.0
        OCCTQuaternionMultiplyVec(handle, vector.x, vector.y, vector.z, &x, &y, &z)
        return SIMD3(x, y, z)
    }

    /// Multiply with another quaternion (Hamilton product).
    public func multiplied(by other: Quaternion) -> Quaternion {
        Quaternion(handle: OCCTQuaternionMultiply(handle, other.handle))
    }

    /// Get axis-angle representation.
    public var axisAngle: (axis: SIMD3<Double>, angle: Double) {
        var ax = 0.0, ay = 0.0, az = 0.0, angle = 0.0
        OCCTQuaternionGetVectorAndAngle(handle, &ax, &ay, &az, &angle)
        return (SIMD3(ax, ay, az), angle)
    }

    /// Get the rotation angle.
    public var rotationAngle: Double {
        OCCTQuaternionGetRotationAngle(handle)
    }

    /// Normalize to unit length.
    public func normalize() {
        OCCTQuaternionNormalize(handle)
    }
}

// MARK: - OSD_Timer (v0.91.0)

/// High-resolution wall-clock timer.
public final class Timer: @unchecked Sendable {
    let handle: OCCTTimerRef

    public init() {
        handle = OCCTTimerCreate()
    }

    deinit {
        OCCTTimerRelease(handle)
    }

    /// Start the timer.
    public func start() {
        OCCTTimerStart(handle)
    }

    /// Stop the timer.
    public func stop() {
        OCCTTimerStop(handle)
    }

    /// Reset the timer to zero.
    public func reset() {
        OCCTTimerReset(handle)
    }

    /// Elapsed wall-clock time in seconds.
    public var elapsedTime: Double {
        OCCTTimerElapsedTime(handle)
    }

    /// Current wall-clock time in seconds (static).
    public static var wallClockTime: Double {
        OCCTTimerGetWallClockTime()
    }
}

// MARK: - Bnd_OBB — Oriented Bounding Box (v0.92.0)

/// Oriented bounding box in 3D space.
public final class OBB: @unchecked Sendable {
    let handle: OCCTOBBRef

    init(handle: OCCTOBBRef) { self.handle = handle }

    deinit { OCCTOBBRelease(handle) }

    /// Create an OBB from center, axes, and half-sizes.
    public init(center: SIMD3<Double>, xDir: SIMD3<Double>, yDir: SIMD3<Double>, zDir: SIMD3<Double>,
                hx: Double, hy: Double, hz: Double) {
        handle = OCCTOBBCreate(center.x, center.y, center.z,
                               xDir.x, xDir.y, xDir.z,
                               yDir.x, yDir.y, yDir.z,
                               zDir.x, zDir.y, zDir.z,
                               hx, hy, hz)
    }

    /// Create an OBB from a shape's bounding box.
    public static func fromShape(_ shape: Shape) -> OBB? {
        guard let ref = OCCTOBBCreateFromShape(shape.handle) else { return nil }
        return OBB(handle: ref)
    }

    /// Whether the OBB is void (empty).
    public var isVoid: Bool { OCCTOBBIsVoid(handle) }

    /// Center of the OBB.
    public var center: SIMD3<Double> {
        var x = 0.0, y = 0.0, z = 0.0
        OCCTOBBGetCenter(handle, &x, &y, &z)
        return SIMD3(x, y, z)
    }

    /// Half-sizes of the OBB along its local axes.
    public var halfSizes: SIMD3<Double> {
        var hx = 0.0, hy = 0.0, hz = 0.0
        OCCTOBBGetHalfSizes(handle, &hx, &hy, &hz)
        return SIMD3(hx, hy, hz)
    }

    /// Check if a point is outside the OBB.
    public func isOut(point: SIMD3<Double>) -> Bool {
        OCCTOBBIsOutPoint(handle, point.x, point.y, point.z)
    }

    /// Check if another OBB is outside (no overlap).
    public func isOut(_ other: OBB) -> Bool {
        OCCTOBBIsOutOBB(handle, other.handle)
    }

    /// Enlarge the OBB by a gap value on all sides.
    public func enlarge(by gap: Double) {
        OCCTOBBEnlarge(handle, gap)
    }

    /// Square extent (diagonal squared).
    public var squareExtent: Double { OCCTOBBSquareExtent(handle) }
}

// MARK: - Bnd_Range — 1D Range (v0.92.0)

/// A 1D interval [min, max] with void state.
public final class Range: @unchecked Sendable {
    let handle: OCCTRangeRef

    init(handle: OCCTRangeRef) { self.handle = handle }

    deinit { OCCTRangeRelease(handle) }

    /// Create a range [min, max].
    public init(min: Double, max: Double) {
        handle = OCCTRangeCreate(min, max)
    }

    /// Create a void (empty) range.
    public init() {
        handle = OCCTRangeCreateVoid()
    }

    /// Whether the range is void.
    public var isVoid: Bool { OCCTRangeIsVoid(handle) }

    /// Get bounds as (first, last). Returns nil if void.
    public var bounds: (first: Double, last: Double)? {
        var first = 0.0, last = 0.0
        guard OCCTRangeGetBounds(handle, &first, &last) else { return nil }
        return (first, last)
    }

    /// Delta (max - min).
    public var delta: Double { OCCTRangeDelta(handle) }

    /// Check if value is in range.
    public func contains(_ value: Double) -> Bool { OCCTRangeContains(handle, value) }

    /// Extend range to include a value.
    public func add(_ value: Double) { OCCTRangeAddValue(handle, value) }

    /// Extend range to include another range.
    public func add(_ other: Range) { OCCTRangeAddRange(handle, other.handle) }

    /// Intersect with another range.
    public func common(_ other: Range) { OCCTRangeCommon(handle, other.handle) }

    /// Enlarge both boundaries.
    public func enlarge(by delta: Double) { OCCTRangeEnlarge(handle, delta) }

    /// Trim lower boundary.
    public func trimFrom(_ lower: Double) { OCCTRangeTrimFrom(handle, lower) }

    /// Trim upper boundary.
    public func trimTo(_ upper: Double) { OCCTRangeTrimTo(handle, upper) }
}

// MARK: - BRepClass3d — Point Classification (v0.92.0)

extension Shape {

    /// Classification state for a point relative to a solid.
    public enum PointState: Int32 {
        case inside = 0
        case outside = 1
        case on = 2
        case unknown = 3
    }

    /// Classify a 3D point relative to this solid shape.
    /// - Parameters:
    ///   - point: The 3D point to classify
    ///   - tolerance: Classification tolerance
    /// - Returns: The classification state
    public func classifyPoint(_ point: SIMD3<Double>, tolerance: Double = 1e-6) -> PointState {
        let raw = OCCTShapeClassifyPoint(handle, point.x, point.y, point.z, tolerance)
        return PointState(rawValue: raw) ?? .unknown
    }
}

// MARK: - TDataXtd_Constraint (v0.92.0)

extension Document {

    /// Constraint type enum matching TDataXtd_ConstraintEnum.
    public enum ConstraintType: Int32 {
        case radius = 0, diameter, minorRadius, majorRadius
        case tangent, parallel, perpendicular, concentric
        case coincident, distance, angle, equalRadius
        case symmetry, midPoint, equalDistance, fix
        case rigid, from
    }

    /// Set a constraint attribute on a label.
    @discardableResult
    public func setConstraint(labelId: Int64) -> Bool {
        OCCTDocumentSetConstraint(handle, labelId)
    }

    /// Set the constraint type.
    @discardableResult
    public func constraintSetType(labelId: Int64, type: ConstraintType) -> Bool {
        OCCTDocumentConstraintSetType(handle, labelId, type.rawValue)
    }

    /// Get the constraint type. Returns nil if not found.
    public func constraintGetType(labelId: Int64) -> ConstraintType? {
        let raw = OCCTDocumentConstraintGetType(handle, labelId)
        if raw < 0 { return nil }
        return ConstraintType(rawValue: raw)
    }

    /// Number of geometries in the constraint.
    public func constraintNbGeometries(labelId: Int64) -> Int {
        Int(OCCTDocumentConstraintNbGeometries(handle, labelId))
    }

    /// Check if constraint is planar (2D).
    public func constraintIsPlanar(labelId: Int64) -> Bool {
        OCCTDocumentConstraintIsPlanar(handle, labelId)
    }

    /// Check if constraint is a dimension (has value).
    public func constraintIsDimension(labelId: Int64) -> Bool {
        OCCTDocumentConstraintIsDimension(handle, labelId)
    }

    /// Set the verified flag.
    @discardableResult
    public func constraintSetVerified(labelId: Int64, verified: Bool) -> Bool {
        OCCTDocumentConstraintSetVerified(handle, labelId, verified)
    }

    /// Get the verified flag.
    public func constraintGetVerified(labelId: Int64) -> Bool {
        OCCTDocumentConstraintGetVerified(handle, labelId)
    }

    /// Clear all geometries from a constraint.
    @discardableResult
    public func constraintClearGeometries(labelId: Int64) -> Bool {
        OCCTDocumentConstraintClearGeometries(handle, labelId)
    }
}

// MARK: - OSD_MemInfo (v0.93.0)

/// Process memory information utility.
public enum MemInfo {

    /// Heap usage in bytes.
    public static var heapUsage: Int64 { OCCTMemInfoHeapUsage() }

    /// Working set in bytes.
    public static var workingSet: Int64 { OCCTMemInfoWorkingSet() }

    /// Heap usage in precise MiB.
    public static var heapUsageMiB: Double { OCCTMemInfoHeapUsageMiB() }

    /// Full memory info as a formatted string.
    public static var infoString: String? {
        guard let ptr = OCCTMemInfoString() else { return nil }
        defer { OCCTMemInfoFreeString(ptr) }
        return String(cString: ptr)
    }
}

// MARK: - ShapeFix_EdgeProjAux (v0.93.0)

extension Shape {

    /// Project edge endpoints onto face pcurve.
    /// - Parameters:
    ///   - faceIndex: Index of the face (0-based)
    ///   - edgeIndex: Index of the edge within the face (0-based)
    ///   - precision: Projection precision
    /// - Returns: (firstParam, lastParam) or nil if projection fails
    public func edgeProjAux(faceIndex: Int, edgeIndex: Int, precision: Double = 1e-6) -> (first: Double, last: Double)? {
        var first = 0.0, last = 0.0
        guard OCCTShapeFixEdgeProjAux(handle, Int32(faceIndex), Int32(edgeIndex), precision, &first, &last) else {
            return nil
        }
        return (first, last)
    }
}

// MARK: - Geom2dAPI_Interpolate (v0.93.0)

extension Curve2D {

    /// Interpolate a 2D BSpline curve through points.
    /// - Parameters:
    ///   - points: Array of 2D points (x, y)
    ///   - periodic: If true, create a periodic (closed) curve
    ///   - tolerance: Interpolation tolerance
    /// - Returns: The interpolated curve, or nil on failure
    public static func interpolate2D(points: [(Double, Double)], periodic: Bool = false, tolerance: Double = 1e-6) -> Curve2D? {
        let xs = points.map(\.0)
        let ys = points.map(\.1)
        return xs.withUnsafeBufferPointer { xBuf in
            ys.withUnsafeBufferPointer { yBuf in
                guard let ref = OCCTCurve2DInterpolate2D(xBuf.baseAddress!, yBuf.baseAddress!,
                                                         Int32(points.count), periodic, tolerance) else {
                    return nil
                }
                return Curve2D(handle: ref)
            }
        }
    }
}

// MARK: - Geom2dAPI_PointsToBSpline (v0.93.0)

extension Curve2D {

    /// Approximate a 2D BSpline curve through points.
    /// - Parameter points: Array of 2D points (x, y)
    /// - Returns: The approximated curve, or nil on failure
    public static func approximate2D(points: [(Double, Double)]) -> Curve2D? {
        let xs = points.map(\.0)
        let ys = points.map(\.1)
        return xs.withUnsafeBufferPointer { xBuf in
            ys.withUnsafeBufferPointer { yBuf in
                guard let ref = OCCTCurve2DApproximate2D(xBuf.baseAddress!, yBuf.baseAddress!,
                                                          Int32(points.count)) else {
                    return nil
                }
                return Curve2D(handle: ref)
            }
        }
    }
}

// MARK: - TDataXtd_PatternStd (v0.93.0)

extension Document {

    /// Pattern type for TDataXtd_PatternStd.
    public enum PatternSignature: Int32 {
        case linear = 1
        case circular = 2
        case rectangular = 3
        case radialCircular = 4
        case mirror = 5
    }

    /// Set a pattern attribute on a label.
    @discardableResult
    public func setPattern(labelId: Int64) -> Bool {
        OCCTDocumentSetPatternStd(handle, labelId)
    }

    /// Check if a label has a pattern attribute.
    public func hasPattern(labelId: Int64) -> Bool {
        OCCTDocumentHasPattern(handle, labelId)
    }

    /// Set pattern signature (type).
    @discardableResult
    public func patternSetSignature(labelId: Int64, signature: PatternSignature) -> Bool {
        OCCTDocumentPatternSetSignature(handle, labelId, signature.rawValue)
    }

    /// Get pattern signature. Returns nil if not found.
    public func patternGetSignature(labelId: Int64) -> PatternSignature? {
        let raw = OCCTDocumentPatternGetSignature(handle, labelId)
        if raw < 0 { return nil }
        return PatternSignature(rawValue: raw)
    }

    /// Number of transforms in the pattern.
    public func patternNbTrsfs(labelId: Int64) -> Int {
        Int(OCCTDocumentPatternNbTrsfs(handle, labelId))
    }
}

// MARK: - BRepAlgo_FaceRestrictor (v0.93.0)

extension Shape {

    /// Restrict a face to its wires using BRepAlgo_FaceRestrictor.
    /// - Parameter faceIndex: Index of the face (0-based)
    /// - Returns: Number of result faces
    public func faceRestrictAlgo(faceIndex: Int) -> Int {
        Int(OCCTShapeFaceRestrictAlgo(handle, Int32(faceIndex), nil, 0))
    }
}

// MARK: - math_Matrix (v0.94.0)

/// Dense mathematical matrix with 1-based indexing.
public final class MathMatrix: @unchecked Sendable {
    let handle: OCCTMathMatrixRef

    init(handle: OCCTMathMatrixRef) { self.handle = handle }
    deinit { OCCTMathMatrixRelease(handle) }

    /// Create a matrix with given dimensions, initialized to a value.
    public init(rows: Int, cols: Int, initialValue: Double = 0.0) {
        handle = OCCTMathMatrixCreate(Int32(rows), Int32(cols), initialValue)
    }

    /// Number of rows.
    public var rows: Int { Int(OCCTMathMatrixRows(handle)) }
    /// Number of columns.
    public var cols: Int { Int(OCCTMathMatrixCols(handle)) }

    /// Get value at (row, col) — 1-based indexing.
    public func value(row: Int, col: Int) -> Double {
        OCCTMathMatrixGetValue(handle, Int32(row), Int32(col))
    }

    /// Set value at (row, col) — 1-based indexing.
    public func setValue(row: Int, col: Int, value: Double) {
        OCCTMathMatrixSetValue(handle, Int32(row), Int32(col), value)
    }

    /// Compute determinant.
    public var determinant: Double { OCCTMathMatrixDeterminant(handle) }

    /// Invert the matrix in-place.
    @discardableResult
    public func invert() -> Bool { OCCTMathMatrixInvert(handle) }

    /// Multiply all elements by a scalar.
    public func multiply(by scalar: Double) { OCCTMathMatrixMultiplyScalar(handle, scalar) }

    /// Transpose the matrix in-place.
    public func transpose() { OCCTMathMatrixTranspose(handle) }
}

// MARK: - math_Gauss (v0.94.0)

/// Gaussian elimination linear system solver.
public enum MathGauss {

    /// Solve Ax=b where A is NxN and b is length N.
    /// - Parameters:
    ///   - matrix: Row-major NxN matrix (N*N elements)
    ///   - rhs: Right-hand side vector (N elements)
    /// - Returns: Solution vector, or nil on failure
    public static func solve(matrix: [Double], rhs: [Double]) -> [Double]? {
        let n = rhs.count
        guard matrix.count == n * n else { return nil }
        var solution = [Double](repeating: 0, count: n)
        let ok = matrix.withUnsafeBufferPointer { mBuf in
            rhs.withUnsafeBufferPointer { bBuf in
                solution.withUnsafeMutableBufferPointer { xBuf in
                    OCCTMathGaussSolve(mBuf.baseAddress!, Int32(n), bBuf.baseAddress!, xBuf.baseAddress!)
                }
            }
        }
        return ok ? solution : nil
    }

    /// Compute determinant using Gauss elimination.
    public static func determinant(matrix: [Double], n: Int) -> Double {
        matrix.withUnsafeBufferPointer { buf in
            OCCTMathGaussDeterminant(buf.baseAddress!, Int32(n))
        }
    }
}

// MARK: - math_SVD (v0.94.0)

/// Singular Value Decomposition solver.
public enum MathSVD {

    /// Solve least-squares Ax=b where A is MxN.
    /// - Parameters:
    ///   - matrix: Row-major MxN matrix
    ///   - rows: M
    ///   - cols: N
    ///   - rhs: Right-hand side (length M)
    /// - Returns: Solution vector (length N), or nil on failure
    public static func solve(matrix: [Double], rows: Int, cols: Int, rhs: [Double]) -> [Double]? {
        guard matrix.count == rows * cols, rhs.count == rows else { return nil }
        var solution = [Double](repeating: 0, count: cols)
        let ok = matrix.withUnsafeBufferPointer { mBuf in
            rhs.withUnsafeBufferPointer { bBuf in
                solution.withUnsafeMutableBufferPointer { xBuf in
                    OCCTMathSVDSolve(mBuf.baseAddress!, Int32(rows), Int32(cols), bBuf.baseAddress!, xBuf.baseAddress!)
                }
            }
        }
        return ok ? solution : nil
    }
}

// MARK: - math_DirectPolynomialRoots (v0.94.0)

/// Polynomial root finder (degree 1-4).
public enum MathPolynomialRoots {

    /// Find real roots of a polynomial.
    /// - Parameter coefficients: [a, b, c, ...] for a*x^n + b*x^(n-1) + ... (2-5 elements)
    /// - Returns: Array of real roots, or nil on error
    public static func solve(coefficients: [Double]) -> [Double]? {
        guard coefficients.count >= 2, coefficients.count <= 5 else { return nil }
        var roots = [Double](repeating: 0, count: 4)
        let n = coefficients.withUnsafeBufferPointer { cBuf in
            roots.withUnsafeMutableBufferPointer { rBuf in
                OCCTMathPolynomialRoots(cBuf.baseAddress!, Int32(coefficients.count), rBuf.baseAddress!)
            }
        }
        if n < 0 { return nil }
        return Array(roots.prefix(Int(n)))
    }
}

// MARK: - math_Jacobi (v0.94.0)

/// Jacobi eigenvalue solver for symmetric matrices.
public enum MathJacobi {

    /// Compute eigenvalues of a symmetric NxN matrix.
    /// - Parameters:
    ///   - matrix: Row-major NxN symmetric matrix
    ///   - n: Dimension
    /// - Returns: Eigenvalues, or nil on failure
    public static func eigenvalues(matrix: [Double], n: Int) -> [Double]? {
        guard matrix.count == n * n else { return nil }
        var eigenvalues = [Double](repeating: 0, count: n)
        let ok = matrix.withUnsafeBufferPointer { mBuf in
            eigenvalues.withUnsafeMutableBufferPointer { eBuf in
                OCCTMathJacobiEigenvalues(mBuf.baseAddress!, Int32(n), eBuf.baseAddress!)
            }
        }
        return ok ? eigenvalues : nil
    }
}

// MARK: - Convert_CircleToBSplineCurve (v0.94.0)

extension Curve2D {

    /// Convert a 2D circle arc to a BSpline curve.
    public static func fromCircleArc(centerX: Double, centerY: Double, radius: Double,
                                      u1: Double, u2: Double) -> Curve2D? {
        guard let ref = OCCTConvertCircleToBSpline2D(centerX, centerY, radius, u1, u2) else { return nil }
        return Curve2D(handle: ref)
    }
}

// MARK: - Convert_SphereToBSplineSurface (v0.94.0)

extension Surface {

    /// Convert a sphere to a BSpline surface.
    public static func fromSphere(origin: SIMD3<Double>, axis: SIMD3<Double>, radius: Double) -> Surface? {
        guard let ref = OCCTConvertSphereToBSplineSurface(origin.x, origin.y, origin.z,
                                                           axis.x, axis.y, axis.z, radius) else { return nil }
        return Surface(handle: ref)
    }
}

// MARK: - OSD_Environment (v0.94.0)

/// Environment variable access.
public enum Environment {

    /// Get the value of an environment variable.
    public static func get(_ name: String) -> String? {
        guard let ptr = OCCTEnvironmentGet(name) else { return nil }
        defer { OCCTEnvironmentFreeString(ptr) }
        return String(cString: ptr)
    }

    /// Set an environment variable.
    @discardableResult
    public static func set(_ name: String, value: String) -> Bool {
        OCCTEnvironmentSet(name, value)
    }

    /// Remove an environment variable.
    public static func remove(_ name: String) {
        OCCTEnvironmentRemove(name)
    }
}

// MARK: - Convert Conic Curves to BSpline (v0.95.0)

extension Curve2D {

    /// Convert a 2D ellipse arc to a BSpline curve.
    public static func fromEllipseArc(centerX: Double, centerY: Double,
                                       majorRadius: Double, minorRadius: Double,
                                       u1: Double, u2: Double) -> Curve2D? {
        guard let ref = OCCTConvertEllipseToBSpline2D(centerX, centerY, majorRadius, minorRadius, u1, u2) else { return nil }
        return Curve2D(handle: ref)
    }

    /// Convert a 2D hyperbola arc to a BSpline curve.
    public static func fromHyperbolaArc(centerX: Double, centerY: Double,
                                         majorRadius: Double, minorRadius: Double,
                                         u1: Double, u2: Double) -> Curve2D? {
        guard let ref = OCCTConvertHyperbolaToBSpline2D(centerX, centerY, majorRadius, minorRadius, u1, u2) else { return nil }
        return Curve2D(handle: ref)
    }

    /// Convert a 2D parabola arc to a BSpline curve.
    public static func fromParabolaArc(centerX: Double, centerY: Double, focal: Double,
                                        u1: Double, u2: Double) -> Curve2D? {
        guard let ref = OCCTConvertParabolaToBSpline2D(centerX, centerY, focal, u1, u2) else { return nil }
        return Curve2D(handle: ref)
    }
}

// MARK: - Convert Elementary Surfaces to BSpline (v0.95.0)

extension Surface {

    /// Convert a cylinder patch to a BSpline surface.
    public static func fromCylinder(origin: SIMD3<Double>, axis: SIMD3<Double>, radius: Double,
                                     u1: Double, u2: Double, v1: Double, v2: Double) -> Surface? {
        guard let ref = OCCTConvertCylinderToBSplineSurface(origin.x, origin.y, origin.z,
                                                              axis.x, axis.y, axis.z, radius,
                                                              u1, u2, v1, v2) else { return nil }
        return Surface(handle: ref)
    }

    /// Convert a cone patch to a BSpline surface.
    public static func fromCone(origin: SIMD3<Double>, axis: SIMD3<Double>,
                                 semiAngle: Double, refRadius: Double,
                                 u1: Double, u2: Double, v1: Double, v2: Double) -> Surface? {
        guard let ref = OCCTConvertConeToBSplineSurface(origin.x, origin.y, origin.z,
                                                          axis.x, axis.y, axis.z,
                                                          semiAngle, refRadius,
                                                          u1, u2, v1, v2) else { return nil }
        return Surface(handle: ref)
    }

    /// Convert a full torus to a BSpline surface.
    public static func fromTorus(origin: SIMD3<Double>, axis: SIMD3<Double>,
                                  majorRadius: Double, minorRadius: Double) -> Surface? {
        guard let ref = OCCTConvertTorusToBSplineSurface(origin.x, origin.y, origin.z,
                                                           axis.x, axis.y, axis.z,
                                                           majorRadius, minorRadius) else { return nil }
        return Surface(handle: ref)
    }
}

// MARK: - math_Householder (v0.95.0)

/// Householder QR least-squares solver.
public enum MathHouseholder {

    /// Solve overdetermined Ax=b using Householder QR (M >= N).
    public static func solve(matrix: [Double], rows: Int, cols: Int, rhs: [Double]) -> [Double]? {
        guard matrix.count == rows * cols, rhs.count == rows, rows >= cols else { return nil }
        var solution = [Double](repeating: 0, count: cols)
        let ok = matrix.withUnsafeBufferPointer { mBuf in
            rhs.withUnsafeBufferPointer { bBuf in
                solution.withUnsafeMutableBufferPointer { xBuf in
                    OCCTMathHouseholderSolve(mBuf.baseAddress!, Int32(rows), Int32(cols),
                                             bBuf.baseAddress!, xBuf.baseAddress!)
                }
            }
        }
        return ok ? solution : nil
    }
}

// MARK: - math_Crout (v0.95.0)

/// Crout LDL^T solver for symmetric systems.
public enum MathCrout {

    /// Solve symmetric Ax=b using Crout decomposition.
    public static func solve(matrix: [Double], rhs: [Double]) -> [Double]? {
        let n = rhs.count
        guard matrix.count == n * n else { return nil }
        var solution = [Double](repeating: 0, count: n)
        let ok = matrix.withUnsafeBufferPointer { mBuf in
            rhs.withUnsafeBufferPointer { bBuf in
                solution.withUnsafeMutableBufferPointer { xBuf in
                    OCCTMathCroutSolve(mBuf.baseAddress!, Int32(n), bBuf.baseAddress!, xBuf.baseAddress!)
                }
            }
        }
        return ok ? solution : nil
    }

    /// Determinant of symmetric matrix via Crout.
    public static func determinant(matrix: [Double], n: Int) -> Double {
        matrix.withUnsafeBufferPointer { buf in
            OCCTMathCroutDeterminant(buf.baseAddress!, Int32(n))
        }
    }
}

// MARK: - ShapeFix_IntersectionTool (v0.95.0)

extension Shape {

    /// Fix intersecting wires on a face of this shape.
    /// - Parameters:
    ///   - faceIndex: Index of the face (0-based)
    ///   - precision: Fix precision
    /// - Returns: true if fixes were applied
    @discardableResult
    public func fixIntersectingWires(faceIndex: Int, precision: Double = 1e-6) -> Bool {
        OCCTShapeFixIntersectingWires(handle, Int32(faceIndex), precision)
    }
}

// MARK: - XCAFDoc_AssemblyItemRef (v0.96.0)

extension Document {

    /// Set an assembly item reference on a label.
    @discardableResult
    public func setAssemblyItemRef(labelId: Int64, itemPath: String) -> Bool {
        OCCTDocumentSetAssemblyItemRef(handle, labelId, itemPath)
    }

    /// Get the assembly item reference path string.
    public func assemblyItemRefPath(labelId: Int64) -> String? {
        guard let ptr = OCCTDocumentGetAssemblyItemRef(handle, labelId) else { return nil }
        defer { OCCTDocumentFreeAssemblyItemRefString(ptr) }
        return String(cString: ptr)
    }

    /// Set subshape index on an assembly item ref.
    @discardableResult
    public func assemblyItemRefSetSubshape(labelId: Int64, index: Int32) -> Bool {
        OCCTDocumentAssemblyItemRefSetSubshape(handle, labelId, index)
    }

    /// Get subshape index. Returns nil if not set.
    public func assemblyItemRefGetSubshape(labelId: Int64) -> Int32? {
        let v = OCCTDocumentAssemblyItemRefGetSubshape(handle, labelId)
        return v >= 0 ? v : nil
    }

    /// Check if assembly item ref has extra reference.
    public func assemblyItemRefHasExtra(labelId: Int64) -> Bool {
        OCCTDocumentAssemblyItemRefHasExtra(handle, labelId)
    }

    /// Clear extra reference from assembly item ref.
    @discardableResult
    public func assemblyItemRefClearExtra(labelId: Int64) -> Bool {
        OCCTDocumentAssemblyItemRefClearExtra(handle, labelId)
    }

    /// Check if assembly item ref is orphan.
    public func assemblyItemRefIsOrphan(labelId: Int64) -> Bool {
        OCCTDocumentAssemblyItemRefIsOrphan(handle, labelId)
    }
}

// MARK: - BRepAlgo_Image (v0.96.0)

/// Shape-to-shape image mapping for tracking shape history.
public final class ShapeImage: @unchecked Sendable {
    let handle: OCCTBRepAlgoImageRef

    public init() { handle = OCCTBRepAlgoImageCreate() }
    deinit { OCCTBRepAlgoImageRelease(handle) }

    /// Set the root shape.
    public func setRoot(_ shape: Shape) { OCCTBRepAlgoImageSetRoot(handle, shape.handle) }

    /// Bind old shape to new shape (replacement).
    public func bind(old: Shape, new: Shape) { OCCTBRepAlgoImageBind(handle, old.handle, new.handle) }

    /// Check if shape has an image.
    public func hasImage(_ shape: Shape) -> Bool { OCCTBRepAlgoImageHasImage(handle, shape.handle) }

    /// Check if shape is an image of another.
    public func isImage(_ shape: Shape) -> Bool { OCCTBRepAlgoImageIsImage(handle, shape.handle) }

    /// Clear all mappings.
    public func clear() { OCCTBRepAlgoImageClear(handle) }
}

// MARK: - OSD_Path (v0.96.0)

/// File path parsing and manipulation utilities.
public enum OSDPath {

    /// Get the filename (without extension) from a path.
    public static func name(_ path: String) -> String? {
        guard let ptr = OCCTOSDPathName(path) else { return nil }
        defer { OCCTOSDPathFreeString(ptr) }
        return String(cString: ptr)
    }

    /// Get the file extension (with dot) from a path.
    public static func fileExtension(_ path: String) -> String? {
        guard let ptr = OCCTOSDPathExtension(path) else { return nil }
        defer { OCCTOSDPathFreeString(ptr) }
        return String(cString: ptr)
    }

    /// Get the directory trek from a path.
    public static func trek(_ path: String) -> String? {
        guard let ptr = OCCTOSDPathTrek(path) else { return nil }
        defer { OCCTOSDPathFreeString(ptr) }
        return String(cString: ptr)
    }

    /// Get the system-formatted path.
    public static func systemName(_ path: String) -> String? {
        guard let ptr = OCCTOSDPathSystemName(path) else { return nil }
        defer { OCCTOSDPathFreeString(ptr) }
        return String(cString: ptr)
    }

    /// Split path into folder and filename.
    public static func folderAndFile(_ path: String) -> (folder: String, file: String)? {
        var folderPtr: UnsafePointer<CChar>?
        var filePtr: UnsafePointer<CChar>?
        OCCTOSDPathFolderAndFile(path, &folderPtr, &filePtr)
        guard let fp = folderPtr, let flp = filePtr else { return nil }
        defer { OCCTOSDPathFreeString(fp); OCCTOSDPathFreeString(flp) }
        return (String(cString: fp), String(cString: flp))
    }

    /// Check if path is valid.
    public static func isValid(_ path: String) -> Bool { OCCTOSDPathIsValid(path) }

    /// Check if path is a Unix path.
    public static func isUnixPath(_ path: String) -> Bool { OCCTOSDPathIsUnixPath(path) }

    /// Check if path is relative.
    public static func isRelative(_ path: String) -> Bool { OCCTOSDPathIsRelative(path) }

    /// Check if path is absolute.
    public static func isAbsolute(_ path: String) -> Bool { OCCTOSDPathIsAbsolute(path) }
}

// MARK: - BRepClass_FClassifier (v0.96.0)

extension Shape {

    /// Classify a 2D point on a face (in UV parameter space).
    /// - Parameters:
    ///   - faceIndex: Face index (0-based)
    ///   - u: U parameter
    ///   - v: V parameter
    ///   - tolerance: Classification tolerance
    /// - Returns: Classification state
    public func classifyPoint2D(faceIndex: Int, u: Double, v: Double, tolerance: Double = 1e-6) -> PointState {
        let raw = OCCTShapeClassifyPoint2D(handle, Int32(faceIndex), u, v, tolerance)
        return PointState(rawValue: raw) ?? .unknown
    }

    /// Build loops (wires) from edges on a face.
    /// - Returns: Number of result wires, or -1 on error
    public func buildLoops(faceIndex: Int) -> Int {
        Int(OCCTShapeBuildLoops(handle, Int32(faceIndex)))
    }

    /// Count boundary edges of a face using BRepGProp_Domain.
    public func faceDomainEdgeCount(faceIndex: Int) -> Int {
        Int(OCCTShapeFaceDomainEdgeCount(handle, Int32(faceIndex)))
    }
}

// MARK: - Bnd_BoundSortBox (v0.97.0)

/// Spatial bounding box sort for fast intersection queries.
public final class BoundSortBox: @unchecked Sendable {
    let handle: OCCTBoundSortBoxRef

    /// Create from an array of bounding boxes (each: [xmin,ymin,zmin,xmax,ymax,zmax]).
    public init(boxes: [[Double]]) {
        let flat = boxes.flatMap { $0 }
        handle = flat.withUnsafeBufferPointer { buf in
            OCCTBoundSortBoxCreate(buf.baseAddress!, Int32(boxes.count))
        }
    }

    deinit { OCCTBoundSortBoxRelease(handle) }

    /// Find indices of boxes that intersect a query box.
    public func compare(xmin: Double, ymin: Double, zmin: Double,
                        xmax: Double, ymax: Double, zmax: Double) -> [Int] {
        var indices = [Int32](repeating: 0, count: 1000)
        let count = indices.withUnsafeMutableBufferPointer { buf in
            OCCTBoundSortBoxCompare(handle, xmin, ymin, zmin, xmax, ymax, zmax, buf.baseAddress!, 1000)
        }
        return Array(indices.prefix(Int(count))).map { Int($0) }
    }
}

// MARK: - TNaming_Naming (v0.97.0)

extension Document {

    /// Insert a TNaming_Naming attribute on a label.
    @discardableResult
    public func insertNaming(labelId: Int64) -> Bool {
        OCCTDocumentInsertNaming(handle, labelId)
    }

    /// Check if a naming attribute is defined on a label.
    public func namingIsDefined(labelId: Int64) -> Bool {
        OCCTDocumentNamingIsDefined(handle, labelId)
    }
}

// MARK: - Precision Constants (v0.97.0)

/// OCCT precision constants.
public enum OCCTPrecision {
    /// Confusion tolerance (1e-7) — general distance tolerance.
    public static var confusion: Double { OCCTPrecisionConfusion() }
    /// Angular tolerance (1e-12) — for direction comparisons.
    public static var angular: Double { OCCTPrecisionAngular() }
    /// Intersection tolerance.
    public static var intersection: Double { OCCTPrecisionIntersection() }
    /// Approximation tolerance.
    public static var approximation: Double { OCCTPrecisionApproximation() }
    /// Infinite value (2e100).
    public static var infinite: Double { OCCTPrecisionInfinite() }
    /// Parametric confusion tolerance.
    public static var pConfusion: Double { OCCTPrecisionPConfusion() }
    /// Check if a value is considered infinite.
    public static func isInfinite(_ value: Double) -> Bool { OCCTPrecisionIsInfinite(value) }
}

// MARK: - IntAna Analytic Intersections (v0.98.0)

/// Analytic intersection algorithms for lines, planes, spheres, tori.
public enum IntAna {

    /// Result of a line-plane or line-sphere intersection.
    public struct ConicQuadResult {
        /// Intersection points.
        public let points: [SIMD3<Double>]
        /// Parameters on the conic for each point.
        public let params: [Double]
        /// Whether the line is parallel to the surface.
        public let isParallel: Bool
    }

    /// Intersect a line with a plane.
    public static func linePlane(lineOrigin: SIMD3<Double>, lineDir: SIMD3<Double>,
                                  planeOrigin: SIMD3<Double>, planeNormal: SIMD3<Double>) -> ConicQuadResult {
        let r = OCCTIntAnaLineQuad(lineOrigin.x, lineOrigin.y, lineOrigin.z,
                                    lineDir.x, lineDir.y, lineDir.z,
                                    planeOrigin.x, planeOrigin.y, planeOrigin.z,
                                    planeNormal.x, planeNormal.y, planeNormal.z)
        var pts: [SIMD3<Double>] = []
        var pars: [Double] = []
        for i in 0..<Int(r.count) {
            pts.append(SIMD3(r.points.0 + Double(i * 3), r.points.1 + Double(i * 3), r.points.2 + Double(i * 3)))
            pars.append(withUnsafePointer(to: r.params) { p in
                p.withMemoryRebound(to: Double.self, capacity: 4) { $0[i] }
            })
        }
        // Re-extract properly using tuple access
        let pointTuple = r.points
        let paramTuple = r.params
        pts = []
        pars = []
        withUnsafePointer(to: pointTuple) { pp in
            pp.withMemoryRebound(to: Double.self, capacity: 12) { ptr in
                withUnsafePointer(to: paramTuple) { parp in
                    parp.withMemoryRebound(to: Double.self, capacity: 4) { parPtr in
                        for i in 0..<Int(r.count) {
                            pts.append(SIMD3(ptr[i*3], ptr[i*3+1], ptr[i*3+2]))
                            pars.append(parPtr[i])
                        }
                    }
                }
            }
        }
        return ConicQuadResult(points: pts, params: pars, isParallel: r.isParallel)
    }

    /// Intersect a line with a sphere.
    public static func lineSphere(lineOrigin: SIMD3<Double>, lineDir: SIMD3<Double>,
                                   sphereCenter: SIMD3<Double>, sphereAxis: SIMD3<Double>,
                                   radius: Double) -> ConicQuadResult {
        let r = OCCTIntAnaLineSphere(lineOrigin.x, lineOrigin.y, lineOrigin.z,
                                      lineDir.x, lineDir.y, lineDir.z,
                                      sphereCenter.x, sphereCenter.y, sphereCenter.z,
                                      sphereAxis.x, sphereAxis.y, sphereAxis.z, radius)
        var pts: [SIMD3<Double>] = []
        var pars: [Double] = []
        withUnsafePointer(to: r.points) { pp in
            pp.withMemoryRebound(to: Double.self, capacity: 12) { ptr in
                withUnsafePointer(to: r.params) { parp in
                    parp.withMemoryRebound(to: Double.self, capacity: 4) { parPtr in
                        for i in 0..<Int(r.count) {
                            pts.append(SIMD3(ptr[i*3], ptr[i*3+1], ptr[i*3+2]))
                            pars.append(parPtr[i])
                        }
                    }
                }
            }
        }
        return ConicQuadResult(points: pts, params: pars, isParallel: r.isParallel)
    }

    /// Result type for quadric-quadric intersection.
    public struct QuadQuadResult {
        /// Number of solutions found.
        public let count: Int
        /// Intersection lines (origin + direction pairs); populated for plane-plane.
        public let lines: [(origin: SIMD3<Double>, direction: SIMD3<Double>)]
        /// Intersection points; populated for plane-sphere circle center etc.
        public let points: [SIMD3<Double>]
    }

    /// Intersect two planes — result is typically a line.
    public static func planePlane(p1Origin: SIMD3<Double>, p1Normal: SIMD3<Double>,
                                   p2Origin: SIMD3<Double>, p2Normal: SIMD3<Double>) -> QuadQuadResult {
        let r = OCCTIntAnaPlanePlane(p1Origin.x, p1Origin.y, p1Origin.z,
                                      p1Normal.x, p1Normal.y, p1Normal.z,
                                      p2Origin.x, p2Origin.y, p2Origin.z,
                                      p2Normal.x, p2Normal.y, p2Normal.z)
        return quadQuadResultFromC(r)
    }

    /// Intersect a plane with a sphere — result is typically a circle.
    public static func planeSphere(planeOrigin: SIMD3<Double>, planeNormal: SIMD3<Double>,
                                    sphereCenter: SIMD3<Double>, sphereAxis: SIMD3<Double>,
                                    radius: Double) -> QuadQuadResult {
        let r = OCCTIntAnaPlaneSphere(planeOrigin.x, planeOrigin.y, planeOrigin.z,
                                       planeNormal.x, planeNormal.y, planeNormal.z,
                                       sphereCenter.x, sphereCenter.y, sphereCenter.z,
                                       sphereAxis.x, sphereAxis.y, sphereAxis.z, radius)
        return quadQuadResultFromC(r)
    }

    private static func quadQuadResultFromC(_ r: OCCTQuadQuadGeoResult) -> QuadQuadResult {
        let n = Int(r.solutionCount)
        var linesOut: [(origin: SIMD3<Double>, direction: SIMD3<Double>)] = []
        var ptsOut: [SIMD3<Double>] = []
        withUnsafePointer(to: r.lines) { lp in
            lp.withMemoryRebound(to: Double.self, capacity: 24) { ld in
                withUnsafePointer(to: r.points) { pp in
                    pp.withMemoryRebound(to: Double.self, capacity: 12) { pd in
                        for i in 0..<min(n, 4) {
                            linesOut.append((SIMD3(ld[i*6], ld[i*6+1], ld[i*6+2]),
                                             SIMD3(ld[i*6+3], ld[i*6+4], ld[i*6+5])))
                            ptsOut.append(SIMD3(pd[i*3], pd[i*3+1], pd[i*3+2]))
                        }
                    }
                }
            }
        }
        return QuadQuadResult(count: n, lines: linesOut, points: ptsOut)
    }

    /// Intersect three planes to find a single point.
    public static func threePlanes(p1Origin: SIMD3<Double>, p1Normal: SIMD3<Double>,
                                    p2Origin: SIMD3<Double>, p2Normal: SIMD3<Double>,
                                    p3Origin: SIMD3<Double>, p3Normal: SIMD3<Double>) -> SIMD3<Double>? {
        var x = 0.0, y = 0.0, z = 0.0
        let ok = OCCTIntAna3Planes(p1Origin.x, p1Origin.y, p1Origin.z, p1Normal.x, p1Normal.y, p1Normal.z,
                                    p2Origin.x, p2Origin.y, p2Origin.z, p2Normal.x, p2Normal.y, p2Normal.z,
                                    p3Origin.x, p3Origin.y, p3Origin.z, p3Normal.x, p3Normal.y, p3Normal.z,
                                    &x, &y, &z)
        return ok ? SIMD3(x, y, z) : nil
    }

    /// Intersect a line with a torus.
    public static func lineTorus(lineOrigin: SIMD3<Double>, lineDir: SIMD3<Double>,
                                  torusCenter: SIMD3<Double>, torusAxis: SIMD3<Double>,
                                  majorRadius: Double, minorRadius: Double) -> [SIMD3<Double>] {
        var buffer = [Double](repeating: 0, count: 12)
        let n = buffer.withUnsafeMutableBufferPointer { buf in
            OCCTIntAnaLineTorus(lineOrigin.x, lineOrigin.y, lineOrigin.z,
                                lineDir.x, lineDir.y, lineDir.z,
                                torusCenter.x, torusCenter.y, torusCenter.z,
                                torusAxis.x, torusAxis.y, torusAxis.z,
                                majorRadius, minorRadius, buf.baseAddress!)
        }
        return (0..<Int(n)).map { i in SIMD3(buffer[i*3], buffer[i*3+1], buffer[i*3+2]) }
    }
}

// MARK: - OSD_Chronometer (v0.98.0)

/// CPU time measurement utilities.
public enum CPUTime {

    /// Get process CPU time (user + system) in seconds.
    public static func processCPU() -> (user: Double, system: Double) {
        var u = 0.0, s = 0.0
        OCCTGetProcessCPU(&u, &s)
        return (u, s)
    }

    /// Get current thread CPU time in seconds.
    public static func threadCPU() -> (user: Double, system: Double) {
        var u = 0.0, s = 0.0
        OCCTGetThreadCPU(&u, &s)
        return (u, s)
    }
}

// MARK: - OSD_Process (v0.98.0)

/// Process information utilities.
public enum ProcessInfo {

    /// Get current process ID.
    public static var processId: Int { Int(OCCTProcessId()) }

    /// Get current username.
    public static var userName: String? {
        guard let ptr = OCCTProcessUserName() else { return nil }
        defer { OCCTProcessFreeString(ptr) }
        return String(cString: ptr)
    }

    /// Get executable path.
    public static var executablePath: String? {
        guard let ptr = OCCTProcessExecutablePath() else { return nil }
        defer { OCCTProcessFreeString(ptr) }
        return String(cString: ptr)
    }

    /// Get executable folder.
    public static var executableFolder: String? {
        guard let ptr = OCCTProcessExecutableFolder() else { return nil }
        defer { OCCTProcessFreeString(ptr) }
        return String(cString: ptr)
    }
}

// MARK: - Draft_Modification (v0.98.0)

extension Shape {

    /// Apply a draft angle modification to a face.
    /// - Parameters:
    ///   - faceIndex: Index of the face to draft
    ///   - direction: Draft direction
    ///   - angle: Draft angle in radians
    ///   - neutralPlaneOrigin: Origin of the neutral plane
    ///   - neutralPlaneNormal: Normal of the neutral plane
    /// - Returns: Modified shape, or nil on failure
    public func draftModification(faceIndex: Int, direction: SIMD3<Double>, angle: Double,
                                   neutralPlaneOrigin: SIMD3<Double>,
                                   neutralPlaneNormal: SIMD3<Double>) -> Shape? {
        guard let ref = OCCTShapeDraftModification(handle, Int32(faceIndex),
                                                     direction.x, direction.y, direction.z, angle,
                                                     neutralPlaneOrigin.x, neutralPlaneOrigin.y, neutralPlaneOrigin.z,
                                                     neutralPlaneNormal.x, neutralPlaneNormal.y, neutralPlaneNormal.z) else {
            return nil
        }
        return Shape(handle: ref)
    }
}

// MARK: - Convert_CompBezierCurvesToBSplineCurve (v0.99.0)

/// Result of converting composite Bezier segments to a BSpline curve (3D).
public struct BezierToBSplineResult {
    public let degree: Int
    public let poles: [SIMD3<Double>]
    public let knots: [Double]
    public let multiplicities: [Int]
}

/// Result of converting composite 2D Bezier segments to a BSpline curve.
public struct BezierToBSpline2dResult {
    public let degree: Int
    public let poles: [SIMD2<Double>]
    public let knots: [Double]
    public let multiplicities: [Int]
}

/// Utilities for converting composite Bezier curves to BSpline form.
public enum CompBezierConverter {

    /// Convert a sequence of connected Bezier segments (3D) to a single BSpline curve.
    /// - Parameters:
    ///   - segments: Each element is an array of control points for one Bezier segment.
    ///               All segments must have the same number of control points.
    /// - Returns: BSpline data, or nil on failure.
    public static func toBSpline(segments: [[SIMD3<Double>]]) -> BezierToBSplineResult? {
        guard !segments.isEmpty,
              let ptsPerSeg = segments.first?.count, ptsPerSeg > 0,
              segments.allSatisfy({ $0.count == ptsPerSeg }) else { return nil }

        var flat = [Double]()
        flat.reserveCapacity(segments.count * ptsPerSeg * 3)
        for seg in segments {
            for pt in seg { flat += [pt.x, pt.y, pt.z] }
        }

        var raw = OCCTBezierBSplineResult()
        let ok = flat.withUnsafeBufferPointer { buf in
            OCCTConvertCompBezierToBSpline(buf.baseAddress!, Int32(segments.count),
                                           Int32(ptsPerSeg), &raw)
        }
        guard ok else { return nil }

        let nb = Int(raw.nbPoles)
        let nk = Int(raw.nbKnots)

        var poles = [SIMD3<Double>]()
        poles.reserveCapacity(nb)
        withUnsafeBytes(of: raw.poles) { ptr in
            let dbl = ptr.bindMemory(to: Double.self)
            for i in 0..<nb {
                poles.append(SIMD3(dbl[i * 3], dbl[i * 3 + 1], dbl[i * 3 + 2]))
            }
        }

        var knots = [Double]()
        var mults = [Int]()
        knots.reserveCapacity(nk)
        mults.reserveCapacity(nk)
        withUnsafeBytes(of: raw.knots) { kptr in
            withUnsafeBytes(of: raw.mults) { mptr in
                let kd = kptr.bindMemory(to: Double.self)
                let mi = mptr.bindMemory(to: Int32.self)
                for i in 0..<nk {
                    knots.append(kd[i])
                    mults.append(Int(mi[i]))
                }
            }
        }

        return BezierToBSplineResult(degree: Int(raw.degree), poles: poles,
                                     knots: knots, multiplicities: mults)
    }

    /// Convert a sequence of connected 2D Bezier segments to a single BSpline curve.
    /// - Parameters:
    ///   - segments: Each element is an array of 2D control points for one Bezier segment.
    ///               All segments must have the same number of control points.
    /// - Returns: BSpline 2D data, or nil on failure.
    public static func toBSpline2d(segments: [[SIMD2<Double>]]) -> BezierToBSpline2dResult? {
        guard !segments.isEmpty,
              let ptsPerSeg = segments.first?.count, ptsPerSeg > 0,
              segments.allSatisfy({ $0.count == ptsPerSeg }) else { return nil }

        var flat = [Double]()
        flat.reserveCapacity(segments.count * ptsPerSeg * 2)
        for seg in segments {
            for pt in seg { flat += [pt.x, pt.y] }
        }

        var raw = OCCTBezierBSpline2dResult()
        let ok = flat.withUnsafeBufferPointer { buf in
            OCCTConvertCompBezier2dToBSpline2d(buf.baseAddress!, Int32(segments.count),
                                               Int32(ptsPerSeg), &raw)
        }
        guard ok else { return nil }

        let nb = Int(raw.nbPoles)
        let nk = Int(raw.nbKnots)

        var poles = [SIMD2<Double>]()
        poles.reserveCapacity(nb)
        withUnsafeBytes(of: raw.poles) { ptr in
            let dbl = ptr.bindMemory(to: Double.self)
            for i in 0..<nb {
                poles.append(SIMD2(dbl[i * 2], dbl[i * 2 + 1]))
            }
        }

        var knots = [Double]()
        var mults = [Int]()
        knots.reserveCapacity(nk)
        mults.reserveCapacity(nk)
        withUnsafeBytes(of: raw.knots) { kptr in
            withUnsafeBytes(of: raw.mults) { mptr in
                let kd = kptr.bindMemory(to: Double.self)
                let mi = mptr.bindMemory(to: Int32.self)
                for i in 0..<nk {
                    knots.append(kd[i])
                    mults.append(Int(mi[i]))
                }
            }
        }

        return BezierToBSpline2dResult(degree: Int(raw.degree), poles: poles,
                                       knots: knots, multiplicities: mults)
    }
}

// MARK: - Geom_OffsetSurface Extensions (v0.99.0)

extension Surface {

    /// Get the offset distance of this surface (only valid if it is an offset surface).
    public var offsetValue: Double {
        OCCTSurfaceOffsetValue(handle)
    }

    /// Set the offset distance of this surface (only has effect on offset surfaces).
    public func setOffsetValue(_ value: Double) {
        OCCTSurfaceSetOffsetValue(handle, value)
    }

    /// Get the basis (underlying) surface of an offset surface.
    /// Returns nil if this surface is not an offset surface.
    public var offsetBasis: Surface? {
        guard let ref = OCCTSurfaceOffsetBasis(handle) else { return nil }
        return Surface(handle: ref)
    }
}

// MARK: - OSD_File (v0.99.0)

/// A wrapper around OCCT's OSD_File for platform-independent file I/O.
public final class OSDFile {

    @usableFromInline let handle: OCCTOSDFileRef

    /// Create a file object for the given file-system path.
    public init(path: String) {
        handle = OCCTFileCreate(path)
    }

    /// Create a file object for a URL's file path.
    public init(url: URL) {
        handle = OCCTFileCreate(url.path)
    }

    /// Create a temporary file (path chosen by OCCT).
    public init() {
        handle = OCCTFileCreateTemporary()
    }

    deinit {
        OCCTFileRelease(handle)
    }

    /// Build (create/truncate) the file and open it for reading and writing.
    /// - Returns: true on success.
    @discardableResult
    public func open() -> Bool {
        OCCTFileOpen(handle)
    }

    /// Open an existing file for reading only.
    /// - Returns: true on success.
    @discardableResult
    public func openReadOnly() -> Bool {
        OCCTFileOpenReadOnly(handle)
    }

    /// Write a string to the file.
    /// - Returns: true on success.
    @discardableResult
    public func write(_ string: String) -> Bool {
        string.withCString { ptr in
            OCCTFileWrite(handle, ptr, Int32(string.utf8.count))
        }
    }

    /// Write raw bytes to the file.
    /// - Returns: true on success.
    @discardableResult
    public func write(_ bytes: [UInt8]) -> Bool {
        bytes.withUnsafeBufferPointer { buf in
            buf.baseAddress.map { OCCTFileWrite(handle, $0, Int32(bytes.count)) } ?? false
        }
    }

    /// Read one line from the file.
    /// - Parameter bufSize: Maximum line length to read.
    /// - Returns: The line string, or nil at EOF or on error.
    public func readLine(bufSize: Int = 4096) -> String? {
        guard let ptr = OCCTFileReadLine(handle, Int32(bufSize)) else { return nil }
        defer { OCCTFileFreeString(ptr) }
        return String(cString: ptr)
    }

    /// Read the entire remaining content of the file as a string.
    public func readAll() -> String? {
        var length: Int32 = 0
        guard let ptr = OCCTFileReadAll(handle, &length) else { return nil }
        defer { OCCTFileFreeString(ptr) }
        return String(cString: ptr)
    }

    /// Close the file.
    public func close() {
        OCCTFileClose(handle)
    }

    /// Whether the file is currently open.
    public var isOpen: Bool { OCCTFileIsOpen(handle) }

    /// File size in bytes, or nil on error.
    public var fileSize: Int? {
        let sz = OCCTFileSize(handle)
        return sz >= 0 ? Int(sz) : nil
    }

    /// Rewind the file position to the beginning.
    public func rewind() {
        OCCTFileRewind(handle)
    }

    /// Whether the file position is at the end.
    public var isAtEnd: Bool { OCCTFileIsAtEnd(handle) }
}

// MARK: - ShapeFix_Wireframe Extensions (v0.99.0)

extension Shape {

    /// Fix only wire gaps in the shape (no small-edge removal).
    /// - Parameter tolerance: Precision for gap detection.
    /// - Returns: Fixed shape, or nil on failure.
    public func fixWireGaps(tolerance: Double = 1e-7) -> Shape? {
        guard let ref = OCCTShapeFixWireGaps(handle, tolerance) else { return nil }
        return Shape(handle: ref)
    }

    /// Fix only small edges in the shape (no gap repair).
    /// - Parameters:
    ///   - tolerance: Precision for small-edge detection.
    ///   - dropSmall: If true, remove small edges; if false, merge them with neighbours.
    ///   - limitAngle: Maximum tangent angle for merging (radians). Pass -1 for no limit.
    /// - Returns: Fixed shape, or nil on failure.
    public func fixSmallEdges(tolerance: Double = 1e-7,
                               dropSmall: Bool = false,
                               limitAngle: Double = -1) -> Shape? {
        guard let ref = OCCTShapeFixSmallEdges(handle, tolerance, dropSmall, limitAngle) else {
            return nil
        }
        return Shape(handle: ref)
    }
}

// MARK: - v0.100.0: RWStl, ShapeAnalysis_Curve statics, BRepExtrema_SelfIntersection pairs,
//                    Geom_OffsetCurve basis, APIHeaderSection_MakeHeader, ShapeAnalysis_FreeBounds simplified

// --- RWStl direct binary/ASCII STL I/O ---

extension Shape {

    /// Write this shape's triangulation to a binary STL file.
    /// The shape is meshed automatically with 0.1 deflection.
    /// - Parameter filePath: Output file path.
    /// - Returns: true on success.
    public func writeSTLBinary(to filePath: String) -> Bool {
        OCCTShapeWriteSTLBinary(handle, filePath)
    }

    /// Write this shape's triangulation to an ASCII STL file.
    /// The shape is meshed automatically with 0.1 deflection.
    /// - Parameter filePath: Output file path.
    /// - Returns: true on success.
    public func writeSTLAscii(to filePath: String) -> Bool {
        OCCTShapeWriteSTLAscii(handle, filePath)
    }

    /// Read an STL file and return as a triangulated shape.
    /// - Parameter filePath: Input STL file path.
    /// - Returns: Shape with triangulation, or nil on failure.
    public static func readSTL(from filePath: String) -> Shape? {
        guard let ref = OCCTShapeReadSTL(filePath) else { return nil }
        return Shape(handle: ref)
    }
}

// --- ShapeAnalysis_Curve static methods ---

extension Curve3D {

    /// Check if this curve is closed within the given precision.
    /// Uses ShapeAnalysis_Curve::IsClosed (static method).
    /// - Parameter precision: Tolerance for closure check.
    /// - Returns: true if the curve endpoints coincide within precision.
    public func isClosedWithPrecision(_ precision: Double) -> Bool {
        OCCTCurve3DIsClosedWithPreci(handle, precision)
    }

    /// Check if this curve is periodic using ShapeAnalysis_Curve::IsPeriodic.
    /// More robust than the basic isPeriodic property.
    public var isPeriodicSA: Bool {
        OCCTCurve3DIsPeriodicSA(handle)
    }

}

// --- BRepExtrema_SelfIntersection face pair reporting ---

extension Shape {

    /// A pair of overlapping face indices detected by self-intersection analysis.
    public struct OverlapPair: Sendable {
        public let faceIndex1: Int
        public let faceIndex2: Int
    }

    /// Detect self-intersecting face pairs in this shape.
    /// The shape is meshed automatically.
    /// - Parameters:
    ///   - tolerance: Overlap tolerance (default: 0.0).
    ///   - maxPairs: Maximum number of pairs to return (default: 100).
    /// - Returns: Array of overlapping face index pairs, empty if none found.
    public func selfIntersectionPairs(tolerance: Double = 0.0,
                                       maxPairs: Int = 100) -> [OverlapPair] {
        var idx1 = [Int32](repeating: 0, count: maxPairs)
        var idx2 = [Int32](repeating: 0, count: maxPairs)
        let count = OCCTShapeSelfIntersectionPairs(handle, tolerance, &idx1, &idx2, Int32(maxPairs))
        guard count > 0 else { return [] }
        return (0..<Int(count)).map {
            OverlapPair(faceIndex1: Int(idx1[$0]), faceIndex2: Int(idx2[$0]))
        }
    }
}

// --- Geom_OffsetCurve basis curve ---

extension Curve3D {

    /// Get the basis curve of this offset curve.
    /// - Returns: The basis curve, or nil if this is not an offset curve.
    public var offsetBasisCurve: Curve3D? {
        guard let ref = OCCTCurve3DOffsetBasis(handle) else { return nil }
        return Curve3D(handle: ref)
    }
}

// --- APIHeaderSection_MakeHeader ---

/// A STEP file header manager for reading and writing header fields
/// (name, timestamp, author, organization, preprocessor version, originating system).
public final class StepHeader: @unchecked Sendable {
    let handle: OCCTStepHeaderRef

    /// Create a STEP header with the given filename.
    public init?(filename: String) {
        guard let ref = OCCTStepHeaderCreate(filename) else { return nil }
        self.handle = ref
    }

    deinit {
        OCCTStepHeaderRelease(handle)
    }

    /// Whether the header is fully defined.
    public var isDone: Bool { OCCTStepHeaderIsDone(handle) }

    /// The file name field.
    public var name: String? {
        get {
            guard let ptr = OCCTStepHeaderGetName(handle) else { return nil }
            defer { free(ptr) }
            return String(cString: ptr)
        }
        set {
            if let v = newValue { OCCTStepHeaderSetName(handle, v) }
        }
    }

    /// The timestamp field.
    public var timeStamp: String? {
        get {
            guard let ptr = OCCTStepHeaderGetTimeStamp(handle) else { return nil }
            defer { free(ptr) }
            return String(cString: ptr)
        }
        set {
            if let v = newValue { OCCTStepHeaderSetTimeStamp(handle, v) }
        }
    }

    /// The first author field.
    public var author: String? {
        get {
            guard let ptr = OCCTStepHeaderGetAuthor(handle) else { return nil }
            defer { free(ptr) }
            return String(cString: ptr)
        }
        set {
            if let v = newValue { OCCTStepHeaderSetAuthor(handle, v) }
        }
    }

    /// The first organization field.
    public var organization: String? {
        get {
            guard let ptr = OCCTStepHeaderGetOrganization(handle) else { return nil }
            defer { free(ptr) }
            return String(cString: ptr)
        }
        set {
            if let v = newValue { OCCTStepHeaderSetOrganization(handle, v) }
        }
    }

    /// The preprocessor version field.
    public var preprocessorVersion: String? {
        get {
            guard let ptr = OCCTStepHeaderGetPreprocessorVersion(handle) else { return nil }
            defer { free(ptr) }
            return String(cString: ptr)
        }
        set {
            if let v = newValue { OCCTStepHeaderSetPreprocessorVersion(handle, v) }
        }
    }

    /// The originating system field.
    public var originatingSystem: String? {
        get {
            guard let ptr = OCCTStepHeaderGetOriginatingSystem(handle) else { return nil }
            defer { free(ptr) }
            return String(cString: ptr)
        }
        set {
            if let v = newValue { OCCTStepHeaderSetOriginatingSystem(handle, v) }
        }
    }
}

// --- ShapeAnalysis_FreeBounds simplified API ---

extension Shape {

    /// Count the number of closed free-boundary wires.
    /// - Parameter tolerance: Sewing tolerance for boundary detection.
    /// - Returns: Number of closed free-boundary wires.
    public func freeBoundsClosedCount(tolerance: Double = 1e-6) -> Int {
        Int(OCCTShapeFreeBoundsClosedCount(handle, tolerance))
    }

    /// Get the compound of closed free-boundary wires.
    /// - Parameter tolerance: Sewing tolerance for boundary detection.
    /// - Returns: Compound shape of closed wires, or nil if none.
    public func freeBoundsClosedWires(tolerance: Double = 1e-6) -> Shape? {
        guard let ref = OCCTShapeFreeBoundsClosed(handle, tolerance) else { return nil }
        return Shape(handle: ref)
    }

    /// Get the compound of open free-boundary wires.
    /// - Parameter tolerance: Sewing tolerance for boundary detection.
    /// - Returns: Compound shape of open wires, or nil if none.
    public func freeBoundsOpenWires(tolerance: Double = 1e-6) -> Shape? {
        guard let ref = OCCTShapeFreeBoundsOpen(handle, tolerance) else { return nil }
        return Shape(handle: ref)
    }
}

// MARK: - Geom_TrimmedCurve (v0.101.0)

extension Curve3D {

    /// Create a trimmed curve from this curve between parameters u1 and u2.
    public func trimmed(u1: Double, u2: Double) -> Curve3D? {
        guard let ref = OCCTCurve3DTrimmed(handle, u1, u2) else { return nil }
        return Curve3D(handle: ref)
    }

    /// Get the basis curve of a trimmed curve (nil if not trimmed).
    public var trimmedBasis: Curve3D? {
        guard let ref = OCCTCurve3DTrimmedBasis(handle) else { return nil }
        return Curve3D(handle: ref)
    }

    /// Change the trim parameters on a trimmed curve.
    @discardableResult
    public func setTrim(u1: Double, u2: Double) -> Bool {
        OCCTCurve3DSetTrim(handle, u1, u2)
    }
}

// MARK: - BRepLib_FindSurface (v0.101.0)

extension Shape {

    /// Find a surface (typically plane) through the edges of this shape.
    public func findSurface(tolerance: Double = -1, onlyPlane: Bool = false) -> Surface? {
        guard let ref = OCCTFindSurface(handle, tolerance, onlyPlane) else { return nil }
        return Surface(handle: ref)
    }

    /// Find surface tolerance reached.
    public func findSurfaceTolerance(tolerance: Double = -1, onlyPlane: Bool = false) -> Double? {
        let tol = OCCTFindSurfaceTolerance(handle, tolerance, onlyPlane)
        return tol >= 0 ? tol : nil
    }

    /// Check if a surface already existed on the shape edges.
    public func findSurfaceExisted(tolerance: Double = -1, onlyPlane: Bool = false) -> Bool {
        OCCTFindSurfaceExisted(handle, tolerance, onlyPlane)
    }
}

// MARK: - ShapeAnalysis_Surface (v0.101.0)

extension Surface {

    /// Project a 3D point onto this surface using ShapeAnalysis_Surface, returning UV parameters and gap.
    /// Unlike `projectPoint(_:)` (GeomAPI), this uses ShapeAnalysis for robust projection.
    public func projectPointUV(_ point: SIMD3<Double>, precision: Double = 1e-6) -> (u: Double, v: Double, gap: Double) {
        var u = 0.0, v = 0.0
        let gap = OCCTSurfaceProjectPointUV(handle, point.x, point.y, point.z, precision, &u, &v)
        return (u, v, gap)
    }

    /// Check if surface has singularities using ShapeAnalysis_Surface at the given precision.
    public func hasSingularitiesSA(precision: Double = 1e-6) -> Bool {
        OCCTSurfaceHasSingularities(handle, precision)
    }

    /// Number of singularities using ShapeAnalysis_Surface.
    public func singularityCountSA(precision: Double = 1e-6) -> Int {
        Int(OCCTSurfaceNbSingularities(handle, precision))
    }

    /// Check if surface is spatially U-closed using ShapeAnalysis_Surface.
    public func isUClosedSA(precision: Double = -1) -> Bool {
        OCCTSurfaceIsUClosedSA(handle, precision)
    }

    /// Check if surface is spatially V-closed using ShapeAnalysis_Surface.
    public func isVClosedSA(precision: Double = -1) -> Bool {
        OCCTSurfaceIsVClosedSA(handle, precision)
    }
}

// MARK: - Resource_Manager (v0.101.0)

/// Configuration key-value store using OCCT Resource_Manager.
public final class ResourceManager: @unchecked Sendable {
    private let ref: OCCTResourceManagerRef

    public init() {
        ref = OCCTResourceManagerCreate()
    }

    deinit {
        OCCTResourceManagerRelease(ref)
    }

    public func setString(_ key: String, value: String) {
        OCCTResourceManagerSetString(ref, key, value)
    }

    public func setInt(_ key: String, value: Int) {
        OCCTResourceManagerSetInt(ref, key, Int32(value))
    }

    public func setReal(_ key: String, value: Double) {
        OCCTResourceManagerSetReal(ref, key, value)
    }

    public func find(_ key: String) -> Bool {
        OCCTResourceManagerFind(ref, key)
    }

    public func string(_ key: String) -> String? {
        guard let ptr = OCCTResourceManagerGetString(ref, key) else { return nil }
        defer { free(UnsafeMutablePointer(mutating: ptr)) }
        return String(cString: ptr)
    }

    public func integer(_ key: String) -> Int {
        Int(OCCTResourceManagerGetInt(ref, key))
    }

    public func real(_ key: String) -> Double {
        OCCTResourceManagerGetReal(ref, key)
    }
}

// MARK: - TopExp Adjacency (v0.102.0)

extension Shape {

    /// Get the first (FORWARD) vertex position of an edge shape.
    public func edgeFirstVertex() -> SIMD3<Double>? {
        var x = 0.0, y = 0.0, z = 0.0
        guard OCCTEdgeFirstVertex(handle, &x, &y, &z) else { return nil }
        return SIMD3(x, y, z)
    }

    /// Get the last (REVERSED) vertex position of an edge shape.
    public func edgeLastVertex() -> SIMD3<Double>? {
        var x = 0.0, y = 0.0, z = 0.0
        guard OCCTEdgeLastVertex(handle, &x, &y, &z) else { return nil }
        return SIMD3(x, y, z)
    }

    /// Get both vertex positions of an edge shape.
    public func edgeVertices() -> (first: SIMD3<Double>, last: SIMD3<Double>)? {
        var x1 = 0.0, y1 = 0.0, z1 = 0.0, x2 = 0.0, y2 = 0.0, z2 = 0.0
        guard OCCTEdgeVertices(handle, &x1, &y1, &z1, &x2, &y2, &z2) else { return nil }
        return (SIMD3(x1, y1, z1), SIMD3(x2, y2, z2))
    }

    /// Get first and last vertex positions of a wire shape. For closed wires, both are the same.
    public func wireVertices() -> (first: SIMD3<Double>, last: SIMD3<Double>)? {
        var x1 = 0.0, y1 = 0.0, z1 = 0.0, x2 = 0.0, y2 = 0.0, z2 = 0.0
        guard OCCTWireVertices(handle, &x1, &y1, &z1, &x2, &y2, &z2) else { return nil }
        return (SIMD3(x1, y1, z1), SIMD3(x2, y2, z2))
    }

    /// Find common vertex between two edge shapes. Returns nil if no shared vertex.
    public func commonVertex(with other: Shape) -> SIMD3<Double>? {
        var x = 0.0, y = 0.0, z = 0.0
        guard OCCTEdgeCommonVertex(handle, other.handle, &x, &y, &z) else { return nil }
        return SIMD3(x, y, z)
    }

    /// Build edge→face adjacency. Returns array where each element is the number of faces sharing that edge.
    public func edgeFaceAdjacency() -> [Int] {
        let count = Int(OCCTEdgeFaceAdjacency(handle, nil))
        guard count > 0 else { return [] }
        var counts = [Int32](repeating: 0, count: count)
        _ = OCCTEdgeFaceAdjacency(handle, &counts)
        return counts.map { Int($0) }
    }

    /// Build vertex→edge adjacency. Returns array where each element is the number of edges sharing that vertex.
    public func vertexEdgeAdjacency() -> [Int] {
        let count = Int(OCCTVertexEdgeAdjacency(handle, nil))
        guard count > 0 else { return [] }
        var counts = [Int32](repeating: 0, count: count)
        _ = OCCTVertexEdgeAdjacency(handle, &counts)
        return counts.map { Int($0) }
    }

    /// Get 1-based face indices adjacent to a specific edge within this shape.
    public func adjacentFaces(forEdge edge: Shape) -> [Int] {
        var indices = [Int32](repeating: 0, count: 64)
        let count = Int(OCCTEdgeAdjacentFaces(handle, edge.handle, &indices, 64))
        return indices.prefix(count).map { Int($0) }
    }

    /// Get 1-based edge indices adjacent to a specific vertex within this shape.
    public func adjacentEdges(forVertex vertex: Shape) -> [Int] {
        var indices = [Int32](repeating: 0, count: 64)
        let count = Int(OCCTVertexAdjacentEdges(handle, vertex.handle, &indices, 64))
        return indices.prefix(count).map { Int($0) }
    }
}

// MARK: - Poly_Connect Mesh Adjacency (v0.102.0)

extension Shape {

    /// Get adjacent triangles for a triangle in a meshed face.
    /// faceIndex and triangleIndex are 1-based. Returns (adj1, adj2, adj3), 0 means no neighbor.
    public func meshTriangleAdjacency(faceIndex: Int, triangleIndex: Int) -> (Int, Int, Int)? {
        var a1: Int32 = 0, a2: Int32 = 0, a3: Int32 = 0
        guard OCCTMeshTriangleAdjacency(handle, Int32(faceIndex), Int32(triangleIndex), &a1, &a2, &a3) else {
            return nil
        }
        return (Int(a1), Int(a2), Int(a3))
    }

    /// Get a triangle index containing a given node. faceIndex and nodeIndex are 1-based.
    public func meshNodeTriangle(faceIndex: Int, nodeIndex: Int) -> Int? {
        let idx = Int(OCCTMeshNodeTriangle(handle, Int32(faceIndex), Int32(nodeIndex)))
        return idx > 0 ? idx : nil
    }

    /// Count triangles sharing a node (triangle fan count).
    public func meshNodeTriangleCount(faceIndex: Int, nodeIndex: Int) -> Int {
        Int(OCCTMeshNodeTriangleCount(handle, Int32(faceIndex), Int32(nodeIndex)))
    }
}

// MARK: - BRepOffset_Analyse Edge Classification (v0.102.0)

extension Shape {

    /// Concavity classification for edges.
    public enum ConcavityType: Int, Sendable {
        case convex = 0
        case concave = 1
        case tangent = 2
        case freeBound = 3
        case other = 4
    }

    /// Analyze edge concavity for all edges. angle is the tangency threshold in radians.
    public func analyseEdgeConcavity(angle: Double = .pi / 6.0) -> [ConcavityType] {
        let count = Int(OCCTAnalyseEdgeConcavity(handle, angle, nil))
        guard count > 0 else { return [] }
        var types = [Int32](repeating: 0, count: count)
        _ = OCCTAnalyseEdgeConcavity(handle, angle, &types)
        return types.map { ConcavityType(rawValue: Int($0)) ?? .other }
    }

    /// Explode shape into groups of faces connected by edges of a given concavity type.
    public func analyseExplode(angle: Double = .pi / 6.0, type: ConcavityType) -> Shape? {
        guard let ref = OCCTAnalyseExplode(handle, angle, Int32(type.rawValue)) else { return nil }
        return Shape(handle: ref)
    }

    /// Count edges of a given concavity type on a specific face.
    public func analyseEdgesOnFace(_ face: Shape, angle: Double = .pi / 6.0, type: ConcavityType) -> Int {
        Int(OCCTAnalyseEdgesOnFace(handle, angle, face.handle, Int32(type.rawValue)))
    }

    /// Count ancestor faces for an edge in offset analysis.
    public func analyseAncestorCount(edge: Shape, angle: Double = .pi / 6.0) -> Int {
        Int(OCCTAnalyseAncestorCount(handle, angle, edge.handle))
    }

    /// Count tangent edges at a vertex along a given edge.
    public func analyseTangentEdgeCount(edge: Shape, vertex: Shape, angle: Double = .pi / 6.0) -> Int {
        Int(OCCTAnalyseTangentEdgeCount(handle, angle, edge.handle, vertex.handle))
    }
}

// MARK: - BRepTools_WireExplorer Extensions (v0.102.0)

extension Shape {

    /// Edge orientation from wire explorer.
    public enum EdgeOrientation: Int, Sendable {
        case forward = 0
        case reversed = 1
        case `internal` = 2
        case external = 3
    }

    /// Get edge orientations within a wire, optionally with face context.
    public func wireEdgeOrientations(face: Shape? = nil) -> [EdgeOrientation] {
        let count = Int(OCCTWireExplorerOrientations(handle, face?.handle, nil))
        guard count > 0 else { return [] }
        var orientations = [Int32](repeating: 0, count: count)
        _ = OCCTWireExplorerOrientations(handle, face?.handle, &orientations)
        return orientations.map { EdgeOrientation(rawValue: Int($0)) ?? .forward }
    }

    /// Get connecting vertex positions from wire explorer (vertex between consecutive edges).
    public func wireExplorerVertices(face: Shape? = nil) -> [SIMD3<Double>] {
        let count = Int(OCCTWireExplorerVertices(handle, face?.handle, nil, nil, nil))
        guard count > 0 else { return [] }
        var xs = [Double](repeating: 0, count: count)
        var ys = [Double](repeating: 0, count: count)
        var zs = [Double](repeating: 0, count: count)
        _ = OCCTWireExplorerVertices(handle, face?.handle, &xs, &ys, &zs)
        return (0..<count).map { SIMD3(xs[$0], ys[$0], zs[$0]) }
    }
}

// MARK: - BndLib Analytic Bounding (v0.104.0)

/// Bounding box result from analytic geometry.
public struct AnalyticBounds: Sendable {
    public let min: SIMD3<Double>
    public let max: SIMD3<Double>
}

/// Compute bounding boxes from analytic geometry primitives.
public enum BndLib {

    /// Bounding box of a line segment.
    public static func line(origin: SIMD3<Double>, direction: SIMD3<Double>,
                             p1: Double, p2: Double, tolerance: Double = 0) -> AnalyticBounds {
        var x0 = 0.0, y0 = 0.0, z0 = 0.0, x1 = 0.0, y1 = 0.0, z1 = 0.0
        OCCTBndLibLine(origin.x, origin.y, origin.z, direction.x, direction.y, direction.z,
                        p1, p2, tolerance, &x0, &y0, &z0, &x1, &y1, &z1)
        return AnalyticBounds(min: SIMD3(x0,y0,z0), max: SIMD3(x1,y1,z1))
    }

    /// Bounding box of a full circle.
    public static func circle(center: SIMD3<Double>, normal: SIMD3<Double>,
                               radius: Double, tolerance: Double = 0) -> AnalyticBounds {
        var x0 = 0.0, y0 = 0.0, z0 = 0.0, x1 = 0.0, y1 = 0.0, z1 = 0.0
        OCCTBndLibCircle(center.x, center.y, center.z, normal.x, normal.y, normal.z,
                          radius, tolerance, &x0, &y0, &z0, &x1, &y1, &z1)
        return AnalyticBounds(min: SIMD3(x0,y0,z0), max: SIMD3(x1,y1,z1))
    }

    /// Bounding box of a sphere.
    public static func sphere(center: SIMD3<Double>, radius: Double, tolerance: Double = 0) -> AnalyticBounds {
        var x0 = 0.0, y0 = 0.0, z0 = 0.0, x1 = 0.0, y1 = 0.0, z1 = 0.0
        OCCTBndLibSphere(center.x, center.y, center.z, radius, tolerance,
                          &x0, &y0, &z0, &x1, &y1, &z1)
        return AnalyticBounds(min: SIMD3(x0,y0,z0), max: SIMD3(x1,y1,z1))
    }

    /// Bounding box of a cylinder patch.
    public static func cylinder(center: SIMD3<Double>, axis: SIMD3<Double>,
                                 radius: Double, vmin: Double, vmax: Double, tolerance: Double = 0) -> AnalyticBounds {
        var x0 = 0.0, y0 = 0.0, z0 = 0.0, x1 = 0.0, y1 = 0.0, z1 = 0.0
        OCCTBndLibCylinder(center.x, center.y, center.z, axis.x, axis.y, axis.z,
                            radius, vmin, vmax, tolerance, &x0, &y0, &z0, &x1, &y1, &z1)
        return AnalyticBounds(min: SIMD3(x0,y0,z0), max: SIMD3(x1,y1,z1))
    }

    /// Bounding box of a torus.
    public static func torus(center: SIMD3<Double>, axis: SIMD3<Double>,
                              majorRadius: Double, minorRadius: Double, tolerance: Double = 0) -> AnalyticBounds {
        var x0 = 0.0, y0 = 0.0, z0 = 0.0, x1 = 0.0, y1 = 0.0, z1 = 0.0
        OCCTBndLibTorus(center.x, center.y, center.z, axis.x, axis.y, axis.z,
                         majorRadius, minorRadius, tolerance, &x0, &y0, &z0, &x1, &y1, &z1)
        return AnalyticBounds(min: SIMD3(x0,y0,z0), max: SIMD3(x1,y1,z1))
    }

    /// Bounding box of a 3D edge curve.
    public static func edge(_ edge: Shape, tolerance: Double = 0) -> AnalyticBounds {
        var x0 = 0.0, y0 = 0.0, z0 = 0.0, x1 = 0.0, y1 = 0.0, z1 = 0.0
        OCCTBndLibEdge(edge.handle, tolerance, &x0, &y0, &z0, &x1, &y1, &z1)
        return AnalyticBounds(min: SIMD3(x0,y0,z0), max: SIMD3(x1,y1,z1))
    }

    /// Bounding box of a face surface.
    public static func face(_ face: Shape, tolerance: Double = 0) -> AnalyticBounds {
        var x0 = 0.0, y0 = 0.0, z0 = 0.0, x1 = 0.0, y1 = 0.0, z1 = 0.0
        OCCTBndLibFace(face.handle, tolerance, &x0, &y0, &z0, &x1, &y1, &z1)
        return AnalyticBounds(min: SIMD3(x0,y0,z0), max: SIMD3(x1,y1,z1))
    }
}

// MARK: - OSD_Host (v0.104.0)

/// System host information.
public enum HostInfo {
    /// Get the hostname.
    public static var hostName: String? {
        guard let ptr = OCCTHostName() else { return nil }
        defer { free(ptr) }
        return String(cString: ptr)
    }

    /// Get the OS version string.
    public static var systemVersion: String? {
        guard let ptr = OCCTSystemVersion() else { return nil }
        defer { free(ptr) }
        return String(cString: ptr)
    }

    /// Get the internet address.
    public static var internetAddress: String? {
        guard let ptr = OCCTInternetAddress() else { return nil }
        defer { free(ptr) }
        return String(cString: ptr)
    }
}

// MARK: - OSD_PerfMeter (v0.104.0)

/// Performance measurement timer.
public final class PerfMeter: @unchecked Sendable {
    private let ref: OCCTPerfMeterRef

    public init(name: String) {
        ref = OCCTPerfMeterCreate(name)
    }

    deinit { OCCTPerfMeterRelease(ref) }

    public func start() { OCCTPerfMeterStart(ref) }
    public func stop() { OCCTPerfMeterStop(ref) }
    public var elapsed: Double { OCCTPerfMeterElapsed(ref) }
}

// MARK: - GProp Cylinder/Cone (v0.104.0)

extension GeometryProperties {
    /// Cylinder lateral surface area.
    public static func cylinderSurfaceArea(radius: Double, height: Double) -> Double {
        OCCTGPropCylinderSurface(radius, height)
    }

    /// Cylinder volume.
    public static func cylinderVolume(radius: Double, height: Double) -> Double {
        OCCTGPropCylinderVolume(radius, height)
    }

    /// Cone lateral surface area.
    public static func coneSurfaceArea(semiAngle: Double, refRadius: Double, height: Double) -> Double {
        OCCTGPropConeSurface(semiAngle, refRadius, height)
    }

    /// Cone volume.
    public static func coneVolume(semiAngle: Double, refRadius: Double, height: Double) -> Double {
        OCCTGPropConeVolume(semiAngle, refRadius, height)
    }
}

// MARK: - IntAna_IntQuadQuad (v0.104.0)

/// Analytic quadric-quadric intersection.
public enum QuadricIntersection {
    /// Intersect a cylinder (Z-axis, given radius) with a sphere. Returns curve count, or nil on failure.
    public static func cylinderSphere(cylinderRadius: Double,
                                       sphereCenter: SIMD3<Double>, sphereRadius: Double,
                                       tolerance: Double = 1e-6) -> Int? {
        let n = Int(OCCTIntAnaCylinderSphere(cylinderRadius,
                                               sphereCenter.x, sphereCenter.y, sphereCenter.z,
                                               sphereRadius, tolerance))
        return n >= 0 ? n : nil
    }

    /// Check if cylinder and sphere surfaces are identical.
    public static func cylinderSphereIdentical(cylinderRadius: Double,
                                                sphereCenter: SIMD3<Double>, sphereRadius: Double,
                                                tolerance: Double = 1e-6) -> Bool {
        OCCTIntAnaCylinderSphereIdentical(cylinderRadius,
                                            sphereCenter.x, sphereCenter.y, sphereCenter.z,
                                            sphereRadius, tolerance)
    }
}

// MARK: - XCAFPrs_DocumentExplorer (v0.104.0)

extension Document {
    /// Count leaf shape nodes in the document.
    public var explorerNodeCount: Int {
        Int(OCCTDocumentExplorerCount(handle))
    }

    /// Get shape at index from document explorer (0-based).
    public func explorerShape(at index: Int) -> Shape? {
        guard let ref = OCCTDocumentExplorerShape(handle, Int32(index)) else { return nil }
        return Shape(handle: ref)
    }

    /// Get path ID at index from document explorer.
    public func explorerPathId(at index: Int) -> String? {
        guard let ptr = OCCTDocumentExplorerPathId(handle, Int32(index)) else { return nil }
        defer { free(ptr) }
        return String(cString: ptr)
    }

    /// Find shape from path ID string.
    public func explorerFindShape(pathId: String) -> Shape? {
        guard let ref = OCCTDocumentExplorerFindShape(handle, pathId) else { return nil }
        return Shape(handle: ref)
    }
}

// MARK: - gce Transform Factories (v0.103.0)

/// 3D transformation matrix (row-major 3x4) from gce factories.
public struct TransformMatrix3D: Sendable {
    public let values: [Double] // 12 elements: row-major 3x4

    /// Apply this transform to a 3D point.
    public func apply(to point: SIMD3<Double>) -> SIMD3<Double> {
        let x = values[0]*point.x + values[1]*point.y + values[2]*point.z + values[3]
        let y = values[4]*point.x + values[5]*point.y + values[6]*point.z + values[7]
        let z = values[8]*point.x + values[9]*point.y + values[10]*point.z + values[11]
        return SIMD3(x, y, z)
    }
}

/// 2D transformation matrix (row-major 2x3) from gce factories.
public struct TransformMatrix2D: Sendable {
    public let values: [Double] // 6 elements: row-major 2x3

    /// Apply this transform to a 2D point.
    public func apply(to point: SIMD2<Double>) -> SIMD2<Double> {
        let x = values[0]*point.x + values[1]*point.y + values[2]
        let y = values[3]*point.x + values[4]*point.y + values[5]
        return SIMD2(x, y)
    }
}

/// Factory methods for creating 3D transformation matrices.
public enum TransformFactory3D {

    /// Mirror about a point (central symmetry).
    public static func mirrorPoint(_ point: SIMD3<Double>) -> TransformMatrix3D {
        var m = [Double](repeating: 0, count: 12)
        OCCTMakeMirrorPoint(point.x, point.y, point.z, &m)
        return TransformMatrix3D(values: m)
    }

    /// Mirror about an axis (line).
    public static func mirrorAxis(point: SIMD3<Double>, direction: SIMD3<Double>) -> TransformMatrix3D {
        var m = [Double](repeating: 0, count: 12)
        OCCTMakeMirrorAxis(point.x, point.y, point.z, direction.x, direction.y, direction.z, &m)
        return TransformMatrix3D(values: m)
    }

    /// Mirror about a plane.
    public static func mirrorPlane(point: SIMD3<Double>, normal: SIMD3<Double>) -> TransformMatrix3D {
        var m = [Double](repeating: 0, count: 12)
        OCCTMakeMirrorPlane(point.x, point.y, point.z, normal.x, normal.y, normal.z, &m)
        return TransformMatrix3D(values: m)
    }

    /// Rotation about an axis by angle (radians).
    public static func rotation(point: SIMD3<Double>, direction: SIMD3<Double>, angle: Double) -> TransformMatrix3D {
        var m = [Double](repeating: 0, count: 12)
        OCCTMakeRotation(point.x, point.y, point.z, direction.x, direction.y, direction.z, angle, &m)
        return TransformMatrix3D(values: m)
    }

    /// Uniform scale about a point.
    public static func scale(center: SIMD3<Double>, factor: Double) -> TransformMatrix3D {
        var m = [Double](repeating: 0, count: 12)
        OCCTMakeScaleTransform(center.x, center.y, center.z, factor, &m)
        return TransformMatrix3D(values: m)
    }

    /// Translation by a vector.
    public static func translation(_ vector: SIMD3<Double>) -> TransformMatrix3D {
        var m = [Double](repeating: 0, count: 12)
        OCCTMakeTranslationVec(vector.x, vector.y, vector.z, &m)
        return TransformMatrix3D(values: m)
    }

    /// Translation from one point to another.
    public static func translation(from p1: SIMD3<Double>, to p2: SIMD3<Double>) -> TransformMatrix3D {
        var m = [Double](repeating: 0, count: 12)
        OCCTMakeTranslationPoints(p1.x, p1.y, p1.z, p2.x, p2.y, p2.z, &m)
        return TransformMatrix3D(values: m)
    }
}

/// Factory methods for creating 2D transformation matrices.
public enum TransformFactory2D {

    /// Mirror about a point.
    public static func mirrorPoint(_ point: SIMD2<Double>) -> TransformMatrix2D {
        var m = [Double](repeating: 0, count: 6)
        OCCTMakeMirror2dPoint(point.x, point.y, &m)
        return TransformMatrix2D(values: m)
    }

    /// Mirror about an axis.
    public static func mirrorAxis(point: SIMD2<Double>, direction: SIMD2<Double>) -> TransformMatrix2D {
        var m = [Double](repeating: 0, count: 6)
        OCCTMakeMirror2dAxis(point.x, point.y, direction.x, direction.y, &m)
        return TransformMatrix2D(values: m)
    }

    /// Rotation about a point by angle (radians).
    public static func rotation(center: SIMD2<Double>, angle: Double) -> TransformMatrix2D {
        var m = [Double](repeating: 0, count: 6)
        OCCTMakeRotation2d(center.x, center.y, angle, &m)
        return TransformMatrix2D(values: m)
    }

    /// Uniform scale about a point.
    public static func scale(center: SIMD2<Double>, factor: Double) -> TransformMatrix2D {
        var m = [Double](repeating: 0, count: 6)
        OCCTMakeScale2d(center.x, center.y, factor, &m)
        return TransformMatrix2D(values: m)
    }

    /// Translation by a vector.
    public static func translation(_ vector: SIMD2<Double>) -> TransformMatrix2D {
        var m = [Double](repeating: 0, count: 6)
        OCCTMakeTranslation2dVec(vector.x, vector.y, &m)
        return TransformMatrix2D(values: m)
    }

    /// Translation from one point to another.
    public static func translation(from p1: SIMD2<Double>, to p2: SIMD2<Double>) -> TransformMatrix2D {
        var m = [Double](repeating: 0, count: 6)
        OCCTMakeTranslation2dPoints(p1.x, p1.y, p2.x, p2.y, &m)
        return TransformMatrix2D(values: m)
    }

    /// Create a 2D direction from coordinates. Returns nil if zero vector.
    public static func direction(x: Double, y: Double) -> SIMD2<Double>? {
        var ox = 0.0, oy = 0.0
        guard OCCTMakeDir2d(x, y, &ox, &oy) else { return nil }
        return SIMD2(ox, oy)
    }

    /// Create a 2D direction from two points. Returns nil if coincident.
    public static func direction(from p1: SIMD2<Double>, to p2: SIMD2<Double>) -> SIMD2<Double>? {
        var ox = 0.0, oy = 0.0
        guard OCCTMakeDir2dFromPoints(p1.x, p1.y, p2.x, p2.y, &ox, &oy) else { return nil }
        return SIMD2(ox, oy)
    }
}

// MARK: - GProp Element Properties (v0.103.0)

/// Analytical geometry property computation.
public enum GeometryProperties {

    /// Line segment properties: returns (length, centerOfMass).
    public static func lineSegment(from p1: SIMD3<Double>, to p2: SIMD3<Double>) -> (length: Double, center: SIMD3<Double>) {
        var cx = 0.0, cy = 0.0, cz = 0.0
        let mass = OCCTGPropLineSegment(p1.x, p1.y, p1.z, p2.x, p2.y, p2.z, &cx, &cy, &cz)
        return (mass, SIMD3(cx, cy, cz))
    }

    /// Circular arc properties: returns (arcLength, centerOfMass).
    public static func circularArc(center: SIMD3<Double>, normal: SIMD3<Double>,
                                    radius: Double, u1: Double, u2: Double) -> (arcLength: Double, center: SIMD3<Double>) {
        var cx = 0.0, cy = 0.0, cz = 0.0
        let mass = OCCTGPropCircularArc(center.x, center.y, center.z,
                                         normal.x, normal.y, normal.z,
                                         radius, u1, u2, &cx, &cy, &cz)
        return (mass, SIMD3(cx, cy, cz))
    }

    /// Point set centroid. Returns (pointCount, centroid).
    public static func pointSetCentroid(_ points: [SIMD3<Double>]) -> (count: Double, centroid: SIMD3<Double>) {
        var flat = [Double]()
        for p in points { flat.append(contentsOf: [p.x, p.y, p.z]) }
        var cx = 0.0, cy = 0.0, cz = 0.0
        let mass = OCCTGPropPointSetCentroid(flat, Int32(points.count), &cx, &cy, &cz)
        return (mass, SIMD3(cx, cy, cz))
    }

    /// Sphere surface area (analytical).
    public static func sphereSurfaceArea(radius: Double) -> Double {
        var cx = 0.0, cy = 0.0, cz = 0.0
        return OCCTGPropSphereSurface(radius, &cx, &cy, &cz)
    }

    /// Sphere volume (analytical).
    public static func sphereVolume(radius: Double) -> Double {
        var cx = 0.0, cy = 0.0, cz = 0.0
        return OCCTGPropSphereVolume(radius, &cx, &cy, &cz)
    }
}

// MARK: - Plate Constraint Extensions (v0.103.0)

extension PlateSolver {
    /// Load a plane constraint at UV point.
    @discardableResult
    public func loadPlaneConstraint(u: Double, v: Double, planePoint: SIMD3<Double>, planeNormal: SIMD3<Double>) -> Bool {
        OCCTPlateLoadPlaneConstraint(handle, u, v,
                                      planePoint.x, planePoint.y, planePoint.z,
                                      planeNormal.x, planeNormal.y, planeNormal.z)
    }

    /// Load a line constraint at UV point.
    @discardableResult
    public func loadLineConstraint(u: Double, v: Double, linePoint: SIMD3<Double>, lineDirection: SIMD3<Double>) -> Bool {
        OCCTPlateLoadLineConstraint(handle, u, v,
                                     linePoint.x, linePoint.y, linePoint.z,
                                     lineDirection.x, lineDirection.y, lineDirection.z)
    }

    /// Load a free G1 continuity constraint at UV point.
    @discardableResult
    public func loadFreeG1Constraint(u: Double, v: Double, du: SIMD3<Double>, dv: SIMD3<Double>) -> Bool {
        OCCTPlateLoadFreeG1Constraint(handle, u, v, du.x, du.y, du.z, dv.x, dv.y, dv.z)
    }
}

// MARK: - Law_Interpolate (v0.103.0)

extension LawFunction {
    /// Create an interpolated law function from values.
    public static func interpolated(values: [Double], parameters: [Double]? = nil, periodic: Bool = false) -> LawFunction? {
        let ref: OCCTLawFunctionRef?
        if let params = parameters {
            ref = params.withUnsafeBufferPointer { paramBuf in
                values.withUnsafeBufferPointer { valBuf in
                    OCCTLawInterpolate(valBuf.baseAddress!, Int32(values.count), paramBuf.baseAddress!, periodic)
                }
            }
        } else {
            ref = values.withUnsafeBufferPointer { valBuf in
                OCCTLawInterpolate(valBuf.baseAddress!, Int32(values.count), nil, periodic)
            }
        }
        guard let r = ref else { return nil }
        return LawFunction(handle: r)
    }
}

// MARK: - Bnd_Sphere (v0.103.0)

/// Bounding sphere for spatial queries.
public final class BoundingSphere: @unchecked Sendable {
    private let ref: OCCTBndSphereRef

    public init(center: SIMD3<Double>, radius: Double) {
        ref = OCCTBndSphereCreate(center.x, center.y, center.z, radius)
    }

    deinit { OCCTBndSphereRelease(ref) }

    public var radius: Double { OCCTBndSphereRadius(ref) }

    public var center: SIMD3<Double> {
        var x = 0.0, y = 0.0, z = 0.0
        OCCTBndSphereCenter(ref, &x, &y, &z)
        return SIMD3(x, y, z)
    }

    /// Distance from sphere center to point.
    public func distance(to point: SIMD3<Double>) -> Double {
        OCCTBndSphereDistance(ref, point.x, point.y, point.z)
    }

    /// Check if point is outside sphere.
    public func isOutside(_ point: SIMD3<Double>) -> Bool {
        OCCTBndSphereIsOut(ref, point.x, point.y, point.z)
    }

    /// Check if another sphere is disjoint.
    public func isOutside(_ other: BoundingSphere) -> Bool {
        OCCTBndSphereIsOutSphere(ref, other.ref)
    }

    /// Merge (expand to contain) another sphere.
    public func add(_ other: BoundingSphere) {
        OCCTBndSphereAdd(ref, other.ref)
    }
}

// MARK: - GC_MakeCircle (v0.105.0)

extension Curve3D {
    /// Create a 3D circle from axis (center + normal) and radius.
    public static func gcCircle(center: SIMD3<Double>, normal: SIMD3<Double>, radius: Double) -> Curve3D? {
        guard let ref = OCCTGCMakeCircle(center.x, center.y, center.z,
                                          normal.x, normal.y, normal.z, radius) else { return nil }
        return Curve3D(handle: ref)
    }

    /// Create a 3D circle through 3 points.
    public static func gcCircle(p1: SIMD3<Double>, p2: SIMD3<Double>, p3: SIMD3<Double>) -> Curve3D? {
        guard let ref = OCCTGCMakeCircle3Points(p1.x, p1.y, p1.z,
                                                  p2.x, p2.y, p2.z,
                                                  p3.x, p3.y, p3.z) else { return nil }
        return Curve3D(handle: ref)
    }

    /// Create a 3D circle from center, normal, and radius (alias).
    public static func gcCircleCenterNormal(center: SIMD3<Double>, normal: SIMD3<Double>, radius: Double) -> Curve3D? {
        guard let ref = OCCTGCMakeCircleCenterNormal(center.x, center.y, center.z,
                                                       normal.x, normal.y, normal.z, radius) else { return nil }
        return Curve3D(handle: ref)
    }

    /// Create a 3D circle parallel to an existing circle at given distance.
    public static func gcCircleParallel(center: SIMD3<Double>, normal: SIMD3<Double>,
                                         radius: Double, distance: Double) -> Curve3D? {
        guard let ref = OCCTGCMakeCircleParallel(center.x, center.y, center.z,
                                                   normal.x, normal.y, normal.z,
                                                   radius, distance) else { return nil }
        return Curve3D(handle: ref)
    }
}

// MARK: - GC_MakeEllipse (v0.105.0)

extension Curve3D {
    /// Create a 3D ellipse from axis and major/minor radii.
    public static func gcEllipse(center: SIMD3<Double>, normal: SIMD3<Double>,
                                  majorRadius: Double, minorRadius: Double) -> Curve3D? {
        guard let ref = OCCTGCMakeEllipse(center.x, center.y, center.z,
                                            normal.x, normal.y, normal.z,
                                            majorRadius, minorRadius) else { return nil }
        return Curve3D(handle: ref)
    }

    /// Create a 3D ellipse from 3 points (S1, S2, center).
    public static func gcEllipse(s1: SIMD3<Double>, s2: SIMD3<Double>, center: SIMD3<Double>) -> Curve3D? {
        guard let ref = OCCTGCMakeEllipse3Points(s1.x, s1.y, s1.z,
                                                    s2.x, s2.y, s2.z,
                                                    center.x, center.y, center.z) else { return nil }
        return Curve3D(handle: ref)
    }

    /// Create a 3D ellipse from full Ax2 (center + normal + X direction) and radii.
    public static func gcEllipse(center: SIMD3<Double>, normal: SIMD3<Double>, xDirection: SIMD3<Double>,
                                  majorRadius: Double, minorRadius: Double) -> Curve3D? {
        guard let ref = OCCTGCMakeEllipseFromElips(center.x, center.y, center.z,
                                                      normal.x, normal.y, normal.z,
                                                      xDirection.x, xDirection.y, xDirection.z,
                                                      majorRadius, minorRadius) else { return nil }
        return Curve3D(handle: ref)
    }
}

// MARK: - GC_MakeHyperbola (v0.105.0)

extension Curve3D {
    /// Create a 3D hyperbola from axis and major/minor radii.
    public static func gcHyperbola(center: SIMD3<Double>, normal: SIMD3<Double>,
                                    majorRadius: Double, minorRadius: Double) -> Curve3D? {
        guard let ref = OCCTGCMakeHyperbola(center.x, center.y, center.z,
                                              normal.x, normal.y, normal.z,
                                              majorRadius, minorRadius) else { return nil }
        return Curve3D(handle: ref)
    }

    /// Create a 3D hyperbola from 3 points (S1, S2, center).
    public static func gcHyperbola(s1: SIMD3<Double>, s2: SIMD3<Double>, center: SIMD3<Double>) -> Curve3D? {
        guard let ref = OCCTGCMakeHyperbola3Points(s1.x, s1.y, s1.z,
                                                      s2.x, s2.y, s2.z,
                                                      center.x, center.y, center.z) else { return nil }
        return Curve3D(handle: ref)
    }
}

// MARK: - GCE2d_MakeCircle (v0.105.0)

extension Curve2D {
    /// Create a 2D circle from center and radius.
    public static func gceCircle(center: SIMD2<Double>, radius: Double) -> Curve2D? {
        guard let ref = OCTGCE2dMakeCircleCenterRadius(center.x, center.y, radius) else { return nil }
        return Curve2D(handle: ref)
    }

    /// Create a 2D circle through 3 points.
    public static func gceCircle(p1: SIMD2<Double>, p2: SIMD2<Double>, p3: SIMD2<Double>) -> Curve2D? {
        guard let ref = OCTGCE2dMakeCircle3Points(p1.x, p1.y, p2.x, p2.y, p3.x, p3.y) else { return nil }
        return Curve2D(handle: ref)
    }

    /// Create a 2D circle from center and point on circle.
    public static func gceCircle(center: SIMD2<Double>, pointOn: SIMD2<Double>) -> Curve2D? {
        guard let ref = OCTGCE2dMakeCircleCenterPoint(center.x, center.y, pointOn.x, pointOn.y) else { return nil }
        return Curve2D(handle: ref)
    }

    /// Create a 2D circle parallel to existing circle at distance.
    public static func gceCircleParallel(center: SIMD2<Double>, direction: SIMD2<Double>,
                                          radius: Double, distance: Double) -> Curve2D? {
        guard let ref = OCTGCE2dMakeCircleParallel(center.x, center.y,
                                                     direction.x, direction.y,
                                                     radius, distance) else { return nil }
        return Curve2D(handle: ref)
    }

    /// Create a 2D circle from axis and radius.
    public static func gceCircle(axisCenter: SIMD2<Double>, axisDirection: SIMD2<Double>,
                                  radius: Double) -> Curve2D? {
        guard let ref = OCTGCE2dMakeCircleAxis(axisCenter.x, axisCenter.y,
                                                 axisDirection.x, axisDirection.y,
                                                 radius) else { return nil }
        return Curve2D(handle: ref)
    }
}

// MARK: - GCE2d_MakeEllipse (v0.105.0)

extension Curve2D {
    /// Create a 2D ellipse from axis and radii.
    public static func gceEllipse(center: SIMD2<Double>, xDirection: SIMD2<Double>,
                                   majorRadius: Double, minorRadius: Double) -> Curve2D? {
        guard let ref = OCTGCE2dMakeEllipse(center.x, center.y,
                                              xDirection.x, xDirection.y,
                                              majorRadius, minorRadius) else { return nil }
        return Curve2D(handle: ref)
    }

    /// Create a 2D ellipse from 3 points (S1, S2, center).
    public static func gceEllipse(s1: SIMD2<Double>, s2: SIMD2<Double>, center: SIMD2<Double>) -> Curve2D? {
        guard let ref = OCTGCE2dMakeEllipse3Points(s1.x, s1.y, s2.x, s2.y,
                                                      center.x, center.y) else { return nil }
        return Curve2D(handle: ref)
    }

    /// Create a 2D ellipse from full Ax22d and radii.
    public static func gceEllipse(center: SIMD2<Double>, xDirection: SIMD2<Double>,
                                   yDirection: SIMD2<Double>,
                                   majorRadius: Double, minorRadius: Double) -> Curve2D? {
        guard let ref = OCTGCE2dMakeEllipseAxis22d(center.x, center.y,
                                                      xDirection.x, xDirection.y,
                                                      yDirection.x, yDirection.y,
                                                      majorRadius, minorRadius) else { return nil }
        return Curve2D(handle: ref)
    }
}

// MARK: - GCE2d_MakeHyperbola (v0.105.0)

extension Curve2D {
    /// Create a 2D hyperbola from axis and radii.
    public static func gceHyperbola(center: SIMD2<Double>, xDirection: SIMD2<Double>,
                                     majorRadius: Double, minorRadius: Double) -> Curve2D? {
        guard let ref = OCTGCE2dMakeHyperbola(center.x, center.y,
                                                xDirection.x, xDirection.y,
                                                majorRadius, minorRadius) else { return nil }
        return Curve2D(handle: ref)
    }

    /// Create a 2D hyperbola from 3 points (S1, S2, center).
    public static func gceHyperbola(s1: SIMD2<Double>, s2: SIMD2<Double>, center: SIMD2<Double>) -> Curve2D? {
        guard let ref = OCTGCE2dMakeHyperbola3Points(s1.x, s1.y, s2.x, s2.y,
                                                        center.x, center.y) else { return nil }
        return Curve2D(handle: ref)
    }
}

// MARK: - GCE2d_MakeParabola (v0.105.0)

extension Curve2D {
    /// Create a 2D parabola from axis and focal distance.
    public static func gceParabola(center: SIMD2<Double>, direction: SIMD2<Double>,
                                    focalDistance: Double) -> Curve2D? {
        guard let ref = OCTGCE2dMakeParabola(center.x, center.y,
                                               direction.x, direction.y, focalDistance) else { return nil }
        return Curve2D(handle: ref)
    }

    /// Create a 2D parabola from directrix and focus.
    public static func gceParabola(directrixPoint: SIMD2<Double>, directrixDirection: SIMD2<Double>,
                                    focus: SIMD2<Double>) -> Curve2D? {
        guard let ref = OCTGCE2dMakeParabolaDirectrixFocus(directrixPoint.x, directrixPoint.y,
                                                             directrixDirection.x, directrixDirection.y,
                                                             focus.x, focus.y) else { return nil }
        return Curve2D(handle: ref)
    }
}

// MARK: - GCPnts_UniformAbscissa (v0.105.0)

extension Shape {
    /// Uniformly sample an edge by point count. Returns parameter values.
    public func uniformAbscissa(pointCount: Int) -> [Double]? {
        let n = Int(OCCTUniformAbscissaByCount(handle, Int32(pointCount), nil))
        guard n > 0 else { return nil }
        var params = [Double](repeating: 0, count: n)
        _ = OCCTUniformAbscissaByCount(handle, Int32(pointCount), &params)
        return params
    }

    /// Uniformly sample an edge by arc distance. Returns parameter values.
    public func uniformAbscissa(distance: Double) -> [Double]? {
        let n = Int(OCCTUniformAbscissaByDistance(handle, distance, nil))
        guard n > 0 else { return nil }
        var params = [Double](repeating: 0, count: n)
        _ = OCCTUniformAbscissaByDistance(handle, distance, &params)
        return params
    }

    /// Uniformly sample an edge by point count within parameter range.
    public func uniformAbscissa(pointCount: Int, u1: Double, u2: Double) -> [Double]? {
        let n = Int(OCCTUniformAbscissaByCountRange(handle, Int32(pointCount), u1, u2, nil))
        guard n > 0 else { return nil }
        var params = [Double](repeating: 0, count: n)
        _ = OCCTUniformAbscissaByCountRange(handle, Int32(pointCount), u1, u2, &params)
        return params
    }

    /// Uniformly sample an edge by arc distance within parameter range.
    public func uniformAbscissa(distance: Double, u1: Double, u2: Double) -> [Double]? {
        let n = Int(OCCTUniformAbscissaByDistanceRange(handle, distance, u1, u2, nil))
        guard n > 0 else { return nil }
        var params = [Double](repeating: 0, count: n)
        _ = OCCTUniformAbscissaByDistanceRange(handle, distance, u1, u2, &params)
        return params
    }
}

// MARK: - GeomConvert_CompCurveToBSplineCurve (v0.105.0)

extension Curve3D {
    /// Concatenate multiple bounded 3D curves into a single BSpline.
    public static func concatenate(_ curves: [Curve3D], tolerance: Double = 1e-4) -> Curve3D? {
        guard !curves.isEmpty else { return nil }
        var handles = curves.map { $0.handle as OCCTCurve3DRef }
        guard let ref = OCCTConcatenateCurves3D(&handles, Int32(curves.count), tolerance) else { return nil }
        return Curve3D(handle: ref)
    }
}

// MARK: - Geom2dConvert_CompCurveToBSplineCurve (v0.105.0)

extension Curve2D {
    /// Concatenate multiple bounded 2D curves into a single BSpline.
    public static func concatenate(_ curves: [Curve2D], tolerance: Double = 1e-4) -> Curve2D? {
        guard !curves.isEmpty else { return nil }
        var handles = curves.map { $0.handle as OCCTCurve2DRef }
        guard let ref = OCCTConcatenateCurves2D(&handles, Int32(curves.count), tolerance) else { return nil }
        return Curve2D(handle: ref)
    }
}

// MARK: - GeomConvert_BSplineSurfaceKnotSplitting (v0.105.0)

extension Surface {
    /// Get number of U-direction knot splits for a BSpline surface at given continuity.
    public func bsplineKnotSplitsU(continuity: Int) -> Int {
        Int(OCCTBSplineSurfaceKnotSplitsU(handle, Int32(continuity)))
    }

    /// Get number of V-direction knot splits for a BSpline surface at given continuity.
    public func bsplineKnotSplitsV(continuity: Int) -> Int {
        Int(OCCTBSplineSurfaceKnotSplitsV(handle, Int32(continuity)))
    }

    /// Get U and V knot split index arrays.
    public func bsplineKnotSplitValues(continuity: Int) -> (uSplits: [Int32], vSplits: [Int32]) {
        let nu = bsplineKnotSplitsU(continuity: continuity)
        let nv = bsplineKnotSplitsV(continuity: continuity)
        var uSplits = [Int32](repeating: 0, count: max(nu, 1))
        var vSplits = [Int32](repeating: 0, count: max(nv, 1))
        OCCTBSplineSurfaceKnotSplitValues(handle, Int32(continuity), &uSplits, &vSplits)
        return (Array(uSplits.prefix(nu)), Array(vSplits.prefix(nv)))
    }
}

// MARK: - Geom2dConvert_BSplineCurveKnotSplitting (v0.105.0)

extension Curve2D {
    /// Get number of knot splits for a 2D BSpline curve at given continuity.
    public func bsplineKnotSplits(continuity: Int) -> Int {
        Int(OCCTBSplineCurve2dKnotSplits(handle, Int32(continuity)))
    }

    /// Get knot split indices for a 2D BSpline curve at given continuity.
    public func bsplineKnotSplitValues(continuity: Int) -> [Int32] {
        let n = bsplineKnotSplits(continuity: continuity)
        guard n > 0 else { return [] }
        var splits = [Int32](repeating: 0, count: n)
        OCCTBSplineCurve2dKnotSplitValues(handle, Int32(continuity), &splits)
        return splits
    }
}

// MARK: - BndLib extras (v0.105.0)

extension BndLib {
    /// Bounding box of an ellipse.
    public static func ellipse(center: SIMD3<Double>, normal: SIMD3<Double>, xDirection: SIMD3<Double>,
                                majorRadius: Double, minorRadius: Double, tolerance: Double = 0) -> AnalyticBounds {
        var b = [Double](repeating: 0, count: 6)
        OCCTBndLibEllipse(center.x, center.y, center.z,
                           normal.x, normal.y, normal.z,
                           xDirection.x, xDirection.y, xDirection.z,
                           majorRadius, minorRadius, tolerance, &b)
        return AnalyticBounds(min: SIMD3(b[0], b[1], b[2]), max: SIMD3(b[3], b[4], b[5]))
    }

    /// Bounding box of a cone segment.
    public static func cone(center: SIMD3<Double>, axis: SIMD3<Double>,
                             semiAngle: Double, refRadius: Double,
                             vmin: Double, vmax: Double, tolerance: Double = 0) -> AnalyticBounds {
        var b = [Double](repeating: 0, count: 6)
        OCCTBndLibCone(center.x, center.y, center.z,
                        axis.x, axis.y, axis.z,
                        semiAngle, refRadius, vmin, vmax, tolerance, &b)
        return AnalyticBounds(min: SIMD3(b[0], b[1], b[2]), max: SIMD3(b[3], b[4], b[5]))
    }

    /// Bounding box of a circular arc.
    public static func circleArc(center: SIMD3<Double>, normal: SIMD3<Double>,
                                  radius: Double, u1: Double, u2: Double, tolerance: Double = 0) -> AnalyticBounds {
        var b = [Double](repeating: 0, count: 6)
        OCCTBndLibCircleArc(center.x, center.y, center.z,
                             normal.x, normal.y, normal.z,
                             radius, u1, u2, tolerance, &b)
        return AnalyticBounds(min: SIMD3(b[0], b[1], b[2]), max: SIMD3(b[3], b[4], b[5]))
    }

    /// Bounding box of an ellipse arc.
    public static func ellipseArc(center: SIMD3<Double>, normal: SIMD3<Double>, xDirection: SIMD3<Double>,
                                   majorRadius: Double, minorRadius: Double,
                                   u1: Double, u2: Double, tolerance: Double = 0) -> AnalyticBounds {
        var b = [Double](repeating: 0, count: 6)
        OCCTBndLibEllipseArc(center.x, center.y, center.z,
                              normal.x, normal.y, normal.z,
                              xDirection.x, xDirection.y, xDirection.z,
                              majorRadius, minorRadius, u1, u2, tolerance, &b)
        return AnalyticBounds(min: SIMD3(b[0], b[1], b[2]), max: SIMD3(b[3], b[4], b[5]))
    }

    /// Bounding box of a parabola arc.
    public static func parabolaArc(center: SIMD3<Double>, normal: SIMD3<Double>, xDirection: SIMD3<Double>,
                                    focalDistance: Double,
                                    u1: Double, u2: Double, tolerance: Double = 0) -> AnalyticBounds {
        var b = [Double](repeating: 0, count: 6)
        OCCTBndLibParabolaArc(center.x, center.y, center.z,
                               normal.x, normal.y, normal.z,
                               xDirection.x, xDirection.y, xDirection.z,
                               focalDistance, u1, u2, tolerance, &b)
        return AnalyticBounds(min: SIMD3(b[0], b[1], b[2]), max: SIMD3(b[3], b[4], b[5]))
    }

    /// Bounding box of a hyperbola arc.
    public static func hyperbolaArc(center: SIMD3<Double>, normal: SIMD3<Double>, xDirection: SIMD3<Double>,
                                     majorRadius: Double, minorRadius: Double,
                                     u1: Double, u2: Double, tolerance: Double = 0) -> AnalyticBounds {
        var b = [Double](repeating: 0, count: 6)
        OCCTBndLibHyperbolaArc(center.x, center.y, center.z,
                                normal.x, normal.y, normal.z,
                                xDirection.x, xDirection.y, xDirection.z,
                                majorRadius, minorRadius, u1, u2, tolerance, &b)
        return AnalyticBounds(min: SIMD3(b[0], b[1], b[2]), max: SIMD3(b[3], b[4], b[5]))
    }
}

// MARK: - GProp Torus (v0.105.0)

extension GeometryProperties {
    /// Full torus surface area.
    public static func torusSurfaceArea(majorRadius: Double, minorRadius: Double) -> Double {
        OCCTGPropTorusSurface(majorRadius, minorRadius)
    }

    /// Full torus volume.
    public static func torusVolume(majorRadius: Double, minorRadius: Double) -> Double {
        OCCTGPropTorusVolume(majorRadius, minorRadius)
    }
}

// MARK: - BRepTools_ReShape (v0.105.0)

/// A reshape context for recording and applying shape modifications.
public final class ReShapeContext: @unchecked Sendable {
    private let ref: OCCTReShapeRef

    public init() {
        ref = OCCTReShapeCreate()
    }

    deinit { OCCTReShapeRelease(ref) }

    /// Clear all recorded modifications.
    public func clear() {
        OCCTReShapeClear(ref)
    }

    /// Record removal of a shape.
    public func remove(_ shape: Shape) {
        OCCTReShapeRemove(ref, shape.handle)
    }

    /// Record replacement of a shape.
    public func replace(_ oldShape: Shape, with newShape: Shape) {
        OCCTReShapeReplace(ref, oldShape.handle, newShape.handle)
    }

    /// Check if a shape has been recorded for modification.
    public func isRecorded(_ shape: Shape) -> Bool {
        OCCTReShapeIsRecorded(ref, shape.handle)
    }

    /// Apply all recorded modifications to a shape.
    public func apply(to shape: Shape) -> Shape? {
        guard let h = OCCTReShapeApply(ref, shape.handle) else { return nil }
        return Shape(handle: h)
    }

    /// Get the replacement value for a specific shape.
    public func value(for shape: Shape) -> Shape? {
        guard let h = OCCTReShapeValue(ref, shape.handle) else { return nil }
        return Shape(handle: h)
    }
}

// MARK: - BRepTools_Substitution (v0.105.0)

extension Shape {
    /// Substitute a subshape with a list of new shapes. Pass empty array to remove.
    public func substitute(oldSubShape: Shape, newSubShapes: [Shape]) -> Shape? {
        if newSubShapes.isEmpty {
            return withUnsafePointer(to: Optional<OCCTShapeRef>.none) { _ in
                guard let h = OCCTShapeSubstitute(handle, oldSubShape.handle, nil, 0) else { return nil }
                return Shape(handle: h)
            }
        }
        var handles = newSubShapes.map { $0.handle as OCCTShapeRef? }
        return handles.withUnsafeMutableBufferPointer { buf in
            guard let h = OCCTShapeSubstitute(handle, oldSubShape.handle, buf.baseAddress, Int32(newSubShapes.count)) else {
                return nil
            }
            return Shape(handle: h)
        }
    }

    /// Check if a subshape was copied during substitution.
    public func substitutionIsCopied(subshape: Shape) -> Bool {
        OCCTSubstitutionIsCopied(handle, subshape.handle)
    }
}

// MARK: - BRepLib_MakeVertex (v0.105.0)

extension Shape {
    /// Create a vertex shape at the given point using BRepLib_MakeVertex.
    public static func makeVertex(at point: SIMD3<Double>) -> Shape? {
        guard let ref = OCCTMakeVertex(point.x, point.y, point.z) else { return nil }
        return Shape(handle: ref)
    }
}

// MARK: - BRepFill_PipeShell (v0.105.0)

/// Transition mode for pipe shell construction.
public enum PipeShellTransition: Int32, Sendable {
    case modified = 0
    case right = 1
    case round = 2
}

/// Builder for sweeping a profile along a spine wire with advanced control.
public final class PipeShellBuilder: @unchecked Sendable {
    private let ref: OCCTPipeShellRef

    /// Create a pipe shell builder from a spine wire.
    public init?(spine: Shape) {
        guard let r = OCCTPipeShellCreate(spine.handle) else { return nil }
        ref = r
    }

    deinit { OCCTPipeShellRelease(ref) }

    /// Set Frenet trihedron mode.
    public func setFrenet(_ frenet: Bool = true) {
        OCCTPipeShellSetFrenet(ref, frenet)
    }

    /// Set discrete trihedron mode.
    public func setDiscrete() {
        OCCTPipeShellSetDiscrete(ref)
    }

    /// Set fixed binormal direction.
    public func setFixed(binormal: SIMD3<Double>) {
        OCCTPipeShellSetFixed(ref, binormal.x, binormal.y, binormal.z)
    }

    /// Add a profile (wire or vertex) at the current location.
    public func add(profile: Shape) {
        OCCTPipeShellAdd(ref, profile.handle)
    }

    /// Add a profile at a specific vertex on the spine.
    public func add(profile: Shape, atVertex vertex: Shape) {
        OCCTPipeShellAddAtVertex(ref, profile.handle, vertex.handle)
    }

    /// Set a profile with a scaling law.
    public func setLaw(profile: Shape, law: LawFunction) {
        OCCTPipeShellSetLaw(ref, profile.handle, law.handle)
    }

    /// Set tolerances.
    public func setTolerance(tol3d: Double, boundTol: Double, tolAngular: Double) {
        OCCTPipeShellSetTolerance(ref, tol3d, boundTol, tolAngular)
    }

    /// Set transition mode.
    public func setTransition(_ mode: PipeShellTransition) {
        OCCTPipeShellSetTransition(ref, mode.rawValue)
    }

    /// Build the pipe shell.
    @discardableResult
    public func build() -> Bool {
        OCCTPipeShellBuild(ref)
    }

    /// Get the resulting shape.
    public var shape: Shape? {
        guard let h = OCCTPipeShellShape(ref) else { return nil }
        return Shape(handle: h)
    }

    /// Make the result into a solid.
    @discardableResult
    public func makeSolid() -> Bool {
        OCCTPipeShellMakeSolid(ref)
    }

    /// Get the approximation error.
    public var error: Double {
        OCCTPipeShellError(ref)
    }

    /// Check if the pipe shell is ready to build.
    public var isReady: Bool {
        OCCTPipeShellIsReady(ref)
    }
}

// MARK: - OSD_Directory (v0.105.0)

/// Directory operations using OSD_Directory.
public enum DirectoryUtils {
    /// Check if a directory exists.
    public static func exists(_ path: String) -> Bool {
        OCCTDirectoryExists(path)
    }

    /// Create a directory. Returns true on success.
    @discardableResult
    public static func create(_ path: String) -> Bool {
        OCCTDirectoryCreate(path)
    }

    /// Build a temporary directory. Returns the path.
    public static func buildTemporary() -> String? {
        guard let ptr = OCCTDirectoryBuildTemporary() else { return nil }
        defer { free(ptr) }
        return String(cString: ptr)
    }

    /// Remove a directory. Returns true on success.
    @discardableResult
    public static func remove(_ path: String) -> Bool {
        OCCTDirectoryRemove(path)
    }
}

// MARK: - IntAna Cone-Sphere extensions (v0.105.0)

extension QuadricIntersection {
    /// Intersect a cone (Z-axis, given semi-angle and ref radius) with a sphere.
    /// Returns curve count, or nil on error. Returns -2 encoded as nil for identical.
    public static func coneSphere(semiAngle: Double, refRadius: Double,
                                   sphereCenter: SIMD3<Double>, sphereRadius: Double,
                                   tolerance: Double = 1e-6) -> Int? {
        let n = Int(OCCTIntAnaConeSphere(semiAngle, refRadius,
                                          sphereCenter.x, sphereCenter.y, sphereCenter.z,
                                          sphereRadius, tolerance))
        return n >= 0 ? n : nil
    }

    /// Sample points along a cone-sphere intersection curve.
    public static func coneSpherePoints(semiAngle: Double, refRadius: Double,
                                         sphereCenter: SIMD3<Double>, sphereRadius: Double,
                                         tolerance: Double = 1e-6,
                                         curveIndex: Int, sampleCount: Int) -> [SIMD3<Double>] {
        var xs = [Double](repeating: 0, count: sampleCount)
        var ys = [Double](repeating: 0, count: sampleCount)
        var zs = [Double](repeating: 0, count: sampleCount)
        let actual = Int(OCCTIntAnaConeSpherePoints(semiAngle, refRadius,
                                                      sphereCenter.x, sphereCenter.y, sphereCenter.z,
                                                      sphereRadius, tolerance,
                                                      Int32(curveIndex), Int32(sampleCount),
                                                      &xs, &ys, &zs))
        return (0..<actual).map { SIMD3(xs[$0], ys[$0], zs[$0]) }
    }

    /// Check if a cone-sphere intersection curve is open.
    public static func coneSphereIsOpen(semiAngle: Double, refRadius: Double,
                                         sphereCenter: SIMD3<Double>, sphereRadius: Double,
                                         tolerance: Double = 1e-6, curveIndex: Int) -> Bool {
        OCCTIntAnaConeSphereIsOpen(semiAngle, refRadius,
                                    sphereCenter.x, sphereCenter.y, sphereCenter.z,
                                    sphereRadius, tolerance, Int32(curveIndex))
    }

    /// Get the domain of a cone-sphere intersection curve.
    public static func coneSphereDomain(semiAngle: Double, refRadius: Double,
                                         sphereCenter: SIMD3<Double>, sphereRadius: Double,
                                         tolerance: Double = 1e-6, curveIndex: Int) -> ClosedRange<Double> {
        var first = 0.0, last = 0.0
        OCCTIntAnaConeSphereGetDomain(semiAngle, refRadius,
                                       sphereCenter.x, sphereCenter.y, sphereCenter.z,
                                       sphereRadius, tolerance, Int32(curveIndex),
                                       &first, &last)
        return first...last
    }
}

// MARK: - XCAFPrs_DocumentExplorer extensions (v0.105.0)

extension Document {
    /// Get the depth of a document explorer node at given index.
    public func explorerDepth(at index: Int) -> Int {
        Int(OCCTDocumentExplorerDepth(handle, Int32(index)))
    }

    /// Check if a document explorer node is an assembly.
    public func explorerIsAssembly(at index: Int) -> Bool {
        OCCTDocumentExplorerIsAssembly(handle, Int32(index))
    }

    /// Get the location matrix (12 doubles, row-major 3x4) for a document explorer node.
    public func explorerLocation(at index: Int) -> [Double] {
        var matrix = [Double](repeating: 0, count: 12)
        OCCTDocumentExplorerLocation(handle, Int32(index), &matrix)
        return matrix
    }
}

// MARK: - Resource_Unicode (v0.105.0)

/// Unicode format for Resource_Unicode.
public enum UnicodeFormat: Int32, Sendable {
    case sjis = 0
    case euc = 1
    case gb = 2
    case ansi = 3
}

/// Resource_Unicode utilities.
public enum UnicodeUtils {
    /// Set the global Unicode format.
    public static func setFormat(_ format: UnicodeFormat) {
        OCCTUnicodeSetFormat(format.rawValue)
    }

    /// Get the current Unicode format.
    public static var format: UnicodeFormat {
        UnicodeFormat(rawValue: OCCTUnicodeGetFormat()) ?? .ansi
    }

    /// Convert a string to Unicode (UTF-8 output).
    public static func convertToUnicode(_ input: String) -> String? {
        guard let ptr = OCCTUnicodeConvertToUnicode(input) else { return nil }
        defer { free(ptr) }
        return String(cString: ptr)
    }

    /// Convert from UTF-8 to current format.
    public static func convertFromUnicode(_ utf8Input: String, maxSize: Int = 4096) -> String? {
        var output = [CChar](repeating: 0, count: maxSize)
        guard OCCTUnicodeConvertFromUnicode(utf8Input, &output, Int32(maxSize)) else { return nil }
        let result = output.withUnsafeBufferPointer { buf in
            String(cString: buf.baseAddress!)
        }
        return result
    }
}

// MARK: - GProp weighted point sets (v0.105.0)

extension GeometryProperties {
    /// Compute weighted centroid of a point set. Returns (totalMass, centroid).
    public static func weightedCentroid(points: [SIMD3<Double>], weights: [Double]) -> (mass: Double, centroid: SIMD3<Double>) {
        var flat = [Double]()
        for p in points { flat.append(contentsOf: [p.x, p.y, p.z]) }
        var cx = 0.0, cy = 0.0, cz = 0.0
        let mass = OCCTGPropPointSetWeightedCentroid(flat, weights, Int32(points.count), &cx, &cy, &cz)
        return (mass, SIMD3(cx, cy, cz))
    }

    /// Compute barycentre (equal weights) of a point set.
    public static func barycentre(_ points: [SIMD3<Double>]) -> SIMD3<Double> {
        var flat = [Double]()
        for p in points { flat.append(contentsOf: [p.x, p.y, p.z]) }
        var cx = 0.0, cy = 0.0, cz = 0.0
        OCCTGPropBarycentre(flat, Int32(points.count), &cx, &cy, &cz)
        return SIMD3(cx, cy, cz)
    }
}

// MARK: - Draft info types (v0.105.0)

/// Draft geometry information queries.
public enum DraftInfo {
    /// Check default EdgeInfo new geometry status.
    public static var edgeInfoNewGeometry: Bool {
        OCCTDraftEdgeInfoNewGeometry()
    }

    /// Check default FaceInfo new geometry status.
    public static var faceInfoNewGeometry: Bool {
        OCCTDraftFaceInfoNewGeometry()
    }

    /// Get default VertexInfo geometry point.
    public static var vertexInfoGeometry: SIMD3<Double> {
        var x = 0.0, y = 0.0, z = 0.0
        OCCTDraftVertexInfoGeometry(&x, &y, &z)
        return SIMD3(x, y, z)
    }

    /// Set tangent on an EdgeInfo and check success.
    public static func edgeInfoSetTangent(direction: SIMD3<Double>) -> Bool {
        OCCTDraftEdgeInfoSetTangent(direction.x, direction.y, direction.z)
    }

    /// Create FaceInfo from a surface and check RootFace.
    public static func faceInfoFromSurface(_ surface: Surface) -> Bool {
        OCCTDraftFaceInfoFromSurface(surface.handle)
    }

    /// Add a parameter to VertexInfo and get it back.
    public static func vertexInfoAddParameter(_ param: Double) -> Double {
        OCCTDraftVertexInfoAddParameter(param)
    }
}

// MARK: - GeomLib_LogSample (v0.105.0)

/// Logarithmic sampling utilities.
public enum LogSample {
    /// Compute logarithmically spaced parameter values between a and b.
    public static func sample(from a: Double, to b: Double, count n: Int) -> [Double] {
        guard n > 0 else { return [] }
        var params = [Double](repeating: 0, count: n)
        OCCTLogSample(a, b, Int32(n), &params)
        return params
    }
}

// MARK: - GC_MakeConicalSurface (v0.106.0)

extension Surface {
    /// Create a conical surface from axis (center+normal), semi-angle, and reference radius.
    public static func gcConicalSurface(center: SIMD3<Double>, normal: SIMD3<Double>,
                                         semiAngle: Double, radius: Double) -> Surface? {
        guard let h = OCCTGCMakeConicalSurface(center.x, center.y, center.z,
                                                normal.x, normal.y, normal.z,
                                                semiAngle, radius) else { return nil }
        return Surface(handle: h)
    }

    /// Create a conical surface from 2 points and 2 radii.
    public static func gcConicalSurface2Pts(p1: SIMD3<Double>, p2: SIMD3<Double>,
                                             r1: Double, r2: Double) -> Surface? {
        guard let h = OCCTGCMakeConicalSurface2Pts(p1.x, p1.y, p1.z,
                                                    p2.x, p2.y, p2.z,
                                                    r1, r2) else { return nil }
        return Surface(handle: h)
    }

    /// Create a conical surface from 4 points (2 on each circle).
    public static func gcConicalSurface4Pts(p1: SIMD3<Double>, p2: SIMD3<Double>,
                                             p3: SIMD3<Double>, p4: SIMD3<Double>) -> Surface? {
        guard let h = OCCTGCMakeConicalSurface4Pts(p1.x, p1.y, p1.z,
                                                    p2.x, p2.y, p2.z,
                                                    p3.x, p3.y, p3.z,
                                                    p4.x, p4.y, p4.z) else { return nil }
        return Surface(handle: h)
    }
}

// MARK: - GC_MakeCylindricalSurface (v0.106.0)

extension Surface {
    /// Create a cylindrical surface from axis (center+normal) and radius (GC variant).
    public static func gcCylindricalSurface(center: SIMD3<Double>, normal: SIMD3<Double>,
                                              radius: Double) -> Surface? {
        guard let h = OCCTGCMakeCylindricalSurface(center.x, center.y, center.z,
                                                     normal.x, normal.y, normal.z,
                                                     radius) else { return nil }
        return Surface(handle: h)
    }

    /// Create a cylindrical surface from 3 points (GC variant).
    public static func gcCylindricalSurface3Pts(p1: SIMD3<Double>, p2: SIMD3<Double>,
                                                  p3: SIMD3<Double>) -> Surface? {
        guard let h = OCCTGCMakeCylindricalSurface3Pts(p1.x, p1.y, p1.z,
                                                        p2.x, p2.y, p2.z,
                                                        p3.x, p3.y, p3.z) else { return nil }
        return Surface(handle: h)
    }

    /// Create a cylindrical surface from a circle (center+normal+radius).
    public static func gcCylindricalSurfaceFromCircle(center: SIMD3<Double>, normal: SIMD3<Double>,
                                                       radius: Double) -> Surface? {
        guard let h = OCCTGCMakeCylindricalSurfaceFromCircle(center.x, center.y, center.z,
                                                               normal.x, normal.y, normal.z,
                                                               radius) else { return nil }
        return Surface(handle: h)
    }

    /// Create a cylindrical surface parallel to another at a given distance.
    public static func gcCylindricalSurfaceParallel(center: SIMD3<Double>, normal: SIMD3<Double>,
                                                      radius: Double, distance: Double) -> Surface? {
        guard let h = OCCTGCMakeCylindricalSurfaceParallel(center.x, center.y, center.z,
                                                             normal.x, normal.y, normal.z,
                                                             radius, distance) else { return nil }
        return Surface(handle: h)
    }

    /// Create a cylindrical surface from axis (point+direction) and radius.
    public static func gcCylindricalSurfaceAxis(point: SIMD3<Double>, direction: SIMD3<Double>,
                                                  radius: Double) -> Surface? {
        guard let h = OCCTGCMakeCylindricalSurfaceAxis(point.x, point.y, point.z,
                                                         direction.x, direction.y, direction.z,
                                                         radius) else { return nil }
        return Surface(handle: h)
    }
}

// MARK: - GC_MakeTrimmedCone (v0.106.0)

extension Surface {
    /// Create a trimmed cone from 2 points and 2 radii.
    public static func gcTrimmedCone2Pts(p1: SIMD3<Double>, p2: SIMD3<Double>,
                                          r1: Double, r2: Double) -> Surface? {
        guard let h = OCCTGCMakeTrimmedCone2Pts(p1.x, p1.y, p1.z,
                                                 p2.x, p2.y, p2.z,
                                                 r1, r2) else { return nil }
        return Surface(handle: h)
    }

    /// Create a trimmed cone from 4 points.
    public static func gcTrimmedCone4Pts(p1: SIMD3<Double>, p2: SIMD3<Double>,
                                          p3: SIMD3<Double>, p4: SIMD3<Double>) -> Surface? {
        guard let h = OCCTGCMakeTrimmedCone4Pts(p1.x, p1.y, p1.z,
                                                 p2.x, p2.y, p2.z,
                                                 p3.x, p3.y, p3.z,
                                                 p4.x, p4.y, p4.z) else { return nil }
        return Surface(handle: h)
    }
}

// MARK: - GC_MakeTrimmedCylinder (v0.106.0)

extension Surface {
    /// Create a trimmed cylinder from a circle (center+normal+radius) and height.
    public static func gcTrimmedCylinderCircle(center: SIMD3<Double>, normal: SIMD3<Double>,
                                                radius: Double, height: Double) -> Surface? {
        guard let h = OCCTGCMakeTrimmedCylinderCircle(center.x, center.y, center.z,
                                                       normal.x, normal.y, normal.z,
                                                       radius, height) else { return nil }
        return Surface(handle: h)
    }

    /// Create a trimmed cylinder from axis (point+direction), radius, and height.
    public static func gcTrimmedCylinderAxis(point: SIMD3<Double>, direction: SIMD3<Double>,
                                              radius: Double, height: Double) -> Surface? {
        guard let h = OCCTGCMakeTrimmedCylinderAxis(point.x, point.y, point.z,
                                                     direction.x, direction.y, direction.z,
                                                     radius, height) else { return nil }
        return Surface(handle: h)
    }

    /// Create a trimmed cylinder from 3 points.
    public static func gcTrimmedCylinder3Pts(p1: SIMD3<Double>, p2: SIMD3<Double>,
                                              p3: SIMD3<Double>) -> Surface? {
        guard let h = OCCTGCMakeTrimmedCylinder3Pts(p1.x, p1.y, p1.z,
                                                     p2.x, p2.y, p2.z,
                                                     p3.x, p3.y, p3.z) else { return nil }
        return Surface(handle: h)
    }
}

// MARK: - BRepLib_MakeEdge2d extensions (v0.106.0)

extension Shape {
    /// Create a 2D edge from a full circle.
    public static func edge2dFullCircle(center: SIMD2<Double>, direction: SIMD2<Double>,
                                         radius: Double) -> Shape? {
        guard let h = OCCTMakeEdge2dFullCircle(center.x, center.y,
                                                direction.x, direction.y,
                                                radius) else { return nil }
        return Shape(handle: h)
    }

    /// Create a 2D edge from an ellipse.
    public static func edge2dEllipse(center: SIMD2<Double>, direction: SIMD2<Double>,
                                      majorRadius: Double, minorRadius: Double) -> Shape? {
        guard let h = OCCTMakeEdge2dEllipse(center.x, center.y,
                                             direction.x, direction.y,
                                             majorRadius, minorRadius) else { return nil }
        return Shape(handle: h)
    }

    /// Create a 2D edge from an ellipse arc.
    public static func edge2dEllipseArc(center: SIMD2<Double>, direction: SIMD2<Double>,
                                         majorRadius: Double, minorRadius: Double,
                                         u1: Double, u2: Double) -> Shape? {
        guard let h = OCCTMakeEdge2dEllipseArc(center.x, center.y,
                                                direction.x, direction.y,
                                                majorRadius, minorRadius,
                                                u1, u2) else { return nil }
        return Shape(handle: h)
    }

    /// Create a 2D edge from a Curve2D.
    public static func edge2dFromCurve(_ curve: Curve2D) -> Shape? {
        guard let h = OCCTMakeEdge2dCurve(curve.handle) else { return nil }
        return Shape(handle: h)
    }

    /// Create a 2D edge from a Curve2D with parameter range.
    public static func edge2dFromCurve(_ curve: Curve2D, u1: Double, u2: Double) -> Shape? {
        guard let h = OCCTMakeEdge2dCurveRange(curve.handle, u1, u2) else { return nil }
        return Shape(handle: h)
    }
}

// MARK: - ShapeAnalysis_Wire (v0.106.0)

/// Wire analysis utilities using ShapeAnalysis_Wire (v0.106.0).
public enum SAWireAnalysis {
    /// Check wire edge ordering. Returns true if problem found.
    public static func checkOrder(wire: Shape, face: Shape, precision: Double = 1e-6) -> Bool {
        OCCTWireCheckOrder(wire.handle, face.handle, precision)
    }

    /// Check wire connectivity. Returns true if problem found.
    public static func checkConnected(wire: Shape, face: Shape, precision: Double = 1e-6) -> Bool {
        OCCTWireCheckConnected(wire.handle, face.handle, precision)
    }

    /// Check for small edges. Returns true if problem found.
    public static func checkSmall(wire: Shape, face: Shape, precision: Double = 1e-6) -> Bool {
        OCCTWireCheckSmall(wire.handle, face.handle, precision)
    }

    /// Check for degenerated edges. Returns true if problem found.
    public static func checkDegenerated(wire: Shape, face: Shape, precision: Double = 1e-6) -> Bool {
        OCCTWireCheckDegenerated(wire.handle, face.handle, precision)
    }

    /// Check wire closure. Returns true if problem found.
    public static func checkClosed(wire: Shape, face: Shape, precision: Double = 1e-6) -> Bool {
        OCCTWireCheckClosed(wire.handle, face.handle, precision)
    }

    /// Check for self-intersection. Returns true if problem found.
    public static func checkSelfIntersection(wire: Shape, face: Shape, precision: Double = 1e-6) -> Bool {
        OCCTWireCheckSelfIntersection(wire.handle, face.handle, precision)
    }

    /// Check for 3D gaps. Returns true if problem found.
    public static func checkGaps3d(wire: Shape, face: Shape, precision: Double = 1e-6) -> Bool {
        OCCTWireCheckGaps3d(wire.handle, face.handle, precision)
    }

    /// Check for 2D gaps. Returns true if problem found.
    public static func checkGaps2d(wire: Shape, face: Shape, precision: Double = 1e-6) -> Bool {
        OCCTWireCheckGaps2d(wire.handle, face.handle, precision)
    }

    /// Check edge curves consistency. Returns true if problem found.
    public static func checkEdgeCurves(wire: Shape, face: Shape, precision: Double = 1e-6) -> Bool {
        OCCTWireCheckEdgeCurves(wire.handle, face.handle, precision)
    }

    /// Check for lacking edges. Returns true if problem found.
    public static func checkLacking(wire: Shape, face: Shape, precision: Double = 1e-6) -> Bool {
        OCCTWireCheckLacking(wire.handle, face.handle, precision)
    }

    /// Get the number of edges in a wire on a face.
    public static func edgeCount(wire: Shape, face: Shape, precision: Double = 1e-6) -> Int {
        Int(OCCTWireEdgeCount(wire.handle, face.handle, precision))
    }

    /// Get the minimum 3D distance gap in a wire.
    public static func minDistance3d(wire: Shape, face: Shape, precision: Double = 1e-6) -> Double {
        OCCTWireMinDistance3d(wire.handle, face.handle, precision)
    }

    /// Get the maximum 3D distance gap in a wire.
    public static func maxDistance3d(wire: Shape, face: Shape, precision: Double = 1e-6) -> Double {
        OCCTWireMaxDistance3d(wire.handle, face.handle, precision)
    }

    /// Get the minimum 2D distance gap in a wire.
    public static func minDistance2d(wire: Shape, face: Shape, precision: Double = 1e-6) -> Double {
        OCCTWireMinDistance2d(wire.handle, face.handle, precision)
    }

    /// Get the maximum 2D distance gap in a wire.
    public static func maxDistance2d(wire: Shape, face: Shape, precision: Double = 1e-6) -> Double {
        OCCTWireMaxDistance2d(wire.handle, face.handle, precision)
    }

    /// Check connectivity of a specific edge by index (1-based).
    public static func checkConnectedEdge(wire: Shape, face: Shape, precision: Double = 1e-6,
                                           edgeIndex: Int) -> Bool {
        OCCTWireCheckConnectedEdge(wire.handle, face.handle, precision, Int32(edgeIndex))
    }

    /// Check if a specific edge is small (1-based).
    public static func checkSmallEdge(wire: Shape, face: Shape, precision: Double = 1e-6,
                                       edgeIndex: Int) -> Bool {
        OCCTWireCheckSmallEdge(wire.handle, face.handle, precision, Int32(edgeIndex))
    }

    /// Check if a specific edge is degenerated (1-based).
    public static func checkDegeneratedEdge(wire: Shape, face: Shape, precision: Double = 1e-6,
                                              edgeIndex: Int) -> Bool {
        OCCTWireCheckDegeneratedEdge(wire.handle, face.handle, precision, Int32(edgeIndex))
    }

    /// Check 3D gap at a specific edge (1-based).
    public static func checkGap3dEdge(wire: Shape, face: Shape, precision: Double = 1e-6,
                                       edgeIndex: Int) -> Bool {
        OCCTWireCheckGap3dEdge(wire.handle, face.handle, precision, Int32(edgeIndex))
    }

    /// Check if a face has an outer bound wire.
    public static func checkOuterBound(face: Shape, precision: Double = 1e-6) -> Bool {
        OCCTWireCheckOuterBound(face.handle, precision)
    }
}

// MARK: - ShapeAnalysis_Edge (v0.106.0)

/// Edge analysis utilities using ShapeAnalysis_Edge.
public enum EdgeAnalysis {
    /// Check if an edge has a 3D curve.
    public static func hasCurve3d(_ edge: Shape) -> Bool {
        OCCTEdgeHasCurve3dSA(edge.handle)
    }

    /// Check if an edge is closed in 3D.
    public static func isClosed3d(_ edge: Shape) -> Bool {
        OCCTEdgeIsClosed3dSA(edge.handle)
    }

    /// Check if an edge has a PCurve on a face.
    public static func hasPCurve(_ edge: Shape, face: Shape) -> Bool {
        OCCTEdgeHasPCurveSA(edge.handle, face.handle)
    }

    /// Check if an edge is a seam edge on a face.
    public static func isSeam(_ edge: Shape, face: Shape) -> Bool {
        OCCTEdgeIsSeamSA(edge.handle, face.handle)
    }

    /// Check same parameter consistency. Returns (ok, maxDeviation).
    public static func checkSameParameter(_ edge: Shape) -> (ok: Bool, maxDeviation: Double) {
        var maxdev = 0.0
        let ok = OCCTEdgeCheckSameParameter(edge.handle, &maxdev)
        return (ok, maxdev)
    }

    /// Check vertices with 3D curve positions.
    public static func checkVerticesWithCurve3d(_ edge: Shape, precision: Double = 1e-6) -> Bool {
        OCCTEdgeCheckVerticesWithCurve3d(edge.handle, precision)
    }

    /// Check vertices with PCurve positions on a face.
    public static func checkVerticesWithPCurve(_ edge: Shape, face: Shape,
                                                precision: Double = 1e-6) -> Bool {
        OCCTEdgeCheckVerticesWithPCurve(edge.handle, face.handle, precision)
    }

    /// Check 3D curve vs PCurve consistency on a face.
    public static func checkCurve3dWithPCurve(_ edge: Shape, face: Shape) -> Bool {
        OCCTEdgeCheckCurve3dWithPCurve(edge.handle, face.handle)
    }

    /// Get the first vertex position of an edge.
    public static func firstVertex(_ edge: Shape) -> SIMD3<Double> {
        var x = 0.0, y = 0.0, z = 0.0
        OCCTEdgeFirstVertexSA(edge.handle, &x, &y, &z)
        return SIMD3(x, y, z)
    }

    /// Get the last vertex position of an edge.
    public static func lastVertex(_ edge: Shape) -> SIMD3<Double> {
        var x = 0.0, y = 0.0, z = 0.0
        OCCTEdgeLastVertexSA(edge.handle, &x, &y, &z)
        return SIMD3(x, y, z)
    }

    /// Check vertex tolerances on a face edge. Returns (ok, toler1, toler2).
    public static func checkVertexTolerance(_ edge: Shape, face: Shape) -> (ok: Bool, toler1: Double, toler2: Double) {
        var t1 = 0.0, t2 = 0.0
        let ok = OCCTEdgeCheckVertexTolerance(edge.handle, face.handle, &t1, &t2)
        return (ok, t1, t2)
    }

    /// Check if two edges overlap. Returns (overlapping, tolerance).
    public static func checkOverlapping(_ edge1: Shape, _ edge2: Shape) -> (overlapping: Bool, tolerance: Double) {
        var tol = 0.0
        let ok = OCCTEdgeCheckOverlapping(edge1.handle, edge2.handle, &tol)
        return (ok, tol)
    }

    /// Get UV bounds of an edge on a face.
    public static func boundUV(_ edge: Shape, face: Shape) -> (uFirst: Double, vFirst: Double, uLast: Double, vLast: Double)? {
        var uf = 0.0, vf = 0.0, ul = 0.0, vl = 0.0
        let ok = OCCTEdgeBoundUV(edge.handle, face.handle, &uf, &vf, &ul, &vl)
        if !ok { return nil }
        return (uf, vf, ul, vl)
    }

    /// Get end tangent in 2D for an edge on a face.
    public static func endTangent2d(_ edge: Shape, face: Shape,
                                     atEnd: Bool) -> (point: SIMD2<Double>, tangent: SIMD2<Double>)? {
        var px = 0.0, py = 0.0, tx = 0.0, ty = 0.0
        let ok = OCCTEdgeGetEndTangent2d(edge.handle, face.handle, atEnd, &px, &py, &tx, &ty)
        if !ok { return nil }
        return (SIMD2(px, py), SIMD2(tx, ty))
    }

    /// Check PCurve range on a face.
    public static func checkPCurveRange(_ edge: Shape, face: Shape,
                                         first: Double, last: Double) -> Bool {
        OCCTEdgeCheckPCurveRange(edge.handle, face.handle, first, last)
    }
}

// MARK: - OSD_DirectoryIterator (v0.106.0)

/// Directory iteration utilities using OSD_DirectoryIterator.
public enum DirectoryIterator {
    /// Count directories matching a mask in a path.
    public static func count(path: String, mask: String = "*") -> Int {
        Int(OCCTDirectoryIteratorCount(path, mask))
    }

    /// Get directory name at index from directory listing.
    public static func name(path: String, mask: String = "*", index: Int) -> String? {
        guard let cStr = OCCTDirectoryIteratorName(path, mask, Int32(index)) else { return nil }
        let result = String(cString: cStr)
        free(cStr)
        return result
    }

    /// List directory names matching mask.
    public static func list(path: String, mask: String = "*", maxCount: Int = 1000) -> [String] {
        var names = [UnsafeMutablePointer<CChar>?](repeating: nil, count: maxCount)
        let count = Int(OCCTDirectoryList(path, mask, &names, Int32(maxCount)))
        var result: [String] = []
        for i in 0..<count {
            if let cStr = names[i] {
                result.append(String(cString: cStr))
                free(cStr)
            }
        }
        return result
    }
}

// MARK: - OSD_FileIterator (v0.106.0)

/// File iteration utilities using OSD_FileIterator.
public enum FileIterator {
    /// Count files matching a mask in a path.
    public static func count(path: String, mask: String = "*") -> Int {
        Int(OCCTFileIteratorCount(path, mask))
    }

    /// Get file name at index from file listing.
    public static func name(path: String, mask: String = "*", index: Int) -> String? {
        guard let cStr = OCCTFileIteratorName(path, mask, Int32(index)) else { return nil }
        let result = String(cString: cStr)
        free(cStr)
        return result
    }

    /// List file names matching mask.
    public static func list(path: String, mask: String = "*", maxCount: Int = 1000) -> [String] {
        var names = [UnsafeMutablePointer<CChar>?](repeating: nil, count: maxCount)
        let count = Int(OCCTFileList(path, mask, &names, Int32(maxCount)))
        var result: [String] = []
        for i in 0..<count {
            if let cStr = names[i] {
                result.append(String(cString: cStr))
                free(cStr)
            }
        }
        return result
    }
}

// MARK: - BRepFill_PipeShell extensions (v0.106.0)

extension PipeShellBuilder {
    /// Set maximum degree for pipe shell approximation.
    public func setMaxDegree(_ maxDeg: Int) {
        OCCTPipeShellSetMaxDegree(ref, Int32(maxDeg))
    }

    /// Set maximum number of segments for pipe shell approximation.
    public func setMaxSegments(_ maxSeg: Int) {
        OCCTPipeShellSetMaxSegments(ref, Int32(maxSeg))
    }

    /// Force C1 approximation on pipe shell.
    public func setForceApproxC1(_ force: Bool) {
        OCCTPipeShellSetForceApproxC1(ref, force)
    }

    /// Get the error on the generated surface.
    public var errorOnSurface: Double {
        OCCTPipeShellErrorOnSurface(ref)
    }

    /// Get the first shape of the pipe shell (start cap).
    public var firstShape: Shape? {
        guard let h = OCCTPipeShellFirstShape(ref) else { return nil }
        return Shape(handle: h)
    }

    /// Get the last shape of the pipe shell (end cap).
    public var lastShape: Shape? {
        guard let h = OCCTPipeShellLastShape(ref) else { return nil }
        return Shape(handle: h)
    }
}

// MARK: - Shape topology extensions (v0.106.0)

extension Shape {
    /// Shape orientation values.
    public enum Orientation: Int32, Sendable {
        case forward = 0
        case reversed = 1
        case `internal` = 2
        case external = 3
    }

    /// Get shape orientation.
    public var orientation: Orientation {
        Orientation(rawValue: OCCTShapeGetOrientation(handle)) ?? .forward
    }

    /// Set shape orientation.
    public func setOrientation(_ orient: Orientation) {
        OCCTShapeSetOrientation(handle, orient.rawValue)
    }

    /// Get a reversed copy of the shape.
    public var reversed: Shape? {
        guard let h = OCCTShapeReversed(handle) else { return nil }
        return Shape(handle: h)
    }

    /// Get a complemented copy of the shape (reversed orientation).
    public var complemented: Shape? {
        guard let h = OCCTShapeComplemented(handle) else { return nil }
        return Shape(handle: h)
    }

    /// Compose with another orientation.
    public func composed(with orient: Orientation) -> Shape? {
        guard let h = OCCTShapeComposed(handle, orient.rawValue) else { return nil }
        return Shape(handle: h)
    }

    /// Check if the shape's Free flag is set.
    public var isFree: Bool {
        OCCTShapeIsFree(handle)
    }

    /// Check if the shape's Modified flag is set.
    public var isModified: Bool {
        OCCTShapeIsModified(handle)
    }

    /// Check if the shape's Checked flag is set.
    public var isChecked: Bool {
        OCCTShapeIsChecked(handle)
    }

    /// Check if the shape's Orientable flag is set.
    public var isOrientable: Bool {
        OCCTShapeIsOrientable(handle)
    }

    /// Check if the shape's Infinite flag is set.
    public var isInfinite: Bool {
        OCCTShapeIsInfinite(handle)
    }

    /// Check if the shape's Convex flag is set.
    public var isConvex: Bool {
        OCCTShapeIsConvex(handle)
    }

    /// Check if the shape is empty (null underlying shape).
    public var isEmptyShape: Bool {
        OCCTShapeIsEmpty(handle)
    }

    /// Check if two shapes are partners (same TShape).
    public func isPartner(with other: Shape) -> Bool {
        OCCTShapeIsPartner(handle, other.handle)
    }

    /// Check if two shapes are equal (same TShape + same location + same orientation).
    public func isEqual(to other: Shape) -> Bool {
        OCCTShapeIsEqual(handle, other.handle)
    }

    /// Get the number of direct children sub-shapes.
    public var nbChildren: Int {
        Int(OCCTShapeNbChildren(handle))
    }

    /// Get the hash code of a shape.
    public var hashCode: Int {
        Int(OCCTShapeHashCode(handle))
    }
}

// MARK: - Curve3D continuity (v0.106.0)

extension Curve3D {
    /// Get the global continuity of the 3D curve as an integer (0=C0, 1=C1, 2=C2, 3=C3, 4=CN, 5=G1, 6=G2).
    public var continuity: Int {
        Int(OCCTCurve3DGetContinuity(handle))
    }
}

// MARK: - Curve2D continuity (v0.106.0)

extension Curve2D {
    /// Get the global continuity of the 2D curve as an integer (0=C0, 1=C1, 2=C2, 3=C3, 4=CN, 5=G1, 6=G2).
    public var continuity: Int {
        Int(OCCTCurve2DGetContinuity(handle))
    }
}

// MARK: - Surface continuity (v0.106.0)

extension Surface {
    /// Get the global continuity of the surface as an integer (0=C0, 1=C1, 2=C2, 3=C3, 4=CN, 5=G1, 6=G2).
    public var continuity: Int {
        Int(OCCTSurfaceGetContinuity(handle))
    }

    /// Get number of UV bound spans for the surface.
    public var nBounds: (uSpans: Int, vSpans: Int) {
        var u: Int32 = 0, v: Int32 = 0
        OCCTSurfaceGetNBounds(handle, &u, &v)
        return (Int(u), Int(v))
    }
}

// MARK: - Geom_BSplineCurve Methods (v0.107.0)

extension Curve3D {

    /// BSpline-specific operations. Returns nil values if the curve is not a BSpline.
    public struct BSpline {
        let curve: Curve3D

        /// Number of knots (0 if not a BSpline).
        public var knotCount: Int { Int(OCCTCurve3DBSplineKnotCount(curve.handle)) }

        /// Number of poles/control points (0 if not a BSpline).
        public var poleCount: Int { Int(OCCTCurve3DBSplinePoleCount(curve.handle)) }

        /// Degree (0 if not a BSpline).
        public var degree: Int { Int(OCCTCurve3DBSplineDegree(curve.handle)) }

        /// Whether the BSpline is rational.
        public var isRational: Bool { OCCTCurve3DBSplineIsRational(curve.handle) }

        /// Get all knot values.
        public var knots: [Double] {
            let n = knotCount
            guard n > 0 else { return [] }
            var arr = [Double](repeating: 0, count: n)
            OCCTCurve3DBSplineGetKnots(curve.handle, &arr)
            return arr
        }

        /// Get all knot multiplicities.
        public var multiplicities: [Int] {
            let n = knotCount
            guard n > 0 else { return [] }
            var arr = [Int32](repeating: 0, count: n)
            OCCTCurve3DBSplineGetMults(curve.handle, &arr)
            return arr.map { Int($0) }
        }

        /// Get a pole at 1-based index.
        public func pole(at index: Int) -> SIMD3<Double> {
            var x = 0.0, y = 0.0, z = 0.0
            OCCTCurve3DBSplineGetPole(curve.handle, Int32(index), &x, &y, &z)
            return SIMD3(x, y, z)
        }

        /// Set a pole at 1-based index.
        @discardableResult
        public func setPole(at index: Int, to point: SIMD3<Double>) -> Bool {
            OCCTCurve3DBSplineSetPole(curve.handle, Int32(index), point.x, point.y, point.z)
        }

        /// Get the weight at 1-based index.
        public func weight(at index: Int) -> Double {
            OCCTCurve3DBSplineGetWeight(curve.handle, Int32(index))
        }

        /// Set the weight at 1-based index.
        @discardableResult
        public func setWeight(at index: Int, to weight: Double) -> Bool {
            OCCTCurve3DBSplineSetWeight(curve.handle, Int32(index), weight)
        }

        /// Insert a knot at parameter u with given multiplicity.
        @discardableResult
        public func insertKnot(u: Double, multiplicity: Int = 1, tolerance: Double = 1e-6) -> Bool {
            OCCTCurve3DBSplineInsertKnot(curve.handle, u, Int32(multiplicity), tolerance)
        }

        /// Remove a knot at 1-based index down to given multiplicity.
        @discardableResult
        public func removeKnot(at index: Int, multiplicity: Int, tolerance: Double) -> Bool {
            OCCTCurve3DBSplineRemoveKnot(curve.handle, Int32(index), Int32(multiplicity), tolerance)
        }

        /// Segment the BSpline to [u1, u2].
        @discardableResult
        public func segment(u1: Double, u2: Double) -> Bool {
            OCCTCurve3DBSplineSegment(curve.handle, u1, u2)
        }

        /// Increase the degree to the given value.
        @discardableResult
        public func increaseDegree(to degree: Int) -> Bool {
            OCCTCurve3DBSplineIncreaseDegree(curve.handle, Int32(degree))
        }

        /// Compute parametric resolution for a given 3D tolerance.
        public func resolution(tolerance3d: Double) -> Double {
            OCCTCurve3DBSplineResolution(curve.handle, tolerance3d)
        }

        /// Set periodic or non-periodic.
        @discardableResult
        public func setPeriodic(_ periodic: Bool) -> Bool {
            OCCTCurve3DBSplineSetPeriodic(curve.handle, periodic)
        }
    }

    /// Access BSpline-specific operations. Works only if the underlying curve is a Geom_BSplineCurve.
    public var bspline: BSpline { BSpline(curve: self) }
}

// MARK: - Geom_BSplineSurface Methods (v0.107.0)

extension Surface {

    /// BSpline-specific surface operations.
    public struct BSpline {
        let surface: Surface

        /// Number of U knots.
        public var nbUKnots: Int { Int(OCCTSurfaceBSplineNbUKnots(surface.handle)) }

        /// Number of V knots.
        public var nbVKnots: Int { Int(OCCTSurfaceBSplineNbVKnots(surface.handle)) }

        /// Number of U poles.
        public var nbUPoles: Int { Int(OCCTSurfaceBSplineNbUPoles(surface.handle)) }

        /// Number of V poles.
        public var nbVPoles: Int { Int(OCCTSurfaceBSplineNbVPoles(surface.handle)) }

        /// U degree.
        public var uDegree: Int { Int(OCCTSurfaceBSplineUDegree(surface.handle)) }

        /// V degree.
        public var vDegree: Int { Int(OCCTSurfaceBSplineVDegree(surface.handle)) }

        /// Whether the surface is U-rational.
        public var isURational: Bool { OCCTSurfaceBSplineIsURational(surface.handle) }

        /// Whether the surface is V-rational.
        public var isVRational: Bool { OCCTSurfaceBSplineIsVRational(surface.handle) }

        /// Get a pole at (uIndex, vIndex) — both 1-based.
        public func pole(uIndex: Int, vIndex: Int) -> SIMD3<Double> {
            var x = 0.0, y = 0.0, z = 0.0
            OCCTSurfaceBSplineGetPole(surface.handle, Int32(uIndex), Int32(vIndex), &x, &y, &z)
            return SIMD3(x, y, z)
        }

        /// Set a pole at (uIndex, vIndex) — both 1-based.
        @discardableResult
        public func setPole(uIndex: Int, vIndex: Int, to point: SIMD3<Double>) -> Bool {
            OCCTSurfaceBSplineSetPole(surface.handle, Int32(uIndex), Int32(vIndex), point.x, point.y, point.z)
        }

        /// Set the weight at (uIndex, vIndex).
        @discardableResult
        public func setWeight(uIndex: Int, vIndex: Int, to weight: Double) -> Bool {
            OCCTSurfaceBSplineSetWeight(surface.handle, Int32(uIndex), Int32(vIndex), weight)
        }

        /// Insert a U knot.
        @discardableResult
        public func insertUKnot(u: Double, multiplicity: Int = 1, tolerance: Double = 1e-6) -> Bool {
            OCCTSurfaceBSplineInsertUKnot(surface.handle, u, Int32(multiplicity), tolerance)
        }

        /// Insert a V knot.
        @discardableResult
        public func insertVKnot(v: Double, multiplicity: Int = 1, tolerance: Double = 1e-6) -> Bool {
            OCCTSurfaceBSplineInsertVKnot(surface.handle, v, Int32(multiplicity), tolerance)
        }

        /// Segment the surface to [u1,u2] x [v1,v2].
        @discardableResult
        public func segment(u1: Double, u2: Double, v1: Double, v2: Double) -> Bool {
            OCCTSurfaceBSplineSegment(surface.handle, u1, u2, v1, v2)
        }

        /// Increase the degree to (uDeg, vDeg).
        @discardableResult
        public func increaseDegree(uDeg: Int, vDeg: Int) -> Bool {
            OCCTSurfaceBSplineIncreaseDegree(surface.handle, Int32(uDeg), Int32(vDeg))
        }

        /// Exchange U and V directions.
        @discardableResult
        public func exchangeUV() -> Bool {
            OCCTSurfaceBSplineExchangeUV(surface.handle)
        }
    }

    /// Access BSpline-specific surface operations. Works only if the underlying surface is a Geom_BSplineSurface.
    public var bsplineSurface: BSpline { BSpline(surface: self) }
}

// MARK: - Geom2d_BSplineCurve Methods (v0.107.0)

extension Curve2D {

    /// BSpline-specific 2D curve operations.
    public struct BSpline {
        let curve: Curve2D

        /// Number of knots.
        public var knotCount: Int { Int(OCCTCurve2DBSplineKnotCount(curve.handle)) }

        /// Number of poles.
        public var poleCount: Int { Int(OCCTCurve2DBSplinePoleCount(curve.handle)) }

        /// Degree.
        public var degree: Int { Int(OCCTCurve2DBSplineDegree(curve.handle)) }

        /// Whether rational.
        public var isRational: Bool { OCCTCurve2DBSplineIsRational(curve.handle) }

        /// Get a pole at 1-based index.
        public func pole(at index: Int) -> SIMD2<Double> {
            var x = 0.0, y = 0.0
            OCCTCurve2DBSplineGetPole(curve.handle, Int32(index), &x, &y)
            return SIMD2(x, y)
        }

        /// Set a pole at 1-based index.
        @discardableResult
        public func setPole(at index: Int, to point: SIMD2<Double>) -> Bool {
            OCCTCurve2DBSplineSetPole(curve.handle, Int32(index), point.x, point.y)
        }

        /// Set the weight at 1-based index.
        @discardableResult
        public func setWeight(at index: Int, to weight: Double) -> Bool {
            OCCTCurve2DBSplineSetWeight(curve.handle, Int32(index), weight)
        }

        /// Insert a knot.
        @discardableResult
        public func insertKnot(u: Double, multiplicity: Int = 1, tolerance: Double = 1e-6) -> Bool {
            OCCTCurve2DBSplineInsertKnot(curve.handle, u, Int32(multiplicity), tolerance)
        }

        /// Remove a knot at 1-based index.
        @discardableResult
        public func removeKnot(at index: Int, multiplicity: Int, tolerance: Double) -> Bool {
            OCCTCurve2DBSplineRemoveKnot(curve.handle, Int32(index), Int32(multiplicity), tolerance)
        }

        /// Segment to [u1, u2].
        @discardableResult
        public func segment(u1: Double, u2: Double) -> Bool {
            OCCTCurve2DBSplineSegment(curve.handle, u1, u2)
        }

        /// Increase degree.
        @discardableResult
        public func increaseDegree(to degree: Int) -> Bool {
            OCCTCurve2DBSplineIncreaseDegree(curve.handle, Int32(degree))
        }

        /// Compute parametric resolution for a given tolerance.
        public func resolution(tolerance: Double) -> Double {
            OCCTCurve2DBSplineResolution(curve.handle, tolerance)
        }
    }

    /// Access BSpline-specific operations. Works only if the underlying curve is a Geom2d_BSplineCurve.
    public var bspline: BSpline { BSpline(curve: self) }
}

// MARK: - Bezier Curve Methods (v0.107.0)

extension Curve3D {

    /// Bezier-specific operations.
    public struct Bezier {
        let curve: Curve3D

        /// Get a pole at 1-based index.
        public func pole(at index: Int) -> SIMD3<Double> {
            var x = 0.0, y = 0.0, z = 0.0
            OCCTCurve3DBezierGetPole(curve.handle, Int32(index), &x, &y, &z)
            return SIMD3(x, y, z)
        }

        /// Set a pole at 1-based index.
        @discardableResult
        public func setPole(at index: Int, to point: SIMD3<Double>) -> Bool {
            OCCTCurve3DBezierSetPole(curve.handle, Int32(index), point.x, point.y, point.z)
        }

        /// Set the weight at 1-based index.
        @discardableResult
        public func setWeight(at index: Int, to weight: Double) -> Bool {
            OCCTCurve3DBezierSetWeight(curve.handle, Int32(index), weight)
        }

        /// Insert a pole after given index.
        @discardableResult
        public func insertPoleAfter(index: Int, point: SIMD3<Double>) -> Bool {
            OCCTCurve3DBezierInsertPoleAfter(curve.handle, Int32(index), point.x, point.y, point.z)
        }

        /// Remove a pole at given index.
        @discardableResult
        public func removePole(at index: Int) -> Bool {
            OCCTCurve3DBezierRemovePole(curve.handle, Int32(index))
        }

        /// Segment to [u1, u2].
        @discardableResult
        public func segment(u1: Double, u2: Double) -> Bool {
            OCCTCurve3DBezierSegment(curve.handle, u1, u2)
        }

        /// Increase degree.
        @discardableResult
        public func increaseDegree(to degree: Int) -> Bool {
            OCCTCurve3DBezierIncreaseDegree(curve.handle, Int32(degree))
        }

        /// Whether the Bezier is rational.
        public var isRational: Bool { OCCTCurve3DBezierIsRational(curve.handle) }

        /// Degree.
        public var degree: Int { Int(OCCTCurve3DBezierDegree(curve.handle)) }

        /// Number of poles.
        public var poleCount: Int { Int(OCCTCurve3DBezierPoleCount(curve.handle)) }
    }

    /// Access Bezier-specific operations. Works only if the underlying curve is a Geom_BezierCurve.
    public var bezier: Bezier { Bezier(curve: self) }
}

// MARK: - BRepTools/BRepLib Utilities (v0.107.0)

extension Shape {

    /// Clean all tessellation data from the shape.
    public func clean() {
        OCCTShapeClean(handle)
    }

    /// Clean geometry (PCurves etc.) from the shape.
    public func cleanGeometry() {
        OCCTShapeCleanGeometry(handle)
    }

    /// Remove unused PCurves from edges.
    public func removeUnusedPCurves() {
        OCCTShapeRemoveUnusedPCurves(handle)
    }

    /// Update BRep data structures.
    public func updateShape() {
        OCCTShapeUpdate(handle)
    }

    /// Check if an edge has same-range parametrisation.
    public static func checkSameRange(edge: Shape) -> Bool {
        OCCTBRepLibCheckSameRange(edge.handle)
    }

    /// Ensure edge has same-range parametrisation.
    @discardableResult
    public static func sameRange(edge: Shape, tolerance: Double = 1e-6) -> Bool {
        OCCTBRepLibSameRange(edge.handle, tolerance)
    }

    /// Build 3D curve for an edge from PCurves.
    @discardableResult
    public static func buildCurve3d(edge: Shape, tolerance: Double = 1e-6) -> Bool {
        OCCTBRepLibBuildCurve3d(edge.handle, tolerance)
    }

    /// Update tolerances of all sub-shapes.
    public func updateTolerances() {
        OCCTBRepLibUpdateTolerances(handle)
    }

    /// Update inner tolerances of all sub-shapes.
    public func updateInnerTolerances() {
        OCCTBRepLibUpdateInnerTolerances(handle)
    }

    /// Update tolerance of a specific edge.
    @discardableResult
    public static func updateEdgeTolerance(edge: Shape, tolerance: Double) -> Bool {
        OCCTBRepLibUpdateEdgeTolerance(edge.handle, tolerance)
    }
}

// MARK: - MakeFace Extras (v0.107.0)

extension Shape {

    /// Create a face from a sphere with UV bounds.
    public static func faceFromSphere(center: SIMD3<Double> = .zero, radius: Double,
                                       uMin: Double, uMax: Double, vMin: Double, vMax: Double) -> Shape? {
        guard let ref = OCCTMakeFaceFromSphere(center.x, center.y, center.z, radius, uMin, uMax, vMin, vMax) else { return nil }
        return Shape(handle: ref)
    }

    /// Create a face from a torus with UV bounds.
    public static func faceFromTorus(center: SIMD3<Double> = .zero, normal: SIMD3<Double> = SIMD3(0, 0, 1),
                                      majorRadius: Double, minorRadius: Double,
                                      uMin: Double, uMax: Double, vMin: Double, vMax: Double) -> Shape? {
        guard let ref = OCCTMakeFaceFromTorus(center.x, center.y, center.z, normal.x, normal.y, normal.z,
                                               majorRadius, minorRadius, uMin, uMax, vMin, vMax) else { return nil }
        return Shape(handle: ref)
    }

    /// Create a face from a cone with UV bounds.
    public static func faceFromCone(center: SIMD3<Double> = .zero, normal: SIMD3<Double> = SIMD3(0, 0, 1),
                                     semiAngle: Double, radius: Double,
                                     uMin: Double, uMax: Double, vMin: Double, vMax: Double) -> Shape? {
        guard let ref = OCCTMakeFaceFromCone(center.x, center.y, center.z, normal.x, normal.y, normal.z,
                                              semiAngle, radius, uMin, uMax, vMin, vMax) else { return nil }
        return Shape(handle: ref)
    }

    /// Create a face from a surface trimmed by a wire.
    public static func faceFromSurface(_ surface: Surface, wire: Shape, inside: Bool = true) -> Shape? {
        guard let ref = OCCTMakeFaceFromSurfaceWire(surface.handle, wire.handle, inside) else { return nil }
        return Shape(handle: ref)
    }

    /// Add a hole (inner wire) to a face.
    public static func faceAddHole(face: Shape, wire: Shape) -> Shape? {
        guard let ref = OCCTMakeFaceAddHole(face.handle, wire.handle) else { return nil }
        return Shape(handle: ref)
    }

    /// Copy a face.
    public static func faceCopy(_ face: Shape) -> Shape? {
        guard let ref = OCCTMakeFaceCopy(face.handle) else { return nil }
        return Shape(handle: ref)
    }
}

// MARK: - Sewing (v0.107.0)

/// A builder for sewing shapes together.
public final class SewingBuilder: @unchecked Sendable {
    private let ref: OCCTSewingRef

    /// Create a sewing builder with the given tolerance.
    public init?(tolerance: Double = 1e-6) {
        guard let r = OCCTSewingCreate(tolerance) else { return nil }
        self.ref = r
    }

    deinit {
        OCCTSewingRelease(ref)
    }

    /// Add a shape to be sewn.
    public func add(_ shape: Shape) {
        OCCTSewingAdd(ref, shape.handle)
    }

    /// Perform the sewing operation.
    public func perform() {
        OCCTSewingPerform(ref)
    }

    /// Get the result shape.
    public var result: Shape? {
        guard let r = OCCTSewingResult(ref) else { return nil }
        return Shape(handle: r)
    }

    /// Number of free edges.
    public var nbFreeEdges: Int { Int(OCCTSewingNbFreeEdges(ref)) }

    /// Number of contiguous edges.
    public var nbContigousEdges: Int { Int(OCCTSewingNbContigousEdges(ref)) }

    /// Number of degenerated shapes.
    public var nbDegeneratedShapes: Int { Int(OCCTSewingNbDegeneratedShapes(ref)) }
}

// MARK: - Hatch_Hatcher (v0.107.0)

/// A 2D hatching builder.
public final class HatchBuilder: @unchecked Sendable {
    private let ref: OCCTHatcherRef

    /// Create a hatcher with the given tolerance.
    public init?(tolerance: Double = 1e-6) {
        guard let r = OCCTHatcherCreate(tolerance) else { return nil }
        self.ref = r
    }

    deinit {
        OCCTHatcherRelease(ref)
    }

    /// Add a vertical line at x.
    public func addXLine(_ x: Double) {
        OCCTHatcherAddXLine(ref, x)
    }

    /// Add a horizontal line at y.
    public func addYLine(_ y: Double) {
        OCCTHatcherAddYLine(ref, y)
    }

    /// Trim hatch lines with a segment from (x1,y1) to (x2,y2).
    public func trim(x1: Double, y1: Double, x2: Double, y2: Double) {
        OCCTHatcherTrim(ref, x1, y1, x2, y2)
    }

    /// Get the number of hatch lines.
    public var nbLines: Int { Int(OCCTHatcherNbLines(ref)) }

    /// Get the number of intervals on a line (1-based index).
    public func nbIntervals(lineIndex: Int) -> Int {
        Int(OCCTHatcherNbIntervals(ref, Int32(lineIndex)))
    }
}

// MARK: - Edge/Face Extraction (v0.107.0)

extension Shape {

    /// Extract the 3D curve from an edge shape. Returns (curve, firstParam, lastParam) or nil.
    public func extractEdgeCurve3D() -> (curve: Curve3D, first: Double, last: Double)? {
        var first = 0.0, last = 0.0
        guard let ref = OCCTEdgeExtractCurve3D(handle, &first, &last) else { return nil }
        return (Curve3D(handle: ref), first, last)
    }

    /// Extract the PCurve of an edge on a face. Returns (curve, firstParam, lastParam) or nil.
    public func extractEdgePCurve(onFace face: Shape) -> (curve: Curve2D, first: Double, last: Double)? {
        var first = 0.0, last = 0.0
        guard let ref = OCCTEdgeExtractPCurve(handle, face.handle, &first, &last) else { return nil }
        return (Curve2D(handle: ref), first, last)
    }

    /// Get the tolerance of an edge shape.
    public var edgeTolerance: Double { OCCTEdgeGetTolerance(handle) }

    /// Check if an edge is degenerated.
    public var isEdgeDegenerated: Bool { OCCTEdgeIsDegenerated(handle) }

    /// Extract the surface from a face shape.
    public func extractFaceSurface() -> Surface? {
        guard let ref = OCCTFaceExtractSurface(handle) else { return nil }
        return Surface(handle: ref)
    }

    /// Get the tolerance of a face shape.
    public var faceTolerance: Double { OCCTFaceGetTolerance(handle) }

    /// Get the number of wires on a face shape.
    public var faceWireCount: Int { Int(OCCTFaceWireCount(handle)) }

    /// Get the tolerance of a vertex shape.
    public var vertexTolerance: Double { OCCTVertexGetTolerance(handle) }

    /// Get the point of a vertex shape.
    public var vertexPoint: SIMD3<Double> {
        var x = 0.0, y = 0.0, z = 0.0
        OCCTVertexGetPoint(handle, &x, &y, &z)
        return SIMD3(x, y, z)
    }
}

// MARK: - Extrema Elementary Distances (v0.109.0)

/// Result of an elementary extrema computation.
public struct ExtremaResult: Sendable {
    /// Squared distance between the closest/farthest points.
    public let squareDistance: Double
    /// Point on the first element.
    public let point1: SIMD3<Double>
    /// Point on the second element.
    public let point2: SIMD3<Double>
}

/// Elementary curve-curve distance computations (Extrema_ExtElC).
public enum ExtremaElC {

    /// Distance between two 3D lines.
    /// Returns (isParallel, results) where results contains the extrema.
    public static func lineToLine(
        line1Point: SIMD3<Double>, line1Dir: SIMD3<Double>,
        line2Point: SIMD3<Double>, line2Dir: SIMD3<Double>,
        tolerance: Double = 1e-6
    ) -> (isParallel: Bool, results: [ExtremaResult]) {
        var isParallel = false
        var buf = [OCCTExtremaElResult](repeating: OCCTExtremaElResult(), count: 10)
        let n = OCCTExtremaElCLinLin(
            line1Point.x, line1Point.y, line1Point.z,
            line1Dir.x, line1Dir.y, line1Dir.z,
            line2Point.x, line2Point.y, line2Point.z,
            line2Dir.x, line2Dir.y, line2Dir.z,
            tolerance, &isParallel, &buf, 10
        )
        guard n > 0 else { return (isParallel, []) }
        let results = (0..<Int(n)).map { i in
            ExtremaResult(
                squareDistance: buf[i].squareDistance,
                point1: SIMD3(buf[i].x1, buf[i].y1, buf[i].z1),
                point2: SIMD3(buf[i].x2, buf[i].y2, buf[i].z2)
            )
        }
        return (isParallel, results)
    }

    /// Distance between a 3D line and circle.
    public static func lineToCircle(
        linePoint: SIMD3<Double>, lineDir: SIMD3<Double>,
        circleCenter: SIMD3<Double>, circleNormal: SIMD3<Double>, radius: Double,
        tolerance: Double = 1e-6
    ) -> [ExtremaResult] {
        var buf = [OCCTExtremaElResult](repeating: OCCTExtremaElResult(), count: 10)
        let n = OCCTExtremaElCLinCirc(
            linePoint.x, linePoint.y, linePoint.z,
            lineDir.x, lineDir.y, lineDir.z,
            circleCenter.x, circleCenter.y, circleCenter.z,
            circleNormal.x, circleNormal.y, circleNormal.z, radius,
            tolerance, &buf, 10
        )
        guard n > 0 else { return [] }
        return (0..<Int(n)).map { i in
            ExtremaResult(
                squareDistance: buf[i].squareDistance,
                point1: SIMD3(buf[i].x1, buf[i].y1, buf[i].z1),
                point2: SIMD3(buf[i].x2, buf[i].y2, buf[i].z2)
            )
        }
    }

    /// Distance between two 3D circles.
    public static func circleToCircle(
        center1: SIMD3<Double>, normal1: SIMD3<Double>, radius1: Double,
        center2: SIMD3<Double>, normal2: SIMD3<Double>, radius2: Double
    ) -> [ExtremaResult] {
        var buf = [OCCTExtremaElResult](repeating: OCCTExtremaElResult(), count: 10)
        let n = OCCTExtremaElCCircCirc(
            center1.x, center1.y, center1.z,
            normal1.x, normal1.y, normal1.z, radius1,
            center2.x, center2.y, center2.z,
            normal2.x, normal2.y, normal2.z, radius2,
            &buf, 10
        )
        guard n > 0 else { return [] }
        return (0..<Int(n)).map { i in
            ExtremaResult(
                squareDistance: buf[i].squareDistance,
                point1: SIMD3(buf[i].x1, buf[i].y1, buf[i].z1),
                point2: SIMD3(buf[i].x2, buf[i].y2, buf[i].z2)
            )
        }
    }

    /// Distance between a 3D line and ellipse.
    public static func lineToEllipse(
        linePoint: SIMD3<Double>, lineDir: SIMD3<Double>,
        center: SIMD3<Double>, normal: SIMD3<Double>, xDir: SIMD3<Double>,
        majorRadius: Double, minorRadius: Double,
        tolerance: Double = 1e-6
    ) -> [ExtremaResult] {
        var buf = [OCCTExtremaElResult](repeating: OCCTExtremaElResult(), count: 10)
        let n = OCCTExtremaElCLinElips(
            linePoint.x, linePoint.y, linePoint.z,
            lineDir.x, lineDir.y, lineDir.z,
            center.x, center.y, center.z,
            normal.x, normal.y, normal.z,
            xDir.x, xDir.y, xDir.z,
            majorRadius, minorRadius, tolerance,
            &buf, 10
        )
        guard n > 0 else { return [] }
        return (0..<Int(n)).map { i in
            ExtremaResult(
                squareDistance: buf[i].squareDistance,
                point1: SIMD3(buf[i].x1, buf[i].y1, buf[i].z1),
                point2: SIMD3(buf[i].x2, buf[i].y2, buf[i].z2)
            )
        }
    }
}

/// Elementary curve-surface distance computations (Extrema_ExtElCS).
public enum ExtremaElCS {

    /// Distance between a line and a plane.
    public static func lineToPlane(
        linePoint: SIMD3<Double>, lineDir: SIMD3<Double>,
        planePoint: SIMD3<Double>, planeNormal: SIMD3<Double>
    ) -> (isParallel: Bool, results: [ExtremaResult]) {
        var isParallel = false
        var buf = [OCCTExtremaElResult](repeating: OCCTExtremaElResult(), count: 10)
        let n = OCCTExtremaElCSLinPlane(
            linePoint.x, linePoint.y, linePoint.z,
            lineDir.x, lineDir.y, lineDir.z,
            planePoint.x, planePoint.y, planePoint.z,
            planeNormal.x, planeNormal.y, planeNormal.z,
            &isParallel, &buf, 10
        )
        guard n > 0 else { return (isParallel, []) }
        let results = (0..<Int(n)).map { i in
            ExtremaResult(
                squareDistance: buf[i].squareDistance,
                point1: SIMD3(buf[i].x1, buf[i].y1, buf[i].z1),
                point2: SIMD3(buf[i].x2, buf[i].y2, buf[i].z2)
            )
        }
        return (isParallel, results)
    }

    /// Distance between a line and a sphere.
    public static func lineToSphere(
        linePoint: SIMD3<Double>, lineDir: SIMD3<Double>,
        sphereCenter: SIMD3<Double>, sphereRadius: Double
    ) -> [ExtremaResult] {
        var buf = [OCCTExtremaElResult](repeating: OCCTExtremaElResult(), count: 10)
        let n = OCCTExtremaElCSLinSphere(
            linePoint.x, linePoint.y, linePoint.z,
            lineDir.x, lineDir.y, lineDir.z,
            sphereCenter.x, sphereCenter.y, sphereCenter.z, sphereRadius,
            &buf, 10
        )
        guard n > 0 else { return [] }
        return (0..<Int(n)).map { i in
            ExtremaResult(
                squareDistance: buf[i].squareDistance,
                point1: SIMD3(buf[i].x1, buf[i].y1, buf[i].z1),
                point2: SIMD3(buf[i].x2, buf[i].y2, buf[i].z2)
            )
        }
    }

    /// Distance between a line and a cylinder.
    public static func lineToCylinder(
        linePoint: SIMD3<Double>, lineDir: SIMD3<Double>,
        cylCenter: SIMD3<Double>, cylAxis: SIMD3<Double>, cylRadius: Double
    ) -> [ExtremaResult] {
        var buf = [OCCTExtremaElResult](repeating: OCCTExtremaElResult(), count: 10)
        let n = OCCTExtremaElCSLinCylinder(
            linePoint.x, linePoint.y, linePoint.z,
            lineDir.x, lineDir.y, lineDir.z,
            cylCenter.x, cylCenter.y, cylCenter.z,
            cylAxis.x, cylAxis.y, cylAxis.z, cylRadius,
            &buf, 10
        )
        guard n > 0 else { return [] }
        return (0..<Int(n)).map { i in
            ExtremaResult(
                squareDistance: buf[i].squareDistance,
                point1: SIMD3(buf[i].x1, buf[i].y1, buf[i].z1),
                point2: SIMD3(buf[i].x2, buf[i].y2, buf[i].z2)
            )
        }
    }
}

/// Elementary surface-surface distance computations (Extrema_ExtElSS).
public enum ExtremaElSS {

    /// Distance between two planes.
    public static func planeToPlane(
        plane1Point: SIMD3<Double>, plane1Normal: SIMD3<Double>,
        plane2Point: SIMD3<Double>, plane2Normal: SIMD3<Double>
    ) -> (isParallel: Bool, results: [ExtremaResult]) {
        var isParallel = false
        var buf = [OCCTExtremaElResult](repeating: OCCTExtremaElResult(), count: 10)
        let n = OCCTExtremaElSSPlanePlane(
            plane1Point.x, plane1Point.y, plane1Point.z,
            plane1Normal.x, plane1Normal.y, plane1Normal.z,
            plane2Point.x, plane2Point.y, plane2Point.z,
            plane2Normal.x, plane2Normal.y, plane2Normal.z,
            &isParallel, &buf, 10
        )
        guard n > 0 else { return (isParallel, []) }
        let results = (0..<Int(n)).map { i in
            ExtremaResult(
                squareDistance: buf[i].squareDistance,
                point1: SIMD3(buf[i].x1, buf[i].y1, buf[i].z1),
                point2: SIMD3(buf[i].x2, buf[i].y2, buf[i].z2)
            )
        }
        return (isParallel, results)
    }

    /// Distance between a plane and a sphere.
    public static func planeToSphere(
        planePoint: SIMD3<Double>, planeNormal: SIMD3<Double>,
        sphereCenter: SIMD3<Double>, sphereRadius: Double
    ) -> [ExtremaResult] {
        var buf = [OCCTExtremaElResult](repeating: OCCTExtremaElResult(), count: 10)
        let n = OCCTExtremaElSSPlaneSphere(
            planePoint.x, planePoint.y, planePoint.z,
            planeNormal.x, planeNormal.y, planeNormal.z,
            sphereCenter.x, sphereCenter.y, sphereCenter.z, sphereRadius,
            &buf, 10
        )
        guard n > 0 else { return [] }
        return (0..<Int(n)).map { i in
            ExtremaResult(
                squareDistance: buf[i].squareDistance,
                point1: SIMD3(buf[i].x1, buf[i].y1, buf[i].z1),
                point2: SIMD3(buf[i].x2, buf[i].y2, buf[i].z2)
            )
        }
    }

    /// Distance between two spheres.
    public static func sphereToSphere(
        center1: SIMD3<Double>, radius1: Double,
        center2: SIMD3<Double>, radius2: Double
    ) -> [ExtremaResult] {
        var buf = [OCCTExtremaElResult](repeating: OCCTExtremaElResult(), count: 10)
        let n = OCCTExtremaElSSSphereSphere(
            center1.x, center1.y, center1.z, radius1,
            center2.x, center2.y, center2.z, radius2,
            &buf, 10
        )
        guard n > 0 else { return [] }
        return (0..<Int(n)).map { i in
            ExtremaResult(
                squareDistance: buf[i].squareDistance,
                point1: SIMD3(buf[i].x1, buf[i].y1, buf[i].z1),
                point2: SIMD3(buf[i].x2, buf[i].y2, buf[i].z2)
            )
        }
    }
}

/// Point to elementary curve distance (Extrema_ExtPElC).
public enum ExtremaPointCurve {

    /// Distance from a point to a 3D line.
    public static func pointToLine(
        point: SIMD3<Double>,
        lineOrigin: SIMD3<Double>, lineDir: SIMD3<Double>,
        tolerance: Double = 1e-6
    ) -> [ExtremaResult] {
        var buf = [OCCTExtremaElResult](repeating: OCCTExtremaElResult(), count: 10)
        let n = OCCTExtremaExtPElCLin(
            point.x, point.y, point.z,
            lineOrigin.x, lineOrigin.y, lineOrigin.z,
            lineDir.x, lineDir.y, lineDir.z,
            tolerance, &buf, 10
        )
        guard n > 0 else { return [] }
        return (0..<Int(n)).map { i in
            ExtremaResult(
                squareDistance: buf[i].squareDistance,
                point1: SIMD3(buf[i].x1, buf[i].y1, buf[i].z1),
                point2: SIMD3(buf[i].x2, buf[i].y2, buf[i].z2)
            )
        }
    }

    /// Distance from a point to a 3D circle.
    public static func pointToCircle(
        point: SIMD3<Double>,
        center: SIMD3<Double>, normal: SIMD3<Double>, radius: Double,
        tolerance: Double = 1e-6
    ) -> [ExtremaResult] {
        var buf = [OCCTExtremaElResult](repeating: OCCTExtremaElResult(), count: 10)
        let n = OCCTExtremaExtPElCCirc(
            point.x, point.y, point.z,
            center.x, center.y, center.z,
            normal.x, normal.y, normal.z, radius,
            tolerance, &buf, 10
        )
        guard n > 0 else { return [] }
        return (0..<Int(n)).map { i in
            ExtremaResult(
                squareDistance: buf[i].squareDistance,
                point1: SIMD3(buf[i].x1, buf[i].y1, buf[i].z1),
                point2: SIMD3(buf[i].x2, buf[i].y2, buf[i].z2)
            )
        }
    }

    /// Distance from a point to a 3D ellipse.
    public static func pointToEllipse(
        point: SIMD3<Double>,
        center: SIMD3<Double>, normal: SIMD3<Double>, xDir: SIMD3<Double>,
        majorRadius: Double, minorRadius: Double,
        tolerance: Double = 1e-6
    ) -> [ExtremaResult] {
        var buf = [OCCTExtremaElResult](repeating: OCCTExtremaElResult(), count: 10)
        let n = OCCTExtremaExtPElCElips(
            point.x, point.y, point.z,
            center.x, center.y, center.z,
            normal.x, normal.y, normal.z,
            xDir.x, xDir.y, xDir.z,
            majorRadius, minorRadius, tolerance,
            &buf, 10
        )
        guard n > 0 else { return [] }
        return (0..<Int(n)).map { i in
            ExtremaResult(
                squareDistance: buf[i].squareDistance,
                point1: SIMD3(buf[i].x1, buf[i].y1, buf[i].z1),
                point2: SIMD3(buf[i].x2, buf[i].y2, buf[i].z2)
            )
        }
    }

    /// Distance from a point to a 3D parabola.
    public static func pointToParabola(
        point: SIMD3<Double>,
        center: SIMD3<Double>, normal: SIMD3<Double>, xDir: SIMD3<Double>,
        focal: Double,
        tolerance: Double = 1e-6
    ) -> [ExtremaResult] {
        var buf = [OCCTExtremaElResult](repeating: OCCTExtremaElResult(), count: 10)
        let n = OCCTExtremaExtPElCParab(
            point.x, point.y, point.z,
            center.x, center.y, center.z,
            normal.x, normal.y, normal.z,
            xDir.x, xDir.y, xDir.z,
            focal, tolerance, &buf, 10
        )
        guard n > 0 else { return [] }
        return (0..<Int(n)).map { i in
            ExtremaResult(
                squareDistance: buf[i].squareDistance,
                point1: SIMD3(buf[i].x1, buf[i].y1, buf[i].z1),
                point2: SIMD3(buf[i].x2, buf[i].y2, buf[i].z2)
            )
        }
    }
}

/// Point to elementary surface distance (Extrema_ExtPElS).
public enum ExtremaPointSurface {

    /// Distance from a point to a plane.
    public static func pointToPlane(
        point: SIMD3<Double>,
        planePoint: SIMD3<Double>, planeNormal: SIMD3<Double>,
        tolerance: Double = 1e-6
    ) -> [ExtremaResult] {
        var buf = [OCCTExtremaElResult](repeating: OCCTExtremaElResult(), count: 10)
        let n = OCCTExtremaExtPElSPlane(
            point.x, point.y, point.z,
            planePoint.x, planePoint.y, planePoint.z,
            planeNormal.x, planeNormal.y, planeNormal.z,
            tolerance, &buf, 10
        )
        guard n > 0 else { return [] }
        return (0..<Int(n)).map { i in
            ExtremaResult(
                squareDistance: buf[i].squareDistance,
                point1: SIMD3(buf[i].x1, buf[i].y1, buf[i].z1),
                point2: SIMD3(buf[i].x2, buf[i].y2, buf[i].z2)
            )
        }
    }

    /// Distance from a point to a sphere.
    public static func pointToSphere(
        point: SIMD3<Double>,
        center: SIMD3<Double>, radius: Double,
        tolerance: Double = 1e-6
    ) -> [ExtremaResult] {
        var buf = [OCCTExtremaElResult](repeating: OCCTExtremaElResult(), count: 10)
        let n = OCCTExtremaExtPElSSphere(
            point.x, point.y, point.z,
            center.x, center.y, center.z, radius,
            tolerance, &buf, 10
        )
        guard n > 0 else { return [] }
        return (0..<Int(n)).map { i in
            ExtremaResult(
                squareDistance: buf[i].squareDistance,
                point1: SIMD3(buf[i].x1, buf[i].y1, buf[i].z1),
                point2: SIMD3(buf[i].x2, buf[i].y2, buf[i].z2)
            )
        }
    }

    /// Distance from a point to a cylinder.
    public static func pointToCylinder(
        point: SIMD3<Double>,
        center: SIMD3<Double>, axis: SIMD3<Double>, radius: Double,
        tolerance: Double = 1e-6
    ) -> [ExtremaResult] {
        var buf = [OCCTExtremaElResult](repeating: OCCTExtremaElResult(), count: 10)
        let n = OCCTExtremaExtPElSCylinder(
            point.x, point.y, point.z,
            center.x, center.y, center.z,
            axis.x, axis.y, axis.z, radius,
            tolerance, &buf, 10
        )
        guard n > 0 else { return [] }
        return (0..<Int(n)).map { i in
            ExtremaResult(
                squareDistance: buf[i].squareDistance,
                point1: SIMD3(buf[i].x1, buf[i].y1, buf[i].z1),
                point2: SIMD3(buf[i].x2, buf[i].y2, buf[i].z2)
            )
        }
    }

    /// Distance from a point to a cone.
    public static func pointToCone(
        point: SIMD3<Double>,
        apex: SIMD3<Double>, axis: SIMD3<Double>,
        semiAngle: Double, refRadius: Double,
        tolerance: Double = 1e-6
    ) -> [ExtremaResult] {
        var buf = [OCCTExtremaElResult](repeating: OCCTExtremaElResult(), count: 10)
        let n = OCCTExtremaExtPElSCone(
            point.x, point.y, point.z,
            apex.x, apex.y, apex.z,
            axis.x, axis.y, axis.z,
            semiAngle, refRadius, tolerance,
            &buf, 10
        )
        guard n > 0 else { return [] }
        return (0..<Int(n)).map { i in
            ExtremaResult(
                squareDistance: buf[i].squareDistance,
                point1: SIMD3(buf[i].x1, buf[i].y1, buf[i].z1),
                point2: SIMD3(buf[i].x2, buf[i].y2, buf[i].z2)
            )
        }
    }

    /// Distance from a point to a torus.
    public static func pointToTorus(
        point: SIMD3<Double>,
        center: SIMD3<Double>, axis: SIMD3<Double>,
        majorRadius: Double, minorRadius: Double,
        tolerance: Double = 1e-6
    ) -> [ExtremaResult] {
        var buf = [OCCTExtremaElResult](repeating: OCCTExtremaElResult(), count: 10)
        let n = OCCTExtremaExtPElSTorus(
            point.x, point.y, point.z,
            center.x, center.y, center.z,
            axis.x, axis.y, axis.z,
            majorRadius, minorRadius, tolerance,
            &buf, 10
        )
        guard n > 0 else { return [] }
        return (0..<Int(n)).map { i in
            ExtremaResult(
                squareDistance: buf[i].squareDistance,
                point1: SIMD3(buf[i].x1, buf[i].y1, buf[i].z1),
                point2: SIMD3(buf[i].x2, buf[i].y2, buf[i].z2)
            )
        }
    }
}

// MARK: - math_TrigonometricFunctionRoots (v0.109.0)

/// Trigonometric equation solver: A*cos(x) + B*sin(x) + C*cos(2x) + D*sin(2x) + E = 0.
public enum TrigRoots {

    /// Find roots of A*cos(x) + B*sin(x) + C*cos(2x) + D*sin(2x) + E = 0 on [inf, sup].
    public static func solve(
        A: Double = 0, B: Double = 0, C: Double = 0, D: Double = 0, E: Double = 0,
        from inf: Double, to sup: Double
    ) -> [Double] {
        var roots = [Double](repeating: 0, count: 100)
        let n = OCCTTrigRoots(A, B, C, D, E, inf, sup, &roots, 100)
        guard n > 0 else { return [] }
        return Array(roots.prefix(Int(n)))
    }

    /// Check if all reals in [inf, sup] are solutions.
    public static func hasInfiniteRoots(
        A: Double = 0, B: Double = 0, C: Double = 0, D: Double = 0, E: Double = 0,
        from inf: Double, to sup: Double
    ) -> Bool {
        OCCTTrigRootsInfinite(A, B, C, D, E, inf, sup)
    }
}

// MARK: - IntAna2d_Conic (v0.109.0)

/// 2D conic section coefficient representation.
public struct Conic2D: Sendable {
    /// Coefficients A, B, C, D, E, F of A*x^2 + B*x*y + C*y^2 + D*x + E*y + F = 0.
    public let a, b, c, d, e, f: Double

    /// Create from a 2D circle.
    public static func fromCircle(
        center: SIMD2<Double>, direction: SIMD2<Double>, radius: Double
    ) -> Conic2D {
        var coeffs = [Double](repeating: 0, count: 6)
        OCCTConic2dFromCircle(center.x, center.y, direction.x, direction.y, radius, &coeffs)
        return Conic2D(a: coeffs[0], b: coeffs[1], c: coeffs[2],
                        d: coeffs[3], e: coeffs[4], f: coeffs[5])
    }

    /// Create from a 2D line.
    public static func fromLine(
        point: SIMD2<Double>, direction: SIMD2<Double>
    ) -> Conic2D {
        var coeffs = [Double](repeating: 0, count: 6)
        OCCTConic2dFromLine(point.x, point.y, direction.x, direction.y, &coeffs)
        return Conic2D(a: coeffs[0], b: coeffs[1], c: coeffs[2],
                        d: coeffs[3], e: coeffs[4], f: coeffs[5])
    }

    /// Create from a 2D ellipse.
    public static func fromEllipse(
        center: SIMD2<Double>, direction: SIMD2<Double>,
        majorRadius: Double, minorRadius: Double
    ) -> Conic2D {
        var coeffs = [Double](repeating: 0, count: 6)
        OCCTConic2dFromEllipse(center.x, center.y, direction.x, direction.y,
                                majorRadius, minorRadius, &coeffs)
        return Conic2D(a: coeffs[0], b: coeffs[1], c: coeffs[2],
                        d: coeffs[3], e: coeffs[4], f: coeffs[5])
    }

    /// Intersect a 2D line with a 2D circle. Returns intersection points.
    public static func lineCircleIntersection(
        linePoint: SIMD2<Double>, lineDir: SIMD2<Double>,
        circleCenter: SIMD2<Double>, circleDir: SIMD2<Double>, radius: Double
    ) -> [SIMD2<Double>] {
        var xs = [Double](repeating: 0, count: 10)
        var ys = [Double](repeating: 0, count: 10)
        let n = OCCTConic2dLineCircleIntersect(
            linePoint.x, linePoint.y, lineDir.x, lineDir.y,
            circleCenter.x, circleCenter.y, circleDir.x, circleDir.y, radius,
            &xs, &ys, 10
        )
        guard n > 0 else { return [] }
        return (0..<Int(n)).map { SIMD2(xs[$0], ys[$0]) }
    }
}

// MARK: - BRepAlgo_NormalProjection (v0.109.0)

/// Projects wires/edges onto a shape by normal projection.
public final class NormalProjection: @unchecked Sendable {
    private let ref: OCCTNormalProjectionRef

    /// Create a normal projection targeting the given shape.
    public init?(target: Shape) {
        guard let r = OCCTNormalProjectionCreate(target.handle) else { return nil }
        ref = r
    }

    deinit {
        OCCTNormalProjectionRelease(ref)
    }

    /// Add a wire or edge to be projected.
    public func add(_ shape: Shape) {
        OCCTNormalProjectionAdd(ref, shape.handle)
    }

    /// Build the projection. Returns true on success.
    @discardableResult
    public func build() -> Bool {
        OCCTNormalProjectionBuild(ref)
    }

    /// Get the projection result shape.
    public var result: Shape? {
        guard let r = OCCTNormalProjectionResult(ref) else { return nil }
        return Shape(handle: r)
    }
}

// MARK: - OSD_Disk (v0.109.0)

/// Disk/volume information utilities.
public enum DiskInfo {

    /// Get disk total size in KB for the given path.
    public static func size(path: String = "/") -> Int64 {
        OCCTDiskSize(path)
    }

    /// Get disk free space in KB for the given path.
    public static func freeSpace(path: String = "/") -> Int64 {
        OCCTDiskFree(path)
    }

    /// Check if a disk path is valid/accessible.
    public static func isValid(path: String) -> Bool {
        OCCTDiskIsValid(path)
    }

    /// Get the disk/volume name for the given path.
    public static func name(path: String = "/") -> String? {
        guard let cstr = OCCTDiskName(path) else { return nil }
        let result = String(cString: cstr)
        free(cstr)
        return result
    }
}

// MARK: - OSD_SharedLibrary (v0.109.0)

/// Shared library (dynamic library) handle.
public final class SharedLibrary: @unchecked Sendable {
    private let ref: OCCTSharedLibRef

    /// Create a shared library handle for the given name/path.
    public init?(name: String) {
        guard let r = OCCTSharedLibCreate(name) else { return nil }
        ref = r
    }

    deinit {
        OCCTSharedLibRelease(ref)
    }

    /// Open (load) the shared library.
    @discardableResult
    public func open() -> Bool {
        OCCTSharedLibOpen(ref)
    }

    /// Close (unload) the shared library.
    public func close() {
        OCCTSharedLibClose(ref)
    }

    /// Get the name of the shared library.
    public var name: String? {
        guard let cstr = OCCTSharedLibName(ref) else { return nil }
        let result = String(cString: cstr)
        free(cstr)
        return result
    }
}

// MARK: - Message_Msg (v0.109.0)

/// OCCT message system utilities.
public enum MessageSystem {

    /// Get the message text for a given key.
    public static func message(forKey key: String) -> String? {
        guard let cstr = OCCTMessageMsgGet(key) else { return nil }
        let result = String(cString: cstr)
        free(cstr)
        return result
    }

    /// Load message definitions from a file.
    @discardableResult
    public static func loadFile(_ path: String) -> Bool {
        OCCTMessageMsgFileLoad(path)
    }

    /// Load the default OCCT message file.
    @discardableResult
    public static func loadDefault() -> Bool {
        OCCTMessageMsgFileLoadDefault()
    }

    /// Check if a message key is registered.
    public static func hasMessage(forKey key: String) -> Bool {
        OCCTMessageMsgHasMsg(key)
    }
}

// MARK: - Plate Constraint Extensions (v0.109.0)

extension PlateSolver {

    /// Load a global translation constraint.
    /// All sample points are constrained to translate by the same unknown displacement.
    @discardableResult
    public func loadGlobalTranslation(uvPoints: [SIMD2<Double>]) -> Bool {
        let uvs = uvPoints.flatMap { [$0.x, $0.y] }
        return OCCTPlateLoadGlobalTranslation(handle, uvs, Int32(uvPoints.count))
    }

    /// Load a linear XYZ constraint.
    @discardableResult
    public func loadLinearXYZ(
        uvPoints: [SIMD2<Double>],
        targets: [SIMD3<Double>],
        coefficients: [Double]
    ) -> Bool {
        let uvs = uvPoints.flatMap { [$0.x, $0.y] }
        let tgts = targets.flatMap { [$0.x, $0.y, $0.z] }
        return OCCTPlateLoadLinearXYZ(handle, uvs, tgts, coefficients, Int32(uvPoints.count))
    }
}

// MARK: - Shape Topology Extras (v0.109.0)

extension Shape {

    /// Get the shape type as a string ("compound", "solid", "face", etc.).
    public var shapeTypeString: String {
        guard let cstr = OCCTShapeTypeString(handle) else { return "unknown" }
        let result = String(cString: cstr)
        free(cstr)
        return result
    }
}

// MARK: - Curve3D Extras (v0.109.0)

extension Curve3D {

    /// Reverse the curve in-place.
    @discardableResult
    public func reverse() -> Bool {
        OCCTCurve3DReverse(handle)
    }

    /// Create a deep copy of this curve.
    public func copy() -> Curve3D? {
        guard let ref = OCCTCurve3DCopy(handle) else { return nil }
        return Curve3D(handle: ref)
    }
}

// MARK: - Curve2D Extras (v0.109.0)

extension Curve2D {

    /// Reverse the curve in-place.
    @discardableResult
    public func reverse() -> Bool {
        OCCTCurve2DReverse(handle)
    }

    /// Create a deep copy of this curve.
    public func copy() -> Curve2D? {
        guard let ref = OCCTCurve2DCopy(handle) else { return nil }
        return Curve2D(handle: ref)
    }
}

// MARK: - Surface Extras (v0.109.0)

extension Surface {

    /// Get the parameter bounds of the surface.
    public var parameterBounds: (uMin: Double, uMax: Double, vMin: Double, vMax: Double) {
        var uMin = 0.0, uMax = 0.0, vMin = 0.0, vMax = 0.0
        OCCTSurfaceBounds(handle, &uMin, &uMax, &vMin, &vMax)
        return (uMin, uMax, vMin, vMax)
    }

    /// Get the surface continuity order (0=C0, 1=C1, 2=C2, 3=C3, 99=CN).
    public var surfaceContinuityOrder: Int { Int(OCCTSurfaceContinuity(handle)) }

    /// Create a deep copy of this surface.
    public func copy() -> Surface? {
        guard let ref = OCCTSurfaceCopy(handle) else { return nil }
        return Surface(handle: ref)
    }
}

// MARK: - Math Solvers (v0.110.0)

/// Numerical solver infrastructure using OCCT's math library.
/// Bridges Swift closures to OCCT's abstract C++ function classes via C callback adapters.
public enum MathSolver {

    // MARK: - Context helper

    /// Wraps a Swift closure in a reference type for passing through C void* context pointers.
    private final class ClosureBox<T> {
        let closure: T
        init(_ c: T) { closure = c }
    }

    // MARK: - 1D Root Finding

    /// Find a root of f(x)=0 near `guess` using Newton-Raphson with derivatives.
    ///
    /// The closure takes x and returns (value, derivative).
    /// - Parameters:
    ///   - guess: Initial guess for the root
    ///   - tolerance: Convergence tolerance (default 1e-8)
    ///   - maxIterations: Maximum Newton iterations (default 100)
    ///   - function: Closure returning (f(x), f'(x))
    /// - Returns: The root value, or nil if the solver did not converge
    public static func findRoot(
        near guess: Double,
        tolerance: Double = 1e-8,
        maxIterations: Int = 100,
        function: @escaping (Double) -> (value: Double, derivative: Double)
    ) -> Double? {
        let box = ClosureBox(function)
        let ptr = Unmanaged.passRetained(box).toOpaque()
        defer { Unmanaged<ClosureBox<(Double) -> (value: Double, derivative: Double)>>.fromOpaque(ptr).release() }

        let callback: OCCTMathFuncDerivCallback = { x, value, derivative, context in
            guard let ctx = context else { return false }
            let box = Unmanaged<ClosureBox<(Double) -> (value: Double, derivative: Double)>>.fromOpaque(ctx).takeUnretainedValue()
            let result = box.closure(x)
            value.pointee = result.value
            derivative.pointee = result.derivative
            return true
        }

        var isDone = false
        let result = OCCTMathFunctionRoot(callback, ptr, guess, tolerance, Int32(maxIterations), &isDone)
        return isDone ? result : nil
    }

    /// Find a root of f(x)=0 near `guess` within bounds [a, b].
    public static func findRoot(
        near guess: Double,
        in range: ClosedRange<Double>,
        tolerance: Double = 1e-8,
        maxIterations: Int = 100,
        function: @escaping (Double) -> (value: Double, derivative: Double)
    ) -> Double? {
        let box = ClosureBox(function)
        let ptr = Unmanaged.passRetained(box).toOpaque()
        defer { Unmanaged<ClosureBox<(Double) -> (value: Double, derivative: Double)>>.fromOpaque(ptr).release() }

        let callback: OCCTMathFuncDerivCallback = { x, value, derivative, context in
            guard let ctx = context else { return false }
            let box = Unmanaged<ClosureBox<(Double) -> (value: Double, derivative: Double)>>.fromOpaque(ctx).takeUnretainedValue()
            let result = box.closure(x)
            value.pointee = result.value
            derivative.pointee = result.derivative
            return true
        }

        var isDone = false
        let result = OCCTMathFunctionRootBounded(callback, ptr, guess, tolerance,
                                                   range.lowerBound, range.upperBound, Int32(maxIterations), &isDone)
        return isDone ? result : nil
    }

    /// Find a root of f(x)=0 in [a, b] using bisection+Newton hybrid method.
    public static func findRootBisection(
        in range: ClosedRange<Double>,
        tolerance: Double = 1e-8,
        maxIterations: Int = 100,
        function: @escaping (Double) -> (value: Double, derivative: Double)
    ) -> Double? {
        let box = ClosureBox(function)
        let ptr = Unmanaged.passRetained(box).toOpaque()
        defer { Unmanaged<ClosureBox<(Double) -> (value: Double, derivative: Double)>>.fromOpaque(ptr).release() }

        let callback: OCCTMathFuncDerivCallback = { x, value, derivative, context in
            guard let ctx = context else { return false }
            let box = Unmanaged<ClosureBox<(Double) -> (value: Double, derivative: Double)>>.fromOpaque(ctx).takeUnretainedValue()
            let result = box.closure(x)
            value.pointee = result.value
            derivative.pointee = result.derivative
            return true
        }

        var isDone = false
        let result = OCCTMathBissecNewton(callback, ptr,
                                            range.lowerBound, range.upperBound, tolerance, Int32(maxIterations), &isDone)
        return isDone ? result : nil
    }

    // MARK: - System of Equations

    /// Solve a system of equations using Newton's method.
    ///
    /// - Parameters:
    ///   - variables: Number of variables
    ///   - equations: Number of equations
    ///   - startPoint: Initial guess (array of `variables` values)
    ///   - tolerance: Convergence tolerance (default 1e-8)
    ///   - maxIterations: Maximum iterations (default 100)
    ///   - values: Closure taking [Double] of length `variables`, returning [Double] of length `equations`
    ///   - jacobian: Closure taking [Double] of length `variables`, returning row-major Jacobian [Double] of length `equations * variables`
    /// - Returns: Solution point, or nil if the solver did not converge
    public static func solveSystem(
        variables: Int,
        equations: Int,
        startPoint: [Double],
        tolerance: Double = 1e-8,
        maxIterations: Int = 100,
        values: @escaping ([Double]) -> [Double],
        jacobian: @escaping ([Double]) -> [Double]
    ) -> [Double]? {
        typealias ValuesClosure = ([Double]) -> [Double]
        typealias JacobianClosure = ([Double]) -> [Double]
        let valBox = ClosureBox(values)
        let jacBox = ClosureBox(jacobian)
        // Pack both closures into one context
        let pair = ClosureBox((valBox, jacBox))
        let ptr = Unmanaged.passRetained(pair).toOpaque()
        defer { Unmanaged<ClosureBox<(ClosureBox<ValuesClosure>, ClosureBox<JacobianClosure>)>>.fromOpaque(ptr).release() }

        let valCallback: OCCTMathFuncSetCallback = { x, nVars, vals, nEqs, context in
            guard let ctx = context else { return false }
            let pair = Unmanaged<ClosureBox<(ClosureBox<ValuesClosure>, ClosureBox<JacobianClosure>)>>.fromOpaque(ctx).takeUnretainedValue()
            let n = Int(nVars)
            var input = [Double](repeating: 0, count: n)
            for i in 0..<n { input[i] = x[i] }
            let result = pair.closure.0.closure(input)
            let m = Int(nEqs)
            for i in 0..<m { vals[i] = result[i] }
            return true
        }

        let derivCallback: OCCTMathFuncSetDerivCallback = { x, nVars, jac, nEqs, context in
            guard let ctx = context else { return false }
            let pair = Unmanaged<ClosureBox<(ClosureBox<ValuesClosure>, ClosureBox<JacobianClosure>)>>.fromOpaque(ctx).takeUnretainedValue()
            let n = Int(nVars)
            var input = [Double](repeating: 0, count: n)
            for i in 0..<n { input[i] = x[i] }
            let result = pair.closure.1.closure(input)
            let total = Int(nEqs) * n
            for i in 0..<total { jac[i] = result[i] }
            return true
        }

        var result = [Double](repeating: 0, count: variables)
        let ok = OCCTMathFunctionSetRoot(Int32(variables), Int32(equations),
                                          valCallback, derivCallback, ptr,
                                          startPoint, tolerance, Int32(maxIterations), &result)
        return ok ? result : nil
    }

    // MARK: - BFGS Minimization

    /// Minimize a multivariate function using BFGS quasi-Newton method.
    ///
    /// - Parameters:
    ///   - variables: Number of variables
    ///   - startPoint: Initial guess (array of `variables` values)
    ///   - tolerance: Convergence tolerance (default 1e-8)
    ///   - maxIterations: Maximum iterations (default 200)
    ///   - function: Closure taking [Double], returning (value, gradient)
    /// - Returns: (point, minimum) tuple, or nil if the solver did not converge
    public static func minimize(
        variables: Int,
        startPoint: [Double],
        tolerance: Double = 1e-8,
        maxIterations: Int = 200,
        function: @escaping ([Double]) -> (value: Double, gradient: [Double])
    ) -> (point: [Double], minimum: Double)? {
        typealias Fn = ([Double]) -> (value: Double, gradient: [Double])
        let box = ClosureBox(function)
        let ptr = Unmanaged.passRetained(box).toOpaque()
        defer { Unmanaged<ClosureBox<Fn>>.fromOpaque(ptr).release() }

        let callback: OCCTMathMultiVarGradCallback = { x, n, value, gradient, context in
            guard let ctx = context else { return false }
            let box = Unmanaged<ClosureBox<Fn>>.fromOpaque(ctx).takeUnretainedValue()
            let nv = Int(n)
            var input = [Double](repeating: 0, count: nv)
            for i in 0..<nv { input[i] = x[i] }
            let result = box.closure(input)
            value.pointee = result.value
            for i in 0..<nv { gradient[i] = result.gradient[i] }
            return true
        }

        var result = [Double](repeating: 0, count: variables)
        var minimum = 0.0
        let ok = OCCTMathBFGS(Int32(variables), callback, ptr,
                                startPoint, tolerance, Int32(maxIterations), &result, &minimum)
        return ok ? (result, minimum) : nil
    }

    // MARK: - Powell Minimization

    /// Minimize a multivariate function using Powell's method (derivative-free).
    ///
    /// - Parameters:
    ///   - variables: Number of variables
    ///   - startPoint: Initial guess
    ///   - tolerance: Convergence tolerance (default 1e-8)
    ///   - maxIterations: Maximum iterations (default 200)
    ///   - function: Closure taking [Double], returning scalar value
    /// - Returns: (point, minimum) tuple, or nil if the solver did not converge
    public static func minimizePowell(
        variables: Int,
        startPoint: [Double],
        tolerance: Double = 1e-8,
        maxIterations: Int = 200,
        function: @escaping ([Double]) -> Double
    ) -> (point: [Double], minimum: Double)? {
        typealias Fn = ([Double]) -> Double
        let box = ClosureBox(function)
        let ptr = Unmanaged.passRetained(box).toOpaque()
        defer { Unmanaged<ClosureBox<Fn>>.fromOpaque(ptr).release() }

        let callback: OCCTMathMultiVarCallback = { x, n, value, context in
            guard let ctx = context else { return false }
            let box = Unmanaged<ClosureBox<Fn>>.fromOpaque(ctx).takeUnretainedValue()
            let nv = Int(n)
            var input = [Double](repeating: 0, count: nv)
            for i in 0..<nv { input[i] = x[i] }
            value.pointee = box.closure(input)
            return true
        }

        var result = [Double](repeating: 0, count: variables)
        var minimum = 0.0
        let ok = OCCTMathPowell(Int32(variables), callback, ptr,
                                  startPoint, tolerance, Int32(maxIterations), &result, &minimum)
        return ok ? (result, minimum) : nil
    }

    // MARK: - Brent Minimization

    /// Minimize a 1D function using Brent's method.
    ///
    /// The bracket [ax, cx] must contain a minimum, with bx as the initial interior point.
    /// - Parameters:
    ///   - ax: Left bracket bound
    ///   - bx: Interior point (initial guess for minimum)
    ///   - cx: Right bracket bound
    ///   - tolerance: Convergence tolerance (default 1e-8)
    ///   - maxIterations: Maximum iterations (default 100)
    ///   - function: Closure returning (value, derivative) at x
    /// - Returns: (location, minimum) tuple, or nil if the solver did not converge
    public static func minimizeBrent(
        ax: Double, bx: Double, cx: Double,
        tolerance: Double = 1e-8,
        maxIterations: Int = 100,
        function: @escaping (Double) -> (value: Double, derivative: Double)
    ) -> (location: Double, minimum: Double)? {
        let box = ClosureBox(function)
        let ptr = Unmanaged.passRetained(box).toOpaque()
        defer { Unmanaged<ClosureBox<(Double) -> (value: Double, derivative: Double)>>.fromOpaque(ptr).release() }

        let callback: OCCTMathFuncDerivCallback = { x, value, derivative, context in
            guard let ctx = context else { return false }
            let box = Unmanaged<ClosureBox<(Double) -> (value: Double, derivative: Double)>>.fromOpaque(ctx).takeUnretainedValue()
            let result = box.closure(x)
            value.pointee = result.value
            derivative.pointee = result.derivative
            return true
        }

        var location = 0.0, minimum = 0.0
        let ok = OCCTMathBrentMinimum(callback, ptr, ax, bx, cx, tolerance, Int32(maxIterations), &location, &minimum)
        return ok ? (location, minimum) : nil
    }

    // MARK: - Particle Swarm Optimization (v0.111.0)

    /// Minimize a multivariate function using Particle Swarm Optimization.
    ///
    /// - Parameters:
    ///   - variables: Number of variables
    ///   - lower: Lower bounds for each variable
    ///   - upper: Upper bounds for each variable
    ///   - steps: Step sizes for each variable
    ///   - particles: Number of particles (default 64)
    ///   - iterations: Number of iterations (default 100)
    ///   - function: Closure taking [Double], returning scalar value
    /// - Returns: (point, minimum) tuple, or nil on failure
    public static func particleSwarm(
        variables: Int,
        lower: [Double],
        upper: [Double],
        steps: [Double],
        particles: Int = 64,
        iterations: Int = 100,
        function: @escaping ([Double]) -> Double
    ) -> (point: [Double], minimum: Double)? {
        typealias Fn = ([Double]) -> Double
        let box = ClosureBox(function)
        let ptr = Unmanaged.passRetained(box).toOpaque()
        defer { Unmanaged<ClosureBox<Fn>>.fromOpaque(ptr).release() }

        let callback: OCCTMathMultiVarCallback = { x, n, value, context in
            guard let ctx = context else { return false }
            let box = Unmanaged<ClosureBox<Fn>>.fromOpaque(ctx).takeUnretainedValue()
            let nv = Int(n)
            var input = [Double](repeating: 0, count: nv)
            for i in 0..<nv { input[i] = x[i] }
            value.pointee = box.closure(input)
            return true
        }

        var result = [Double](repeating: 0, count: variables)
        var minimum = 0.0
        let ok = OCCTMathPSO(Int32(variables), callback, ptr,
                               lower, upper, steps,
                               Int32(particles), Int32(iterations), &result, &minimum)
        return ok ? (result, minimum) : nil
    }

    // MARK: - Global Minimization (v0.111.0)

    /// Find the global minimum of a multivariate function using Lipschitz optimization.
    ///
    /// - Parameters:
    ///   - variables: Number of variables
    ///   - lower: Lower bounds for each variable
    ///   - upper: Upper bounds for each variable
    ///   - function: Closure taking [Double], returning scalar value
    /// - Returns: (point, minimum) tuple, or nil on failure
    public static func globalMinimize(
        variables: Int,
        lower: [Double],
        upper: [Double],
        function: @escaping ([Double]) -> Double
    ) -> (point: [Double], minimum: Double)? {
        typealias Fn = ([Double]) -> Double
        let box = ClosureBox(function)
        let ptr = Unmanaged.passRetained(box).toOpaque()
        defer { Unmanaged<ClosureBox<Fn>>.fromOpaque(ptr).release() }

        let callback: OCCTMathMultiVarCallback = { x, n, value, context in
            guard let ctx = context else { return false }
            let box = Unmanaged<ClosureBox<Fn>>.fromOpaque(ctx).takeUnretainedValue()
            let nv = Int(n)
            var input = [Double](repeating: 0, count: nv)
            for i in 0..<nv { input[i] = x[i] }
            value.pointee = box.closure(input)
            return true
        }

        var result = [Double](repeating: 0, count: variables)
        var minimum = 0.0
        let ok = OCCTMathGlobOptMin(Int32(variables), callback, ptr, lower, upper, &result, &minimum)
        return ok ? (result, minimum) : nil
    }

    // MARK: - Find All Roots (v0.111.0)

    /// Find all roots of f(x)=0 in a given range using derivative-based search.
    ///
    /// - Parameters:
    ///   - range: The search interval
    ///   - samples: Number of sample subdivisions (default 20)
    ///   - function: Closure returning (value, derivative) at x
    /// - Returns: Array of root values found
    public static func findAllRoots(
        in range: ClosedRange<Double>,
        samples: Int = 20,
        function: @escaping (Double) -> (value: Double, derivative: Double)
    ) -> [Double] {
        let box = ClosureBox(function)
        let ptr = Unmanaged.passRetained(box).toOpaque()
        defer { Unmanaged<ClosureBox<(Double) -> (value: Double, derivative: Double)>>.fromOpaque(ptr).release() }

        let callback: OCCTMathFuncDerivCallback = { x, value, derivative, context in
            guard let ctx = context else { return false }
            let box = Unmanaged<ClosureBox<(Double) -> (value: Double, derivative: Double)>>.fromOpaque(ctx).takeUnretainedValue()
            let result = box.closure(x)
            value.pointee = result.value
            derivative.pointee = result.derivative
            return true
        }

        var roots = [Double](repeating: 0, count: 100)
        let n = OCCTMathFunctionRoots(callback, ptr, range.lowerBound, range.upperBound,
                                        Int32(samples), &roots, 100)
        return Array(roots.prefix(Int(n)))
    }

    // MARK: - Gauss Integration (v0.111.0)

    /// Integrate a function from lower to upper using Gauss quadrature.
    ///
    /// - Parameters:
    ///   - from: Lower bound of integration
    ///   - to: Upper bound of integration
    ///   - order: Order of Gauss quadrature (default 10)
    ///   - function: Closure returning f(x) at x
    /// - Returns: The integral value
    public static func integrate(
        from lower: Double,
        to upper: Double,
        order: Int = 10,
        function: @escaping (Double) -> Double
    ) -> Double {
        typealias Fn = (Double) -> Double
        let box = ClosureBox(function)
        let ptr = Unmanaged.passRetained(box).toOpaque()
        defer { Unmanaged<ClosureBox<Fn>>.fromOpaque(ptr).release() }

        let callback: OCCTMathSimpleFuncCallback = { x, value, context in
            guard let ctx = context else { return false }
            let box = Unmanaged<ClosureBox<Fn>>.fromOpaque(ctx).takeUnretainedValue()
            value.pointee = box.closure(x)
            return true
        }

        return OCCTMathGaussIntegrate(callback, ptr, lower, upper, Int32(order))
    }

    // MARK: - Newton System Solver (v0.111.0)

    /// Solve a system of equations using Newton's method (NewtonFunctionSetRoot variant).
    ///
    /// - Parameters:
    ///   - variables: Number of variables
    ///   - equations: Number of equations
    ///   - startPoint: Initial guess
    ///   - tolerance: Convergence tolerance (default 1e-8)
    ///   - maxIterations: Maximum iterations (default 100)
    ///   - values: Closure returning equation values
    ///   - jacobian: Closure returning row-major Jacobian
    /// - Returns: Solution point, or nil if not converged
    public static func solveSystemNewton(
        variables: Int,
        equations: Int,
        startPoint: [Double],
        tolerance: Double = 1e-8,
        maxIterations: Int = 100,
        values: @escaping ([Double]) -> [Double],
        jacobian: @escaping ([Double]) -> [Double]
    ) -> [Double]? {
        typealias ValuesClosure = ([Double]) -> [Double]
        typealias JacobianClosure = ([Double]) -> [Double]
        let valBox = ClosureBox(values)
        let jacBox = ClosureBox(jacobian)
        let pair = ClosureBox((valBox, jacBox))
        let ptr = Unmanaged.passRetained(pair).toOpaque()
        defer { Unmanaged<ClosureBox<(ClosureBox<ValuesClosure>, ClosureBox<JacobianClosure>)>>.fromOpaque(ptr).release() }

        let valCallback: OCCTMathFuncSetCallback = { x, nVars, vals, nEqs, context in
            guard let ctx = context else { return false }
            let pair = Unmanaged<ClosureBox<(ClosureBox<ValuesClosure>, ClosureBox<JacobianClosure>)>>.fromOpaque(ctx).takeUnretainedValue()
            let n = Int(nVars)
            var input = [Double](repeating: 0, count: n)
            for i in 0..<n { input[i] = x[i] }
            let result = pair.closure.0.closure(input)
            let m = Int(nEqs)
            for i in 0..<m { vals[i] = result[i] }
            return true
        }

        let derivCallback: OCCTMathFuncSetDerivCallback = { x, nVars, jac, nEqs, context in
            guard let ctx = context else { return false }
            let pair = Unmanaged<ClosureBox<(ClosureBox<ValuesClosure>, ClosureBox<JacobianClosure>)>>.fromOpaque(ctx).takeUnretainedValue()
            let n = Int(nVars)
            var input = [Double](repeating: 0, count: n)
            for i in 0..<n { input[i] = x[i] }
            let result = pair.closure.1.closure(input)
            let total = Int(nEqs) * n
            for i in 0..<total { jac[i] = result[i] }
            return true
        }

        var result = [Double](repeating: 0, count: variables)
        let ok = OCCTMathNewtonFuncSetRoot(Int32(variables), Int32(equations),
                                             valCallback, derivCallback, ptr,
                                             startPoint, tolerance, Int32(maxIterations), &result)
        return ok ? result : nil
    }
}

// MARK: - PolynomialSolver Laguerre Extensions (v0.111.0)

extension PolynomialSolver {

    /// Find real roots of a polynomial of any degree using Laguerre's method.
    ///
    /// Coefficients are in ascending order (constant first):
    /// for polynomial a0 + a1*x + a2*x^2 + ... + an*x^n, pass [a0, a1, ..., an].
    /// - Parameter coefficients: Polynomial coefficients in ascending order
    /// - Returns: Array of real roots (sorted)
    public static func laguerreRoots(coefficients: [Double]) -> [Double] {
        let degree = coefficients.count - 1
        guard degree >= 1 else { return [] }
        var roots = [Double](repeating: 0, count: 20)
        let n = OCCTPolyLaguerreRoots(coefficients, Int32(degree), &roots, 20)
        return Array(roots.prefix(Int(n)))
    }

    /// Find complex roots of a polynomial using Laguerre's method.
    ///
    /// - Parameter coefficients: Polynomial coefficients in ascending order (constant first)
    /// - Returns: Array of (real, imaginary) pairs for complex roots
    public static func laguerreComplexRoots(coefficients: [Double]) -> [(real: Double, imaginary: Double)] {
        let degree = coefficients.count - 1
        guard degree >= 1 else { return [] }
        var realParts = [Double](repeating: 0, count: 20)
        var imagParts = [Double](repeating: 0, count: 20)
        let n = OCCTPolyLaguerreComplexRoots(coefficients, Int32(degree), &realParts, &imagParts, 20)
        return (0..<Int(n)).map { (realParts[$0], imagParts[$0]) }
    }

    /// Find real roots of a quintic polynomial: a*x^5 + b*x^4 + c*x^3 + d*x^2 + e*x + f = 0.
    ///
    /// - Returns: Array of real roots (sorted)
    public static func quinticRoots(a: Double, b: Double, c: Double, d: Double, e: Double, f: Double) -> [Double] {
        var roots = [Double](repeating: 0, count: 5)
        let n = OCCTPolyQuinticRoots(a, b, c, d, e, f, &roots, 5)
        return Array(roots.prefix(Int(n)))
    }
}

// MARK: - BRepLProp Edge Extensions (v0.111.0)

extension Shape {

    /// Get point on an edge at parameter using local properties (BRepLProp_CLProps).
    public func edgeLPropValue(at param: Double) -> SIMD3<Double>? {
        var x = 0.0, y = 0.0, z = 0.0
        OCCTEdgeLPropValue(handle, param, &x, &y, &z)
        return SIMD3(x, y, z)
    }

    /// Get tangent direction on an edge at parameter. Returns nil if tangent is undefined.
    public func edgeTangent(at param: Double) -> SIMD3<Double>? {
        var dx = 0.0, dy = 0.0, dz = 0.0
        let ok = OCCTEdgeLPropTangent(handle, param, &dx, &dy, &dz)
        return ok ? SIMD3(dx, dy, dz) : nil
    }

    /// Get curvature on an edge at parameter using local properties.
    public func edgeCurvatureLP(at param: Double) -> Double {
        return OCCTEdgeLPropCurvature(handle, param)
    }

    /// Get normal direction on an edge at parameter.
    public func edgeNormalLP(at param: Double) -> SIMD3<Double> {
        var dx = 0.0, dy = 0.0, dz = 0.0
        OCCTEdgeLPropNormal(handle, param, &dx, &dy, &dz)
        return SIMD3(dx, dy, dz)
    }

    /// Get centre of curvature on an edge at parameter.
    public func edgeCentreOfCurvature(at param: Double) -> SIMD3<Double> {
        var x = 0.0, y = 0.0, z = 0.0
        OCCTEdgeLPropCentreOfCurvature(handle, param, &x, &y, &z)
        return SIMD3(x, y, z)
    }

    /// Get first derivative on an edge at parameter.
    public func edgeLPropD1(at param: Double) -> SIMD3<Double> {
        var d1x = 0.0, d1y = 0.0, d1z = 0.0
        OCCTEdgeLPropD1(handle, param, &d1x, &d1y, &d1z)
        return SIMD3(d1x, d1y, d1z)
    }
}

// MARK: - BRepLProp Face Extensions (v0.111.0)

extension Shape {

    /// Get point on a face at (u, v) using local surface properties (BRepLProp_SLProps).
    public func faceLPropValue(u: Double, v: Double) -> SIMD3<Double> {
        var x = 0.0, y = 0.0, z = 0.0
        OCCTFaceLPropValue(handle, u, v, &x, &y, &z)
        return SIMD3(x, y, z)
    }

    /// Get normal on a face at (u, v). Returns nil if normal is undefined.
    public func faceLPropNormal(u: Double, v: Double) -> SIMD3<Double>? {
        var dx = 0.0, dy = 0.0, dz = 0.0
        let ok = OCCTFaceLPropNormal(handle, u, v, &dx, &dy, &dz)
        return ok ? SIMD3(dx, dy, dz) : nil
    }

    /// Get maximum principal curvature on a face at (u, v).
    public func faceLPropMaxCurvature(u: Double, v: Double) -> Double {
        return OCCTFaceLPropMaxCurvature(handle, u, v)
    }

    /// Get minimum principal curvature on a face at (u, v).
    public func faceLPropMinCurvature(u: Double, v: Double) -> Double {
        return OCCTFaceLPropMinCurvature(handle, u, v)
    }

    /// Get mean curvature on a face at (u, v).
    public func faceLPropMeanCurvature(u: Double, v: Double) -> Double {
        return OCCTFaceLPropMeanCurvature(handle, u, v)
    }

    /// Get Gaussian curvature on a face at (u, v).
    public func faceLPropGaussianCurvature(u: Double, v: Double) -> Double {
        return OCCTFaceLPropGaussianCurvature(handle, u, v)
    }

    /// Check if a face is umbilic at (u, v) (all principal curvatures equal).
    public func faceLPropIsUmbilic(u: Double, v: Double) -> Bool {
        return OCCTFaceLPropIsUmbilic(handle, u, v)
    }

    /// Get tangent in U direction on a face at (u, v). Returns nil if tangent is undefined.
    public func faceLPropTangentU(u: Double, v: Double) -> SIMD3<Double>? {
        var dx = 0.0, dy = 0.0, dz = 0.0
        let ok = OCCTFaceLPropTangentU(handle, u, v, &dx, &dy, &dz)
        return ok ? SIMD3(dx, dy, dz) : nil
    }
}

// MARK: - GridEval Curve3D Extensions (v0.111.0)

extension Curve3D {

    /// Evaluate curve at multiple parameters using GeomGridEval_Curve (optimized batch D0).
    public func gridEvalD0(params: [Double]) -> [SIMD3<Double>] {
        let count = params.count
        guard count > 0 else { return [] }
        var xs = [Double](repeating: 0, count: count)
        var ys = [Double](repeating: 0, count: count)
        var zs = [Double](repeating: 0, count: count)
        OCCTGridEvalCurveD0(handle, params, Int32(count), &xs, &ys, &zs)
        return (0..<count).map { SIMD3(xs[$0], ys[$0], zs[$0]) }
    }

    /// Evaluate curve at multiple parameters using GeomGridEval_Curve (optimized batch D1).
    public func gridEvalD1(params: [Double]) -> [(point: SIMD3<Double>, d1: SIMD3<Double>)] {
        let count = params.count
        guard count > 0 else { return [] }
        var xs = [Double](repeating: 0, count: count)
        var ys = [Double](repeating: 0, count: count)
        var zs = [Double](repeating: 0, count: count)
        var d1xs = [Double](repeating: 0, count: count)
        var d1ys = [Double](repeating: 0, count: count)
        var d1zs = [Double](repeating: 0, count: count)
        OCCTGridEvalCurveD1(handle, params, Int32(count), &xs, &ys, &zs, &d1xs, &d1ys, &d1zs)
        return (0..<count).map { (SIMD3(xs[$0], ys[$0], zs[$0]), SIMD3(d1xs[$0], d1ys[$0], d1zs[$0])) }
    }
}

// MARK: - GridEval Curve2D Extensions (v0.111.0)

extension Curve2D {

    /// Evaluate 2D curve at multiple parameters using Geom2dGridEval_Curve (optimized batch D0).
    public func gridEvalD0(params: [Double]) -> [SIMD2<Double>] {
        let count = params.count
        guard count > 0 else { return [] }
        var xs = [Double](repeating: 0, count: count)
        var ys = [Double](repeating: 0, count: count)
        OCCTGridEvalCurve2dD0(handle, params, Int32(count), &xs, &ys)
        return (0..<count).map { SIMD2(xs[$0], ys[$0]) }
    }

    /// Evaluate 2D curve at multiple parameters using Geom2dGridEval_Curve (optimized batch D1).
    public func gridEvalD1(params: [Double]) -> [(point: SIMD2<Double>, d1: SIMD2<Double>)] {
        let count = params.count
        guard count > 0 else { return [] }
        var xs = [Double](repeating: 0, count: count)
        var ys = [Double](repeating: 0, count: count)
        var d1xs = [Double](repeating: 0, count: count)
        var d1ys = [Double](repeating: 0, count: count)
        OCCTGridEvalCurve2dD1(handle, params, Int32(count), &xs, &ys, &d1xs, &d1ys)
        return (0..<count).map { (SIMD2(xs[$0], ys[$0]), SIMD2(d1xs[$0], d1ys[$0])) }
    }
}

// MARK: - GridEval Surface Extensions (v0.111.0)

extension Surface {

    /// Evaluate surface at grid of (u, v) parameters using GeomGridEval_Surface (optimized batch D0).
    /// Returns row-major array of points with dimensions [uParams.count x vParams.count].
    public func gridEvalD0(uParams: [Double], vParams: [Double]) -> [SIMD3<Double>] {
        let uCount = uParams.count
        let vCount = vParams.count
        guard uCount > 0 && vCount > 0 else { return [] }
        let total = uCount * vCount
        var xs = [Double](repeating: 0, count: total)
        var ys = [Double](repeating: 0, count: total)
        var zs = [Double](repeating: 0, count: total)
        OCCTGridEvalSurfaceD0(handle, uParams, Int32(uCount), vParams, Int32(vCount), &xs, &ys, &zs)
        return (0..<total).map { SIMD3(xs[$0], ys[$0], zs[$0]) }
    }

    /// Evaluate surface at grid of (u, v) parameters using GeomGridEval_Surface (optimized batch D1).
    /// Returns row-major array of (point, d1u, d1v) tuples with dimensions [uParams.count x vParams.count].
    public func gridEvalD1(uParams: [Double], vParams: [Double]) -> [(point: SIMD3<Double>, d1u: SIMD3<Double>, d1v: SIMD3<Double>)] {
        let uCount = uParams.count
        let vCount = vParams.count
        guard uCount > 0 && vCount > 0 else { return [] }
        let total = uCount * vCount
        var xs = [Double](repeating: 0, count: total)
        var ys = [Double](repeating: 0, count: total)
        var zs = [Double](repeating: 0, count: total)
        var d1uxs = [Double](repeating: 0, count: total)
        var d1uys = [Double](repeating: 0, count: total)
        var d1uzs = [Double](repeating: 0, count: total)
        var d1vxs = [Double](repeating: 0, count: total)
        var d1vys = [Double](repeating: 0, count: total)
        var d1vzs = [Double](repeating: 0, count: total)
        OCCTGridEvalSurfaceD1(handle, uParams, Int32(uCount), vParams, Int32(vCount),
                                &xs, &ys, &zs, &d1uxs, &d1uys, &d1uzs, &d1vxs, &d1vys, &d1vzs)
        return (0..<total).map {
            (SIMD3(xs[$0], ys[$0], zs[$0]),
             SIMD3(d1uxs[$0], d1uys[$0], d1uzs[$0]),
             SIMD3(d1vxs[$0], d1vys[$0], d1vzs[$0]))
        }
    }
}

// MARK: - Curve3D Evaluation (v0.110.0)

extension Curve3D {

    /// Evaluate the curve point at parameter u.
    public func evalD0(at u: Double) -> SIMD3<Double> {
        var x = 0.0, y = 0.0, z = 0.0
        OCCTCurve3DEvalD0(handle, u, &x, &y, &z)
        return SIMD3(x, y, z)
    }

    /// Evaluate the curve point and first derivative at parameter u.
    public func evalD1(at u: Double) -> (point: SIMD3<Double>, d1: SIMD3<Double>) {
        var px = 0.0, py = 0.0, pz = 0.0
        var d1x = 0.0, d1y = 0.0, d1z = 0.0
        OCCTCurve3DEvalD1(handle, u, &px, &py, &pz, &d1x, &d1y, &d1z)
        return (SIMD3(px, py, pz), SIMD3(d1x, d1y, d1z))
    }

    /// Evaluate the curve point, first and second derivatives at parameter u.
    public func evalD2(at u: Double) -> (point: SIMD3<Double>, d1: SIMD3<Double>, d2: SIMD3<Double>) {
        var px = 0.0, py = 0.0, pz = 0.0
        var d1x = 0.0, d1y = 0.0, d1z = 0.0
        var d2x = 0.0, d2y = 0.0, d2z = 0.0
        OCCTCurve3DEvalD2(handle, u, &px, &py, &pz, &d1x, &d1y, &d1z, &d2x, &d2y, &d2z)
        return (SIMD3(px, py, pz), SIMD3(d1x, d1y, d1z), SIMD3(d2x, d2y, d2z))
    }

    /// Evaluate the curve point, first, second, and third derivatives at parameter u.
    public func evalD3(at u: Double) -> (point: SIMD3<Double>, d1: SIMD3<Double>, d2: SIMD3<Double>, d3: SIMD3<Double>) {
        var px = 0.0, py = 0.0, pz = 0.0
        var d1x = 0.0, d1y = 0.0, d1z = 0.0
        var d2x = 0.0, d2y = 0.0, d2z = 0.0
        var d3x = 0.0, d3y = 0.0, d3z = 0.0
        OCCTCurve3DEvalD3(handle, u, &px, &py, &pz, &d1x, &d1y, &d1z, &d2x, &d2y, &d2z, &d3x, &d3y, &d3z)
        return (SIMD3(px, py, pz), SIMD3(d1x, d1y, d1z), SIMD3(d2x, d2y, d2z), SIMD3(d3x, d3y, d3z))
    }

    /// Evaluate curve points at multiple parameters (batch D0).
    public func evalBatchD0(params: [Double]) -> [SIMD3<Double>] {
        let count = params.count
        var xs = [Double](repeating: 0, count: count)
        var ys = [Double](repeating: 0, count: count)
        var zs = [Double](repeating: 0, count: count)
        OCCTCurve3DEvalBatchD0(handle, params, Int32(count), &xs, &ys, &zs)
        return (0..<count).map { SIMD3(xs[$0], ys[$0], zs[$0]) }
    }

    /// Evaluate curve points and first derivatives at multiple parameters (batch D1).
    public func evalBatchD1(params: [Double]) -> [(point: SIMD3<Double>, d1: SIMD3<Double>)] {
        let count = params.count
        var xs = [Double](repeating: 0, count: count)
        var ys = [Double](repeating: 0, count: count)
        var zs = [Double](repeating: 0, count: count)
        var d1xs = [Double](repeating: 0, count: count)
        var d1ys = [Double](repeating: 0, count: count)
        var d1zs = [Double](repeating: 0, count: count)
        OCCTCurve3DEvalBatchD1(handle, params, Int32(count), &xs, &ys, &zs, &d1xs, &d1ys, &d1zs)
        return (0..<count).map { (SIMD3(xs[$0], ys[$0], zs[$0]), SIMD3(d1xs[$0], d1ys[$0], d1zs[$0])) }
    }
}

// MARK: - Curve2D Evaluation (v0.110.0)

extension Curve2D {

    /// Evaluate the 2D curve point at parameter u.
    public func evalD0(at u: Double) -> SIMD2<Double> {
        var x = 0.0, y = 0.0
        OCCTCurve2DEvalD0(handle, u, &x, &y)
        return SIMD2(x, y)
    }

    /// Evaluate the 2D curve point and first derivative at parameter u.
    public func evalD1(at u: Double) -> (point: SIMD2<Double>, d1: SIMD2<Double>) {
        var px = 0.0, py = 0.0, d1x = 0.0, d1y = 0.0
        OCCTCurve2DEvalD1(handle, u, &px, &py, &d1x, &d1y)
        return (SIMD2(px, py), SIMD2(d1x, d1y))
    }

    /// Evaluate the 2D curve point, first and second derivatives at parameter u.
    public func evalD2(at u: Double) -> (point: SIMD2<Double>, d1: SIMD2<Double>, d2: SIMD2<Double>) {
        var px = 0.0, py = 0.0, d1x = 0.0, d1y = 0.0, d2x = 0.0, d2y = 0.0
        OCCTCurve2DEvalD2(handle, u, &px, &py, &d1x, &d1y, &d2x, &d2y)
        return (SIMD2(px, py), SIMD2(d1x, d1y), SIMD2(d2x, d2y))
    }

    /// Evaluate 2D curve points at multiple parameters (batch D0).
    public func evalBatchD0(params: [Double]) -> [SIMD2<Double>] {
        let count = params.count
        var xs = [Double](repeating: 0, count: count)
        var ys = [Double](repeating: 0, count: count)
        OCCTCurve2DEvalBatchD0(handle, params, Int32(count), &xs, &ys)
        return (0..<count).map { SIMD2(xs[$0], ys[$0]) }
    }

    /// Evaluate 2D curve points and first derivatives at multiple parameters (batch D1).
    public func evalBatchD1(params: [Double]) -> [(point: SIMD2<Double>, d1: SIMD2<Double>)] {
        let count = params.count
        var xs = [Double](repeating: 0, count: count)
        var ys = [Double](repeating: 0, count: count)
        var d1xs = [Double](repeating: 0, count: count)
        var d1ys = [Double](repeating: 0, count: count)
        OCCTCurve2DEvalBatchD1(handle, params, Int32(count), &xs, &ys, &d1xs, &d1ys)
        return (0..<count).map { (SIMD2(xs[$0], ys[$0]), SIMD2(d1xs[$0], d1ys[$0])) }
    }
}

// MARK: - Surface Evaluation (v0.110.0)

extension Surface {

    /// Evaluate the surface point at (u, v).
    public func evalD0(u: Double, v: Double) -> SIMD3<Double> {
        var x = 0.0, y = 0.0, z = 0.0
        OCCTSurfaceEvalD0(handle, u, v, &x, &y, &z)
        return SIMD3(x, y, z)
    }

    /// Evaluate the surface point and first partial derivatives at (u, v).
    public func evalD1(u: Double, v: Double) -> (point: SIMD3<Double>, d1u: SIMD3<Double>, d1v: SIMD3<Double>) {
        var px = 0.0, py = 0.0, pz = 0.0
        var d1ux = 0.0, d1uy = 0.0, d1uz = 0.0
        var d1vx = 0.0, d1vy = 0.0, d1vz = 0.0
        OCCTSurfaceEvalD1(handle, u, v, &px, &py, &pz, &d1ux, &d1uy, &d1uz, &d1vx, &d1vy, &d1vz)
        return (SIMD3(px, py, pz), SIMD3(d1ux, d1uy, d1uz), SIMD3(d1vx, d1vy, d1vz))
    }

    /// Evaluate the surface point, first and second partial derivatives at (u, v).
    public func evalD2(u: Double, v: Double) -> (point: SIMD3<Double>, d1u: SIMD3<Double>, d1v: SIMD3<Double>, d2u: SIMD3<Double>, d2v: SIMD3<Double>, d2uv: SIMD3<Double>) {
        var px = 0.0, py = 0.0, pz = 0.0
        var d1ux = 0.0, d1uy = 0.0, d1uz = 0.0
        var d1vx = 0.0, d1vy = 0.0, d1vz = 0.0
        var d2ux = 0.0, d2uy = 0.0, d2uz = 0.0
        var d2vx = 0.0, d2vy = 0.0, d2vz = 0.0
        var d2uvx = 0.0, d2uvy = 0.0, d2uvz = 0.0
        OCCTSurfaceEvalD2(handle, u, v, &px, &py, &pz,
                            &d1ux, &d1uy, &d1uz, &d1vx, &d1vy, &d1vz,
                            &d2ux, &d2uy, &d2uz, &d2vx, &d2vy, &d2vz,
                            &d2uvx, &d2uvy, &d2uvz)
        return (SIMD3(px, py, pz), SIMD3(d1ux, d1uy, d1uz), SIMD3(d1vx, d1vy, d1vz),
                SIMD3(d2ux, d2uy, d2uz), SIMD3(d2vx, d2vy, d2vz), SIMD3(d2uvx, d2uvy, d2uvz))
    }
}

// MARK: - math_NewtonMinimum (v0.111.1)

extension MathSolver {

    /// Minimize using Newton's method with Hessian (second derivatives).
    /// The closure takes x[n] and returns (value, gradient[n], hessian[n*n] row-major).
    /// This is the most precise minimizer when the Hessian is available.
    public static func minimizeNewton(
        variables n: Int,
        startPoint: [Double],
        tolerance: Double = 1e-8,
        maxIterations: Int = 40,
        function: @escaping ([Double]) -> (value: Double, gradient: [Double], hessian: [Double])
    ) -> (point: [Double], minimum: Double)? {
        typealias Closure = ([Double]) -> (value: Double, gradient: [Double], hessian: [Double])
        class Box { let fn: Closure; init(_ f: @escaping Closure) { fn = f } }
        let box = Box(function)
        let ptr = Unmanaged.passRetained(box).toOpaque()
        defer { Unmanaged<Box>.fromOpaque(ptr).release() }

        let callback: OCCTMathHessianCallback = { x, nVars, value, gradient, hessian, context in
            guard let ctx = context else { return false }
            let box = Unmanaged<Box>.fromOpaque(ctx).takeUnretainedValue()
            let n = Int(nVars)
            let input = Array(UnsafeBufferPointer(start: x, count: n))
            let result = box.fn(input)
            value.pointee = result.value
            for i in 0..<n { gradient[i] = result.gradient[i] }
            for i in 0..<(n*n) { hessian[i] = result.hessian[i] }
            return true
        }

        var result = [Double](repeating: 0, count: n)
        var minimum = 0.0
        let ok = OCCTMathNewtonMinimum(Int32(n), callback, ptr,
                                        startPoint, tolerance, Int32(maxIterations),
                                        &result, &minimum)
        return ok ? (result, minimum) : nil
    }
}
