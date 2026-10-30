# vava_time — l'heure, les saisons et le ciel du royaume

Tous les joueurs vivent la même heure, la même saison et le même ciel. L'**heure du royaume** suit l'horloge de Paris
(heure d'été comprise), au rythme réel ; les **saisons** vont plus vite : chacune dure quatorze jours réels (une année
du royaume dure huit semaines) et donne le jour de la saison et l'an du royaume ; le **ciel** suit son cours selon la
saison, avec des transitions douces et sans neige hors de l'hiver, et certaines **nuits d'hiver gèlent**. Le
**Conseil** décale ou fige l'heure, impose ou fige un ciel, puis rend la main, depuis l'outil « Ciel et heure » du
Registre (`F10`), la commande `/ciel` ou la Chancellerie. Les saisons et le gel pèsent sur l'agriculture
(`vava_farming`) et la récolte (`vava_gathering`), qui les lisent par l'export `getSeason` et les hooks du gel.

Ordre de démarrage : après `vAvA_core` (≥ 0.7.0 : registre des commandes), de préférence juste après `vava_world`.
Facultatifs : `vava_admin` (droits, outil du Registre, journal ; sans lui, personne ne règle le ciel et l'heure),
`vava_hud` (notifications), `vava_chancellerie` ≥ 1.4.0 (page Ciel et heure du panneau web).

## Règles (config.lua)

| Règle | Défaut | Clé |
|---|---|---|
| Heure du royaume | heure de Paris calculée depuis l'heure UTC du serveur (la machine peut être à n'importe quelle heure) ; heure d'été du dernier dimanche de mars au dernier dimanche d'octobre, à 01:00 UTC ; une minute du jeu = une minute réelle | `clock.msPerGameMinute` |
| Décalage du Conseil | ± 12 h ; la date et la saison suivent l'heure réelle, pas le décalage | `clock.maxShiftMinutes` |
| Calendrier | cycle : chaque saison dure 14 jours réels, à partir de minuit (heure de Paris) du lundi 26 octobre 2026, printemps de l'an 1 ; l'an change à chaque nouveau printemps (une année : huit semaines). Avant cette date : premier jour du cycle | `calendar.mode`, `calendar.cycle` |
| Vrai calendrier (au choix) | `calendar.mode = 'real'` : printemps 20 mars, été 21 juin, automne 22 septembre, hiver 21 décembre (heure de Paris) ; l'an 1 commence au printemps de `firstYear` | `calendar.starts`, `calendar.firstYear` |
| Saisons | printemps « saison des semailles », été « saison des moissons », automne « saison des brumes », hiver « saison des frimas » ; chaque début de saison est annoncé aux joueurs en jeu | `calendar.seasons`, `messages.seasonStart` |
| Ère et dates | « an 1 du royaume », « 4e jour de la saison des semailles (printemps), an 1 du royaume » : écrits une seule fois, dans la config | `messages.year`, `messages.dateText` |
| Moments du jour | nuit, aube (6 h), matin (8 h), midi, après-midi (14 h), soir (18 h), nuit (22 h) | `calendar.moments` |
| Ciels | treize ciels (clair, grand soleil, nuages épars, couvert, éclaircies, pluie, orage, brume, brouillard, neige légère, neige, tempête de neige, neige au sol) ; les noms de météo de GTA ne paraissent que dans la config | `weather.types` |
| Cours du ciel | chaque ciel dure 25 à 50 min (orage, tempête : 10 à 20), puis un successeur plausible est tiré selon les poids de la saison (pas d'orage sous un ciel clair) ; transition de 90 s | `weather.next`, `weather.seasons`, `weather.durationMinutes`, `weather.durations`, `weather.fadeSeconds` |
| Neige | en hiver seulement (neige légère, neige, tempête rare) ; « neige au sol » (traces de pas et de roues) jamais tirée, imposable par le Conseil ; `snow = false` : aucune neige tirée | `weather.snow`, `weather.seasons.hiver` |
| Changement de saison | un ciel qui n'est plus de saison (neige au printemps) change dans les 15 s, sauf s'il est imposé ou figé | `server.tickMs` |
| Nuits de gel | l'hiver, chaque nuit gèle avec 40 % de chances (tirées une fois par jour) ; avertissement à 17 h, gel à 21 h (heure du royaume) ; ce qui est déjà passé au démarrage du module ne se rejoue pas | `frost` |
| Ciel imposé | transition de 20 s ; il tient le temps d'un ciel puis reprend son cours (même hors saison), sauf s'il est figé | `council.fadeSeconds` |
| Débit du Conseil | 6 décisions coup sur coup, puis une toutes les deux secondes, en jeu et depuis la Chancellerie confondus (chaque décision part à tous les joueurs) | `council.rate` |
| Droit du Conseil | `tools` (Sénéchal et au-dessus), comme les zones de voix ; Chancellerie : lecture au droit `view`, décisions au droit `tools` | `council.permission` |

## Joueurs

- **`/date`** : « Il est 15 h 20, le 4e jour de la saison des semailles (printemps), an 1 du royaume. C'est
  l'après-midi : il pleut. » (plus « Les astres restent immobiles dans le ciel. » si l'heure est figée). Calculé chez le
  joueur, sans réseau, et montré à lui seul.
- **Nouvelle saison** : « La saison des frimas commence : la terre dort, les herbes se font rares, les nuits gèlent. »
  (une phrase par saison), chez chaque joueur en jeu, lue sur l'état partagé : aucun envoi de plus.
- L'heure et le ciel s'appliquent dès l'arrivée, sélection du personnage comprise. Un joueur qui arrive pendant une
  transition part du ciel d'avant et rejoint le nouveau dans le temps qui reste.

## Conseil

**Outil « Ciel et heure »** (Registre `F10` → Outils, ou `/ciel`) : panneau sur le côté, le ciel reste visible.
- Heure du royaume (qui avance), heure réelle, décalage ; « Mettre l'heure à » heures : minutes, « − 1 h », « + 1 h »,
  « Figer l'heure » / « Laisser le temps reprendre » (l'heure repart de là où elle était figée), « Rendre l'heure
  réelle » (sans décalage ni gel).
- Calendrier : jour, saison, an, durée d'une saison ; nuit de gel annoncée ou tombée.
- Ciel : courant, imposé ou figé, hors saison, prochain changement ; tampons des treize ciels (« hors saison » en
  mention) ; « le figer » ; « Imposer ce ciel », « Figer le ciel », « Rendre à son cours » (le ciel suivant est tiré
  tout de suite).

**`/ciel`** et ses sous-commandes (déclarées au Codex, noms dans `commands.actions`) : `heure <h> [min]`,
`decaler <heures>`, `figer`, `reprendre`, `reelle`, `imposer <ciel> [figer]`, `garder`, `rendre`.

Chaque décision est revérifiée par le serveur (droit, valeur bornée, ciel connu, débit commun), publiée à tous les
joueurs, écrite en base (`vava_time_state`, une ligne) et inscrite au journal du Registre si elle change quelque chose :
« Heure du royaume réglée / décalée / figée / reprise », « Heure réelle rendue », « Ciel imposé / figé / rendu à son
cours », avec l'heure, le décalage, le ciel et s'il est figé. Depuis la Chancellerie, au nom de « Chancellerie :
<compte> ».

## Réseau et performance

- **GlobalState** (usage légitime : petit, rare, utile à tous) : `vava_time:clock` `{ shift, frozen }` (~35 o, à chaque
  décision sur l'heure), `vava_time:weather` `{ id, from, at, fade, forced, frozen }` (~70 o, à chaque ciel : toutes les
  25 à 50 min), `vava_time:calendar` `{ season, day, year }` (~45 o, une fois par jour). Retirés à l'arrêt du module.
  Au pire, un Conseil qui clique sans arrêt (jeu et web confondus) : une écriture toutes les deux secondes.
- **RPC** : `vava_time:sync` (heure UTC du serveur, à l'arrivée puis toutes les 30 min ; si le module serveur n'est pas
  prêt, quatre relances puis plus rien jusqu'à ce qu'il publie l'heure), `open`, `clock`, `weather` (Conseil). Aucun
  évènement serveur → client : le gel passe par des hooks serveur, l'agriculture prévient elle-même ses cultivateurs.
- **Client** : aucune boucle par image. Le jeu fait avancer l'horloge seul ; recalage local toutes les 60 s (aucun
  réseau) ; un thread attend la fin d'une transition pour poser le ciel. À l'arrêt de la ressource, l'heure et la
  météo sont rendues au jeu.
- Le serveur relit la date, la fin du ciel et la nuit de gel toutes les 15 s (calcul en mémoire).

## Pour les autres modules

| Export serveur | Retour |
|---|---|
| `getSeason()` | `printemps`, `ete`, `automne`, `hiver`, ou `nil` avant le démarrage |
| `getCalendar()` | `{ season, label, name, day, year, yearText, text, length }` (`yearText`, `text` : écrits par la config ; `length` : jours d'une saison) |
| `getClock()` | `{ hour, minute, seconds, frozen, shift }` |
| `getFrost()` | `{ tonight, warned, struck, warnHour, hour }` : la nuit du jour |
| `getWeather()` | `{ id, label, forced, frozen }` |

Exports client : `getClock()` (`{ hour, minute, frozen }`), `getSeason()`, `getWeather()` (identifiant).

Hooks serveur (`after`) : `vava_time:seasonChanged` `{ season, previous, day, year }`, `vava_time:dayChanged`
`{ season, day, year }`, `vava_time:weatherChanged` `{ weather, previous, forced, frozen, by }`,
`vava_time:clockChanged` `{ shift, frozen, by }` (`by` : `cycle`, `council` ou `web`), `vava_time:frostWarning` (au soir
d'une nuit de gel) et `vava_time:frost` (le gel tombe) `{ season, day, year, warnHour, hour }`.

Un module qui lit la saison passe par son `bridge/server.lua` (appel isolé, saison gardée 5 s ; abonnement aux hooks
du gel) : `vava_time` absent ou arrêté = aucun effet. Les réglages par saison vivent dans la config du module lecteur
(`vava_farming` : `seasons` et `frost` ; `vava_gathering` : `seasons.regen` et `seasons.yield`).

## Base de données (sql/0001_time.sql)

`vava_time_state` : une ligne (`id` = 1) — décalage, seconde figée (−1 : l'heure court), ciel, fin prévue, imposé,
figé, date d'écriture. Au démarrage, un ciel figé ou pas encore fini est repris sans transition ; un ciel inconnu de la
config est remplacé par un ciel de la saison. La nuit de gel n'est pas gardée : elle est tirée de nouveau au
démarrage, sans rejouer ce qui est déjà passé dans la journée.

## Hors jeu

`web/index.html` dans un navigateur montre l'outil (`?frozen=1` heure figée, `?forced=1` ciel imposé et figé,
`?struck=1` gel tombé, `?refused=1` décisions refusées). La logique pure (heure de Paris, saisons, tirage du ciel, nuits
de gel) est testée dans `tests/spec/time_*_spec.lua`.

## À vérifier en jeu

Procédure complète : `docs/tests/temps.md` (deux joueurs, Chancellerie, gel, redémarrage, resmon). Points à regarder de
près : la transition du ciel chez un joueur qui arrive pendant qu'elle se fait ; la neige au sol et ses traces ; l'heure
figée (`PauseClock`) après une reconnexion ; la remise à l'état du jeu quand la ressource s'arrête.
