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
