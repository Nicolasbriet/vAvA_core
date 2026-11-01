# T-155 — Contrat entre le Lua de `vava_hud` et sa page (chiffres des coups)

Fixé par `vava-dev-lua` d'après la spec `docs/plan/specs/T-155.md` § 6.4 et § 9, pour ce que la spec ne fixe pas. Tous
les messages partent par `client/nui.lua` (`SendNUIMessage({ action = nom, payload = charge })`), jamais avant que la
page se dise prête, jamais à chaque image. Aucun ne passe sur le réseau.

## `init` (existant) : une clé de plus

`payload.numbers = { durationMs, riseVh, followMs, maxAlive, maxPerSecond }` — valeurs de `config_client.lua`
(`numbers`), contrôlées au démarrage du Lua (bornes de la spec § 4.1 : 400 à 3 000 ; 0 à 20 ; 50 à 500 ; 1 à 30 ; 1 à
60). La page les relit et garde ses valeurs de base pour une valeur absente ou hors bornes.

## `number` : un chiffre créé

```
{ id, x, y, dx, dy, text, sub?, cls }
```

| Champ | Forme |
|---|---|
| `id` | entier ≥ 1, croissant (compteur du Lua, jamais réutilisé pendant la vie de la ressource) |
| `x`, `y` | position à l'écran de l'**ancre** (tête de la cible + `headOffset`, ou point fixe), en part de la largeur et de la hauteur (0 à 1, bornée par le Lua) ; pour un chiffre reçu dont la tête est hors de l'écran : `takenFallback` |
| `dx` | décalage de cascade de côté, en **vw** (crans alternés gauche / droite + petit hasard) ; 0 au premier cran |
| `dy` | décalage de cascade en hauteur, en **vh**, **négatif vers le haut** (0 au premier cran, − `stackStepVh` × cran) |
| `text` | chiffre déjà mis en forme (« 12 », « 7,2 ») ou mot (« Paré », « Sans effet »…), 1 à 32 octets |
| `sub` | mot sous le chiffre (« Bloqué », « Garde brisée », « Chancelle », « À terre ») ; **absent** sinon |
| `cls` | chaîne de classes séparées par une espace, dans cet ordre : côté `dealt` ou `taken` (toujours), puis une taille au plus `small` (morsure, zone qui dure), `big` (chancelle), `huge` (à terre), puis `word` si `text` est un mot. Ex. : `'dealt'`, `'taken big'`, `'dealt word'`, `'taken huge'` |

Le décalage `dx`, `dy` est donné **une fois** ; la page le garde et l'ajoute à chaque position reçue ensuite.

## `numbersMove` : positions suivies

```
{ list = { { id, x, y, hidden? }, … } }
```

- Au plus un message par `followMs` (100 ms), seulement si un chiffre a bougé de plus de `followEpsilon` (part de
  l'écran) ou a changé d'état caché / visible ; au plus `maxAlive` entrées.
- `x`, `y` : nouvelle position de l'**ancre** (sans le décalage de cascade), 0 à 1.
- `hidden = true` : l'ancre est sortie de l'écran (chiffre donné) ou sa cible a disparu ; `x`, `y` sont alors absents.
  `hidden` absent : visible (la page retire son masque). L'animation continue pendant qu'il est caché.
- Un `id` inconnu de la page (déjà retiré à la fin de son animation, page rechargée) est ignoré.

## `numbersClear` : tout effacer

`{}` — HUD masqué (sélection, bannière, menu de GTA, fondu), personnage déchargé. Envoyé une fois (rien s'il n'y avait
aucun chiffre depuis le dernier effacement).

## Vie d'un chiffre

Le Lua oublie un chiffre à `durationMs` après sa création (il ne le suit plus) ; la page le retire à la fin de son
animation. Au-delà de `maxAlive`, le Lua oublie le plus ancien sans message : la page retire elle aussi son plus ancien
quand un `number` de trop arrive.
