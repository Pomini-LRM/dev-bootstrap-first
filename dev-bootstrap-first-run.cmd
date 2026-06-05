@echo off
REM ============================================================================
REM dev-bootstrap-first-run.cmd
REM First-run launcher for dev-bootstrap on a clean Windows machine.
REM Does not require Git or PowerShell 7. Requires only CMD and Internet.
REM
REM Steps:
REM   1. Download the dev-bootstrap repository ZIP from GitHub.
REM   2. Extract it into %DEST%\repo using curl/tar/Expand-Archive/VBS fallback.
REM   3. Run install-prerequisites-windows.ps1 (installs PowerShell 7).
REM   4. Run setup-config-interactive.ps1 (interactive configuration).
REM   5. Run dev-bootstrap.ps1 (full bootstrap with tokens and tools).
REM   6. Copy generated config.json and .env to the final repository folder.
REM   7. Clean up the staging folder.
REM
REM Environment variables (optional):
REM   DEV_BOOTSTRAP_DEST  - staging folder. Default: %USERPROFILE%\PominiLRM\dev-bootstrap-first
REM   DEV_BOOTSTRAP_FINAL - final repo folder where config files are copied.
REM                          Default: %USERPROFILE%\PominiLRM\dev-bootstrap
REM   DEV_BOOTSTRAP_REF   - branch/tag to download. Default: main
REM
REM Command-line flags:
REM   --force          re-download even if the repo is already extracted
REM   --keep           do not delete the staging folder at the end
REM   --dest <path>    override staging folder
REM   --final <path>   override final folder
REM   --ref <branch>   override branch/tag
REM ============================================================================

setlocal EnableExtensions EnableDelayedExpansion

set "EXIT_CODE=0"

REM ---- Prevent concurrent execution ----------------------------------------
set "LOCK_FILE=%TEMP%\dev-bootstrap-first-run.lock"
if exist "%LOCK_FILE%" (
    echo [ERROR] Another instance appears to be already running.
    echo         Lock file: %LOCK_FILE%
    echo         If no other instance is running, delete that file and retry.
    exit /b 99
)
echo %DATE% %TIME% > "%LOCK_FILE%"

REM ---- Defaults --------------------------------------------------------------
if not defined DEV_BOOTSTRAP_DEST  set "DEV_BOOTSTRAP_DEST=%USERPROFILE%\PominiLRM\dev-bootstrap-first"
if not defined DEV_BOOTSTRAP_FINAL set "DEV_BOOTSTRAP_FINAL=%USERPROFILE%\PominiLRM\dev-bootstrap"
if not defined DEV_BOOTSTRAP_REF   set "DEV_BOOTSTRAP_REF=main"
if not defined DEV_BOOTSTRAP_DEBUG set "DEV_BOOTSTRAP_DEBUG=0"

set "DEST=%DEV_BOOTSTRAP_DEST%"
set "FINAL_TARGET=%DEV_BOOTSTRAP_FINAL%"
set "REF=%DEV_BOOTSTRAP_REF%"
set "DEBUG=%DEV_BOOTSTRAP_DEBUG%"
set "FORCE=0"
set "KEEP=0"

REM ---- Parse arguments -------------------------------------------------------
:parse_args
if "%~1"=="" goto args_done
if /I "%~1"=="--force" ( set "FORCE=1" & shift & goto parse_args )
if /I "%~1"=="-f"      ( set "FORCE=1" & shift & goto parse_args )
if /I "%~1"=="--keep"  ( set "KEEP=1"  & shift & goto parse_args )
if /I "%~1"=="--dest"  ( set "DEST=%~2"         & shift & shift & goto parse_args )
if /I "%~1"=="--final" ( set "FINAL_TARGET=%~2" & shift & shift & goto parse_args )
if /I "%~1"=="--ref"   ( set "REF=%~2"          & shift & shift & goto parse_args )
echo Unknown argument: %~1
shift
goto parse_args
:args_done

set "REPO_URL=https://github.com/Pomini-LRM/dev-bootstrap/archive/refs/heads/%REF%.zip"
set "EXTRACTED_DIR_NAME=dev-bootstrap-%REF%"
set "TMP_DIR=%DEST%\_tmp"
set "EXTRACT_DIR=%TMP_DIR%\extract"
set "ZIP_FILE=%TMP_DIR%\dev-bootstrap.zip"
set "REPO_DIR=%DEST%\repo"
set "LOG_DIR=%DEST%\logs"
set "LOG_FILE=%LOG_DIR%\first-run.log"
set "VBS_FILE=%TMP_DIR%\unzip.vbs"

REM ---- Prepare folders -------------------------------------------------------
if not exist "%DEST%"    mkdir "%DEST%"    >nul 2>nul
if not exist "%TMP_DIR%" mkdir "%TMP_DIR%" >nul 2>nul
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%" >nul 2>nul

call :log "============================================================"
call :log "dev-bootstrap first-run launcher started"
call :log "Date           : %DATE% %TIME%"
call :log "Staging (DEST) : %DEST%"
call :log "Final target   : %FINAL_TARGET%"
call :log "Repo URL       : %REPO_URL%"
call :log "Force          : %FORCE%"
call :log "Keep staging   : %KEEP%"
call :log "Debug mode     : %DEBUG%"
call :log "============================================================"

echo.
echo ============================================================
echo  dev-bootstrap - First Run Launcher
echo ============================================================
echo  Staging folder : %DEST%
echo  Final folder   : %FINAL_TARGET%
echo  Source         : %REPO_URL%
echo  Log file       : %LOG_FILE%
echo  Debug mode     : %DEBUG%
echo ============================================================
echo.
echo [INFO] Keep this window open until the process completes.
echo [INFO] You may be prompted for elevation during prerequisites installation.

call :phase "1/7" "Download repository"
call :debug "Launcher path: %~f0"
call :debug "User: %USERNAME% | Machine: %COMPUTERNAME%"

REM ---- Step 1: Download ZIP (skip if already extracted and not forced) ------
if "%FORCE%"=="0" if exist "%REPO_DIR%\dev-bootstrap.ps1" (
    call :log "Repository already present at %REPO_DIR%. Skipping download."
    echo [SKIP] Repository already present. Use --force to re-download.
    goto run_scripts
)

REM Clean previous staging artifacts.
if exist "%ZIP_FILE%"     del /F /Q "%ZIP_FILE%" >nul 2>nul
if exist "%EXTRACT_DIR%"  rmdir /S /Q "%EXTRACT_DIR%" >nul 2>nul
if exist "%REPO_DIR%"     rmdir /S /Q "%REPO_DIR%" >nul 2>nul
mkdir "%EXTRACT_DIR%" >nul 2>nul

echo [INFO] Downloading repository ZIP...
call :log "Downloading %REPO_URL% to %ZIP_FILE%"

set "DOWNLOAD_OK=0"

where curl >nul 2>nul
if %ERRORLEVEL% EQU 0 (
    call :debug "Download tool selected: curl"
    call :log "Using curl to download."
    curl -L --fail --silent --show-error -o "%ZIP_FILE%" "%REPO_URL%" >> "%LOG_FILE%" 2>&1
    if !ERRORLEVEL! EQU 0 if exist "%ZIP_FILE%" set "DOWNLOAD_OK=1"
    if not "!DOWNLOAD_OK!"=="1" call :debug "curl download failed with code !ERRORLEVEL!"
)
if %ERRORLEVEL% NEQ 0 (
    call :debug "curl not found."
)

if "%DOWNLOAD_OK%"=="0" (
    echo [INFO] Primary downloader unavailable or failed. Trying fallback...
    where bitsadmin >nul 2>nul
    if !ERRORLEVEL! EQU 0 (
        call :debug "Download fallback selected: bitsadmin"
        call :log "Using bitsadmin fallback to download."
        bitsadmin /transfer dev-bootstrap-first-run /priority FOREGROUND "%REPO_URL%" "%ZIP_FILE%" >> "%LOG_FILE%" 2>&1
        if !ERRORLEVEL! EQU 0 if exist "%ZIP_FILE%" set "DOWNLOAD_OK=1"
        if not "!DOWNLOAD_OK!"=="1" call :debug "bitsadmin download failed with code !ERRORLEVEL!"
    ) else (
        call :debug "bitsadmin not found."
    )
)

if "%DOWNLOAD_OK%"=="0" (
    call :log "ERROR: Download failed. Neither curl nor bitsadmin succeeded."
    echo [ERROR] Download failed. Check your Internet connection and proxy settings.
    echo         See %LOG_FILE% for details.
    set "EXIT_CODE=10"
    goto cleanup_and_exit
)

call :log "Download completed: %ZIP_FILE%"
echo [OK] Download completed.

REM ---- Step 2: Extract -------------------------------------------------------
call :phase "2/7" "Extract archive"
echo [INFO] Extracting archive...
call :log "Extracting %ZIP_FILE% into %EXTRACT_DIR%"

set "EXTRACT_OK=0"

where tar >nul 2>nul
if %ERRORLEVEL% EQU 0 (
    call :debug "Extraction tool selected: tar"
    call :log "Using tar -xf to extract."
    pushd "%EXTRACT_DIR%" >nul
    tar -xf "%ZIP_FILE%" >> "%LOG_FILE%" 2>&1
    if !ERRORLEVEL! EQU 0 set "EXTRACT_OK=1"
    popd >nul
    if not "!EXTRACT_OK!"=="1" call :debug "tar extraction failed with code !ERRORLEVEL!"
)
if %ERRORLEVEL% NEQ 0 (
    call :debug "tar not found."
)

if "%EXTRACT_OK%"=="0" (
    echo [INFO] Primary extractor unavailable or failed. Trying fallback...
    where powershell >nul 2>nul
    if !ERRORLEVEL! EQU 0 (
        call :debug "Extraction fallback selected: powershell Expand-Archive"
        call :log "Using Windows PowerShell Expand-Archive to extract."
        powershell -NoProfile -ExecutionPolicy Bypass -Command "try { Expand-Archive -LiteralPath '%ZIP_FILE%' -DestinationPath '%EXTRACT_DIR%' -Force; exit 0 } catch { Write-Error $_; exit 1 }" >> "%LOG_FILE%" 2>&1
        if !ERRORLEVEL! EQU 0 set "EXTRACT_OK=1"
        if not "!EXTRACT_OK!"=="1" call :debug "Expand-Archive failed with code !ERRORLEVEL!"
    ) else (
        call :debug "powershell.exe not found."
    )
)

if "%EXTRACT_OK%"=="0" (
    call :debug "Extraction fallback selected: cscript/vbs"
    call :log "Falling back to VBScript Shell.Application extraction."
    call :write_vbs_unzip
    cscript //nologo "%VBS_FILE%" "%ZIP_FILE%" "%EXTRACT_DIR%" >> "%LOG_FILE%" 2>&1
    if !ERRORLEVEL! EQU 0 set "EXTRACT_OK=1"
    if not "!EXTRACT_OK!"=="1" call :debug "VBScript extraction failed with code !ERRORLEVEL!"
)

if "%EXTRACT_OK%"=="0" (
    call :log "ERROR: All extraction methods failed."
    echo [ERROR] Could not extract the archive. See %LOG_FILE% for details.
    set "EXIT_CODE=20"
    goto cleanup_and_exit
)

call :log "Extraction completed."
echo [OK] Extraction completed.

REM ---- Step 3: Locate extracted folder and move to repo ----------------------
call :phase "3/7" "Stage repository"
echo [INFO] Locating extracted repository...

set "FOUND_DIR="
if exist "%EXTRACT_DIR%\%EXTRACTED_DIR_NAME%\dev-bootstrap.ps1" (
    set "FOUND_DIR=%EXTRACT_DIR%\%EXTRACTED_DIR_NAME%"
) else (
    for /D %%D in ("%EXTRACT_DIR%\*") do (
        if exist "%%~fD\dev-bootstrap.ps1" set "FOUND_DIR=%%~fD"
    )
)

if "%FOUND_DIR%"=="" (
    call :log "ERROR: Could not locate dev-bootstrap.ps1 in extracted archive."
    echo [ERROR] Extracted archive does not contain dev-bootstrap.ps1.
    set "EXIT_CODE=30"
    goto cleanup_and_exit
)

call :log "Extracted repo at: %FOUND_DIR%"
call :debug "Extracted repository folder: %FOUND_DIR%"

REM Move (rename) to %REPO_DIR%. Use robocopy + rmdir for reliability.
if exist "%REPO_DIR%" rmdir /S /Q "%REPO_DIR%" >nul 2>nul
mkdir "%REPO_DIR%" >nul 2>nul
robocopy "%FOUND_DIR%" "%REPO_DIR%" /E /MOVE /NFL /NDL /NJH /NJS /NP >> "%LOG_FILE%" 2>&1
REM robocopy returns 0-7 for success.
if errorlevel 8 (
    call :log "ERROR: robocopy failed while moving extracted folder."
    echo [ERROR] Could not stage repository. See %LOG_FILE% for details.
    set "EXIT_CODE=31"
    goto cleanup_and_exit
)

echo        Repository staged at %REPO_DIR%.
call :debug "Repository staged in: %REPO_DIR%"

:run_scripts

if not exist "%REPO_DIR%\dev-bootstrap.ps1" (
    call :log "ERROR: %REPO_DIR%\dev-bootstrap.ps1 not found."
    echo [ERROR] Bootstrap entry point not found at %REPO_DIR%\dev-bootstrap.ps1.
    set "EXIT_CODE=40"
    goto cleanup_and_exit
)

REM ---- Step 4: Install prerequisites (PowerShell 7) --------------------------
call :phase "4/7" "Install prerequisites"
echo [INFO] Installing prerequisites (PowerShell 7)...
call :log "Running install-prerequisites-windows.ps1"

set "PREREQ_SCRIPT=%REPO_DIR%\scripts\install-prerequisites-windows.ps1"
if exist "%PREREQ_SCRIPT%" (
    where pwsh >nul 2>nul
    if !ERRORLEVEL! EQU 0 (
        call :debug "Prerequisites host: pwsh"
        pwsh -NoProfile -ExecutionPolicy Bypass -File "%PREREQ_SCRIPT%"
    ) else (
        where powershell >nul 2>nul
        if !ERRORLEVEL! EQU 0 (
            call :debug "Prerequisites host fallback: powershell"
            powershell -NoProfile -ExecutionPolicy Bypass -File "%PREREQ_SCRIPT%"
        ) else (
            call :log "ERROR: Neither pwsh nor powershell is available."
            echo [ERROR] Cannot run prerequisites script: no PowerShell host found.
            set "EXIT_CODE=50"
            goto cleanup_and_exit
        )
    )
    if errorlevel 1 (
        call :log "WARNING: install-prerequisites-windows.ps1 returned a non-zero exit code."
        echo [WARN] Prerequisite installer reported issues. Continuing anyway.
    )
) else (
    call :log "WARNING: %PREREQ_SCRIPT% not found, skipping."
    echo [WARN] Prerequisites script not found. Skipping.
)

REM ---- Step 5: Interactive setup + main bootstrap ----------------------------
call :phase "5/7" "Interactive setup and bootstrap"
echo [INFO] Running interactive setup and bootstrap...
call :log "Locating pwsh for setup-config-interactive.ps1 and dev-bootstrap.ps1"

REM After install-prerequisites, pwsh should be on PATH. Refresh PATH from registry.
call :refresh_path

set "PWSH_EXE="
where pwsh >nul 2>nul
if %ERRORLEVEL% EQU 0 (
    for /F "delims=" %%P in ('where pwsh') do (
        if not defined PWSH_EXE set "PWSH_EXE=%%P"
    )
)
if "%PWSH_EXE%"=="" (
    if exist "%ProgramFiles%\PowerShell\7\pwsh.exe" set "PWSH_EXE=%ProgramFiles%\PowerShell\7\pwsh.exe"
)
if "%PWSH_EXE%"=="" (
    call :log "ERROR: PowerShell 7 (pwsh) not found after prerequisites step."
    echo [ERROR] PowerShell 7 was not installed correctly. Open a new terminal and re-run.
    set "EXIT_CODE=60"
    goto cleanup_and_exit
)

call :log "Using pwsh at: %PWSH_EXE%"
call :debug "Bootstrap host: %PWSH_EXE%"

set "SETUP_SCRIPT=%REPO_DIR%\scripts\setup-config-interactive.ps1"
if exist "%SETUP_SCRIPT%" (
    call :log "Running setup-config-interactive.ps1"
    "%PWSH_EXE%" -NoProfile -ExecutionPolicy Bypass -File "%SETUP_SCRIPT%"
    if errorlevel 1 (
        call :log "ERROR: setup-config-interactive.ps1 failed."
        echo [ERROR] Interactive configuration failed. See %LOG_FILE%.
        set "EXIT_CODE=70"
        goto cleanup_and_exit
    )
) else (
    call :log "WARNING: setup-config-interactive.ps1 not found, skipping."
    echo [WARN] Interactive setup script not found. Skipping.
)

call :log "Running dev-bootstrap.ps1"
pushd "%REPO_DIR%" >nul
"%PWSH_EXE%" -NoProfile -ExecutionPolicy Bypass -File "%REPO_DIR%\dev-bootstrap.ps1"
set "BOOTSTRAP_RC=!ERRORLEVEL!"
popd >nul

call :log "dev-bootstrap.ps1 exited with code !BOOTSTRAP_RC!"

if not "!BOOTSTRAP_RC!"=="0" (
    echo [ERROR] dev-bootstrap.ps1 returned exit code !BOOTSTRAP_RC!.
    echo         See %LOG_FILE% for details.
    set "EXIT_CODE=!BOOTSTRAP_RC!"
    goto cleanup_and_exit
)

REM ---- Step 6: Copy generated config files to final folder -------------------
call :phase "6/7" "Copy generated configuration"
echo [INFO] Copying generated config files to %FINAL_TARGET% ...
call :log "Copying generated config.json and .env to final folder."

set "SRC_CONFIG=%REPO_DIR%\config\config.json"
set "SRC_ENV=%REPO_DIR%\.env"
set "DST_CONFIG_DIR=%FINAL_TARGET%\config"

if not exist "%FINAL_TARGET%" mkdir "%FINAL_TARGET%" >nul 2>nul
if not exist "%DST_CONFIG_DIR%" mkdir "%DST_CONFIG_DIR%" >nul 2>nul

set "COPY_WARN=0"

if exist "%SRC_CONFIG%" (
    copy /Y "%SRC_CONFIG%" "%DST_CONFIG_DIR%\config.json" >nul 2>&1
    call :log "Copied config.json -> %DST_CONFIG_DIR%\config.json"
    echo        config.json copied.
) else (
    call :log "WARNING: %SRC_CONFIG% not found, nothing to copy."
    echo [WARN] config.json was not generated in %REPO_DIR%\config.
    set "COPY_WARN=1"
)

if exist "%SRC_ENV%" (
    copy /Y "%SRC_ENV%" "%FINAL_TARGET%\.env" >nul 2>&1
    call :log "Copied .env -> %FINAL_TARGET%\.env"
    echo        .env copied.
) else (
    call :log "WARNING: %SRC_ENV% not found, nothing to copy."
    echo [WARN] .env was not generated in %REPO_DIR%.
    set "COPY_WARN=1"
)

if "!COPY_WARN!"=="1" if "!EXIT_CODE!"=="0" (
    call :log "ERROR: Bootstrap ran but expected output files were not generated."
    echo.
    echo [ERROR] Bootstrap completed but config.json and/or .env were not produced.
    echo         Suggestions:
    echo           - Re-run with --keep to inspect %REPO_DIR% and review the log.
    echo           - Make sure you completed all interactive prompts during Step 5.
    echo           - Check %LOG_FILE% for PowerShell errors.
    set "EXIT_CODE=81"
)

:cleanup_and_exit

REM ---- Step 7: Clean up staging folder --------------------------------------
call :phase "7/7" "Cleanup"
if "%KEEP%"=="1" (
    call :log "Keep flag set or final target missing. Staging folder preserved at %DEST%."
    echo.
    echo Staging folder preserved at: %DEST%
) else (
    call :log "Removing staging folder %DEST%"
    echo.
    echo Cleaning up %DEST% ...
    REM Save log file before deleting DEST.
    if exist "%LOG_FILE%" (
        if exist "%TEMP%\dev-bootstrap-first-run.log" del /F /Q "%TEMP%\dev-bootstrap-first-run.log" >nul 2>nul
        copy /Y "%LOG_FILE%" "%TEMP%\dev-bootstrap-first-run.log" >nul 2>nul
    )
    cd /D "%SystemDrive%\" >nul 2>nul
    rmdir /S /Q "%DEST%" >nul 2>nul
    if exist "%DEST%" (
        echo [WARN] Could not fully remove %DEST%. Delete it manually if needed.
    ) else (
        echo Staging folder removed.
        echo Log saved to: %TEMP%\dev-bootstrap-first-run.log
    )
)

echo.
if "%EXIT_CODE%"=="0" (
    echo ============================================================
    echo  dev-bootstrap first-run completed successfully.
    echo ============================================================
) else (
    echo ============================================================
    echo  dev-bootstrap first-run FAILED with exit code %EXIT_CODE%.
    echo ============================================================
)

echo.
if exist "%LOCK_FILE%" del /F /Q "%LOCK_FILE%" >nul 2>nul
pause
endlocal & exit /b %EXIT_CODE%


REM ============================================================================
REM Subroutines
REM ============================================================================

:log
>> "%LOG_FILE%" <nul set /p "=[%DATE% %TIME%] %~1"
>> "%LOG_FILE%" echo(
exit /b 0

:phase
echo.
echo ------------------------------------------------------------
echo [PHASE %~1] %~2
echo ------------------------------------------------------------
call :log "PHASE %~1 - %~2"
exit /b 0

:debug
if "%DEBUG%"=="1" echo [DEBUG] %~1
call :log "DEBUG: %~1"
exit /b 0

:refresh_path
REM Refresh PATH from the registry so newly installed tools (pwsh) are visible.
for /F "tokens=2*" %%A in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v Path 2^>nul ^| findstr /I "Path"') do set "SYS_PATH=%%B"
for /F "tokens=2*" %%A in ('reg query "HKCU\Environment" /v Path 2^>nul ^| findstr /I "Path"') do set "USR_PATH=%%B"
if defined SYS_PATH set "PATH=%SYS_PATH%;%USR_PATH%"
exit /b 0

:write_vbs_unzip
> "%VBS_FILE%" echo Option Explicit
>> "%VBS_FILE%" echo Dim sZip, sDest, oFS, oShell, oZip, oDest
>> "%VBS_FILE%" echo If WScript.Arguments.Count ^< 2 Then WScript.Quit 1
>> "%VBS_FILE%" echo sZip  = WScript.Arguments(0)
>> "%VBS_FILE%" echo sDest = WScript.Arguments(1)
>> "%VBS_FILE%" echo Set oFS = CreateObject("Scripting.FileSystemObject")
>> "%VBS_FILE%" echo If Not oFS.FolderExists(sDest) Then oFS.CreateFolder(sDest)
>> "%VBS_FILE%" echo Set oShell = CreateObject("Shell.Application")
>> "%VBS_FILE%" echo Set oZip   = oShell.NameSpace(sZip)
>> "%VBS_FILE%" echo Set oDest  = oShell.NameSpace(sDest)
>> "%VBS_FILE%" echo If oZip Is Nothing Then WScript.Quit 2
>> "%VBS_FILE%" echo If oDest Is Nothing Then WScript.Quit 3
>> "%VBS_FILE%" echo oDest.CopyHere oZip.Items, 16
>> "%VBS_FILE%" echo WScript.Quit 0
exit /b 0
