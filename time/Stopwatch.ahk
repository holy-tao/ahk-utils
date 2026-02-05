#Requires AutoHotkey v2.0
#Include Timespan.ahk

/**
 * A Stopwatch is used to produce high-resolution time measurements for e.g. performance testing
 * @see {@link https://learn.microsoft.com/en-us/windows/win32/sysinfo/acquiring-high-resolution-time-stamps Acquiring high-resolution time stamps - Win32 apps | Microsoft Learn}
 * @author Tao Beloney
 */
class Stopwatch {

    /**
     * The frequency of the performance counter in counts per second
     * @type {Integer}
     */
    static frequency := 0

    /**
     * @private the tick count at the time the stopwatch started
     * @type {Integer}
     */
    _startTime := 0

    /**
     * @private accumulated ticks when the stopwatch is stopped
     * @type {Integer}
     */
    _elapsedTicks := 0

    /**
     * @private whether the stopwatch is currently running
     * @type {Boolean}
     */
    _isRunning := false

    /**
     * Gets whether the stopwatch is currently running
     * @type {Boolean}
     */
    IsRunning => this._isRunning

    /**
     * Starts and returns a new Stopwatch
     * @returns {Stopwatch}
     */
    static StartNew() {
        watch := Stopwatch()
        watch.Start()
        return watch
    }

    /**
     * Grabs the performance frequency on startup
     */
    static __New(){
        DllCall("QueryPerformanceFrequency", "Int64*", &freq := 0)
        Stopwatch.frequency := freq
        this.DeleteProp("__New")
    }

    /**
     * Starts the stopwatch. If already running, does nothing.
     * Use {@link Restart `Restart()`} to reset and start again.
     */
    Start() {
        if (!this._isRunning) {
            DllCall("QueryPerformanceCounter", "Int64*", &counter := 0)
            this._startTime := counter
            this._isRunning := true
        }
    }

    /**
     * Stops the stopwatch and captures the elapsed time.
     * If not running, does nothing.
     */
    Stop() {
        if (this._isRunning) {
            DllCall("QueryPerformanceCounter", "Int64*", &counter := 0)
            this._elapsedTicks += (counter - this._startTime)
            this._isRunning := false
        }
    }

    /**
     * Resets the stopwatch to zero without starting it
     */
    Reset() {
        this._elapsedTicks := 0
        this._startTime := 0
        this._isRunning := false
    }

    /**
     * Resets the stopwatch and immediately starts it
     */
    Restart() {
        this.Reset()
        this.Start()
    }

    /**
     * Returns a {@link Timespan `Timespan`} representing the amount of time measured by this stopwatch.
     * If running, returns the time elapsed since started plus any previously accumulated time.
     * If stopped, returns the captured elapsed time.
     *
     * @returns {Timespan} The total elapsed time
     */
    Elapsed() {
        totalTicks := this._elapsedTicks
        if (this._isRunning) {
            DllCall("QueryPerformanceCounter", "Int64*", &counter := 0)
            totalTicks += (counter - this._startTime)
        }
        return Timespan.OfSeconds(totalTicks / Stopwatch.frequency)
    }

    /**
     * Returns the elapsed time as a String
     * @returns {String}
     */
    ToString() {
        return this.Elapsed().ToString()
    }

    /**
     * Times the execution of a function and returns the elapsed time. The return value
     * or thrown error of the function can be accessed via `output`
     *
     * @param {Func() => Any} fn The function to time
     * @param {VarRef<Any>} output An optional output variable which receives either
     *          the return value or thrown error of `fn`.
     * @returns {Timespan} A {@link Timespan `Timespan`} for the execution time of `fn`.
     */
    static TimeFunc(fn, &output := "") {
        watch := Stopwatch.StartNew()
        try {
            output := fn.Call()
            return watch.Elapsed()
        }
        catch Any as thrown {
            output := thrown
            return watch.Elapsed()
        }
    }
}

;@Ahk2Exe-IgnoreBegin
if(A_ScriptName == "Stopwatch.ahk") {
    elapsed := Stopwatch.TimeFunc((*) => MsgBox("Close me to stop the timer!"))
    MsgBox("Took " String(elapsed) "`nSeconds: " elapsed.seconds "`nMilliseconds: " elapsed.milliseconds "`nTotal Seconds: " elapsed.totalSeconds)
}
;@Ahk2Exe-IgnoreEnd
