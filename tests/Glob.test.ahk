#Include ../Glob.ahk
#Include YUnit\Assert.ahk

; Records which directories _Walk visits so tests can check pruning, not just results.
;@ahkunit-ignore
class SpyMatcher extends FileSystemMatcher {
    visited := []

    _Walk(dir, rel, depth, matches) {
        this.visited.Push(rel = "" ? "." : rel)
        super._Walk(dir, rel, depth, matches)
    }
}

; Builds a throwaway directory tree before each test and deletes it afterwards.
;@ahkunit-ignore
class GlobFixture {
    static files := [
        "a.ahk",
        "tests/x.test.ahk",
        "tests/y.ahk",
        "tests/sub/z.test.ahk",
        "tests/sub/deep/d.test.ahk",
        "node_modules/pkg/q.test.ahk",
        "src/m.ahk",
        "src/build/out.ahk",
        "src/lib/l.ahk",
        "src/lib/x/lx.ahk",
        "build/b.ahk",
    ]

    Begin() {
        this.root := A_Temp "\GlobTests_" A_TickCount "_" Random(0, 0xFFFF)
        for file in GlobFixture.files {
            path := this.root "\" StrReplace(file, "/", "\")
            SplitPath(path, , &dir)
            DirCreate(dir)
            FileAppend("", path)
        }
    }

    End() {
        if DirExist(this.root)
            DirDelete(this.root, true)
    }

    /**
     * Run `matcher` against the fixture and return the matches relative to the root, using "/"
     * separators, in sorted order.
     */
    Collect(matcher) {
        joined := ""
        for path in matcher.Matches(this.root)
            joined .= StrReplace(SubStr(path, StrLen(this.root) + 2), "\", "/") "`n"
        joined := Sort(RTrim(joined, "`n"))
        return joined = "" ? [] : StrSplit(joined, "`n")
    }

    static Sorted(arr) {
        joined := ""
        for item in arr
            joined .= item "`n"
        joined := Sort(RTrim(joined, "`n"))
        return joined = "" ? [] : StrSplit(joined, "`n")
    }
}

class GlobTests {
    class Compile {
        Star_MatchesWithinSegment() {
            Assert.Equals(Glob.Matches("foo.ahk", "*.ahk"), 1)
            Assert.Equals(Glob.Matches("a/foo.ahk", "*.ahk"), 0)
        }

        QuestionMark_MatchesOneCharacter() {
            Assert.Equals(Glob.Matches("a1.ahk", "a?.ahk"), 1)
            Assert.Equals(Glob.Matches("a12.ahk", "a?.ahk"), 0)
            Assert.Equals(Glob.Matches("a/.ahk", "a?.ahk"), 0)
        }

        DoubleStarSlash_MatchesZeroOrMoreDirectories() {
            Assert.Equals(Glob.Matches("x.ahk", "**/x.ahk"), 1)
            Assert.Equals(Glob.Matches("a/b/x.ahk", "**/x.ahk"), 1)
            Assert.Equals(Glob.Matches("ax.ahk", "**/x.ahk"), 0)
        }

        DoubleStar_CrossesSegments() {
            Assert.Equals(Glob.Matches("tests/a/b.ahk", "tests/**.ahk"), 1)
        }

        SpecialCharacters_AreLiteral() {
            Assert.Equals(Glob.Matches("a.b", "a.b"), 1)
            Assert.Equals(Glob.Matches("axb", "a.b"), 0)
            Assert.Equals(Glob.Matches("f(1)+$.txt", "f(1)+$.txt"), 1)
        }

        Matching_IsCaseInsensitive() {
            Assert.Equals(Glob.Matches("SRC/Main.AHK", "src/*.ahk"), 1)
        }

        Matching_IsAnchored() {
            Assert.Equals(Glob.Matches("src/m.ahk.bak", "src/*.ahk"), 0)
            Assert.Equals(Glob.Matches("x/src/m.ahk", "src/*.ahk"), 0)
        }
    }

    class Anchor {
        FixedFolder_IsSplitFromWildcardSegment() {
            a := FileSystemMatcher._Anchor("tests/*.test.ahk")
            Assert.Equals(a.dir, "tests")
            Assert.Equals(a.depth, 1)
        }

        MultipleFixedSegments_AreJoined() {
            a := FileSystemMatcher._Anchor("src/lib/*.ahk")
            Assert.Equals(a.dir, "src/lib")
            Assert.Equals(a.depth, 1)
        }

        WildcardSegments_AddDepth() {
            a := FileSystemMatcher._Anchor("src/*/*.ahk")
            Assert.Equals(a.dir, "src")
            Assert.Equals(a.depth, 2)
        }

        LeadingWildcard_HasNoFixedFolder() {
            a := FileSystemMatcher._Anchor("*/x.ahk")
            Assert.Equals(a.dir, "")
            Assert.Equals(a.depth, 2)
        }

        DoubleStar_IsUnlimited() {
            a := FileSystemMatcher._Anchor("tests/**/*.ahk")
            Assert.Equals(a.dir, "tests")
            Assert.Equals(a.depth, MAX_INT)
        }

        LiteralFile_IsDirectChildOfRoot() {
            a := FileSystemMatcher._Anchor("a.ahk")
            Assert.Equals(a.dir, "")
            Assert.Equals(a.depth, 1)
        }

        LiteralFilePath_KeepsFileOutOfFolder() {
            a := FileSystemMatcher._Anchor("src/m.ahk")
            Assert.Equals(a.dir, "src")
            Assert.Equals(a.depth, 1)
        }
    }

    class Roots {
        NoIncludes_WalksWholeTree() {
            roots := FileSystemMatcher()._Roots()
            Assert.Equals(roots.Count, 1)
            Assert.Equals(roots[""], MAX_INT)
        }

        DisjointFolders_AreKeptSeparate() {
            roots := FileSystemMatcher(["tests/*.ahk", "src/lib/*.ahk"])._Roots()
            Assert.Equals(roots.Count, 2)
            Assert.Equals(roots["tests"], 1)
            Assert.Equals(roots["src/lib"], 1)
        }

        NestedFolder_IsMergedWithDeeperDepth() {
            roots := FileSystemMatcher(["src/*.ahk", "src/lib/x/*.ahk"])._Roots()
            Assert.Equals(roots.Count, 1)
            Assert.Equals(roots["src"], 3)
        }

        NestedFolder_KeepsOuterDepthWhenLarger() {
            roots := FileSystemMatcher(["src/**", "src/lib/*.ahk"])._Roots()
            Assert.Equals(roots.Count, 1)
            Assert.Equals(roots["src"], MAX_INT)
        }

        RootPattern_AbsorbsEverything() {
            roots := FileSystemMatcher(["*.ahk", "tests/sub/*.ahk"])._Roots()
            Assert.Equals(roots.Count, 1)
            Assert.Equals(roots[""], 3)
        }

        SameFolderDifferentCase_IsMerged() {
            roots := FileSystemMatcher(["Tests/*.ahk", "tests/sub/*.ahk"])._Roots()
            Assert.Equals(roots.Count, 1)
            Assert.Equals(roots["tests"], 2)
        }

        SimilarPrefix_IsNotNested() {
            roots := FileSystemMatcher(["src/*.ahk", "srcx/*.ahk"])._Roots()
            Assert.Equals(roots.Count, 2)
        }
    }

    class Matches extends GlobFixture {
        NoPatterns_ReturnsEveryFile() {
            Assert.ArraysEqual(this.Collect(FileSystemMatcher()), GlobFixture.Sorted(GlobFixture.files))
        }

        ReturnsFullPaths() {
            matches := FileSystemMatcher(["a.ahk"]).Matches(this.root)
            Assert.ArraysEqual(matches, [this.root "\a.ahk"])
        }

        Includes_AreCombinedWithOr() {
            matches := this.Collect(FileSystemMatcher(["tests/*.test.ahk", "src/*.ahk"]))
            Assert.ArraysEqual(matches, ["src/m.ahk", "tests/x.test.ahk"])
        }

        Exclude_PrunesNamedDirectory() {
            m := SpyMatcher(["**/*.test.ahk"], ["node_modules"])
            matches := this.Collect(m)
            Assert.ArraysEqual(matches, ["tests/sub/deep/d.test.ahk", "tests/sub/z.test.ahk", "tests/x.test.ahk"])
            for dir in m.visited
                Assert.Equals(InStr(dir, "node_modules"), 0)
        }

        Exclude_WithDoubleStar_PrunesAtAnyDepth() {
            matches := this.Collect(FileSystemMatcher(["**/*.ahk"], ["**/build"]))
            for path in matches
                Assert.Equals(InStr(path, "build/"), 0)
            Assert.Equals(matches.Length, 9)
        }

        Exclude_MatchingFile_SkipsOnlyThatFile() {
            matches := this.Collect(FileSystemMatcher(["tests/*.ahk"], ["tests/y.ahk"]))
            Assert.ArraysEqual(matches, ["tests/x.test.ahk"])
        }

        DepthCap_DoesNotDescendPastPattern() {
            m := SpyMatcher(["tests/*.test.ahk"])
            Assert.ArraysEqual(this.Collect(m), ["tests/x.test.ahk"])
            Assert.ArraysEqual(m.visited, ["tests"])
        }

        DepthCap_AllowsWildcardFolders() {
            m := SpyMatcher(["src/*/*.ahk"])
            Assert.ArraysEqual(this.Collect(m), ["src/build/out.ahk", "src/lib/l.ahk"])
            Assert.ArraysEqual(GlobFixture.Sorted(m.visited), ["src", "src/build", "src/lib"])
        }

        DoubleStar_WalksWholeFixedFolder() {
            m := SpyMatcher(["tests/**"])
            matches := this.Collect(m)
            Assert.ArraysEqual(matches, ["tests/sub/deep/d.test.ahk", "tests/sub/z.test.ahk", "tests/x.test.ahk", "tests/y.ahk"])
            Assert.ArraysEqual(GlobFixture.Sorted(m.visited), ["tests", "tests/sub", "tests/sub/deep"])
        }

        FixedFolders_SkipRoot() {
            m := SpyMatcher(["tests/*.ahk", "src/lib/*.ahk"])
            Assert.ArraysEqual(this.Collect(m), ["src/lib/l.ahk", "tests/x.test.ahk", "tests/y.ahk"])
            Assert.ArraysEqual(GlobFixture.Sorted(m.visited), ["src/lib", "tests"])
        }

        NestedFolders_VisitEachDirectoryOnce() {
            m := SpyMatcher(["src/*.ahk", "src/lib/x/*.ahk"])
            Assert.ArraysEqual(this.Collect(m), ["src/lib/x/lx.ahk", "src/m.ahk"])
            Assert.ArraysEqual(GlobFixture.Sorted(m.visited), ["src", "src/build", "src/lib", "src/lib/x"])
        }

        DifferentCaseFolders_DoNotDuplicateMatches() {
            matches := this.Collect(FileSystemMatcher(["Tests/*.ahk", "tests/sub/*.ahk"]))
            Assert.Equals(matches.Length, 3)
        }

        FixedFolderUnderExclude_IsNotWalked() {
            m := SpyMatcher(["node_modules/pkg/*"], ["node_modules"])
            Assert.ArraysEqual(this.Collect(m), [])
            Assert.ArraysEqual(m.visited, [])
        }

        MissingFixedFolder_ReturnsNothing() {
            m := SpyMatcher(["nope/*.ahk"])
            Assert.ArraysEqual(this.Collect(m), [])
            Assert.ArraysEqual(m.visited, [])
        }

        RelativeRoot_ResolvesAgainstWorkingDir() {
            prev := A_WorkingDir
            SetWorkingDir(this.root)
            try matches := FileSystemMatcher(["a.ahk"]).Matches(".")
            finally SetWorkingDir(prev)
            Assert.ArraysEqual(matches, [this.root "\a.ahk"])
        }

        AddIncludeAndExclude_AfterConstruction() {
            m := FileSystemMatcher()
            m.AddInclude("tests/**/*.ahk")
            m.AddExclude("tests/sub")
            Assert.ArraysEqual(this.Collect(m), ["tests/x.test.ahk", "tests/y.ahk"])
        }
    }
}
