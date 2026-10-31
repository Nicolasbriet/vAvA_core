# vava_voice — la voix du royaume

Chat vocal de proximité, sur la voix intégrée à FiveM (Mumble de FXServer, son 3D du jeu) : aucune autre ressource
vocale. Quatre portées changées d'une touche, un médaillon dans le HUD, un cercle au sol au changement de portée ;
silence hors du jeu ; portée réduite à terre ; zones où la voix porte plus ou moins loin, créées en jeu par le Conseil.

Ordre de démarrage : après `vava_admin`, avant `vava_cameras` (ordre complet : `README.md` à la racine du dépôt).

## Installation

1. Placer le dossier dans `resources/[vava]/vava_voice` (avec la Chancellerie : il est installé avec vAvA).
2. Dans le `server.cfg`, ces deux lignes (son 3D du jeu ; voix envoyée aux seuls joueurs à portée) :

   ```cfg
   setr voice_useNativeAudio true
   setr voice_useSendingRangeOnly true
   ```

   Par `setr` : un `set` n'est pas transmis aux joueurs. La Chancellerie (1.4.2) les écrit d'elle-même, et les ajoute
   avant chaque lancement de FXServer à un `server.cfg` qui ne les pose pas par `setr` ; une valeur posée est gardée.
   Si le fichier inclut d'autres fichiers (`exec`) ou n'est pas en UTF-8, elle n'écrit rien et avertit : vérifier à la
   main (`docs/chancellerie.md`).
3. `ensure vava_voice` après `ensure vava_admin`. La table `vava_voice_zones` est créée par le core au premier
   démarrage (migration `sql/0001_voice_zones.sql`, jamais rejouée).
4. Chaque joueur active le chat vocal dans les réglages du jeu (Paramètres > Chat vocal) et parle avec la touche de GTA
   (`N` par défaut).
5. **Règlement du serveur** : y reprendre la limite des voix FiveM (voir « Sécurité et coût »).

| Dépendance | Rôle | Sans elle |
| --- | --- | --- |
| `vAvA_core` ≥ 0.11.0 | personnages, RPC, hooks, base, registre des commandes, abonnements de zone (1.3.0) | obligatoire |
| `vava_ui` ≥ 1.0.0 | polices, grain, papier et coins de l'éditeur (`nui://vava_ui/…`) | obligatoire (dépendance déclarée : démarrée d'office, à ne jamais arrêter sur un serveur ouvert) |
| `vava_hud` ≥ 1.2.0 | médaillon « Voix » et sa lueur | pas de médaillon |
| `vava_health` | portée réduite à terre | aucune limite à terre |
| `vava_admin` ≥ 1.1.0 | droits des zones, outil « Zones de voix » du Registre, journal | personne ne crée de zone |
| `vava_chancellerie` | zones modifiées et supprimées depuis le web | zones gérées en jeu seulement |

## Règles (config.lua)

| Règle | Défaut | Clé |
| --- | --- | --- |
| Portées | Chuchoter 1,5 m, Parler 5 m, Crier 15 m, Déclamer 25 m | `ranges` |
| Portée de départ | Parler | `defaultRange` |
| À terre | Chuchoter et Parler seulement ; la portée d'avant revient à la réanimation | `downedMaxRange` |
| Touche de portée | `Z` pour FiveM, soit la touche W d'un clavier AZERTY ; réglable par chaque joueur (Paramètres > Raccourcis > FiveM) ; changer la touche par défaut demande de renommer la commande, et de relire le conseil de la voix dans `modules/vava_loading/web/js/strings.js` (il ne cite pas la touche, mais les quatre portées) | `key`, `command`, `keyLabel` |
| Joueurs à portée | recalculés toutes les 250 ms, marge de 2 m (la voix ne se coupe pas à chaque pas en bordure) | `client.targetsPollMs`, `client.targetMargin` |
| Médaillon | un quart par portée, lueur relue toutes les 150 ms | `hud`, `client.talkingPollMs` |
| Zone où se tient le joueur | relue toutes les 500 ms | `client.zonesPollMs` |
| Limite de portée | redemandée à l'apparition et au redémarrage du module : 5 essais à 2 s d'écart si le serveur n'est pas prêt | `client.syncTries`, `client.syncRetryMs` |
| Zones connues d'un joueur | celles dont il est à moins de rayon + 40 m (envoyées par le core, 1.3.0) ; oubliées au-delà de 25 m de plus | `zones.subscribeMargin` (et `zones.exitMargin` du core) |
| Cercle au sol | 1,5 s, s'efface sur les 0,6 dernières, couleur laiton | `ring` |
| Cercle au sol, réglage du joueur (1.4.0) | « Cercle de portée au sol » de la bannière du royaume (`voice.circle`, gardé sur sa machine) : désactivé, la portée change sans cercle ; sans `vava_pause`, toujours montré | `pauseResource` |
| Zones de voix | 200 au plus ; nom de 40 signes ; rayon 2 à 60 m (10 par défaut), hauteur 2 à 30 m (6), par pas de 0,5 ; effet ×0,5, ×0,75, ×1, ×1,5, ×2 (défaut) ou ×3 | `zones` |
| Droits | `tools` pour créer, régler, supprimer ; `teleport` pour « S'y rendre » | `zones.permission`, `zones.teleportPermission` |
| Débits | limite de portée : 3 puis 1 toutes les 5 s ; éditeur : 5 puis 1 par seconde ; actions : 10 puis 1 par seconde | `rateLimits` |
| Journal du Registre | « Zone de voix créée », « modifiée », « supprimée » | `messages` |

## Ce que vit le joueur

- **Portée** : la touche passe à la suivante, puis revient à Chuchoter ; le choix est gardé sur sa machine. Le
  médaillon « Voix » se remplit d'un quart par portée et s'illumine quand il parle ; le cercle au sol montre la distance
  pendant 1,5 s, au seul appui sur la touche, vu de lui seul ; il le retire dans la bannière (Réglages → Voix, 1.4.0).
- **Hors du jeu** (connexion, sélection du personnage) : micro coupé par le serveur (`MumbleSetPlayerMuted`) et joueur
  au salon racine, sans personne à qui parler. Le micro s'ouvre à l'apparition confirmée du personnage.
- **À terre** (`vava_health`) : Chuchoter et Parler seulement. Relu à chaque apparition (reconnecté à terre : toujours
  limité) et renvoyé au client qui redémarre.
- **Zones de voix** : là où la voix porte plus loin (tribune, place) ou moins (bibliothèque, crypte). L'effet
  multiplie toutes les portées de qui se tient dans la zone, pas l'oreille de qui l'écoute. Si des zones se
  chevauchent, la plus petite l'emporte (la plus précise).

## Conseil : l'éditeur des zones

Registre du Conseil (`F10`) → Outils → « Zones de voix », ou `/zonesvoix` (droit `tools`). Un panneau de parchemin sur
le côté, le monde reste visible : les zones à moins de 150 m y sont dessinées en cylindres (bleutés quand la voix porte
moins, beiges à ×1, dorés au-delà).

- **Nouvelle zone ici** : centrée sur la position du membre du Conseil, lue par le serveur. La hauteur se compte depuis
  ses hanches (la position du personnage) ; la zone descend aussi d'un mètre sous elles (`zones.baseOffset`), jusqu'au
  sol : une zone de 2 m au rez-de-chaussée ne déborde pas à l'étage.
- **Nom** : 40 signes au plus — un « é » ou un emoji compte pour un, dans le champ comme sur le serveur ; les espaces
  en trop sont retirés. Refusés : un nom fait d'espaces (insécables comprises) — « Donnez un nom au lieu. » —, et les
  caractères de contrôle ou invisibles qui tromperaient la lecture (largeur nulle, marques de sens d'écriture, BOM) —
  « Ce nom contient des signes illisibles. » (code `label_unreadable`, 1.2.2 ; la Chancellerie montre son message
  générique tant que ses textes ne connaissent pas ce code).
- **Réglages** : rayon, hauteur, effet ; l'aperçu suit en direct, avec les quatre portées avant et après l'effet.
- **Modifier** une zone (la cliquer dans la liste), la **recentrer** là où l'on se tient, **S'y rendre** (droit
  `teleport`), **Supprimer** (deux clics).
- **Sceller** (ou `Entrée`) : une seule demande à la fois ; rien n'est écrit avant.
- Chaque action est revérifiée par le serveur (droit, bornes, centre lu par lui) et inscrite au journal du Registre.
  Chaque zone n'est envoyée qu'aux joueurs à moins de rayon + 40 m d'elle (abonnements de zone du core, 1.3.0), et
  chaque changement à eux seuls : plus rien ne part à tous.
- La liste de l'éditeur (toutes les zones) part au seul membre qui l'ouvre ; elle suit ensuite ses propres actions et
  les zones proches changées par un autre membre. Une zone lointaine changée par un autre l'est à la réouverture ; une
  zone supprimée par un autre entre-temps répond « Cette zone n'existe plus. » et la liste est redemandée.

Depuis la Chancellerie (pont `vava_chancellerie`) : modifier (nom, rayon, hauteur, effet, sans recentrage) et
supprimer, au journal du Registre ; la création reste en jeu, car une zone se centre sur qui la crée.

## Base de données (sql/0001_voice_zones.sql)

`vava_voice_zones` : nom, centre (x, y, z, au centimètre), rayon, hauteur, effet, date de modification. Lue une fois au
démarrage puis tenue en mémoire ; chaque action est écrite en base avant d'être diffusée.

## Pour les autres modules

Exports serveur `isActive`, `limitRange`, `releaseRange`, `getZones` ; exports client `getRange`, `isTalking` ; hooks
`vava_voice:zonesChanged` (serveur) et `vava_voice:rangeChanged` (client). Détail : `docs/api.md`, section `vava_voice`.

```lua
-- un bâillon : Chuchoter au plus, jusqu'à ce qu'on le retire (la raison est préfixée par la ressource appelante)
exports.vava_voice:limitRange(source, 'baillon', 1)
exports.vava_voice:releaseRange(source, 'baillon')
```

## Sécurité et coût

- Chaque intention du client est un RPC du core à schéma strict et à débit limité (`vava_voice:zones`, `:editor`,
  `:zoneCreate`, `:zoneUpdate`, `:zoneDelete`, `:zoneReach`) ; le droit est revérifié à chaque action. Le nom d'une
  zone est borné à 160 octets sur le réseau (40 signes de 4 octets au plus), sans caractère de contrôle, puis compté en
  signes par le serveur (`shared/label.lua`).
- Chaque joueur en jeu écoute son propre salon (`1000 + numéro de joueur`) ; sa parole part vers les salons des seuls
  joueurs à portée. Le serveur décide qui parle (micro coupé hors du jeu) ; la portée, elle, est réglée par le client,
  comme toute voix FiveM : un client modifié pourrait l'agrandir. FXServer n'a pas de contrôle d'accès aux salons
  Mumble : un client modifié peut écouter le salon d'un autre joueur ou parler à tout le serveur. Aucune parade
  technique fiable : à traiter par le règlement et la modération.
- La limite de portée (à terre, autres modules) part au seul joueur concerné, à chaque changement, et de nouveau quand
  son client la redemande (apparition, redémarrage du module).
- Zones de voix : envoyées par le core aux seuls joueurs proches (positions lues par le serveur, jamais demandées par
  le client), environ 150 o par zone à l'approche, environ 100 o par changement aux seuls joueurs qui la suivent ;
  `/vava_reseau zones` montre qui suit quoi. Plus d'exception d'audit pour ce module.
- Aucune boucle par image au repos (relevés toutes les 150, 250 et 500 ms) ; une boucle par image seulement pendant le
  cercle au sol (1,5 s) et l'éditeur ouvert, chez le seul membre du Conseil.
- Arrêt du module : aucun micro n'est rendu. Un joueur en sélection reste muet pendant un `restart`. Après un `stop`
  sans redémarrage, ou un redémarrage dont le setup échoue (le module ne devient jamais prêt), les joueurs alors en
  sélection restent muets jusqu'à leur reconnexion, même une fois leur personnage en jeu ; si le module revient prêt,
  ceux déjà en jeu retrouvent la voix sans reconnexion. Éditeur ouvert, le clavier et la souris reviennent au jeu.

## Arborescence

```
vava_voice/
├── fxmanifest.lua · config.lua
├── shared/   constants.lua (protocole) · label.lua (nom d'une zone, compté en signes)
├── server/   core · store (base) · presence (micros, limites) · links (santé, Conseil) · zones · api · commands
│             main
├── client/   core · nui · hud (médaillon) · mumble (salons, cibles) · ring (cercle) · zones · range (portée)
│             editor · main
├── web/      index.html · css/style.css · js/ (strings, bridge, editor) · dev/devmock.js (hors jeu, jamais livré)
└── sql/      0001_voice_zones.sql
```

Pour travailler le rendu de l'éditeur sans le jeu : `web/index.html` (ou `?zone=1` pour le formulaire) dans un
navigateur, depuis le dépôt (option `--allow-file-access-from-files` pour les polices) ; le médaillon : `vava_hud/web/index.html?values=0.8,0.6,0.3,0.75&talking=1`.

## À vérifier en jeu

Procédure complète : `docs/tests/voix.md`. À regarder en premier :

1. Les portées entendues à deux, avec les deux lignes du `server.cfg` (voix 2-1 à 2-6).
2. Le silence en sélection, y compris pendant un `restart vava_voice` (voix 2-7, 8-3, 8-5).
3. La portée à terre, et après un `restart` à terre (voix 6-1 à 6-5).
4. L'éditeur : nom de 40 signes accentués, double `Entrée`, clavier rendu à l'arrêt (voix 3-6, 3-15, 8-2).
5. Les zones après un `restart` (voix 8-1).
6. 1.3.0 : zones reçues à l'approche seulement, changées sans reconnexion, oubliées en s'éloignant (zones 2-1 à 2-10) ;
   éditeur qui suit les changements d'un autre membre (zones 4-1 à 4-3).
7. 1.4.0 : réglage « Cercle de portée au sol » désactivé dans la bannière → aucun cercle au changement de portée ; réactivé
   ou `vava_pause` arrêté → le cercle revient (pause 6-3).
