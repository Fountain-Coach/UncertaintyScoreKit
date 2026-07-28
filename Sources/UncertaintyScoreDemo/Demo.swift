import SwiftUI
import AppKit
import UncertaintyScoreKit
import UncertaintyScoreKitUI

// Snapshot harness — renders the fixture scores to PNG in light and dark, the way `ScoreKitSnap` does for notation.
// This is how the encoding gets LOOKED AT (pixel verification) rather than asserted. Pass an output directory as the
// first argument; defaults to the current directory.

@main
struct UncertaintyScoreDemo {
    @MainActor
    static func main() {
        let outDir = CommandLine.arguments.count > 1
            ? URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
            : URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

        let scores: [(String, UncertaintyScore)] = [
            ("telemachus", Fixtures.telemachus),
            ("log-triage", Fixtures.logTriage),
            ("braided-chapter", Fixtures.braidedChapter)
        ]
        for (name, score) in scores {
            for (label, scheme) in [("light", ColorScheme.light), ("dark", ColorScheme.dark)] {
                let url = outDir.appendingPathComponent("uncertainty-\(name)-\(label).png")
                render(UncertaintyScoreView(score: score), scheme: scheme, to: url)
                FileHandle.standardError.write(Data("wrote \(url.path)\n".utf8))
            }
        }
    }

    @MainActor
    static func render(_ view: some View, scheme: ColorScheme, to url: URL) {
        let renderer = ImageRenderer(content:
            view
                .environment(\.colorScheme, scheme)
                .frame(width: 1120)
                .fixedSize(horizontal: false, vertical: true)
        )
        renderer.scale = 2
        guard let cg = renderer.cgImage else {
            FileHandle.standardError.write(Data("FAILED to render \(url.lastPathComponent)\n".utf8))
            return
        }
        let rep = NSBitmapImageRep(cgImage: cg)
        guard let png = rep.representation(using: .png, properties: [:]) else { return }
        try? png.write(to: url)
    }
}
