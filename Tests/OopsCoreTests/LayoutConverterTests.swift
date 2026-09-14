import XCTest
@testable import OopsCore

final class LayoutConverterTests: XCTestCase {

    func testEnglishToRussian() {
        XCTAssertEqual(LayoutConverter.toRussian("vfvf"), "мама")
        XCTAssertEqual(LayoutConverter.toRussian("Z nt,z k.,k."), "Я тебя люблю")
        XCTAssertEqual(LayoutConverter.toRussian("ghbdtn"), "привет")
        XCTAssertEqual(LayoutConverter.toRussian(""), "")
    }

    func testRussianToEnglish() {
        XCTAssertEqual(LayoutConverter.toEnglish("мама"), "vfvf")
        XCTAssertEqual(LayoutConverter.toEnglish("Я тебя люблю"), "Z nt,z k.,k.")
        XCTAssertEqual(LayoutConverter.toEnglish("привет"), "ghbdtn")
    }

    func testRoundTripIsStable() {
        let latin = "Hello, World!"
        XCTAssertEqual(LayoutConverter.toEnglish(LayoutConverter.toRussian(latin)), latin)

        let cyrillic = "Привет, мир!"
        XCTAssertEqual(LayoutConverter.toRussian(LayoutConverter.toEnglish(cyrillic)), cyrillic)
    }

    func testDirectionFollowsTheMajorityAlphabet() {
        var converted = LayoutConverter.autoConvert("vfvf")
        XCTAssertEqual(converted.direction, .toRussian)
        XCTAssertEqual(converted.result, "мама")

        converted = LayoutConverter.autoConvert("мама")
        XCTAssertEqual(converted.direction, .toEnglish)
        XCTAssertEqual(converted.result, "vfvf")

        // Digits and punctuation get no vote — nothing to decide, nothing to do.
        converted = LayoutConverter.autoConvert("123 !@#")
        XCTAssertEqual(converted.direction, .unchanged)
        XCTAssertEqual(converted.result, "123 !@#")
    }

    func testShiftSymbolsMapByKeyPosition() {
        let pairs: [(String, String)] = [
            ("@", "\""), ("#", "№"), ("$", ";"), ("^", ":"),
            ("&", "?"), ("|", "/"), ("?", ","), ("~", "Ё"), ("`", "ё")
        ]
        for (english, russian) in pairs {
            XCTAssertEqual(LayoutConverter.toRussian(english), russian, "EN → RU for \(english)")
            XCTAssertEqual(LayoutConverter.toEnglish(russian), english, "RU → EN for \(russian)")
        }
    }
}
