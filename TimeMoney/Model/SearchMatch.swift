import Foundation

/// One definition of "this matches what I typed", used by every list filter.
///
/// The obvious way to filter a list is `localizedCaseInsensitiveContains`, and it is
/// wrong in three ways that all look like the app having nothing to show you:
///
///  - **Word order.** "membership gym" finds nothing in "Gym membership", because the
///    letters are not adjacent. People do not recall the phrase, they recall two of
///    the words.
///  - **Accents.** "cafe" does not find "Café". The keyboard makes one of those far
///    easier to type than the other, and it is not the one that got stored.
///  - **Partial words.** "warr" does not find "warranty" under a whole-word rule, and
///    searching is most useful before you have typed the whole thing.
///
/// So: fold both sides, split both into words, and require every word typed to be the
/// **start** of some word in the text. Order-independent, accent-blind, and it narrows
/// as you type rather than flicking between all and nothing.
///
/// Prefix rather than substring on purpose. Substring matching makes short queries
/// match almost everything — "in" would hit every payee with "ing" in it — and the
/// noise arrives exactly when the query is shortest and the list longest.
enum SearchMatch {

    /// The form two spellings of the same thing have in common: lower-cased, stripped
    /// of accents, and with anything that is not a letter or digit treated as a space.
    ///
    /// Nothing is dropped as noise. A search box is the one place where a word the
    /// app considers unimportant is still exactly the word somebody meant.
    static func fold(_ text: String) -> String {
        let folded = text.folding(options: [.diacriticInsensitive, .caseInsensitive],
                                  locale: Locale(identifier: "en_GB"))
            // The one symbol worth spelling out. "M&S" is typed as "M&S", "M and S"
            // and "M S" by the same person on different days, and all three should
            // reach the same row; dropping the ampersand to a space only serves the
            // third. Widening a match, never narrowing one.
            .replacingOccurrences(of: "&", with: " and ")
        return String(folded.map { $0.isLetter || $0.isNumber ? $0 : " " })
    }

    /// The words of a query, folded. Empty when there is nothing to search for.
    static func terms(_ query: String) -> [String] {
        fold(query).split(separator: " ").map(String.init)
    }

    /// Whether `fields` together satisfy every word of `query`.
    ///
    /// The fields are searched as one body of text, so a query can span them — typing
    /// A query can span a title and its keywords, though neither contains both words.
    /// That is how people remember a thing: by a couple of facts about it, not by
    /// which box each fact lives in.
    ///
    /// An empty query matches everything, so a filter can be applied unconditionally
    /// and the unfiltered list is what an empty search box shows.
    static func matches(_ query: String, in fields: [String?]) -> Bool {
        let needles = terms(query)
        guard !needles.isEmpty else { return true }

        let haystack = fields
            .compactMap { $0 }
            .map(fold)
            .joined(separator: " ")
            .split(separator: " ")
            .map(String.init)
        guard !haystack.isEmpty else { return false }

        return needles.allSatisfy { needle in
            haystack.contains { $0.hasPrefix(needle) }
        }
    }

    /// Convenience for the common single-field case.
    static func matches(_ query: String, in field: String) -> Bool {
        matches(query, in: [field])
    }
}
