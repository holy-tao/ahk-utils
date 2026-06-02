#Requires AutoHotkey v2.0

/**
 * Respresents a Gregorian calendar date and time, and provides utilities for working with them and for converting
 * between the AHK {@link https://www.autohotkey.com/docs/v2/lib/FileSetTime.htm#YYYYMMDD `YYYYMMDDHH24MISS`} format
 * and the {@link https://www.iso.org/iso-8601-date-and-time-format.html ISO-8061} format.
 *
 * Values are either *naive* (no zone information) or *zoned* (carry an integer offset in minutes from UTC,
 * where `0` means UTC). Naive values cannot be safely compared across systems or converted between zones —
 * resolve them at the boundary with {@link DateTime.Prototype.AssumeLocal} or
 * {@link DateTime.Prototype.AssumeUTC} when the caller knows the intended zone.
 */
class DateTime {

    /**
     * Get a `DateTime` representing the current local time, with the process's UTC offset attached.
     * @returns {DateTime} the current local time
     */
    static Now() => DateTime(A_Year, A_Mon, A_MDay, A_Hour, A_Min, A_Sec, A_MSec, DateTime.LocalOffsetMinutes())

    /**
     * Get a `DateTime` representing the current UTC time.
     * @returns {DateTime} the current UTC time
     */
    static NowUTC() => DateTime.FromAHK(A_NowUTC, 0)

    /**
     * The process's current offset from UTC, in minutes. Positive east of UTC.
     * @returns {Integer}
     */
    static LocalOffsetMinutes() => DateDiff(A_Now, A_NowUTC, "Minutes")

    /**
     * Parse a `YYYYMMDDHH24MISS` timestamp. AHK strings carry no offset information, so the result is
     * naive by default; pass `offsetMinutes` (or call {@link DateTime.Prototype.AssumeLocal} /
     * {@link DateTime.Prototype.AssumeUTC} afterwards) when you know the time zone.
     *
     * @param {String} timestamp the `YYYYMMDDHH24MISS` timestamp to parse
     * @param {Integer} [offsetMinutes] offset from UTC in minutes, or unset for a naive value
     */
    static FromAHK(timestamp, offsetMinutes?) {
        if !(timestamp is String)
            throw TypeError("Expected a String but got a(n) " Type(timestamp), -1, timestamp)

        if !IsTime(timestamp)
            throw ValueError("Not a valid YYYYMMDDHH24MISS timestamp", -1, timestamp)

        ; AHK conventionally allows timestamps to be incomplete, defaulting unset values to 0,
        ; we also allow this.
        return DateTime(
            (year := SubStr(timestamp, 1, 4)) == "" ? 0 : year,
            (month := SubStr(timestamp, 5, 2)) == "" ? 0 : month,
            (day := SubStr(timestamp, 7, 2)) == "" ? 0 : day,
            (hours := SubStr(timestamp, 9, 2)) == "" ? 0 : hours,
            (mins := SubStr(timestamp, 11, 2)) == "" ? 0 : mins,
            (secs := SubStr(timestamp, 13, 2)) == "" ? 0 : secs,
            0,
            offsetMinutes?
        )
    }

    /**
     * Parse an ISO-8601 timestamp. The offset is taken from the input: `Z` produces a UTC value (offset 0),
     * `±HH:MM` (or `±HHMM` / `±HH`) produces a value with that offset, and no suffix produces a naive value.
     *
     * The time portion is optional (date-only input is allowed), and either `T` or a space may separate
     * date and time. Fractional seconds (any precision) are accepted; precision beyond milliseconds is
     * truncated.
     *
     * @param {String} timestamp
     */
    static FromISO(timestamp) {
        if !(timestamp is String)
            throw TypeError("Expected a String but got a(n) " Type(timestamp), -1, timestamp)

        static pattern := "^(\d{4})-(\d{2})-(\d{2})(?:[Tt ](\d{2}):(\d{2})(?::(\d{2})([\.\,]\d+)?)?([Zz]|[+\-]\d{2}:?\d{2}|[+\-]\d{2})?)?$"
        if !RegExMatch(timestamp, pattern, &m)
            throw ValueError("Not a valid ISO-8601 timestamp", -1, timestamp)

        ms := 0
        if m[7] != "" {
            ; Drop the leading dot, then pad/truncate to exactly 3 digits.
            frac := SubStr(m[7], 2)
            ms := Integer(SubStr(frac . "000", 1, 3))
        }

        year := Integer(m[1]), month := Integer(m[2]), day := Integer(m[3])
        hours := m[4] == "" ? 0 : Integer(m[4])
        minutes := m[5] == "" ? 0 : Integer(m[5])
        seconds := m[6] == "" ? 0 : Integer(m[6])
        offset := DateTime._ParseISOOffset(m[8])

        ; A seconds value of 60 is only valid as a positive leap second. Validate it against the
        ; historical record, then store it directly (the constructor's 0-59 guard would reject it).
        if seconds == 60 {
            DateTime._ValidateLeapSecond(year, month, day, hours, minutes, offset)
            dt := DateTime(year, month, day, hours, minutes, 59, ms, offset)
            dt.seconds := 60
            return dt
        }

        return DateTime(year, month, day, hours, minutes, seconds, ms, offset)
    }

    /**
     * Validate that a parsed `:60` seconds field denotes a real inserted leap second. Positive leap
     * seconds only ever occur at `23:59:60` UTC on a date where the IERS actually inserted one, so
     * anything else (wrong time-of-day, non-UTC zone, or an unused/bogus date) is rejected.
     *
     * The table below is the complete list of positive leap seconds through 2016-12-31 (the most
     * recent as of 2026); none have been scheduled since. Extend it if the IERS inserts another.
     */
    static _ValidateLeapSecond(year, month, day, hours, minutes, offsetMinutes) {
        static leapDates := Map(
            "1972-06-30", 1, "1972-12-31", 1, "1973-12-31", 1, "1974-12-31", 1, "1975-12-31", 1,
            "1976-12-31", 1, "1977-12-31", 1, "1978-12-31", 1, "1979-12-31", 1, "1981-06-30", 1,
            "1982-06-30", 1, "1983-06-30", 1, "1985-06-30", 1, "1987-12-31", 1, "1989-12-31", 1,
            "1990-12-31", 1, "1992-06-30", 1, "1993-06-30", 1, "1994-06-30", 1, "1995-12-31", 1,
            "1997-06-30", 1, "1998-12-31", 1, "2005-12-31", 1, "2008-12-31", 1, "2012-06-30", 1,
            "2015-06-30", 1, "2016-12-31", 1)

        date := Format("{1:04}-{2:02}-{3:02}", year, month, day)
        if offsetMinutes != 0 || hours != 23 || minutes != 59 || !leapDates.Has(date)
            throw ValueError("Second value 60 is only valid as an inserted UTC leap second", -1,
                date "T" Format("{1:02}:{2:02}:60", hours, minutes))
    }

    /**
     * Convert an ISO-8601 offset suffix (`Z`, `±HH:MM`, `±HHMM`, `±HH`, or empty) to a minute count.
     * Returns `""` (the naive sentinel) for an empty input.
     */
    static _ParseISOOffset(suffix) {
        if suffix == ""
            return ""
        if suffix = "Z"
            return 0

        sign := SubStr(suffix, 1, 1) == "-" ? -1 : 1
        digits := StrReplace(SubStr(suffix, 2), ":")
        hours := Integer(SubStr(digits, 1, 2))
        mins := StrLen(digits) >= 4 ? Integer(SubStr(digits, 3, 2)) : 0
        if hours > 23 || mins > 59
            throw ValueError("UTC offset out of range - must be within ±24:00", -1, suffix)
        return sign * (hours * 60 + mins)
    }

    /**
     * Get the number of days in `month` month of `year` year.
     * 
     * @param {Integer} year the year of the month
     * @param {Integer} month the month
     * @returns {Integer} the number of days in the month
     */
    static DaysInMonth(year, month) {
        if month == 2
            return DateTime.IsLeapYear(year) ? 29 : 28

        static days := [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
        return days[month]
    }

    /**
     * Check if the given year is a leap year.
     * 
     * Leap years are years divisible by four but not 100, unless they are also divisble by 400.
     * @param {Integer} year the year 
     * @returns {Boolean} 1 if the year is a leap year, 0 if not 
     */
    static IsLeapYear(year) {
        year := Integer(year)
        return (Mod(year, 4) == 0) && ((Mod(year, 100) != 0) || (Mod(year, 400) == 0))
    }

    /**
     * Whether the value carries no offset information. Naive values cannot be safely compared to or
     * converted between zones until resolved via {@link DateTime.Prototype.AssumeLocal `AssumeLocal`},
     * {@link DateTime.Prototype.AssumeUTC `AssumeUTC`}, or {@link DateTime.Prototype.AssumeOffset `AssumeOffset`}.
     * @type {Boolean}
     */
    isNaive => !IsInteger(this.offsetMinutes)

    /**
     * Whether the time is in {@link https://en.wikipedia.org/wiki/Coordinated_Universal_Time UTC}.
     * A naive value is not UTC — its zone is unknown.
     * @type {Boolean}
     */
    isUTC => !this.isNaive && this.offsetMinutes == 0

    /**
     * Whether the date is in a leap year
     * @type {Boolean}
     */
    isLeapYear => DateTime.IsLeapYear(this.year)

    /**
     * The number of days in the date's month, taking into account leap years
     * @type {Integer}
     */
    daysInMonth => DateTime.DaysInMonth(this.year, this.month)

    /**
     * Create a new DateTime from its component parts
     * 
     * @param {Integer} year the year part
     * @param {Integer} month the month part
     * @param {Integer} day the day part
     * @param {Integer} hours the hours
     * @param {Integer} minutes the minutes
     * @param {Integer} seconds the seconds
     * @param {Integer} milliseconds the milliseconds
     * @param {Integer | String} offsetMinutes the offset minutes - this determines the DateTime's
     *          time zone. Leave unset to create a "naive" DateTime which does not carry time zone
     *          information
     */
    __New(year := 0, month := 1, day := 1, hours := 0, minutes := 0, seconds := 0, milliseconds := 0, offsetMinutes := "") {
        this.year := DateTime._ValidateRange(year, 0, 9999, "year")
        this.month := DateTime._ValidateRange(month, 1, 12, "month")
        this.day := DateTime._ValidateRange(day, 1, DateTime.DaysInMonth(year, month), "days")

        this.hours := DateTime._ValidateRange(hours, 0, 23, "hours")
        this.minutes := DateTime._ValidateRange(minutes, 0, 59, "minutes")
        this.seconds := DateTime._ValidateRange(seconds, 0, 59, "seconds")
        this.milliseconds := DateTime._ValidateRange(milliseconds, 0, 999, "milliseconds")
        this.offsetMinutes := offsetMinutes
    }

    static _ValidateRange(num, min, max, label) {
        if !IsInteger(num)
            throw TypeError("Expected an Integer but got a(n) " Type(num), -2, num)

        if num < min || num > max
            throw ValueError(Format("Invalid {1} - must be {2} - {3} (inclusive)", label, min, max), -2, num)

        return Integer(num)
    }

    /**
     * Return a copy of this value stamped with the process's current local offset. Throws if the value
     * is already zoned — use {@link DateTime.Prototype.WithOffset} to convert instead.
     * @returns {DateTime}
     */
    AssumeLocal() => this.AssumeOffset(DateTime.LocalOffsetMinutes())

    /**
     * Return a copy of this value stamped as UTC. Throws if the value is already zoned.
     * @returns {DateTime}
     */
    AssumeUTC() => this.AssumeOffset(0)

    /**
     * Return a copy of this value stamped with the given offset. Throws if the value is already zoned.
     * @param {Integer} offsetMinutes
     * @returns {DateTime}
     */
    AssumeOffset(offsetMinutes) {
        if !this.isNaive
            throw Error("DateTime already has an offset; use WithOffset() to convert zones", -1)
        return DateTime(this.year, this.month, this.day, this.hours, this.minutes, this.seconds,
            this.milliseconds, offsetMinutes)
    }

    /**
     * Convert this value to the given offset, shifting the wall-clock fields accordingly. Throws if the
     * value is naive — resolve it first with {@link DateTime.Prototype.AssumeLocal} or
     * {@link DateTime.Prototype.AssumeUTC}.
     * @param {Integer} offsetMinutes
     * @returns {DateTime}
     */
    WithOffset(offsetMinutes) {
        if this.isNaive
            throw Error("Cannot convert a naive DateTime; call AssumeLocal/AssumeUTC first", -1)
        new := this.AddMinutes(offsetMinutes - this.offsetMinutes)
        new.offsetMinutes := offsetMinutes
        return new
    }

    /**
     * Return a copy advanced by `years` years. The offset (if any) is preserved. If the source day is
     * Feb 29 and the target year is not a leap year, the day is clamped to Feb 28.
     * @param {Integer} years may be negative
     */
    AddYears(years) {
        new := this.Clone()
        new.year := DateTime._ValidateRange(new.year + years, 0, 9999, "year")
        maxDay := DateTime.DaysInMonth(new.year, new.month)
        if new.day > maxDay
            new.day := maxDay
        return new
    }

    /**
     * Return a copy advanced by `months` months. The offset (if any) is preserved. If the source day
     * does not exist in the target month (e.g. Jan 31 + 1mo), the day is clamped to the last day of
     * the target month.
     * @param {Integer} months may be negative
     */
    AddMonths(months) {
        new := this.Clone()
        m := new.month + months
        while m > 12 {
            m -= 12
            new.year += 1
        }
        while m < 1 {
            m += 12
            new.year -= 1
        }
        new.year := DateTime._ValidateRange(new.year, 0, 9999, "year")
        new.month := m
        maxDay := DateTime.DaysInMonth(new.year, new.month)
        if new.day > maxDay
            new.day := maxDay
        return new
    }

    AddDays(days) => this._AddAndNormalize("day", days)
    AddHours(hrs) => this._AddAndNormalize("hours", hrs)
    AddMinutes(mins) => this._AddAndNormalize("minutes", mins)
    AddSeconds(secs) => this._AddAndNormalize("seconds", secs)
    AddMilliseconds(ms) => this._AddAndNormalize("milliseconds", ms)

    _AddAndNormalize(field, amount) {
        new := this.Clone()
        new.%field% += amount
        DateTime.Normalize(new)
        return new
    }

    /**
     * Cascade out-of-range field values up through coarser units. For example, if `month` is 13,
     * `year` is advanced by one and `month` is reset to 1.
     * 
     * Operates in place. The caller is expected to keep the offset (if any) untouched.
     */
    static Normalize(dt) {
        ; ms -> s -> min -> hr -> day cascade (fixed bases)
        for spec in [["milliseconds", "seconds", 1000], ["seconds", "minutes", 60],
                     ["minutes", "hours", 60], ["hours", "day", 24]] {
            v := dt.%spec[1]%
            carry := v // spec[3]
            v := Mod(v, spec[3])
            if v < 0 {
                v += spec[3]
                carry -= 1
            }
            dt.%spec[1]% := v
            dt.%spec[2]% += carry
        }
        ; day -> month -> year (variable month lengths)
        while dt.day > (dim := DateTime.DaysInMonth(dt.year, dt.month)) {
            dt.day -= dim
            if ++dt.month > 12 {
                dt.month := 1
                dt.year += 1
            }
        }
        while dt.day < 1 {
            if --dt.month < 1 {
                dt.month := 12
                dt.year -= 1
            }
            dt.day += DateTime.DaysInMonth(dt.year, dt.month)
        }
        DateTime._ValidateRange(dt.year, 0, 9999, "year")
    }

    /**
     * Convert the time to {@link https://www.autohotkey.com/docs/v2/lib/FileSetTime.htm#YYYYMMDD `YYYYMMDDHH24MISS`} format.
     * Offset information and milliseconds are dropped.
     * @returns {String} the datetime in `YYYYMMDDHH24MISS` format
     */
    ToAHK() => Format("{1:04}{2:02}{3:02}{4:02}{5:02}{6:02}",
        this.year, this.month, this.day, this.hours, this.minutes, this.seconds)

    /**
     * Convert the time to ISO-8601. UTC values get a `Z` suffix, zoned values get `±HH:MM`, and naive
     * values get no suffix.
     * @returns {String}
     */
    ToISO() {
        base := Format("{1:04}-{2:02}-{3:02}T{4:02}:{5:02}:{6:02}",
            this.year, this.month, this.day, this.hours, this.minutes, this.seconds)
        if this.milliseconds > 0
            base .= Format(".{:03}", this.milliseconds)

        if this.isNaive
            return base
        if this.isUTC
            return base "Z"

        sign := this.offsetMinutes < 0 ? "-" : "+"
        absMin := Abs(this.offsetMinutes)
        return base . Format("{1}{2:02}:{3:02}", sign, absMin // 60, Mod(absMin, 60))
    }

    /**
     * Returns a string representation of the DateTime.
     * 
     * @param {String} format the format. Pass "AHK" or "ISO" to convert to the specified format,
     *          otherwise provide any {@link https://www.autohotkey.com/docs/v2/lib/FormatTime.htm `FormatTime`}
     *          format string. Leave unset or pass the empty string to use "Longdate"
     * @returns {String} the string representation
     */
    ToString(format := "") {
        ; Case-insensitive comparison. Switching on format itself would be case-sensitive
        switch true {
            case format = "AHK":
                return this.ToAHK()
            case format = "ISO":
                return this.ToISO()
            default:
                return FormatTime(this.ToAHK(), format)
        }
    }
}