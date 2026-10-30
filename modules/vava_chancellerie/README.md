# vava_chancellerie — le pont de la Chancellerie

Le pont entre la Chancellerie (panneau web, programme Node.js à part : `chancellerie/`, guide dans
`docs/chancellerie.md`) et le serveur de jeu. Il reçoit les demandes du panneau et les fait exécuter, au nom du compte
du panneau, par le Registre du Conseil (`vava_admin`), les zones de voix (`vava_voice`), le ciel et l'heure
(`vava_time`) et les caméras (`vava_cameras`), et lit le compteur réseau du core (page Réseau, lecture seule) ; il
prévient la Chancellerie en direct (signalements, arrivées et départs, caméras, rangs changés) ; il relie un compte du panneau à son joueur et tient la liste blanche Discord à la
connexion. Serveur seulement : rien n'est envoyé aux joueurs, sauf le résultat de leur liaison (affiché par vava_admin).

Ordre de démarrage : en dernier, après `vava_admin`, `vava_voice`, `vava_cameras`, `vava_time` et `vava_codex` (ordre
complet : `README.md` à la racine du dépôt).

## Installation

1. Placer le dossier dans `resources/[vava]/vava_chancellerie` (avec la Chancellerie : il est installé avec vAvA).
2. `ensure vava_chancellerie` en dernier. Aucun réglage à poser à la main ; la table `vava_chancellerie_links` se crée
   seule (migration `sql/0001_chancellerie.sql`, 1.5.0). La Chancellerie pose son adresse sur la ligne de commande de
   FXServer (`+set vava_chancellerie_url`, pas un secret), que le pont lit **une seule fois, au setup**, et seulement
   de la forme `http://127.0.0.1:<port>` (sinon : « adresse de la Chancellerie refusée », pont fermé) ; changer la
   convar ensuite ne déplace ni la clé ni les évènements. La **clé du pont**, tirée à chaque lancement, n'y passe
   plus (1.5.0) : le pont la demande dans la console et la Chancellerie la lui donne par l'entrée de FXServer (voir
   « Sécurité »). Il faut la Chancellerie 1.6.0 ou plus récente : une plus ancienne passe encore la clé en `+set
   vava_chancellerie_token`, que le pont ignore (console : « clé du pont passée sur la ligne de commande … : ignorée »),
   et le pont reste fermé.
3. Serveur lancé sans la Chancellerie (txAdmin, à la main) : le pont reste fermé, la liste blanche n'est pas vérifiée ;
   la console le dit au démarrage (« serveur lancé sans la Chancellerie : le pont reste fermé »).
4. Après la mise à jour en 1.5.0 : chaque compte du panneau déjà relié à un joueur est **à relier une fois de plus**
   (page Comptes, puis `chancellerie <code>` en jeu) pour que son rang s'applique encore en jeu (voir « Sécurité »).

| Dépendance | Rôle | Sans elle |
| --- | --- | --- |
| `vAvA_core` ≥ 0.5.0 | joueurs, hooks, registre des commandes | obligatoire |
| `vava_admin` ≥ 1.3.0 | demandes du Conseil, droits des rangs, journal, rangs des comptes reliés | obligatoire |
| `vava_voice` ≥ 1.1.0 | zones de voix lues, modifiées et supprimées depuis le web | page Zones de voix vide |
| `vava_cameras` ≥ 1.3.0 | écran des joueurs depuis le web (`webCheck` depuis 1.5.1) | pas de caméras depuis le web |
| `vava_time` ≥ 1.0.0 | ciel et heure du royaume lus et réglés depuis le web (1.4.0) | page Ciel et heure : « ne sont pas lancés » |
| `vAvA_core` ≥ 0.10.0 | compteur réseau (`core.net.stats`) lu par la page Réseau (1.6.0) | page Réseau : « demande vAvA_core 0.10.0 » |

## Règles (config.lua)

| Règle | Défaut | Clé |
| --- | --- | --- |
| Réglage posé au lancement | `vava_chancellerie_url` (adresse de la Chancellerie ; présent : serveur lancé par elle) ; `vava_chancellerie_token`, ancienne clé, ignorée et signalée | `convars` |
| Clé minimale | 32 signes hexadécimaux (128 au plus) ; hors de ces bornes, refusée | `tokenMin`, `key.max` |
| Demande de la clé | ligne « en attente de la clé de la Chancellerie (vava_chancellerie:cle?) » dans la console (texte fixé par le protocole, `VavaBridge.KEY_ASK_LINE`), toutes les 5 s pendant 2 min au plus ; une clé arrivée plus tard ouvre encore le pont | `key` |
| Comptes vus reliés | les liaisons en cours sont attendues 5 s au plus par requête, toutes confondues, avant de refuser un rang (sous les 8 s après lesquelles la Chancellerie abandonne sa demande) | `links.waitMs` |
| Évènements vers la Chancellerie | `/api/bridge/event` ; perdus si elle est fermée, signalés une fois par minute au plus | `eventPath`, `pushWarnEveryMs` |
| Corps de requête | 64 Ko au plus | `bodyMax` |
| Caméras | droit `watch` pour regarder ; la vue en grand passe par la demande `watchScreen` du Registre ; une case sans mur ouvert depuis 2 h est inscrite au journal | `cameras` |
| Page Réseau | droit `tools` (celui de `/vava_reseau`) ; 20 évènements au plus ; deux lectures d'un même compte du panneau espacées de 500 ms ; une ligne au journal à l'ouverture de la page, à chaque autre joueur lu, puis au plus tard toutes les 30 min | `net` |
| Liaison d'un compte | commande `chancellerie <code>`, 5 essais par minute, messages au joueur | `link` |
| Liste blanche Discord | réponse attendue 8 s à la connexion d'un joueur ; messages quand elle ne répond pas, ou quand la clé n'est pas encore arrivée | `whitelist` |
| Journal du Registre | « Zone de voix modifiée », « Zone de voix supprimée », « Mur des caméras ouvert », « Cases du mur regardées », « Compteur réseau consulté », « Réseau d'un joueur consulté » | `messages` |

## Ce que fait le pont

- **Entrée** : l'adresse HTTP du serveur de jeu (`http://127.0.0.1:<port>/vava_chancellerie/…`). Il n'accepte que les
  requêtes venues de la machine elle-même et portant la clé tirée par la Chancellerie à ce lancement (en-tête
  `x-vava-token`) ; corps borné, lu en JSON, chaque demande dans son propre thread, toujours une réponse.
- **Demandes du Conseil** : passées telles quelles au Registre (`webRequest`), qui vérifie le droit du rang, le schéma,
  la cible et son rang, et inscrit l'action à son journal au nom de « Chancellerie : <compte> ».
- **Zones de voix** : lues (droit `view`), modifiées et supprimées (droit `tools`) auprès de vava_voice ; droit vérifié
  et journal tenu par le Registre. Le nom suit la règle de l'éditeur en jeu (40 signes).
- **Ciel et heure** (1.4.0, `server/time.lua`) : demandes `time` (droit `view`), `timeClock` et `timeWeather` (droit
  `tools`) transmises à vava_time (`webState`, `webClock`, `webWeather`), qui revalide chaque valeur ; droit vérifié
  auprès du Registre (`webCan`), décision inscrite à son journal (`webLog`) si elle change quelque chose. Un fichier du
  pont ajoute ses demandes à `routes.requests`.
- **Compteur réseau** (1.6.0, `server/network.lua`) : demande `netStats` (portée `all`, `resource` + nom de ressource
  ou `player` + numéro, ouverture de la page), en **lecture seule** : le pont lit `core.net.stats` (core ≥ 0.10.0) —
  ce que montre `/vava_reseau` en jeu : mesure, envois, volume, latents, évènements les plus lourds et leur plus gros
  message — et ne rend que ces champs, en liste pure. Arguments bornés (`rules.netQuery` : 48 signes au motif des
  ressources, joueur de 1 à 65 535), lectures d'un même compte espacées de `net.minIntervalMs` (vérifié avant le droit :
  `rate_limited`), droit `net.permission` (tools) vérifié auprès du Registre (`webCan`), joueur absent :
  `unknown_player`. Le pont ne lance ni n'arrête aucun suivi : le détail d'un joueur, évènement par évènement,
  n'existe que s'il est suivi par `/vava_reseau joueur` en jeu, et son personnage n'est nommé que dans ce cas. Journal
  du Registre (`webLog`, `rules.netJournal`) : « Compteur réseau consulté » à l'ouverture de la page (et à la première
  lecture d'un compte que le pont ne connaît pas), « Réseau d'un joueur consulté » (numéro) à chaque autre joueur lu,
  puis au plus tard toutes les `net.logEveryMs` ; jamais à chaque relecture. Une ligne ne compte que si le Registre
  l'a acceptée.
- **Caméras** : ouvertes auprès de vava_cameras une fois le droit `watch` accordé — la vue en grand par la demande
  « écran du joueur » du Registre (cible vérifiée, au journal) — une fois le droit lu et la caméra jugée accordable par
  vava_cameras (`webCheck`, 1.5.1) : une vue refusée faute de débit chez le joueur filmé (`budget`), que la
  Chancellerie retente toutes les 10 s, ne laisse pas de ligne au journal —, les cases d'un mur sur le seul droit, l'ouverture du mur
  étant inscrite au journal. Le pont ne sait pas quand un mur du navigateur se ferme (onglet fermé, redémarrage) : au
  lieu de refuser une case, il inscrit au journal (« Cases du mur regardées », numéro du joueur) la première case d'un
  compte qui n'a ouvert aucun mur depuis `cameras.tileLogMs` (2 h, durée maximale d'une caméra), puis au plus une ligne
  toutes les 2 h (1.4.1). Une ligne ne compte que si le Registre l'a acceptée : sinon la case suivante réessaie. Aucune
  case n'est donc regardée sans trace au journal. Routes `/cameras/wall`,
  `/cameras/players`, `/camera/start`, `/camera/answer`, `/camera/stop`.
- **Évènements vers la Chancellerie** (requête HTTP locale, avec la clé, sans attendre de réponse) : signalements,
  arrivées et départs des joueurs, offre et fin des caméras du web, arrêt du module des caméras, rang du Conseil donné
  ou retiré (la Chancellerie revérifie alors le droit de chaque compte qui regarde), pont prêt (elle applique alors les
  rangs des comptes reliés et dit si sa liste blanche est active).
- **Liaison d'un compte du panneau** : le joueur tape en jeu (console `F8`) `chancellerie 482913`, avec le code affiché
  par la page Comptes ; le pont envoie à la Chancellerie le code, la license, les identifiants `fivem:` et `discord:`
  et le numéro de compte vAvA du joueur ; elle relie le compte et applique son rang du Conseil en jeu. Le joueur lit le
  résultat (relié, code inconnu, trop d'essais, Chancellerie injoignable). Une liaison confirmée par la réponse de la
  Chancellerie fait entrer le compte de jeu dans `vava_chancellerie_links` (1.5.0).
- **Rangs des comptes reliés** (`/staff/sync`) : appliqués par le Registre (`webSyncStaff`), mais un rang n'est **donné**
  qu'à un compte de `vava_chancellerie_links` (refus `not_linked_in_game`, une ligne dans la console) ; le retirer
  reste toujours permis ; un retrait marqué `unlinked` (déliaison, compte du panneau supprimé) fait aussi oublier le
  compte. Le panneau applique le rang pendant qu'il répond à la liaison : les liaisons en cours sont attendues, sous une
  seule échéance par requête (`links.waitMs`, un seul minuteur).
- **Liste blanche Discord** : à la connexion d'un joueur (hook `core:player:connecting`, avant toute création de
  données), le pont demande à la Chancellerie s'il peut entrer et lui montre sa réponse. Sans réponse en 8 s : refusé si
  la liste blanche était active à la dernière réponse, accepté sinon.

## Sécurité

- Le port du jeu est public (et relayé par Cfx.re) : la machine locale **et** la clé du lancement sont exigées ; la clé
  n'est jamais écrite dans le `server.cfg` et la Chancellerie la masque dans la console.
- **La clé ne passe pas sur la ligne de commande** (1.5.0) : celle d'un processus se lit sans droit particulier sur la
  machine (`ps`, `/proc/<pid>/cmdline`, Gestionnaire des tâches). Au setup, le pont déclare la commande
  `vava_chancellerie_cle` (console seulement : lancée par un joueur, elle est ignorée), puis écrit la ligne
  `[script:vava_chancellerie] en attente de la clé de la Chancellerie (vava_chancellerie:cle?)` dans la console ; la
  Chancellerie, qui lit cette console et ne reconnaît que cette ligne exacte, répond sur l'entrée de FXServer par
  `vava_chancellerie_cle <clé>`, une fois par démarrage du pont (plus de réponse après l'évènement `ready` vérifié,
  jusqu'au prochain lancement ou `restart vava_chancellerie`, qu'elle repère à « Started resource vava_chancellerie »).
  Ni convar (qu'une autre ressource lirait par `GetConvar`) ni fichier : la clé ne vit qu'en mémoire, la première reçue
  est gardée (une autre est refusée : ligne `une autre clé du pont a été refusée : la première reçue est gardée`), et
  aucun message ne l'affiche.
- **Ce mécanisme ne protège pas d'une ressource serveur hostile.** Une ressource qui lance `vava_chancellerie_cle` avant
  la Chancellerie garde le pont ; la Chancellerie le **repère et alerte** (console, journal, bandeau dans les pages
  ouvertes) : sa clé refusée par le pont, un évènement du pont arrivé avec une autre clé, ou aucun `ready` vérifié
  15 s après sa réponse. Une ressource serveur a de toute façon tous les pouvoirs sur le serveur (console, base) : ne
  lancer que des ressources de confiance.
- **Défense en profondeur** : qui volerait la clé pourrait parler au pont au nom de n'importe quel rang (le panneau en est
  la source), mais ne pourrait pas nommer Souverain un compte qui n'a jamais été relié en jeu, par `/staff/sync` :
  seuls les comptes que le pont a vus reliés en jeu reçoivent un rang (un code juste tapé par le joueur et confirmé par
  la Chancellerie en réponse au pont lui-même ; la clé n'y suffit pas). « Délier » dans le panneau fait oublier le
  compte (ligne supprimée de `vava_chancellerie_links`).
- **Liste blanche** : sur un serveur lancé par la Chancellerie, tant que la clé n'est pas arrivée, toute connexion est
  refusée (« Le registre des portes s'ouvre : réessayez dans un instant. ») plutôt qu'acceptée faute de réponse. Si la
  clé n'arrive jamais (Chancellerie trop ancienne), plus personne n'entre : mettre la Chancellerie à jour.
- Le pont ne décide de rien : chaque demande est revérifiée par le module qui l'exécute (droit du rang, cible, schéma),
  et journalisée par le Registre. Les exports réservés au pont (`vava_admin:web*`, `vava_voice:webUpdateZone`,
  `webDeleteZone`, `vava_cameras:web*`, `vava_time:web*`) refusent toute autre ressource appelante.
- Liaison : 5 essais par minute et par joueur ; un code vaut 5 minutes, une fois ; après 5 codes faux, la license
  attend (règles tenues par la Chancellerie).

## Arborescence

```
vava_chancellerie/
├── fxmanifest.lua · config.lua
├── shared/   constants.lua (modules reliés, hooks, protocole de la clé) · rules.lua (forme de la clé, rangs permis,
│             demande et journal du compteur réseau : logique pure, tests/spec/chancellerie_rules_spec.lua, chargée côté
│             serveur seulement)
├── server/   core · auth (machine locale, clé demandée à la console) · push (évènements vers la Chancellerie)
│             links (comptes vus reliés en jeu) · link (liaison d'un compte) · whitelist (liste blanche)
│             routes (demandes du panneau) · time (ciel et heure) · network (compteur réseau, lecture seule)
│             http (écoute) · commands · main
└── sql/      0001_chancellerie.sql (vava_chancellerie_links)
```

## À vérifier en jeu

Avec la Chancellerie lancée (elle démarre FXServer) et un compte du panneau qui a un rang du Conseil :

1. Console du serveur au démarrage : aucun « pont fermé ». Chancellerie : page Joueurs en direct, arrivées et départs.
2. Depuis le web : avertir, soigner, immobiliser un joueur ; le Journal du Conseil l'inscrit au nom de
   « Chancellerie : <compte> » ; un compte Gardien est refusé sur un Souverain pour une action protégée par le rang.
3. Zones de voix : modifier un nom (40 signes accentués acceptés), supprimer ; l'éditeur en jeu suit (voir
   `docs/tests/voix.md`, section 5).
4. Caméras : page Caméras (mur), puis « Regarder l'écran » ; révoquer le rang du compte pendant qu'il regarde : ses
   caméras s'éteignent (« Droit refusé »). Case demandée sans ouvrir le mur : une ligne « Cases du mur regardées »
   (`docs/tests/registre.md`, § 10, test 13).
5. Liaison : page Comptes → « Relier un joueur », puis `chancellerie <code>` en jeu ; le rang s'applique en jeu ;
   un code faux répond « Code inconnu ou expiré ».
6. Liste blanche (si elle est réglée) : un joueur sans le rôle Discord est refusé avec le message de la Chancellerie.
7. FXServer lancé sans la Chancellerie : le pont reste fermé (console), le jeu marche normalement.
8. Ciel et heure : régler l'heure et imposer un ciel depuis la page Ciel et heure ; les joueurs le voient, le Journal
   du Conseil l'inscrit (voir `docs/tests/temps.md`, section 6).
9. Clé du pont et rangs des comptes reliés (1.5.0) : procédure complète dans `docs/tests/chancellerie.md`.
10. Page Réseau (1.6.0) : mêmes chiffres que `/vava_reseau`, journal à l'ouverture et à chaque joueur lu, refus d'un
    Gardien : `docs/tests/chancellerie.md`, section 3.
