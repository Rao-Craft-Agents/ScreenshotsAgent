import Foundation

/// What a pipe carried, gathered as it comes (`readabilityHandler`), so nothing blocks on it: a grandchild that keeps
/// the pipe open past the command's exit costs a short wait, never a hang.
final class OutputCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var bytes = Data()
    private let closed = DispatchSemaphore(value: 0)

    /// Starts gathering what `pipe` carries.
    init(_ pipe: Pipe) {
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let chunk = handle.availableData
            if chunk.isEmpty {
                handle.readabilityHandler = nil
                self?.closed.signal()
            } else {
                self?.lock.withLock { self?.bytes.append(chunk) }
            }
        }
    }

    /// Everything gathered, once the pipe closes or `seconds` pass.
    func data(waiting seconds: TimeInterval) -> Data {
        _ = closed.wait(timeout: .now() + seconds)
        return lock.withLock { bytes }
    }
}
