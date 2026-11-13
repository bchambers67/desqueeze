import Foundation
import Testing
import DesqueezeCore

@Suite("Picture signals")
struct PictureSignalsTests {

    /// Texture with no preferred direction, squeezed sideways by `squeeze`:
    /// a sum of waves heading every way, sampled closer together across.
    func texture(squeeze: Double, width: Int = 384, height: Int = 384) -> [UInt8] {
        var seed: UInt64 = 0x9E3779B97F4A7C15
        func random() -> Double {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return Double(seed >> 11) / Double(1 << 53)
        }
        let waves = (0..<48).map { _ -> (fx: Double, fy: Double, phase: Double) in
            let angle = random() * 2 * .pi, frequency = 0.02 + random() * 0.03
            return (cos(angle) * frequency, sin(angle) * frequency, random() * 2 * .pi)
        }
        var pixels = [UInt8](repeating: 0, count: width * height)
        for y in 0..<height {
            for x in 0..<width {
                let u = Double(x) * squeeze, v = Double(y)
                let sum = waves.reduce(0.0) { $0 + cos(2 * .pi * ($1.fx * u + $1.fy * v) + $1.phase) }
                pixels[y * width + x] = UInt8(max(0, min(255, 128 + sum * 12)))
            }
        }
        return pixels
    }

    @Test("even texture reads as unsqueezed")
    func detailOrdinary() throws {
        let factor = try #require(PictureSignals.detailFactor(pixels: texture(squeeze: 1), width: 384, height: 384))
        #expect(abs(factor - 1) < 0.15)
    }

    @Test("texture squeezed sideways reads as about that squeeze", arguments: [1.33, 1.5, 2.0])
    func detailSqueezed(squeeze: Double) throws {
        let factor = try #require(PictureSignals.detailFactor(pixels: texture(squeeze: squeeze), width: 384, height: 384))
        #expect(abs(factor - squeeze) / squeeze < 0.15)
    }

    @Test("a flat frame gives no reading")
    func detailFlat() {
        #expect(PictureSignals.detailFactor(pixels: [UInt8](repeating: 120, count: 256 * 256), width: 256, height: 256) == nil)
    }

    @Test("letters at their usual width read as unsqueezed, and narrow ones as squeezed")
    func text() throws {
        // Ten characters, each 0.55 of the line height wide.
        let ordinary = [PictureSignals.TextLine(characters: 10, width: 220, height: 40),
                        PictureSignals.TextLine(characters: 6, width: 99, height: 30)]
        #expect(abs(try #require(PictureSignals.textFactor(lines: ordinary)) - 1) < 0.01)

        let narrow = ordinary.map { PictureSignals.TextLine(characters: $0.characters, width: $0.width / 1.5, height: $0.height) }
        #expect(abs(try #require(PictureSignals.textFactor(lines: narrow)) - 1.5) < 0.01)
    }

    @Test("one line, short words and sideways text give no reading")
    func textTooLittle() {
        #expect(PictureSignals.textFactor(lines: [.init(characters: 10, width: 220, height: 40)]) == nil)
        #expect(PictureSignals.textFactor(lines: [.init(characters: 2, width: 44, height: 40),
                                                  .init(characters: 3, width: 66, height: 40)]) == nil)
        #expect(PictureSignals.textFactor(lines: [.init(characters: 10, width: 30, height: 200),
                                                  .init(characters: 8, width: 30, height: 160)]) == nil)
    }

    @Test("bodies are read from the widest person, who is the one facing the camera")
    func body() throws {
        // Facing forward at 1.5x: shoulders 0.72 / 1.5 of the torso. The other is turned away.
        let people = [PictureSignals.Body(shoulderWidth: 48, torsoLength: 100),
                      PictureSignals.Body(shoulderWidth: 20, torsoLength: 100)]
        #expect(abs(try #require(PictureSignals.bodyFactor(people: people)) - 1.5) < 0.01)
        #expect(PictureSignals.bodyFactor(people: []) == nil)
    }

    @Test("a photo takes the factor of the nearest corrected one from its session")
    func session() {
        let size = PixelSize(width: 6000, height: 4000)
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let corrections = [PictureSignals.Correction(taken: start, size: size, factor: 1.33),
                           PictureSignals.Correction(taken: start.addingTimeInterval(400), size: size, factor: 1.6)]

        #expect(PictureSignals.sessionFactor(taken: start.addingTimeInterval(60), size: size, corrections: corrections) == 1.33)
        #expect(PictureSignals.sessionFactor(taken: start.addingTimeInterval(350), size: size, corrections: corrections) == 1.6)
        // An hour later, or from a different camera, it is not the same session.
        #expect(PictureSignals.sessionFactor(taken: start.addingTimeInterval(4000), size: size, corrections: corrections) == nil)
        #expect(PictureSignals.sessionFactor(taken: start, size: PixelSize(width: 4032, height: 3024), corrections: corrections) == nil)
    }
}
