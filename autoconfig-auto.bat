@echo off
setlocal EnableDelayedExpansion

:: Set console colors
set "RESET=[0m"
set "BLUE=[94m"
set "GREEN=[92m"
set "YELLOW=[93m"
set "RED=[91m"
set "CYAN=[96m"

:: Title
title Zen Browser AutoConfig Script

:: Header
echo %BLUE%=============================================%RESET%
echo %BLUE%   fx-autoconfig Interactive Installer      %RESET%
echo %BLUE%=============================================%RESET%
echo %YELLOW%This batch file helps install fx-autoconfig and Sine%RESET%
echo %YELLOW%for Zen Browser and Firefox-based browsers%RESET%
echo.

:: Check if script exists
if not exist "autoconfig-auto.sh" (
    echo %RED%Error: autoconfig-auto.sh script not found!%RESET%
    echo %YELLOW%This batch file must be in the same directory as autoconfig-auto.sh%RESET%
    pause
    exit /b 1
)

:: Check for Bash environments in preference order
set "bash_found=0"
set "bash_type="

:: Check for Git Bash (common on Windows)
where /q bash.exe
if %ERRORLEVEL% EQU 0 (
    set "bash_found=1"
    set "bash_type=Git Bash"
    goto :BASH_FOUND
)

:: Check for WSL
where /q wsl.exe
if %ERRORLEVEL% EQU 0 (
    echo %CYAN%Windows Subsystem for Linux (WSL) detected.%RESET%
    wsl -l >nul 2>&1
    if %ERRORLEVEL% EQU 0 (
        set "bash_found=1"
        set "bash_type=WSL"
        goto :BASH_FOUND
    ) else (
        echo %YELLOW%WSL is installed but no Linux distribution is set up.%RESET%
    )
)

:: Check for Cygwin
if exist "C:\cygwin64\bin\bash.exe" (
    set "bash_found=1"
    set "bash_type=Cygwin"
    set "cygwin_path=C:\cygwin64\bin"
    goto :BASH_FOUND
) else if exist "C:\cygwin\bin\bash.exe" (
    set "bash_found=1" 
    set "bash_type=Cygwin"
    set "cygwin_path=C:\cygwin\bin"
    goto :BASH_FOUND
)

:BASH_FOUND
if %bash_found% EQU 1 (
    echo %GREEN%Found %bash_type% for running the installer.%RESET%
    echo.
) else (
    goto :NO_BASH
)

:: Present options to user
echo %CYAN%Please select an option:%RESET%
echo %CYAN%1)%RESET% Install fx-autoconfig
echo %CYAN%2)%RESET% Install Sine (includes fx-autoconfig)
echo %CYAN%3)%RESET% Restore from backup
echo %CYAN%q)%RESET% Quit
echo.

set /p choice="Enter your choice: "

if /i "%choice%"=="q" (
    echo %YELLOW%Exiting...%RESET%
    exit /b 0
)

if "%choice%"=="1" (
    set "action=fx-autoconfig"
) else if "%choice%"=="2" (
    set "action=Sine"
) else if "%choice%"=="3" (
    set "action=restore"
) else (
    echo %RED%Invalid choice.%RESET%
    pause
    exit /b 1
)

:: Run the appropriate script based on detected Bash type
echo %YELLOW%Starting installation of %action%...%RESET%
echo.

if "%bash_type%"=="Git Bash" (
    start bash.exe -c "cd \"%CD%\" && chmod +x autoconfig-auto.sh && ./autoconfig-auto.sh"
) else if "%bash_type%"=="WSL" (
    echo %YELLOW%Converting Windows path to WSL path...%RESET%
    for /f "tokens=*" %%p in ('wsl wslpath -a "%CD%"') do set "wsl_path=%%p"
    echo %YELLOW%Launching WSL to run the script...%RESET%
    start wsl bash -c "cd '%wsl_path%' && chmod +x autoconfig-auto.sh && ./autoconfig-auto.sh"
) else if "%bash_type%"=="Cygwin" (
    echo %YELLOW%Converting Windows path to Cygwin path...%RESET%
    for /f "tokens=1,2 delims=:" %%a in ("%CD%") do (
        set "drive=%%a"
        set "path_tail=%%b"
    )
    set "cygwin_compatible_path=/cygdrive/%drive:~0,1%%path_tail:\=/%"
    echo %YELLOW%Launching Cygwin to run the script...%RESET%
    start "Cygwin" "%cygwin_path%\bash.exe" -l -c "cd '%cygwin_compatible_path%' && chmod +x autoconfig-auto.sh && ./autoconfig-auto.sh"
)

goto :EOF

:NO_BASH
echo %RED%Could not find a suitable Bash environment to run the script.%RESET%
echo %YELLOW%You need one of the following to run this script:%RESET%
echo.
echo %CYAN%Option 1: Install Git for Windows%RESET%
echo   Download from: https://git-scm.com/download/win
echo.
echo %CYAN%Option 2: Install Windows Subsystem for Linux (WSL)%RESET%
echo   1. Open PowerShell as Administrator and run:
echo      wsl --install
echo   2. Restart your computer
echo   3. Complete the Ubuntu setup when it launches
echo.
echo %CYAN%Option 3: Download the portable version%RESET%
echo   If you don't want to install anything, you can download our portable version
echo   which includes a portable Git Bash environment:
echo   https://github.com/CosmoCreeper/Zen-Tools/releases
echo.

echo %YELLOW%Would you like to open the Git for Windows download page? (Y/N)%RESET%
set /p open_git="Your choice: "
if /i "%open_git%"=="Y" start https://git-scm.com/download/win

pause
exit /b 1

:EOF
:: End of script
endlocal