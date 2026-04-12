@echo off
chcp 65001 >nul
setlocal EnableDelayedExpansion

set "FLUTTER=C:\flutter\bin\flutter.bat"

:: Bat dosyasinin bulundugu klasoru proje dizini olarak al
pushd "%~dp0"
set "PROJECT=%CD%"
popd

echo ================================
echo   BUZZA ADMIN
echo ================================
echo Project : %PROJECT%
echo.

if not exist "%FLUTTER%" (
  echo ERROR: Flutter bulunamadi: %FLUTTER%
  pause & exit /b 1
)

echo Eski proses kapatiliyor...
taskkill /F /IM buzza_admin.exe >nul 2>&1
timeout /t 1 /nobreak >nul

echo Build kalintilari temizleniyor...

if exist "%PROJECT%\build\windows\x64\CMakeCache.txt" (
  del /f /q "%PROJECT%\build\windows\x64\CMakeCache.txt" >nul 2>&1
  echo  - CMakeCache.txt silindi.
)
if exist "%PROJECT%\build\windows\x64\CMakeFiles" (
  rmdir /s /q "%PROJECT%\build\windows\x64\CMakeFiles" >nul 2>&1
  echo  - CMakeFiles silindi.
)
if exist "%PROJECT%\windows\flutter\ephemeral" (
  rmdir /s /q "%PROJECT%\windows\flutter\ephemeral" >nul 2>&1
  echo  - windows\flutter\ephemeral silindi.
)
if exist "%PROJECT%\linux\flutter\ephemeral" (
  rmdir /s /q "%PROJECT%\linux\flutter\ephemeral" >nul 2>&1
  echo  - linux\flutter\ephemeral silindi.
)

echo.
echo Proje dizinine geciliyor...
cd /d "%PROJECT%"
if errorlevel 1 (
  echo ERROR: Proje dizinine girilemedi: %PROJECT%
  pause & exit /b 1
)

echo Calisma dizini: %CD%
echo.

echo Bagimliliklar yukleniyor (pub get)...
call "%FLUTTER%" pub get
if errorlevel 1 (
  echo ERROR: pub get basarisiz.
  pause & exit /b 1
)

echo.
echo buzza_admin baslatiliyor...
call "%FLUTTER%" run -d windows

echo.
pause
