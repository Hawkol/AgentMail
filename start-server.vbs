' Agent Mail service hidden launcher (WindowStyle 0 = no window)
' Run by scheduled task DSH-Mail-Server at logon.
' Note: keep this file pure ASCII to avoid VBScript encoding errors.
Set sh = CreateObject("WScript.Shell")
sh.Run """d:\Program Files\nodejs\node.exe"" E:\AgentMail\server.js", 0, False
