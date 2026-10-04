#Requires AutoHotkey v2.0

/**
 * Supports glob pattern matching. Provides utilities for compiling glob patterns to regular
 * expressions.
 */
class Glob {
    /**
     * Compile a glob pattern into a Regex pattern. Note that brace expansion (`{a,b,...}` and character classes
     * (`[a-z]`) are not supported.
     *
     * @param {String} text pattern to compile
     * @returns {String} compiled Regex
     */
    static Compile(text) {
        re := "", i := 1, len := StrLen(text)
        while i <= len {
            c := SubStr(text, i, 1)

            if SubStr(text, i, 3) = "**/" {
                re .= "(?:.*/)?"
                i += 3
            } else if SubStr(text, i, 2) = "**" {
                re .= ".*"
                i += 2
            } else {
                switch c {
                    case "*": re .= "[^/]*"
                    case "?": re .= "[^/]"
                    case "\", ".", "+", "^", "$", "|", "(", ")", "{", "}", "[", "]":
                        re .= "\" c ; these characters must be escaped
                    default:
                        re .= c
                }
                i++
            }
        }
        return "iS)^" re "$"   ; case-insensitive, like the filesystem
    }

    /**
     * Check if `text` matches glob pattern `pattern`.
     *
     * @param {String} text text to search
     * @param {String} pattern pattern to check for
     * @returns {Integer} 1 if the pattern matches, 0 if not 
     */
    static Matches(text, pattern) => !!RegExMatch(text, Glob.Compile(pattern))
}

MAX_INT := 0x7FFFFFFFFFFFFFFF

/**
 * A utility class that can find files and directories relative to some root that match
 * a set of constraints expressed as glob patterns.
 */
class FileSystemMatcher {
    __New(includes := [], excludes := []) {
        this.includes := []
        this.anchors := []
        for pattern in includes
            this.AddInclude(pattern)

        this.excludes := []
        for pattern in excludes
            this.excludes.Push(Glob.Compile(pattern))
    }

    /**
     * Add a new include pattern
     * @param {String} pattern the pattern to add
     */
    AddInclude(pattern) {
        this.includes.Push(Glob.Compile(pattern))
        this.anchors.Push(FileSystemMatcher._Anchor(pattern))
    }

    /**
     * Add a new exclude pattern
     * @param {String} pattern the pattern to add 
     */
    AddExclude(pattern) => this.excludes.Push(Glob.Compile(pattern))

    /**
     * Find all paths that match the given constraints under `root`.
     * @param {String} root the root path from which to match
     * @returns {Array<String>} all matching paths 
     */
    Matches(root := A_WorkingDir) {
        root := RTrim(FileSystemMatcher._Expand(root), "\/")
        matches := []
        for base, depth in this._Roots() {
            if this._IsBaseExcluded(base)
                continue
            dir := base = "" ? root : root "\" StrReplace(base, "/", "\")
            if DirExist(dir)
                this._Walk(dir, base, depth, matches)
        }
        return matches
    }

    /**
     * Whether a single path matches the patterns
     * @param {String} path path to check 
     * @returns {Number} 1 if a match, 0 otherwise
     */
    PathMatches(path) => this._IsIncluded(path) && !this._IsExcluded(path)

    /**
     * Recursively walk `dir`, pushing matching files onto `matches`. Directories matching an
     * exclude pattern are pruned without being entered.
     * 
     * @param {String} dir absolute path of the directory to walk
     * @param {String} rel path of `dir` relative to the root, using "/" separators
     * @param {Integer} depth how many levels below `dir` files may match; 1 means only its
     *     direct children
     * @param {Array<String>} matches output array
     */
    _Walk(dir, rel, depth, matches) {
        loop files dir "\*", depth > 1 ? "DF" : "F" {
            path := rel = "" ? A_LoopFileName : rel "/" A_LoopFileName
            if this._IsExcluded(path)
                continue

            if InStr(A_LoopFileAttrib, "D") {
                this._Walk(A_LoopFileFullPath, path, depth - 1, matches)
            } else if this._IsIncluded(path) {
                matches.Push(A_LoopFileFullPath)
            }
        }
    }

    /**
     * Split an include pattern into its fixed folder (the leading directory segments with no
     * wildcards) and the number of levels below that folder it can match. Patterns containing
     * `**` can match at any depth.
     *
     * @param {String} pattern glob pattern
     * @returns {Object} `{dir, depth}`
     */
    static _Anchor(pattern) {
        segments := StrSplit(pattern, "/")
        base := "", i := 1
        while i < segments.Length && !RegExMatch(segments[i], "[*?]") {
            base .= (base = "" ? "" : "/") segments[i]
            i++
        }
        depth := InStr(pattern, "**") ? MAX_INT : segments.Length - i + 1
        return {dir: base, depth: depth}
    }

    /**
     * Find the folders to start walking from. Anchors nested inside another anchor's folder are
     * merged into it, so that each file is visited at most once.
     * 
     * This prevents us from considering folders that can't ever have matches, e.g. a glob like
     * `tests/*.ahk` from this project's git root can never match `text/SemVer.ahk`. With a little
     * work up front we can prove we don't even have to look in `text/`.
     *
     * @returns {Map<String, Integer>} map of fixed folder => depth to walk
     */
    _Roots() {
        IsUnder(path, base) => base = "" || path = base || SubStr(path, 1, StrLen(base) + 1) = base "/"
        Count(path) => path = "" ? 0 : StrSplit(path, "/").Length

        anchors := this.includes.Length ? this.anchors : [{dir: "", depth: MAX_INT}]

        roots := Map(), roots.CaseSense := "Off"
        for a in anchors {
            top := a.dir
            for b in anchors {
                if StrLen(b.dir) < StrLen(top) && IsUnder(a.dir, b.dir)
                    top := b.dir
            }
            depth := a.depth = MAX_INT ? MAX_INT : a.depth + Count(a.dir) - Count(top)
            roots[top] := Max(roots.Get(top, 0), depth)
        }
        return roots
    }

    /**
     * Check whether a fixed folder, or any folder above it, is excluded.
     *
     * @param {String} base relative folder path
     * @returns {Integer} 1 if excluded, 0 if not
     */
    _IsBaseExcluded(base) {
        if base = ""
            return false

        prefix := ""
        for segment in StrSplit(base, "/") {
            prefix .= (prefix = "" ? "" : "/") segment
            if this._IsExcluded(prefix)
                return true
        }

        return false
    }

    static _Expand(path) {
        cc := DllCall("GetFullPathNameW", "str", path, "uint", 0, "ptr", 0, "ptr", 0, "uint")
        buf := Buffer(cc*2)
        DllCall("GetFullPathNameW", "str", path, "uint", cc, "ptr", buf.ptr, "ptr", 0)
        return StrGet(buf)
    }

    _IsIncluded(path) {
        if !this.includes.Length
            return true

        for pattern in this.includes {
            if RegExMatch(path, pattern)
                return true
        }

        return false
    }

    _IsExcluded(path) {
        for pattern in this.excludes {
            if RegExMatch(path, pattern)
                return true
        }

        return false
    }
}