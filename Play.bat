@echo off
setlocal EnableExtensions

rem One-click launcher, driven from the server checkout like redmoonrising's
rem (3913) and EveJS' (3396210) Play.bat: start the trinity compose stack, wait
rem for the game port, then start the 45017 client against 127.0.0.1:26000.
rem
rem Usage:
rem     Play.bat              start the server and the client
rem     Play.bat --no-client  start the server only
rem
rem Environment overrides:
rem     TRINITY_CLIENT_DIR    client directory (default below)
rem
rem The client is launched as bin\ExeFile.exe with /server:127.0.0.1 /port:26000
rem (loginII.py reads both switches), not through eve.exe. The bootstrapper is
rem skipped so a local run never checks for or downloads an update; the game
rem build stays fixed at 45017.
rem
rem docker-compose.yml pins the project name to "trinity", so every checkout
rem drives the same containers. Running this from a worktree therefore
rem recreates them from that worktree's tree; the main checkout stays the
rem normal place to run it.

set "TRINITY_DIR=%~dp0"
if "%TRINITY_DIR:~-1%"=="\" set "TRINITY_DIR=%TRINITY_DIR:~0,-1%"

if not defined TRINITY_CLIENT_DIR set "TRINITY_CLIENT_DIR=M:\EVE-LOCAL\inputs\EVE-Online-45017"

set "PLAY_SERVER_ONLY=0"
if /i "%~1"=="--no-client" set "PLAY_SERVER_ONLY=1"

echo [1/3] Starting trinity from "%TRINITY_DIR%" ...
pushd "%TRINITY_DIR%" || goto :no_dir
docker compose up -d
if errorlevel 1 (
    popd
    echo.
    echo Failed to start trinity.
    echo If port 26000 or 5432 is busy, stop EveJS or redmoonrising first:
    echo     docker ps
    pause
    exit /b 1
)
popd

echo [2/3] Waiting for 127.0.0.1:26000 (first start imports the database) ...
powershell -NoProfile -Command "$end=(Get-Date).AddMinutes(10); while((Get-Date) -lt $end){ try{ $c=New-Object Net.Sockets.TcpClient; $c.Connect('127.0.0.1',26000); $c.Close(); exit 0 }catch{ Start-Sleep -Milliseconds 500 } }; exit 1"
if errorlevel 1 (
    echo Server did not open port 26000. Check logs with:
    echo     docker compose logs server --tail 100
    pause
    exit /b 1
)

if "%PLAY_SERVER_ONLY%"=="1" (
    echo [3/3] Skipping client ^(--no-client^).
    exit /b 0
)

if not exist "%TRINITY_CLIENT_DIR%\bin\ExeFile.exe" (
    echo.
    echo Client not found: "%TRINITY_CLIENT_DIR%\bin\ExeFile.exe"
    echo Set TRINITY_CLIENT_DIR to the client directory and run Play.bat again.
    pause
    exit /b 1
)

echo [3/3] Launching client from "%TRINITY_CLIENT_DIR%" ...
pushd "%TRINITY_CLIENT_DIR%" || goto :no_dir
start "" "%TRINITY_CLIENT_DIR%\bin\ExeFile.exe" /server:127.0.0.1 /port:26000
popd
exit /b 0

:no_dir
echo Directory not found.
pause
exit /b 1
