# ═══════════════════════════════════════════════════════════════════════════
# Installation Manuelle des Tables SQL - vAvA_core
# Script PowerShell pour installer les tables manquantes
# ═══════════════════════════════════════════════════════════════════════════

Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Installation des Tables SQL - vAvA_core Framework" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Configuration MySQL
Write-Host "Configuration de la connexion MySQL..." -ForegroundColor Yellow
$mysqlHost = Read-Host "Hôte MySQL (par défaut: localhost)"
if ([string]::IsNullOrWhiteSpace($mysqlHost)) { $mysqlHost = "localhost" }

$mysqlPort = Read-Host "Port MySQL (par défaut: 3306)"
if ([string]::IsNullOrWhiteSpace($mysqlPort)) { $mysqlPort = "3306" }

$mysqlUser = Read-Host "Utilisateur MySQL (par défaut: root)"
if ([string]::IsNullOrWhiteSpace($mysqlUser)) { $mysqlUser = "root" }

$mysqlPassword = Read-Host "Mot de passe MySQL" -AsSecureString
$mysqlPasswordPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($mysqlPassword)
)

$mysqlDatabase = Read-Host "Nom de la base de données (par défaut: s1_fivem)"
if ([string]::IsNullOrWhiteSpace($mysqlDatabase)) { $mysqlDatabase = "s1_fivem" }

Write-Host ""

# Chemin vers MySQL
$mysqlPath = "mysql"
$mysqlExe = Get-Command mysql -ErrorAction SilentlyContinue

if (-not $mysqlExe) {
    Write-Host "❌ MySQL non trouvé dans le PATH" -ForegroundColor Red
    Write-Host "Veuillez installer MySQL ou ajouter le dossier bin de MySQL au PATH" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Chemins courants :" -ForegroundColor Yellow
    Write-Host "  - C:\Program Files\MySQL\MySQL Server 8.0\bin" -ForegroundColor Gray
    Write-Host "  - C:\xampp\mysql\bin" -ForegroundColor Gray
    Write-Host "  - C:\wamp\bin\mysql\mysqlX.X.X\bin" -ForegroundColor Gray
    Write-Host ""
    $customPath = Read-Host "Entrez le chemin complet vers mysql.exe (ou laissez vide pour annuler)"
    
    if ([string]::IsNullOrWhiteSpace($customPath)) {
        Write-Host "❌ Installation annulée" -ForegroundColor Red
        exit 1
    }
    
    $mysqlPath = $customPath
}

# Fichiers SQL à installer
$sqlFiles = @(
    @{
        Name = "Système EMS"
        Path = "modules\ems\sql\ems_system.sql"
        Tables = "hospital_blood_stock, ems_medical_history, ems_invoices, ems_calls, etc."
    },
    @{
        Name = "Système de Clés"
        Path = "modules\keys\sql\keys_system.sql"
        Tables = "shared_vehicle_keys, vehicle_keys_history, vehicle_lockpick_attempts, etc."
    },
    @{
        Name = "Système Police"
        Path = "modules\police\sql\police_system.sql"
        Tables = "police_fines, police_criminal_records, police_prisoners, etc."
    },
    @{
        Name = "Player Manager"
        Path = "modules\player_manager\sql\player_manager.sql"
        Tables = "player_characters, player_appearance, player_licenses, etc."
    }
)

Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Fichiers SQL à installer :" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

foreach ($file in $sqlFiles) {
    Write-Host "  ✓ $($file.Name)" -ForegroundColor Green
    Write-Host "    Fichier: $($file.Path)" -ForegroundColor Gray
    Write-Host "    Tables: $($file.Tables)" -ForegroundColor DarkGray
    Write-Host ""
}

$confirm = Read-Host "Continuer l'installation? (O/N)"
if ($confirm -ne "O" -and $confirm -ne "o") {
    Write-Host "❌ Installation annulée" -ForegroundColor Red
    exit 0
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Installation en cours..." -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

$successCount = 0
$errorCount = 0

foreach ($file in $sqlFiles) {
    $filePath = Join-Path $PSScriptRoot $file.Path
    
    if (-not (Test-Path $filePath)) {
        Write-Host "  ❌ Fichier introuvable: $($file.Path)" -ForegroundColor Red
        $errorCount++
        continue
    }
    
    Write-Host "  📄 Installation: $($file.Name)..." -ForegroundColor Yellow
    
    # Exécuter le fichier SQL
    $arguments = @(
        "-h$mysqlHost",
        "-P$mysqlPort",
        "-u$mysqlUser",
        "-p$mysqlPasswordPlain",
        $mysqlDatabase,
        "-e",
        "source $filePath"
    )
    
    try {
        $process = Start-Process -FilePath $mysqlPath -ArgumentList $arguments -NoNewWindow -Wait -PassThru
        
        if ($process.ExitCode -eq 0) {
            Write-Host "  ✅ $($file.Name) installé avec succès!" -ForegroundColor Green
            $successCount++
        } else {
            Write-Host "  ❌ Erreur lors de l'installation de $($file.Name)" -ForegroundColor Red
            $errorCount++
        }
    } catch {
        Write-Host "  ❌ Erreur: $_" -ForegroundColor Red
        $errorCount++
    }
    
    Write-Host ""
}

Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Résumé de l'installation" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "  ✅ Installés avec succès: $successCount" -ForegroundColor Green
Write-Host "  ❌ Erreurs: $errorCount" -ForegroundColor Red
Write-Host ""

if ($errorCount -eq 0) {
    Write-Host "✅ Installation terminée avec succès!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Prochaines étapes:" -ForegroundColor Yellow
    Write-Host "  1. Vérifiez que les tables ont été créées dans votre base de données" -ForegroundColor Gray
    Write-Host "  2. Copiez les modules manquants (vAvA_police, vAvA_player_manager)" -ForegroundColor Gray
    Write-Host "  3. Redémarrez votre serveur FiveM" -ForegroundColor Gray
    Write-Host ""
} else {
    Write-Host "⚠️  Certaines installations ont échoué" -ForegroundColor Yellow
    Write-Host "Vérifiez les erreurs ci-dessus et réessayez" -ForegroundColor Yellow
    Write-Host ""
}

Write-Host "Appuyez sur une touche pour fermer..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
