// Copyright (c) gsdali. Licensed under LGPL 2.1.
//
// Wraps OCCT's Message_ProgressIndicator into a Swift protocol so callers of
// loadSTEP / loadIGES can subscribe to progress updates and cooperatively
// cancel long-running imports.
//
// Driver: issue #98 / OCCTSwiftTools' CADFileLoader.load(from:format:) async
// API needs a progress + cancel channel for GUI consumers.

import Foundation
import OCCTBridge

/// Progress + cancellation channel for long-running OCCT import operations.
///
/// Pass an `ImportProgress` to the `progress:` parameter on `Shape.load(from:)`,
/// `Shape.loadSTEP(from:unitInMeters:)`, `Shape.loadIGES(from:)`,
/// `Shape.loadIGESRobust(from:)`, `Document.load(from:)`, and
/// `Document.loadSTEP(from:modes:)` to receive progress callbacks during the
/// reader's `TransferRoots` phase, and to request cooperative cancellation.
///
/// `progress(fraction:step:)` is called on whatever thread the import runs on
/// — typically the calling thread for synchronous loaders, or the executor of
/// a `Task.detached`. UI updates should hop to the main actor.
///
/// `shouldCancel()` is polled at OCCT's progress-checkpoint boundaries
/// (typically once per transferred entity in STEP/IGES). Returning `true` aborts
/// the in-flight import; the loader throws `ImportError.cancelled`.
public protocol ImportProgress: AnyObject, Sendable {
    /// Called as the importer advances. `fraction` is `0.0...1.0`. `step` is a
    /// human-readable name of the current sub-task (may be empty).
    func progress(fraction: Double, step: String)

    /// Return `true` to cooperatively cancel the in-flight import. Polled at
    /// each progress checkpoint. The loader throws `ImportError.cancelled` on
    /// the next boundary after this returns `true`.
    func shouldCancel() -> Bool
}

/// Default no-op cancellation. Callers can adopt `ImportProgress` and only
/// implement `progress(fraction:step:)` to get a progress-only channel.
extension ImportProgress {
    public func shouldCancel() -> Bool { false }
}

// MARK: - Bridge plumbing

/// Box that holds an `ImportProgress` reference at a stable address so the C
/// callback can recover it from `userData`.
private final class ImportProgressBox {
    let progress: ImportProgress
    init(_ progress: ImportProgress) { self.progress = progress }
}

/// Run `body` with an `OCCTImportProgress*` pointing to a struct that forwards
/// to the given Swift `ImportProgress`. The pointer is valid only for the
/// duration of `body`. Pass nil if `progress` is nil.
internal func withImportProgress<T>(
    _ progress: ImportProgress?,
    _ body: (UnsafePointer<OCCTImportProgress>?) -> T
) -> T {
    guard let progress else {
        return body(nil)
    }
    let box = ImportProgressBox(progress)
    let userData = Unmanaged.passUnretained(box).toOpaque()
    var ctx = OCCTImportProgress(
        onProgress: { fraction, step, userData in
            guard let userData else { return }
            let box = Unmanaged<ImportProgressBox>.fromOpaque(userData).takeUnretainedValue()
            let stepStr = step.map { String(cString: $0) } ?? ""
            box.progress.progress(fraction: fraction, step: stepStr)
        },
        shouldCancel: { userData in
            guard let userData else { return false }
            let box = Unmanaged<ImportProgressBox>.fromOpaque(userData).takeUnretainedValue()
            return box.progress.shouldCancel()
        },
        userData: userData
    )
    return withExtendedLifetime(box) {
        withUnsafePointer(to: &ctx) { body($0) }
    }
}
