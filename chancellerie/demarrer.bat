@echo off
rem demarrer.bat — lance la Chancellerie (panneau web du serveur vAvA).
rem Node.js est cherché d'abord à côté de ce fichier (node.exe ou node\node.exe), puis sur la machine.
chcp 65001 >nul
title La Chancellerie - vAvA
set "CHANCELLERIE_HOME=%~dp0"
cd /d "%~dp0"

set "NODE_EXE="
if exist "%~dp0node.exe" set "NODE_EXE=%~dp0node.exe"
if not defined NODE_EXE if exist "%~dp0node\node.exe" set "NODE_EXE=%~dp0node\node.exe"
if not defined NODE_EXE (
  where node >nul 2>nul
  if errorlevel 1 (
    echo.
    echo   Node.js est introuvable.
    echo   Installez-le depuis https://nodejs.org/ ^(version LTS^), ou posez node.exe a cote de ce fichier.
    echo.
    pause
    exit /b 1
  )
  set "NODE_EXE=node"
)

"%NODE_EXE%" "%~dp0index.js"
echo.
echo   La Chancellerie est arretee.
pause
