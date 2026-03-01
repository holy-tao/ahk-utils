#Requires AutoHotkey v2.0

/**
 * Runs a `cmd` command and captures its output. Note `stdout` and `stderr` are combined into a single string. The
 * command is run from the script's current working directory - set `A_WorkingDir` beforehand to change it.
 * 
 *      ; Get the root of the current git repository
 *      Cmd("git rev-parse --show-toplevel", &gitDir := "")
 * 
 * This function works by piping the command's output to a file and then reading it, so it's fairly slow, as things
 * go - expect about 150-200ms overhead on top of the time it takes to run the actual command.
 * 
 * @param {String} command the command to run
 * @param {VarRef<String>} out an optional parameter which receives the command's `stdout`. If `err` is not provided,
 *          this parameter also receives the command's stderr.
 * @param {VarRef<String>} err an optional parameter which receives the command's `stderr`
 * @returns {Integer} the return code of the command
 */
Cmd(command, &out?, &err?) {
    tmpOut := A_Temp "\" A_ScriptName ".cmd.out.tmp"
    tmpErr := A_Temp "\" A_ScriptName ".cmd.err.tmp"

    rc := RunWait(Format('{1} /c "{3} 1>"{2}" 2>{4}"', 
        A_ComSpec, tmpOut, command, IsSet(err) ? tmpErr : "&1"), , "Hide")

    out := Trim(FileRead(tmpOut), "`t`r`n ")
    if(IsSet(err)) {
        err := Trim(FileRead(tmpErr), "`t`r`n ")
        FileDelete(tmpErr)
    }

    FileDelete(tmpOut)

    return rc
}

/**
 * Runs a `cmd` command and captures its output, but throws an Error if the return code is not zero. See
 * {@link Cmd `Cmd`} for details
 * 
 * @param {String} cmd the command to run
 * @returns {String} the command's stdout 
 */
CmdExpect(command) {
    rc := Cmd(command, &out := "", &err := "")
    if(rc != 0)
        throw Error(err, -1, command)

    return out
}