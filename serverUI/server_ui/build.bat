@echo off
REM Build script per Sinergy Work Server Manager
REM Questo script semplifica la compilazione dell'applicazione

setlocal enabledelayedexpansion

if "%1"=="" goto :help
if /i "%1"=="help" goto :help
if /i "%1"=="run" goto :run
if /i "%1"=="build" goto :build
if /i "%1"=="clean" goto :clean

:help
echo.
echo === Sinergy Work Server Manager - Build Script ===
echo.
echo Comandi disponibili:
echo.
echo   run     - Esegue l'applicazione in modalità debug
echo   build   - Compila l'applicazione per Windows (release)
echo   clean   - Pulisce i file di build
echo   help    - Mostra questo messaggio
echo.
echo Esempi:
echo   build.bat run
echo   build.bat build
echo   build.bat clean
echo.
goto :end

:run
echo.
echo === Avvio applicazione ===
echo.
call flutter pub get
if errorlevel 1 goto :error
call flutter run -d windows
goto :end

:build
echo.
echo === Compilazione per Windows ===
echo.
call flutter pub get
if errorlevel 1 goto :error
call flutter build windows --release
if errorlevel 1 goto :error
echo.
echo Compilazione completata!
echo Eseguibile: build\windows\x64\runner\Release\server_ui.exe
echo.
goto :end

:clean
echo.
echo === Pulizia build ===
echo.
if exist "build" rmdir /s /q "build"
if exist ".dart_tool" rmdir /s /q ".dart_tool"
echo Pulizia completata!
echo.
goto :end

:error
echo.
echo Errore durante l'esecuzione!
echo.
exit /b 1

:end
endlocal
