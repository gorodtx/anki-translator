// Copies an optical PNG from the Penpot Mono icon system.
//
//   swift scripts/make_icon.swift OUT.png [size]     (size defaults to 1024)
//
// scripts/make_icon.sh packs the curated 1x/2x icon set directly. Rebuild the PNG
// sources with design/translator-icon/build-kit.mjs after exporting from Penpot.
import Foundation

let arguments = CommandLine.arguments
let pixels = arguments.count >= 3 ? Int(arguments[2]) : 1024
guard arguments.count >= 2,
      let size = pixels,
      [16, 32, 64, 128, 256, 512, 1024, 2048].contains(size)
else {
    FileHandle.standardError.write(Data("usage: make_icon.swift OUT.png [16|32|64|128|256|512|1024|2048]\n".utf8))
    exit(2)
}
let repository = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
let relative = size == 2048
    ? "design/translator-icon/master/app-icon-master.png"
    : "design/translator-icon/macOS/png/light/\(size).png"
let source = repository.appendingPathComponent(relative)
let output = URL(fileURLWithPath: arguments[1])
do {
    let data = try Data(contentsOf: source)
    try data.write(to: output, options: .atomic)
} catch {
    FileHandle.standardError.write(Data("could not copy the optical icon: \(error)\n".utf8))
    exit(1)
}
