@echo off
rem Claude Skins - Windows launcher for the PowerShell engine.
rem Usage: run-engine.cmd <script.ps1> [arg]
rem Tries PowerShell 7 (pwsh), then Windows PowerShell 5.1 on PATH, then the
rem built-in 5.1 path. With no PowerShell at all it exits 0 so hooks never fail.
rem stdin, the optional argument, and the exit code pass through.
setlocal
set "SKIN_SCRIPT=%~dp0%~1"
where pwsh >nul 2>nul && goto pwsh
where powershell >nul 2>nul && goto winps
set "SKIN_PS=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if exist "%SKIN_PS%" goto winpsabs
exit /b 0

:pwsh
pwsh -NoProfile -ExecutionPolicy Bypass -File "%SKIN_SCRIPT%" %2
exit /b %ERRORLEVEL%

:winps
powershell -NoProfile -ExecutionPolicy Bypass -File "%SKIN_SCRIPT%" %2
exit /b %ERRORLEVEL%

:winpsabs
"%SKIN_PS%" -NoProfile -ExecutionPolicy Bypass -File "%SKIN_SCRIPT%" %2
exit /b %ERRORLEVEL%
