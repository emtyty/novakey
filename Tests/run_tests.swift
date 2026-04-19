// NovaKey Test Runner
// Compile: swiftc -o /tmp/novakey_tests Sources/NovaKey/Engine/*.swift Tests/run_tests.swift -framework Carbon
// Run:     /tmp/novakey_tests

import Foundation

// ============================================================
// Minimal test harness
// ============================================================
var totalTests = 0
var passedTests = 0
var failedTests: [(String, String)] = []

func test(_ name: String, _ body: () throws -> Void) {
    totalTests += 1
    do {
        try body()
        passedTests += 1
        print("  PASS  \(name)")
    } catch {
        failedTests.append((name, "\(error)"))
        print("  FAIL  \(name) -- \(error)")
    }
}

struct AssertionError: Error, CustomStringConvertible {
    let description: String
}
func expect<T: Equatable>(_ actual: T, _ expected: T, file: String = #file, line: Int = #line) throws {
    if actual != expected {
        throw AssertionError(description: "Expected \(expected), got \(actual) at line \(line)")
    }
}
func expectNil<T>(_ value: T?, file: String = #file, line: Int = #line) throws {
    if value != nil {
        throw AssertionError(description: "Expected nil, got \(value!) at line \(line)")
    }
}
func expectTrue(_ value: Bool, file: String = #file, line: Int = #line) throws {
    if !value {
        throw AssertionError(description: "Expected true at line \(line)")
    }
}
func expectFalse(_ value: Bool, file: String = #file, line: Int = #line) throws {
    if value {
        throw AssertionError(description: "Expected false at line \(line)")
    }
}

// ============================================================
// Test helper: type into engine
// ============================================================
func keyCodeFor(_ char: Character) -> UInt16 {
    switch char {
    case "a": return KeyCode.a.rawValue
    case "b": return KeyCode.b.rawValue
    case "c": return KeyCode.c.rawValue
    case "d": return KeyCode.d.rawValue
    case "e": return KeyCode.e.rawValue
    case "f": return KeyCode.f.rawValue
    case "g": return KeyCode.g.rawValue
    case "h": return KeyCode.h.rawValue
    case "i": return KeyCode.i.rawValue
    case "j": return KeyCode.j.rawValue
    case "k": return KeyCode.k.rawValue
    case "l": return KeyCode.l.rawValue
    case "m": return KeyCode.m.rawValue
    case "n": return KeyCode.n.rawValue
    case "o": return KeyCode.o.rawValue
    case "p": return KeyCode.p.rawValue
    case "q": return KeyCode.q.rawValue
    case "r": return KeyCode.r.rawValue
    case "s": return KeyCode.s.rawValue
    case "t": return KeyCode.t.rawValue
    case "u": return KeyCode.u.rawValue
    case "v": return KeyCode.v.rawValue
    case "w": return KeyCode.w.rawValue
    case "x": return KeyCode.x.rawValue
    case "y": return KeyCode.y.rawValue
    case "z": return KeyCode.z.rawValue
    default: return 0xFF
    }
}

func typeAndGetText(_ chars: String) -> String {
    let engine = TelexEngine()
    engine.isVietnameseMode = true
    for char in chars {
        let lower = char.lowercased().first!
        let isShift = char.isUppercase
        let keyCode = keyCodeFor(lower)
        _ = engine.processKey(keyCode: keyCode, isShift: isShift)
    }
    return engine.buffer.text
}

func makeBuffer(_ text: String) -> SyllableBuffer {
    var buffer = SyllableBuffer()
    for char in text.lowercased() {
        buffer.append(ViChar(base: char))
    }
    return buffer
}

/// Type a sequence of letters, then press space, and return the engine
/// result for the space key and the composed text right before the break.
func typeThenSpace(_ chars: String) -> (space: EngineResult, composed: String) {
    let engine = TelexEngine()
    engine.isVietnameseMode = true
    for char in chars {
        let lower = char.lowercased().first!
        let isShift = char.isUppercase
        let keyCode = keyCodeFor(lower)
        _ = engine.processKey(keyCode: keyCode, isShift: isShift)
    }
    let composed = engine.buffer.text
    let result = engine.processKey(keyCode: KeyCode.space.rawValue)
    return (result, composed)
}

// ============================================================
// Main entry point
// ============================================================
@main
struct TestRunner {
    static func main() {
        runAllTests()
        printSummary()
    }
}

func runAllTests() {
// ============================================================
// SyllableBuffer Tests
// ============================================================
print("\n--- SyllableBuffer Tests ---")

test("empty buffer") {
    let buffer = SyllableBuffer()
    try expectTrue(buffer.isEmpty)
    try expect(buffer.count, 0)
    try expect(buffer.text, "")
}

test("append and text") {
    var buffer = SyllableBuffer()
    buffer.append(ViChar(base: "h"))
    buffer.append(ViChar(base: "a"))
    try expect(buffer.text, "ha")
    try expect(buffer.count, 2)
}

test("remove last") {
    var buffer = SyllableBuffer()
    buffer.append(ViChar(base: "a"))
    buffer.append(ViChar(base: "b"))
    let removed = buffer.removeLast()
    try expect(removed?.base, Optional("b"))
    try expect(buffer.text, "a")
}

test("reset") {
    var buffer = SyllableBuffer()
    buffer.append(ViChar(base: "t"))
    buffer.append(ViChar(base: "o"))
    buffer.applyTone(.sac, at: 1)
    buffer.reset()
    try expectTrue(buffer.isEmpty)
    try expect(buffer.currentTone, ToneMark.none)
    try expectNil(buffer.toneIndex)
}

test("vowel indices") {
    var buffer = SyllableBuffer()
    buffer.append(ViChar(base: "t"))
    buffer.append(ViChar(base: "o"))
    buffer.append(ViChar(base: "a"))
    buffer.append(ViChar(base: "n"))
    try expect(buffer.vowelIndices, [1, 2])
    try expect(buffer.vowelCount, 2)
    try expect(buffer.firstVowelIndex, Optional(1))
    try expect(buffer.lastVowelIndex, Optional(2))
}

test("ending consonant") {
    var buffer = SyllableBuffer()
    buffer.append(ViChar(base: "t"))
    buffer.append(ViChar(base: "o"))
    buffer.append(ViChar(base: "a"))
    try expectFalse(buffer.hasEndingConsonant)
    buffer.append(ViChar(base: "n"))
    try expectTrue(buffer.hasEndingConsonant)
    try expect(buffer.endingConsonant, "n")
}

test("apply tone") {
    var buffer = SyllableBuffer()
    buffer.append(ViChar(base: "a"))
    buffer.applyTone(.sac, at: 0)
    try expect(buffer.text, "\u{00E1}") // á
    try expect(buffer.currentTone, ToneMark.sac)
    try expect(buffer.toneIndex, Optional(0))
}

test("apply modifier circumflex") {
    var buffer = SyllableBuffer()
    buffer.append(ViChar(base: "a"))
    buffer.applyModifier(.circumflex, at: 0)
    try expect(buffer.text, "\u{00E2}") // â
}

test("apply tone + modifier") {
    var buffer = SyllableBuffer()
    buffer.append(ViChar(base: "a"))
    buffer.applyModifier(.circumflex, at: 0)
    buffer.applyTone(.sac, at: 0)
    try expect(buffer.text, "\u{1EA5}") // ấ
}

test("move tone") {
    var buffer = SyllableBuffer()
    buffer.append(ViChar(base: "t"))
    buffer.append(ViChar(base: "o"))
    buffer.append(ViChar(base: "a"))
    buffer.applyTone(.sac, at: 1)
    buffer.moveTone(to: 2)
    try expect(buffer.chars[1].tone, ToneMark.none)
    try expect(buffer.chars[2].tone, ToneMark.sac)
}

test("initial/vowel/ending consonant parsing") {
    var buffer = SyllableBuffer()
    buffer.append(ViChar(base: "t"))
    buffer.append(ViChar(base: "r"))
    buffer.append(ViChar(base: "o"))
    buffer.append(ViChar(base: "n"))
    buffer.append(ViChar(base: "g"))
    try expect(buffer.initialConsonant, "tr")
    try expect(buffer.vowelCluster, "o")
    try expect(buffer.endingConsonant, "ng")
}

// ============================================================
// TonePlacement Tests
// ============================================================
print("\n--- TonePlacement Tests ---")

test("single vowel 'ba'") {
    let buffer = makeBuffer("ba")
    try expect(TonePlacement.findTonePosition(in: buffer), Optional(1))
}

test("single vowel 'ti'") {
    let buffer = makeBuffer("ti")
    try expect(TonePlacement.findTonePosition(in: buffer), Optional(1))
}

test("two vowels + ending: 'toan'") {
    let buffer = makeBuffer("toan")
    try expect(TonePlacement.findTonePosition(in: buffer), Optional(2))
}

test("two vowels + ending: 'hoang'") {
    let buffer = makeBuffer("hoang")
    try expect(TonePlacement.findTonePosition(in: buffer), Optional(2))
}

test("two vowels no ending: 'hoa'") {
    let buffer = makeBuffer("hoa")
    try expect(TonePlacement.findTonePosition(in: buffer), Optional(2))
}

test("falling diphthong: 'hai'") {
    let buffer = makeBuffer("hai")
    try expect(TonePlacement.findTonePosition(in: buffer), Optional(1))
}

test("falling diphthong: 'cao'") {
    let buffer = makeBuffer("cao")
    try expect(TonePlacement.findTonePosition(in: buffer), Optional(1))
}

test("three vowels: 'khoai'") {
    let buffer = makeBuffer("khoai")
    try expect(TonePlacement.findTonePosition(in: buffer), Optional(3))
}

test("qu cluster: 'quan'") {
    let buffer = makeBuffer("quan")
    try expect(TonePlacement.findTonePosition(in: buffer), Optional(2))
}

test("no vowels: 'tr'") {
    let buffer = makeBuffer("tr")
    try expectNil(TonePlacement.findTonePosition(in: buffer))
}

// ============================================================
// TelexEngine Tests
// ============================================================
print("\n--- TelexEngine Tests ---")

test("tone: sắc (as -> á)") {
    try expect(typeAndGetText("as"), "\u{00E1}")
}

test("tone: huyền (af -> à)") {
    try expect(typeAndGetText("af"), "\u{00E0}")
}

test("tone: hỏi (ar -> ả)") {
    try expect(typeAndGetText("ar"), "\u{1EA3}")
}

test("tone: ngã (ax -> ã)") {
    try expect(typeAndGetText("ax"), "\u{00E3}")
}

test("tone: nặng (aj -> ạ)") {
    try expect(typeAndGetText("aj"), "\u{1EA1}")
}

test("remove tone: asz -> a") {
    try expect(typeAndGetText("asz"), "a")
}

test("circumflex: aa -> â") {
    try expect(typeAndGetText("aa"), "\u{00E2}")
}

test("circumflex: ee -> ê") {
    try expect(typeAndGetText("ee"), "\u{00EA}")
}

test("circumflex: oo -> ô") {
    try expect(typeAndGetText("oo"), "\u{00F4}")
}

test("breve: aw -> ă") {
    try expect(typeAndGetText("aw"), "\u{0103}")
}

test("horn: ow -> ơ") {
    try expect(typeAndGetText("ow"), "\u{01A1}")
}

test("horn: uw -> ư") {
    try expect(typeAndGetText("uw"), "\u{01B0}")
}

test("ww -> w (standalone reversal)") {
    // First 'w' on empty buffer -> 'ư'. Second 'w' should revert to literal 'w'.
    try expect(typeAndGetText("ww"), "w")
}

test("uww -> uw (undo via double w after uw)") {
    // After 'u' + 'w' -> 'ư', pressing 'w' again removes horn and appends 'w'.
    try expect(typeAndGetText("uww"), "uw")
}

test("d-stroke: dd -> đ") {
    try expect(typeAndGetText("dd"), "\u{0111}")
}

test("combined: Vieejt -> Việt") {
    try expect(typeAndGetText("Vieejt"), "Việt")
}

test("english mode: passthrough") {
    let engine = TelexEngine()
    engine.isVietnameseMode = false
    let result = engine.processKey(keyCode: KeyCode.a.rawValue)
    try expect(result, EngineResult.passThrough)
}

test("word break: space resets buffer") {
    let engine = TelexEngine()
    engine.isVietnameseMode = true
    _ = engine.processKey(keyCode: KeyCode.a.rawValue)
    _ = engine.processKey(keyCode: KeyCode.s.rawValue)
    let result = engine.processKey(keyCode: KeyCode.space.rawValue)
    try expect(result, EngineResult.wordBreak)
    try expectTrue(engine.buffer.isEmpty)
}

test("modifier key: Cmd resets buffer") {
    let engine = TelexEngine()
    engine.isVietnameseMode = true
    _ = engine.processKey(keyCode: KeyCode.a.rawValue)
    let result = engine.processKey(keyCode: KeyCode.c.rawValue, hasCommandOrControl: true)
    try expect(result, EngineResult.passThrough)
    try expectTrue(engine.buffer.isEmpty)
}

// ============================================================
// Tone re-check on late vowel append (feature #3)
// ============================================================
print("\n--- Tone Re-check on Vowel Append ---")

test("hosa -> hoá (tone moves to 2nd vowel when vowel is appended)") {
    try expect(typeAndGetText("hosa"), "ho\u{00E1}") // hoá
}

test("tosa -> toá") {
    try expect(typeAndGetText("tosa"), "to\u{00E1}") // toá
}

test("hofa -> hoà (huyen moves to 2nd vowel on vowel append)") {
    try expect(typeAndGetText("hofa"), "ho\u{00E0}") // hoà
}

// ============================================================
// Horn propagation for "uo" + w (feature #3)
// ============================================================
print("\n--- Horn Propagation for uo ---")

test("uow -> ươ (horn propagates to u)") {
    try expect(typeAndGetText("uow"), "\u{01B0}\u{01A1}") // ươ
}

test("thuowng -> thương") {
    try expect(typeAndGetText("thuowng"), "th\u{01B0}\u{01A1}ng") // thương
}

test("nuowcs -> nướcs? -> nước") {
    // n-u-o-w-c-s: uo+w->ươ, then c appended (ươc), then s tones ư -> ướ
    try expect(typeAndGetText("nuowcs"), "n\u{01B0}\u{1EDB}c") // nước
}

test("quow -> quơ (qu exception: no horn on u)") {
    // After "qu" the u is part of the consonant cluster, so horn should only
    // apply to the following o.
    try expect(typeAndGetText("quow"), "qu\u{01A1}") // quơ
}

// ============================================================
// Spelling check + restore on word-break (feature #2)
// ============================================================
print("\n--- Restore on Invalid Word-Break ---")

test("valid syllable 'as' + space -> no restore") {
    let (result, composed) = typeThenSpace("as")
    try expect(composed, "\u{00E1}") // á
    try expect(result, EngineResult.wordBreak)
}

test("valid 'viet' + space -> no restore (plain letters)") {
    let (result, _) = typeThenSpace("viet")
    try expect(result, EngineResult.wordBreak)
}

test("invalid 'wd' + space -> restore to raw 'wd'") {
    // 'w' alone -> ư. Then 'd' makes "ưd". 'd' is not a valid ending.
    // Buffer has horn transformation -> restore to raw "wd".
    let (result, composed) = typeThenSpace("wd")
    try expect(composed, "\u{01B0}d") // ưd
    try expect(result, EngineResult.restore(backspaces: 2, text: "wd"))
}

test("invalid 'aal' + space -> restore to 'aal'") {
    // "aa" -> â, then 'l' appended. "âl" has no valid ending (l).
    // Circumflex transformation present -> restore.
    let (result, composed) = typeThenSpace("aal")
    try expect(composed, "\u{00E2}l") // âl
    try expect(result, EngineResult.restore(backspaces: 2, text: "aal"))
}

test("plain English 'hello' + space -> no restore") {
    let (result, _) = typeThenSpace("hello")
    try expect(result, EngineResult.wordBreak)
}

test("case preserved on restore: 'AAL' -> 'AAL'") {
    let (result, _) = typeThenSpace("AAL")
    try expect(result, EngineResult.restore(backspaces: 2, text: "AAL"))
}

test("backspace disables restore for the rest of the word") {
    let engine = TelexEngine()
    engine.isVietnameseMode = true
    // Type "aa" (-> â), then backspace once (clears raw tracking),
    // then type "l" and space. No restore should fire now.
    for ch in "aa" {
        _ = engine.processKey(keyCode: keyCodeFor(ch), isShift: false)
    }
    _ = engine.processKey(keyCode: KeyCode.delete.rawValue)
    _ = engine.processKey(keyCode: keyCodeFor("l"), isShift: false)
    let result = engine.processKey(keyCode: KeyCode.space.rawValue)
    try expect(result, EngineResult.wordBreak)
}

test("word break resets buffer even after restore") {
    let engine = TelexEngine()
    engine.isVietnameseMode = true
    for ch in "wd" {
        _ = engine.processKey(keyCode: keyCodeFor(ch), isShift: false)
    }
    _ = engine.processKey(keyCode: KeyCode.space.rawValue)
    try expectTrue(engine.buffer.isEmpty)
}

} // end runAllTests()

func printSummary() {
    print("\n========================================")
    print("Results: \(passedTests)/\(totalTests) passed")
    if !failedTests.isEmpty {
        print("\nFailed tests:")
        for (name, reason) in failedTests {
            print("  - \(name): \(reason)")
        }
        print("========================================")
        exit(1)
    } else {
        print("All tests passed!")
        print("========================================")
        exit(0)
    }
}
