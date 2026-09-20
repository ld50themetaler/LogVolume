Option Explicit

Dim ws, scriptDir, ps1Path, command

Set ws = CreateObject("WScript.Shell")
scriptDir = Replace(WScript.ScriptFullName, WScript.ScriptName, "")
ps1Path = scriptDir & "LogVolume.ps1"
command = "powershell.exe -NoProfile -File """ & ps1Path & """"

' 通常のウィンドウで表示し、終了を待ってから戻る
' Windows Defender の検出を抑えるため、-ExecutionPolicy Bypass と -WindowStyle Hidden は使わない
ws.Run command, 1, True
