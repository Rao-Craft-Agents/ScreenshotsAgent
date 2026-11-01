import Foundation

/// The family's agents as Craft calls them: an installed runner from `~/.rao/apps/craft/agents`, started in the
/// app's folder, given one `perform` line, read until its `output` or `failed`.
enum Runner {
    /// The runner of `agent` (`GraniteAgent`), or nil when it is not installed.
    static func executable(_ agent: String) -> URL? {
        let url = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".rao/apps/craft/agents/\(agent)/agent")
        return FileManager.default.isExecutableFile(atPath: url.path) ? url : nil
    }

    enum Failure: Error, CustomStringConvertible {
        case missing(String)
        case failed(String, String)
        var description: String {
            switch self {
            case .missing(let agent): return "\(agent) is not installed"
            case .failed(let word, let said): return "\(word) failed: \(said)"
            }
        }
    }

    /// One call, its output's JSON object. Throws the runner's `failed` sentence.
    @discardableResult
    static func call(_ agent: String, word: String, input: [String: Any], in folder: URL) throws -> [String: Any] {
        guard let executable = executable(agent) else { throw Failure.missing(agent) }
        let perform: [String: Any] = ["perform": ["word": word, "directory": folder.path, "ask": "make the fixture app", "model": false, "input": input]]
        var line = try JSONSerialization.data(withJSONObject: perform)
        line.append(0x0A)
        let process = Process()
        process.executableURL = executable
        process.currentDirectoryURL = folder
        let input = Pipe(), output = Pipe()
        process.standardInput = input
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        try process.run()
        input.fileHandleForWriting.write(line)
        try input.fileHandleForWriting.close()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        for text in String(decoding: data, as: UTF8.self).split(separator: "\n") {
            guard let message = try? JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any] else { continue }
            if let answer = message["output"] as? [String: Any] { return answer }
            if let failed = message["failed"] { throw Failure.failed(word, "\(failed)") }
        }
        throw Failure.failed(word, "no answer (exit \(process.terminationStatus))")
    }
}
