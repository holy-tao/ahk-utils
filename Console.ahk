/**
 * Provides utilities for interacting with the attached console. By default, AHK scripts have no attached console,
 * and may not have stdio streams at all (or may only have a subset of the expected three). Scripts compiled with
 * the {@link https://www.autohotkey.com/docs/alpha/misc/Ahk2ExeDirectives.htm#ConsoleApp `ConsoleApp`} directive
 * always have all three expected streams.
 * 
 * You can create a console on one of two ways:
 * 1. By attaching to an existing process's console (by default, the AHK process's parent):
 *      
 *          Console.Attach()
 *          Console.Attach(WinGetPID("target")) ; Specify a PID to attach to their console
 *      If the script was compiled with `ConsoleApp`, calling `Attach()` simply sets up the utilities to work
 *      with the default stdio streams.
 * 
 * 2. By creating a new console. This opens a window:
 * 
 *          Console.Create()
 * 
 * This gives you access to three {@link https://www.autohotkey.com/docs/v2/lib/File.htm `File`} objects which you can
 * use to interact with the console:
 * 
 *          Console.Out.WriteLine("Hello, World!")
 *          Console.Err.WriteLine(err.Message)
 * 
 *          ; Note that blocking reads on shared consoles are generally a bad idea
 *          input := Console.In.ReadLine()
 * 
 * AHK file streams are *not* flushed automatically. `Console` will make a best-effort attempt to flush them when
 * your script exits, or you can manually flush them by calling the polyfilled `Flush` method:
 * 
 *          Console.Out.Flush()
 */
class Console {

    /**
     * The Console's currently attached StdIn stream
     * @type {File}
     */
    static In := 0

    /**
     * The Console's currently attached StdOut stream
     * @type {File}
     */
    static Out := 0

    /**
     * The Console's currently attached StdErr stream
     * @type {File}
     */
    static Err := 0

    static Hwnd => DllCall("GetConsoleWindow", "ptr")

    /**
     * @type {String} 0x1b as a string - used to start escape sequences
     */
    static Escape => Chr(0x1B)

    static __New() {
        ; Best-effort, detach from the console on script exit
        OnExit((*) => Console.Detach())
    }

    /**
     * Attach to another process's console. By default, attaches to the parent process's console. If the script
     * was compiled with the {@link https://www.autohotkey.com/docs/alpha/misc/Ahk2ExeDirectives.htm#ConsoleApp `ConsoleApp`}
     * directive, this method simply sets up the stdio handles in the `Console` class.
     * 
     * Because the AHK interpreter is not a console app, shells won't wait for your script when running without
     * having been compiled with the `ConsoleApp` directive. Blocking reads in this state are generally unsafe - you
     * should prefer to create a new console in this case.
     * 
     * @param {Integer} pid The PID of the console to attach to
     */
    static Attach(pid := -1) {
        if !Console.HasConsole() {
            if !DllCall("AttachConsole", "int", pid, "char")
                throw OSError()
        }
        Console._InitStreams(false)
    }

    /**
     * Create a new console window and redirects stdio streams to it.
     */
    static Create() {
        ; https://learn.microsoft.com/en-us/windows/console/allocconsole
        ; TODO use AllocConsoleWithOptions and provide options
        if !DllCall("AllocConsole")
            throw OSError()

        Console._InitStreams(true)
    }

    /**
     * Attach to the script's parent process's console if it has one, otherwise create a new
     * console.
     */
    static AttachOrCreate() {
        try {
            Console.Attach()
            return
        }
        catch OSError {
            Console.Create()
        }
    }

    /**
     * Detach from the current console
     */
    static Detach() {
        for val in [Console.In, Console.Out, Console.Err] {
            if val is File {
                if !DllCall("CloseHandle", "ptr", val.Handle, "char")
                    throw OSError()
            }
        }

        Console.In := "", Console.Out := "", Console.Err := ""

        if Console.HasConsole() {
            if !DllCall("FreeConsole", "char")
                throw OSError()
        }
    }

    /**
     * Get whether the script currently has a console window.
     * https://learn.microsoft.com/en-us/windows/console/getconsolemode
     */
    static HasConsole() => DllCall("GetConsoleWindow", "ptr") != 0

    /**
     * Get a standard handle for use in the console. This is a `HANDLE` and does not need to be freed
     * @see https://learn.microsoft.com/en-us/windows/console/getstdhandle
     * @param {"in" | "out" | "err"} hKind the handle to retrieve
     * @returns {Integer} the handle
     */
    static GetStdHandle(hKind) {
        switch StrLower(SubStr(hKind, 1, 1)) {
            case "i":
                handleNum := -10
            case "o":
                handleNum := -11
            case "e":
                handleNum := -12
            default:
                throw ValueError("Unknown handle kind", -1, hKind)
        }

        handle := DllCall("GetStdHandle", "uint", handleNum, "ptr")
        if handle == -1
            throw OSError()
        return handle
    }

    /**
     * Open an stdio stream or fall back to a console buffer if it doesn't exist
     * @returns {File} 
     */
    static _OpenStream(stdHandleNum, conName, preferConsole) {
        static UNKNOWN := 0, DISK := 1, CHAR := 2, PIPE := 3

        h := DllCall("GetStdHandle", "uint", stdHandleNum, "ptr")
        type := DllCall("GetFileType", "ptr", h, "uint")
        redirected := (type = PIPE || type = DISK)

        if (redirected && !preferConsole)
            return FileOpen(h, "h")

        ; Open the console buffer via a handle + the "h" flag so AHK doesn't probe
        ; for a BOM. On CONIN$ that probe is a blocking read that waits for a newline
        ; before FileOpen returns.
        conHandle := DllCall("CreateFile", "str", conName,
            "uint", 0xC0000000,   ; GENERIC_READ | GENERIC_WRITE
            "uint", 0x3,          ; FILE_SHARE_READ | FILE_SHARE_WRITE
            "ptr", 0, "uint", 3,  ; OPEN_EXISTING
            "uint", 0, "ptr", 0, "ptr")

        if (conHandle = -1)
            throw OSError()

        stream := FileOpen(conHandle, "h")

        ; Override instance Write methods to always flush the write buffer immediately
        ; Accessing the handle flushes read/write buffers
        stream.DefineProp("WriteLine", { 
            Call: (self, text) => (
                bytesWritten := File.Prototype.WriteLine.Call(self, text), 
                _ := self.handle,
                bytesWritten) 
        })
        stream.DefineProp("Write", { 
            Call: (self, text) => (
                bytesWritten := File.Prototype.Write.Call(self, text),
                _ := self.handle,
                bytesWritten) 
        })

        return stream
    }

    static _InitStreams(preferConsole) {
        Console.In  := Console._OpenStream(-10, "CONIN$",  preferConsole)
        Console.Out := Console._OpenStream(-11, "CONOUT$", preferConsole)
        Console.Err := Console._OpenStream(-12, "CONOUT$", preferConsole)

        ; Rewire std handles so GetStdHandle / IsAttached agree with reality
        DllCall("SetStdHandle", "uint", -10, "ptr", Console.In.Handle)
        DllCall("SetStdHandle", "uint", -11, "ptr", Console.Out.Handle)
        DllCall("SetStdHandle", "uint", -12, "ptr", Console.Err.Handle)

        Console._EnableVirtualTerminalSequences()
    }

    /**
     * Enable modern virtual terminal sequences for our stdout handle. Allows, among other
     * things, ANSI escape sequences to work
     * @see https://learn.microsoft.com/en-us/windows/console/console-virtual-terminal-sequences
     */
    static _EnableVirtualTerminalSequences() {
        hOut := Console.GetStdHandle("out")
        ; This only works on real console handles, if stdout is e.g. a pipe it'll fail, just ignore it
        if !DllCall("GetConsoleMode", "ptr", hOut, "uint*", &dwMode := 0, "char")
            return

        ; ENABLE_PROCESSED_OUTPUT | ENABLE_VIRTUAL_TERMINAL_PROCESSING
        dwMode |= 0x0001 | 0x0004
        if !DllCall("SetConsoleMode", "ptr", hOut, "uint", dwMode, "char")
            throw OSError()
    }
}