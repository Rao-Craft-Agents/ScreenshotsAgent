//  WHAT: Command lines run on this Mac, off the caller's thread: each a child process whose output is gathered as it
//        comes, or kept in a log file for a long build, and whose exit is heard, not waited on in a run loop.
//  PIN:  NEVER THE WIRE. A child's stdout and stderr go to a pipe or a log file, never inherited: the process's own
//        stdout is the host's wire.
//  PIN:  A CANCELLED CALL ENDS ITS CHILD. The task awaiting a command is the command's owner: cancelling it, or the
//        command running past its timeout, ends the child (SIGTERM, then SIGKILL).
//  PIN:  NO `waitUntilExit`. Its run-loop wait can miss an exit that lands as it begins and sleep forever (a capture
//        hung on one `screencapture` that had long exited); the exit is heard by `terminationHandler`, set before the
//        child starts.

import Foundation

struct SystemCommands: CommandRunning {
    func run(_ command: Command) async throws -> CommandOutput {
        try Task.checkCancellation()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = command.arguments
        if let directory = command.directory { process.currentDirectoryURL = directory }
        if !command.environment.isEmpty {
            process.environment = ProcessInfo.processInfo.environment.merging(command.environment) { $1 }
        }
        process.standardInput = FileHandle.nullDevice
        var log: FileHandle?
        var output: OutputCollector?
        var errors: OutputCollector?
        if let file = command.log {
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            FileManager.default.createFile(atPath: file.path, contents: nil)
            let handle = try FileHandle(forWritingTo: file)
            process.standardOutput = handle
            process.standardError = handle
            log = handle
        } else {
            let printed = Pipe(), said = Pipe()
            process.standardOutput = printed
            process.standardError = said
            output = OutputCollector(printed)
            errors = OutputCollector(said)
        }
        let handle = ProcessHandle(process)
        let logged = log, printed = output, said = errors
        let result: CommandOutput = try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CommandOutput, Error>) in
                do {
                    guard try handle.start() else {
                        try? logged?.close()
                        continuation.resume(returning: CommandOutput(status: 15, errors: "ended before it started"))
                        return
                    }
                } catch {
                    try? logged?.close()
                    continuation.resume(throwing: error)
                    return
                }
                if let timeout = command.timeout {
                    DispatchQueue.global().asyncAfter(deadline: .now() + timeout) { handle.end(timedOut: true) }
                }
                DispatchQueue.global().async {
                    handle.waitForExit()
                    // The pipes close with the child, unless a grandchild holds them: then what came is enough.
                    let text = printed?.data(waiting: 3) ?? Data()
                    let complaint = said?.data(waiting: 1) ?? Data()
                    try? logged?.close()
                    continuation.resume(returning: CommandOutput(status: process.terminationStatus, output: text,
                                                                 errors: String(decoding: complaint, as: UTF8.self), timedOut: handle.timedOut))
                }
            }
        } onCancel: {
            handle.end()
        }
        try Task.checkCancellation()
        return result
    }
}
