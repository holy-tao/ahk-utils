#Requires AutoHotkey v2.0

#Include ./YUnit/YUnit.ahk
#Include ./YUnit/ResultCounter.ahk
#Include ./YUnit/JUnit.ahk
#Include ./YUnit/Stdout.ahk

#Include SemVer.test.ahk
#Include RegEx.test.ahk

YUnit.Use(YunitResultCounter, YUnitJUnit, YUnitStdOut).Test(
	SemVerTests, RegExTests
)

Exit(-YunitResultCounter.failures)