' Godsfall launcher shim.
'
' Starts launch.ps1 with no console window. A .cmd/.bat shortcut always flashes a
' window before it can hide itself, and PowerShell's -WindowStyle Hidden still
' creates one briefly; WScript.Shell.Run with intWindowStyle=0 does not.
'
' The final "False" means this shim does NOT wait -- it exits immediately, while
' the hidden PowerShell keeps running to capture Godot's output and write the log.

Dim shell, fso, here, ps1
Set shell = CreateObject("WScript.Shell")
Set fso   = CreateObject("Scripting.FileSystemObject")

here = fso.GetParentFolderName(WScript.ScriptFullName)
ps1  = fso.BuildPath(here, "launch.ps1")

shell.Run "powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File """ & ps1 & """", 0, False
