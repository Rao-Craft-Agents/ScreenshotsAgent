import Foundation

/// A child process that may be ended from any thread, once it has started or before: a cancel that comes first is
/// kept and ends the process the moment it starts. Its exit is heard through `terminationHandler`, set before it
/// starts, never by `waitUntilExit`, whose run-loop wait can miss an exit that comes as it begins and sleep forever.
final class ProcessHandle: @unchecked Sendable {
    private let lock = NSLock()
    let process: Process
    private let exit = DispatchSemaphore(value: 0)
    private var started = false
    private var ended = false
    private var exited = false
    private(set) var timedOut = false

    init(_ process: Process) {
        self.process = process
        process.terminationHandler = { [weak self] _ in self?.heardExit() }
    }

    /// Starts the process, unless it was ended first. Answers whether it started.
    @discardableResult
    func start() throws -> Bool {
        try lock.withLock {
            guard !ended else { return false }
            try process.run()
            started = true
            return true
        }
    }

    /// Ends the process: SIGTERM now, SIGKILL after `grace` seconds if it is still there; one that has not started
    /// never starts.
    func end(timedOut: Bool = false, grace: TimeInterval = 5) {
        let pid: Int32? = lock.withLock {
            ended = true
            if timedOut { self.timedOut = true }
            return started && !exited ? process.processIdentifier : nil
        }
        guard let pid else { return }
        kill(pid, SIGTERM)
        DispatchQueue.global().asyncAfter(deadline: .now() + grace) { [weak self] in
            guard let self, self.isRunning else { return }
            kill(pid, SIGKILL)
        }
    }

    /// Whether it started and has not exited.
    var isRunning: Bool { lock.withLock { started && !exited } }

    /// Whether it started at all.
    var didStart: Bool { lock.withLock { started } }

    /// Waits for it to exit, up to `seconds` (forever when nil); answers whether it did.
    @discardableResult
    func waitForExit(_ seconds: TimeInterval? = nil) -> Bool {
        guard didStart else { return true }
        let heard = seconds.map { exit.wait(timeout: .now() + $0) == .success } ?? { exit.wait(); return true }()
        if heard { exit.signal() }
        return heard
    }

    private func heardExit() {
        lock.withLock { exited = true }
        exit.signal()
    }
}
