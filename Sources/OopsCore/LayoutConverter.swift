/// Which way the text was converted. Reported back so the caller can switch the
/// system input source to match — the user carries on typing right after.
///
/// The case is `unchanged` rather than `none` on purpose: `.none` on a
/// non-optional enum collides with `Optional.none` the moment the value ends up
/// inside an optional, and the compiler picks the wrong one without a word.
public enum LayoutDirection: Equatable {
    case unchanged
    case toRussian
    case toEnglish
}

/// Character-for-character conversion between QWERTY (en-US) and ЙЦУКЕН (ru).
///
/// The table is built by physical key position, not by meaning: `q` and `й` sit
/// on the same key, so one replaces the other. There are no dictionaries and no
/// guessing here, and there must not be — that was tried and removed.
public enum LayoutConverter {

    private static let pairsLower: [(en: Character, ru: Character)] = [
        ("q", "й"), ("w", "ц"), ("e", "у"), ("r", "к"), ("t", "е"), ("y", "н"),
        ("u", "г"), ("i", "ш"), ("o", "щ"), ("p", "з"), ("[", "х"), ("]", "ъ"),
        ("a", "ф"), ("s", "ы"), ("d", "в"), ("f", "а"), ("g", "п"), ("h", "р"),
        ("j", "о"), ("k", "л"), ("l", "д"), (";", "ж"), ("'", "э"),
        ("z", "я"), ("x", "ч"), ("c", "с"), ("v", "м"), ("b", "и"), ("n", "т"),
        ("m", "ь"), (",", "б"), (".", "ю"), ("/", "."),
        ("`", "ё")
    ]

    private static let pairsUpper: [(en: Character, ru: Character)] = [
        ("Q", "Й"), ("W", "Ц"), ("E", "У"), ("R", "К"), ("T", "Е"), ("Y", "Н"),
        ("U", "Г"), ("I", "Ш"), ("O", "Щ"), ("P", "З"), ("{", "Х"), ("}", "Ъ"),
        ("A", "Ф"), ("S", "Ы"), ("D", "В"), ("F", "А"), ("G", "П"), ("H", "Р"),
        ("J", "О"), ("K", "Л"), ("L", "Д"), (":", "Ж"), ("\"", "Э"),
        ("Z", "Я"), ("X", "Ч"), ("C", "С"), ("V", "М"), ("B", "И"), ("N", "Т"),
        ("M", "Ь"), ("<", "Б"), (">", "Ю"), ("?", ","),
        ("~", "Ё"),
        // Shift+digit gives different characters on the two layouts. Mapped by
        // position, like everything else here.
        ("@", "\""),   // Shift+2
        ("#", "№"),    // Shift+3
        ("$", ";"),    // Shift+4
        ("^", ":"),    // Shift+6
        ("&", "?"),    // Shift+7
        ("|", "/")     // Shift+\
    ]

    private static let enToRu: [Character: Character] = {
        var map: [Character: Character] = [:]
        for pair in pairsLower + pairsUpper { map[pair.en] = pair.ru }
        return map
    }()

    private static let ruToEn: [Character: Character] = {
        var map: [Character: Character] = [:]
        for pair in pairsLower + pairsUpper { map[pair.ru] = pair.en }
        return map
    }()

    /// EN → RU. Characters outside both layouts are left alone.
    public static func toRussian(_ text: String) -> String {
        String(text.map { enToRu[$0] ?? $0 })
    }

    /// RU → EN. Characters outside both layouts are left alone.
    public static func toEnglish(_ text: String) -> String {
        String(text.map { ruToEn[$0] ?? $0 })
    }

    /// Converts and reports which way it went.
    ///
    /// The side is chosen by whichever alphabet has more letters in the piece.
    /// Digits and punctuation exist in both layouts and get no vote — otherwise
    /// "2024 (!!!)" would decide the direction for the words around it.
    public static func autoConvert(_ text: String) -> (result: String, direction: LayoutDirection) {
        var latin = 0
        var cyrillic = 0
        for character in text {
            if (character >= "a" && character <= "z") || (character >= "A" && character <= "Z") {
                latin += 1
            } else if (character >= "а" && character <= "я")
                        || (character >= "А" && character <= "Я")
                        || character == "ё" || character == "Ё" {
                cyrillic += 1
            }
        }

        if latin == 0 && cyrillic == 0 { return (text, .unchanged) }
        return latin >= cyrillic
            ? (toRussian(text), .toRussian)
            : (toEnglish(text), .toEnglish)
    }
}
