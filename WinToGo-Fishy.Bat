@echo off
REM Run Windows To Go Script

REM Check for admin rights
NET SESSION >nul 2>&1
if %errorLevel% neq 0 (
    echo Administrator rights required
    echo Right-click and select "Run as administrator"
    pause
    exit /B 1
)

REM Set script path
set "SCRIPT_PATH=%~dp0main_script.ps1"

REM Check if script exists
if not exist "%SCRIPT_PATH%" (
    echo Script not found: %SCRIPT_PATH%
    pause
    exit /B 1
)

REM Run PowerShell script
powershell.exe -ExecutionPolicy Bypass -File "%SCRIPT_PATH%"

REM Pause to see any output
pause
