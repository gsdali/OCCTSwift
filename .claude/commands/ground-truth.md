# Generate and Run Ground Truth C++ Test

Generate a ground truth C++ test file for a new release, compile it against the local OCCT xcframework, run it, and report results.

**Arguments:** `$ARGUMENTS` should be the version number and OCCT classes, e.g. `v51 GeomFill_Pipe GCPnts_AbscissaPoint BRepTools_WireExplorer`

## Instructions

1. **Parse arguments.** Extract the version number (e.g., `v51`) and the list of OCCT classes from `$ARGUMENTS`. If no arguments are provided, ask the user for the version number and class list.

2. **Read OCCT headers** for each specified class. Headers are at:
   ```
   Libraries/OCCT.xcframework/macos-arm64/Headers/{ClassName}.hxx
   ```
   Read each header to understand constructors, public methods, and required includes.

3. **Verify symbols exist** in the static library for each class:
   ```bash
   nm -C Libraries/OCCT.xcframework/macos-arm64/libOCCT-macos.a 2>/dev/null | grep "ClassName" | head -10
   ```
   If a class has no symbols, flag it as potentially header-only or abstract and skip it.

4. **Generate the test file** at `/tmp/occt_v{XX}_test.mm` following this template:

   ```objc
   // Ground truth C++ test for OCCTSwift v0.{XX}.0
   // Tests OCCT classes directly to verify API before wrapping

   #import <Foundation/Foundation.h>
   #include <cstdio>
   #include <cmath>

   // Suppress OCCT 8.0.0 deprecation warnings
   #pragma clang diagnostic push
   #pragma clang diagnostic ignored "-W#pragma-messages"
   #pragma clang diagnostic ignored "-Wdeprecated-declarations"

   // OCCT includes
   #include <Standard.hxx>
   #include <gp_Pnt.hxx>
   #include <gp_Vec.hxx>
   #include <gp_Dir.hxx>
   #include <gp_Ax1.hxx>
   #include <gp_Ax2.hxx>
   // ... (add all needed includes)

   #pragma clang diagnostic pop

   static int passed = 0, failed = 0;

   #define TEST(name) printf("  Testing %s... ", name);
   #define PASS() { printf("PASSED\n"); passed++; }
   #define FAIL(msg) { printf("FAILED: %s\n", msg); failed++; }
   #define CHECK(cond, msg) if (cond) { PASS(); } else { FAIL(msg); }

   // === Test functions for each class ===

   void test_ClassName() {
       printf("\n=== ClassName ===\n");
       try {
           // Test each public method
           TEST("basic construction")
           // ... actual test code ...
           CHECK(/* condition */, "expected description")
       } catch (...) {
           FAIL("exception thrown")
       }
   }

   // ... more test functions ...

   int main() {
       printf("OCCTSwift v0.{XX}.0 Ground Truth Tests\n");
       printf("======================================\n");

       // Call all test functions
       test_ClassName();
       // ...

       printf("\n======================================\n");
       printf("Results: %d passed, %d failed\n", passed, failed);
       return failed > 0 ? 1 : 0;
   }
   ```

   **Key rules for the test file:**
   - Wrap every OCCT call in `try/catch(...)` to prevent crashes
   - Use `#pragma clang diagnostic push/pop` around OCCT includes to suppress deprecation warnings
   - Test realistic scenarios (create geometry, then query it) rather than just constructing objects
   - Each test function should test 2-4 operations on one class
   - Use tolerance-based comparisons for floating point: `fabs(a - b) < 1e-6`

5. **Compile the test** using the exact project invocation:
   ```bash
   cd /Users/elb/Projects/OCCTSwift && \
   clang++ -std=c++17 -ObjC++ -w \
     -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
     -L"Libraries/OCCT.xcframework/macos-arm64" \
     -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
     /tmp/occt_v{XX}_test.mm -o /tmp/occt_v{XX}_test
   ```

6. **Run the test:**
   ```bash
   DYLD_LIBRARY_PATH="Libraries/OCCT.xcframework/macos-arm64" /tmp/occt_v{XX}_test
   ```

7. **Report results.** If compilation fails, show the errors and suggest fixes. If tests fail, show which ones and why. If all pass, report success and confirm these classes are ready for wrapping.

8. **If any test fails**, fix the test code and re-compile/re-run until all pass. The ground truth test must be fully green before proceeding to bridge implementation.

## Output
- Show the generated test file path
- Show compilation output (errors if any)
- Show test execution output
- Summarize: N classes tested, M operations verified, all pass / X failures
