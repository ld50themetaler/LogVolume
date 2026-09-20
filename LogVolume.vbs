Option Explicit

Dim ws, scriptDir, ps1Path, command

Set ws = CreateObject("WScript.Shell")
scriptDir = Replace(WScript.ScriptFullName, WScript.ScriptName, "")
ps1Path = scriptDir & "LogVolume.ps1"

' WinForms を確実に STA で起動する。
' RemoteSigned は Bypass と異なり、実行ポリシーを無条件に回避しない。
command = "powershell.exe -NoProfile -STA -ExecutionPolicy RemoteSigned -File """ & ps1Path & """"

' 通常のウィンドウで起動し、エラー内容を確認できるようにする。
ws.Run command, 1, True
