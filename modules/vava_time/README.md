# vava_time — l'heure, les saisons et le ciel du royaume

Tous les joueurs vivent la même heure, la même saison et le même ciel. L'**heure du royaume** suit l'horloge de Paris
(heure d'été comprise), au rythme réel ; le **calendrier** suit le vrai calendrier (ou un cycle plus rapide) et donne la
saison, le jour de la saison et l'an du royaume ; le **ciel** change de lui-même selon la saison, avec des transitions
douces et sans neige hors de l'hiver. Le **Conseil** décale ou fige l'heure, impose ou fige un ciel, puis rend la main,
depuis l'outil « Ciel et heure » du Registre (`F10`), la commande `/ciel` ou la Chancellerie. Les saisons pèsent sur
l'agriculture (`vava_farming`) et la récolte (`vava_gathering`), qui les lisent par l'export `getSeason`.

Ordre de démarrage : après `vAvA_core` (≥ 0.7.0 : registre des commandes), de préférence juste après `vava_world`.
Facultatifs : `vava_admin` (droits, outil du Registre, journal ; sans lui, personne ne règle le ciel et l'heure),
`vava_hud` (notifications), `vava_chancellerie` ≥ 1.4.0 (page Ciel et heure du panneau web).

## Règles (config.lua)

| Règle | Défaut | Clé |
|---|---|---|
| Heure du royaume | heure de Paris calculée depuis l'heure UTC du serveur (la machine peut être à n'importe quelle heure) ; heure d'été du dernier dimanche de mars au dernier dimanche d'octobre, à 01:00 UTC ; une minute du jeu = une minute réelle | `clock.msPerGameMinute` |
| Décalage du Conseil | ± 12 h ; la date et la saison suivent l'heure réelle, pas le décalage | `clock.maxShiftMinutes` |
| Calendrier | vrai calendrier : printemps 20 mars, été 21 juin, automne 22 septembre, hiver 21 décembre (heure de Paris) ; l'an 1 commence au printemps 2026 et l'an change au printemps | `calendar.mode`, `calendar.starts`, `calendar.firstYear` |
| Cycle plus rapide | `calendar.mode = 'cycle'` : chaque saison dure `seasonDays` jours réels (7 ; décimaux permis pour les essais) depuis minuit (Paris) de `origin`, en commençant par `first` | `calendar.cycle` |
| Saisons | printemps « saison des semailles », été « saison des moissons », automne « saison des brumes », hiver « saison des frimas » | `calendar.seasons` |
| Ciels | treize ciels (clair, grand soleil, nuages épars, couvert, éclaircies, pluie, orage, brume de chaleur, brouillard, neige légère, neige, tempête de neige, neige au sol) ; les noms de météo de GTA ne paraissent que dans la config | `weather.types` |
| Cycle du ciel | chaque ciel dure 25 à 50 min (orage, tempête : 10 à 20), puis un successeur plausible est tiré selon les poids de la saison (pas d'orage sous un ciel clair) ; transition de 90 s | `weather.next`, `weather.seasons`, `weather.durationMinutes`, `weather.durations`, `weather.fadeSeconds` |
| Neige | en hiver seulement (neige légère, neige, tempête rare) ; « neige au sol » (traces de pas et de roues) jamais tirée par le cycle, imposable par le Conseil ; `snow = false` : aucune neige tirée | `weather.snow`, `weather.seasons.hiver` |
| Changement de saison | un ciel qui n'est plus de saison (neige au printemps) change dans les 15 s, sauf s'il est imposé ou figé | `server.tickMs` |
| Ciel imposé | transition de 20 s ; il dure le temps d'un ciel puis le cycle reprend (même hors saison), sauf s'il est figé | `council.fadeSeconds` |
| Droit du Conseil | `tools` (Sénéchal et au-dessus), comme les zones de voix ; Chancellerie : lecture au droit `view`, décisions au droit `tools` | `council.permission` |

## Joueurs

- **`/date`** : « Il est 15 h 20, le 38e jour de la saison des brumes (automne), an 1 du royaume. C'est l'après-midi :
  il pleut. » (plus « Le temps s'est arrêté sur le royaume. » si l'heure est figée). Calculé chez le joueur, sans
  réseau, et montré à lui seul.
- L'heure et le ciel s'appliquent dès l'arrivée, sélection du personnage comprise. Un joueur qui arrive pendant une
  transition part du ciel d'avant et rejoint le nouveau dans le temps qui reste.

## Conseil

**Outil « Ciel et heure »** (Registre `F10` → Outils, ou `/ciel`) : panneau sur le côté, le ciel reste visible.
- Heure du royaume (qui avance), heure réelle, décalage ; « Mettre l'heure à » heures : minutes, « − 1 h », « + 1 h »,
  « Figer l'heure » / « Laisser le temps reprendre » (l'heure repart de là où elle était figée), « Rendre l'heure
  réelle » (sans décalage ni gel).
- Calendrier : jour, saison, an.
- Ciel : courant, imposé ou figé, hors saison, prochain changement ; tampons des treize ciels (« hors saison » en
  mention) ; « le figer » ; « Imposer ce ciel », « Figer le ciel », « Rendre au cycle » (le cycle tire tout de suite le
  ciel suivant).

**`/ciel`** et ses sous-commandes (déclarées au Codex) : `heure <h> [min]`, `decaler <heures>`, `figer`, `reprendre`,
`reelle`, `meteo <ciel> [figer]`, `garder`, `cycle`.

Chaque décision est revérifiée par le serveur (droit, valeur bornée, ciel connu), publiée à tous les joueurs, écrite
en base (`vava_time_state`, une ligne) et inscrite au journal du Registre si elle change quelque chose : « Heure du
royaume réglée / décalée / figée / reprise », « Heure réelle rendue », « Ciel imposé / figé / rendu au cycle », avec
l'heure, le décalage, le ciel et s'il est figé. Depuis la Chancellerie, au nom de « Chancellerie : <compte> ».

## Réseau et performance

- **GlobalState** (usage légitime : petit, rare, utile à tous) : `vava_time:clock` `{ shift, frozen }` (~25 o, à chaque
  décision sur l'heure), `vava_time:weather` `{ id, from, at, fade, forced, frozen }` (~70 o, à chaque ciel : toutes les
  25 à 50 min), `vava_time:calendar` `{ season, day, year }` (~35 o, une fois par jour). Retirés à l'arrêt du module.
- **RPC** : `vava_time:sync` (heure UTC du serveur, à l'arrivée puis toutes les 30 min), `open`, `clock`, `weather`
  (Conseil). Aucun évènement serveur → client.
- **Client** : aucune boucle par image. Le jeu fait avancer l'horloge seul ; recalage local toutes les 60 s (aucun
  réseau) ; un thread attend la fin d'une transition pour poser le ciel. À l'arrêt de la ressource, l'heure et la
  météo sont rendues au jeu.
- Le serveur relit la date et la fin du ciel toutes les 15 s (calcul en mémoire).

## Pour les autres modules

| Export serveur | Retour |
|---|---|
| `getSeason()` | `printemps`, `ete`, `automne`, `hiver`, ou `nil` avant le démarrage |
| `getCalendar()` | `{ season, label, name, day, year, text }` |
| `getClock()` | `{ hour, minute, seconds, frozen, shift }` |
| `getWeather()` | `{ id, label, forced, frozen }` |

Exports client : `getClock()` (`{ hour, minute, frozen }`), `getSeason()`, `getWeather()` (identifiant).

Hooks serveur (`after`) : `vava_time:seasonChanged` `{ season, previous, day, year }`, `vava_time:dayChanged`
`{ season, day, year }`, `vava_time:weatherChanged` `{ weather, previous, forced, frozen, by }`,
`vava_time:clockChanged` `{ shift, frozen, by }` (`by` : `cycle`, `council` ou `web`).

Un module qui lit la saison passe par son `bridge/server.lua` (appel isolé, saison gardée 5 s) : `vava_time` absent ou
arrêté = aucun effet. Les réglages par saison vivent dans la config du module lecteur (`vava_farming` : `seasons`,
`vava_gathering` : `seasons.regen` et `seasons.yield`).

## Base de données (sql/0001_time.sql)

`vava_time_state` : une ligne (`id` = 1) — décalage, seconde figée (−1 : l'heure court), ciel, fin prévue, imposé,
figé, date d'écriture. Au démarrage, un ciel figé ou pas encore fini est repris sans transition ; un ciel inconnu de la
config est remplacé par un ciel de la saison.

## Hors jeu

`web/index.html` dans un navigateur montre l'outil (`?frozen=1` heure figée, `?forced=1` ciel imposé et figé,
`?refused=1` décisions refusées). La logique pure (heure de Paris, saisons, tirage du ciel) est testée dans
`tests/spec/time_*_spec.lua`.

## À vérifier en jeu

Procédure complète : `docs/tests/temps.md` (deux joueurs, Chancellerie, redémarrage, resmon). Points à regarder de
près : la transition du ciel chez un joueur qui arrive pendant qu'elle se fait ; la neige au sol et ses traces ; l'heure
figée (`PauseClock`) après une reconnexion ; la remise à l'état du jeu quand la ressource s'arrête.
