#Requires AutoHotkey v2.0

/**
 * Encapsulates a span of time.
 *
 * Internally, time is always measured in seconds, and other properties simply
 * compute their values based on `totalSeconds`. This decision was made to support
 * easy interop with `QueryPerformanceCounter`, which similarly uses seconds.
 */
class Timespan {
   
    /**
     * The total number of elapsed days (with fractional part)
     * @type {Float}
     */
    totalDays => this.totalSeconds / 86400.0

    /**
     * The total number of elapsed hours (with fractional part)
     * @type {Float}
     */
    totalHours => this.totalSeconds / 3600.0

    /**
     * The total number of elapsed minutes (with fractional part)
     * @type {Float}
     */
    totalMinutes => this.totalSeconds / 60.0

    /**
     * The total number of elapsed seconds (with fractional part)
     * @type {Float}
     */
    totalSeconds := unset

    /**
     * The total number of elapsed milliseconds (with fractional part)
     * @type {Float}
     */
    totalMilliseconds => this.totalSeconds * 1000.0

    /**
     * The number of elapsed days without fractional part
     * @type {Integer}
     */
    days => Floor(this.totalDays)

    /**
     * The number of elapsed hours without fractional part
     * @type {Integer}
     */
    hours => Floor(this.totalHours)

    /**
     * The number of elapsed minutes without fractional part
     * @type {Integer}
     */
    minutes => Floor(this.totalMinutes)

    /**
     * The number of elapsed seconds without fractional part
     * @type {Integer}
     */
    seconds => Floor(this.totalSeconds)

    /**
     * The number of elapsed milliseconds without fractional part
     * @type {Integer}
     */
    milliseconds => Floor(this.totalMilliseconds)

    /**
     * Creates a timespan from a number of days
     * @param {Float} days - The number of days
     * @returns {Timespan}
     */
    static OfDays(days) => Timespan(days * 86400.0)

    /**
     * Creates a Timespan from a number of hours
     * @param {Float} hrs - The number of hours
     * @returns {Timespan}
     */
    static OfHours(hrs) => Timespan(hrs * 3600.0)

    /**
     * Creates a Timespan from a number of minutes
     * @param {Float} mins - The number of minutes
     * @returns {Timespan}
     */
    static OfMinutes(mins) => Timespan(mins * 60.0)

    /**
     * Creates a Timespan from a number of seconds
     * @param {Float} seconds - The number of seconds
     * @returns {Timespan}
     */
    static OfSeconds(seconds) => Timespan(seconds)

    /**
     * Creates a Timespan from a number of milliseconds
     * @param {Float} ms - The number of milliseconds
     * @returns {Timespan}
     */
    static OfMilliseconds(ms) => Timespan(ms / 1000.0)

    /**
     * Creates a new Timespan
     * @param {Float} seconds - The total number of seconds in this timespan
     */
    __New(seconds) {
        this.totalSeconds := seconds
    }

    /**
     * Returns the elapsed time in the format hh:mm:ss
     * @returns {String}
     */
    ToString() {
        totalSecs := Floor(this.totalSeconds)
        hrs := Floor(totalSecs / 3600)
        mins := Floor(Mod(totalSecs, 3600) / 60)
        secs := Mod(totalSecs, 60)
        return Format("{1:02d}:{2:02d}:{3:02d}", hrs, mins, secs)
    }
}