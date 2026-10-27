@echo off
rem demarrer.bat — lance la Chancellerie (panneau web du serveur vAvA).
rem Node.js est cherché d'abord à côté de ce fichier (node.exe ou node\node.exe), puis sur la machine ; absent, il est
rem téléchargé depuis nodejs.org (version LTS fixée ci-dessous, empreinte SHA-256 vérifiée) dans node\node.exe.
rem Code de sortie 75 : la Chancellerie vient de se mettre à jour et demande à être relancée. Si la nouvelle version
rem s'arrête avant d'avoir démarré, l'ancienne est remise (data\updates\chancellerie-precedente) et relancée.
chcp 65001 >nul
title La Chancellerie - vAvA
set "CHANCELLERIE_HOME=%~dp0"
cd /d "%~dp0"
set "NODE_VERSION=v22.12.0"
set "UPDATES=%~dp0data\updates"

set "NODE_EXE="
if exist "%~dp0node.exe" set "NODE_EXE=%~dp0node.exe"
if not defined NODE_EXE if exist "%~dp0node\node.exe" set "NODE_EXE=%~dp0node\node.exe"
if not defined NODE_EXE (
  where node >nul 2>nul
  if not errorlevel 1 set "NODE_EXE=node"
)
if not defined NODE_EXE call :telecharger_node
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

:telecharger_node
echo.
echo   Node.js est introuvable : telechargement de Node.js %NODE_VERSION% depuis nodejs.org...
powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; $base='https://nodejs.org/dist/'+$env:NODE_VERSION; $dir=Join-Path $env:CHANCELLERIE_HOME 'node'; New-Item -ItemType Directory -Force $dir | Out-Null; $exe=Join-Path $dir 'node.exe'; $tmp=$exe+'.partial'; Invoke-WebRequest -UseBasicParsing ($base+'/win-x64/node.exe') -OutFile $tmp; $sums=(Invoke-WebRequest -UseBasicParsing ($base+'/SHASUMS256.txt')).Content; $line=$sums.Split([char]10) | Where-Object { $_.Trim().EndsWith(' win-x64/node.exe') }; $expected=($line -split '\s+')[0]; $actual=(Get-FileHash $tmp -Algorithm SHA256).Hash.ToLower(); if (-not $expected -or $expected -ne $actual) { Remove-Item $tmp; throw 'empreinte de node.exe incorrecte' }; Move-Item -Force $tmp $exe"
if exist "%~dp0node\node.exe" (
  set "NODE_EXE=%~dp0node\node.exe"
  echo   Node.js est installe dans node\node.exe.
)
exit /b 0
