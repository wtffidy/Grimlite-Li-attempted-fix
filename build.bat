@echo off
setlocal EnableExtensions
title Grimlite-Li local build

rem ============================================================
rem  Local build for Grimlite-Li-attempted-fix (.NET Framework)
rem  Usage: build.bat [Configuration]   (default: Release)
rem ============================================================

cd /d "%~dp0"

set "CONFIG=%~1"
if not defined CONFIG set "CONFIG=Release"

set "SLN=Project Grimlite.sln"
set "OUTPUT=%~dp0bin\%CONFIG%"
set "EXE=%OUTPUT%\Grimoire.exe"
set "START_TICKS="
set "ELAPSED="

rem ---------- Start stopwatch ----------
for /f %%i in ('powershell -NoProfile -Command "[Diagnostics.Stopwatch]::GetTimestamp()" 2^>nul') do set "START_TICKS=%%i"

if not exist "%SLN%" goto :nosln

rem ---------- 1. Pull latest fork changes ----------
echo.
echo ============================================================
echo Updating from GitHub...
echo ============================================================

where git >nul 2>&1
if errorlevel 1 goto :nogit

git rev-parse --is-inside-work-tree >nul 2>&1
if errorlevel 1 goto :nogit

for /f "delims=" %%i in ('git branch --show-current') do set "BRANCH=%%i"
if not defined BRANCH goto :nobranch

echo Branch: %BRANCH%
git pull --ff-only origin "%BRANCH%"
if errorlevel 1 goto :pullfailed

rem ---------- 2. Locate MSBuild ----------
set "MSBUILD="
set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"

if exist "%VSWHERE%" for /f "usebackq delims=" %%i in (`"%VSWHERE%" -latest -prerelease -products * -requires Microsoft.Component.MSBuild -find MSBuild\**\Bin\MSBuild.exe`) do set "MSBUILD=%%i"

if not defined MSBUILD for /f "delims=" %%i in ('where msbuild 2^>nul') do if not defined MSBUILD set "MSBUILD=%%i"
if not defined MSBUILD goto :nomsbuild

echo Using MSBuild: %MSBUILD%

rem ---------- 3. Locate or download NuGet ----------
set "NUGET="
for /f "delims=" %%i in ('where nuget 2^>nul') do if not defined NUGET set "NUGET=%%i"

if not defined NUGET set "NUGET=%~dp0.nuget\nuget.exe"
if exist "%NUGET%" goto :restore

echo Downloading nuget.exe...
if not exist "%~dp0.nuget" mkdir "%~dp0.nuget"

powershell -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol='Tls12'; Invoke-WebRequest 'https://dist.nuget.org/win-x86-commandline/latest/nuget.exe' -OutFile '%NUGET%'"
if errorlevel 1 goto :nonuget

rem ---------- 4. Restore packages ----------
:restore
echo.
echo ============================================================
echo Restoring NuGet packages...
echo ============================================================

"%NUGET%" restore "%SLN%" -NonInteractive
if errorlevel 1 goto :fail

rem ---------- 5. Rebuild ----------
echo.
echo ============================================================
echo Building %SLN% [%CONFIG%]...
echo ============================================================

"%MSBUILD%" "%SLN%" /t:Rebuild /p:Configuration=%CONFIG% /p:GenerateManifests=false /m /v:minimal
if errorlevel 1 goto :fail

rem ---------- 6. Report time and launch ----------
call :showtime

echo.
echo ============================================================
echo BUILD SUCCEEDED!
echo Output: %EXE%
echo ============================================================

if exist "%EXE%" (
    echo Launching Grimoire...
    start "" "%EXE%"
) else (
    echo WARNING: Grimoire.exe was not found.
    if exist "%OUTPUT%" start "" explorer "%OUTPUT%"
)

exit /b 0

rem ============================================================
rem  Error handling
rem ============================================================

:nosln
echo ERROR: "%SLN%" not found in %CD%
goto :fail

:nogit
echo ERROR: Git is unavailable or this folder is not a Git repository.
goto :fail

:nobranch
echo ERROR: Could not determine the current Git branch.
goto :fail

:pullfailed
echo ERROR: Could not update from origin.
echo Check GitHub authentication and local changes.
goto :fail

:nomsbuild
echo ERROR: MSBuild not found. Install Visual Studio Build Tools with the .NET desktop workload.
goto :fail

:nonuget
echo ERROR: Could not download nuget.exe.
goto :fail

:fail
call :showtime
echo.
echo BUILD FAILED.
pause
exit /b 1

rem ---------- Stopwatch display ----------
:showtime
if not defined START_TICKS exit /b

for /f "delims=" %%i in ('powershell -NoProfile -Command "$seconds = ([Diagnostics.Stopwatch]::GetTimestamp() - [long]%START_TICKS%) / [Diagnostics.Stopwatch]::Frequency; [TimeSpan]::FromSeconds($seconds).ToString('hh\:mm\:ss\.fff')" 2^>nul') do set "ELAPSED=%%i"

if defined ELAPSED echo Elapsed time: %ELAPSED%
exit /b