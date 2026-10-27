# vAvA_core

Core FiveM 100 % maison pour un serveur RP médiéval : Lua 5.4, OneSync, `oxmysql` comme seule dépendance.
Aucun framework tiers (ni ESX, ni QBCore, ni Qbox, ni ox_core).

## Contenu

| Dossier | Rôle |
| --- | --- |
| racine (`fxmanifest.lua`, `server/`, `client/`, `shared/`, `config/`) | La ressource `vAvA_core` : logger, base de données, migrations, RPC, limites de débit, hooks, registres, modules, joueurs et personnages |
| `modules/` | Les modules du royaume : apparence, sélection et création de personnage, HUD, inventaire, faim et soif, santé, Registre du Conseil, chat vocal, monde sans PNJ, caméras, pont de la Chancellerie |
| `examples/` | Modules d'exemple et outils de développement |
| `chancellerie/` | La Chancellerie, panneau web autonome (Node.js, sans dépendance) qui configure, lance et surveille FXServer |
| `docs/` | [API des modules](docs/api.md) et [guide de la Chancellerie](docs/chancellerie.md) |

## Prérequis

- FXServer récent avec OneSync ;
- MySQL ou MariaDB, et la ressource `oxmysql` ;
- Node.js LTS 18 ou plus récent pour la Chancellerie.

## Installation

Le plus simple est de passer par la Chancellerie : copiez seulement le dossier `chancellerie/` sur la machine et lancez
`demarrer.sh` (Linux) ou `demarrer.bat` (Windows). Elle installe le reste (Node.js s'il manque, FXServer, oxmysql, vAvA depuis ce dépôt), crée la base,
écrit le `server.cfg`, lance le serveur, puis propose chaque nouvelle version poussée ici et l'applique sans casser le
serveur (réglages gardés, contrôle, retour arrière). Seul MySQL / MariaDB reste à installer soi-même.
Voir [docs/chancellerie.md](docs/chancellerie.md).

À la main : placer `vAvA_core` et chaque module dans `resources/`, puis les démarrer dans cet ordre, après
`oxmysql` : `vAvA_core`, `vava_world`, `vava_appearance`, `vava_characters_ui`, `vava_hud`, `vava_inventory`,
`vava_needs`, `vava_health`, `vava_admin`, `vava_voice`, `vava_cameras`, `vava_chancellerie`.

Le `server.cfg` contient la clé de licence et le mot de passe de la base : il ne doit jamais être publié.
