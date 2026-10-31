# vava_loading — l'écran de chargement d'Eldoria

Dès qu'il se connecte, le voyageur voit Eldoria s'allumer : le nom du royaume s'embrase lettre à lettre, la cité
passe d'une lumière à l'autre (aube, brume du matin, hiver, crépuscule, nuit étoilée, brume de nuit, orage), des
paroles du bourg et des conseils défilent, et **six feux de veille** s'allument au rythme **réel** du
chargement. Quand le dernier feu brûle et que la sélection du personnage est prête, un éclair doré « Le royaume vous
attend » se dissout sur le Registre des âmes, **sans écran noir**.

Ressource **cliente uniquement** : aucun RPC, aucun évènement réseau, aucun state bag, aucune donnée en base. Tout ce
que l'écran montre est dans ses fichiers ou vient du jeu local. Le seul coût réseau est le téléchargement de ses
fichiers (≈ 1,38 Mo avec le client Lua, dont 1,15 Mo pour les sept ambiances, une fois par version, mis en cache par
FiveM).

## Installation et ordre de démarrage

- `ensure vava_loading` **juste après `vava_ui`** (avant `vava_chat` et surtout avant `vava_characters_ui`) : son
  script client doit tourner avant celui de l'écran de sélection. La Chancellerie (1.8.1) le range à cette place.
- Dépendance déclarée : `vAvA_core`. Il faut **`vAvA_core` ≥ 0.13.0** : en dessous, le core ferme lui-même l'écran de
  chargement à la mise en attente du joueur (écran noir bref avant la sélection, signalé une fois en `F8`).
- Facultatif : `vava_characters_ui` ≥ 1.2.0 (hook `vava_characters_ui:shown`, export `isShown()`). Sans lui, l'écran
  se ferme par son filet (20 s après la mise en attente).
- **Pas** de `dependency 'vava_ui'` : la page s'affiche avant le téléchargement des autres ressources et ne peut pas
  lire `nui://vava_ui/…` ; elle embarque ses polices (exception d'audit `modules/vava_loading/web/fonts/`, décision 2 de
  T-012).
- `restart vAvA_core` arrête aussi `vava_loading` (dépendance) : sans effet pour les joueurs déjà en jeu, il redémarre
  avec le serveur.

## Comment l'écran se ferme

```
loading ──(core:character:selection)──▶ waiting ──(vava_characters_ui:shown)──▶ handoff ──(handoffMs)──▶ closed
```

| Moment | Ce que fait `client/main.lua` | Ce que voit le joueur |
|---|---|---|
| le script client démarre | message `vava_loading:resources` | 4e feu au moins |
| le core met le joueur en attente (session ouverte) | message `vava_loading:waiting` ; filet de `selectionFallbackMs` | 6e feu, « Le bourg prépare votre arrivée » |
| la sélection est affichée (hook, ou export lu au démarrage) | message `vava_loading:handoff { ms = handoffMs }` | 100 %, éclair, puis la page se dissout sur la sélection |
| `handoffMs` plus tard | `ShutdownLoadingScreenNui()` | la sélection, souris active |

Seul le client Lua de `vava_loading` envoie ces trois messages. La page ne sait pas qui les envoie
(`SendLoadingScreenMessage` est ouvert à toute ressource cliente du serveur) : une autre ressource qui enverrait
`vava_loading:handoff` ferait jouer l'éclair trop tôt, sur ce seul client. Aucune ressource ne doit le faire.

Le core (`spawn.loadingScreen` de `config/shared.lua`, 0.13.0) ne ferme plus l'écran à la première mise en attente quand
`vava_loading` tourne : il fait son fondu au noir **sous** l'écran de chargement. Quatre chemins de fermeture, l'écran
ne peut pas rester bloqué :

1. `vava_loading` à la fin de l'éclair (sélection affichée) ;
2. son filet : `selectionFallbackMs` (20 s) après la mise en attente, passage quand même ;
3. le filet du core : `spawn.loadingScreen.maxHoldMs` (30 s) après la première mise en attente ;
4. l'apparition d'un personnage (`perform()` du core, et hook `core:character:loaded` ici : fermeture immédiate).

Aussi : fermeture à l'arrêt de la ressource ; sans API du core, fermeture dès que la session réseau est ouverte
(attente toutes les `noCorePollMs`, sans éclair). Un retour à la sélection en cours de jeu (`/perso quitter`) n'a pas
d'écran de chargement : l'état est `closed`, rien ne se passe.

## Règles du client Lua (`config_client.lua`)

Ressource cliente uniquement : ces réglages sont dans `config_client.lua` (nommé `config.lua` avant 1.2.0, T-132 :
`config.lua` est réservé aux réglages du seul serveur, jamais téléchargés). **Mise à jour vers 1.2.0** : un
`config.lua` modifié est gardé par l'installeur de la Chancellerie, qui le signale (« reportez vos réglages dans
config_client.lua »), mais il n'est plus au manifeste et n'est plus lu : reportez vos réglages dans
`config_client.lua`, puis supprimez l'ancien fichier.

| Règle | Défaut | Clé |
|---|---|---|
| Core attendu (en dessous : noir bref, avertissement en `F8`) | `0.13.0` | `coreVersion` |
| Écran de sélection attendu | `vava_characters_ui` | `selection.resource` |
| Hook client émis quand il est affiché | `vava_characters_ui:shown` | `selection.shownHook` |
| Export lu au démarrage (hook déjà passé) | `isShown` | `selection.isShownExport` |
| Durée de l'éclair et du fondu, envoyée à la page | 1 800 ms (bornée de 300 à 5 000) | `handoffMs` |
| Sélection jamais signalée affichée : passage quand même | 20 000 ms (au-delà des 10 s d'un RPC du core) | `selectionFallbackMs` |
| Sans API du core : intervalle d'attente de la session | 250 ms | `noCorePollMs` |

Un autre écran de sélection n'a qu'à émettre son propre hook client (dans son espace de noms) quand il est affiché,
exposer un export équivalent, et être nommé dans `selection.*`.

## Réglages de la page (`web/js/config.js`) et textes (`web/js/strings.js`)

La page s'affiche **avant** que le moindre script Lua tourne : elle ne peut pas lire `config_client.lua`. Ses réglages
sont donc dans deux fichiers à elle (décision 5 de la spec, écart assumé à « tout dans la config Lua ») ; la seule durée
partagée, celle de l'éclair, est envoyée par le Lua avec le message de passage.

| Règle | Défaut | Clé |
|---|---|---|
| Seuils des six feux (%) : position sur le chemin et plancher de l'étape ; recalibrés après le premier test en jeu | `[0, 12, 38, 72, 88, 97]` | `stages` |
| Ouverture à chaque connexion, passable d'un clic | oui ; filet 300 ms, 1re lettre 1 100 ms, puis 190 ms par lettre, rideau 300 ms après | `opening.*` |
| Changement d'extrait, de conseil | 9 s, 6,5 s (fondu 900 ms) | `rotation.*` |
| Ambiances, dans leur ordre (noms des fichiers de `web/img/ambiances/`, sans `.webp` ; 12 au plus). La première est tirée au hasard, puis la suite de la liste, en boucle ; une image manquante ou illisible est sautée pour de bon ; aucune lisible : le dégradé de nuit reste | `aube`, `brume_matin`, `hiver`, `crepuscule`, `nuit_etoilee`, `brume_nuit`, `orage` | `ambiances.order` |
| Durée d'une ambiance, du début de son fondu au début du suivant (la première est comptée depuis la levée du rideau) | 9 000 ms (3 000 à 60 000) | `ambiances.showMs` |
| Fondu enchaîné (opacité seule) | 3 000 ms (300 à 6 000, jamais plus de la moitié de `showMs`) | `ambiances.fadeMs` |
| Dérive lente de l'image (zoom et glissement, sens alterné) ; jamais en `basse` ni quand le joueur demande moins d'animations | 3 % (0 à 5 ; 0 : fondu seul) | `ambiances.driftPct` |
| Niveau d'effets (`auto` : `basse` si le joueur demande moins d'animations, `moyenne` jusqu'à 4 cœurs, sinon `haute`) | `auto` (`haute`, `moyenne`, `basse`) | `effects.level` |
| Cadence au plus des braises et étincelles | 30 i/s | `effects.fpsMax` |
| Dégradation sous `minFps` sur `badWindows` fenêtres de `windowMs` | 20 i/s, 2 × 2 s | `effects.*` |
| Par niveau : braises, étincelles, parallaxe de la souris (ambiances et braises), dérive des ambiances (`drift`), grain (`no-grain`), reflet du titre (`no-shine`) ; en `basse`, plus rien n'est animé par le script, la dérive en cours s'arrête sur place, les ambiances continuent en fondu seul, seule la flamme du feu en cours bouge encore | voir le fichier | `effects.levels.*` |
| Musique (aucune piste en 1.0.0 : bouton caché) | `''` | `music.file` |
| Journal de calibrage à l'écran (**`false` avant fusion**, le test unitaire le vérifie) | `false` | `debug.journal` |

Les réglages `ambiances.*` sont bornés par `web/js/ambiances.js` (hors bornes : ramenés à la borne ; pas un nombre :
le défaut ; ordre sans nom valable : les sept) ; aucune image n'est lue hors de `web/img/ambiances/`. Ajouter une
ambiance : son WebP dans ce dossier (1600 × 900, qualité 50, 300 Ko au plus), son nom dans `ambiances.order`, et le
poids total vérifié (plafond de 1,5 Mo ci-dessous).

Les textes vus du joueur sont tous dans `web/js/strings.js` (définitifs depuis 1.1.0, T-021 : 28 extraits du lore,
15 conseils). Format fixé, vérifié par `tests/spec/loading_screen_spec.lua` : aucun `<`, 6 étapes, 6 à 40 extraits et
6 à 20 conseils de 240 octets au plus, une chaîne entre apostrophes simples par ligne ; une touche s'écrit `[[F1]]`
(3 au plus par conseil, 12 octets au plus). Chaque conseil décrit le jeu tel qu'il est codé : une règle qui change
dans un module (récolte, agriculture, santé, compétences…) fait relire le conseil qui en parle.

**Touches citées** : celles **par défaut** de `vava_codex` (F1), `vava_inventory` (I), `vava_chat` (T),
`vava_skills` (K), `vava_health` (G, relever) et `vava_gathering` (O) ; la page ne peut pas lire les réglages du
joueur. Changer une de ces touches par défaut oblige à retoucher `strings.js` (décision 12, rappel dans les README de
ces modules). Seules sont citées des touches à la même place en QWERTY et en AZERTY (FiveM nomme les touches d'après
le QWERTY) : la touche de la voix (`Z`, le W d'un clavier AZERTY) et les chiffres de la ceinture ne le sont pas, le
conseil renvoie au Codex, qui montre la touche réellement liée.

Toute retouche d'un fichier livré le fait retélécharger à chaque joueur : retouches rares et groupées.

**Seuils des feux (`stages`)** : les calibrer avec le journal (`debug.journal`) **sur le serveur de test seulement**,
puis publier les seuils recalibrés **dans le même envoi que les textes de T-021** (`strings.js`). Chaque retouche de la
page fait retélécharger les fichiers retouchés à chaque joueur : une seule publication pour les deux.

## Poids (livré aux joueurs)

| Partie | 1.2.0 | Mesuré (1.3.0) | Plafond |
|---|---|---|---|
| `web/index.html`, `web/css/style.css`, `web/js/*.js` (8 fichiers en 1.3.0) | 93 518 o | 92 437 o | |
| `web/fonts/*.woff2` : Cinzel, EB Garamond droit et italique (copies identiques de `vava_ui`), Cinzel Decorative 900 | 132 748 o | 132 748 o | |
| **Code et polices** | **226 266 o** | **225 185 o** | **300 Ko** (700 Ko avec une piste) — test unitaire |
| `web/img/ambiances/*.webp` : sept ambiances 1600 × 900, qualité 50 (de 104 à 257 Ko chacune) | — | 1 208 910 o | 300 Ko chacune — essais de la page |
| **Page entière** | 226 266 o | **1 434 095 o (≈ 1,37 Mo)** | **1,5 Mo** — test unitaire |
| Avec le manifeste et le client Lua (téléchargé par chaque joueur) | ≈ 234 Ko | ≈ 1,38 Mo | |
| Dossier entier (README, licences, `web/dev/`, Lua) | | voir le rapport de T-152 | **1,5 Mo** — `scripts/audit-reseau.sh`, BLOQUANT |

En 1.3.0 (T-152), le paysage peint par le code est retiré : le code livré baisse d'un peu plus d'1 Ko malgré la
logique des ambiances ; les sept peintures (1,15 Mo) sont le seul ajout. Elles ne sont pas toutes chargées d'un coup :
la page décode la suivante seulement après l'affichage de la courante (mais FiveM télécharge tout le dossier livré à
la première connexion, puis le garde en cache).

Aucune vidéo, aucune ressource externe : les ambiances sont des WebP du dossier `web/img/ambiances/`, le grain est un
petit SVG en `data:`. Les licences (`web/fonts/OFL_*.txt`) et `web/dev/` restent dans le dépôt sans être livrés. Une
mise à jour des polices de `vava_ui` se reporte ici (le test compare les octets).

## Hors jeu

`web/index.html` s'ouvre dans un navigateur depuis le dépôt : en `file:`, la page charge `web/dev/devmock.js` (jamais
livré), qui rejoue des suites de messages et ajoute un panneau « Hors jeu ». Adresses : `?scenario=normal|rapide|lent|
muet|sans-selection`, `?niveau=haute|moyenne|basse`, `?vitesse=4`, `?ouverture=0`, `?fps=1` (cadence, niveau et ambiance à l'écran), `?journal=1`,
`?ambiances=hiver,absente,orage` (un nom sans fichier montre le saut d'une image manquante ; que des noms absents : le
fond de repli), `?tenue=4000` (durée d'une ambiance), `?derive=0` (dérive en %, mesure de 5-5) ; bouton « Ambiance suivante ».
Le dossier `web/img/ambiances/` ne contient que les WebP de `ambiances.order` (vérifié par le test unitaire et les
essais) : le joker du manifeste livrerait tout autre `.webp` qui y serait laissé. Les
fonctions pures de la page s'essaient par `web/dev/essais.html` (navigateur) ou `node
modules/vava_loading/web/dev/essais.js` (lancé aussi par `scripts/verifier.sh` quand `node` est présent).

## Sécurité et coût

- Aucune entrée réseau : rien n'est demandé au serveur, rien n'est décidé. La sélection, la création et l'apparition
  restent au core et à `vava_characters_ui`.
- Messages reçus par la page : liste blanche de noms, `type` dans l'énumération, nombres finis et bornés, chaîne de
  2 048 caractères au plus ; aucune chaîne venue d'un message n'est affichée ; aucun `innerHTML`.
- Client Lua : aucune boucle permanente (resmon 0,00 ms) ; des `SetTimeout`, et un seul fil borné dans le cas « sans
  core ». Trois messages locaux par connexion, 80 octets au plus chacun.

## Fichiers

| Fichier | Rôle |
|---|---|
| `fxmanifest.lua` | `loadscreen`, fermeture à la main, souris ; motifs livrés exacts (jamais `web/dev/`) |
| `config_client.lua` | réglages du client Lua (sélection attendue, éclair, filets) ; `config.lua` avant 1.2.0 |
| `shared/constants.lua` | `VavaLoading` (seule globale Lua), noms des messages et des hooks, bornes, fonctions pures |
| `client/core.lua` | API client du core et export de la sélection, lus sous `pcall` |
| `client/main.lua` | cycle chargement → attente → passage → fermé |
| `web/` | la page (`index.html`, `css/`, `js/`, `fonts/`, `img/ambiances/`) ; `web/dev/` : données simulées et essais, jamais livrés |
| `web/js/ambiances.js` | logique pure des ambiances (réglages bornés, ordre, image sautée, dérive) ; `web/js/scene.js` : calques, fondu, braises |

## À vérifier en jeu

Procédure complète : `docs/tests/chargement.md`. Par ordre d'importance :

1. **Aucun noir au passage** (3-2) : l'éclair se dissout sur la sélection déjà en place.
2. **Messages réellement reçus et seuils recalibrés** (1-4) : journal de calibrage sur le serveur de test seulement,
   puis `stages` réglé, le journal remis à `false`, et les seuils publiés avec les textes de T-021 (un seul
   retéléchargement).
3. **Transparence de la page à la dissolution** (3-2) : sinon la fermeture coupe au sommet de l'éclair (repli voulu,
   jamais par le noir).
4. **Runes du sceau lisibles** (2-3) : pas de carrés vides (police système `Segoe UI Historic`).
5. **Coût sur petite machine** (5-1) : écart de durée de chargement ≤ 5 % entre `basse` et `haute`, sinon défaut
   `moyenne`.
6. **Souris et clavier** sur l'écran de chargement (1-2) : « Passer l'ouverture », clic n'importe où.
7. `localStorage` gardé d'une connexion à l'autre (seulement si une musique est ajoutée).
8. **Indicateur du jeu** par-dessus le pourcentage (2-5) : sinon régler `--foot-gap`.
9. **Ambiances** (2-7 à 2-11) : ordre et rebouclage, fondu sans écran vide ni creux de lumière, image renommée sautée,
   `basse` sans dérive, coût du fondu sur petite machine.
10. **Coût de la dérive** (5-5) : mesurée seule (`driftPct` 3 puis 0) et vérifiée une fois composée dans le panneau
    Performance de Chrome. Si l'écart se voit, repli : `animation-timing-function: steps(360)` sur `.amb img.drift`
    (≈ 30 pas par seconde, invisibles) ou `driftPct: 0` en `moyenne` ; rien n'est changé tant que ce n'est pas mesuré.
11. **Premier téléchargement** (5-6) : cache FiveM vidé, délai jusqu'à l'apparition de l'écran d'Eldoria noté.
