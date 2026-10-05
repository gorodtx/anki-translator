import Foundation

// The app launches this signed Mach-O as its owned backend process. Replace the
// launcher with the bundled engine so its PID and TRANSLATOR_PARENT_PID remain
// intact; BackendBootstrap and the daemon parent watcher own its lifecycle.

let executable = (Bundle.main.executableURL ?? URL(fileURLWithPath: CommandLine.arguments[0]))
    .resolvingSymlinksInPath()
let resources = executable
    .deletingLastPathComponent()  // Contents/MacOS
    .deletingLastPathComponent()  // Contents
    .appendingPathComponent("Resources")

func die(_ message: String, _ code: Int32) -> Never {
    FileHandle.standardError.write(Data("translator-backend: \(message)\n".utf8))
    // BackendBootstrap observes an unsuccessful launch and reports/retries it.
    exit(code)
}

// Executed through a link named after the app: Activity Monitor names a process after
// the file that was executed, and "python3.13" tells the user nothing about whose process
// it is or why it never stops. The link points at the same interpreter.
let python = resources.appendingPathComponent("bin/TranslatorEngine")
guard FileManager.default.isExecutableFile(atPath: python.path) else {
    die("no engine at \(python.path); the bundle is incomplete", 66)
}

setenv("PYTHONPATH", "\(resources.path)/app:\(resources.path)/site-packages", 1)
setenv("PYTHONDONTWRITEBYTECODE", "1", 1)
setenv("PYTHONUNBUFFERED", "1", 1)
setenv("TRANSLATOR_APPLE_HELPER", resources.appendingPathComponent("bin/TranslatorLookup").path, 1)

var argv: [UnsafeMutablePointer<CChar>?] = [
    // -P prevents the current directory from overriding modules shipped in the app.
    // Preserve our explicit PYTHONPATH: -I would ignore the bundle's module roots.
    strdup(python.path), strdup("-P"), strdup("-m"), strdup("desktop_app.platform.macos.daemon"),
]
argv += CommandLine.arguments.dropFirst().map { strdup($0) }
argv.append(nil)
execv(python.path, &argv)
die("could not start python: \(String(cString: strerror(errno)))", 71)
