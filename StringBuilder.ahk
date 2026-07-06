#Requires AutoHotkey v2.0

; NOTE: .NET StringBuilders uses chunks. I think this is fine for now, but maybe worth looking into.

/**
 * An efficient way to build potentially large strings. A `StringBuilder` allocates a single contiguous
 * buffer and append strings to it by copying their bytes in exactly once. Normally, AHK strings are
 * copied when passed between or returned from functions - a `StringBuilder` allows you to minimize the
 * amount of copies involved. This is most efficient when repeatedly concatenating strings or working
 * with very large strings. A `StringBuilder` also allows you to *pass* references to very large strings
 * around without copying them.
 */
class StringBuilder {
    /** @type {Buffer} */
    _buf := ""
    _offset := 0

    /** 
     * The string appended by {@link StringBuilder.Prototype.AppendLine `AppendLine`}.
     */
    NewLine := "`n"

    /**
     * Create a new `StringBuilder`
     * @param {Integer} capacity the initial capacity to allocate, in characters. Pre-sizing avoids
     *   repeated reallocations when the eventual size is roughly known.
     * @param {String} newLine the string to use for {@link StringBuilder.Prototype.AppendLine `AppendLine`}
     */
    __New(capacity := 16, newLine := "`r`n") {
        this._buf := Buffer(Max(capacity, 1) * 2, 0)
        this.NewLine := newLine
    }

    /**
     * The current length of the contents, in characters.
     * @type {Integer}
     */
    Length => this._offset // 2

    /**
     * The current capacity of the internal buffer, in characters.
     * @type {Integer}
     */
    Capacity => this._buf.Size // 2

    /**
     * Append a value to the `StringBuilder`. Numbers are coerced to strings. To avoid copying a very
     * large string into this method's parameter, use {@link StringBuilder.Prototype.AppendRef `AppendRef`}
     * instead.
     *
     * @param {String} str the value to append
     * @returns {StringBuilder} `this`, for chaining
     */
    Append(str) => this._Append(&str)

    /**
     * Append a string to the `StringBuilder` by reference, avoiding the copy that passing by value
     * incurs. Prefer this over {@link StringBuilder.Prototype.Append `Append`} for very large strings.
     *
     * @param {VarRef<String>} str a reference to the string to append
     * @returns {StringBuilder} `this`, for chaining
     */
    AppendRef(&str) => this._Append(&str)

    _Append(&str) {
        if (chars := StrLen(str)) == 0
            return this

        this.Reserve(size := chars * 2)
        
        StrPut(str, this._buf.ptr + this._offset, chars, "UTF-16")
        this._offset += size
        return this
    }

    /**
     * Append a value (if given) followed by {@link StringBuilder#NewLine}.
     *
     * @param {String} str the value to append before the newline
     * @returns {StringBuilder} `this`, for chaining
     */
    AppendLine(str := "") {
        nl := this.NewLine
        this._Append(&str)
        return this._Append(&nl)
    }

    /**
     * Append a string a certain number of times
     *
     * @param {String} str the string to append
     * @param {Integer} times the number of times to append it
     * @returns {StringBuilder} `this`, for chaining
     */
    AppendRepeat(str, times) {
        loop times
            this._Append(&str)
        return this
    }

    /**
     * Read the contents of the `StringBuilder` back into a string
     * @returns {String} the contents of the `StringBuilder`
     */
    ToString() => StrGet(this._buf.ptr, this._offset // 2, "UTF-16")

    /**
     * Clear the contents of the `StringBuilder`
     * @returns {StringBuilder} `this`, for chaining
     */
    Clear() {
        this._offset := 0
        return this
    }

    /**
     * Ensure that the `StringBuilder`'s internal buffer has at least enough space for `bytes` more bytes
     *
     * @param {integer} bytes the number of **bytes** to reserve
     * @returns {Integer} the `StringBuilder`'s capacity in bytes after any resizing
     */
    Reserve(bytes) {
        needed := this._offset + bytes
        if (needed <= this._buf.Size)
            return this._buf.Size

        newSize := this._buf.Size
        while (newSize < needed)
            newSize *= 2
        this._buf.Size := newSize
        return this._buf.Size
    }
}
