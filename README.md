# vAvA_core

Core FiveM 100 % maison pour un serveur RP médiéval : Lua 5.4, OneSync, `oxmysql` comme seule dépendance.
Aucun framework tiers (ni ESX, ni QBCore, ni Qbox, ni ox_core).

## Contenu

| Dossier | Rôle |
| --- | --- |
| racine (`fxmanifest.lua`, `server/`, `client/`, `shared/`, `config/`) | La ressource `vAvA_core` : logger, base de données, migrations, RPC, limites de débit, hooks, registres, modules, joueurs et personnages |
| `modules/` | Les modules du royaume : chat, apparence, sélection et création de personnage, HUD, inventaire, faim et soif, santé, Registre du Conseil, chat vocal, monde sans PNJ, ciel et heure (heure de Paris, saisons, météo), caméras, magie, compétences (fondation des métiers), récolte, artisanat, agriculture, Codex (toutes les commandes et touches), pont de la Chancellerie |
| `examples/` | Modules d'exemple et outils de développement |
| `chancellerie/` | La Chancellerie, panneau web autonome (Node.js, sans dépendance) qui configure, lance et surveille FXServer |
| `docs/` | [API des modules](docs/api.md) et [guide de la Chancellerie](docs/chancellerie.md) |

## Prérequis

- FXServer récent avec OneSync ;
- MySQL ou MariaDB, et la ressource `oxmysql` ;
- Node.js 22 ou plus récent pour la Chancellerie (18 suffit sans le bot Discord) ; ses lanceurs l'installent s'il
  manque ou s'il est trop ancien.

## Installation

Le plus simple est de passer par la Chancellerie : copiez seulement le dossier `chancellerie/` sur la machine et lancez
`demarrer.sh` (Linux) ou `demarrer.bat` (Windows). Elle installe le reste (Node.js s'il manque, FXServer, oxmysql, vAvA depuis ce dépôt), crée la base,
écrit le `server.cfg`, lance le serveur, puis propose chaque nouvelle version poussée ici et l'applique sans casser le
serveur (réglages gardés, contrôle, retour arrière). Seul MySQL / MariaDB reste à installer soi-même.
Voir [docs/chancellerie.md](docs/chancellerie.md).

À la main : placer `vAvA_core` et chaque module dans `resources/`, puis les démarrer dans cet ordre, après
`oxmysql` : `vAvA_core`, `vava_chat` (à la place de `chat`), `vava_world`, `vava_time`, `vava_appearance`, `vava_characters_ui`,
`vava_hud`, `vava_inventory`, `vava_needs`, `vava_health`, `vava_admin`, `vava_voice`, `vava_cameras`, `vava_magic`,
`vava_skills`, `vava_gathering`, `vava_crafting`, `vava_farming`, `vava_codex`, `vava_chancellerie`.

Le `server.cfg` contient la clé de licence et le mot de passe de la base : il ne doit jamais être publié.

## Serveur de test et serveur ouvert au public

Le dossier `examples/` contient quatre ressources de **développement**. **Ne jamais les `ensure` sur un serveur ouvert
au public** (la Chancellerie les pose dans `[vava-dev]` sans jamais les lancer d'office) :

| Ressource | Ce qu'elle offrirait |
| --- | --- |
| `vava_dev_characters` | `/objet` (n'importe quel objet), `/vie`, `/aterre`, `/besoins`, `/respawn`, `/perso` |
| `vava_example` | `/note` (lignes écrites en base), `example_ping` |
| `vava_example_items` | huit objets de démonstration, dont une Bande de lin qui soigne, et leurs images (~51 Ko) téléchargées par chaque joueur |
| `vava_anim_test` | `/anim`, `/epee`, `/animstop`, `/animprop`, et un `.ycd` téléchargé par chaque joueur |

Elles sont en plus **inoffensives par construction** : chacune refuse de démarrer tant que la convar serveur
`vava_env` ne vaut pas exactement `dev` (console : « mode développement absent »). Sans cette ligne, elles ne
proposent rien à personne ; avec, leurs commandes sont réservées au droit `staff` du Registre (Souverain) ou à l'ACE
`vava.dev`, et les dons, soins et téléportations sont inscrits au journal du Registre.

**Sur le serveur de test**, pour retrouver les commandes de développement, ajouter au `server.cfg` (page
**server.cfg** de la Chancellerie, ou à la main), au-dessus des lignes `ensure`, puis redémarrer le serveur :

```cfg
set vava_env dev
# facultatif : un testeur qui n'est pas Souverain (licence lue dans la Chancellerie, fiche du joueur)
add_ace identifier.license:<licence> vava.dev allow
```

Sans redémarrer le serveur : `set vava_env dev` dans sa console (page Console de la Chancellerie), puis `restart` de
chaque ressource de `[vava-dev]` démarrée (la convar est lue au démarrage du module ; posée ainsi, elle est perdue au
prochain redémarrage du serveur). À l'inverse, `set vava_env prod` ferme aussitôt les commandes (relue à chaque
appel) ; seuls les objets de `vava_example_items` restent déclarés jusqu'à son redémarrage. **Sur le serveur public, cette ligne ne doit jamais exister.** Détails :
`examples/*/README.md` ; contrôles : [docs/tests/developpement.md](docs/tests/developpement.md).
