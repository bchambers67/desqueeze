import Testing
import DesqueezeCore

@Suite("Desqueeze geometry")
struct GeometryTests {
    @Test("a 2× frame doubles in width and keeps its height")
    func widens() {
        let out = Squeeze(factor: 2.0).outputSize(for: PixelSize(width: 6000, height: 4000))
        #expect(out == PixelSize(width: 12000, height: 4000))
    }

    @Test("a 3:2 frame shot through 1.33× glass comes out at 1.995:1")
    func aspect() {
        let ratio = Squeeze(factor: 1.33).aspectRatio(for: PixelSize(width: 6000, height: 4000))
        #expect(abs(ratio - 1.995) < 0.0001)
    }

    @Test("a typed factor is read as a number", arguments: [("1.8", 1.8), ("2", 2.0), (" 1.55 ", 1.55)])
    func typed(text: String, expected: Double) {
        #expect(Squeeze(typed: text)?.factor == expected)
    }

    @Test("a comma decimal, as the keypad gives in much of Europe, is accepted")
    func commaDecimal() {
        #expect(Squeeze(typed: "1,5")?.factor == 1.5)
    }

    @Test("text that is not a number is rejected rather than guessed at", arguments: ["", "abc", "1.2.3", "-"])
    func rejects(text: String) {
        #expect(Squeeze(typed: text) == nil)
    }

    @Test("a typed factor outside what anamorphic glass does is pulled into range", arguments: [("9", 3.0), ("0.5", 1.0), ("-2", 1.0)])
    func clamps(text: String, expected: Double) {
        #expect(Squeeze(typed: text)?.factor == expected)
    }
}
