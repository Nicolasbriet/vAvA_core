# Audit réseau et performance — vava_admin 1.7.0 — 30 octobre 2026 (T-011)

## Périmètre

Registre du Conseil : rangs et droits, sanctions, signalements, annonces, outils (vol, observation, repère).
Lus : `server/requests.lua` (`:160-188`), `server/reports.lua` (`:40-75`), `server/actions.lua` (`:45-56`),
`server/players.lua` (`:60-80`), `server/staff.lua` (`:140-180`), `client/tools.lua`, `client/main.lua`,
`config.lua`, `fxmanifest.lua`.

## Envois serveur → client

| Évènement | Fichier:ligne | Cible | Taille estimée | Fréquence |
|---|---|---|---|---|
| `ANNOUNCE` | `server/requests.lua:177` | **tous les joueurs** (exception inscrite dans `scripts/audit-exceptions.txt`) | 50 o + texte | annonce du Conseil, réservée à un droit, rare |
| `REPORT` (signalement) | `server/reports.lua:72` | les membres en jeu qui ont le droit `reports` | 150 o | par signalement (délai d'une minute par joueur, `config.lua:45`) |
| `NOTIFY` | `server/actions.lua:54`, `server/reports.lua:47` | le joueur concerné | 50-150 o | messages |
| réponses du panneau (joueurs, sanctions, journal) | RPC | le membre du Conseil | 64 joueurs × 80 o ≈ 5 Ko pour la liste | à l'ouverture et aux actions |

## GlobalState, state bags

Aucun (le champ d'observation `server/spectate.lua:162` est `private`).

## Boucles client

| Boucle | Fichier:ligne | Au repos | En action | Remarque |
|---|---|---|---|---|
| vol libre | `client/tools.lua:109-123` | — | par image pendant le vol (Conseil) | justifié : lecture des touches |
| recherche du sol pour le repère | `client/tools.lua:162-169` | — | 50 ms, quelques hauteurs | borné |
| observation | `client/tools.lua:234-250` | — | 100 ms (attente du ped, 3 s au plus), puis 1 s tant qu'on observe | |

## NUI et fichiers web

`web/` : 335 882 o, dont 243 457 o communs (T-012) ; `web/js/devmock.js` (6 876 o) livré. Le panneau ne sert qu'au
Conseil mais il est **téléchargé par tous les joueurs** (FiveM livre les `files` de toute ressource démarrée).

## BLOQUANT

Aucun.

## IMPORTANT

Aucun.

## MINEUR

- `fxmanifest.lua` (`files`) — **panneau du Conseil téléchargé par chaque joueur** — environ 92 Ko propres au module
  après T-012. À garder en tête pour le poids de la première connexion ; une séparation (page chargée à la demande) ne
  vaut la peine que si la mesure de T-019 le justifie.

## Points solides

- Le seul envoi à tous du dépôt qui soit voulu est inscrit aux exceptions et réservé à un droit.
- Signalements envoyés aux seuls membres qui peuvent les traiter ; boucles d'outils liées à leur état.

VERDICT : OK
