# T-157 — Contrat entre le chargeur Lua de `vava_atelier` et l'amorce de sa page (`web/boot.js`)

Fixé par `vava-dev-lua` d'après la spec `docs/plan/specs/T-157.md` § 6.3 et § 9.1, pour ce que la spec ne fixe pas. Tous
les messages Lua → page partent par `client/nui.lua` (`SendNUIMessage({ action = nom, payload = charge })`) ; les
rappels page → Lua sont des POST `https://<ressource>/<nom>` (corps JSON), enregistrés par l'amorce Lua au démarrage de
la ressource (`client/loader.lua`, par `nui.on`) et répondus `{ ok = true }`. Rien ne passe sur le réseau ; aucun message
à chaque image : une fois par séance de jeu (redémarrage de la ressource compris).

## Rappels page → Lua

| Rappel | Corps | Quand |
|---|---|---|
| `pageReady` | `{}` | au chargement de `boot.js` ; et en réponse à `hello` **tant que `bootEnd` n'a pas été traité** |
| `booted` | `{ ok: true, count }` ou `{ ok: false, piece }` | après le traitement de `bootEnd` ; et de nouveau, **même contenu**, en réponse à un `hello` reçu après ce traitement |

- `count` : entier, nombre de fichiers insérés (= `bootEnd.count`).
- `piece` : `name` du premier fichier dont la marque n'a pas été atteinte (erreur de syntaxe ou d'exécution), ou
  `'refus'` si un `bootPiece` a été refusé par `Boot.accept` ou si le nombre accepté diffère de `bootEnd.count`.
- Le Lua lit : `ok === true` et `count` égal au nombre envoyé → page prête ; `ok === false` → échec (« Les registres de
  l'Atelier n'ont pas pu être ouverts… », plus d'essai dans la séance) ; toute autre forme → échec. `piece` n'est écrit
  qu'en console F8, coupé à 96 octets.

## Messages Lua → page

| `action` | `payload` | Règles |
|---|---|---|
| `hello` | `{}` | envoyé par le Lua quand il n'a pas encore reçu `pageReady`, ou pour relancer une page restée muette (F9 suivant) |
| `bootPiece` | `{ index, kind, name, code }` | un par fichier `C`/`J` du paquet, dans l'ordre de `vava_conseil_web` |
| `bootEnd` | `{ count }` | après le dernier `bootPiece` |

`bootPiece` :
- `index` : entier, **0** pour le premier, puis 1, 2… sans trou (le Lua numérote dans l'ordre d'envoi) ;
- `kind` : `'css'` (genre `C` du paquet) ou `'js'` (genre `J`) ;
- `name` : chemin dans la ressource, tel qu'au manifeste : `'web/css/style.css'`, `'web/js/app.js'`… Règle (celle de
  `codepack.validName`) : 1 à 96 octets ; segments séparés par `/`, 5 au plus ; chaque segment sauf le dernier
  `^[a-z][a-z0-9_-]*$`, le dernier `^[a-z][a-z0-9_-]*\.[a-z]+$` ; extension `.css` pour `css`, `.js` pour `js` ; jamais
  `..`, `\`, `/` en tête ;
- `code` : chaîne, le fichier entier (fins de ligne `\n`), rien ajouté devant (les numéros de ligne sont ceux du fichier
  d'origine).

Bornes que la page applique (copies de `VavaAtelier.CODEPACK`, vérifiées par `tests/spec/atelier_delivery_spec.lua` dans
`web/boot.js`) : `MAX_PIECES = 48`, `MAX_BYTES = 524288` (somme des `code.length` : la longueur JS, en unités UTF-16, ne
dépasse jamais les octets UTF-8), `MAX_NAME = 96`. Ces trois noms sont écrits tels quels dans `boot.js`
(`MAX_PIECES = 48`, …) : l'essai Lua les y lit par motif `MAX_PIECES%s*[=:]%s*(%d+)`.

`bootEnd` :
- `count` : entier, nombre de `bootPiece` envoyés ;
- la page insère seulement si tous les `bootPiece` ont été acceptés et que leur nombre vaut `count` ; sinon elle
  n'insère **rien** et rend `booted { ok: false, piece: 'refus' }` ;
- après `bootEnd`, plus aucun `bootPiece` ni `bootEnd` n'est lu (aucune réinjection) ; seul `hello` reçoit une réponse
  (le même `booted`).

## Déroulé côté Lua (pour mémoire)

1. Si `pageReady` n'est pas encore venu : `hello`, attente de `pageReady` au plus `delivery.pageWaitMs` (5 s).
2. Les `bootPiece`, puis `bootEnd` ; attente de `booted` au plus `delivery.bootWaitMs` (5 s).
3. Page muette (aucun `booted`) : état « Lua prêt » ; au F9 suivant, `hello` puis attente du premier des deux rappels :
   `booted` (la page avait inséré, réponse perdue) → lu comme en 2 ; `pageReady` (la page n'avait rien reçu, ou s'est
   rechargée) → étape 2 de nouveau.
