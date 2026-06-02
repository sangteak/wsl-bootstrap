' Run start-wsl-docker.cmd (same folder) with no console window.
' Self-locating: works wherever the two files are placed together.
Dim fso, here
Set fso = CreateObject("Scripting.FileSystemObject")
here = fso.GetParentFolderName(WScript.ScriptFullName)
CreateObject("WScript.Shell").Run """" & here & "\start-wsl-docker.cmd""", 0, False
