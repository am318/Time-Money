import SwiftUI
import UIKit
import XCTest

/// A small snapshot-testing helper, so no third-party package is needed.
///
/// Baselines live in `__Snapshots__` beside the tests. With no baseline present a test
/// is *skipped* (not failed) and the rendered image is attached to the result; run with
/// `SNAPSHOT_RECORD=1` in the test environment to write baselines into the source tree,
/// review them, and commit. Baselines depend on the simulator's OS and device, so record
/// them on the same simulator CI uses, and keep `tolerance` generous enough for
/// anti-aliasing differences.
@MainActor
enum Snapshot {
    static let tolerance = 0.01      // fraction of pixels allowed to differ
    static let channelSlack = 8      // per-channel difference ignored as noise

    static var isRecording: Bool {
        ProcessInfo.processInfo.environment["SNAPSHOT_RECORD"] == "1"
    }

    static func render<V: View>(_ view: V, size: CGSize, dynamicType: DynamicTypeSize,
                                scheme: ColorScheme) -> UIImage {
        let root = view
            .environment(\.dynamicTypeSize, dynamicType)
            .environment(\.colorScheme, scheme)
            .frame(width: size.width, height: size.height, alignment: .topLeading)
            .background(Color(scheme == .dark ? UIColor.black : UIColor.white))
        let host = UIHostingController(rootView: root)
        host.overrideUserInterfaceStyle = scheme == .dark ? .dark : .light
        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        window.rootViewController = host
        window.isHidden = false
        host.view.frame = window.bounds
        host.view.layoutIfNeeded()
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            host.view.drawHierarchy(in: host.view.bounds, afterScreenUpdates: true)
        }
    }

    /// Fraction of pixels that differ by more than the channel slack. 1 if sizes differ.
    static func difference(_ a: UIImage, _ b: UIImage) -> Double {
        guard let ca = a.cgImage, let cb = b.cgImage,
              ca.width == cb.width, ca.height == cb.height,
              let pa = pixels(ca), let pb = pixels(cb), pa.count == pb.count else { return 1 }
        var differing = 0
        for i in stride(from: 0, to: pa.count, by: 4) {
            for c in 0..<3 where abs(Int(pa[i + c]) - Int(pb[i + c])) > channelSlack {
                differing += 1
                break
            }
        }
        return Double(differing) / Double(pa.count / 4)
    }

    private static func pixels(_ image: CGImage) -> [UInt8]? {
        let w = image.width, h = image.height
        var data = [UInt8](repeating: 0, count: w * h * 4)
        guard let ctx = CGContext(data: &data, width: w, height: h, bitsPerComponent: 8,
                                  bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        return data
    }
}

extension XCTestCase {
    /// Renders `view` and compares it with the stored baseline called `name`.
    @MainActor
    func assertSnapshot<V: View>(_ view: V, named name: String,
                                 size: CGSize = CGSize(width: 390, height: 220),
                                 dynamicType: DynamicTypeSize = .large,
                                 scheme: ColorScheme = .light,
                                 file: StaticString = #filePath, line: UInt = #line) throws {
        let image = Snapshot.render(view, size: size, dynamicType: dynamicType, scheme: scheme)
        let directory = URL(fileURLWithPath: "\(file)").deletingLastPathComponent()
            .appendingPathComponent("__Snapshots__", isDirectory: true)
        let baseline = directory.appendingPathComponent("\(name).png")

        let attach = { (img: UIImage, label: String) in
            let a = XCTAttachment(image: img)
            a.name = label
            a.lifetime = .keepAlways
            self.add(a)
        }

        if Snapshot.isRecording {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try XCTUnwrap(image.pngData()).write(to: baseline)
            attach(image, "recorded \(name)")
            return
        }

        guard let data = try? Data(contentsOf: baseline), let expected = UIImage(data: data) else {
            attach(image, "no baseline for \(name)")
            throw XCTSkip("No baseline for \(name); record with SNAPSHOT_RECORD=1")
        }
        let diff = Snapshot.difference(image, expected)
        if diff > Snapshot.tolerance {
            attach(image, "actual \(name)")
            attach(expected, "expected \(name)")
            XCTFail("\(name) differs from its baseline by \(String(format: "%.2f", diff * 100))%",
                    file: file, line: line)
        }
    }
}
