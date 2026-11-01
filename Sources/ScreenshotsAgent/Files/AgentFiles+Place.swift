//  WHAT: Files a call made itself in a staging folder of its own (images, a contact sheet, a README), moved into the
//        project together, as `write` moves the text it staged.
//  PIN:  EVERY FOLDER FIRST. The folders are made before any file moves, so a call that cannot write one fails before
//        anything lands.

import Foundation

extension AgentFiles {
    /// Moves each staged file to its place (absolute), replacing what is there; answers the paths, in the order given.
    func place(_ files: [(from: URL, to: URL)]) throws -> [String] {
        let manager = FileManager.default
        for pair in files {
            let folder = pair.to.deletingLastPathComponent()
            do { try manager.createDirectory(at: folder, withIntermediateDirectories: true) } catch { throw AgentFilesError.unwritable(folder.path) }
        }
        var written: [String] = []
        for pair in files {
            do {
                if manager.fileExists(atPath: pair.to.path) { try manager.removeItem(at: pair.to) }
                try manager.moveItem(at: pair.from, to: pair.to)
            } catch {
                throw AgentFilesError.unwritable(pair.to.path)
            }
            written.append(pair.to.path)
        }
        return written
    }
}
