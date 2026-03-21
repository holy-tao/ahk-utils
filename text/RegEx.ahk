/**
 * Provides utility methods for regular expressions beyond those available
 * via the built-ins.
 */
class RegEx {
    /**
     * Searches an input string for all occurrences of a regular expression and returns all the matches.
     * @param {String} haystack the string to search 
     * @param {String} pattern the regular expression to evaluate
     * @returns {Array<String>} all substrings of `haystack` which match `pattern` 
     */
    static Matches(haystack, pattern) {
        out := Array()
        match := "", pos := 1
        while RegExMatch(haystack, pattern, &match, pos) {
            out.Push(match[0])
            pos := match.Pos + match.Len
        }

        return out
    }

    /**
     * Splits an input string into an array of substrings at the positions defined by a specified regular expression 
     * pattern.
     * 
     * If no matches are found, the returned array contains the input string as its only element.
     * 
     * @param {String} haystack the string to search 
     * @param {String} pattern the regular expression to evaluate. This expression should match the *delimiters* that
     *          you want to split at, not the elements you want to return. Use {@link RegEx.Matches} for that.
     * @returns {Array<String>} a String array
     */
    static Split(haystack, pattern) {
        out := Array()
        match := "", pos := 1
        while RegExMatch(haystack, pattern, &match, pos) {
            out.Push(SubStr(haystack, pos, match.Pos - pos))
            pos := match.Pos + match.Len
        }

        out.Push(SubStr(haystack, pos))

        return out
    }
}