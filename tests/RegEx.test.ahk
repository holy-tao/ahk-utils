#Include ../text/RegEx.ahk
#Include YUnit\Assert.ahk

class RegExTests {
    class Split {
        RegExSplit_WithNoMatches_ReturnsInputString() {
            parts := RegEx.Split("OneTwoThree", "\s")

            Assert.ArraysEqual(parts, ["OneTwoThree"])
        }
        
        RegExSplit_WithMatches_SplitsAtMatches() {
            parts := RegEx.Split("One-Two-Three", "-")

            Assert.ArraysEqual(parts, ["One", "Two", "Three"])
        }

        RegExSplit_WithAdjacentMatches_AddsEmptyStrings() {
            parts := RegEx.Split("One-Two--Three", "-")

            Assert.ArraysEqual(parts, ["One", "Two", "", "Three"])
        }
    }

    class Matches {
        RegExMatches_WithNoMatches_ReturnsEmptyArray() {
            matches := RegEx.Matches("OneTwoThree", "\d+")

            Assert.ArraysEqual(matches, [])
        }

        RegExMatches_WithMatches_ReturnsThem() {
            matches := RegEx.Matches("One1Two2Three3", "[^\d]+")

            Assert.ArraysEqual(matches, ["One", "Two", "Three"])
        }

        RegExMatches_WithAdjacentMatches_ReturnsThem() {
            matches := RegEx.Matches("123", "\d")

            Assert.ArraysEqual(matches, ["1", "2", "3"])
        }
    }
}