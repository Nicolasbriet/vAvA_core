# vava_cameras — l'écran des joueurs

L'écran des joueurs, pour le Conseil. Tout membre (droit `watch` de vava_admin, sans règle de rang) regarde tout le
monde : en jeu, sur le **mur des caméras**, ou depuis la Chancellerie (par son pont). Le jeu du joueur filmé capture
l'image du jeu seule et l'envoie en WebRTC direct à chaque spectateur ; le serveur ne relaie que la mise en relation,
décide qui regarde qui, et l'inscrit au journal du Conseil.

Ordre de démarrage : après `vava_admin` et `vava_voice`, avant `vava_magic` et `vava_chancellerie` (ordre complet :
`README.md` à la racine du dépôt).

## Installation

1. Placer le dossier dans `resources/[vava]/vava_cameras` (avec la Chancellerie : il est installé avec vAvA).
2. `ensure vava_cameras` après `ensure vava_admin`. Aucune table : rien n'est gardé en base.
3. **Règlement du serveur** : y écrire que le Conseil peut regarder l'écran d'un joueur sans le prévenir, et que la
   connexion directe révèle l'adresse IP du joueur à qui le regarde (voir « Sécurité »).
4. Facultatif : une autre adresse STUN dans `config.lua` (`iceServers`), si celle de Google ne convient pas.

| Dépendance | Rôle | Sans elle |
| --- | --- | --- |
| `vAvA_core` ≥ 0.5.0 | personnages, RPC, hooks, registre des commandes | obligatoire |
| `vava_admin` ≥ 1.2.0 | droit `watch`, journal du Conseil, outil « Mur des caméras » du Registre | personne ne regarde en jeu |
| `vava_chancellerie` ≥ 1.1.0 | caméras regardées depuis le web | mur en jeu seulement |

## Règles (config.lua)

| Règle | Défaut | Clé |
| --- | --- | --- |
| Droit de regarder | `watch` : tout le Conseil, sur tout le monde, membres de tout rang compris | `permission` |
| Capture (une par joueur filmé, partagée) | 960 × 540, 20 images/s | `capture` |
| Case d'un mur | 480 × 270, 10 images/s ; 250 kbit/s au plus, 120 au moins | `qualities.tile` |
| Vue en grand | 960 × 540, 20 images/s ; 1 200 kbit/s au plus, 600 au moins | `qualities.full` |
| Débit montant d'un joueur filmé (1.3.0) | 1 500 kbit/s pour tous ses spectateurs ensemble (jeu et web) ; une seule vue en grand à la fois ; au-delà, refus `budget` (voir « Débit montant du joueur filmé ») | `budget` |
| Adresse STUN | `stun:stun.l.google.com:19302` | `iceServers` |
| Limites | 6 spectateurs par joueur filmé, 96 caméras en tout, 2 h au plus ; sans réponse du spectateur en 30 s, la caméra s'éteint ; négociation de 20 000 octets au plus ; offre relayée au membre en jeu en envoi latent, à 32 000 octets par seconde (1.3.0) | `limits` |
| Mur | `/cameras` ; grilles 1 × 1 à 4 × 4 (3 × 3 par défaut) ; joueurs relus toutes les 5 s ; cases ouvertes à 150 ms d'écart (réellement depuis 1.2.0 : avant, toutes partaient d'un coup) ; mur valable 2 h, puis à rouvrir | `wall` |
| Débits | capture du joueur filmé 8 puis 2/s ; ouverture du mur 4 puis 1 toutes les 2 s ; caméras demandées 40 puis 8/s ; réponses et fermetures 40 puis 8/s ; liste des joueurs 4 puis 1/s | `rateLimits` |
| Pont du web | seule ressource admise à ouvrir une caméra en son nom : `vava_chancellerie` | `web.bridge` |
| Journal du Conseil | « Mur des caméras ouvert », « Écran regardé » | `messages` |

## Le mur des caméras (en jeu)

Registre du Conseil (`F10`) → Outils → « Mur des caméras », ou `/cameras` (droit `watch`).

- Une grille des joueurs connectés (le membre lui-même exclu) : touches `1` à `4` pour 1 × 1 à 4 × 4, flèches pour
  changer de page. Un joueur en sélection de personnage est signalé, sans caméra.
- Seules les cases de la page affichée ont une caméra, ouvertes une à une (150 ms d'écart : un mur 4 × 4 reste sous la
  limite de messages du core). Liste des joueurs relue toutes les 5 s, mur ouvert seulement ; caméra perdue retentée
  après 10 s.
- Un clic ouvre un écran en grand : flèches pour le joueur précédent ou suivant, `Échap` pour revenir au mur, puis pour
  le fermer. En grand, seule la vue en grand garde sa caméra. Un joueur déjà regardé en grand par un autre membre (en
  jeu ou depuis la Chancellerie) affiche « Débit du joueur déjà pris, nouvel essai bientôt » : la vue est retentée
  (10 à 15 s après, au rythme de la relecture des joueurs) et s'ouvre une fois que l'autre membre a quitté la sienne.
- Fermer le mur, revenir à la sélection ou partir éteint toutes ses caméras ; la ressource arrêtée mur ouvert rend le
  clavier et la souris au jeu.

Depuis la Chancellerie, la page **Caméras** fait le même mur dans un navigateur, et « Regarder l'écran » (fiche d'un
joueur) ouvre la vue en grand : voir `docs/chancellerie.md`.

## Ce qui part sur le réseau

- L'image va **directement** du jeu du joueur filmé au spectateur (jeu d'un membre ou navigateur) ; le serveur ne relaie
  que la négociation : une offre et une réponse de quelques Ko par caméra, au seul joueur concerné.
- Une seule capture par joueur filmé, partagée par tous ceux qui le regardent ; chacun a sa connexion et sa qualité. La
  connexion montante du joueur filmé porte le débit de chaque spectateur, borné ensemble par le budget (voir plus bas) ;
  WebRTC le baisse encore de lui-même si elle sature.
- L'offre (jusqu'à 20 000 octets) part au membre en jeu en envoi latent, à 32 000 octets par seconde : un mur 4 × 4 en
  reçoit seize sans occuper la voie fiable de son jeu. La réponse du membre (quelques Ko) reste un envoi simple.
- Personne ne regarde : ni dessin ni capture chez le joueur.

## Débit montant du joueur filmé

Avant 1.3.0, chaque spectateur avait son propre débit : 6 spectateurs en vue en grand prenaient jusqu'à 7,2 Mbit/s sur
la connexion montante d'un joueur qui n'a rien demandé, celle qui porte aussi son jeu et sa voix. Désormais :

- **Budget** : 1 500 kbit/s pour tous ses spectateurs ensemble (`budget.uplinkKbps`), en jeu comme depuis la
  Chancellerie. C'est le débit visé par les encodeurs : sur le fil, compter environ 1,6 Mbit/s (en-têtes RTP, SRTP,
  UDP et IP : 6 à 10 %, retransmissions, images clés, sondes de débit au démarrage). Régler `uplinkKbps` à 1 400 tient
  1,5 Mbit/s sur le fil.
- **Admission** (serveur, `server/sessions.lua`, après la limite de 6 spectateurs) : une seule vue en grand à la fois
  (`budget.perQuality.full`), et la somme des planchers (`minKbps`) de tous les spectateurs sous le budget. Sinon :
  refus `budget`, sans rien demander au joueur filmé. Avec les valeurs par défaut, seule la seconde vue en grand est
  refusée (6 spectateurs dont une vue en grand : 1 200 kbit/s de planchers). Le mur ne met pas ce refus parmi les fins
  définitives : la caméra est retentée comme une caméra perdue, le débit se libérant quand un spectateur s'en va.
  Une case refusée faute de mur ouvert (`wall_closed`) l'est avant toute limite et ne compte dans aucun budget.
- **Répartition** (règle pure, `shared/budget.lua`) : chacun reçoit son plancher ; le reste va d'abord à la vue en grand
  jusqu'à son plafond, puis aux cases, à parts égales jusqu'au leur. Deux spectateurs de même qualité ont toujours le
  même débit.
- **Application** : la part d'une caméra nouvelle part avec l'ordre de capture ; les parts des autres caméras qui
  changent (arrivée ou départ d'un spectateur) partent au seul joueur filmé (`vava_cameras:rates`), avant l'ordre de
  la caméra nouvelle quand elles baissent. Sa page les applique à chaque encodeur par `setParameters`, sans nouvelle
  offre (une seule offre par caméra).

| Spectateurs du joueur filmé | Vue en grand | Chaque case | Total |
| --- | --- | --- | --- |
| 1 vue en grand | 1 200 | — | 1 200 |
| 1 à 6 cases | — | 250 | 250 à 1 500 |
| 1 vue en grand + 1 case | 1 200 | 250 | 1 450 |
| 1 vue en grand + 2 cases | 1 200 | 150 | 1 500 |
| 1 vue en grand + 3 cases | 1 140 | 120 | 1 500 |
| 1 vue en grand + 4 cases | 1 020 | 120 | 1 500 |
| 1 vue en grand + 5 cases | 900 | 120 | 1 500 |

(kbit/s visés par les encodeurs, sans les en-têtes ni les retransmissions ; `tests/spec/cameras_budget_spec.lua`
vérifie ce tableau.)

## Sécurité

- Chaque demande du membre est un RPC du core à schéma strict et à débit limité ; le droit `watch` est revérifié à
  chaque caméra. Seul le joueur filmé envoie l'offre de sa caméra, une seule fois (une seconde offre est refusée,
  `already_offered`, et rien n'est relayé : une renégociation passe par une nouvelle caméra) ; seul son spectateur y
  répond (une fois) ou la ferme. Identifiants de caméra tirés au hasard (24 chiffres hexadécimaux).
- **Pas de case sans mur ouvert** : le serveur tient pour chaque membre en jeu un état « mur ouvert », posé à
  l'ouverture du mur (inscrite au journal), levé quand il le ferme, revient à la sélection, part ou perd le droit de
  regarder ; il ne vaut que 2 h (`wall.maxOpenMs`), après quoi il faut rouvrir le mur (nouvelle ligne au journal).
  Sans lui, une case est refusée (`wall_closed`) ; au premier refus, le mur cesse de demander des cases et chacune
  affiche « Mur à rouvrir », sans nouvel essai, jusqu'à sa réouverture : nul ne regarde en cases sans une ligne « Mur
  des caméras ouvert » de moins de 2 h. La vue en grand n'en dépend pas : chacune est inscrite.
  Depuis le web, le pont inscrit la première case d'un compte qui n'a pas ouvert de mur (voir le README du pont).
- Une caméra s'éteint quand le joueur filmé quitte le jeu (sélection, départ), quand son spectateur ferme le mur,
  revient à la sélection, part, ou perd le droit de regarder (rang donné ou retiré, relu au hook `vava_admin:action` ;
  son mur affiche « Droit refusé »). Depuis le web, le pont fait revérifier par la Chancellerie le rang de chaque compte
  qui regarde.
- Journal du Conseil : l'ouverture du mur et chaque vue en grand (les cases d'un mur sont couvertes par l'ouverture,
  exigée par le serveur). Le joueur n'est pas prévenu.
- Le WebRTC direct révèle l'adresse IP du joueur filmé au spectateur, et inversement ; derrière certains pare-feux, la
  connexion directe échoue (aucun relais TURN). Avec le DLSS activé, l'image peut inclure les interfaces du jeu.

## Pour les autres modules

Exports serveur `count()` (caméras ouvertes) et, réservés au pont de la Chancellerie, `webPlayers`, `webCheck`
(caméra accordable, sans rien ouvrir : 1.3.0), `webStart`, `webAnswer`, `webStop` ; hook `vava_cameras:web` (offre et fin des caméras regardées depuis le web). Détail :
`docs/api.md`, section `vava_cameras`.

## Arborescence

```
vava_cameras/
├── fxmanifest.lua · config.lua
├── shared/   constants.lua (protocole) · budget.lua (débit montant, chargé par le serveur seul)
├── server/   core · links (Conseil) · players (joueurs regardables) · sessions (caméras) · api · commands · main
├── client/   core · nui · capture (joueur filmé) · wall (mur du membre) · main
└── web/      index.html · css/wall.css · js/ (strings, bridge, capture, viewer, wall, devmock)
```

Pour travailler le rendu du mur sans le jeu : `web/index.html?players=11&layout=3` (ou `&focus=<numéro>`, et
`&budget=<numéro>` pour voir la vue en grand de ce joueur refusée) dans un navigateur ; chaque case est une vraie
connexion WebRTC locale filmant une scène dessinée.

## À vérifier en jeu

Il n'y a pas encore de procédure propre aux caméras : les tests du Registre les couvrent en partie
(`docs/tests/registre.md`, Outils et Gardien). À faire, à deux joueurs (A du Conseil, B sans rang) :

1. A : `/cameras` → le mur s'ouvre (B visible, A exclu, 3 × 3) ; journal « Mur des caméras ouvert ». Touches `1` à `4`,
   flèches ; un clic sur B : vue en grand, journal « Écran regardé ». L'image est celle du jeu de B, sans interface.
2. B revient à la sélection : sa case s'éteint et le signale ; B réapparaît : sa caméra revient d'elle-même (liste
   relue toutes les 5 s, nouvel essai 10 s après une caméra perdue).
3. B, sans rang : `/cameras` ne fait rien. B nommé Gardien : il regarde l'écran de A, même Souverain. B révoqué mur
   ouvert : « Droit refusé », ses caméras s'éteignent.
4. `restart vava_cameras` mur ouvert : le mur disparaît, la souris revient au jeu.
5. Depuis la Chancellerie : page Caméras, puis « Regarder l'écran » sur la fiche de B.
6. Resmon de B pendant qu'on le regarde (capture active), puis au repos une fois le mur fermé.
7. Offre unique et case sans mur (1.2.0) : `docs/tests/registre.md`, § 10, tests 9 à 12.
8. Débit montant du joueur filmé (1.3.0) : `docs/tests/registre.md`, § 10, tests 15 à 20 (images par seconde et ping
   du joueur filmé par 1, 3 et 6 membres, netteté de la vue en grand avec 5 cases, vue en grand unique, refus `budget`
   depuis la Chancellerie, taille réelle d'une offre).
