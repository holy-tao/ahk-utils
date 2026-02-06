#Requires AutoHotkey v2.0

#Include ./YUnit/Assert.ahk

#Include ../text/SemVer.ahk

class SemVerTests {

    class Parsing {

        class Success {
            ; Basic versions
            Parse_Simple() {
                v := SemVer.Parse("1.2.3")
                Assert.Equals(v.major, 1)
                Assert.Equals(v.minor, 2)
                Assert.Equals(v.patch, 3)
                Assert.Equals(v.prerelease, "")
                Assert.Equals(v.build, "")
            }

            Parse_WithZeros() {
                v := SemVer.Parse("0.0.4")
                Assert.Equals(v.major, 0)
                Assert.Equals(v.minor, 0)
                Assert.Equals(v.patch, 4)
            }

            Parse_LargeNumbers() {
                v := SemVer.Parse("10.20.30")
                Assert.Equals(v.major, 10)
                Assert.Equals(v.minor, 20)
                Assert.Equals(v.patch, 30)
            }

            ; With prerelease
            Parse_Prerelease() {
                v := SemVer.Parse("1.0.0-alpha")
                Assert.Equals(v.prerelease, "alpha")
            }

            Parse_PrereleaseWithDots() {
                v := SemVer.Parse("1.0.0-alpha.beta.1")
                Assert.Equals(v.prerelease, "alpha.beta.1")
            }

            Parse_ComplexPrerelease() {
                v := SemVer.Parse("1.2.3----RC-SNAPSHOT.12.9.1--.12")
                Assert.Equals(v.major, 1)
                Assert.Equals(v.minor, 2)
                Assert.Equals(v.patch, 3)
                Assert.Equals(v.prerelease, "---RC-SNAPSHOT.12.9.1--.12")
            }

            Parse_PrereleaseWithNumeric() {
                v := SemVer.Parse("1.0.0-alpha.1")
                Assert.Equals(v.prerelease, "alpha.1")
            }

            Parse_PrereleaseAlphanumeric() {
                v := SemVer.Parse("1.0.0-alpha0.valid")
                Assert.Equals(v.prerelease, "alpha0.valid")
            }

            ; With build metadata
            Parse_BuildMetadata() {
                v := SemVer.Parse("1.1.2+meta")
                Assert.Equals(v.build, "meta")
                Assert.Equals(v.prerelease, "")
            }

            Parse_BuildMetadataComplex() {
                v := SemVer.Parse("2.0.0+build.1848")
                Assert.Equals(v.build, "build.1848")
            }

            Parse_BuildMetadataWithDashes() {
                v := SemVer.Parse("1.1.2+meta-valid")
                Assert.Equals(v.build, "meta-valid")
            }

            ; With both prerelease and build
            Parse_PrereleaseAndBuild() {
                v := SemVer.Parse("1.1.2-prerelease+meta")
                Assert.Equals(v.prerelease, "prerelease")
                Assert.Equals(v.build, "meta")
            }

            Parse_ComplexBoth() {
                v := SemVer.Parse("1.0.0-alpha-a.b-c-somethinglong+build.1-aef.1-its-okay")
                Assert.Equals(v.prerelease, "alpha-a.b-c-somethinglong")
                Assert.Equals(v.build, "build.1-aef.1-its-okay")
            }

            Parse_RCWithBuild() {
                v := SemVer.Parse("1.0.0-rc.1+build.1")
                Assert.Equals(v.prerelease, "rc.1")
                Assert.Equals(v.build, "build.1")
            }

            ; Edge cases
            Parse_VeryLargeNumbers() {
                v := SemVer.Parse("999999999999999999.999999999999999999.99999999999999999")
                Assert.Equals(v.ToString(), "999999999999999999.999999999999999999.99999999999999999")
            }

            Parse_PrereleaseStartingWithZero() {
                v := SemVer.Parse("1.0.0-0A.is.legal")
                Assert.Equals(v.prerelease, "0A.is.legal")
            }

            ; With leading v
            Parse_LeadingV() {
                v := SemVer.Parse("v1.2.3")
                Assert.Equals(v.major, 1)
                Assert.Equals(v.minor, 2)
                Assert.Equals(v.patch, 3)
            }
        }

        class Failure {
            ; Incomplete versions
            Parse_SingleNumber_Throws() {
                Assert.Throws((*) => SemVer.Parse("1"), ValueError)
            }

            Parse_TwoNumbers_Throws() {
                Assert.Throws((*) => SemVer.Parse("1.2"), ValueError)
            }

            ; Leading zeros (not allowed in numeric identifiers)
            Parse_LeadingZeroMajor_Throws() {
                Assert.Throws((*) => SemVer.Parse("01.1.1"), ValueError)
            }

            Parse_LeadingZeroMinor_Throws() {
                Assert.Throws((*) => SemVer.Parse("1.01.1"), ValueError)
            }

            Parse_LeadingZeroPatch_Throws() {
                Assert.Throws((*) => SemVer.Parse("1.1.01"), ValueError)
            }

            Parse_LeadingZeroInPrerelease_Throws() {
                Assert.Throws((*) => SemVer.Parse("1.2.3-0123"), ValueError)
            }

            Parse_LeadingZeroInPrereleaseIdentifier_Throws() {
                Assert.Throws((*) => SemVer.Parse("1.2.3-0123.0123"), ValueError)
            }

            ; Invalid formats
            Parse_NoVersion_Throws() {
                Assert.Throws((*) => SemVer.Parse("alpha"), ValueError)
            }

            Parse_AlphaBeta_Throws() {
                Assert.Throws((*) => SemVer.Parse("alpha.beta"), ValueError)
            }

            Parse_PlusOnly_Throws() {
                Assert.Throws((*) => SemVer.Parse("+invalid"), ValueError)
            }

            Parse_DashOnly_Throws() {
                Assert.Throws((*) => SemVer.Parse("-invalid"), ValueError)
            }

            Parse_BuildMetadataStartingWithDot_Throws() {
                Assert.Throws((*) => SemVer.Parse("1.1.2+.123"), ValueError)
            }

            Parse_UnderscoreInPrerelease_Throws() {
                Assert.Throws((*) => SemVer.Parse("1.0.0-alpha_beta"), ValueError)
            }

            Parse_UnderscoreInVersion_Throws() {
                Assert.Throws((*) => SemVer.Parse("alpha_beta"), ValueError)
            }

            Parse_DoubleDotInPrerelease_Throws() {
                Assert.Throws((*) => SemVer.Parse("1.0.0-alpha.."), ValueError)
            }

            Parse_DoubleDotInPrerelease2_Throws() {
                Assert.Throws((*) => SemVer.Parse("1.0.0-alpha..1"), ValueError)
            }

            Parse_FourComponents_Throws() {
                Assert.Throws((*) => SemVer.Parse("1.2.3.4"), ValueError)
            }

            Parse_ExtraComponentWithText_Throws() {
                Assert.Throws((*) => SemVer.Parse("1.2.3.DEV"), ValueError)
            }

            Parse_MultiplePlus_Throws() {
                Assert.Throws((*) => SemVer.Parse("9.8.7+meta+meta"), ValueError)
            }

            Parse_LeadingDash_Throws() {
                Assert.Throws((*) => SemVer.Parse("-1.0.3-gamma+b7718"), ValueError)
            }

            Parse_JustMeta_Throws() {
                Assert.Throws((*) => SemVer.Parse("+justmeta"), ValueError)
            }
        }
    }

    class FuzzyParsing {

        class Success {
            ; Test padding incomplete versions with zeros
            FuzzyParse_SingleNumber() {
                v := SemVer.FuzzyParse("1")
                Assert.Equals(v.major, 1)
                Assert.Equals(v.minor, 0)
                Assert.Equals(v.patch, 0)
            }

            FuzzyParse_TwoNumbers() {
                v := SemVer.FuzzyParse("1.2")
                Assert.Equals(v.major, 1)
                Assert.Equals(v.minor, 2)
                Assert.Equals(v.patch, 0)
            }

            FuzzyParse_CompleteVersion() {
                v := SemVer.FuzzyParse("1.2.3")
                Assert.Equals(v.major, 1)
                Assert.Equals(v.minor, 2)
                Assert.Equals(v.patch, 3)
            }

            ; Test ignoring extra version components
            FuzzyParse_FourComponents() {
                v := SemVer.FuzzyParse("1.2.3.4")
                Assert.Equals(v.major, 1)
                Assert.Equals(v.minor, 2)
                Assert.Equals(v.patch, 3)
                Assert.Equals(v.prerelease, "")
                Assert.Equals(v.build, "")
            }

            FuzzyParse_ManyComponents() {
                v := SemVer.FuzzyParse("1.2.3.4.5.6")
                Assert.Equals(v.major, 1)
                Assert.Equals(v.minor, 2)
                Assert.Equals(v.patch, 3)
            }

            ; Test with prerelease
            FuzzyParse_ExtraComponentWithPrerelease() {
                v := SemVer.FuzzyParse("1.2.3.4-alpha")
                Assert.Equals(v.major, 1)
                Assert.Equals(v.minor, 2)
                Assert.Equals(v.patch, 3)
                Assert.Equals(v.prerelease, "alpha")
                Assert.Equals(v.build, "")
            }

            FuzzyParse_IncompleteWithPrerelease() {
                v := SemVer.FuzzyParse("1.0-beta")
                Assert.Equals(v.major, 1)
                Assert.Equals(v.minor, 0)
                Assert.Equals(v.patch, 0)
                Assert.Equals(v.prerelease, "beta")
            }

            FuzzyParse_PrereleaseWithDots() {
                v := SemVer.FuzzyParse("2.1.3-rc.1")
                Assert.Equals(v.major, 2)
                Assert.Equals(v.minor, 1)
                Assert.Equals(v.patch, 3)
                Assert.Equals(v.prerelease, "rc.1")
            }

            FuzzyParse_PrereleaseWithTrailingPlus() {
                v := SemVer.FuzzyParse("2.1.3-rc.1+")
                Assert.Equals(v.major, 2)
                Assert.Equals(v.minor, 1)
                Assert.Equals(v.patch, 3)
                Assert.Equals(v.prerelease, "rc.1")
            }

            FuzzyParse_VersionTrailingDash() {
                v := SemVer.FuzzyParse("2.1.3-")
                Assert.Equals(v.major, 2)
                Assert.Equals(v.minor, 1)
                Assert.Equals(v.patch, 3)
                Assert.Equals(v.prerelease, "")
            }

            FuzzyParse_IncompleteVersionTrailingDash() {
                v := SemVer.FuzzyParse("2.3-")
                Assert.Equals(v.major, 2)
                Assert.Equals(v.minor, 3)
                Assert.Equals(v.patch, 0)
                Assert.Equals(v.prerelease, "")
            }

            FuzzyParse_TrailingDashAndPlus() {
                v := SemVer.FuzzyParse("2.3.4-+")
                Assert.Equals(v.major, 2)
                Assert.Equals(v.minor, 3)
                Assert.Equals(v.patch, 4)
                Assert.Equals(v.prerelease, "")
            }

            ; Test with build metadata
            FuzzyParse_WithBuildMetadata() {
                v := SemVer.FuzzyParse("1.2.3+build123")
                Assert.Equals(v.major, 1)
                Assert.Equals(v.minor, 2)
                Assert.Equals(v.patch, 3)
                Assert.Equals(v.prerelease, "")
                Assert.Equals(v.build, "build123")
            }

            FuzzyParse_IncompleteWithBuild() {
                v := SemVer.FuzzyParse("1.0+abc")
                Assert.Equals(v.major, 1)
                Assert.Equals(v.minor, 0)
                Assert.Equals(v.patch, 0)
                Assert.Equals(v.build, "abc")
            }

            ; Test with both prerelease and build
            FuzzyParse_PrereleaseAndBuild() {
                v := SemVer.FuzzyParse("1.2.3-rc.1+build.456")
                Assert.Equals(v.major, 1)
                Assert.Equals(v.minor, 2)
                Assert.Equals(v.patch, 3)
                Assert.Equals(v.prerelease, "rc.1")
                Assert.Equals(v.build, "build.456")
            }

            FuzzyParse_ExtraComponentsWithBoth() {
                v := SemVer.FuzzyParse("2.0.1.999-alpha+exp")
                Assert.Equals(v.major, 2)
                Assert.Equals(v.minor, 0)
                Assert.Equals(v.patch, 1)
                Assert.Equals(v.prerelease, "alpha")
                Assert.Equals(v.build, "exp")
            }

            ; Test leading "v"
            FuzzyParse_WithLeadingV() {
                v := SemVer.FuzzyParse("v1.2.3")
                Assert.Equals(v.major, 1)
                Assert.Equals(v.minor, 2)
                Assert.Equals(v.patch, 3)
            }

            FuzzyParse_LeadingVIncomplete() {
                v := SemVer.FuzzyParse("v2.0")
                Assert.Equals(v.major, 2)
                Assert.Equals(v.minor, 0)
                Assert.Equals(v.patch, 0)
            }

            FuzzyParse_LeadingVWithPrerelease() {
                v := SemVer.FuzzyParse("v0.4.2.54-test")
                Assert.Equals(v.major, 0)
                Assert.Equals(v.minor, 4)
                Assert.Equals(v.patch, 2)
                Assert.Equals(v.prerelease, "test")
            }
        }
        
        class Failure {
            ; Failure cases - should throw ValueError
            FuzzyParse_EmptyString_Throws() {
                Assert.Throws((*) => SemVer.FuzzyParse(""), ValueError)
            }

            FuzzyParse_NoVersionInfo_Throws() {
                Assert.Throws((*) => SemVer.FuzzyParse("alpha-beta"), ValueError)
            }

            FuzzyParse_InvalidCharacters_Throws() {
                Assert.Throws((*) => SemVer.FuzzyParse("1.2.3!"), ValueError)
            }

            FuzzyParse_OnlyV_Throws() {
                Assert.Throws((*) => SemVer.FuzzyParse("v"), ValueError)
            }

            ; Test that invalid prerelease/build metadata still throws
            ; (because the strict Parse validation catches it)
            FuzzyParse_InvalidPrerelease_Throws() {
                ; Prerelease can't start with a dot
                Assert.Throws((*) => SemVer.FuzzyParse("1.2.3-.alpha"), ValueError)
            }
        }
    }

    class Compare {
        ; Helper to assert a comparison result is positive (left > right)
        static AssertGreater(result) {
            if (result <= 0)
                throw Error(Format("Expected positive comparison result but got {1}", result))
        }

        ; Helper to assert a comparison result is negative (left < right)
        static AssertLess(result) {
            if (result >= 0)
                throw Error(Format("Expected negative comparison result but got {1}", result))
        }

        ; Basic version number comparisons
        Compare_MajorVersions() {
            SemVerTests.Compare.AssertGreater(SemVer.Parse("2.0.0").Compare("1.0.0"))
            SemVerTests.Compare.AssertLess(SemVer.Parse("1.0.0").Compare("2.0.0"))
        }

        Compare_MinorVersions() {
            SemVerTests.Compare.AssertGreater(SemVer.Parse("1.1.0").Compare("1.0.0"))
            SemVerTests.Compare.AssertLess(SemVer.Parse("1.0.0").Compare("1.1.0"))
        }

        Compare_PatchVersions() {
            SemVerTests.Compare.AssertGreater(SemVer.Parse("1.0.1").Compare("1.0.0"))
            SemVerTests.Compare.AssertLess(SemVer.Parse("1.0.0").Compare("1.0.1"))
        }

        Compare_Equal() {
            Assert.Equals(SemVer.Parse("1.2.3").Compare("1.2.3"), 0)
        }

        ; Pre-release precedence: pre-release < normal version
        Compare_PrereleaseVsNormal() {
            SemVerTests.Compare.AssertLess(SemVer.Parse("1.0.0-alpha").Compare("1.0.0"))
            SemVerTests.Compare.AssertGreater(SemVer.Parse("1.0.0").Compare("1.0.0-alpha"))
        }

        Compare_PrereleaseVsNormal_DifferentVersions() {
            ; 1.0.0-alpha < 1.0.0 < 1.0.1-alpha
            SemVerTests.Compare.AssertLess(SemVer.Parse("1.0.0-alpha").Compare("1.0.0"))
            SemVerTests.Compare.AssertLess(SemVer.Parse("1.0.0").Compare("1.0.1-alpha"))
        }

        ; Pre-release comparisons: lexical order
        Compare_PrereleaseAlphabetical() {
            SemVerTests.Compare.AssertLess(SemVer.Parse("1.0.0-alpha").Compare("1.0.0-beta"))
            SemVerTests.Compare.AssertGreater(SemVer.Parse("1.0.0-beta").Compare("1.0.0-alpha"))
        }

        Compare_PrereleaseNumeric() {
            SemVerTests.Compare.AssertLess(SemVer.Parse("1.0.0-alpha.1").Compare("1.0.0-alpha.2"))
            SemVerTests.Compare.AssertGreater(SemVer.Parse("1.0.0-alpha.10").Compare("1.0.0-alpha.2"))  ; Numeric comparison
        }

        Compare_PrereleaseMoreFields() {
            ; Larger set of fields has higher precedence
            SemVerTests.Compare.AssertLess(SemVer.Parse("1.0.0-alpha").Compare("1.0.0-alpha.1"))
            SemVerTests.Compare.AssertGreater(SemVer.Parse("1.0.0-alpha.1").Compare("1.0.0-alpha"))
        }

        Compare_PrereleaseNumericVsAlpha() {
            ; Numeric identifiers have lower precedence than non-numeric
            SemVerTests.Compare.AssertLess(SemVer.Parse("1.0.0-1").Compare("1.0.0-alpha"))
        }

        Compare_PrereleaseComplex() {
            ; Test complex pre-release comparison
            SemVerTests.Compare.AssertGreater(SemVer.Parse("1.0.0-alpha.beta").Compare("1.0.0-alpha.1"))  ; "beta" > 1 (alpha > numeric)
            SemVerTests.Compare.AssertLess(SemVer.Parse("1.0.0-rc.1").Compare("1.0.0-rc.2"))
        }

        Compare_PrereleaseEqual() {
            Assert.Equals(SemVer.Parse("1.0.0-alpha").Compare("1.0.0-alpha"), 0)
            Assert.Equals(SemVer.Parse("1.0.0-rc.1").Compare("1.0.0-rc.1"), 0)
        }

        ; Build metadata should be ignored
        Compare_BuildMetadataIgnored() {
            Assert.Equals(SemVer.Parse("1.0.0+build1").Compare("1.0.0+build2"), 0)
            Assert.Equals(SemVer.Parse("1.0.0").Compare("1.0.0+build"), 0)
        }

        Compare_BuildMetadataIgnored_WithPrerelease() {
            Assert.Equals(SemVer.Parse("1.0.0-alpha+001").Compare("1.0.0-alpha+002"), 0)
            Assert.Equals(SemVer.Parse("1.0.0-alpha").Compare("1.0.0-alpha+build"), 0)
        }

        ; Spec examples from precedence section
        Compare_SpecExample_Sequence() {
            ; 1.0.0 < 2.0.0 < 2.1.0 < 2.1.1
            SemVerTests.Compare.AssertLess(SemVer.Parse("1.0.0").Compare("2.0.0"))
            SemVerTests.Compare.AssertLess(SemVer.Parse("2.0.0").Compare("2.1.0"))
            SemVerTests.Compare.AssertLess(SemVer.Parse("2.1.0").Compare("2.1.1"))
        }

        Compare_SpecExample_PrereleaseSequence() {
            ; 1.0.0-alpha < 1.0.0-alpha.1 < 1.0.0-alpha.beta < 1.0.0-beta < 1.0.0-beta.2 < 1.0.0-beta.11 < 1.0.0-rc.1 < 1.0.0
            v1 := SemVer.Parse("1.0.0-alpha")
            v2 := SemVer.Parse("1.0.0-alpha.1")
            v3 := SemVer.Parse("1.0.0-alpha.beta")
            v4 := SemVer.Parse("1.0.0-beta")
            v5 := SemVer.Parse("1.0.0-beta.2")
            v6 := SemVer.Parse("1.0.0-beta.11")
            v7 := SemVer.Parse("1.0.0-rc.1")
            v8 := SemVer.Parse("1.0.0")

            SemVerTests.Compare.AssertLess(v1.Compare(v2))
            SemVerTests.Compare.AssertLess(v2.Compare(v3))
            SemVerTests.Compare.AssertLess(v3.Compare(v4))
            SemVerTests.Compare.AssertLess(v4.Compare(v5))
            SemVerTests.Compare.AssertLess(v5.Compare(v6))
            SemVerTests.Compare.AssertLess(v6.Compare(v7))
            SemVerTests.Compare.AssertLess(v7.Compare(v8))
        }

        ; Compare with string argument (not just SemVer object)
        Compare_WithString() {
            v := SemVer.Parse("1.2.3")
            SemVerTests.Compare.AssertGreater(v.Compare("1.2.2"))
            SemVerTests.Compare.AssertLess(v.Compare("1.2.4"))
            Assert.Equals(v.Compare("1.2.3"), 0)
        }

        Compare_WithString_Prerelease() {
            v := SemVer.Parse("1.0.0-alpha")
            SemVerTests.Compare.AssertLess(v.Compare("1.0.0-beta"))
            SemVerTests.Compare.AssertLess(v.Compare("1.0.0"))
        }

        ; Edge cases
        Compare_LargeNumbers() {
            SemVerTests.Compare.AssertGreater(SemVer.Parse("999999999.0.0").Compare("1.0.0"))
        }

        Compare_ZeroVersions() {
            Assert.Equals(SemVer.Parse("0.0.0").Compare("0.0.0"), 0)
            SemVerTests.Compare.AssertGreater(SemVer.Parse("0.0.1").Compare("0.0.0"))
        }

        ; Comparison convenience methods
        IsGreaterThan_True() {
            v1 := SemVer.Parse("2.0.0")
            v2 := SemVer.Parse("1.0.0")
            Assert.Equals(v1.IsGreaterThan(v2), true)
        }

        IsGreaterThan_False() {
            v1 := SemVer.Parse("1.0.0")
            v2 := SemVer.Parse("2.0.0")
            Assert.Equals(v1.IsGreaterThan(v2), false)
        }

        IsGreaterThan_WithString() {
            v := SemVer.Parse("2.0.0")
            Assert.Equals(v.IsGreaterThan("1.0.0"), true)
        }

        IsLessThan_True() {
            v1 := SemVer.Parse("1.0.0")
            v2 := SemVer.Parse("2.0.0")
            Assert.Equals(v1.IsLessThan(v2), true)
        }

        IsLessThan_False() {
            v1 := SemVer.Parse("2.0.0")
            v2 := SemVer.Parse("1.0.0")
            Assert.Equals(v1.IsLessThan(v2), false)
        }

        IsLessThan_WithString() {
            v := SemVer.Parse("1.0.0")
            Assert.Equals(v.IsLessThan("2.0.0"), true)
        }

        Equals_True() {
            v1 := SemVer.Parse("1.2.3")
            v2 := SemVer.Parse("1.2.3")
            Assert.Equals(v1.Equals(v2), true)
        }

        Equals_False() {
            v1 := SemVer.Parse("1.2.3")
            v2 := SemVer.Parse("1.2.4")
            Assert.Equals(v1.Equals(v2), false)
        }

        Equals_IgnoresBuildMetadata() {
            v1 := SemVer.Parse("1.0.0+build1")
            v2 := SemVer.Parse("1.0.0+build2")
            Assert.Equals(v1.Equals(v2), true)
        }

        Equals_WithString() {
            v := SemVer.Parse("1.2.3")
            Assert.Equals(v.Equals("1.2.3"), true)
        }
    }

    class Utilities {
        ; IsPrerelease property tests
        IsPrerelease_NormalVersion() {
            v := SemVer.Parse("1.2.3")
            Assert.Equals(v.IsPrerelease, false)
        }

        IsPrerelease_WithPrerelease() {
            v := SemVer.Parse("1.2.3-alpha")
            Assert.Equals(v.IsPrerelease, true)
        }

        IsPrerelease_WithBuildOnly() {
            v := SemVer.Parse("1.2.3+build")
            Assert.Equals(v.IsPrerelease, false)
        }

        IsPrerelease_WithBoth() {
            v := SemVer.Parse("1.2.3-beta+build")
            Assert.Equals(v.IsPrerelease, true)
        }

        ; IncrementMajor tests
        IncrementMajor_Simple() {
            v := SemVer.Parse("1.2.3")
            v2 := v.IncrementMajor()
            Assert.Equals(v2.major, 2)
            Assert.Equals(v2.minor, 0)
            Assert.Equals(v2.patch, 0)
            Assert.Equals(v2.ToString(), "2.0.0")
        }

        IncrementMajor_WithPrerelease() {
            v := SemVer.Parse("1.2.3-alpha")
            v2 := v.IncrementMajor()
            Assert.Equals(v2.ToString(), "2.0.0")
            Assert.Equals(v2.prerelease, "")
        }

        IncrementMajor_WithBuild() {
            v := SemVer.Parse("1.2.3+build123")
            v2 := v.IncrementMajor()
            Assert.Equals(v2.ToString(), "2.0.0")
            Assert.Equals(v2.build, "")
        }

        IncrementMajor_WithBoth() {
            v := SemVer.Parse("1.2.3-rc.1+build.456")
            v2 := v.IncrementMajor()
            Assert.Equals(v2.ToString(), "2.0.0")
            Assert.Equals(v2.prerelease, "")
            Assert.Equals(v2.build, "")
        }

        IncrementMajor_DoesNotModifyOriginal() {
            v := SemVer.Parse("1.2.3")
            v2 := v.IncrementMajor()
            Assert.Equals(v.ToString(), "1.2.3")
            Assert.Equals(v2.ToString(), "2.0.0")
        }

        ; IncrementMinor tests
        IncrementMinor_Simple() {
            v := SemVer.Parse("1.2.3")
            v2 := v.IncrementMinor()
            Assert.Equals(v2.major, 1)
            Assert.Equals(v2.minor, 3)
            Assert.Equals(v2.patch, 0)
            Assert.Equals(v2.ToString(), "1.3.0")
        }

        IncrementMinor_WithPrerelease() {
            v := SemVer.Parse("1.2.3-alpha")
            v2 := v.IncrementMinor()
            Assert.Equals(v2.ToString(), "1.3.0")
            Assert.Equals(v2.prerelease, "")
        }

        IncrementMinor_WithBuild() {
            v := SemVer.Parse("1.2.3+build123")
            v2 := v.IncrementMinor()
            Assert.Equals(v2.ToString(), "1.3.0")
            Assert.Equals(v2.build, "")
        }

        IncrementMinor_WithBoth() {
            v := SemVer.Parse("1.2.3-beta.2+build")
            v2 := v.IncrementMinor()
            Assert.Equals(v2.ToString(), "1.3.0")
            Assert.Equals(v2.prerelease, "")
            Assert.Equals(v2.build, "")
        }

        IncrementMinor_DoesNotModifyOriginal() {
            v := SemVer.Parse("1.2.3")
            v2 := v.IncrementMinor()
            Assert.Equals(v.ToString(), "1.2.3")
            Assert.Equals(v2.ToString(), "1.3.0")
        }

        ; IncrementPatch tests
        IncrementPatch_Simple() {
            v := SemVer.Parse("1.2.3")
            v2 := v.IncrementPatch()
            Assert.Equals(v2.major, 1)
            Assert.Equals(v2.minor, 2)
            Assert.Equals(v2.patch, 4)
            Assert.Equals(v2.ToString(), "1.2.4")
        }

        IncrementPatch_WithPrerelease() {
            v := SemVer.Parse("1.2.3-alpha")
            v2 := v.IncrementPatch()
            Assert.Equals(v2.ToString(), "1.2.4")
            Assert.Equals(v2.prerelease, "")
        }

        IncrementPatch_WithBuild() {
            v := SemVer.Parse("1.2.3+build123")
            v2 := v.IncrementPatch()
            Assert.Equals(v2.ToString(), "1.2.4")
            Assert.Equals(v2.build, "")
        }

        IncrementPatch_WithBoth() {
            v := SemVer.Parse("1.2.3-rc.1+build.789")
            v2 := v.IncrementPatch()
            Assert.Equals(v2.ToString(), "1.2.4")
            Assert.Equals(v2.prerelease, "")
            Assert.Equals(v2.build, "")
        }

        IncrementPatch_DoesNotModifyOriginal() {
            v := SemVer.Parse("1.2.3")
            v2 := v.IncrementPatch()
            Assert.Equals(v.ToString(), "1.2.3")
            Assert.Equals(v2.ToString(), "1.2.4")
        }

        ; Test chaining increments
        IncrementChain_MajorThenMinor() {
            v := SemVer.Parse("1.2.3-alpha")
            v2 := v.IncrementMajor().IncrementMinor()
            Assert.Equals(v2.ToString(), "2.1.0")
        }

        IncrementChain_MinorThenPatch() {
            v := SemVer.Parse("1.2.3")
            v2 := v.IncrementMinor().IncrementPatch()
            Assert.Equals(v2.ToString(), "1.3.1")
        }

        IncrementChain_AllThree() {
            v := SemVer.Parse("1.2.3")
            v2 := v.IncrementMajor().IncrementMinor().IncrementPatch()
            Assert.Equals(v2.ToString(), "2.1.1")
        }

        ; Clone method
        Clone_CreatesNewInstance() {
            v := SemVer.Parse("1.2.3-alpha+build")
            v2 := v.Clone()
            Assert.Equals(v2.ToString(), "1.2.3-alpha+build")
        }

        Clone_IsIndependent() {
            v := SemVer.Parse("1.2.3")
            v2 := v.Clone()
            v3 := v2.IncrementMajor()
            Assert.Equals(v.ToString(), "1.2.3")
            Assert.Equals(v2.ToString(), "1.2.3")
            Assert.Equals(v3.ToString(), "2.0.0")
        }

        Clone_CopiesAllFields() {
            v := SemVer.Parse("1.2.3-rc.1+build.456")
            v2 := v.Clone()
            Assert.Equals(v2.major, 1)
            Assert.Equals(v2.minor, 2)
            Assert.Equals(v2.patch, 3)
            Assert.Equals(v2.prerelease, "rc.1")
            Assert.Equals(v2.build, "build.456")
        }
    }
}