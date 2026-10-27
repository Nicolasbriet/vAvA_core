@echo off
rem demarrer.bat — lance la Chancellerie (panneau web du serveur vAvA).
rem Node.js est cherché d'abord à côté de ce fichier (node.exe ou node\node.exe), puis sur la machine ; absent ou plus
rem ancien que NODE_MIN (le bot Discord utilise le WebSocket de Node 22), il est téléchargé depuis nodejs.org (version LTS
rem fixée ci-dessous, empreinte SHA-256 vérifiée) dans node\node.exe. Téléchargement impossible : un Node.js plus ancien
rem déjà installé sert quand même (la Chancellerie démarre dès Node 18), sans le bot Discord.
rem Code de sortie 75 : la Chancellerie vient de se mettre à jour et demande à être relancée. Si la nouvelle version
rem s'arrête avant d'avoir démarré, l'ancienne est remise (data\updates\chancellerie-precedente) et relancée.
chcp 65001 >nul
title La Chancellerie - vAvA
set "CHANCELLERIE_HOME=%~dp0"
cd /d "%~dp0"
set "NODE_VERSION=v22.23.4"
set "NODE_MIN=22"
set "UPDATES=%~dp0data\updates"

rem NODE_EXE : premier Node.js en version NODE_MIN ou plus ; NODE_OLD : premier trop ancien, gardé en secours
set "NODE_EXE="
set "NODE_OLD="
if exist "%~dp0node.exe" call :essayer_node "%~dp0node.exe"
if not defined NODE_EXE if exist "%~dp0node\node.exe" call :essayer_node "%~dp0node\node.exe"
if not defined NODE_EXE (
  where node >nul 2>nul
  if not errorlevel 1 call :essayer_node node
)
if not defined NODE_EXE call :telecharger_node
if not defined NODE_EXE if defined NODE_OLD (
  echo.
  echo   Node.js %NODE_MIN% n'a pas pu etre telecharge : la Chancellerie demarre avec le Node.js deja installe,
  echo   sans le bot Discord. Mettez Node.js a jour ^(https://nodejs.org/, version LTS^) pour l'avoir.
  set "NODE_EXE=%NODE_OLD%"
)
if not defined NODE_EXE (
  echo.
  echo   Node.js est introuvable et n'a pas pu etre telecharge.
  echo   Installez-le depuis https://nodejs.org/ ^(version LTS^), ou posez node.exe a cote de ce fichier.
  echo.
  pause
  exit /b 1
)

:lancer
"%NODE_EXE%" "%~dp0index.js"
set "CODE=%errorlevel%"
if "%CODE%"=="75" goto lancer
if exist "%UPDATES%\chancellerie-a-verifier" (
  echo.
  echo   La nouvelle version de la Chancellerie n'a pas demarre : retour a la version precedente.
  rem /IS /IT : tout est recopié, même un fichier de même taille et de même date que celui qu'il remplace
  robocopy "%UPDATES%\chancellerie-precedente" "%~dp0." /E /IS /IT /XF demarrer.bat /NFL /NDL /NJH /NJS /NP >nul
  del "%UPDATES%\chancellerie-a-verifier"
  echo annulee> "%UPDATES%\chancellerie-annulee"
  goto lancer
)
echo.
echo   La Chancellerie est arretee.
pause
exit /b 0

:essayer_node
rem retient %1 s'il est en version NODE_MIN ou plus ; code 3 : trop ancien (gardé en secours) ; autre : inutilisable
"%~1" -e "process.exit(parseInt(process.versions.node, 10) >= %NODE_MIN% ? 0 : 3)" >nul 2>nul
set "NODE_CHECK=%errorlevel%"
if "%NODE_CHECK%"=="0" set "NODE_EXE=%~1"
if "%NODE_CHECK%"=="3" if not defined NODE_OLD set "NODE_OLD=%~1"
exit /b 0

:telecharger_node
echo.
echo   Node.js %NODE_MIN% ou plus recent est introuvable : telechargement de Node.js %NODE_VERSION% depuis nodejs.org...
powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; $base='https://nodejs.org/dist/'+$env:NODE_VERSION; $dir=Join-Path $env:CHANCELLERIE_HOME 'node'; New-Item -ItemType Directory -Force $dir | Out-Null; $exe=Join-Path $dir 'node.exe'; $tmp=$exe+'.partial'; Invoke-WebRequest -UseBasicParsing ($base+'/win-x64/node.exe') -OutFile $tmp; $sums=(Invoke-WebRequest -UseBasicParsing ($base+'/SHASUMS256.txt')).Content; $line=$sums.Split([char]10) | Where-Object { $_.Trim().EndsWith(' win-x64/node.exe') }; $expected=($line -split '\s+')[0]; $actual=(Get-FileHash $tmp -Algorithm SHA256).Hash.ToLower(); if (-not $expected -or $expected -ne $actual) { Remove-Item $tmp; throw 'empreinte de node.exe incorrecte' }; Move-Item -Force $tmp $exe"
if exist "%~dp0node\node.exe" call :essayer_node "%~dp0node\node.exe"
if defined NODE_EXE echo   Node.js est installe dans node\node.exe.
exit /b 0
