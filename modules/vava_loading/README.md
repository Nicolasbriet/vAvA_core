# vava_loading — l'écran de chargement d'Eldoria

Dès qu'il se connecte, le voyageur voit Eldoria s'allumer : le nom du royaume s'embrase lettre à lettre, un paysage de
nuit s'anime, des paroles du bourg et des conseils défilent, et **six feux de veille** s'allument au rythme **réel** du
chargement. Quand le dernier feu brûle et que la sélection du personnage est prête, un éclair doré « Le Conseil vous
attend » se dissout sur le Registre des âmes, **sans écran noir**.

Ressource **cliente uniquement** : aucun RPC, aucun évènement réseau, aucun state bag, aucune donnée en base. Tout ce
que l'écran montre est dans ses fichiers ou vient du jeu local. Le seul coût réseau est le téléchargement de ses
fichiers (≈ 216 Ko, une fois par version, mis en cache par FiveM).

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

## Règles du client Lua (`config.lua`)

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

La page s'affiche **avant** que le moindre script Lua tourne : elle ne peut pas lire `config.lua`. Ses réglages sont
donc dans deux fichiers à elle (décision 5 de la spec, écart assumé à « tout dans `config.lua` ») ; la seule durée
partagée, celle de l'éclair, est envoyée par le Lua avec le message de passage.

| Règle | Défaut | Clé |
|---|---|---|
| Seuils des six feux (%) : position sur le chemin et plancher de l'étape ; recalibrés après le premier test en jeu | `[0, 12, 38, 72, 88, 97]` | `stages` |
| Ouverture à chaque connexion, passable d'un clic | oui ; filet 300 ms, 1re lettre 1 100 ms, puis 190 ms par lettre, rideau 300 ms après | `opening.*` |
| Changement d'extrait, de conseil | 9 s, 6,5 s (fondu 900 ms) | `rotation.*` |
| Niveau d'effets | `auto` (`haute`, `moyenne`, `basse`) | `effects.level` |
| Cadence des canvas au plus ; dégradation sous `minFps` sur `badWindows` fenêtres de `windowMs` | 30 i/s ; 20 i/s, 2 × 2 s | `effects.*` |
| Musique (aucune piste en 1.0.0 : bouton caché) | `''` | `music.file` |
| Journal de calibrage à l'écran (**`false` avant fusion**, le test unitaire le vérifie) | `false` | `debug.journal` |

Les textes vus du joueur sont tous dans `web/js/strings.js` (provisoires : ceux de la maquette, remplacés par T-021 en
ne touchant que ce fichier). Format fixé, vérifié par `tests/spec/loading_screen_spec.lua` : aucun `<`, 6 étapes,
6 à 40 extraits et 6 à 20 conseils de 240 octets au plus, une chaîne entre apostrophes simples par ligne ; une touche
s'écrit `[[F1]]` (3 au plus par conseil, 12 octets au plus).

**Touches citées** : celles **par défaut** de `vava_codex` (F1), `vava_inventory` (I), `vava_voice` (Z) et `vava_chat`
(T) ; la page ne peut pas lire les réglages du joueur. Changer une de ces touches par défaut oblige à retoucher
`strings.js` (décision 12).

Toute retouche d'un fichier livré le fait retélécharger à chaque joueur : retouches rares et groupées.

## Poids (livré aux joueurs)

| Partie | Mesuré (1.0.0) | Plafond |
|---|---|---|
| `web/index.html`, `web/css/style.css`, `web/js/*.js` (7 fichiers) | ≈ 83 Ko | |
| `web/fonts/*.woff2` : Cinzel, EB Garamond droit et italique (copies identiques de `vava_ui`), Cinzel Decorative 900 | ≈ 134 Ko | |
| **Total livré sans musique** | **≈ 216 Ko** | **300 Ko** (700 Ko avec une piste) — test unitaire |
| Dossier entier (README, licences, `web/dev/`, Lua) | ≈ 270 Ko (visé) | **1,5 Mo** — `scripts/audit-reseau.sh`, BLOQUANT |

Aucune image, aucune vidéo, aucune ressource externe : le paysage est peint par le code, le grain est un petit SVG en
`data:`. Les licences (`web/fonts/OFL_*.txt`) et `web/dev/` restent dans le dépôt sans être livrés. Une mise à jour des
polices de `vava_ui` se reporte ici (le test compare les octets).

## Hors jeu

`web/index.html` s'ouvre dans un navigateur depuis le dépôt : en `file:`, la page charge `web/dev/devmock.js` (jamais
livré), qui rejoue des suites de messages et ajoute un panneau « Hors jeu ». Adresses : `?scenario=normal|rapide|lent|
muet|sans-selection`, `?niveau=haute|moyenne|basse`, `?vitesse=4`, `?ouverture=0`, `?fps=1`, `?journal=1`. Les
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
| `config.lua` | réglages du client Lua (sélection attendue, éclair, filets) |
| `shared/constants.lua` | `VavaLoading` (seule globale Lua), noms des messages et des hooks, bornes, fonctions pures |
| `client/core.lua` | API client du core et export de la sélection, lus sous `pcall` |
| `client/main.lua` | cycle chargement → attente → passage → fermé |
| `web/` | la page (`index.html`, `css/`, `js/`, `fonts/`) ; `web/dev/` : données simulées et essais, jamais livrés |

## À vérifier en jeu

Procédure complète : `docs/tests/chargement.md`. Par ordre d'importance :

1. **Aucun noir au passage** (3-2) : l'éclair se dissout sur la sélection déjà en place.
2. **Messages réellement reçus et seuils recalibrés** (1-4) : journal de calibrage, puis `stages` réglé et le journal
   remis à `false`.
3. **Transparence de la page à la dissolution** (3-2) : sinon la fermeture coupe au sommet de l'éclair (repli voulu,
   jamais par le noir).
4. **Runes du sceau lisibles** (2-3) : pas de carrés vides (police système `Segoe UI Historic`).
5. **Coût sur petite machine** (5-1) : écart de durée de chargement ≤ 5 % entre `basse` et `haute`, sinon défaut
   `moyenne`.
6. **Souris et clavier** sur l'écran de chargement (1-2) : « Passer l'ouverture », clic n'importe où.
7. `localStorage` gardé d'une connexion à l'autre (seulement si une musique est ajoutée).
8. **Indicateur du jeu** par-dessus le pourcentage (2-5) : sinon régler `--foot-gap`.
