//  WHAT: The Xcode project in the host's folder, as xcodebuild is pointed at it: the workspace or project file, its
//        schemes (shared, then the person's own), the scheme that builds the iOS app and the one for the Mac.
//  PIN:  A SCHEME, ALWAYS. An app that uses Swift packages, as every Granite app does, builds only by a scheme, so a
//        project with no scheme to name is refused rather than built bare.

import Foundation

struct AppProject: Sendable, Equatable {
    /// The `.xcworkspace` or `.xcodeproj` xcodebuild is pointed at.
    var container: URL
    /// The app's name: the project file's, less its extension.
    var name: String
    /// Every scheme found, by name, with its file.
    var schemes: [String: URL]

    /// Whether `container` is a workspace.
    var isWorkspace: Bool { container.pathExtension == "xcworkspace" }

    /// `-workspace <path>` or `-project <path>`.
    var xcodebuildTarget: [String] { [isWorkspace ? "-workspace" : "-project", container.path] }

    /// The project at the top of `root`: a workspace beside the project wins, as Xcode opens it. Throws the reason
    /// when there is none, or when several leave it unclear.
    static func find(in root: URL) throws -> AppProject {
        let manager = FileManager.default
        guard let names = try? manager.contentsOfDirectory(atPath: root.path) else {
            throw ScreenshotsError.refused(["the folder \(root.path) cannot be read"])
        }
        let projects = names.filter { $0.hasSuffix(".xcodeproj") }.sorted()
        let workspaces = names.filter { $0.hasSuffix(".xcworkspace") }.sorted()
        guard !projects.isEmpty || !workspaces.isEmpty else {
            throw ScreenshotsError.refused(["\(root.path) has no Xcode project: screenshots builds and launches an app's .xcodeproj (`$granite` makes one)"])
        }
        let chosen: String
        if workspaces.count == 1 {
            chosen = workspaces[0]
        } else if workspaces.isEmpty, projects.count == 1 {
            chosen = projects[0]
        } else {
            throw ScreenshotsError.refused(["\(root.path) has several Xcode projects (\((workspaces + projects).joined(separator: ", "))): call screenshots in the folder of the one to capture"])
        }
        let container = root.appendingPathComponent(chosen, isDirectory: true)
        var schemes: [String: URL] = [:]
        // The workspace's and every project's shared schemes, then the person's own: a shared one wins a name.
        let holders = [container] + projects.map { root.appendingPathComponent($0, isDirectory: true) }
        for holder in holders {
            for (name, url) in schemeFiles(in: holder.appendingPathComponent("xcshareddata/xcschemes")) where schemes[name] == nil {
                schemes[name] = url
            }
        }
        for holder in holders {
            let users = holder.appendingPathComponent("xcuserdata")
            for user in (try? manager.contentsOfDirectory(atPath: users.path)) ?? [] {
                for (name, url) in schemeFiles(in: users.appendingPathComponent(user).appendingPathComponent("xcschemes")) where schemes[name] == nil {
                    schemes[name] = url
                }
            }
        }
        let name = (chosen as NSString).deletingPathExtension
        return AppProject(container: container, name: name, schemes: schemes)
    }

    /// The scheme that builds the iOS app: the one asked for, else `<App>-iOS`, else the one scheme the project has.
    func iOSScheme(_ asked: String?) throws -> String {
        let listed = schemes.keys.sorted()
        if let asked = asked?.trimmingCharacters(in: .whitespaces), !asked.isEmpty {
            guard schemes[asked] != nil || schemes.isEmpty else {
                throw ScreenshotsError.refused(["the project has no scheme `\(asked)`: its schemes are \(listed.map { "`\($0)`" }.joined(separator: ", "))"])
            }
            return asked
        }
        if schemes["\(name)-iOS"] != nil { return "\(name)-iOS" }
        let iOS = listed.filter { $0.hasSuffix("-iOS") }
        if iOS.count == 1 { return iOS[0] }
        if listed.count == 1 { return listed[0] }
        if schemes[name] != nil { return name }
        if listed.isEmpty {
            throw ScreenshotsError.refused(["\(container.lastPathComponent) shares no scheme: name the scheme that builds the iOS app with `scheme`"])
        }
        throw ScreenshotsError.refused(["name the scheme that builds the iOS app with `scheme`: the project has \(listed.map { "`\($0)`" }.joined(separator: ", "))"])
    }

    /// The scheme that builds the Mac app: `<Stem>-macOS` beside an `<Stem>-iOS` scheme, else `<App>-macOS`, else the
    /// iOS scheme itself when it is the project's only one (a multiplatform scheme); nil when there is none.
    func macScheme(besides iOS: String) -> String? {
        if iOS.hasSuffix("-iOS") {
            let stem = String(iOS.dropLast(4))
            if schemes["\(stem)-macOS"] != nil { return "\(stem)-macOS" }
        }
        if schemes["\(name)-macOS"] != nil { return "\(name)-macOS" }
        let mac = schemes.keys.filter { $0.hasSuffix("-macOS") }.sorted()
        if mac.count == 1 { return mac[0] }
        if !iOS.hasSuffix("-iOS"), schemes.count <= 1 { return iOS }
        return nil
    }

    /// What `scheme` launches and builds, read off its file.
    func scheme(_ scheme: String) -> SchemeFile? {
        schemes[scheme].flatMap(SchemeFile.read(at:))
    }

    private static func schemeFiles(in folder: URL) -> [(String, URL)] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        return names.filter { $0.hasSuffix(".xcscheme") }.sorted().map { (String($0.dropLast(9)), folder.appendingPathComponent($0)) }
    }
}
