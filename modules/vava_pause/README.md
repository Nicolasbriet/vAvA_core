# vava_pause — la bannière du royaume

Échap (ou P, ou Start à la manette) déploie la bannière du royaume au lieu du menu pause de GTA : son personnage et ses
savoir-faire, le Codex dans le panneau, la carte, ses réglages (interface, voix, touches), une demande au Conseil, les
paramètres du jeu, et « Quitter Eldoria ». La plaque du royaume, en bas à droite, dit le moment du jour, la saison et
combien d'habitants sont là. La bannière montre, elle n'agit pas sur le monde : rien ne se fige pendant qu'elle est
ouverte, et personne n'en tire d'avantage.

Spec : `docs/plan/specs/T-145.md` (avec les décisions du porteur du projet du 31 octobre 2026). Procédure en jeu :
`docs/tests/pause.md`.

## Ce que vit le joueur

- **Ouvrir** : Échap, P ou Start, personnage en jeu. À l'écran de sélection ou pendant un chargement, le menu de GTA
  reste. Refusée, avec un message : **en combat** (10 s après un coup donné ou reçu, sort compris ; la faim et les
  chutes n'en sont pas), **ligoté** ; sans message : une autre interface ouverte (l'Échap qui la ferme ne déploie pas
  la bannière dans la foulée), écran au noir, menu de GTA ouvert. Un refus du serveur est gardé par le client : en
  combat, jusqu'à la fin de la fenêtre (temps restant donné par le serveur) ; Échap répété est refusé sur place, sans
  redemander ni dérouler la bannière, et le message ne revient pas plus d'une fois toutes les 3 s.
- **À terre** : bannière **réduite** (décision 2) : Reprendre, Paramètres du jeu, Quitter Eldoria seulement ; les autres
  rubriques sont absentes. Le serveur en décide.
- **Pendant** : un coup reçu (perte de vie d'au moins 2 %), une mise à terre (bannière entière) ou un ligotage replient
  la bannière (« Le monde vous rappelle à lui : la bannière se replie. »).
- **Personnage** : nom, rang du métier principal, confrérie (ou « sujet du royaume »), santé, faim, soif, savoir-faire ;
  « ouvrir la fiche complète » ouvre le livre des compétences.
- **Codex** : le livre de `vava_codex` s'ouvre à droite de la bannière (Codex en panneau, `vava_codex` ≥ 1.7.0).
- **Carte** : la carte de GTA en attendant la carte du royaume ; Échap la ferme et la bannière revient.
- **Réglages** : taille de l'interface (bannière et HUD), durée des notifications, cercle de portée de la voix ; touches
  du joueur (celles qu'il a liées). Gardés **sur sa machine**, pour tous ses personnages ; rien ne part au serveur.
- **Le Conseil** : une question, un signalement de joueur, un bug, autre ; position jointe au choix (toujours pour un
  signalement : le Conseil saura qui se trouvait près de vous) ; suivi de la demande (envoyée, prise en charge, close).
  Le joueur signalé ne voit jamais le nom de celui qui signale ; le Conseil le voit (décision 3).
- **Quitter Eldoria** : Rester, Se déconnecter (le serveur déconnecte avec « Votre personnage vous attend là où vous
  l'avez laissé. »), Quitter le jeu.

## Règles (config_client.lua : lu par le client ; config.lua : serveur seul)

| Règle | Défaut | Clé |
|---|---|---|
| Contrôles interceptés | 199 (P, Start), 200 (Échap) | `intercept.controls` (client) |
| Délai de grâce après une autre interface | 300 ms ; focus guetté toutes les 100 ms ; boucle au repos 500 ms hors jeu | `intercept.graceMs`, `focusWatchMs`, `idleMs` (client) |
| Même refus non répété | 3 s | `intercept.noticeMs` (client) |
| Attente de la réponse avant de dérouler | 50 ms (sinon déroulée, données à venir), 4 s au plus | `open.waitMs`, `open.timeoutMs` (client) |
| Instantané repris si le serveur refuse pour débit | 60 s | `open.reuseMs` (client) |
| Veille bannière ouverte | 500 ms ; repli pour une perte de vie de 2 % | `open.watchMs`, `open.hitDrop` (client) |
| Déroulé | 250 ms (0 : sans animation) | `open.rollMs` (client) |
| Menu de GTA tenu fermé à chaque image | oui (`false` : essai pause 1-8, voir Performance) | `intercept.holdPauseMenu` (client) |
| Manette pendant un menu natif ou le Codex en panneau | relue toutes les 100 ms | `gamepad.pausedMs` (client) |
| Menus natifs | carte `FE_MENU_VERSION_MP_PAUSE` (+ un niveau plus bas), paramètres `FE_MENU_VERSION_LANDING_MENU`, raccourcis `FE_MENU_VERSION_LANDING_KEYMAPPING_MENU` (repli : paramètres) ; fermeture guettée toutes les 250 ms ; menu jamais ouvert : 1,5 s | `native` (client) |
| Quitter le jeu | commande `quit`, puis déconnexion par le serveur après 1,5 s si le jeu tourne encore | `quit.fallbackMs` (client) |
| Manette | croix, A, B, LB, RB, Start | `gamepad` (client) |
| Codex en panneau | rectangle 32,6 / 10,7 / 58,3 × 71,1 (vw, vh) | `codex` (client) |
| Fiche complète | commande `vava_skills` | `sheet` (client) |
| Bannière royale, tampons de rang | garance, champ bleu, croix ; encres par rang | `royal`, `rankInks` (client) |
| Plaque | périodes du jour, saisons, habitants | `plaque` (client) |
| Réglages du joueur | `ui.scale`, `hud.notifyDuration`, `voice.circle` ; stockage local `vava_pause:reglages` | `settings` (client) |
| Essai du ligotage | `''` (commande absente) | `devCuffCommand` (client) |
| Textes du client | refus, repli, indisponible | `messages` (client) |
| Débits | ouverture 4 puis 1 / 4 s ; Conseil 2 puis 1 / min ; quitter 2 puis 1 / 10 s | `rateLimits` |
| Fenêtre de combat | 10 s (décision 4) ; `privation` et `monde` ignorés | `combat` |
| Habitants | compte gardé 10 s | `people.cacheMs` |
| Instantané | 32 savoir-faire, 48 touches, portée `player` | `snapshot` |
| Confrérie (facultatif) | `vava_guilds`, export `bannerOf`, meubles `croix` ; avertissement 1 / min | `guild` |
| Quitter | réponse, puis déconnexion après 200 ms ; messages | `leave` |
| Touche au registre | « Déployer la bannière du royaume », `Échap ou P`, chapitre Royaume | `commands` |

Aucun modèle, aucune coordonnée : rien n'est marqué `-- PLACEHOLDER`.

## Réseau

- **Une seule demande à l'ouverture** : RPC `vava_pause:open(versionDesTouches)` (chaîne de 24 octets au plus,
  `^[%w%-]*$`) → `{ skills, guild?, people, council, request?, keysVersion, keys? }` ou, à terre, `{ downed = true }` ;
  refus `not_ready`, `no_character`, `combat` (avec les millisecondes restantes), `restrained`, `busy`. Les touches ne repartent que si leur version a
  changé (le client garde la liste jusqu'au déchargement du personnage ; la page ne la reçoit elle aussi qu'à son
  changement, et les touches liées par le joueur sont relues une fois par ouverture). Aucune attente de la base.
- `vava_pause:council(nature, texte, position)` (énuméré ; 1 à 500 octets ; booléen) → `true, { id, kind, state, age }`
  ou `false, code[, secondes]` : `no_character`, `too_short`, `invalid_text`, `too_soon`, `too_many`, `full`,
  `council_unavailable`. Demande créée par `vava_admin` (`submitRequest`) : texte normalisé par lui, comme pour
  `/signaler` (contrôles, caractères invisibles et marques de sens d'écriture refusés, 10 caractères, 12 lignes),
  position et témoins lus par le serveur.
- `vava_pause:leave(mode)` (`disconnect` | `quit`) : l'appelant seul est déconnecté, après le départ de la réponse ;
  la console note son temps de combat restant et s'il est à terre (la bannière ne l'en empêche pas : Alt+F4 existe).
- **Aucun évènement serveur → client, aucun state bag, aucun GlobalState.** Un joueur proche ne reçoit rien quand un
  autre ouvre sa bannière. Heure et saison : `vava_time` (déjà présent chez le joueur) ; vie, faim, soif, voix : lues
  localement.

## Pour les autres modules

Exports client : `isOpen()`, `close()`, `block(id, posé, sorte?)` (un outil qui lit Échap, une cinématique, un
ligotage pose un blocage pendant son usage), `setting(clé)`, `settings()`. Crochets client : `vava_pause:state`
(`{ open }`), `vava_pause:settingChanged` (`{ key, value }`). Serveur : export `inCombat(source)` → `true, ms` ou
`false` ; crochet `vava_pause:opening` (`before`, `{ source, characterId, downed }` ; refus `combat` ou `restrained`
gardés, tout autre → `busy`). Détail : `docs/api.md`, section `vava_pause`.

**Ligotage** : aujourd'hui vérifié par le seul client (`IsPedCuffed`, blocage `restrained`) ; sans enjeu, la bannière
n'agissant pas sur le monde. Le futur module qui lie un personnage refusera aussi côté serveur, par le crochet
`vava_pause:opening` (raison `restrained`).

Un réglage de plus : une ligne dans `settings.list` de `config_client.lua` (clé, onglet, sorte, défaut, choix, libellés,
`uses`), puis le module qui l'applique lit `exports.vava_pause:setting(clé)` et suit `vava_pause:settingChanged`.

## Performance

La seule boucle par image permanente (`client/intercept.lua`) bloque Échap et P et empêche le menu de GTA de s'ouvrir :
trois natives et deux lectures par image, rien d'autre (exception décidée par le porteur du projet, marquée
`-- audit: ok`). `SetPauseMenuActive(false)` y est gardé : bloquer 199 et 200 suffit peut-être, mais il empêche le menu
de GTA de s'ouvrir par un autre chemin (manette) ; en contrepartie, il refermerait un menu de GTA qu'un autre module
ouvrirait. `intercept.holdPauseMenu = false` permet l'essai sans lui (pause 1-8) ; s'il ne manque pas, le retirer. Elle dort hors jeu et pendant un menu natif ouvert par la bannière. La manette n'est lue à chaque image
que bannière ouverte. Le reste : 100, 250 ou 500 ms. Cible : `resmon` ≤ 0,02 ms au repos.

## Installation

`ensure vava_pause` juste après `ensure vava_codex`, avant `vava_arrival`. Demande `vAvA_core` ≥ 0.10.0 et `vava_ui`.
Facultatifs : `vava_skills`, `vava_health`, `vava_needs`, `vava_time`, `vava_voice`, `vava_hud` ≥ 1.6.0 (HUD masqué,
réglages), `vava_codex` ≥ 1.7.0 (panneau), `vava_admin` ≥ 1.10.0 (Conseil ; `vava_pause` dans `requests.callers`),
`vava_guilds` (couleurs de confrérie, à venir). Aucune table en base.

## Fichiers

| Fichier | Rôle |
|---|---|
| `config_client.lua`, `config.lua` | réglages (client ; serveur seul) |
| `shared/constants.lua` | table `VavaPause`, RPC, crochets, natures, bornes |
| `shared/gate.lua`, `shared/settings.lua`, `shared/plaque.lua` | logique pure lue par le client : porte, réglages, plaque (testées) |
| `shared/snapshot.lua`, `shared/combat.lua` | logique pure, serveur seul : instantané, fenêtre de combat (testées) |
| `bridge/server.lua` | seul contact serveur avec les autres modules, chaque appel isolé |
| `server/*.lua` | fenêtre de combat, touches, instantané, RPC, export `inCombat`, touche au registre, setup |
| `client/nui.lua` | seul fichier qui parle à la page |
| `client/sources.lua` | lectures locales des autres modules |
| `client/settings.lua` | réglages du joueur (stockage local), exports `setting`, `settings` |
| `client/native.lua` | carte et paramètres du jeu |
| `client/intercept.lua` | boucle de blocage d'Échap et de P, guet du focus |
| `client/gamepad.lua` | manette, bannière ouverte |
| `client/main.lua` | ouverture, veille, rubriques, exports, blocages |
| `web/` | la page (bannière, rubriques) ; hors jeu : `web/dev/devmock.js` (jamais livré) |

Tests hors jeu : `tests/spec/pause_gate_spec.lua`, `pause_settings_spec.lua`, `pause_plaque_spec.lua`,
`pause_snapshot_spec.lua` (et poids de la page ≤ 100 Ko), `pause_combat_spec.lua` ; texte d'une demande :
`admin_requests_spec.lua` (normalisation dans `vava_admin`).

## À vérifier en jeu

- Noms des menus natifs (`FE_MENU_VERSION_MP_PAUSE` puis `PauseMenuceptionGoDeeper(0)`, `FE_MENU_VERSION_LANDING_MENU`,
  `FE_MENU_VERSION_LANDING_KEYMAPPING_MENU`) et retour à la bannière à leur fermeture.
- `ExecuteCommand('quit')` permis côté client (sinon le repli du serveur déconnecte avec un message).
- Manette lue sous focus de la page (`IsDisabledControlJustPressed(2, …)`) ; sinon passer la lecture par
  `SetNuiFocusKeepInput(true)` le temps où la manette sert.
- Échap qui ferme une autre interface sans ouvrir la bannière (délai de grâce).
- Focus rendu au Codex en panneau, puis repris par la bannière.
- Menu de GTA jamais visible, même une image (`SetPauseMenuActive(false)` à chaque image).
- `resmon` ≤ 0,02 ms au repos, ≤ 0,15 ms bannière ouverte.
