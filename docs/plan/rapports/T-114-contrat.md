# T-114 — Contrat entre le Lua de `vava_hud` et sa page (remontée d'une jauge)

Fixé par `vava-dev-lua` d'après la spec `docs/plan/specs/T-114.md` § 9.2 et § 9.3, pour ce que la spec ne fixe pas. Tous
les messages partent par `client/nui.lua` (`SendNUIMessage({ action = nom, payload = charge })`), jamais avant que la
page se dise prête, jamais à chaque image : **un message par changement** de la jauge. Aucun ne passe sur le réseau.

## La remontée : `refill`

```
refill = { perSecond, delayMs }
```

| Champ | Forme |
|---|---|
| `perSecond` | nombre fini, `0 < perSecond ≤ 10` : part de la jauge (0 à 1) regagnée par seconde, **linéaire** |
| `delayMs` | entier, `0 ≤ delayMs ≤ 60 000` : ms à attendre, **comptées à la réception du message**, avant que la remontée commence |

- Le Lua n'envoie **jamais** `refill` avec une valeur de 1 (rien à remonter) : une jauge pleine arrive sans `refill`.
- La remontée va jusqu'à 1 et s'arrête là ; la page n'attend aucun message de fin (le Lua n'en envoie pas).
- Les bornes sont celles de `config_client.lua` (`refill.maxPerSecond`, `refill.maxDelayMs`), appliquées par le Lua :
  la page peut les relire par prudence, une remontée hors bornes est alors traitée comme absente.

## `value` (existant) : une clé de plus

```
{ id, value, refill? }
```

- `value` : valeur de **départ** (0 à 1), à peindre aussitôt (baisse comprise : transition habituelle de 600 ms).
- `refill` présent : après `max(delayMs, 600)` ms, une **seule** transition linéaire jusqu'à 1, de durée
  `(1 − value) / perSecond` s (spec § 9.3), classe `is-refilling` pendant la remontée, paliers franchis par minuteries.
- `refill` absent : comportement de 1.7.0 ; **toute remontée en cours s'arrête** (transition et minuteries annulées),
  la jauge est peinte à `value`.
- Un nouveau `value` (avec ou sans `refill`) annule la remontée en cours et ses minuteries.

## `define` et `init.gauges[]` (existants) : `value` projetée, `refill` restant

Chaque jauge décrite par `define` et par la liste `gauges` d'`init` porte les mêmes champs qu'en 1.7.0
(`id, label, icon, order, low, critical, value, active`) et, si une remontée est en cours, `refill` :

- `value` : valeur **projetée** au moment de l'envoi (valeur de départ + part déjà remontée) ;
- `refill` : `{ perSecond, delayMs }` avec `delayMs` = attente **restante** (0 si la remontée a déjà commencé) ; absent
  si la jauge est pleine à ce moment ou sans remontée.

La page traite une jauge ainsi décrite **comme** un `value` avec la même remontée, aussitôt après sa déclaration (cas
d'une page rechargée, d'une jauge redéclarée par un module qui revient, de `vava_hud` redémarré : le médaillon reprend à
la bonne valeur et continue de monter).

## Ce que le Lua garantit

- Même valeur de départ et même remontée (même `perSecond`, même instant de départ à 1 ms près) qu'au dernier envoi :
  **aucun** message.
- `refill` invalide (clé inconnue, `perSecond` ≤ 0, > 10 ou non fini, `delayMs` négatif, > 60 000 ou non entier) : refus
  `false, 'invalid_refill'` à l'appelant, **aucun** message.
- `setGauge(id, valeur)` sans troisième argument (faim, soif, santé, voix) : inchangé depuis 1.7.0.
