@echo off
chcp 65001 >nul
title vAvA_core - Installateur
color 0B

echo.
echo  ██╗   ██╗ █████╗ ██╗   ██╗ █████╗         ██████╗ ██████╗ ██████╗ ███████╗
echo  ██║   ██║██╔══██╗██║   ██║██╔══██╗       ██╔════╝██╔═══██╗██╔══██╗██╔════╝
echo  ██║   ██║███████║██║   ██║███████║       ██║     ██║   ██║██████╔╝█████╗  
echo  ╚██╗ ██╔╝██╔══██║╚██╗ ██╔╝██╔══██║       ██║     ██║   ██║██╔══██╗██╔══╝  
echo   ╚████╔╝ ██║  ██║ ╚████╔╝ ██║  ██║███████╚██████╗╚██████╔╝██║  ██║███████╗
echo    ╚═══╝  ╚═╝  ╚═╝  ╚═══╝  ╚═╝  ╚═╝╚══════╝╚═════╝ ╚═════╝ ╚═╝  ╚═╝╚══════╝
echo.
echo                         Framework FiveM - Installateur
echo                         ══════════════════════════════
echo.

:: Vérifier si on est admin
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [!] Ce script nécessite les droits administrateur.
    echo     Clic droit ^> Exécuter en tant qu'administrateur
    pause
    exit /b 1
)

:: Variables
set "INSTALL_DIR=%~dp0"
set "CONFIG_FILE=%INSTALL_DIR%config\config.lua"

echo [1/6] Vérification des prérequis...
echo.

:: Vérifier si MySQL est installé
where mysql >nul 2>&1
if %errorLevel% neq 0 (
    echo [!] MySQL n'est pas détecté dans le PATH.
    echo     Assurez-vous que XAMPP/MySQL est installé.
    echo.
    set /p MYSQL_PATH="Entrez le chemin vers mysql.exe (ex: C:\xampp\mysql\bin\mysql.exe): "
) else (
    set "MYSQL_PATH=mysql"
)

echo.
echo [2/6] Configuration de la base de données...
echo.

set /p DB_HOST="Hôte MySQL [localhost]: " || set "DB_HOST=localhost"
if "%DB_HOST%"=="" set "DB_HOST=localhost"

set /p DB_USER="Utilisateur MySQL [root]: " || set "DB_USER=root"
if "%DB_USER%"=="" set "DB_USER=root"

set /p DB_PASS="Mot de passe MySQL [vide]: "

set /p DB_NAME="Nom de la base de données [vava_core]: " || set "DB_NAME=vava_core"
if "%DB_NAME%"=="" set "DB_NAME=vava_core"

echo.
echo [3/6] Création de la base de données...
echo.

:: Créer la base de données
if "%DB_PASS%"=="" (
    "%MYSQL_PATH%" -h %DB_HOST% -u %DB_USER% -e "CREATE DATABASE IF NOT EXISTS `%DB_NAME%` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" 2>nul
) else (
    "%MYSQL_PATH%" -h %DB_HOST% -u %DB_USER% -p%DB_PASS% -e "CREATE DATABASE IF NOT EXISTS `%DB_NAME%` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" 2>nul
)

if %errorLevel% neq 0 (
    echo [X] Erreur lors de la création de la base de données.
    echo     Vérifiez vos identifiants MySQL.
    pause
    exit /b 1
)

echo [OK] Base de données '%DB_NAME%' créée.

echo.
echo [4/6] Import des tables SQL...
echo.

:: Importer le SQL (sans le trigger pour éviter les problèmes DELIMITER)
if "%DB_PASS%"=="" (
    "%MYSQL_PATH%" -h %DB_HOST% -u %DB_USER% %DB_NAME% < "%INSTALL_DIR%database\sql\init_simple.sql" 2>nul
) else (
    "%MYSQL_PATH%" -h %DB_HOST% -u %DB_USER% -p%DB_PASS% %DB_NAME% < "%INSTALL_DIR%database\sql\init_simple.sql" 2>nul
)

if %errorLevel% neq 0 (
    echo [!] Erreur lors de l'import SQL. Import manuel requis.
) else (
    echo [OK] Tables importées avec succès.
)

echo.
echo [5/6] Configuration du framework...
echo.

set /p SERVER_NAME="Nom de votre serveur [vAvA RP]: " || set "SERVER_NAME=vAvA RP"
if "%SERVER_NAME%"=="" set "SERVER_NAME=vAvA RP"

set /p DISCORD_WEBHOOK="Webhook Discord pour les logs (optionnel): "

set /p STARTING_CASH="Argent de départ - Cash [5000]: " || set "STARTING_CASH=5000"
if "%STARTING_CASH%"=="" set "STARTING_CASH=5000"

set /p STARTING_BANK="Argent de départ - Banque [10000]: " || set "STARTING_BANK=10000"
if "%STARTING_BANK%"=="" set "STARTING_BANK=10000"

set /p DEFAULT_LANG="Langue par défaut (fr/en/es) [fr]: " || set "DEFAULT_LANG=fr"
if "%DEFAULT_LANG%"=="" set "DEFAULT_LANG=fr"

echo.
echo [6/6] Génération des fichiers de configuration...
echo.

:: Créer le fichier de connexion string
echo -- Configuration MySQL générée par l'installateur > "%INSTALL_DIR%mysql_connection.txt"
echo. >> "%INSTALL_DIR%mysql_connection.txt"
echo set mysql_connection_string "mysql://%DB_USER%:%DB_PASS%@%DB_HOST%/%DB_NAME%?charset=utf8mb4" >> "%INSTALL_DIR%mysql_connection.txt"
echo. >> "%INSTALL_DIR%mysql_connection.txt"
echo -- À ajouter dans votre server.cfg >> "%INSTALL_DIR%mysql_connection.txt"

echo [OK] Fichier mysql_connection.txt créé.

:: Créer un server.cfg exemple
(
echo # ═══════════════════════════════════════════════════════════════════════════
echo # vAvA_core - Configuration Serveur
echo # Généré par l'installateur
echo # ═══════════════════════════════════════════════════════════════════════════
echo.
echo # Informations serveur
echo sv_hostname "%SERVER_NAME%"
echo sv_maxclients 32
echo.
echo # Endpoints
echo endpoint_add_tcp "0.0.0.0:30120"
echo endpoint_add_udp "0.0.0.0:30120"
echo.
echo # Clé de licence ^(https://keymaster.fivem.net/^)
echo sv_licenseKey "VOTRE_CLE_ICI"
echo.
echo # Base de données MySQL
echo set mysql_connection_string "mysql://%DB_USER%:%DB_PASS%@%DB_HOST%/%DB_NAME%?charset=utf8mb4"
echo.
echo # Ressources de base
echo ensure mapmanager
echo ensure chat
echo ensure spawnmanager
echo ensure sessionmanager
echo ensure basic-gamemode
echo ensure hardcap
echo.
echo # oxmysql ^(requis^)
echo ensure oxmysql
echo.
echo # vAvA_core
echo ensure vAvA_core
echo.
echo # Sécurité
echo sv_scriptHookAllowed 0
echo sv_enableNetworkedPhoneExplosions 0
) > "%INSTALL_DIR%server.cfg.example"

echo [OK] Fichier server.cfg.example créé.

echo.
echo  ══════════════════════════════════════════════════════════════════════════
echo                         INSTALLATION TERMINÉE !
echo  ══════════════════════════════════════════════════════════════════════════
echo.
echo  Prochaines étapes :
echo.
echo  1. Téléchargez oxmysql :
echo     https://github.com/overextended/oxmysql/releases
echo.
echo  2. Copiez 'vAvA_core' dans votre dossier resources/[local]/
echo.
echo  3. Copiez le contenu de 'server.cfg.example' dans votre server.cfg
echo.
echo  4. Obtenez une clé de licence sur https://keymaster.fivem.net/
echo.
echo  5. Lancez votre serveur !
echo.
echo  ══════════════════════════════════════════════════════════════════════════
echo.
echo  Connexion MySQL : mysql://%DB_USER%:%DB_PASS%@%DB_HOST%/%DB_NAME%
echo.
pause
