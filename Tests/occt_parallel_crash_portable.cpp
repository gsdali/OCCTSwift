// Portable C++17 reproducer for OCCT parallel crashes (NO IGES, NO Apple APIs)
// Targets: Extrema_ExtElCS and ShapeUpgrade_FaceDivide under high concurrency
//
// Compiles on Windows (MSVC), Linux (GCC/Clang), macOS (Apple Clang)
//
// Windows (MSVC):
//   cl /std:c++17 /EHsc /I<OCCT_INCLUDE> occt_parallel_crash_portable.cpp /link /LIBPATH:<OCCT_LIB> TKernel.lib TKMath.lib TKG2d.lib TKG3d.lib TKGeomBase.lib TKBRep.lib TKGeomAlgo.lib TKTopAlgo.lib TKPrim.lib TKBO.lib TKBool.lib TKFillet.lib TKShHealing.lib TKOffset.lib TKMesh.lib
//
// Linux/macOS:
//   clang++ -std=c++17 -w -I<OCCT_INCLUDE> -L<OCCT_LIB> -lTKernel -lTKMath -lTKG2d -lTKG3d -lTKGeomBase -lTKBRep -lTKGeomAlgo -lTKTopAlgo -lTKPrim -lTKBO -lTKBool -lTKFillet -lTKShHealing -lTKOffset -lTKMesh occt_parallel_crash_portable.cpp -o occt_parallel_crash -lpthread
//
// For static lib on macOS (our xcframework):
//   clang++ -std=c++17 -ObjC++ -w -I"Libraries/OCCT.xcframework/macos-arm64/Headers" -L"Libraries/OCCT.xcframework/macos-arm64" -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ occt_parallel_crash_portable.cpp -o occt_parallel_crash

#include <thread>
#include <vector>
#include <atomic>
#include <mutex>
#include <queue>
#include <functional>
#include <condition_variable>
#include <cstdio>
#include <cstdlib>
#include <chrono>

#include <Extrema_ExtElCS.hxx>
#include <gp_Lin.hxx>
#include <gp_Pln.hxx>
#include <gp_Cylinder.hxx>
#include <gp_Cone.hxx>
#include <gp_Sphere.hxx>

#include <ShapeUpgrade_FaceDivide.hxx>
#include <ShapeUpgrade_ShapeDivideContinuity.hxx>
#include <ShapeUpgrade_UnifySameDomain.hxx>
#include <ShapeFix_Shape.hxx>
#include <ShapeFix_Wire.hxx>
#include <ShapeAnalysis_Wire.hxx>

#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRepPrimAPI_MakeCone.hxx>
#include <BRepPrimAPI_MakeTorus.hxx>
#include <BRepAlgoAPI_Fuse.hxx>
#include <BRepAlgoAPI_Cut.hxx>
#include <BRepFilletAPI_MakeFillet.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepGProp.hxx>
#include <GProp_GProps.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>

// ============================================================
// Simple thread pool (portable C++17, no platform dependencies)
// ============================================================
class ThreadPool {
public:
    explicit ThreadPool(int numThreads) : stop_(false) {
        for (int i = 0; i < numThreads; i++) {
            workers_.emplace_back([this] {
                while (true) {
                    std::function<void()> task;
                    {
                        std::unique_lock<std::mutex> lock(mutex_);
                        cv_.wait(lock, [this] { return stop_ || !tasks_.empty(); });
                        if (stop_ && tasks_.empty()) return;
                        task = std::move(tasks_.front());
                        tasks_.pop();
                    }
                    task();
                }
            });
        }
    }

    void submit(std::function<void()> task) {
        {
            std::lock_guard<std::mutex> lock(mutex_);
            tasks_.push(std::move(task));
        }
        cv_.notify_one();
    }

    void waitAll() {
        // Spin until queue is drained and all workers are idle
        while (true) {
            {
                std::lock_guard<std::mutex> lock(mutex_);
                if (tasks_.empty()) break;
            }
            std::this_thread::yield();
        }
        // Give workers time to finish current tasks
        std::this_thread::sleep_for(std::chrono::milliseconds(100));
    }

    ~ThreadPool() {
        {
            std::lock_guard<std::mutex> lock(mutex_);
            stop_ = true;
        }
        cv_.notify_all();
        for (auto& w : workers_) w.join();
    }

private:
    std::vector<std::thread> workers_;
    std::queue<std::function<void()>> tasks_;
    std::mutex mutex_;
    std::condition_variable cv_;
    bool stop_;
};

// ============================================================
// Task counters
// ============================================================
static std::atomic<int> g_ops{0};

// ============================================================
// Extrema tasks — independent objects, no shared state
// ============================================================

void extrema_line_cylinder(int seed) {
    double offset = seed * 0.0137;
    gp_Lin line(gp_Pnt(offset, offset, offset), gp_Dir(1, 0.1 * offset, 0));
    gp_Cylinder cyl(gp_Ax3(gp_Pnt(5 + offset, 5, 0), gp_Dir(0, 0, 1)), 3.0 + offset * 0.1);
    Extrema_ExtElCS extrema(line, cyl);
    if (extrema.IsDone()) {
        int nb = extrema.NbExt();
        for (int j = 1; j <= nb; j++) {
            Extrema_POnCurv pc; Extrema_POnSurf ps;
            extrema.Points(j, pc, ps);
            (void)pc.Value(); (void)ps.Value();
        }
    }
    g_ops.fetch_add(1);
}

void extrema_line_sphere(int seed) {
    double offset = seed * 0.023;
    gp_Lin line(gp_Pnt(0, 0, offset), gp_Dir(1, 0, 0));
    gp_Sphere sph(gp_Ax3(gp_Pnt(10 + offset, 0, 0), gp_Dir(0, 0, 1)), 5.0);
    Extrema_ExtElCS extrema(line, sph);
    if (extrema.IsDone()) {
        int nb = extrema.NbExt();
        for (int j = 1; j <= nb; j++) {
            Extrema_POnCurv pc; Extrema_POnSurf ps;
            extrema.Points(j, pc, ps);
        }
    }
    g_ops.fetch_add(1);
}

void extrema_line_cone(int seed) {
    double offset = seed * 0.019;
    gp_Lin line(gp_Pnt(offset, 0, 0), gp_Dir(0, 1, 0));
    gp_Cone cone(gp_Ax3(gp_Pnt(5, 5 + offset, 0), gp_Dir(0, 0, 1)), 0.3, 2.0);
    try {
        Extrema_ExtElCS extrema(line, cone);
        if (extrema.IsDone() && !extrema.IsParallel()) {
            int nb = extrema.NbExt();
            for (int j = 1; j <= nb; j++) {
                Extrema_POnCurv pc; Extrema_POnSurf ps;
                extrema.Points(j, pc, ps);
            }
        }
    } catch (...) {
        // Extrema_ExtElCS(Lin, Cone) can throw — this is one of the crash sites
    }
    g_ops.fetch_add(1);
}

// ============================================================
// ShapeUpgrade tasks — independent objects, no shared state
// ============================================================

void task_face_divide(int seed) {
    double s = 10.0 + seed * 0.03;
    BRepPrimAPI_MakeBox box(s, s + 5, s + 10);
    TopExp_Explorer ex(box.Shape(), TopAbs_FACE);
    if (ex.More()) {
        TopoDS_Face face = TopoDS::Face(ex.Current());
        try {
            ShapeUpgrade_FaceDivide divider(face);
            divider.Perform();
        } catch (...) {}
    }
    g_ops.fetch_add(1);
}

void task_face_divide_cylinder(int seed) {
    double r = 5.0 + seed * 0.02;
    BRepPrimAPI_MakeCylinder cyl(r, 20.0);
    TopExp_Explorer ex(cyl.Shape(), TopAbs_FACE);
    if (ex.More()) {
        TopoDS_Face face = TopoDS::Face(ex.Current());
        try {
            ShapeUpgrade_FaceDivide divider(face);
            divider.Perform();
        } catch (...) {}
    }
    g_ops.fetch_add(1);
}

void task_shape_divide_continuity(int seed) {
    double s = 10.0 + seed * 0.04;
    BRepPrimAPI_MakeBox box(s, s + 3, s + 7);
    try {
        ShapeUpgrade_ShapeDivideContinuity divider(box.Shape());
        divider.Perform();
    } catch (...) {}
    g_ops.fetch_add(1);
}

// ============================================================
// Boolean + fillet tasks (allocator pressure)
// ============================================================

void task_boolean(int seed) {
    double s = 10.0 + seed * 0.07;
    BRepPrimAPI_MakeBox box(s, s, s);
    BRepPrimAPI_MakeSphere sphere(gp_Pnt(s/2, s/2, s/2), s * 0.6);
    BRepAlgoAPI_Cut cut(box.Shape(), sphere.Shape());
    if (cut.IsDone()) {
        GProp_GProps props;
        BRepGProp::VolumeProperties(cut.Shape(), props);
        (void)props.Mass();
    }
    g_ops.fetch_add(1);
}

void task_fillet(int seed) {
    double s = 20.0 + seed * 0.04;
    BRepPrimAPI_MakeBox box(s, s, s);
    TopoDS_Shape shape = box.Shape();
    BRepFilletAPI_MakeFillet fillet(shape);
    TopExp_Explorer ex(shape, TopAbs_EDGE);
    if (ex.More()) {
        fillet.Add(1.0, TopoDS::Edge(ex.Current()));
        try {
            fillet.Build();
            if (fillet.IsDone()) {
                BRepCheck_Analyzer analyzer(fillet.Shape());
                (void)analyzer.IsValid();
            }
        } catch (...) {}
    }
    g_ops.fetch_add(1);
}

void task_shape_fix(int seed) {
    double s = 12.0 + seed * 0.06;
    BRepPrimAPI_MakeBox box(s, s, s);
    BRepPrimAPI_MakeSphere sph(gp_Pnt(s/2, s/2, s/2), s * 0.7);
    BRepAlgoAPI_Cut cut(box.Shape(), sph.Shape());
    if (cut.IsDone()) {
        try {
            ShapeFix_Shape fixer(cut.Shape());
            fixer.Perform();
            (void)fixer.Shape();
        } catch (...) {}
    }
    g_ops.fetch_add(1);
}

void task_unify(int seed) {
    double s = 10.0 + seed * 0.03;
    BRepPrimAPI_MakeBox box1(s, s, s);
    BRepPrimAPI_MakeBox box2(gp_Pnt(s, 0, 0), s, s, s);
    BRepAlgoAPI_Fuse fuse(box1.Shape(), box2.Shape());
    if (fuse.IsDone()) {
        try {
            ShapeUpgrade_UnifySameDomain unifier(fuse.Shape());
            unifier.Build();
            (void)unifier.Shape();
        } catch (...) {}
    }
    g_ops.fetch_add(1);
}

void task_shape_creation(int seed) {
    BRepPrimAPI_MakeBox box(10 + seed * 0.01, 20, 30);
    BRepPrimAPI_MakeCylinder cyl(5.0, 15.0);
    BRepPrimAPI_MakeCone cone(5.0, 2.0, 10.0);
    BRepPrimAPI_MakeTorus torus(10.0, 3.0);
    GProp_GProps props;
    BRepGProp::VolumeProperties(box.Shape(), props);
    BRepGProp::VolumeProperties(cyl.Shape(), props);
    BRepGProp::VolumeProperties(cone.Shape(), props);
    BRepGProp::VolumeProperties(torus.Shape(), props);
    g_ops.fetch_add(1);
}

// ============================================================
// Main — fire hundreds of concurrent tasks via thread pool
// ============================================================

int main(int argc, char* argv[]) {
    // Hardware concurrency or default to 16
    int numWorkers = std::thread::hardware_concurrency();
    if (numWorkers < 8) numWorkers = 16;

    // Allow override from command line
    int tasksPerRound = 300;
    int numRounds = 30;
    if (argc > 1) tasksPerRound = atoi(argv[1]);
    if (argc > 2) numRounds = atoi(argv[2]);

    printf("OCCT Parallel Crash Reproducer (Portable C++17, NO IGES)\n");
    printf("=========================================================\n");
    printf("Workers: %d, Tasks/round: %d, Rounds: %d\n", numWorkers, tasksPerRound, numRounds);
    printf("Total: %d concurrent operations\n", tasksPerRound * numRounds);
    printf("Each task creates independent OCCT objects. No shared mutable state.\n\n");

    printf("Task mix: Extrema (line-cyl/sphere/cone), ShapeUpgrade (FaceDivide,\n");
    printf("  ShapeDivideContinuity), Boolean, Fillet, ShapeFix, Unify, ShapeCreation\n\n");

    for (int round = 1; round <= numRounds; round++) {
        printf("Round %d/%d...", round, numRounds);
        fflush(stdout);
        g_ops.store(0);

        {
            ThreadPool pool(numWorkers);

            for (int i = 0; i < tasksPerRound; i++) {
                int seed = round * 10000 + i;
                pool.submit([seed, i] {
                    switch (i % 10) {
                        case 0: extrema_line_cylinder(seed); break;
                        case 1: extrema_line_sphere(seed); break;
                        case 2: extrema_line_cone(seed); break;
                        case 3: task_face_divide(seed); break;
                        case 4: task_face_divide_cylinder(seed); break;
                        case 5: task_shape_divide_continuity(seed); break;
                        case 6: task_boolean(seed); break;
                        case 7: task_fillet(seed); break;
                        case 8: task_shape_fix(seed); break;
                        case 9: task_unify(seed); break;
                    }
                });
            }
            // ThreadPool destructor waits for all tasks
        }

        printf(" %d ops\n", g_ops.load());
    }

    printf("\nAll %d rounds completed without crash.\n", numRounds);
    return 0;
}
