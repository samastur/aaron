import AaronCore
import AppKit

/// Aaron ▸ Install Command Line Tool…
@MainActor
enum CommandLineToolInstall {
    static func run() async {
        let alert = NSAlert()
        guard let script = Bundle.main.url(forResource: "aaron", withExtension: nil) else {
            alert.messageText = "The aaron command is missing from this copy of Aaron."
            alert.runModal()
            return
        }
        let bin = CommandLineInstaller.userBinDirectory
        do {
            let link = try CommandLineInstaller.install(script: script, into: bin)
            // The PATH of a login shell, as the user's Terminal sees it.
            let path = (try? await ProcessRunner().run("print -r -- $PATH", timeout: .seconds(10)).stdout) ?? ""
            alert.messageText = "The aaron command is installed"
            var text = "\(link.path) now opens files in this copy of Aaron (\(Bundle.main.bundleURL.path))."
            if CommandLineInstaller.directory(bin, isIn: path) {
                text += "\n\nTry it in a new Terminal window: aaron --help"
            } else {
                text += "\n\n\(bin.path) is not on your PATH yet. Add this line to ~/.zprofile, "
                    + "then open a new Terminal window:\n\nexport PATH=\"$HOME/.local/bin:$PATH\""
            }
            alert.informativeText = text
        } catch {
            alert.alertStyle = .warning
            alert.messageText = "The aaron command was not installed"
            alert.informativeText = error.localizedDescription
        }
        alert.runModal()
    }
}
