import Foundation

/// What a call can say instead of capturing.
public enum ScreenshotsError: Error, Equatable, CustomStringConvertible {
    /// What is wrong with the call or the project, every problem at once: nothing was built, launched or written.
    case refused([String])
    /// The app did not build: the scheme, and the build's error lines.
    case build(String, String)
    /// A simulator or the Mac would not do what it was asked: the step, and what it said.
    case device(String, String)
    /// No screen could be captured, and why.
    case nothing(String)

    public var description: String {
        switch self {
        case .refused(let problems):
            if problems.count == 1 { return "\(problems[0]); nothing was captured" }
            return "\(problems.count) problems, so nothing was captured:\n" + problems.map { "- \($0)" }.joined(separator: "\n")
        case .build(let scheme, let lines): return "\(scheme) did not build for the screenshots, so nothing was captured:\n\(lines)"
        case .device(let step, let said): return "could not \(step): \(said)"
        case .nothing(let reason): return "no screen was captured: \(reason)"
        }
    }
}
