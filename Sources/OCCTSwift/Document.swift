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
