//
//  OCCTBridge_BRepGraph.mm
//  OCCTSwift
//
//  Extracted from OCCTBridge.mm — issue #99 phase 1.
//
//  Wraps OCCT 8.0.0 BRepGraph + EditorView + MeshView + ML export surface.
//  Originally implemented across v0.129.0 → v0.164.0; lifted into its own
//  translation unit so the main bridge file isn't 58k lines and so changes
//  here don't trigger a rebuild of unrelated bridge areas.
//
//  Public C surface (OCCTBRepGraph*, OCCTPolyTriangulation*, etc.) lives in
//  ../include/OCCTBridge.h. No symbol changes — this is a pure file move.
//

#import "../include/OCCTBridge.h"
#import "OCCTBridge_Internal.h"

// Area-specific OCCT headers — the foundation set + handle wrappers come from
// OCCTBridge_Internal.h, this block is just the BRepGraph-block extras.

#include <TopAbs_Orientation.hxx>
#include <TopLoc_Location.hxx>
#include <TopoDS.hxx>
#include <gp_Pnt.hxx>
#include <gp_Pnt2d.hxx>
#include <gp_Vec.hxx>
#include <gp_Trsf.hxx>
#include <Poly_Triangle.hxx>
#include <BRepTools.hxx>
#include <GeomLProp_SLProps.hxx>
#include <Precision.hxx>
#include <NCollection_Array1.hxx>
#include <NCollection_DataMap.hxx>
#include <NCollection_DynamicArray.hxx>
#include <TCollection_AsciiString.hxx>
#include <GeomAbs_Shape.hxx>

// === Local static helper duplicated from OCCTBridge.mm ===
//
// `static` ensures internal linkage so the symbol doesn't conflict with the
// canonical definition over there. The function bodies are identical.

static GeomAbs_Shape continuityFromInt(int val) {
    switch (val) {
        case 0: return GeomAbs_C0;
        case 1: return GeomAbs_C1;
        case 2: return GeomAbs_C2;
        case 3: return GeomAbs_C3;
        default: return GeomAbs_CN;
    }
}

// === Extracted BRepGraph block ===
//
// Verbatim copy of lines 55486–EOF from OCCTBridge.mm at the time of issue #99.

// MARK: - BRepGraph (v0.129.0)

#include <BRepGraph.hxx>
#include <BRepGraph_Builder.hxx>
#include <BRepGraph_TopoView.hxx>
#include <BRepGraph_MeshView.hxx>
#include <BRepGraph_Compact.hxx>
#include <BRepGraph_Deduplicate.hxx>
#include <BRepGraph_Validate.hxx>
#include <BRepGraph_ChildExplorer.hxx>
#include <BRepGraph_ParentExplorer.hxx>
#include <BRepGraph_NodeId.hxx>

struct OCCTBRepGraph {
    BRepGraph graph;
};

static BRepGraph_NodeId::Kind kindFromInt(int32_t k) {
    switch (k) {
        case 0: return BRepGraph_NodeId::Kind::Solid;
        case 1: return BRepGraph_NodeId::Kind::Shell;
        case 2: return BRepGraph_NodeId::Kind::Face;
        case 3: return BRepGraph_NodeId::Kind::Wire;
        case 4: return BRepGraph_NodeId::Kind::Edge;
        case 5: return BRepGraph_NodeId::Kind::Vertex;
        case 6: return BRepGraph_NodeId::Kind::Compound;
        case 7: return BRepGraph_NodeId::Kind::CompSolid;
        case 8: return BRepGraph_NodeId::Kind::CoEdge;
        default: return BRepGraph_NodeId::Kind::Solid;
    }
}

OCCTBRepGraphRef OCCTBRepGraphCreate(OCCTShapeRef shape, bool parallel) {
    if (!shape) return nullptr;
    try {
        auto ref = new OCCTBRepGraph();
        BRepGraph_Builder::Options opts;
        opts.Parallel = parallel;
        opts.CreateAutoProduct = false; // preserve pre-beta1 behaviour: no auto Product/Occurrence wrap
        auto result = BRepGraph_Builder::Add(ref->graph, *(const TopoDS_Shape*)shape, opts);
        if (!result.Ok || !ref->graph.IsDone()) { delete ref; return nullptr; }
        return ref;
    } catch (...) { return nullptr; }
}

void OCCTBRepGraphRelease(OCCTBRepGraphRef graph) { delete graph; }

bool OCCTBRepGraphIsDone(OCCTBRepGraphRef graph) {
    if (!graph) return false;
    return graph->graph.IsDone();
}

int32_t OCCTBRepGraphNbNodes(OCCTBRepGraphRef graph) {
    if (!graph) return 0;
    return graph->graph.Topo().Gen().NbNodes();
}

// --- Topology Counts ---

int32_t OCCTBRepGraphNbFaces(OCCTBRepGraphRef g) { return g ? g->graph.Topo().Faces().Nb() : 0; }
int32_t OCCTBRepGraphNbActiveFaces(OCCTBRepGraphRef g) { return g ? g->graph.Topo().Faces().NbActive() : 0; }
int32_t OCCTBRepGraphNbEdges(OCCTBRepGraphRef g) { return g ? g->graph.Topo().Edges().Nb() : 0; }
int32_t OCCTBRepGraphNbActiveEdges(OCCTBRepGraphRef g) { return g ? g->graph.Topo().Edges().NbActive() : 0; }
int32_t OCCTBRepGraphNbVertices(OCCTBRepGraphRef g) { return g ? g->graph.Topo().Vertices().Nb() : 0; }
int32_t OCCTBRepGraphNbActiveVertices(OCCTBRepGraphRef g) { return g ? g->graph.Topo().Vertices().NbActive() : 0; }
int32_t OCCTBRepGraphNbWires(OCCTBRepGraphRef g) { return g ? g->graph.Topo().Wires().Nb() : 0; }
int32_t OCCTBRepGraphNbShells(OCCTBRepGraphRef g) { return g ? g->graph.Topo().Shells().Nb() : 0; }
int32_t OCCTBRepGraphNbSolids(OCCTBRepGraphRef g) { return g ? g->graph.Topo().Solids().Nb() : 0; }
int32_t OCCTBRepGraphNbCoEdges(OCCTBRepGraphRef g) { return g ? g->graph.Topo().CoEdges().Nb() : 0; }
int32_t OCCTBRepGraphNbCompounds(OCCTBRepGraphRef g) { return g ? g->graph.Topo().Compounds().Nb() : 0; }

// --- Geometry Counts ---

int32_t OCCTBRepGraphNbSurfaces(OCCTBRepGraphRef g) { return g ? g->graph.Topo().Geometry().NbSurfaces() : 0; }
int32_t OCCTBRepGraphNbCurves3D(OCCTBRepGraphRef g) { return g ? g->graph.Topo().Geometry().NbCurves3D() : 0; }
int32_t OCCTBRepGraphNbCurves2D(OCCTBRepGraphRef g) { return g ? g->graph.Topo().Geometry().NbCurves2D() : 0; }

// --- Face Queries ---

int32_t OCCTBRepGraphFaceAdjacentCount(OCCTBRepGraphRef g, int32_t faceIndex) {
    if (!g) return 0;
    try {
        auto adj = g->graph.Topo().Faces().Adjacent(BRepGraph_FaceId(faceIndex), g->graph.Allocator());
        return (int32_t)adj.Size();
    } catch (...) { return 0; }
}

void OCCTBRepGraphFaceAdjacentIndices(OCCTBRepGraphRef g, int32_t faceIndex, int32_t* outIndices) {
    if (!g || !outIndices) return;
    try {
        auto adj = g->graph.Topo().Faces().Adjacent(BRepGraph_FaceId(faceIndex), g->graph.Allocator());
        for (int i = 0; i < adj.Size(); i++)
            outIndices[i] = adj(i).Index;
    } catch (...) {}
}

int32_t OCCTBRepGraphFaceSharedEdgeCount(OCCTBRepGraphRef g, int32_t faceA, int32_t faceB) {
    if (!g) return 0;
    try {
        auto shared = g->graph.Topo().Faces().SharedEdges(
            BRepGraph_FaceId(faceA), BRepGraph_FaceId(faceB), g->graph.Allocator());
        return (int32_t)shared.Size();
    } catch (...) { return 0; }
}

void OCCTBRepGraphFaceSharedEdgeIndices(OCCTBRepGraphRef g, int32_t faceA, int32_t faceB, int32_t* outIndices) {
    if (!g || !outIndices) return;
    try {
        auto shared = g->graph.Topo().Faces().SharedEdges(
            BRepGraph_FaceId(faceA), BRepGraph_FaceId(faceB), g->graph.Allocator());
        for (int i = 0; i < shared.Size(); i++)
            outIndices[i] = shared(i).Index;
    } catch (...) {}
}

int32_t OCCTBRepGraphFaceOuterWire(OCCTBRepGraphRef g, int32_t faceIndex) {
    if (!g) return -1;
    try {
        auto wid = g->graph.Topo().Faces().OuterWire(BRepGraph_FaceId(faceIndex));
        return wid.Index;
    } catch (...) { return -1; }
}

// --- Edge Queries ---

int32_t OCCTBRepGraphEdgeNbFaces(OCCTBRepGraphRef g, int32_t edgeIndex) {
    if (!g) return 0;
    try { return g->graph.Topo().Edges().NbFaces(BRepGraph_EdgeId(edgeIndex)); }
    catch (...) { return 0; }
}

void OCCTBRepGraphEdgeFaceIndices(OCCTBRepGraphRef g, int32_t edgeIndex, int32_t* outIndices) {
    if (!g || !outIndices) return;
    try {
        auto& faces = g->graph.Topo().Edges().Faces(BRepGraph_EdgeId(edgeIndex));
        for (int i = 0; i < faces.Size(); i++)
            outIndices[i] = faces(i).Index;
    } catch (...) {}
}

bool OCCTBRepGraphEdgeIsBoundary(OCCTBRepGraphRef g, int32_t edgeIndex) {
    if (!g) return false;
    try { return g->graph.Topo().Edges().IsBoundary(BRepGraph_EdgeId(edgeIndex)); }
    catch (...) { return false; }
}

bool OCCTBRepGraphEdgeIsManifold(OCCTBRepGraphRef g, int32_t edgeIndex) {
    if (!g) return false;
    try { return g->graph.Topo().Edges().IsManifold(BRepGraph_EdgeId(edgeIndex)); }
    catch (...) { return false; }
}

int32_t OCCTBRepGraphEdgeAdjacentCount(OCCTBRepGraphRef g, int32_t edgeIndex) {
    if (!g) return 0;
    try {
        auto adj = g->graph.Topo().Edges().Adjacent(BRepGraph_EdgeId(edgeIndex), g->graph.Allocator());
        return (int32_t)adj.Size();
    } catch (...) { return 0; }
}

void OCCTBRepGraphEdgeAdjacentIndices(OCCTBRepGraphRef g, int32_t edgeIndex, int32_t* outIndices) {
    if (!g || !outIndices) return;
    try {
        auto adj = g->graph.Topo().Edges().Adjacent(BRepGraph_EdgeId(edgeIndex), g->graph.Allocator());
        for (int i = 0; i < adj.Size(); i++)
            outIndices[i] = adj(i).Index;
    } catch (...) {}
}

// --- Vertex Queries ---

int32_t OCCTBRepGraphVertexEdgeCount(OCCTBRepGraphRef g, int32_t vertexIndex) {
    if (!g) return 0;
    try {
        auto& edges = g->graph.Topo().Vertices().Edges(BRepGraph_VertexId(vertexIndex));
        return (int32_t)edges.Size();
    } catch (...) { return 0; }
}

void OCCTBRepGraphVertexEdgeIndices(OCCTBRepGraphRef g, int32_t vertexIndex, int32_t* outIndices) {
    if (!g || !outIndices) return;
    try {
        auto& edges = g->graph.Topo().Vertices().Edges(BRepGraph_VertexId(vertexIndex));
        for (int i = 0; i < edges.Size(); i++)
            outIndices[i] = edges(i).Index;
    } catch (...) {}
}

// --- Child Explorer ---

int32_t OCCTBRepGraphChildCount(OCCTBRepGraphRef g, int32_t rootKind, int32_t rootIndex, int32_t targetKind) {
    if (!g) return 0;
    try {
        BRepGraph_NodeId root(kindFromInt(rootKind), rootIndex);
        BRepGraph_ChildExplorer explorer(g->graph, root, kindFromInt(targetKind));
        int32_t count = 0;
        for (; explorer.More(); explorer.Next()) count++;
        return count;
    } catch (...) { return 0; }
}

int32_t OCCTBRepGraphChildIndices(OCCTBRepGraphRef g,
                                    int32_t rootKind, int32_t rootIndex,
                                    int32_t targetKind,
                                    int32_t* outIndices, int32_t maxCount) {
    if (!g || !outIndices) return 0;
    try {
        BRepGraph_NodeId root(kindFromInt(rootKind), rootIndex);
        BRepGraph_ChildExplorer explorer(g->graph, root, kindFromInt(targetKind));
        int32_t total = 0;
        for (; explorer.More(); explorer.Next()) {
            if (total < maxCount) {
                BRepGraphInc::NodeInstance usage = explorer.Current();
                outIndices[total] = usage.DefId.Index;
            }
            total++;
        }
        return total;
    } catch (...) { return 0; }
}

// --- Parent Explorer ---

int32_t OCCTBRepGraphParentCount(OCCTBRepGraphRef g, int32_t nodeKind, int32_t nodeIndex) {
    if (!g) return 0;
    try {
        BRepGraph_NodeId node(kindFromInt(nodeKind), nodeIndex);
        BRepGraph_ParentExplorer explorer(g->graph, node);
        int32_t count = 0;
        for (; explorer.More(); explorer.Next()) count++;
        return count;
    } catch (...) { return 0; }
}

// --- Validate ---

bool OCCTBRepGraphValidate(OCCTBRepGraphRef g) {
    if (!g) return false;
    try { return BRepGraph_Validate::Perform(g->graph).IsValid(); }
    catch (...) { return false; }
}

int32_t OCCTBRepGraphValidateIssueCount(OCCTBRepGraphRef g) {
    if (!g) return -1;
    try { return (int32_t)BRepGraph_Validate::Perform(g->graph).Issues.Size(); }
    catch (...) { return -1; }
}

OCCTBRepGraphValidateResult OCCTBRepGraphValidateDetailed(OCCTBRepGraphRef g) {
    OCCTBRepGraphValidateResult r = {false, 0, 0};
    if (!g) return r;
    try {
        auto result = BRepGraph_Validate::Perform(g->graph);
        r.isValid = result.IsValid();
        r.errorCount = result.NbIssues(BRepGraph_Validate::Severity::Error);
        r.warningCount = result.NbIssues(BRepGraph_Validate::Severity::Warning);
    } catch (...) {}
    return r;
}

// --- Compact ---

OCCTBRepGraphCompactResult OCCTBRepGraphCompact(OCCTBRepGraphRef g) {
    OCCTBRepGraphCompactResult r = {0, 0, 0, 0};
    if (!g) return r;
    try {
        auto result = BRepGraph_Compact::Perform(g->graph);
        r.removedVertices = result.NbRemovedVertices;
        r.removedEdges = result.NbRemovedEdges;
        r.removedFaces = result.NbRemovedFaces;
        r.nodesAfter = result.NbNodesAfter;
    } catch (...) {}
    return r;
}

// --- Deduplicate ---

OCCTBRepGraphDeduplicateResult OCCTBRepGraphDeduplicate(OCCTBRepGraphRef g) {
    OCCTBRepGraphDeduplicateResult r = {0, 0, 0, 0};
    if (!g) return r;
    try {
        auto result = BRepGraph_Deduplicate::Perform(g->graph);
        r.canonicalSurfaces = result.NbCanonicalSurfaces;
        r.canonicalCurves = result.NbCanonicalCurves;
        r.surfaceRewrites = result.NbSurfaceRewrites;
        r.curveRewrites = result.NbCurveRewrites;
    } catch (...) {}
    return r;
}

// --- Node Removal ---

bool OCCTBRepGraphIsRemoved(OCCTBRepGraphRef g, int32_t nodeKind, int32_t nodeIndex) {
    if (!g) return false;
    try {
        BRepGraph_NodeId nid(kindFromInt(nodeKind), nodeIndex);
        return g->graph.Topo().Gen().IsRemoved(nid);
    } catch (...) { return false; }
}

// --- Root Nodes ---

int32_t OCCTBRepGraphRootCount(OCCTBRepGraphRef g) {
    if (!g) return 0;
    try { return (int32_t)g->graph.RootProductIds().Size(); }
    catch (...) { return 0; }
}

void OCCTBRepGraphRootNodes(OCCTBRepGraphRef g, int32_t* outKinds, int32_t* outIndices) {
    if (!g || !outKinds || !outIndices) return;
    try {
        // OCCT 8.0.0 beta1: root iteration is now Products only (was: arbitrary node kinds).
        const auto& roots = g->graph.RootProductIds();
        for (int i = 0; i < (int)roots.Size(); i++) {
            outKinds[i] = (int32_t)BRepGraph_NodeId::Kind::Product;
            outIndices[i] = roots(i).Index;
        }
    } catch (...) {}
}

// --- Stats ---

OCCTBRepGraphStats OCCTBRepGraphGetStats(OCCTBRepGraphRef g) {
    OCCTBRepGraphStats s = {};
    if (!g) return s;
    try {
        auto& topo = g->graph.Topo();
        s.solids = topo.Solids().Nb();
        s.shells = topo.Shells().Nb();
        s.faces = topo.Faces().Nb();
        s.wires = topo.Wires().Nb();
        s.edges = topo.Edges().Nb();
        s.vertices = topo.Vertices().Nb();
        s.coedges = topo.CoEdges().Nb();
        s.compounds = topo.Compounds().Nb();
        s.totalNodes = topo.Gen().NbNodes();
        s.surfaces = topo.Geometry().NbSurfaces();
        s.curves3d = topo.Geometry().NbCurves3D();
        s.curves2d = topo.Geometry().NbCurves2D();
    } catch (...) {}
    return s;
}

// end of v0.129.0 implementations

// MARK: - BRepGraph Extended (v0.133.0)

#include <BRepGraph_Tool.hxx>
#include <BRepGraph_ShapesView.hxx>
#include <BRepGraph_Copy.hxx>
#include <BRepGraph_Transform.hxx>
#include <BRepGraph_History.hxx>

// --- Shape Reconstruction ---

OCCTShapeRef OCCTBRepGraphShapeFromNode(OCCTBRepGraphRef g, int32_t nodeKind, int32_t nodeIndex) {
    if (!g) return nullptr;
    try {
        BRepGraph_NodeId nid(kindFromInt(nodeKind), nodeIndex);
        TopoDS_Shape s = g->graph.Shapes().Shape(nid);
        if (s.IsNull()) return nullptr;
        return new OCCTShape{s};
    } catch (...) { return nullptr; }
}

void OCCTBRepGraphFindNode(OCCTBRepGraphRef g, OCCTShapeRef shape,
                           int32_t* outKind, int32_t* outIndex) {
    *outKind = -1;
    *outIndex = -1;
    if (!g || !shape) return;
    try {
        auto nid = g->graph.Shapes().FindNode(shape->shape);
        if (nid.IsValid()) {
            *outKind = static_cast<int32_t>(nid.NodeKind);
            *outIndex = nid.Index;
        }
    } catch (...) {}
}

bool OCCTBRepGraphHasNode(OCCTBRepGraphRef g, OCCTShapeRef shape) {
    if (!g || !shape) return false;
    try { return g->graph.Shapes().HasNode(shape->shape); }
    catch (...) { return false; }
}

// --- Vertex Geometry ---

void OCCTBRepGraphVertexPoint(OCCTBRepGraphRef g, int32_t vertexIndex,
                              double* outX, double* outY, double* outZ) {
    *outX = 0; *outY = 0; *outZ = 0;
    if (!g) return;
    try {
        auto pnt = BRepGraph_Tool::Vertex::Pnt(g->graph, BRepGraph_VertexId(vertexIndex));
        *outX = pnt.X(); *outY = pnt.Y(); *outZ = pnt.Z();
    } catch (...) {}
}

double OCCTBRepGraphVertexTolerance(OCCTBRepGraphRef g, int32_t vertexIndex) {
    if (!g) return 0;
    try { return BRepGraph_Tool::Vertex::Tolerance(g->graph, BRepGraph_VertexId(vertexIndex)); }
    catch (...) { return 0; }
}

// --- Edge Geometry ---

double OCCTBRepGraphEdgeTolerance(OCCTBRepGraphRef g, int32_t edgeIndex) {
    if (!g) return 0;
    try { return BRepGraph_Tool::Edge::Tolerance(g->graph, BRepGraph_EdgeId(edgeIndex)); }
    catch (...) { return 0; }
}

bool OCCTBRepGraphEdgeIsDegenerated(OCCTBRepGraphRef g, int32_t edgeIndex) {
    if (!g) return false;
    try { return BRepGraph_Tool::Edge::Degenerated(g->graph, BRepGraph_EdgeId(edgeIndex)); }
    catch (...) { return false; }
}

bool OCCTBRepGraphEdgeIsSameParameter(OCCTBRepGraphRef g, int32_t edgeIndex) {
    if (!g) return false;
    try { return BRepGraph_Tool::Edge::SameParameter(g->graph, BRepGraph_EdgeId(edgeIndex)); }
    catch (...) { return false; }
}

bool OCCTBRepGraphEdgeIsSameRange(OCCTBRepGraphRef g, int32_t edgeIndex) {
    if (!g) return false;
    try { return BRepGraph_Tool::Edge::SameRange(g->graph, BRepGraph_EdgeId(edgeIndex)); }
    catch (...) { return false; }
}

void OCCTBRepGraphEdgeRange(OCCTBRepGraphRef g, int32_t edgeIndex,
                            double* outFirst, double* outLast) {
    *outFirst = 0; *outLast = 0;
    if (!g) return;
    try {
        auto range = BRepGraph_Tool::Edge::Range(g->graph, BRepGraph_EdgeId(edgeIndex));
        *outFirst = range.first; *outLast = range.second;
    } catch (...) {}
}

bool OCCTBRepGraphEdgeHasCurve(OCCTBRepGraphRef g, int32_t edgeIndex) {
    if (!g) return false;
    try { return BRepGraph_Tool::Edge::HasCurve(g->graph, BRepGraph_EdgeId(edgeIndex)); }
    catch (...) { return false; }
}

bool OCCTBRepGraphEdgeIsClosedOnFace(OCCTBRepGraphRef g, int32_t edgeIndex, int32_t faceIndex) {
    if (!g) return false;
    try {
        return BRepGraph_Tool::Edge::IsClosedOnFace(g->graph,
            BRepGraph_EdgeId(edgeIndex), BRepGraph_FaceId(faceIndex));
    } catch (...) { return false; }
}

bool OCCTBRepGraphEdgeHasPolygon3D(OCCTBRepGraphRef g, int32_t edgeIndex) {
    if (!g) return false;
    try { return BRepGraph_Tool::Edge::HasPolygon3D(g->graph, BRepGraph_EdgeId(edgeIndex)); }
    catch (...) { return false; }
}

int32_t OCCTBRepGraphEdgeMaxContinuity(OCCTBRepGraphRef g, int32_t edgeIndex) {
    if (!g) return 0;
    try {
        return static_cast<int32_t>(
            BRepGraph_Tool::Edge::MaxContinuity(g->graph, BRepGraph_EdgeId(edgeIndex)));
    } catch (...) { return 0; }
}

// --- Face Geometry ---

double OCCTBRepGraphFaceTolerance(OCCTBRepGraphRef g, int32_t faceIndex) {
    if (!g) return 0;
    try { return BRepGraph_Tool::Face::Tolerance(g->graph, BRepGraph_FaceId(faceIndex)); }
    catch (...) { return 0; }
}

bool OCCTBRepGraphFaceIsNaturalRestriction(OCCTBRepGraphRef g, int32_t faceIndex) {
    if (!g) return false;
    try { return BRepGraph_Tool::Face::NaturalRestriction(g->graph, BRepGraph_FaceId(faceIndex)); }
    catch (...) { return false; }
}

bool OCCTBRepGraphFaceHasSurface(OCCTBRepGraphRef g, int32_t faceIndex) {
    if (!g) return false;
    try { return BRepGraph_Tool::Face::HasSurface(g->graph, BRepGraph_FaceId(faceIndex)); }
    catch (...) { return false; }
}

bool OCCTBRepGraphFaceHasTriangulation(OCCTBRepGraphRef g, int32_t faceIndex) {
    if (!g) return false;
    try { return BRepGraph_Tool::Face::HasTriangulation(g->graph, BRepGraph_FaceId(faceIndex)); }
    catch (...) { return false; }
}

// --- Wire Queries ---

bool OCCTBRepGraphWireIsClosed(OCCTBRepGraphRef g, int32_t wireIndex) {
    if (!g) return false;
    try { return BRepGraph_Tool::Wire::IsClosed(g->graph, BRepGraph_WireId(wireIndex)); }
    catch (...) { return false; }
}

int32_t OCCTBRepGraphWireNbCoEdges(OCCTBRepGraphRef g, int32_t wireIndex) {
    if (!g) return 0;
    try { return BRepGraph_Tool::Wire::NbCoEdges(g->graph, BRepGraph_WireId(wireIndex)); }
    catch (...) { return 0; }
}

int32_t OCCTBRepGraphWireFaceCount(OCCTBRepGraphRef g, int32_t wireIndex) {
    if (!g) return 0;
    try {
        auto& faces = g->graph.Topo().Wires().Faces(BRepGraph_WireId(wireIndex));
        return (int32_t)faces.Size();
    } catch (...) { return 0; }
}

void OCCTBRepGraphWireFaceIndices(OCCTBRepGraphRef g, int32_t wireIndex, int32_t* outIndices) {
    if (!g || !outIndices) return;
    try {
        auto& faces = g->graph.Topo().Wires().Faces(BRepGraph_WireId(wireIndex));
        for (int i = 0; i < faces.Size(); ++i) {
            outIndices[i] = faces(i).Index;
        }
    } catch (...) {}
}

// --- CoEdge Queries ---

int32_t OCCTBRepGraphCoEdgeEdge(OCCTBRepGraphRef g, int32_t coedgeIndex) {
    if (!g) return -1;
    try {
        auto eid = g->graph.Topo().CoEdges().Edge(BRepGraph_CoEdgeId(coedgeIndex));
        return eid.Index;
    } catch (...) { return -1; }
}

int32_t OCCTBRepGraphCoEdgeFace(OCCTBRepGraphRef g, int32_t coedgeIndex) {
    if (!g) return -1;
    try {
        auto fid = g->graph.Topo().CoEdges().Face(BRepGraph_CoEdgeId(coedgeIndex));
        return fid.Index;
    } catch (...) { return -1; }
}

int32_t OCCTBRepGraphCoEdgeSeamPair(OCCTBRepGraphRef g, int32_t coedgeIndex) {
    if (!g) return -1;
    try {
        auto pid = g->graph.Topo().CoEdges().SeamPair(BRepGraph_CoEdgeId(coedgeIndex));
        return pid.IsValid() ? pid.Index : -1;
    } catch (...) { return -1; }
}

bool OCCTBRepGraphCoEdgeHasPCurve(OCCTBRepGraphRef g, int32_t coedgeIndex) {
    if (!g) return false;
    try { return BRepGraph_Tool::CoEdge::HasPCurve(g->graph, BRepGraph_CoEdgeId(coedgeIndex)); }
    catch (...) { return false; }
}

void OCCTBRepGraphCoEdgeRange(OCCTBRepGraphRef g, int32_t coedgeIndex,
                              double* outFirst, double* outLast) {
    *outFirst = 0; *outLast = 0;
    if (!g) return;
    try {
        auto range = BRepGraph_Tool::CoEdge::Range(g->graph, BRepGraph_CoEdgeId(coedgeIndex));
        *outFirst = range.first; *outLast = range.second;
    } catch (...) {}
}

// --- Shell Queries ---

int32_t OCCTBRepGraphShellSolidCount(OCCTBRepGraphRef g, int32_t shellIndex) {
    if (!g) return 0;
    try {
        auto& solids = g->graph.Topo().Shells().Solids(BRepGraph_ShellId(shellIndex));
        return (int32_t)solids.Size();
    } catch (...) { return 0; }
}

void OCCTBRepGraphShellSolidIndices(OCCTBRepGraphRef g, int32_t shellIndex, int32_t* outIndices) {
    if (!g || !outIndices) return;
    try {
        auto& solids = g->graph.Topo().Shells().Solids(BRepGraph_ShellId(shellIndex));
        for (int i = 0; i < solids.Size(); ++i) {
            outIndices[i] = solids(i).Index;
        }
    } catch (...) {}
}

// --- Solid Queries ---

int32_t OCCTBRepGraphSolidCompSolidCount(OCCTBRepGraphRef g, int32_t solidIndex) {
    if (!g) return 0;
    try {
        auto& cs = g->graph.Topo().Solids().CompSolids(BRepGraph_SolidId(solidIndex));
        return (int32_t)cs.Size();
    } catch (...) { return 0; }
}

// --- History ---

int32_t OCCTBRepGraphHistoryNbRecords(OCCTBRepGraphRef g) {
    if (!g) return 0;
    try { return g->graph.History().NbRecords(); }
    catch (...) { return 0; }
}

bool OCCTBRepGraphHistoryIsEnabled(OCCTBRepGraphRef g) {
    if (!g) return false;
    try { return g->graph.History().IsEnabled(); }
    catch (...) { return false; }
}

void OCCTBRepGraphHistorySetEnabled(OCCTBRepGraphRef g, bool enabled) {
    if (!g) return;
    try { g->graph.History().SetEnabled(enabled); }
    catch (...) {}
}

void OCCTBRepGraphHistoryClear(OCCTBRepGraphRef g) {
    if (!g) return;
    try { g->graph.History().Clear(); }
    catch (...) {}
}

// --- History Record Readback (v0.141, #72 Phase 0) ---

#include <BRepGraph_HistoryRecord.hxx>
#include <BRepGraph_History.hxx>

bool OCCTBRepGraphHistoryGetRecordInfo(OCCTBRepGraphRef g,
                                        int32_t recordIdx,
                                        char* outOpName,
                                        int32_t outOpNameMax,
                                        int32_t* outSequenceNumber) {
    if (!g || !outOpName || !outSequenceNumber || outOpNameMax <= 0) return false;
    try {
        const auto& hist = g->graph.History();
        if (recordIdx < 0 || recordIdx >= hist.NbRecords()) return false;
        const auto& rec = hist.Record(recordIdx);
        const char* src = rec.OperationName.ToCString();
        int srcLen = rec.OperationName.Length();
        int copy = std::min(srcLen, outOpNameMax - 1);
        memcpy(outOpName, src, copy);
        outOpName[copy] = '\0';
        *outSequenceNumber = rec.SequenceNumber;
        return true;
    } catch (...) { return false; }
}

int32_t OCCTBRepGraphHistoryGetRecordOriginalsCount(OCCTBRepGraphRef g, int32_t recordIdx) {
    if (!g) return 0;
    try {
        const auto& hist = g->graph.History();
        if (recordIdx < 0 || recordIdx >= hist.NbRecords()) return 0;
        const auto& rec = hist.Record(recordIdx);
        return (int32_t)rec.Mapping.Extent();
    } catch (...) { return 0; }
}

int32_t OCCTBRepGraphHistoryGetRecordOriginals(OCCTBRepGraphRef g,
                                                int32_t recordIdx,
                                                int32_t* outKinds,
                                                int32_t* outIndices,
                                                int32_t maxCount) {
    if (!g || !outKinds || !outIndices) return 0;
    try {
        const auto& hist = g->graph.History();
        if (recordIdx < 0 || recordIdx >= hist.NbRecords()) return 0;
        const auto& rec = hist.Record(recordIdx);
        int32_t total = 0;
        typedef NCollection_DataMap<BRepGraph_NodeId, NCollection_DynamicArray<BRepGraph_NodeId>> MapT;
        for (MapT::Iterator it(rec.Mapping); it.More(); it.Next()) {
            if (total < maxCount) {
                outKinds[total] = (int32_t)it.Key().NodeKind;
                outIndices[total] = it.Key().Index;
            }
            total++;
        }
        return total;
    } catch (...) { return 0; }
}

int32_t OCCTBRepGraphHistoryGetRecordMapping(OCCTBRepGraphRef g,
                                              int32_t recordIdx,
                                              int32_t origKind,
                                              int32_t origIndex,
                                              int32_t* outKinds,
                                              int32_t* outIndices,
                                              int32_t maxCount) {
    if (!g || !outKinds || !outIndices) return -1;
    try {
        const auto& hist = g->graph.History();
        if (recordIdx < 0 || recordIdx >= hist.NbRecords()) return -1;
        const auto& rec = hist.Record(recordIdx);
        BRepGraph_NodeId key((BRepGraph_NodeId::Kind)origKind, origIndex);
        if (!rec.Mapping.IsBound(key)) return -1;
        const auto& repls = rec.Mapping.Find(key);
        int32_t total = repls.Length();
        int32_t copy = std::min(total, maxCount);
        for (int32_t i = 0; i < copy; i++) {
            outKinds[i] = (int32_t)repls.Value(i).NodeKind;
            outIndices[i] = repls.Value(i).Index;
        }
        return total;
    } catch (...) { return -1; }
}

bool OCCTBRepGraphHistoryFindOriginal(OCCTBRepGraphRef g,
                                       int32_t derivedKind,
                                       int32_t derivedIndex,
                                       int32_t* outKind,
                                       int32_t* outIndex) {
    if (!g || !outKind || !outIndex) return false;
    try {
        const auto& hist = g->graph.History();
        BRepGraph_NodeId derived((BRepGraph_NodeId::Kind)derivedKind, derivedIndex);
        BRepGraph_NodeId orig = hist.FindOriginal(derived);
        *outKind = (int32_t)orig.NodeKind;
        *outIndex = orig.Index;
        return true;
    } catch (...) { return false; }
}

int32_t OCCTBRepGraphHistoryFindDerived(OCCTBRepGraphRef g,
                                         int32_t origKind,
                                         int32_t origIndex,
                                         int32_t* outKinds,
                                         int32_t* outIndices,
                                         int32_t maxCount) {
    if (!g || !outKinds || !outIndices) return 0;
    try {
        const auto& hist = g->graph.History();
        BRepGraph_NodeId orig((BRepGraph_NodeId::Kind)origKind, origIndex);
        auto derived = hist.FindDerived(orig);
        int32_t total = derived.Length();
        int32_t copy = std::min(total, maxCount);
        for (int32_t i = 0; i < copy; i++) {
            outKinds[i] = (int32_t)derived.Value(i).NodeKind;
            outIndices[i] = derived.Value(i).Index;
        }
        return total;
    } catch (...) { return 0; }
}

void OCCTBRepGraphHistoryRecord(OCCTBRepGraphRef g,
                                 const char* opName,
                                 int32_t origKind,
                                 int32_t origIndex,
                                 const int32_t* replKinds,
                                 const int32_t* replIndices,
                                 int32_t replCount) {
    if (!g || !opName) return;
    try {
        auto& hist = g->graph.History();
        BRepGraph_NodeId orig((BRepGraph_NodeId::Kind)origKind, origIndex);
        NCollection_DynamicArray<BRepGraph_NodeId> repls;
        for (int32_t i = 0; i < replCount; i++) {
            repls.Append(BRepGraph_NodeId((BRepGraph_NodeId::Kind)replKinds[i], replIndices[i]));
        }
        hist.Record(TCollection_AsciiString(opName), orig, repls);
    } catch (...) {}
}

// --- Poly Counts ---

int32_t OCCTBRepGraphNbTriangulations(OCCTBRepGraphRef g) {
    if (!g) return 0;
    try { return g->graph.Mesh().Poly().NbTriangulations(); }
    catch (...) { return 0; }
}

int32_t OCCTBRepGraphNbPolygons3D(OCCTBRepGraphRef g) {
    if (!g) return 0;
    try { return g->graph.Mesh().Poly().NbPolygons3D(); }
    catch (...) { return 0; }
}

// --- MeshView additions (v0.158.0, OCCT 8.0.0 beta1 two-tier mesh storage) ---

int32_t OCCTBRepGraphMeshNbPolygons2D(OCCTBRepGraphRef g) {
    if (!g) return 0;
    try { return g->graph.Mesh().Poly().NbPolygons2D(); }
    catch (...) { return 0; }
}

int32_t OCCTBRepGraphMeshNbPolygonsOnTri(OCCTBRepGraphRef g) {
    if (!g) return 0;
    try { return g->graph.Mesh().Poly().NbPolygonsOnTri(); }
    catch (...) { return 0; }
}

int32_t OCCTBRepGraphMeshNbActiveTriangulations(OCCTBRepGraphRef g) {
    if (!g) return 0;
    try { return g->graph.Mesh().Poly().NbActiveTriangulations(); }
    catch (...) { return 0; }
}

int32_t OCCTBRepGraphMeshNbActivePolygons3D(OCCTBRepGraphRef g) {
    if (!g) return 0;
    try { return g->graph.Mesh().Poly().NbActivePolygons3D(); }
    catch (...) { return 0; }
}

int32_t OCCTBRepGraphMeshNbActivePolygons2D(OCCTBRepGraphRef g) {
    if (!g) return 0;
    try { return g->graph.Mesh().Poly().NbActivePolygons2D(); }
    catch (...) { return 0; }
}

int32_t OCCTBRepGraphMeshNbActivePolygonsOnTri(OCCTBRepGraphRef g) {
    if (!g) return 0;
    try { return g->graph.Mesh().Poly().NbActivePolygonsOnTri(); }
    catch (...) { return 0; }
}

// MeshView FaceOps: cache-first triangulation queries.

int32_t OCCTBRepGraphMeshFaceActiveTriangulationRepId(OCCTBRepGraphRef g, int32_t faceIndex) {
    if (!g) return -1;
    try {
        auto rid = g->graph.Mesh().Faces().ActiveTriangulationRepId(BRepGraph_FaceId(faceIndex));
        return rid.IsValid() ? (int32_t)rid.Index : -1;
    } catch (...) { return -1; }
}

// MeshView EdgeOps: cache-first polygon3D queries.

int32_t OCCTBRepGraphMeshEdgePolygon3DRepId(OCCTBRepGraphRef g, int32_t edgeIndex) {
    if (!g) return -1;
    try {
        auto rid = g->graph.Mesh().Edges().Polygon3DRepId(BRepGraph_EdgeId(edgeIndex));
        return rid.IsValid() ? (int32_t)rid.Index : -1;
    } catch (...) { return -1; }
}

// MeshView CoEdgeOps: cache-only coedge mesh check.

bool OCCTBRepGraphMeshCoEdgeHasMesh(OCCTBRepGraphRef g, int32_t coedgeIndex) {
    if (!g) return false;
    try { return g->graph.Mesh().CoEdges().HasMesh(BRepGraph_CoEdgeId(coedgeIndex)); }
    catch (...) { return false; }
}

// MeshCache write API (v0.160.0). All BRepGraph_Tool::Mesh statics. RepId allocations
// return the Index field; -1 indicates failure. Writes are no-ops on invalid ids.

int32_t OCCTBRepGraphMeshCreateTriangulationRep(OCCTBRepGraphRef g, OCCTPolyTriangulationRef tri) {
    if (!g || !tri) return -1;
    try {
        const Handle(Poly_Triangulation)& h = reinterpret_cast<Poly_TriangulationOpaque*>(tri)->triangulation;
        if (h.IsNull()) return -1;
        auto rid = BRepGraph_Tool::Mesh::CreateTriangulationRep(g->graph, h);
        return rid.IsValid() ? (int32_t)rid.Index : -1;
    } catch (...) { return -1; }
}

int32_t OCCTBRepGraphMeshCreatePolygon3DRep(OCCTBRepGraphRef g, OCCTPolyPolygon3DRef poly) {
    if (!g || !poly) return -1;
    try {
        const Handle(Poly_Polygon3D)& h = reinterpret_cast<Poly_Polygon3DOpaque*>(poly)->polygon;
        if (h.IsNull()) return -1;
        auto rid = BRepGraph_Tool::Mesh::CreatePolygon3DRep(g->graph, h);
        return rid.IsValid() ? (int32_t)rid.Index : -1;
    } catch (...) { return -1; }
}

int32_t OCCTBRepGraphMeshCreatePolygonOnTriRep(OCCTBRepGraphRef g, OCCTPolyPolygonOnTriRef poly, int32_t triRepId) {
    if (!g || !poly || triRepId < 0) return -1;
    try {
        const Handle(Poly_PolygonOnTriangulation)& h = reinterpret_cast<Poly_PolygonOnTriangulationOpaque*>(poly)->polygon;
        if (h.IsNull()) return -1;
        BRepGraph_TriangulationRepId tid;
        tid.Index = (uint32_t)triRepId;
        auto rid = BRepGraph_Tool::Mesh::CreatePolygonOnTriRep(g->graph, h, tid);
        return rid.IsValid() ? (int32_t)rid.Index : -1;
    } catch (...) { return -1; }
}

void OCCTBRepGraphMeshAppendCachedTriangulation(OCCTBRepGraphRef g, int32_t faceIndex, int32_t triRepId) {
    if (!g || triRepId < 0) return;
    try {
        BRepGraph_TriangulationRepId tid;
        tid.Index = (uint32_t)triRepId;
        BRepGraph_Tool::Mesh::AppendCachedTriangulation(g->graph, BRepGraph_FaceId(faceIndex), tid);
    } catch (...) {}
}

void OCCTBRepGraphMeshSetCachedActiveIndex(OCCTBRepGraphRef g, int32_t faceIndex, int32_t activeIndex) {
    if (!g) return;
    try {
        BRepGraph_Tool::Mesh::SetCachedActiveIndex(g->graph, BRepGraph_FaceId(faceIndex), activeIndex);
    } catch (...) {}
}

void OCCTBRepGraphMeshSetCachedPolygon3D(OCCTBRepGraphRef g, int32_t edgeIndex, int32_t polyRepId) {
    if (!g || polyRepId < 0) return;
    try {
        BRepGraph_Polygon3DRepId rid;
        rid.Index = (uint32_t)polyRepId;
        BRepGraph_Tool::Mesh::SetCachedPolygon3D(g->graph, BRepGraph_EdgeId(edgeIndex), rid);
    } catch (...) {}
}

void OCCTBRepGraphMeshAppendCachedPolygonOnTri(OCCTBRepGraphRef g, int32_t coedgeIndex, int32_t polyRepId) {
    if (!g || polyRepId < 0) return;
    try {
        BRepGraph_PolygonOnTriRepId rid;
        rid.Index = (uint32_t)polyRepId;
        BRepGraph_Tool::Mesh::AppendCachedPolygonOnTri(g->graph, BRepGraph_CoEdgeId(coedgeIndex), rid);
    } catch (...) {}
}

void OCCTBRepGraphMeshSetCachedPolygon2D(OCCTBRepGraphRef g, int32_t coedgeIndex, int32_t poly2DRepId) {
    if (!g || poly2DRepId < 0) return;
    try {
        BRepGraph_Polygon2DRepId rid;
        rid.Index = (uint32_t)poly2DRepId;
        BRepGraph_Tool::Mesh::SetCachedPolygon2D(g->graph, BRepGraph_CoEdgeId(coedgeIndex), rid);
    } catch (...) {}
}

// --- Active Geometry Counts ---

int32_t OCCTBRepGraphNbActiveSurfaces(OCCTBRepGraphRef g) {
    if (!g) return 0;
    try { return g->graph.Topo().Geometry().NbActiveSurfaces(); }
    catch (...) { return 0; }
}

int32_t OCCTBRepGraphNbActiveCurves3D(OCCTBRepGraphRef g) {
    if (!g) return 0;
    try { return g->graph.Topo().Geometry().NbActiveCurves3D(); }
    catch (...) { return 0; }
}

int32_t OCCTBRepGraphNbActiveCurves2D(OCCTBRepGraphRef g) {
    if (!g) return 0;
    try { return g->graph.Topo().Geometry().NbActiveCurves2D(); }
    catch (...) { return 0; }
}

// --- SameDomain ---

int32_t OCCTBRepGraphFaceSameDomainCount(OCCTBRepGraphRef g, int32_t faceIndex) {
    if (!g) return 0;
    try {
        auto sd = g->graph.Topo().Faces().SameDomain(
            BRepGraph_FaceId(faceIndex), g->graph.Allocator());
        return (int32_t)sd.Size();
    } catch (...) { return 0; }
}

void OCCTBRepGraphFaceSameDomainIndices(OCCTBRepGraphRef g, int32_t faceIndex,
                                        int32_t* outIndices) {
    if (!g || !outIndices) return;
    try {
        auto sd = g->graph.Topo().Faces().SameDomain(
            BRepGraph_FaceId(faceIndex), g->graph.Allocator());
        for (int i = 0; i < sd.Size(); ++i) {
            outIndices[i] = sd(i).Index;
        }
    } catch (...) {}
}

// --- Copy and Transform ---

OCCTBRepGraphRef OCCTBRepGraphCopy(OCCTBRepGraphRef g, bool copyGeom) {
    if (!g) return nullptr;
    try {
        auto ref = new OCCTBRepGraph();
        ref->graph = BRepGraph_Copy::Perform(g->graph, copyGeom);
        if (!ref->graph.IsDone()) { delete ref; return nullptr; }
        return ref;
    } catch (...) { return nullptr; }
}

OCCTBRepGraphRef OCCTBRepGraphCopyFace(OCCTBRepGraphRef g, int32_t faceIndex, bool copyGeom) {
    if (!g) return nullptr;
    try {
        auto ref = new OCCTBRepGraph();
        // OCCT 8.0.0 beta1: BRepGraph_Copy::CopyFace replaced by CopyNode taking any NodeId.
        ref->graph = BRepGraph_Copy::CopyNode(
            g->graph,
            BRepGraph_NodeId(BRepGraph_NodeId::Kind::Face, faceIndex),
            copyGeom);
        if (!ref->graph.IsDone()) { delete ref; return nullptr; }
        return ref;
    } catch (...) { return nullptr; }
}

OCCTBRepGraphRef OCCTBRepGraphTransformTranslation(OCCTBRepGraphRef g,
                                                    double dx, double dy, double dz,
                                                    bool copyGeom) {
    if (!g) return nullptr;
    try {
        gp_Trsf trsf;
        trsf.SetTranslation(gp_Vec(dx, dy, dz));
        auto ref = new OCCTBRepGraph();
        ref->graph = BRepGraph_Transform::Perform(g->graph, trsf, copyGeom);
        if (!ref->graph.IsDone()) { delete ref; return nullptr; }
        return ref;
    } catch (...) { return nullptr; }
}

// MARK: - BRepGraph Assembly & Refs (v0.134.0)

#include <BRepGraph_RefsView.hxx>

static BRepGraph_RefId::Kind refKindFromInt(int32_t k) {
    switch (k) {
        case 0: return BRepGraph_RefId::Kind::Shell;
        case 1: return BRepGraph_RefId::Kind::Face;
        case 2: return BRepGraph_RefId::Kind::Wire;
        case 3: return BRepGraph_RefId::Kind::CoEdge;
        case 4: return BRepGraph_RefId::Kind::Vertex;
        case 5: return BRepGraph_RefId::Kind::Solid;
        case 6: return BRepGraph_RefId::Kind::Child;
        case 7: return BRepGraph_RefId::Kind::Occurrence;
        default: return BRepGraph_RefId::Kind::Shell;
    }
}

static int32_t nodeKindToInt(BRepGraph_NodeId::Kind k) {
    switch (k) {
        case BRepGraph_NodeId::Kind::Solid:     return 0;
        case BRepGraph_NodeId::Kind::Shell:     return 1;
        case BRepGraph_NodeId::Kind::Face:      return 2;
        case BRepGraph_NodeId::Kind::Wire:      return 3;
        case BRepGraph_NodeId::Kind::Edge:      return 4;
        case BRepGraph_NodeId::Kind::Vertex:    return 5;
        case BRepGraph_NodeId::Kind::Compound:  return 6;
        case BRepGraph_NodeId::Kind::CompSolid: return 7;
        case BRepGraph_NodeId::Kind::CoEdge:    return 8;
        default: return -1;
    }
}

// --- Product (Assembly) Queries ---

int32_t OCCTBRepGraphNbProducts(OCCTBRepGraphRef g) {
    if (!g) return 0;
    try { return g->graph.Topo().Products().Nb(); }
    catch (...) { return 0; }
}

int32_t OCCTBRepGraphNbOccurrences(OCCTBRepGraphRef g) {
    if (!g) return 0;
    try { return g->graph.Topo().Occurrences().Nb(); }
    catch (...) { return 0; }
}

bool OCCTBRepGraphProductIsAssembly(OCCTBRepGraphRef g, int32_t productIndex) {
    if (!g) return false;
    try { return g->graph.Topo().Products().IsAssembly(BRepGraph_ProductId(productIndex)); }
    catch (...) { return false; }
}

bool OCCTBRepGraphProductIsPart(OCCTBRepGraphRef g, int32_t productIndex) {
    if (!g) return false;
    try { return g->graph.Topo().Products().IsPart(BRepGraph_ProductId(productIndex)); }
    catch (...) { return false; }
}

int32_t OCCTBRepGraphProductNbComponents(OCCTBRepGraphRef g, int32_t productIndex) {
    if (!g) return 0;
    try { return g->graph.Topo().Products().NbComponents(BRepGraph_ProductId(productIndex)); }
    catch (...) { return 0; }
}

int32_t OCCTBRepGraphProductShapeRootKind(OCCTBRepGraphRef g, int32_t productIndex) {
    if (!g) return -1;
    try {
        auto nid = g->graph.Topo().Products().ShapeRootNode(BRepGraph_ProductId(productIndex));
        if (!nid.IsValid()) return -1;
        return nodeKindToInt(nid.NodeKind);
    } catch (...) { return -1; }
}

int32_t OCCTBRepGraphProductShapeRootIndex(OCCTBRepGraphRef g, int32_t productIndex) {
    if (!g) return -1;
    try {
        auto nid = g->graph.Topo().Products().ShapeRootNode(BRepGraph_ProductId(productIndex));
        if (!nid.IsValid()) return -1;
        return nid.Index;
    } catch (...) { return -1; }
}

int32_t OCCTBRepGraphOccurrenceProduct(OCCTBRepGraphRef g, int32_t occIndex) {
    if (!g) return -1;
    try {
        auto pid = g->graph.Topo().Occurrences().Product(BRepGraph_OccurrenceId(occIndex));
        return pid.IsValid() ? pid.Index : -1;
    } catch (...) { return -1; }
}

int32_t OCCTBRepGraphOccurrenceParentProduct(OCCTBRepGraphRef g, int32_t occIndex) {
    if (!g) return -1;
    try {
        auto pid = g->graph.Topo().Occurrences().ParentProduct(BRepGraph_OccurrenceId(occIndex));
        return pid.IsValid() ? pid.Index : -1;
    } catch (...) { return -1; }
}

// OCCT 8.0.0 beta1 removed the parent-occurrence-of-occurrence relationship: assembly
// hierarchy is now Product -> Occurrence -> Product, and an occurrence has only one
// parent (a Product), not another occurrence. The wrapper is retained as -1 sentinel
// for ABI compatibility within v0.157.x; remove at v1.0 if unused.
int32_t OCCTBRepGraphOccurrenceParentOccurrence(OCCTBRepGraphRef g, int32_t occIndex) {
    (void)g; (void)occIndex;
    return -1;
}

int32_t OCCTBRepGraphRootProductCount(OCCTBRepGraphRef g) {
    if (!g) return 0;
    try {
        const auto& roots = g->graph.RootProductIds();
        return (int32_t)roots.Size();
    } catch (...) { return 0; }
}

void OCCTBRepGraphRootProductIndices(OCCTBRepGraphRef g, int32_t* outIndices) {
    if (!g || !outIndices) return;
    try {
        const auto& roots = g->graph.RootProductIds();
        for (int i = 0; i < (int)roots.Size(); ++i) {
            outIndices[i] = roots(i).Index;
        }
    } catch (...) {}
}

// --- RefsView Per-Kind Counts ---

int32_t OCCTBRepGraphNbShellRefs(OCCTBRepGraphRef g) {
    if (!g) return 0;
    try { return g->graph.Refs().Shells().Nb(); }
    catch (...) { return 0; }
}

int32_t OCCTBRepGraphNbFaceRefs(OCCTBRepGraphRef g) {
    if (!g) return 0;
    try { return g->graph.Refs().Faces().Nb(); }
    catch (...) { return 0; }
}

int32_t OCCTBRepGraphNbWireRefs(OCCTBRepGraphRef g) {
    if (!g) return 0;
    try { return g->graph.Refs().Wires().Nb(); }
    catch (...) { return 0; }
}

int32_t OCCTBRepGraphNbCoEdgeRefs(OCCTBRepGraphRef g) {
    if (!g) return 0;
    try { return g->graph.Refs().CoEdges().Nb(); }
    catch (...) { return 0; }
}

int32_t OCCTBRepGraphNbVertexRefs(OCCTBRepGraphRef g) {
    if (!g) return 0;
    try { return g->graph.Refs().Vertices().Nb(); }
    catch (...) { return 0; }
}

int32_t OCCTBRepGraphNbSolidRefs(OCCTBRepGraphRef g) {
    if (!g) return 0;
    try { return g->graph.Refs().Solids().Nb(); }
    catch (...) { return 0; }
}

int32_t OCCTBRepGraphNbChildRefs(OCCTBRepGraphRef g) {
    if (!g) return 0;
    try { return g->graph.Refs().Children().Nb(); }
    catch (...) { return 0; }
}

int32_t OCCTBRepGraphNbOccurrenceRefs(OCCTBRepGraphRef g) {
    if (!g) return 0;
    try { return g->graph.Refs().Occurrences().Nb(); }
    catch (...) { return 0; }
}

// --- RefsView Global Methods ---

int32_t OCCTBRepGraphRefChildNodeKind(OCCTBRepGraphRef g, int32_t refKind, int32_t refIndex) {
    if (!g) return -1;
    try {
        BRepGraph_RefId rid(refKindFromInt(refKind), refIndex);
        auto nid = g->graph.Refs().ChildNode(rid);
        if (!nid.IsValid()) return -1;
        return nodeKindToInt(nid.NodeKind);
    } catch (...) { return -1; }
}

int32_t OCCTBRepGraphRefChildNodeIndex(OCCTBRepGraphRef g, int32_t refKind, int32_t refIndex) {
    if (!g) return -1;
    try {
        BRepGraph_RefId rid(refKindFromInt(refKind), refIndex);
        auto nid = g->graph.Refs().ChildNode(rid);
        if (!nid.IsValid()) return -1;
        return nid.Index;
    } catch (...) { return -1; }
}

bool OCCTBRepGraphRefIsRemoved(OCCTBRepGraphRef g, int32_t refKind, int32_t refIndex) {
    if (!g) return false;
    try {
        BRepGraph_RefId rid(refKindFromInt(refKind), refIndex);
        return g->graph.Refs().IsRemoved(rid);
    } catch (...) { return false; }
}

int32_t OCCTBRepGraphRefOrientation(OCCTBRepGraphRef g, int32_t refKind, int32_t refIndex) {
    if (!g) return 0;
    try {
        BRepGraph_RefId rid(refKindFromInt(refKind), refIndex);
        return (int32_t)g->graph.Refs().Orientation(rid);
    } catch (...) { return 0; }
}

// --- Face Definition Details ---

int32_t OCCTBRepGraphFaceNbWires(OCCTBRepGraphRef g, int32_t faceIndex) {
    if (!g) return 0;
    try {
        auto& def = g->graph.Topo().Faces().Definition(BRepGraph_FaceId(faceIndex));
        return (int32_t)def.WireRefIds.Length();
    } catch (...) { return 0; }
}

int32_t OCCTBRepGraphFaceNbVertexRefs(OCCTBRepGraphRef g, int32_t faceIndex) {
    if (!g) return 0;
    try {
        auto& def = g->graph.Topo().Faces().Definition(BRepGraph_FaceId(faceIndex));
        return (int32_t)def.VertexRefIds.Length();
    } catch (...) { return 0; }
}

// --- Edge Definition Details ---

int32_t OCCTBRepGraphEdgeStartVertex(OCCTBRepGraphRef g, int32_t edgeIndex) {
    if (!g) return -1;
    try {
        auto vid = BRepGraph_Tool::Edge::StartVertexId(g->graph, BRepGraph_EdgeId(edgeIndex));
        return vid.IsValid() ? vid.Index : -1;
    } catch (...) { return -1; }
}

int32_t OCCTBRepGraphEdgeEndVertex(OCCTBRepGraphRef g, int32_t edgeIndex) {
    if (!g) return -1;
    try {
        auto vid = BRepGraph_Tool::Edge::EndVertexId(g->graph, BRepGraph_EdgeId(edgeIndex));
        return vid.IsValid() ? vid.Index : -1;
    } catch (...) { return -1; }
}

bool OCCTBRepGraphEdgeIsClosed(OCCTBRepGraphRef g, int32_t edgeIndex) {
    if (!g) return false;
    try {
        auto& def = g->graph.Topo().Edges().Definition(BRepGraph_EdgeId(edgeIndex));
        return def.IsClosed;
    } catch (...) { return false; }
}

// --- Compound/CompSolid Queries ---

int32_t OCCTBRepGraphCompoundParentCount(OCCTBRepGraphRef g, int32_t compoundIndex) {
    if (!g) return 0;
    try {
        auto& parents = g->graph.Topo().Compounds().ParentCompounds(BRepGraph_CompoundId(compoundIndex));
        return (int32_t)parents.Length();
    } catch (...) { return 0; }
}

int32_t OCCTBRepGraphCompoundChildCount(OCCTBRepGraphRef g, int32_t compoundIndex) {
    if (!g) return 0;
    try {
        auto& def = g->graph.Topo().Compounds().Definition(BRepGraph_CompoundId(compoundIndex));
        return (int32_t)def.ChildRefIds.Length();
    } catch (...) { return 0; }
}

int32_t OCCTBRepGraphCompSolidSolidCount(OCCTBRepGraphRef g, int32_t compSolidIndex) {
    if (!g) return 0;
    try {
        auto& def = g->graph.Topo().CompSolids().Definition(BRepGraph_CompSolidId(compSolidIndex));
        return (int32_t)def.SolidRefIds.Length();
    } catch (...) { return 0; }
}

int32_t OCCTBRepGraphCompSolidCompoundCount(OCCTBRepGraphRef g, int32_t compSolidIndex) {
    if (!g) return 0;
    try {
        auto& compounds = g->graph.Topo().CompSolids().Compounds(BRepGraph_CompSolidId(compSolidIndex));
        return (int32_t)compounds.Length();
    } catch (...) { return 0; }
}

// --- Edge Additional Queries ---

int32_t OCCTBRepGraphEdgeWireCount(OCCTBRepGraphRef g, int32_t edgeIndex) {
    if (!g) return 0;
    try {
        auto& wires = g->graph.Topo().Edges().Wires(BRepGraph_EdgeId(edgeIndex));
        return (int32_t)wires.Length();
    } catch (...) { return 0; }
}

void OCCTBRepGraphEdgeWireIndices(OCCTBRepGraphRef g, int32_t edgeIndex, int32_t* outIndices) {
    if (!g || !outIndices) return;
    try {
        auto& wires = g->graph.Topo().Edges().Wires(BRepGraph_EdgeId(edgeIndex));
        for (int i = 0; i < wires.Length(); ++i) {
            outIndices[i] = wires.Value(i).Index;
        }
    } catch (...) {}
}

int32_t OCCTBRepGraphEdgeCoEdgeCount(OCCTBRepGraphRef g, int32_t edgeIndex) {
    if (!g) return 0;
    try {
        auto& coedges = g->graph.Topo().Edges().CoEdges(BRepGraph_EdgeId(edgeIndex));
        return (int32_t)coedges.Length();
    } catch (...) { return 0; }
}

void OCCTBRepGraphEdgeCoEdgeIndices(OCCTBRepGraphRef g, int32_t edgeIndex, int32_t* outIndices) {
    if (!g || !outIndices) return;
    try {
        auto& coedges = g->graph.Topo().Edges().CoEdges(BRepGraph_EdgeId(edgeIndex));
        for (int i = 0; i < coedges.Length(); ++i) {
            outIndices[i] = coedges.Value(i).Index;
        }
    } catch (...) {}
}

// --- Face Additional Queries ---

int32_t OCCTBRepGraphFaceShellCount(OCCTBRepGraphRef g, int32_t faceIndex) {
    if (!g) return 0;
    try {
        auto& shells = g->graph.Topo().Faces().Shells(BRepGraph_FaceId(faceIndex));
        return (int32_t)shells.Length();
    } catch (...) { return 0; }
}

void OCCTBRepGraphFaceShellIndices(OCCTBRepGraphRef g, int32_t faceIndex, int32_t* outIndices) {
    if (!g || !outIndices) return;
    try {
        auto& shells = g->graph.Topo().Faces().Shells(BRepGraph_FaceId(faceIndex));
        for (int i = 0; i < shells.Length(); ++i) {
            outIndices[i] = shells.Value(i).Index;
        }
    } catch (...) {}
}

int32_t OCCTBRepGraphFaceCompoundCount(OCCTBRepGraphRef g, int32_t faceIndex) {
    if (!g) return 0;
    try {
        auto& compounds = g->graph.Topo().Faces().Compounds(BRepGraph_FaceId(faceIndex));
        return (int32_t)compounds.Length();
    } catch (...) { return 0; }
}

// --- Shell Additional Queries ---

int32_t OCCTBRepGraphShellCompoundCount(OCCTBRepGraphRef g, int32_t shellIndex) {
    if (!g) return 0;
    try {
        auto& compounds = g->graph.Topo().Shells().Compounds(BRepGraph_ShellId(shellIndex));
        return (int32_t)compounds.Length();
    } catch (...) { return 0; }
}

bool OCCTBRepGraphShellIsClosed(OCCTBRepGraphRef g, int32_t shellIndex) {
    if (!g) return false;
    try {
        auto& def = g->graph.Topo().Shells().Definition(BRepGraph_ShellId(shellIndex));
        return def.IsClosed;
    } catch (...) { return false; }
}

// --- Solid Additional Queries ---

int32_t OCCTBRepGraphSolidCompoundCount(OCCTBRepGraphRef g, int32_t solidIndex) {
    if (!g) return 0;
    try {
        auto& compounds = g->graph.Topo().Solids().Compounds(BRepGraph_SolidId(solidIndex));
        return (int32_t)compounds.Length();
    } catch (...) { return 0; }
}

// --- CompSolid Count ---

int32_t OCCTBRepGraphNbCompSolids(OCCTBRepGraphRef g) {
    if (!g) return 0;
    try { return g->graph.Topo().CompSolids().Nb(); }
    catch (...) { return 0; }
}

// --- Edge FindCoEdge ---

int32_t OCCTBRepGraphEdgeFindCoEdge(OCCTBRepGraphRef g, int32_t edgeIndex, int32_t faceIndex) {
    if (!g) return -1;
    try {
        auto cid = g->graph.Topo().Edges().FindCoEdgeId(BRepGraph_EdgeId(edgeIndex), BRepGraph_FaceId(faceIndex));
        return cid.IsValid() ? cid.Index : -1;
    } catch (...) { return -1; }
}

// end of v0.133.0 implementations

// MARK: - BRepGraph Builder (v0.135.0; migrated to EditorView in v0.157.0 / OCCT 8.0.0 beta1)

#include <BRepGraph_EditorView.hxx>
#include <BRepGraph_Builder.hxx>
#include <BRepGraph_Tool.hxx>
#include <BRepGraph_DeferredScope.hxx>

static TopAbs_Orientation oriFromInt(int32_t o) {
    switch (o) {
        case 0: return TopAbs_FORWARD;
        case 1: return TopAbs_REVERSED;
        case 2: return TopAbs_INTERNAL;
        case 3: return TopAbs_EXTERNAL;
        default: return TopAbs_FORWARD;
    }
}

// --- Add Topology Nodes ---

int32_t OCCTBRepGraphBuilderAddVertex(OCCTBRepGraphRef g, double x, double y, double z, double tolerance) {
    if (!g) return -1;
    try {
        auto vid = g->graph.Editor().Vertices().Add(gp_Pnt(x, y, z), tolerance);
        return vid.IsValid() ? vid.Index : -1;
    } catch (...) { return -1; }
}

int32_t OCCTBRepGraphBuilderAddShell(OCCTBRepGraphRef g) {
    if (!g) return -1;
    try {
        auto sid = g->graph.Editor().Shells().Add();
        return sid.IsValid() ? sid.Index : -1;
    } catch (...) { return -1; }
}

int32_t OCCTBRepGraphBuilderAddSolid(OCCTBRepGraphRef g) {
    if (!g) return -1;
    try {
        auto sid = g->graph.Editor().Solids().Add();
        return sid.IsValid() ? sid.Index : -1;
    } catch (...) { return -1; }
}

int32_t OCCTBRepGraphBuilderAddFaceToShell(OCCTBRepGraphRef g, int32_t shellIndex, int32_t faceIndex, int32_t orientation) {
    if (!g) return -1;
    try {
        auto rid = g->graph.Editor().Shells().AddFace(
            BRepGraph_ShellId(shellIndex),
            BRepGraph_FaceId(faceIndex),
            oriFromInt(orientation));
        return rid.IsValid() ? rid.Index : -1;
    } catch (...) { return -1; }
}

int32_t OCCTBRepGraphBuilderAddShellToSolid(OCCTBRepGraphRef g, int32_t solidIndex, int32_t shellIndex, int32_t orientation) {
    if (!g) return -1;
    try {
        auto rid = g->graph.Editor().Solids().AddShell(
            BRepGraph_SolidId(solidIndex),
            BRepGraph_ShellId(shellIndex),
            oriFromInt(orientation));
        return rid.IsValid() ? rid.Index : -1;
    } catch (...) { return -1; }
}

int32_t OCCTBRepGraphBuilderAddCompound(OCCTBRepGraphRef g, const int32_t* kinds, const int32_t* indices, int32_t count) {
    if (!g || !kinds || !indices || count <= 0) return -1;
    try {
        NCollection_DynamicArray<BRepGraph_NodeId> children;
        for (int32_t i = 0; i < count; ++i) {
            children.Append(BRepGraph_NodeId(kindFromInt(kinds[i]), indices[i]));
        }
        auto cid = g->graph.Editor().Compounds().Add(children);
        return cid.IsValid() ? cid.Index : -1;
    } catch (...) { return -1; }
}

int32_t OCCTBRepGraphBuilderAddCompSolid(OCCTBRepGraphRef g, const int32_t* solidIndices, int32_t count) {
    if (!g || !solidIndices || count <= 0) return -1;
    try {
        NCollection_DynamicArray<BRepGraph_SolidId> solids;
        for (int32_t i = 0; i < count; ++i) {
            solids.Append(BRepGraph_SolidId(solidIndices[i]));
        }
        auto csid = g->graph.Editor().CompSolids().Add(solids);
        return csid.IsValid() ? csid.Index : -1;
    } catch (...) { return -1; }
}

// --- Remove/Modify Nodes ---

void OCCTBRepGraphBuilderRemoveNode(OCCTBRepGraphRef g, int32_t nodeKind, int32_t nodeIndex) {
    if (!g) return;
    try {
        g->graph.Editor().Gen().RemoveNode(BRepGraph_NodeId(kindFromInt(nodeKind), nodeIndex));
    } catch (...) {}
}

void OCCTBRepGraphBuilderRemoveSubgraph(OCCTBRepGraphRef g, int32_t nodeKind, int32_t nodeIndex) {
    if (!g) return;
    try {
        g->graph.Editor().Gen().RemoveSubgraph(BRepGraph_NodeId(kindFromInt(nodeKind), nodeIndex));
    } catch (...) {}
}

// --- Append Shapes ---
// NOTE: OCCT 8.0.0 beta1 routes the former Builder().AppendFlattenedShape /
// AppendFullShape through the static BRepGraph_Builder::Add(graph, shape, options).
// The Flatten option preserves the pre-beta1 distinction.

void OCCTBRepGraphBuilderAppendFlattenedShape(OCCTBRepGraphRef g, OCCTShapeRef shape, bool parallel) {
    if (!g || !shape) return;
    try {
        BRepGraph_Builder::Options opts;
        opts.Parallel = parallel;
        opts.CreateAutoProduct = false;
        opts.Flatten = true;
        (void)BRepGraph_Builder::Add(g->graph, *(const TopoDS_Shape*)shape, opts);
    } catch (...) {}
}

void OCCTBRepGraphBuilderAppendFullShape(OCCTBRepGraphRef g, OCCTShapeRef shape, bool parallel) {
    if (!g || !shape) return;
    try {
        BRepGraph_Builder::Options opts;
        opts.Parallel = parallel;
        opts.CreateAutoProduct = false;
        (void)BRepGraph_Builder::Add(g->graph, *(const TopoDS_Shape*)shape, opts);
    } catch (...) {}
}

// --- Deferred Invalidation ---

void OCCTBRepGraphBuilderBeginDeferred(OCCTBRepGraphRef g) {
    if (!g) return;
    try { g->graph.Editor().BeginDeferredInvalidation(); }
    catch (...) {}
}

void OCCTBRepGraphBuilderEndDeferred(OCCTBRepGraphRef g) {
    if (!g) return;
    try { g->graph.Editor().EndDeferredInvalidation(); }
    catch (...) {}
}

bool OCCTBRepGraphBuilderIsDeferredMode(OCCTBRepGraphRef g) {
    if (!g) return false;
    try { return g->graph.Editor().IsDeferredMode(); }
    catch (...) { return false; }
}

void OCCTBRepGraphBuilderCommitMutation(OCCTBRepGraphRef g) {
    if (!g) return;
    try { g->graph.Editor().CommitMutation(); }
    catch (...) {}
}

// --- Edge Splitting ---

void OCCTBRepGraphBuilderSplitEdge(OCCTBRepGraphRef g, int32_t edgeIndex, int32_t vertexIndex,
                                    double param, int32_t* outSubA, int32_t* outSubB) {
    if (!g || !outSubA || !outSubB) {
        if (outSubA) *outSubA = -1;
        if (outSubB) *outSubB = -1;
        return;
    }
    try {
        BRepGraph_EdgeId subA, subB;
        g->graph.Editor().Edges().Split(
            BRepGraph_EdgeId(edgeIndex),
            BRepGraph_VertexId(vertexIndex),
            param, subA, subB);
        *outSubA = subA.IsValid() ? subA.Index : -1;
        *outSubB = subB.IsValid() ? subB.Index : -1;
    } catch (...) {
        *outSubA = -1;
        *outSubB = -1;
    }
}

// --- Replace Edge in Wire ---

void OCCTBRepGraphBuilderReplaceEdgeInWire(OCCTBRepGraphRef g, int32_t wireIndex,
                                            int32_t oldEdgeIndex, int32_t newEdgeIndex,
                                            bool reversed) {
    if (!g) return;
    try {
        g->graph.Editor().Wires().ReplaceEdge(
            BRepGraph_WireId(wireIndex),
            BRepGraph_EdgeId(oldEdgeIndex),
            BRepGraph_EdgeId(newEdgeIndex),
            reversed);
    } catch (...) {}
}

// --- Remove Ref ---

bool OCCTBRepGraphBuilderRemoveRef(OCCTBRepGraphRef g, int32_t refKind, int32_t refIndex) {
    if (!g) return false;
    try {
        BRepGraph_RefId rid(refKindFromInt(refKind), refIndex);
        return g->graph.Editor().Gen().RemoveRef(rid);
    } catch (...) { return false; }
}

// --- Clear Mesh ---
// NOTE: OCCT 8.0.0 beta1 split mesh storage into a cache (algorithm-derived)
// and persistent (STEP-imported) tier. The Builder-era ClearFaceMesh /
// ClearEdgePolygon3D methods now clear only the cache via BRepGraph_Tool::Mesh.

void OCCTBRepGraphBuilderClearFaceMesh(OCCTBRepGraphRef g, int32_t faceIndex) {
    if (!g) return;
    try {
        BRepGraph_Tool::Mesh::ClearFaceCache(g->graph, BRepGraph_FaceId(faceIndex));
    } catch (...) {}
}

void OCCTBRepGraphBuilderClearEdgePolygon3D(OCCTBRepGraphRef g, int32_t edgeIndex) {
    if (!g) return;
    try {
        BRepGraph_Tool::Mesh::ClearEdgeCache(g->graph, BRepGraph_EdgeId(edgeIndex));
    } catch (...) {}
}

// --- Validate Mutation Boundary ---

bool OCCTBRepGraphBuilderValidateMutation(OCCTBRepGraphRef g) {
    if (!g) return false;
    try {
        return g->graph.Editor().ValidateMutationBoundary();
    } catch (...) { return false; }
}

// MARK: - BRepGraph EditorView Field Setters (v0.159.0)
//
// Pure-value setters on the per-entity Ops classes of BRepGraph::EditorView.
// All take a typed entity id + scalar/bool argument and return void; on
// invalid id or out-of-range value the underlying call is a no-op.

// VertexOps

void OCCTBRepGraphSetVertexPoint(OCCTBRepGraphRef g, int32_t vertexIndex, double x, double y, double z) {
    if (!g) return;
    try {
        g->graph.Editor().Vertices().SetPoint(BRepGraph_VertexId(vertexIndex), gp_Pnt(x, y, z));
    } catch (...) {}
}

void OCCTBRepGraphSetVertexTolerance(OCCTBRepGraphRef g, int32_t vertexIndex, double tolerance) {
    if (!g) return;
    try {
        g->graph.Editor().Vertices().SetTolerance(BRepGraph_VertexId(vertexIndex), tolerance);
    } catch (...) {}
}

// EdgeOps

void OCCTBRepGraphSetEdgeTolerance(OCCTBRepGraphRef g, int32_t edgeIndex, double tolerance) {
    if (!g) return;
    try {
        g->graph.Editor().Edges().SetTolerance(BRepGraph_EdgeId(edgeIndex), tolerance);
    } catch (...) {}
}

void OCCTBRepGraphSetEdgeParamRange(OCCTBRepGraphRef g, int32_t edgeIndex, double first, double last) {
    if (!g) return;
    try {
        g->graph.Editor().Edges().SetParamRange(BRepGraph_EdgeId(edgeIndex), first, last);
    } catch (...) {}
}

void OCCTBRepGraphSetEdgeSameParameter(OCCTBRepGraphRef g, int32_t edgeIndex, bool sameParameter) {
    if (!g) return;
    try {
        g->graph.Editor().Edges().SetSameParameter(BRepGraph_EdgeId(edgeIndex), sameParameter);
    } catch (...) {}
}

void OCCTBRepGraphSetEdgeSameRange(OCCTBRepGraphRef g, int32_t edgeIndex, bool sameRange) {
    if (!g) return;
    try {
        g->graph.Editor().Edges().SetSameRange(BRepGraph_EdgeId(edgeIndex), sameRange);
    } catch (...) {}
}

void OCCTBRepGraphSetEdgeDegenerate(OCCTBRepGraphRef g, int32_t edgeIndex, bool degenerate) {
    if (!g) return;
    try {
        g->graph.Editor().Edges().SetDegenerate(BRepGraph_EdgeId(edgeIndex), degenerate);
    } catch (...) {}
}

void OCCTBRepGraphSetEdgeIsClosed(OCCTBRepGraphRef g, int32_t edgeIndex, bool isClosed) {
    if (!g) return;
    try {
        g->graph.Editor().Edges().SetIsClosed(BRepGraph_EdgeId(edgeIndex), isClosed);
    } catch (...) {}
}

// CoEdgeOps

void OCCTBRepGraphSetCoEdgeParamRange(OCCTBRepGraphRef g, int32_t coedgeIndex, double first, double last) {
    if (!g) return;
    try {
        g->graph.Editor().CoEdges().SetParamRange(BRepGraph_CoEdgeId(coedgeIndex), first, last);
    } catch (...) {}
}

void OCCTBRepGraphSetCoEdgeOrientation(OCCTBRepGraphRef g, int32_t coedgeIndex, int32_t orientation) {
    if (!g) return;
    try {
        g->graph.Editor().CoEdges().SetOrientation(BRepGraph_CoEdgeId(coedgeIndex), oriFromInt(orientation));
    } catch (...) {}
}

// WireOps

void OCCTBRepGraphSetWireIsClosed(OCCTBRepGraphRef g, int32_t wireIndex, bool isClosed) {
    if (!g) return;
    try {
        g->graph.Editor().Wires().SetIsClosed(BRepGraph_WireId(wireIndex), isClosed);
    } catch (...) {}
}

// FaceOps

void OCCTBRepGraphSetFaceTolerance(OCCTBRepGraphRef g, int32_t faceIndex, double tolerance) {
    if (!g) return;
    try {
        g->graph.Editor().Faces().SetTolerance(BRepGraph_FaceId(faceIndex), tolerance);
    } catch (...) {}
}

void OCCTBRepGraphSetFaceNaturalRestriction(OCCTBRepGraphRef g, int32_t faceIndex, bool naturalRestriction) {
    if (!g) return;
    try {
        g->graph.Editor().Faces().SetNaturalRestriction(BRepGraph_FaceId(faceIndex), naturalRestriction);
    } catch (...) {}
}

// ShellOps

void OCCTBRepGraphSetShellIsClosed(OCCTBRepGraphRef g, int32_t shellIndex, bool isClosed) {
    if (!g) return;
    try {
        g->graph.Editor().Shells().SetIsClosed(BRepGraph_ShellId(shellIndex), isClosed);
    } catch (...) {}
}

// MARK: - BRepGraph EditorView Add/Remove + Ref Setters (v0.161.0)
//
// Add operations return the typed ref id (or -1 on failure). Remove operations return
// bool indicating whether the active usage was removed. Ref setters are no-ops on
// invalid ids.

// --- Add operations ---

int32_t OCCTBRepGraphEdgeAddInternalVertex(OCCTBRepGraphRef g, int32_t edgeIndex,
                                            int32_t vertexIndex, int32_t orientation) {
    if (!g) return -1;
    try {
        auto rid = g->graph.Editor().Edges().AddInternalVertex(
            BRepGraph_EdgeId(edgeIndex),
            BRepGraph_VertexId(vertexIndex),
            oriFromInt(orientation));
        return rid.IsValid() ? (int32_t)rid.Index : -1;
    } catch (...) { return -1; }
}

int32_t OCCTBRepGraphFaceAddVertex(OCCTBRepGraphRef g, int32_t faceIndex,
                                    int32_t vertexIndex, int32_t orientation) {
    if (!g) return -1;
    try {
        auto rid = g->graph.Editor().Faces().AddVertex(
            BRepGraph_FaceId(faceIndex),
            BRepGraph_VertexId(vertexIndex),
            oriFromInt(orientation));
        return rid.IsValid() ? (int32_t)rid.Index : -1;
    } catch (...) { return -1; }
}

int32_t OCCTBRepGraphShellAddChild(OCCTBRepGraphRef g, int32_t shellIndex,
                                    int32_t childKind, int32_t childIndex, int32_t orientation) {
    if (!g) return -1;
    try {
        auto rid = g->graph.Editor().Shells().AddChild(
            BRepGraph_ShellId(shellIndex),
            BRepGraph_NodeId(kindFromInt(childKind), childIndex),
            oriFromInt(orientation));
        return rid.IsValid() ? (int32_t)rid.Index : -1;
    } catch (...) { return -1; }
}

int32_t OCCTBRepGraphSolidAddChild(OCCTBRepGraphRef g, int32_t solidIndex,
                                    int32_t childKind, int32_t childIndex, int32_t orientation) {
    if (!g) return -1;
    try {
        auto rid = g->graph.Editor().Solids().AddChild(
            BRepGraph_SolidId(solidIndex),
            BRepGraph_NodeId(kindFromInt(childKind), childIndex),
            oriFromInt(orientation));
        return rid.IsValid() ? (int32_t)rid.Index : -1;
    } catch (...) { return -1; }
}

int32_t OCCTBRepGraphCompoundAddChild(OCCTBRepGraphRef g, int32_t compoundIndex,
                                       int32_t childKind, int32_t childIndex, int32_t orientation) {
    if (!g) return -1;
    try {
        auto rid = g->graph.Editor().Compounds().AddChild(
            BRepGraph_CompoundId(compoundIndex),
            BRepGraph_NodeId(kindFromInt(childKind), childIndex),
            oriFromInt(orientation));
        return rid.IsValid() ? (int32_t)rid.Index : -1;
    } catch (...) { return -1; }
}

int32_t OCCTBRepGraphCompSolidAddSolid(OCCTBRepGraphRef g, int32_t compSolidIndex,
                                        int32_t solidIndex, int32_t orientation) {
    if (!g) return -1;
    try {
        auto rid = g->graph.Editor().CompSolids().AddSolid(
            BRepGraph_CompSolidId(compSolidIndex),
            BRepGraph_SolidId(solidIndex),
            oriFromInt(orientation));
        return rid.IsValid() ? (int32_t)rid.Index : -1;
    } catch (...) { return -1; }
}

// --- Remove operations ---

bool OCCTBRepGraphEdgeRemoveVertex(OCCTBRepGraphRef g, int32_t edgeIndex, int32_t vertexRefIndex) {
    if (!g) return false;
    try {
        return g->graph.Editor().Edges().RemoveVertex(
            BRepGraph_EdgeId(edgeIndex), BRepGraph_VertexRefId(vertexRefIndex));
    } catch (...) { return false; }
}

int32_t OCCTBRepGraphEdgeReplaceVertex(OCCTBRepGraphRef g, int32_t edgeIndex,
                                        int32_t oldVertexRefIndex, int32_t newVertexIndex) {
    if (!g) return -1;
    try {
        auto rid = g->graph.Editor().Edges().ReplaceVertex(
            BRepGraph_EdgeId(edgeIndex),
            BRepGraph_VertexRefId(oldVertexRefIndex),
            BRepGraph_VertexId(newVertexIndex));
        return rid.IsValid() ? (int32_t)rid.Index : -1;
    } catch (...) { return -1; }
}

bool OCCTBRepGraphWireRemoveCoEdge(OCCTBRepGraphRef g, int32_t wireIndex, int32_t coedgeRefIndex) {
    if (!g) return false;
    try {
        return g->graph.Editor().Wires().RemoveCoEdge(
            BRepGraph_WireId(wireIndex), BRepGraph_CoEdgeRefId(coedgeRefIndex));
    } catch (...) { return false; }
}

bool OCCTBRepGraphFaceRemoveVertex(OCCTBRepGraphRef g, int32_t faceIndex, int32_t vertexRefIndex) {
    if (!g) return false;
    try {
        return g->graph.Editor().Faces().RemoveVertex(
            BRepGraph_FaceId(faceIndex), BRepGraph_VertexRefId(vertexRefIndex));
    } catch (...) { return false; }
}

bool OCCTBRepGraphFaceRemoveWire(OCCTBRepGraphRef g, int32_t faceIndex, int32_t wireRefIndex) {
    if (!g) return false;
    try {
        return g->graph.Editor().Faces().RemoveWire(
            BRepGraph_FaceId(faceIndex), BRepGraph_WireRefId(wireRefIndex));
    } catch (...) { return false; }
}

bool OCCTBRepGraphShellRemoveFace(OCCTBRepGraphRef g, int32_t shellIndex, int32_t faceRefIndex) {
    if (!g) return false;
    try {
        return g->graph.Editor().Shells().RemoveFace(
            BRepGraph_ShellId(shellIndex), BRepGraph_FaceRefId(faceRefIndex));
    } catch (...) { return false; }
}

bool OCCTBRepGraphShellRemoveChild(OCCTBRepGraphRef g, int32_t shellIndex, int32_t childRefIndex) {
    if (!g) return false;
    try {
        return g->graph.Editor().Shells().RemoveChild(
            BRepGraph_ShellId(shellIndex), BRepGraph_ChildRefId(childRefIndex));
    } catch (...) { return false; }
}

bool OCCTBRepGraphSolidRemoveShell(OCCTBRepGraphRef g, int32_t solidIndex, int32_t shellRefIndex) {
    if (!g) return false;
    try {
        return g->graph.Editor().Solids().RemoveShell(
            BRepGraph_SolidId(solidIndex), BRepGraph_ShellRefId(shellRefIndex));
    } catch (...) { return false; }
}

bool OCCTBRepGraphSolidRemoveChild(OCCTBRepGraphRef g, int32_t solidIndex, int32_t childRefIndex) {
    if (!g) return false;
    try {
        return g->graph.Editor().Solids().RemoveChild(
            BRepGraph_SolidId(solidIndex), BRepGraph_ChildRefId(childRefIndex));
    } catch (...) { return false; }
}

bool OCCTBRepGraphCompoundRemoveChild(OCCTBRepGraphRef g, int32_t compoundIndex, int32_t childRefIndex) {
    if (!g) return false;
    try {
        return g->graph.Editor().Compounds().RemoveChild(
            BRepGraph_CompoundId(compoundIndex), BRepGraph_ChildRefId(childRefIndex));
    } catch (...) { return false; }
}

bool OCCTBRepGraphCompSolidRemoveSolid(OCCTBRepGraphRef g, int32_t compSolidIndex, int32_t solidRefIndex) {
    if (!g) return false;
    try {
        return g->graph.Editor().CompSolids().RemoveSolid(
            BRepGraph_CompSolidId(compSolidIndex), BRepGraph_SolidRefId(solidRefIndex));
    } catch (...) { return false; }
}

void OCCTBRepGraphRemoveRep(OCCTBRepGraphRef g, int32_t repKind, int32_t repIndex) {
    if (!g) return;
    try {
        BRepGraph_RepId rid;
        rid.RepKind = (BRepGraph_RepId::Kind)repKind;
        rid.Index = (uint32_t)repIndex;
        g->graph.Editor().Gen().RemoveRep(rid);
    } catch (...) {}
}

// --- Simple Ref setters (no TopLoc_Location, no Bnd_Box2d) ---

void OCCTBRepGraphSetVertexRefOrientation(OCCTBRepGraphRef g, int32_t vertexRefIndex, int32_t orientation) {
    if (!g) return;
    try {
        g->graph.Editor().Vertices().SetRefOrientation(
            BRepGraph_VertexRefId(vertexRefIndex), oriFromInt(orientation));
    } catch (...) {}
}

void OCCTBRepGraphSetVertexRefVertexDefId(OCCTBRepGraphRef g, int32_t vertexRefIndex, int32_t vertexIndex) {
    if (!g) return;
    try {
        g->graph.Editor().Vertices().SetRefVertexDefId(
            BRepGraph_VertexRefId(vertexRefIndex), BRepGraph_VertexId(vertexIndex));
    } catch (...) {}
}

void OCCTBRepGraphSetEdgeStartVertexRefId(OCCTBRepGraphRef g, int32_t edgeIndex, int32_t vertexRefIndex) {
    if (!g) return;
    try {
        g->graph.Editor().Edges().SetStartVertexRefId(
            BRepGraph_EdgeId(edgeIndex), BRepGraph_VertexRefId(vertexRefIndex));
    } catch (...) {}
}

void OCCTBRepGraphSetEdgeEndVertexRefId(OCCTBRepGraphRef g, int32_t edgeIndex, int32_t vertexRefIndex) {
    if (!g) return;
    try {
        g->graph.Editor().Edges().SetEndVertexRefId(
            BRepGraph_EdgeId(edgeIndex), BRepGraph_VertexRefId(vertexRefIndex));
    } catch (...) {}
}

void OCCTBRepGraphSetEdgeCurve3DRepId(OCCTBRepGraphRef g, int32_t edgeIndex, int32_t curve3DRepId) {
    if (!g) return;
    try {
        BRepGraph_Curve3DRepId rid;
        rid.Index = (uint32_t)curve3DRepId;
        g->graph.Editor().Edges().SetCurve3DRepId(BRepGraph_EdgeId(edgeIndex), rid);
    } catch (...) {}
}

void OCCTBRepGraphSetEdgePolygon3DRepId(OCCTBRepGraphRef g, int32_t edgeIndex, int32_t polygon3DRepId) {
    if (!g) return;
    try {
        BRepGraph_Polygon3DRepId rid;
        rid.Index = (uint32_t)polygon3DRepId;
        g->graph.Editor().Edges().SetPolygon3DRepId(BRepGraph_EdgeId(edgeIndex), rid);
    } catch (...) {}
}

void OCCTBRepGraphSetCoEdgeRefCoEdgeDefId(OCCTBRepGraphRef g, int32_t coedgeRefIndex, int32_t coedgeIndex) {
    if (!g) return;
    try {
        g->graph.Editor().CoEdges().SetRefCoEdgeDefId(
            BRepGraph_CoEdgeRefId(coedgeRefIndex), BRepGraph_CoEdgeId(coedgeIndex));
    } catch (...) {}
}

void OCCTBRepGraphSetCoEdgeEdgeDefId(OCCTBRepGraphRef g, int32_t coedgeIndex, int32_t edgeIndex) {
    if (!g) return;
    try {
        g->graph.Editor().CoEdges().SetEdgeDefId(
            BRepGraph_CoEdgeId(coedgeIndex), BRepGraph_EdgeId(edgeIndex));
    } catch (...) {}
}

void OCCTBRepGraphSetCoEdgeFaceDefId(OCCTBRepGraphRef g, int32_t coedgeIndex, int32_t faceIndex) {
    if (!g) return;
    try {
        g->graph.Editor().CoEdges().SetFaceDefId(
            BRepGraph_CoEdgeId(coedgeIndex), BRepGraph_FaceId(faceIndex));
    } catch (...) {}
}

void OCCTBRepGraphSetCoEdgeCurve2DRepId(OCCTBRepGraphRef g, int32_t coedgeIndex, int32_t curve2DRepId) {
    if (!g) return;
    try {
        BRepGraph_Curve2DRepId rid;
        rid.Index = (uint32_t)curve2DRepId;
        g->graph.Editor().CoEdges().SetCurve2DRepId(BRepGraph_CoEdgeId(coedgeIndex), rid);
    } catch (...) {}
}

void OCCTBRepGraphSetCoEdgePolygon2DRepId(OCCTBRepGraphRef g, int32_t coedgeIndex, int32_t polygon2DRepId) {
    if (!g) return;
    try {
        BRepGraph_Polygon2DRepId rid;
        rid.Index = (uint32_t)polygon2DRepId;
        g->graph.Editor().CoEdges().SetPolygon2DRepId(BRepGraph_CoEdgeId(coedgeIndex), rid);
    } catch (...) {}
}

void OCCTBRepGraphSetCoEdgePolygonOnTriRepId(OCCTBRepGraphRef g, int32_t coedgeIndex, int32_t polygonOnTriRepId) {
    if (!g) return;
    try {
        BRepGraph_PolygonOnTriRepId rid;
        rid.Index = (uint32_t)polygonOnTriRepId;
        g->graph.Editor().CoEdges().SetPolygonOnTriRepId(BRepGraph_CoEdgeId(coedgeIndex), rid);
    } catch (...) {}
}

void OCCTBRepGraphClearCoEdgePCurveBinding(OCCTBRepGraphRef g, int32_t coedgeIndex) {
    if (!g) return;
    try {
        g->graph.Editor().CoEdges().ClearPCurveBinding(BRepGraph_CoEdgeId(coedgeIndex));
    } catch (...) {}
}

void OCCTBRepGraphSetWireRefIsOuter(OCCTBRepGraphRef g, int32_t wireRefIndex, bool isOuter) {
    if (!g) return;
    try {
        g->graph.Editor().Wires().SetRefIsOuter(BRepGraph_WireRefId(wireRefIndex), isOuter);
    } catch (...) {}
}

void OCCTBRepGraphSetWireRefOrientation(OCCTBRepGraphRef g, int32_t wireRefIndex, int32_t orientation) {
    if (!g) return;
    try {
        g->graph.Editor().Wires().SetRefOrientation(
            BRepGraph_WireRefId(wireRefIndex), oriFromInt(orientation));
    } catch (...) {}
}

void OCCTBRepGraphSetWireRefWireDefId(OCCTBRepGraphRef g, int32_t wireRefIndex, int32_t wireIndex) {
    if (!g) return;
    try {
        g->graph.Editor().Wires().SetRefWireDefId(
            BRepGraph_WireRefId(wireRefIndex), BRepGraph_WireId(wireIndex));
    } catch (...) {}
}

void OCCTBRepGraphSetFaceSurfaceRepId(OCCTBRepGraphRef g, int32_t faceIndex, int32_t surfaceRepId) {
    if (!g) return;
    try {
        BRepGraph_SurfaceRepId rid;
        rid.Index = (uint32_t)surfaceRepId;
        g->graph.Editor().Faces().SetSurfaceRepId(BRepGraph_FaceId(faceIndex), rid);
    } catch (...) {}
}

void OCCTBRepGraphSetFaceRefOrientation(OCCTBRepGraphRef g, int32_t faceRefIndex, int32_t orientation) {
    if (!g) return;
    try {
        g->graph.Editor().Faces().SetRefOrientation(
            BRepGraph_FaceRefId(faceRefIndex), oriFromInt(orientation));
    } catch (...) {}
}

void OCCTBRepGraphSetFaceRefFaceDefId(OCCTBRepGraphRef g, int32_t faceRefIndex, int32_t faceIndex) {
    if (!g) return;
    try {
        g->graph.Editor().Faces().SetRefFaceDefId(
            BRepGraph_FaceRefId(faceRefIndex), BRepGraph_FaceId(faceIndex));
    } catch (...) {}
}

void OCCTBRepGraphSetShellRefOrientation(OCCTBRepGraphRef g, int32_t shellRefIndex, int32_t orientation) {
    if (!g) return;
    try {
        g->graph.Editor().Shells().SetRefOrientation(
            BRepGraph_ShellRefId(shellRefIndex), oriFromInt(orientation));
    } catch (...) {}
}

void OCCTBRepGraphSetShellRefShellDefId(OCCTBRepGraphRef g, int32_t shellRefIndex, int32_t shellIndex) {
    if (!g) return;
    try {
        g->graph.Editor().Shells().SetRefShellDefId(
            BRepGraph_ShellRefId(shellRefIndex), BRepGraph_ShellId(shellIndex));
    } catch (...) {}
}

void OCCTBRepGraphSetSolidRefOrientation(OCCTBRepGraphRef g, int32_t solidRefIndex, int32_t orientation) {
    if (!g) return;
    try {
        g->graph.Editor().Solids().SetRefOrientation(
            BRepGraph_SolidRefId(solidRefIndex), oriFromInt(orientation));
    } catch (...) {}
}

void OCCTBRepGraphSetSolidRefSolidDefId(OCCTBRepGraphRef g, int32_t solidRefIndex, int32_t solidIndex) {
    if (!g) return;
    try {
        g->graph.Editor().Solids().SetRefSolidDefId(
            BRepGraph_SolidRefId(solidRefIndex), BRepGraph_SolidId(solidIndex));
    } catch (...) {}
}

void OCCTBRepGraphSetOccurrenceChildDefId(OCCTBRepGraphRef g, int32_t occurrenceIndex,
                                            int32_t childKind, int32_t childIndex) {
    if (!g) return;
    try {
        g->graph.Editor().Occurrences().SetChildDefId(
            BRepGraph_OccurrenceId(occurrenceIndex),
            BRepGraph_NodeId(kindFromInt(childKind), childIndex));
    } catch (...) {}
}

void OCCTBRepGraphSetOccurrenceRefOccurrenceDefId(OCCTBRepGraphRef g, int32_t occurrenceRefIndex,
                                                    int32_t occurrenceIndex) {
    if (!g) return;
    try {
        g->graph.Editor().Occurrences().SetRefOccurrenceDefId(
            BRepGraph_OccurrenceRefId(occurrenceRefIndex),
            BRepGraph_OccurrenceId(occurrenceIndex));
    } catch (...) {}
}

void OCCTBRepGraphSetChildRefOrientation(OCCTBRepGraphRef g, int32_t childRefIndex, int32_t orientation) {
    if (!g) return;
    try {
        g->graph.Editor().Gen().SetChildRefOrientation(
            BRepGraph_ChildRefId(childRefIndex), oriFromInt(orientation));
    } catch (...) {}
}

void OCCTBRepGraphSetChildRefChildDefId(OCCTBRepGraphRef g, int32_t childRefIndex,
                                          int32_t childKind, int32_t childIndex) {
    if (!g) return;
    try {
        g->graph.Editor().Gen().SetChildRefChildDefId(
            BRepGraph_ChildRefId(childRefIndex),
            BRepGraph_NodeId(kindFromInt(childKind), childIndex));
    } catch (...) {}
}

// MARK: - BRepGraph EditorView v0.162.0 — geometric setters, location setters, PCurve API

// CoEdge geometric setters

void OCCTBRepGraphSetCoEdgeUVBox(OCCTBRepGraphRef g, int32_t coedgeIndex,
                                  double u1, double v1, double u2, double v2) {
    if (!g) return;
    try {
        g->graph.Editor().CoEdges().SetUVBox(
            BRepGraph_CoEdgeId(coedgeIndex), gp_Pnt2d(u1, v1), gp_Pnt2d(u2, v2));
    } catch (...) {}
}

void OCCTBRepGraphSetCoEdgeContinuity(OCCTBRepGraphRef g, int32_t coedgeIndex, int32_t continuity) {
    if (!g) return;
    try {
        g->graph.Editor().CoEdges().SetContinuity(
            BRepGraph_CoEdgeId(coedgeIndex), continuityFromInt(continuity));
    } catch (...) {}
}

void OCCTBRepGraphSetCoEdgeSeamContinuity(OCCTBRepGraphRef g, int32_t coedgeIndex, int32_t continuity) {
    if (!g) return;
    try {
        g->graph.Editor().CoEdges().SetSeamContinuity(
            BRepGraph_CoEdgeId(coedgeIndex), continuityFromInt(continuity));
    } catch (...) {}
}

void OCCTBRepGraphSetCoEdgeSeamPairId(OCCTBRepGraphRef g, int32_t coedgeIndex, int32_t seamPairCoedgeIndex) {
    if (!g) return;
    try {
        g->graph.Editor().CoEdges().SetSeamPairId(
            BRepGraph_CoEdgeId(coedgeIndex), BRepGraph_CoEdgeId(seamPairCoedgeIndex));
    } catch (...) {}
}

// Face triangulation rep binding

void OCCTBRepGraphSetFaceTriangulationRep(OCCTBRepGraphRef g, int32_t faceIndex, int32_t triRepId) {
    if (!g) return;
    try {
        BRepGraph_TriangulationRepId rid;
        rid.Index = (uint32_t)triRepId;
        g->graph.Editor().Faces().SetTriangulationRep(BRepGraph_FaceId(faceIndex), rid);
    } catch (...) {}
}

// CoEdge PCurve operations (Geom2d_Curve handle from OCCTCurve2D opaque)

int32_t OCCTBRepGraphCoEdgeCreateCurve2DRep(OCCTBRepGraphRef g, OCCTCurve2DRef curve2d) {
    if (!g || !curve2d) return -1;
    try {
        const Handle(Geom2d_Curve)& h = reinterpret_cast<OCCTCurve2D*>(curve2d)->curve;
        if (h.IsNull()) return -1;
        auto rid = g->graph.Editor().CoEdges().CreateCurve2DRep(h);
        return rid.IsValid() ? (int32_t)rid.Index : -1;
    } catch (...) { return -1; }
}

void OCCTBRepGraphCoEdgeSetPCurve(OCCTBRepGraphRef g, int32_t coedgeIndex, OCCTCurve2DRef curve2d) {
    if (!g) return;
    try {
        Handle(Geom2d_Curve) h;
        if (curve2d) h = reinterpret_cast<OCCTCurve2D*>(curve2d)->curve;
        g->graph.Editor().CoEdges().SetPCurve(BRepGraph_CoEdgeId(coedgeIndex), h);
    } catch (...) {}
}

void OCCTBRepGraphCoEdgeAddPCurve(OCCTBRepGraphRef g, int32_t edgeIndex, int32_t faceIndex,
                                    OCCTCurve2DRef curve2d, double first, double last,
                                    int32_t orientation) {
    if (!g || !curve2d) return;
    try {
        const Handle(Geom2d_Curve)& h = reinterpret_cast<OCCTCurve2D*>(curve2d)->curve;
        if (h.IsNull()) return;
        g->graph.Editor().CoEdges().AddPCurve(
            BRepGraph_EdgeId(edgeIndex),
            BRepGraph_FaceId(faceIndex),
            h, first, last, oriFromInt(orientation));
    } catch (...) {}
}

// Location setters (12-double 3x4 matrix, gp_Trsf::SetValues convention)

static TopLoc_Location locationFromMatrix(const double m[12]) {
    gp_Trsf trsf;
    trsf.SetValues(
        m[0], m[1], m[2],  m[3],
        m[4], m[5], m[6],  m[7],
        m[8], m[9], m[10], m[11]);
    return TopLoc_Location(trsf);
}

void OCCTBRepGraphSetVertexRefLocalLocation(OCCTBRepGraphRef g, int32_t vertexRefIndex, const double* matrix) {
    if (!g || !matrix) return;
    try {
        g->graph.Editor().Vertices().SetRefLocalLocation(
            BRepGraph_VertexRefId(vertexRefIndex), locationFromMatrix(matrix));
    } catch (...) {}
}

void OCCTBRepGraphSetCoEdgeRefLocalLocation(OCCTBRepGraphRef g, int32_t coedgeRefIndex, const double* matrix) {
    if (!g || !matrix) return;
    try {
        g->graph.Editor().CoEdges().SetRefLocalLocation(
            BRepGraph_CoEdgeRefId(coedgeRefIndex), locationFromMatrix(matrix));
    } catch (...) {}
}

void OCCTBRepGraphSetWireRefLocalLocation(OCCTBRepGraphRef g, int32_t wireRefIndex, const double* matrix) {
    if (!g || !matrix) return;
    try {
        g->graph.Editor().Wires().SetRefLocalLocation(
            BRepGraph_WireRefId(wireRefIndex), locationFromMatrix(matrix));
    } catch (...) {}
}

void OCCTBRepGraphSetFaceRefLocalLocation(OCCTBRepGraphRef g, int32_t faceRefIndex, const double* matrix) {
    if (!g || !matrix) return;
    try {
        g->graph.Editor().Faces().SetRefLocalLocation(
            BRepGraph_FaceRefId(faceRefIndex), locationFromMatrix(matrix));
    } catch (...) {}
}

void OCCTBRepGraphSetShellRefLocalLocation(OCCTBRepGraphRef g, int32_t shellRefIndex, const double* matrix) {
    if (!g || !matrix) return;
    try {
        g->graph.Editor().Shells().SetRefLocalLocation(
            BRepGraph_ShellRefId(shellRefIndex), locationFromMatrix(matrix));
    } catch (...) {}
}

void OCCTBRepGraphSetSolidRefLocalLocation(OCCTBRepGraphRef g, int32_t solidRefIndex, const double* matrix) {
    if (!g || !matrix) return;
    try {
        g->graph.Editor().Solids().SetRefLocalLocation(
            BRepGraph_SolidRefId(solidRefIndex), locationFromMatrix(matrix));
    } catch (...) {}
}

void OCCTBRepGraphSetOccurrenceRefLocalLocation(OCCTBRepGraphRef g, int32_t occurrenceRefIndex, const double* matrix) {
    if (!g || !matrix) return;
    try {
        g->graph.Editor().Occurrences().SetRefLocalLocation(
            BRepGraph_OccurrenceRefId(occurrenceRefIndex), locationFromMatrix(matrix));
    } catch (...) {}
}

void OCCTBRepGraphSetChildRefLocalLocation(OCCTBRepGraphRef g, int32_t childRefIndex, const double* matrix) {
    if (!g || !matrix) return;
    try {
        g->graph.Editor().Gen().SetChildRefLocalLocation(
            BRepGraph_ChildRefId(childRefIndex), locationFromMatrix(matrix));
    } catch (...) {}
}

// MARK: - BRepGraph EditorView v0.163.0 — ProductOps assembly building

int32_t OCCTBRepGraphLinkProductToTopology(OCCTBRepGraphRef g,
                                             int32_t shapeRootKind, int32_t shapeRootIndex,
                                             const double* placementMatrix) {
    if (!g) return -1;
    try {
        TopLoc_Location loc = placementMatrix ? locationFromMatrix(placementMatrix) : TopLoc_Location();
        BRepGraph_NodeId root(kindFromInt(shapeRootKind), shapeRootIndex);
        auto pid = g->graph.Editor().Products().LinkProductToTopology(root, loc);
        return pid.IsValid() ? (int32_t)pid.Index : -1;
    } catch (...) { return -1; }
}

int32_t OCCTBRepGraphCreateEmptyProduct(OCCTBRepGraphRef g) {
    if (!g) return -1;
    try {
        auto pid = g->graph.Editor().Products().CreateEmptyProduct();
        return pid.IsValid() ? (int32_t)pid.Index : -1;
    } catch (...) { return -1; }
}

/// Returns occurrence id, or -1 on failure. Outputs the new occurrence ref id via outOccRefId.
int32_t OCCTBRepGraphLinkProducts(OCCTBRepGraphRef g, int32_t parentProductIndex,
                                    int32_t referencedProductIndex,
                                    const double* placementMatrix,
                                    int32_t parentOccurrenceIndex,
                                    int32_t* outOccurrenceRefId) {
    if (!g || !placementMatrix) return -1;
    try {
        TopLoc_Location loc = locationFromMatrix(placementMatrix);
        BRepGraph_OccurrenceId parentOcc =
            (parentOccurrenceIndex >= 0)
                ? BRepGraph_OccurrenceId(parentOccurrenceIndex)
                : BRepGraph_OccurrenceId();
        BRepGraph_OccurrenceRefId outRefId;
        auto oid = g->graph.Editor().Products().LinkProducts(
            BRepGraph_ProductId(parentProductIndex),
            BRepGraph_ProductId(referencedProductIndex),
            loc, parentOcc, &outRefId);
        if (outOccurrenceRefId) *outOccurrenceRefId = outRefId.IsValid() ? (int32_t)outRefId.Index : -1;
        return oid.IsValid() ? (int32_t)oid.Index : -1;
    } catch (...) {
        if (outOccurrenceRefId) *outOccurrenceRefId = -1;
        return -1;
    }
}

bool OCCTBRepGraphProductRemoveOccurrence(OCCTBRepGraphRef g, int32_t productIndex, int32_t occurrenceRefIndex) {
    if (!g) return false;
    try {
        return g->graph.Editor().Products().RemoveOccurrence(
            BRepGraph_ProductId(productIndex), BRepGraph_OccurrenceRefId(occurrenceRefIndex));
    } catch (...) { return false; }
}

bool OCCTBRepGraphProductRemoveShapeRoot(OCCTBRepGraphRef g, int32_t productIndex) {
    if (!g) return false;
    try {
        return g->graph.Editor().Products().RemoveShapeRoot(BRepGraph_ProductId(productIndex));
    } catch (...) { return false; }
}

// MARK: - BRepGraph EditorView v0.164.0 — RepOps non-guard setters

#include <Geom_Surface.hxx>
#include <Geom_Curve.hxx>
#include <Geom2d_Curve.hxx>

void OCCTBRepGraphRepSetSurface(OCCTBRepGraphRef g, int32_t surfaceRepId, OCCTSurfaceRef surface) {
    if (!g || !surface) return;
    try {
        BRepGraph_SurfaceRepId rid; rid.Index = (uint32_t)surfaceRepId;
        const Handle(Geom_Surface)& h = reinterpret_cast<OCCTSurface*>(surface)->surface;
        g->graph.Editor().Reps().SetSurface(rid, h);
    } catch (...) {}
}

void OCCTBRepGraphRepSetCurve3D(OCCTBRepGraphRef g, int32_t curve3DRepId, OCCTCurve3DRef curve) {
    if (!g || !curve) return;
    try {
        BRepGraph_Curve3DRepId rid; rid.Index = (uint32_t)curve3DRepId;
        const Handle(Geom_Curve)& h = reinterpret_cast<OCCTCurve3D*>(curve)->curve;
        g->graph.Editor().Reps().SetCurve3D(rid, h);
    } catch (...) {}
}

void OCCTBRepGraphRepSetCurve2D(OCCTBRepGraphRef g, int32_t curve2DRepId, OCCTCurve2DRef curve) {
    if (!g || !curve) return;
    try {
        BRepGraph_Curve2DRepId rid; rid.Index = (uint32_t)curve2DRepId;
        const Handle(Geom2d_Curve)& h = reinterpret_cast<OCCTCurve2D*>(curve)->curve;
        g->graph.Editor().Reps().SetCurve2D(rid, h);
    } catch (...) {}
}

void OCCTBRepGraphRepSetTriangulation(OCCTBRepGraphRef g, int32_t triRepId, OCCTPolyTriangulationRef tri) {
    if (!g || !tri) return;
    try {
        BRepGraph_TriangulationRepId rid; rid.Index = (uint32_t)triRepId;
        const Handle(Poly_Triangulation)& h = reinterpret_cast<Poly_TriangulationOpaque*>(tri)->triangulation;
        g->graph.Editor().Reps().SetTriangulation(rid, h);
    } catch (...) {}
}

void OCCTBRepGraphRepSetPolygon3D(OCCTBRepGraphRef g, int32_t polyRepId, OCCTPolyPolygon3DRef poly) {
    if (!g || !poly) return;
    try {
        BRepGraph_Polygon3DRepId rid; rid.Index = (uint32_t)polyRepId;
        const Handle(Poly_Polygon3D)& h = reinterpret_cast<Poly_Polygon3DOpaque*>(poly)->polygon;
        g->graph.Editor().Reps().SetPolygon3D(rid, h);
    } catch (...) {}
}

void OCCTBRepGraphRepSetPolygon2D(OCCTBRepGraphRef g, int32_t polyRepId, OCCTPolyPolygon2DRef poly) {
    if (!g || !poly) return;
    try {
        BRepGraph_Polygon2DRepId rid; rid.Index = (uint32_t)polyRepId;
        const Handle(Poly_Polygon2D)& h = reinterpret_cast<Poly_Polygon2DOpaque*>(poly)->polygon;
        g->graph.Editor().Reps().SetPolygon2D(rid, h);
    } catch (...) {}
}

void OCCTBRepGraphRepSetPolygonOnTri(OCCTBRepGraphRef g, int32_t polyRepId, OCCTPolyPolygonOnTriRef poly) {
    if (!g || !poly) return;
    try {
        BRepGraph_PolygonOnTriRepId rid; rid.Index = (uint32_t)polyRepId;
        const Handle(Poly_PolygonOnTriangulation)& h = reinterpret_cast<Poly_PolygonOnTriangulationOpaque*>(poly)->polygon;
        g->graph.Editor().Reps().SetPolygonOnTri(rid, h);
    } catch (...) {}
}

void OCCTBRepGraphRepSetPolygonOnTriTriangulationId(OCCTBRepGraphRef g, int32_t polyOnTriRepId, int32_t triRepId) {
    if (!g) return;
    try {
        BRepGraph_PolygonOnTriRepId polyRid; polyRid.Index = (uint32_t)polyOnTriRepId;
        BRepGraph_TriangulationRepId triRid; triRid.Index = (uint32_t)triRepId;
        g->graph.Editor().Reps().SetPolygonOnTriTriangulationId(polyRid, triRid);
    } catch (...) {}
}

// MARK: - BRepGraph MeshView v0.164.0 — cache entry inspection

#include <BRepGraph_MeshCache.hxx>

bool OCCTBRepGraphCachedFaceMeshIsPresent(OCCTBRepGraphRef g, int32_t faceIndex) {
    if (!g) return false;
    try {
        const auto* entry = g->graph.Mesh().Faces().CachedMesh(BRepGraph_FaceId(faceIndex));
        return entry && entry->IsPresent();
    } catch (...) { return false; }
}

int32_t OCCTBRepGraphCachedFaceMeshTriRepCount(OCCTBRepGraphRef g, int32_t faceIndex) {
    if (!g) return 0;
    try {
        const auto* entry = g->graph.Mesh().Faces().CachedMesh(BRepGraph_FaceId(faceIndex));
        return entry ? (int32_t)entry->TriangulationRepIds.Length() : 0;
    } catch (...) { return 0; }
}

int32_t OCCTBRepGraphCachedFaceMeshActiveIndex(OCCTBRepGraphRef g, int32_t faceIndex) {
    if (!g) return -1;
    try {
        const auto* entry = g->graph.Mesh().Faces().CachedMesh(BRepGraph_FaceId(faceIndex));
        return entry ? (int32_t)entry->ActiveTriangulationIndex : -1;
    } catch (...) { return -1; }
}

uint32_t OCCTBRepGraphCachedFaceMeshStoredOwnGen(OCCTBRepGraphRef g, int32_t faceIndex) {
    if (!g) return 0;
    try {
        const auto* entry = g->graph.Mesh().Faces().CachedMesh(BRepGraph_FaceId(faceIndex));
        return entry ? entry->StoredOwnGen : 0u;
    } catch (...) { return 0; }
}

int32_t OCCTBRepGraphCachedFaceMeshTriRepId(OCCTBRepGraphRef g, int32_t faceIndex, int32_t repIndex) {
    if (!g) return -1;
    try {
        const auto* entry = g->graph.Mesh().Faces().CachedMesh(BRepGraph_FaceId(faceIndex));
        if (!entry) return -1;
        if (repIndex < 0 || repIndex >= entry->TriangulationRepIds.Length()) return -1;
        const auto& rid = entry->TriangulationRepIds.Value(repIndex);
        return rid.IsValid() ? (int32_t)rid.Index : -1;
    } catch (...) { return -1; }
}

bool OCCTBRepGraphCachedEdgeMeshIsPresent(OCCTBRepGraphRef g, int32_t edgeIndex) {
    if (!g) return false;
    try {
        const auto* entry = g->graph.Mesh().Edges().CachedMesh(BRepGraph_EdgeId(edgeIndex));
        return entry && entry->IsPresent();
    } catch (...) { return false; }
}

int32_t OCCTBRepGraphCachedEdgeMeshPolygon3DRepId(OCCTBRepGraphRef g, int32_t edgeIndex) {
    if (!g) return -1;
    try {
        const auto* entry = g->graph.Mesh().Edges().CachedMesh(BRepGraph_EdgeId(edgeIndex));
        if (!entry) return -1;
        return entry->Polygon3DRepId.IsValid() ? (int32_t)entry->Polygon3DRepId.Index : -1;
    } catch (...) { return -1; }
}

uint32_t OCCTBRepGraphCachedEdgeMeshStoredOwnGen(OCCTBRepGraphRef g, int32_t edgeIndex) {
    if (!g) return 0;
    try {
        const auto* entry = g->graph.Mesh().Edges().CachedMesh(BRepGraph_EdgeId(edgeIndex));
        return entry ? entry->StoredOwnGen : 0u;
    } catch (...) { return 0; }
}

bool OCCTBRepGraphCachedCoEdgeMeshIsPresent(OCCTBRepGraphRef g, int32_t coedgeIndex) {
    if (!g) return false;
    try {
        const auto* entry = g->graph.Mesh().CoEdges().CachedMesh(BRepGraph_CoEdgeId(coedgeIndex));
        return entry && entry->IsPresent();
    } catch (...) { return false; }
}

int32_t OCCTBRepGraphCachedCoEdgeMeshPolygon2DRepId(OCCTBRepGraphRef g, int32_t coedgeIndex) {
    if (!g) return -1;
    try {
        const auto* entry = g->graph.Mesh().CoEdges().CachedMesh(BRepGraph_CoEdgeId(coedgeIndex));
        if (!entry) return -1;
        return entry->Polygon2DRepId.IsValid() ? (int32_t)entry->Polygon2DRepId.Index : -1;
    } catch (...) { return -1; }
}

int32_t OCCTBRepGraphCachedCoEdgeMeshPolygonOnTriRepCount(OCCTBRepGraphRef g, int32_t coedgeIndex) {
    if (!g) return 0;
    try {
        const auto* entry = g->graph.Mesh().CoEdges().CachedMesh(BRepGraph_CoEdgeId(coedgeIndex));
        return entry ? (int32_t)entry->PolygonOnTriRepIds.Length() : 0;
    } catch (...) { return 0; }
}

int32_t OCCTBRepGraphCachedCoEdgeMeshPolygonOnTriRepId(OCCTBRepGraphRef g, int32_t coedgeIndex, int32_t repIndex) {
    if (!g) return -1;
    try {
        const auto* entry = g->graph.Mesh().CoEdges().CachedMesh(BRepGraph_CoEdgeId(coedgeIndex));
        if (!entry) return -1;
        if (repIndex < 0 || repIndex >= entry->PolygonOnTriRepIds.Length()) return -1;
        const auto& rid = entry->PolygonOnTriRepIds.Value(repIndex);
        return rid.IsValid() ? (int32_t)rid.Index : -1;
    } catch (...) { return -1; }
}

uint32_t OCCTBRepGraphCachedCoEdgeMeshStoredOwnGen(OCCTBRepGraphRef g, int32_t coedgeIndex) {
    if (!g) return 0;
    try {
        const auto* entry = g->graph.Mesh().CoEdges().CachedMesh(BRepGraph_CoEdgeId(coedgeIndex));
        return entry ? entry->StoredOwnGen : 0u;
    } catch (...) { return 0; }
}

// MARK: - BRepGraph ML Export & Sampling (v0.136.0)

#include <BRepTools.hxx>
#include <GeomLProp_SLProps.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Face.hxx>
#include <Precision.hxx>

int32_t OCCTBRepGraphSampleFaceUVGrid(OCCTBRepGraphRef g, int32_t faceIndex,
    int32_t uSamples, int32_t vSamples,
    double* outPositions, double* outNormals,
    double* outGaussianCurvatures, double* outMeanCurvatures)
{
    if (!g || uSamples < 1 || vSamples < 1) return 0;
    try {
        // Reconstruct the face shape to get proper UV bounds (trimmed by wires)
        BRepGraph_NodeId nid(BRepGraph_NodeId::Kind::Face, faceIndex);
        TopoDS_Shape faceShape = g->graph.Shapes().Shape(nid);
        if (faceShape.IsNull()) return 0;
        const TopoDS_Face& face = TopoDS::Face(faceShape);

        double uMin, uMax, vMin, vMax;
        BRepTools::UVBounds(face, uMin, uMax, vMin, vMax);

        // Get the surface
        auto& surfHandle = BRepGraph_Tool::Face::Surface(g->graph, BRepGraph_FaceId(faceIndex));
        if (surfHandle.IsNull()) return 0;

        int32_t count = uSamples * vSamples;
        double uStep = (uSamples > 1) ? (uMax - uMin) / (uSamples - 1) : 0.0;
        double vStep = (vSamples > 1) ? (vMax - vMin) / (vSamples - 1) : 0.0;

        for (int32_t iv = 0; iv < vSamples; ++iv) {
            double v = vMin + iv * vStep;
            for (int32_t iu = 0; iu < uSamples; ++iu) {
                double u = uMin + iu * uStep;
                int32_t idx = iv * uSamples + iu;

                GeomLProp_SLProps props(surfHandle, u, v, 2, Precision::Confusion());

                // Position
                gp_Pnt pnt = props.Value();
                outPositions[idx * 3 + 0] = pnt.X();
                outPositions[idx * 3 + 1] = pnt.Y();
                outPositions[idx * 3 + 2] = pnt.Z();

                // Normal
                if (props.IsNormalDefined()) {
                    gp_Dir nrm = props.Normal();
                    outNormals[idx * 3 + 0] = nrm.X();
                    outNormals[idx * 3 + 1] = nrm.Y();
                    outNormals[idx * 3 + 2] = nrm.Z();
                } else {
                    outNormals[idx * 3 + 0] = 0.0;
                    outNormals[idx * 3 + 1] = 0.0;
                    outNormals[idx * 3 + 2] = 0.0;
                }

                // Curvatures
                if (props.IsCurvatureDefined()) {
                    outGaussianCurvatures[idx] = props.GaussianCurvature();
                    outMeanCurvatures[idx] = props.MeanCurvature();
                } else {
                    outGaussianCurvatures[idx] = 0.0;
                    outMeanCurvatures[idx] = 0.0;
                }
            }
        }
        return count;
    } catch (...) { return 0; }
}

int32_t OCCTBRepGraphSampleEdgeCurve(OCCTBRepGraphRef g, int32_t edgeIndex,
    int32_t count, double* outPoints)
{
    if (!g || count < 1) return 0;
    try {
        if (!BRepGraph_Tool::Edge::HasCurve(g->graph, BRepGraph_EdgeId(edgeIndex)))
            return 0;

        auto& curveHandle = BRepGraph_Tool::Edge::Curve(g->graph, BRepGraph_EdgeId(edgeIndex));
        if (curveHandle.IsNull()) return 0;

        auto range = BRepGraph_Tool::Edge::Range(g->graph, BRepGraph_EdgeId(edgeIndex));
        double first = range.first;
        double last = range.second;
        double step = (count > 1) ? (last - first) / (count - 1) : 0.0;

        for (int32_t i = 0; i < count; ++i) {
            double t = first + i * step;
            gp_Pnt pnt = curveHandle->Value(t);
            outPoints[i * 3 + 0] = pnt.X();
            outPoints[i * 3 + 1] = pnt.Y();
            outPoints[i * 3 + 2] = pnt.Z();
        }
        return count;
    } catch (...) { return 0; }
}
