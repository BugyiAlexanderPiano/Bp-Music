@echo off
rem ===========================================================================
rem  SoundNexus Pro - parancssori eszköz: egykattintásos indító Windowsra
rem  Ingyenes: a w64devkit (MinGW GCC) fordítót és az RtMidi forrást tölti le
rem  egyszer, a Windows beépített PowerShell-jével. Telepítés és admin jog nem kell.
rem  Ezt a fájlt az "als" projektmappa gyökerébe tedd (ahol a README.md van).
rem  Egy WAV fájlt rá is húzhatsz: akkor azonnal levágja.
rem ===========================================================================
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul
title SoundNexus Pro - parancssori eszköz
cd /d "%~dp0"

set "ROOT=%~dp0"
set "TOOLS=%ROOT%tools"
set "DEVKIT=%TOOLS%\w64devkit"
set "RT=%ROOT%third_party\rtmidi"
set "BIN=%ROOT%bin"
set "EXE=%BIN%\als_cli.exe"
set "DROPPED=%~1"

rem Kész program (pl. a GitHubról letöltött csomag): nincs letöltés, nincs fordítás
if exist "%EXE%" goto :ready

:setup
if not exist "%ROOT%app\main.cpp" (
  echo [HIBA] Nincs kész program és nem találom a forráskódot ^(app\main.cpp^).
  echo Tedd ezt a .bat fájlt a projektmappa gyökerébe, a README.md mellé,
  echo vagy töltsd le a kész Windows csomagot a GitHub Releases oldalról.
  pause
  exit /b 1
)

rem ---------------------------------------------------------------------------
rem  1. Fordító keresése vagy letöltése
rem ---------------------------------------------------------------------------
if exist "%DEVKIT%\bin\g++.exe" goto :have_devkit
where g++ >nul 2>&1
if not errorlevel 1 goto :have_compiler

echo.
echo  Első indítás: az ingyenes w64devkit fordító letöltése (kb. 100 MB, egyszer kell).
echo.
if not exist "%TOOLS%" mkdir "%TOOLS%"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; $r=Invoke-RestMethod -Uri 'https://api.github.com/repos/skeeto/w64devkit/releases/latest' -Headers @{'User-Agent'='als-setup'}; $a=$r.assets | Where-Object { $_.name -like '*x64*.exe' } | Select-Object -First 1; if(-not $a){ throw 'No x64 package found' }; Write-Host ('  Downloading ' + $a.name + ' ...'); Invoke-WebRequest -Uri $a.browser_download_url -OutFile '%TOOLS%\w64devkit-setup.exe' -UseBasicParsing"
if errorlevel 1 goto :download_failed

echo  Kicsomagolás...
"%TOOLS%\w64devkit-setup.exe" -o"%TOOLS%" -y >nul
if not exist "%DEVKIT%\bin\g++.exe" goto :extract_failed
del "%TOOLS%\w64devkit-setup.exe" >nul 2>&1

:have_devkit
set "PATH=%DEVKIT%\bin;%PATH%"

:have_compiler

rem ---------------------------------------------------------------------------
rem  2. RtMidi forrás (USB-MIDI a hangszerhez) - ha nem sikerül, demó mód marad
rem ---------------------------------------------------------------------------
if exist "%RT%\RtMidi.cpp" goto :have_rtmidi
echo  RtMidi letöltése (USB-MIDI kapcsolathoz)...
if not exist "%RT%" mkdir "%RT%"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; $b='https://raw.githubusercontent.com/thestk/rtmidi/6.0.0/'; Invoke-WebRequest -Uri ($b+'RtMidi.h') -OutFile '%RT%\RtMidi.h' -UseBasicParsing; Invoke-WebRequest -Uri ($b+'RtMidi.cpp') -OutFile '%RT%\RtMidi.cpp' -UseBasicParsing"
if errorlevel 1 (
  echo  [FIGYELEM] Az RtMidi nem tölthető le: a program hangszer nélküli módban fordul.
  del "%RT%\RtMidi.cpp" >nul 2>&1
)
:have_rtmidi

rem ---------------------------------------------------------------------------
rem  3. Fordítás (csak ha még nincs kész program)
rem ---------------------------------------------------------------------------
call :build
if not exist "%EXE%" (
  echo [HIBA] A fordítás nem sikerült. A hibaüzenet fent látható.
  pause
  exit /b 1
)

:ready
rem WAV a .bat ikonjára húzva: azonnali vágás
if not "%DROPPED%"=="" (
  set "WAV=%DROPPED%"
  call :do_trim
  pause
  exit /b 0
)

rem ---------------------------------------------------------------------------
rem  4. Menü
rem ---------------------------------------------------------------------------
:menu
echo.
echo  ================================================================
echo    SoundNexus Pro - parancssori eszköz
echo  ================================================================
echo    1  Bemutató hangszer nélkül (demo)
echo    2  MIDI portok listája
echo    3  Élő mód a hangszerrel (USB-MIDI)
echo    4  WAV sample vágása
echo    5  Stílus hangerő-normalizálás (CC7 számítás)
echo    6  Újrafordítás (ha módosítottad a kódot)
echo    0  Kilépés
echo  ================================================================
set "CH="
set /p "CH=  Válassz: "
if "%CH%"=="1" goto :m_demo
if "%CH%"=="2" goto :m_ports
if "%CH%"=="3" goto :m_live
if "%CH%"=="4" goto :m_trim
if "%CH%"=="5" goto :m_norm
if "%CH%"=="6" goto :m_rebuild
if "%CH%"=="0" exit /b 0
goto :menu

:m_demo
"%EXE%" demo
goto :menu

:m_ports
"%EXE%" ports
goto :menu

:m_live
"%EXE%" ports
if errorlevel 1 goto :menu
echo.
set "PIN=" & set "POUT="
set /p "PIN=  Bemeneti port száma (a hangszer, pl. 0): "
set /p "POUT=  Kimeneti port száma (a hangszer, pl. 1): "
if "%PIN%"=="" goto :menu
if "%POUT%"=="" goto :menu
"%EXE%" live %PIN% %POUT%
goto :menu

:m_trim
set "WAV="
set /p "WAV=  Húzd ide a WAV fájlt, majd nyomj Entert: "
if "!WAV!"=="" goto :menu
call :do_trim
goto :menu

:m_norm
set "LUFS=" & set "CCS="
set /p "LUFS=  Mért hangerő LUFS-ben (pl. -22.5): "
set /p "CCS=  A részek CC7 értékei szóközzel (pl. 100 90 110 80): "
if "%LUFS%"=="" goto :menu
"%EXE%" normalize %LUFS% %CCS%
goto :menu

:m_rebuild
del "%EXE%" >nul 2>&1
goto :setup

rem ---------------------------------------------------------------------------
rem  Segédrutinok
rem ---------------------------------------------------------------------------
:do_trim
set "WAV=!WAV:"=!"
if not exist "!WAV!" (
  echo  [HIBA] Nem található: !WAV!
  goto :eof
)
for %%F in ("!WAV!") do set "OUTWAV=%%~dpnF_vagott%%~xF"
"%EXE%" trim "!WAV!" "!OUTWAV!"
if not errorlevel 1 echo  Mentve: !OUTWAV!
goto :eof

:build
echo.
echo  Fordítás folyamatban (1-2 perc)...
if not exist "%BIN%" mkdir "%BIN%"
set "SRC=app\main.cpp core\src\midi_transport.cpp core\src\rtmidi_transport.cpp core\src\soft_registration.cpp core\src\wav_io.cpp core\src\dsp\sample_trimmer.cpp core\src\dsp\style_normalizer.cpp core\src\dsp\loop_finder.cpp"
set "FLAGS=-std=c++17 -O2 -static -Icore\include -D__USE_MINGW_ANSI_STDIO=1"
if exist "%RT%\RtMidi.cpp" (
  g++ %FLAGS% -DALS_WITH_RTMIDI -D__WINDOWS_MM__ -I"%RT%" %SRC% "%RT%\RtMidi.cpp" -o "%EXE%" -lwinmm
) else (
  g++ %FLAGS% %SRC% -o "%EXE%"
)
if errorlevel 1 (
  del "%EXE%" >nul 2>&1
  echo  [HIBA] Fordítási hiba.
) else (
  echo  Kész: !EXE!
)
goto :eof

:download_failed
echo.
echo  [HIBA] A fordító letöltése nem sikerült (nincs internet, vagy a GitHub nem elérhető).
echo  Kézi megoldás: töltsd le a "w64devkit-x64-....exe" fájlt innen:
echo    https://github.com/skeeto/w64devkit/releases
echo  és csomagold ki ide: %TOOLS%
echo  (a végén léteznie kell ennek: %DEVKIT%\bin\g++.exe), majd indítsd újra ezt a fájlt.
pause
exit /b 1

:extract_failed
echo.
echo  [HIBA] A kicsomagolás nem sikerült.
echo  Kattints duplán erre: %TOOLS%\w64devkit-setup.exe
echo  és célmappának add meg: %TOOLS%
echo  Utána indítsd újra ezt a fájlt.
pause
exit /b 1
