// TonePlacement.swift
// Smart (modern) Vietnamese tone mark placement algorithm.
//
// Implements the standard modern Vietnamese orthographic rules
// (Quy tắc đặt dấu thanh tiếng Việt - kiểu mới).
//
// Sources:
// - Vietnamese orthographic conventions as taught in Vietnamese education system
// - The "new style" rule adopted by Vietnamese language authorities
//
// Core principle: the tone mark goes on the **main vowel** of the syllable nucleus.

import Foundation

enum TonePlacement {

    /// Determine which vowel index in the buffer should receive the tone mark.
    ///
    /// - Parameters:
    ///   - buffer: The current syllable buffer.
    /// - Returns: The index into `buffer.chars` where the tone should be placed,
    ///            or nil if no valid position exists.
    static func findTonePosition(in buffer: SyllableBuffer) -> Int? {
        let vowelIndices = buffer.vowelIndices
        guard !vowelIndices.isEmpty else { return nil }

        // Single vowel: tone goes on it
        if vowelIndices.count == 1 {
            return vowelIndices[0]
        }

        let hasEnding = buffer.hasEndingConsonant
        let initial = buffer.initialConsonant.lowercased()

        // Handle special consonant-vowel combinations
        // "qu" + vowel: the 'u' in 'qu' is part of the consonant, skip it
        // "gi" + vowel: the 'i' in 'gi' is part of the consonant when followed by another vowel
        let effectiveVowelIndices = adjustForConsonantClusters(
            vowelIndices: vowelIndices,
            initial: initial,
            buffer: buffer
        )

        guard !effectiveVowelIndices.isEmpty else { return vowelIndices.last }

        if effectiveVowelIndices.count == 1 {
            return effectiveVowelIndices[0]
        }

        // Get the effective vowel cluster after adjustment
        let effectiveVowels = String(effectiveVowelIndices.map { buffer.chars[$0].base })

        return positionForVowelCluster(
            vowels: effectiveVowels,
            indices: effectiveVowelIndices,
            hasEndingConsonant: hasEnding,
            buffer: buffer
        )
    }

    // MARK: - Private Helpers

    /// Adjust vowel indices to account for "qu" and "gi" consonant clusters
    /// where a vowel letter is actually part of the initial consonant.
    private static func adjustForConsonantClusters(
        vowelIndices: [Int],
        initial: String,
        buffer: SyllableBuffer
    ) -> [Int] {
        var adjusted = vowelIndices

        // "qu" + vowel: 'u' is part of consonant cluster
        // Only if there are more vowels after the 'u'
        if initial.hasSuffix("q"), adjusted.count > 1 {
            if let first = adjusted.first, buffer.chars[first].base == "u" {
                adjusted.removeFirst()
            }
        }

        // "gi" + vowel: 'i' is part of consonant when followed by another vowel
        // e.g., "gia" -> 'i' is consonantal, tone on 'a'
        // But "gi" alone -> 'i' is the vowel
        if initial == "g" || initial == "gi" {
            if adjusted.count > 1, let first = adjusted.first, buffer.chars[first].base == "i" {
                adjusted.removeFirst()
            }
        }

        return adjusted
    }

    /// Determine tone position for a multi-vowel cluster.
    ///
    /// Modern Vietnamese rules:
    /// 1. If the syllable has an ending consonant -> tone on the **last** vowel of the nucleus
    ///    that carries a modifier (ô, ơ, â, ê, ă, ư), or the second vowel if none has a modifier.
    /// 2. If no ending consonant -> tone on the **first** vowel of a two-vowel cluster,
    ///    unless the second vowel has a modifier.
    /// 3. Special vowel pairs have specific rules.
    private static func positionForVowelCluster(
        vowels: String,
        indices: [Int],
        hasEndingConsonant: Bool,
        buffer: SyllableBuffer
    ) -> Int {
        let count = indices.count
        let lower = vowels.lowercased()

        // Three-vowel clusters: tone on the middle vowel
        // e.g., "oai" -> tone on 'a', "uye" -> tone on 'y', "uoi" -> tone on 'o'
        if count >= 3 {
            return indices[1]
        }

        // Two-vowel clusters
        guard count == 2 else { return indices.last! }

        let first = lower.first!
        let second = lower.last!

        // Check if either vowel has a modifier (circumflex, horn, breve)
        let firstMod = buffer.chars[indices[0]].modifier
        let secondMod = buffer.chars[indices[1]].modifier

        // If a vowel has a modifier (â, ă, ê, ô, ơ, ư), it's the main vowel
        // and gets the tone mark
        if secondMod != .none && firstMod == .none {
            return indices[1]
        }
        if firstMod != .none && secondMod == .none {
            return indices[0]
        }

        // Both or neither have modifiers -> apply positional rules

        // With ending consonant: tone on the SECOND vowel
        // e.g., "toán", "hoàng", "uyên"
        if hasEndingConsonant {
            return indices[1]
        }

        // Without ending consonant: apply specific pair rules

        // Diphthongs ending in 'i', 'u', 'y' (falling diphthongs):
        // ai, oi, ui, ao, au, eu, iu, ay, uy -> tone on FIRST vowel
        // e.g., "hai" -> "hái", "cao" -> "cáo", "đau" -> "đáu"
        let fallingEnders: Set<Character> = ["i", "y", "u"]
        if fallingEnders.contains(second) && !fallingEnders.contains(first) {
            return indices[0]
        }

        // Rising diphthongs where first vowel glides into second:
        // ia, ua, ưa -> tone on FIRST vowel
        // e.g., "mía", "của", "mùa"
        if (first == "i" || first == "u") && second == "a" {
            return indices[0]
        }

        // "oa", "oe" clusters: tone on the SECOND vowel
        // e.g., "hoà" (modern) -> tone on 'a'
        if first == "o" && (second == "a" || second == "e") {
            return indices[1]
        }

        // "ue" cluster: tone on the SECOND vowel
        if first == "u" && second == "e" {
            return indices[1]
        }

        // Default for remaining two-vowel clusters without ending consonant:
        // tone on the first vowel
        return indices[0]
    }
}
