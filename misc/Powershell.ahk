#Requires AutoHotkey v2.0

/**
 * Provides utilities for running powershell (not to be confused with `pwsh`, or PowerShell 7+) commands and files
 */
class Powershell {
    /**
     * Runs a PowerShell CmdLet or series of commands, optionally capturing their outputs, via the `-Command` flag
     * 
     *      ; Generate a UUID
     *      Powershell.Cmd("$(New-Guid).ToString()")
     * 
     * This method is slow; expect 400-500ms overhead on top of the time it takes to execute your command(s)
     * 
     * @param {String} command the PowerShell CmdLet(s) to run 
     * @param {VarRef<String>} out an optional parameter which receives the command's `stdout`. If `err` is not
     *          provided this parameter also receives the command's stderr.
     * @param {VarRef<String>} err an optional output parameter which receives the commands `stderr`
     * @returns {Integer} the exit code of the command
     */
    static Cmd(command, &out?, &err?) {
        tmpOut := A_Temp "\" A_ScriptName ".powershell-" A_Now ".cmd.out.tmp"
        tmpErr := A_Temp "\" A_ScriptName ".powershell-" A_Now ".cmd.err.tmp"

        rc := RunWait(Format('{1} /c "powershell.exe -NoLogo -NonInteractive -Command "{2}" 1>"{3}" 2>{4}"',
            A_ComSpec, command,
            IsSet(out) ? tmpOut : "NUL",
            IsSet(err) ? tmpErr : "&1"), , "Hide")

        if(IsSet(out)) {
            out := Trim(FileRead(tmpOut), "`t`r`n ")
            FileDelete(tmpOut)
        }
        if(IsSet(err)) {
            err := Trim(FileRead(tmpErr), "`t`r`n ")
            FileDelete(tmpErr)
        }

        return rc
    }

    /**
     * Executes a .ps1 script in PowerShell, optionally capturing its outputs. See also {@link Powershell.Cmd `Powershell.Cmd`}
     * 
     * @param {String} filepath path to the file being run
     * @param {VarRef<String>} out an optional parameter which receives the command's `stdout`. If `err` is not
     *          provided this parameter also receives the command's stderr.
     * @param {VarRef<String>} err an optional output parameter which receives the commands `stderr`
     * @returns {Integer} the exit code of the script
     */
    static File(filepath, &out?, &err?) {
        if(!FileExist(filepath))
            throw ValueError("File must exist", -1, filepath)

        tmpOut := A_Temp "\" A_ScriptName ".powershell-" A_Now ".file.out.tmp"
        tmpErr := A_Temp "\" A_ScriptName ".powershell-" A_Now ".file.err.tmp"

        rc := RunWait(Format('{1} /c "powershell.exe -NoLogo -NonInteractive -File "{2}" 1>"{3}" 2>{4}"',
            A_ComSpec, filepath,
            IsSet(out) ? tmpOut : "NUL",
            IsSet(err) ? tmpErr : "&1"), , "Hide")

        if(IsSet(out)) {
            out := Trim(FileRead(tmpOut), "`t`r`n ")
            FileDelete(tmpOut)
        }
        if(IsSet(err)) {
            err := Trim(FileRead(tmpErr), "`t`r`n ")
            FileDelete(tmpErr)
        }

        return rc
    }

    /**
     * Like {@link Powershell.Cmd `Powershell.Cmd`}, except that if powershell exits with a non-zero exit code, an
     * Error is thrown, and the return value is the output of `command`.
     * 
     * @param {String} command the CmdLet(s) to execute
     * @returns {String} the output of `command` 
     */
    static CmdExpect(command) {
        rc := Powershell.Cmd(command, &out := "", &err := "")
        if(rc != 0)
            throw Error(err, -1, command)
        return out
    }

    /**
     * Like {@link Powershell.File `Powershell.File`}, except that if powershell exits with a non-zero exit code, an
     * Error is thrown, and the return value is the output of `filepath`.
     * 
     * @param {String} filepath path to the file to execute
     * @returns {String} the output of `filepath` 
     */
    static FileExpect(filepath) {
        rc := Powershell.File(filepath, &out := "", &err := "")
        if(rc != 0)
            throw Error(err, -1, filepath)
        return out
    }
}