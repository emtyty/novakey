// TelexEngine.swift
// Core Telex input processing engine.
// Pure Swift, no UI or system dependencies -- fully testable.

import Foundation

// MARK: - Engine Result

/// The result of processing a single keystroke through the engine.
enum EngineResult: Equatable {
    /// Let the original key event pass through unchanged.
    case passThrough

    /// Suppress the original key event and send replacement characters.
    /// `backspaces`: how many backspace events to send first.
    /// `text`: the replacement Unicode string to send after backspaces.
    case replace(backspaces: Int, text: String)

    /// The key is a word break -- reset the session and let it through.
    case wordBreak

    /// Emit a replacement (backspace + raw text) THEN let the original key
    /// event pass through. Used when the accumulated syllable is invalid
    /// at word-break time and must be restored to the raw keystrokes.
    case restore(backspaces: Int, text: String)
}

// MARK: - Telex Engine

/// Processes keystrokes according to the Telex input method.
/// Maintains a syllable buffer and produces engine results that tell the
/// event tap what to do (pass through, replace, or reset).
final class TelexEngine {

    // MARK: - State

    /// The current syllable being composed.
    private(set) var buffer = SyllableBuffer()

    /// Whether Vietnamese mode is active.
    var isVietnameseMode: Bool = true

    /// The last raw key that was typed (for double-press detection).
    private var lastRawKey: Character? = nil

    /// Raw letter keystrokes typed in the current session, with original case.
    /// Used to restore the original keys if the syllable fails spelling check
    /// at word-break. Cleared on reset and on backspace (since backspace makes
    /// exact restoration impossible).
    private var rawKeystrokes: String = ""

    // MARK: - Main Entry Point

    /// Process a single keystroke.
    ///
    /// - Parameters:
    ///   - keyCode: The macOS virtual keycode.
    ///   - isShift: Whether Shift is held.
    ///   - hasCommandOrControl: Whether Cmd or Ctrl is held.
    ///   - hasOption: Whether Option is held.
    /// - Returns: An `EngineResult` telling the event tap what to do.
    func processKey(
        keyCode: UInt16,
        isShift: Bool = false,
        hasCommandOrControl: Bool = false,
        hasOption: Bool = false
    ) -> EngineResult {
        guard let key = KeyCode(rawValue: keyCode) else {
            return .passThrough
        }

        // Modifier combos (Cmd+C, Ctrl+A, etc.) always pass through and reset
        if hasCommandOrControl {
            resetSession()
            return .passThrough
        }

        // Option key combos pass through and reset
        if hasOption {
            resetSession()
            return .passThrough
        }

        // Word break keys: check for invalid syllable and restore if needed
        if key.isWordBreak {
            if let restore = restoreIfInvalid() {
                resetSession()
                return restore
            }
            resetSession()
            return .wordBreak
        }

        // Backspace: remove last character from buffer
        if key == .delete {
            return handleBackspace()
        }

        // Vietnamese mode off: just track nothing
        if !isVietnameseMode {
            return .passThrough
        }

        // Get the ASCII character for this key
        guard let ascii = key.asciiLetter else {
            // Non-letter key that isn't a word break -- reset and pass through
            resetSession()
            return .passThrough
        }

        let char = isShift ? Character(ascii.uppercased()) : ascii

        // Record the raw keystroke (with original case) for potential
        // restoration on word-break if the syllable is invalid.
        rawKeystrokes.append(char)

        return processLetter(char, isUpperCase: isShift)
    }

    /// Reset the syllable buffer and start fresh.
    func resetSession() {
        buffer.reset()
        lastRawKey = nil
        rawKeystrokes = ""
    }

    // MARK: - Letter Processing

    private func processLetter(_ char: Character, isUpperCase: Bool) -> EngineResult {
        let lower = char.lowercased().first!

        // Check if this is a Telex tone key (s, f, r, x, j, z)
        if let tone = VietnameseData.telexToneKeys[lower], buffer.vowelCount > 0 {
            let result = handleToneKey(lower, tone: tone, isUpperCase: isUpperCase)
            if result != nil {
                lastRawKey = lower
                return result!
            }
        }

        // Check if this is a d-stroke trigger (dd -> đ)
        if lower == "d" {
            let result = handleDKey(isUpperCase: isUpperCase)
            lastRawKey = lower
            return result
        }

        // Check if this is a vowel modifier trigger (aa, ee, oo, aw, ow, uw, w)
        if lower == "w" || isDoubleKeyTrigger(lower) {
            if let result = handleVowelModifier(lower, isUpperCase: isUpperCase) {
                lastRawKey = lower
                return result
            }
        }

        // Regular letter -- add to buffer
        let viChar = ViChar(base: lower, isUpperCase: isUpperCase)
        buffer.append(viChar)

        // After adding any letter, re-check tone placement. This matters
        // for vowel appends too -- e.g. "hos" -> "hó", then typing "a"
        // should produce "hoá" (tone moves to the second vowel), not "hóa".
        if buffer.currentTone != .none {
            if let moved = recheckTonePlacement() {
                lastRawKey = lower
                return moved
            }
        }

        lastRawKey = lower
        return .passThrough
    }

    // MARK: - Tone Handling

    /// Handle a tone key press (s, f, r, x, j, z).
    /// Returns nil if the tone cannot be applied (treat as regular letter).
    private func handleToneKey(_ key: Character, tone: ToneMark, isUpperCase: Bool) -> EngineResult? {
        // z key: remove existing tone
        if tone == .none {
            return handleRemoveTone(key, isUpperCase: isUpperCase)
        }

        // If same tone is already applied, undo it (double-press reversal)
        if buffer.currentTone == tone {
            return undoTone(key, isUpperCase: isUpperCase)
        }

        // Find the correct position for the tone mark
        guard let position = TonePlacement.findTonePosition(in: buffer) else {
            return nil
        }

        // Capture old state for backspace calculation
        let oldText = buffer.text

        // Apply the tone
        buffer.applyTone(tone, at: position)

        let newText = buffer.text
        return buildReplacement(oldText: oldText, newText: newText)
    }

    /// Handle z key: remove existing tone mark.
    private func handleRemoveTone(_ key: Character, isUpperCase: Bool) -> EngineResult? {
        guard buffer.currentTone != .none else {
            // No tone to remove -- treat as regular letter
            return nil
        }

        let oldText = buffer.text
        buffer.applyTone(.none, at: 0) // index doesn't matter for .none
        let newText = buffer.text
        return buildReplacement(oldText: oldText, newText: newText)
    }

    /// Undo a tone mark when the same tone key is pressed again.
    /// e.g., "as" -> "á", then "ass" -> "as"
    private func undoTone(_ key: Character, isUpperCase: Bool) -> EngineResult {
        let oldText = buffer.text

        // Remove the tone
        buffer.applyTone(.none, at: 0)

        // Add the key as a literal character
        let viChar = ViChar(base: key, isUpperCase: isUpperCase)
        buffer.append(viChar)

        let newText = buffer.text
        return buildReplacement(oldText: oldText, newText: newText)
    }

    // MARK: - D-Stroke Handling

    /// Handle the 'd' key. If the last character in the buffer is also 'd',
    /// convert to đ. Otherwise, add as regular 'd'.
    private func handleDKey(isUpperCase: Bool) -> EngineResult {
        // Check if previous character is 'd' without stroke
        if let lastIdx = buffer.lastIndex(ofBase: "d"), !buffer.hasDStroke {
            // Double d -> đ
            let oldText = buffer.text
            buffer.applyDStroke(at: lastIdx)
            let newText = buffer.text

            // The second 'd' is consumed; we replace the first 'd' with 'đ'
            return buildReplacement(oldText: oldText, newText: newText)
        }

        // If already has đ and typing another d -> undo (đd -> dd)
        if buffer.hasDStroke, lastRawKey == "d" {
            let oldText = buffer.text
            buffer.removeDStroke()
            let viChar = ViChar(base: "d", isUpperCase: isUpperCase)
            buffer.append(viChar)
            let newText = buffer.text
            return buildReplacement(oldText: oldText, newText: newText)
        }

        // Regular d
        let viChar = ViChar(base: "d", isUpperCase: isUpperCase)
        buffer.append(viChar)
        return .passThrough
    }

    // MARK: - Vowel Modifier Handling

    /// Check if typing this character triggers a double-key modifier.
    /// (a after a -> â, e after e -> ê, o after o -> ô)
    private func isDoubleKeyTrigger(_ char: Character) -> Bool {
        guard let last = lastRawKey else { return false }
        return last == char && (char == "a" || char == "e" || char == "o")
    }

    /// Handle vowel modifier keys (aa->â, ee->ê, oo->ô, aw->ă, ow->ơ, uw->ư, w standalone).
    /// Returns nil if no modification can be applied.
    private func handleVowelModifier(_ key: Character, isUpperCase: Bool) -> EngineResult? {
        // "ww" -> literal "w": the first 'w' on an empty buffer becomes 'ư'
        // (standalone rule); pressing 'w' again in that state should revert
        // to literal 'w', not 'uw'. Guarded by rawKeystrokes == "ww" to
        // distinguish the standalone path from the 'u' + 'w' + 'w' path.
        if key == "w"
            && buffer.count == 1
            && buffer.chars[0].base == "u"
            && buffer.chars[0].modifier == .horn
            && rawKeystrokes.lowercased() == "ww" {
            let oldText = buffer.text
            buffer.reset()
            buffer.append(ViChar(base: "w", isUpperCase: isUpperCase))
            let newText = buffer.text
            return buildReplacement(oldText: oldText, newText: newText)
        }

        // Try each modifier rule
        for rule in VietnameseData.telexVowelModifiers {
            if rule.trigger == key {
                // Find the target vowel in the buffer
                if let targetIdx = buffer.lastIndex(ofBase: rule.target) {
                    let currentMod = buffer.chars[targetIdx].modifier

                    // If already has this modifier -> undo (double press reversal)
                    if currentMod == rule.modifier {
                        return undoVowelModifier(key, targetIndex: targetIdx, isUpperCase: isUpperCase)
                    }

                    // If no modifier yet -> apply
                    if currentMod == .none {
                        let oldText = buffer.text
                        buffer.applyModifier(rule.modifier, at: targetIdx)
                        // "uo" + w -> "ươ": when horn is applied to an 'o'
                        // immediately preceded by an unmodified 'u', propagate
                        // horn to the 'u' as well. Exception: "qu" + 'o' + w
                        // should only horn the 'o' (giving quơ, not qươ) since
                        // the 'u' there is part of the consonant cluster.
                        if rule.modifier == .horn && rule.target == "o" && targetIdx > 0 {
                            let prev = buffer.chars[targetIdx - 1]
                            let precededByQ = targetIdx >= 2
                                && buffer.chars[targetIdx - 2].base == "q"
                            if prev.base == "u" && prev.modifier == .none && !precededByQ {
                                buffer.applyModifier(.horn, at: targetIdx - 1)
                            }
                        }
                        let newText = buffer.text
                        return buildReplacement(oldText: oldText, newText: newText)
                    }
                }
            }
        }

        // Standalone 'w' -> 'ư' when there's no target vowel to modify
        if key == "w" && buffer.isEmpty {
            let viChar = ViChar(base: "u", modifier: .horn, isUpperCase: isUpperCase)
            buffer.append(viChar)
            // Replace the 'w' keystroke with 'ư'
            return .replace(backspaces: 0, text: String(viChar.unicode))
        }

        return nil
    }

    /// Undo a vowel modifier when the same trigger is pressed again.
    /// e.g., "aa" -> "â", then "aaa" -> "aa"
    private func undoVowelModifier(_ key: Character, targetIndex: Int, isUpperCase: Bool) -> EngineResult {
        let oldText = buffer.text

        // Remove the modifier
        buffer.removeModifier(at: targetIndex)

        // Add the key as a literal character
        let viChar = ViChar(base: key, isUpperCase: isUpperCase)
        buffer.append(viChar)

        let newText = buffer.text
        return buildReplacement(oldText: oldText, newText: newText)
    }

    // MARK: - Backspace Handling

    private func handleBackspace() -> EngineResult {
        buffer.removeLast()
        // Once the user corrects mid-word, we cannot reliably reconstruct
        // the original raw keystrokes, so we disable the restore path for
        // the remainder of this session.
        rawKeystrokes = ""
        return .passThrough
    }

    // MARK: - Grammar Re-check

    /// After adding a consonant following vowels, the tone mark position
    /// might need to shift. e.g., typing "toa" + "s" places tone on 'o',
    /// but then typing "n" (making "toasn" -> "toán") requires moving tone to 'a'.
    private func recheckTonePlacement() -> EngineResult? {
        guard let currentToneIdx = buffer.toneIndex else { return nil }
        guard let newPosition = TonePlacement.findTonePosition(in: buffer) else { return nil }

        // If position hasn't changed, no action needed
        if newPosition == currentToneIdx { return nil }

        let oldText = buffer.text
        buffer.moveTone(to: newPosition)
        let newText = buffer.text

        // Only emit replacement if the text actually changed
        if oldText == newText { return nil }

        return buildReplacement(oldText: oldText, newText: newText)
    }

    // MARK: - Spelling Restore

    /// If the current buffer carries Telex transformations (tone, modifier,
    /// or d-stroke) but does not form a structurally valid Vietnamese syllable,
    /// return a restore result that replaces the composed text with the raw
    /// keystrokes the user originally typed. Returns nil when no restore is
    /// needed.
    private func restoreIfInvalid() -> EngineResult? {
        guard !buffer.isEmpty else { return nil }
        guard !rawKeystrokes.isEmpty else { return nil }

        // Only restore when the buffer actually contains a Telex transformation;
        // otherwise the user just typed plain letters that we should leave alone.
        let hasTransformation = buffer.chars.contains {
            $0.modifier != .none || $0.tone != .none || $0.hasDStroke
        }
        guard hasTransformation else { return nil }

        // Don't restore if the syllable is structurally valid.
        if SpellingChecker.isValidSyllable(buffer) { return nil }

        // Avoid a no-op replacement if nothing would change on screen.
        let composed = buffer.text
        if composed == rawKeystrokes { return nil }

        return .restore(backspaces: composed.count, text: rawKeystrokes)
    }

    // MARK: - Replacement Building

    /// Build an EngineResult.replace by comparing old and new buffer text.
    /// Calculates the minimum number of backspaces needed.
    private func buildReplacement(oldText: String, newText: String) -> EngineResult {
        // Find the common prefix length
        let commonPrefix = zip(oldText, newText).prefix(while: { $0 == $1 }).count

        // Number of old characters to delete (after the common prefix)
        let backspaces = oldText.count - commonPrefix

        // New characters to send (after the common prefix)
        let newSuffix = String(newText.dropFirst(commonPrefix))

        if backspaces == 0 && newSuffix.isEmpty {
            return .passThrough
        }

        return .replace(backspaces: backspaces, text: newSuffix)
    }
}
