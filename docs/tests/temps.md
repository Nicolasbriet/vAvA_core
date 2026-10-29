# Ciel et heure du royaume — procédure de test en jeu

Procédure pour vérifier en jeu `vava_time` 1.0.0 (heure de Paris, saisons, météo, décisions du Conseil), ses effets sur
`vava_farming` 1.3.0 et `vava_gathering` 1.3.0, et la page Ciel et heure de la Chancellerie 1.5.0 (pont
`vava_chancellerie` 1.4.0). Comptez une heure et demie ; les tests à deux joueurs sont marqués **(2 joueurs)**. Chaque
test dit quoi faire et ce qui doit se passer ; si ce n'est pas le cas, notez le test (« temps 3-4 »), ce que vous avez
vu, et les lignes des consoles serveur et client.

## 0. Préparation

1. **Ordre de démarrage** (`server.cfg`, ou la Chancellerie qui le fait seule) : `vava_time` juste après `vava_world`,
   avant `vava_appearance` (voir `docs/tests/LISEZMOI.md`).
2. **Démarrage** : la console affiche `module 'vava_time' v1.0.0 prêt` ; la migration `0001_time` passe seule (table
   `vava_time_state`). Aucun avertissement attendu.
3. **Comptes** : vous en Sénéchal ou Souverain (droit `tools`) ; un second compte en Gardien pour les refus
   (`vava_conseil <compte> gardien`), un troisième sans rang pour les joueurs.
4. **Heure de référence** : gardez l'heure de Paris sous les yeux (téléphone, horloge du PC réglée sur Paris). Le
   serveur peut être réglé sur n'importe quel fuseau : l'heure du royaume doit rester celle de Paris.
5. **Réglages pour aller vite** (facultatif, `modules/vava_time/config.lua`, à remettre après, `restart vava_time`) :
   - ciel qui change souvent : `weather.durationMinutes = { 1, 2 }`, `weather.durations = {}`, `weather.fadeSeconds = 30` ;
   - saisons de quelques minutes : `calendar.mode = 'cycle'`, `calendar.cycle.seasonDays = 0.01` (≈ 14 min par saison),
     `calendar.cycle.origin` = la date du jour, `calendar.cycle.first = 'automne'`.

## 1. Heure du royaume

| # | Faire | Attendu |
|---|---|---|
| 1 | Se connecter, choisir un personnage, taper `/date`. | « Il est HH h MM, le Ne jour de la saison des …, an 1 du royaume. C'est … : … » ; l'heure est celle de Paris à la minute près ; le ciel et la lumière du jeu vont avec (nuit à 23 h, plein jour à 14 h). |
| 2 | Attendre deux minutes, `/date`. | L'heure a avancé de deux minutes (rythme réel, pas celui de GTA). |
| 3 | Rester une heure sans rien faire, ou comparer après une reconnexion. | L'heure reste celle de Paris (recalage chaque minute, aucune dérive). |
| 4 | Pendant la sélection du personnage (écran de choix), regarder le ciel. | L'heure et le ciel du royaume s'appliquent déjà. |
| 5 | Mesurer `resmon 1` au repos. | `vava_time` ≤ 0,02 ms. |

## 2. Ciel (cycle)

| # | Faire | Attendu |
|---|---|---|
| 1 | Avec les réglages rapides du § 0, attendre plusieurs changements. | Le ciel change toutes les 1 à 2 min, en fondu sur 30 s (jamais d'un coup) ; les enchaînements sont plausibles (pas d'orage juste après un ciel clair). `/date` dit ce que fait le ciel. |
| 2 | Hors de l'hiver (`/date` : semailles, moissons ou brumes), observer une vingtaine de ciels. | Jamais de neige. |
| 3 | En hiver (mode cycle, § 0), observer. | Neige légère, neige, parfois une tempête ; jamais de « neige au sol » tirée seule. |
| 4 | Laisser passer l'hiver pendant qu'il neige (mode cycle). | Dans les 15 s après le printemps, le ciel quitte la neige en fondu ; console : « le royaume entre dans la saison des semailles ». |

## 3. Le Conseil, en jeu

| # | Faire | Attendu |
|---|---|---|
| 1 | `F10` → Outils (compte Sénéchal). | Bouton « Ciel et heure » ; un clic ferme le Registre et ouvre un panneau sur la droite (le ciel reste visible). |
| 2 | Regarder le panneau. | Heure du royaume qui avance, heure réelle, décalage « aucun », « au rythme réel » ; jour, saison, an ; ciel courant, « au gré du cycle », prochain changement ; treize tampons, ceux hors saison marqués. Lisible en 1280 × 720 comme en 2560 × 1440. |
| 3 | Mettre l'heure à 22:00, « Régler ». | La nuit tombe aussitôt ; « L'heure du royaume est réglée. » ; décalage affiché ; Registre → Journal : « Heure du royaume réglée » (heure, décalage, figée : non). |
| 4 | « + 1 h », puis « − 1 h ». | 23:00 puis 22:00 ; une ligne au journal par clic. |
| 5 | « Figer l'heure », attendre deux minutes, `/date`. | L'heure ne bouge plus (la lune reste immobile) ; tampon « figée » ; `/date` ajoute « Le temps s'est arrêté sur le royaume. » |
| 6 | Heure figée : mettre l'heure à 06:00. | Elle passe à 06:00 et reste figée. |
| 7 | « Laisser le temps reprendre ». | L'heure repart de 06:00 au rythme réel. |
| 8 | « Rendre l'heure réelle ». | Retour à l'heure de Paris, sans décalage ni gel. |
| 9 | Choisir « Pluie », « Imposer ce ciel ». | La pluie arrive en une vingtaine de secondes ; « imposé par le Conseil » ; journal « Ciel imposé » (ciel, figé, de saison). Après la durée d'un ciel, le cycle reprend seul. |
| 10 | Choisir « Neige au sol », cocher « le figer », imposer. | Neige au sol, traces de pas ; « hors saison » si ce n'est pas l'hiver ; le ciel ne bouge plus, même au-delà de sa durée. |
| 11 | « Rendre au cycle ». | Le ciel repart vers un ciel de la saison (fondu de 30 à 90 s), plus de traces ; journal « Ciel rendu au cycle ». |
| 12 | « Figer le ciel » sur un ciel du cycle. | Il reste ; le bouton se grise ; « Rendre au cycle » le libère. |
| 13 | `/ciel heure 6 30`, `/ciel decaler 3`, `/ciel figer`, `/ciel reprendre`, `/ciel reelle`, `/ciel meteo orage figer`, `/ciel garder`, `/ciel cycle`, `/ciel`. | Chaque commande répond par une notification et agit comme le bouton ; `/ciel` seul ouvre le panneau ; `/ciel heure midi` → la ligne d'usage, rien n'est envoyé. |
| 14 | `F1` (Codex). | Chapitre « Ciel et heure » : `/date` pour tous, `/ciel` et ses sous-commandes pour le Conseil, formulaires (heures, ciel parmi la liste) qui lancent la commande. |
| 15 | Cliquer « + 1 h » une dizaine de fois aussi vite que possible. | Après six décisions coup sur coup : « Doucement : le ciel ne change pas si vite. » ; ensuite, une décision toutes les deux secondes. |
| 16 | `resmon 1`, panneau ouvert. | `vava_time` ≤ 0,15 ms ; retombe au repos à la fermeture (Échap ou ×). |

## 4. Droits refusés

| # | Faire | Attendu |
|---|---|---|
| 1 | Compte Gardien : `F10` → Outils. | Pas de bouton « Ciel et heure ». |
| 2 | Compte Gardien : `/ciel`, puis `/ciel meteo neige`. | « Ce pouvoir revient au Conseil. » ; rien ne change, pour personne. |
| 3 | Compte sans rang : `/ciel reelle`, puis `/date`. | Refus pour `/ciel` ; `/date` répond normalement. |
| 4 | `stop vava_admin`, puis votre compte Souverain : `/ciel`. | Refusé (sans le Registre, personne ne règle le ciel) ; `start vava_admin` → l'outil revient dans le Registre. |

## 5. À deux

| # | Faire | Attendu |
|---|---|---|
| 1 | **(2 joueurs)** Les deux tapent `/date` au même moment et regardent le ciel. | Même heure à la minute, même ciel, même jour et saison. |
| 2 | **(2 joueurs)** A impose la pluie pendant que B regarde le ciel. | Le ciel de B change en même temps, en fondu. |
| 3 | **(2 joueurs)** A règle 22:00 ; B est en sélection de personnage. | B voit déjà la nuit sur l'écran de sélection, puis en jeu. |
| 4 | **(2 joueurs)** Réglages rapides (§ 0) : A impose « Orage » (fondu de 20 s) et B se connecte à ce moment-là (ou se reconnecte dans les 20 s). | B arrive sous le ciel d'avant qui tourne à l'orage dans le temps qui reste ; à la fin, A et B ont le même ciel. |
| 5 | **(2 joueurs)** A fige l'heure ; B se déconnecte puis se reconnecte. | B retrouve l'heure figée (horloge immobile). |
| 6 | **(2 joueurs)** A ouvre l'outil ; un second membre du Conseil (ou la Chancellerie) impose un ciel. | L'outil de A se met à jour dans les deux secondes. |

## 6. Depuis la Chancellerie

| # | Faire | Attendu |
|---|---|---|
| 1 | Compte du panneau en Sénéchal : Royaume → « Ciel et heure ». | Heure du royaume qui avance, heure de Paris, décalage, cours ; jour, saison, an ; ciel, conduite, prochain changement, saison ; boutons d'action. |
| 2 | « Mettre l'heure… » 21:30. | Les joueurs voient l'heure changer aussitôt ; Journal du Conseil : « Heure du royaume réglée » au nom de « Chancellerie : <compte> ». |
| 3 | « Imposer un ciel… » Pluie, « Le figer ». | La pluie arrive chez les joueurs en ~20 s ; conduite « figé » ; l'outil en jeu, s'il est ouvert, suit. |
| 4 | « Rendre au cycle », « Rendre l'heure réelle ». | Retour au cycle et à l'heure réelle, chez tous ; deux lignes au journal. |
| 5 | Compte du panneau en Gardien. | La page s'affiche sans boutons, avec « Ce rang lit le ciel et l'heure… ». |
| 6 | Compte Gardien : console du navigateur (F12) → `GAME.call('timeClock', 'real', 0).then(console.log)`. | `{ ok: false, error: 'forbidden' }` : le pont refuse sans le droit, rien ne change en jeu. |
| 7 | Laisser la page ouverte jusqu'au changement de ciel prévu. | La page se relit seule quelques secondes après. |
| 8 | `stop vava_time`, puis « Relire ». | « Le ciel et l'heure du royaume (vava_time) ne sont pas lancés. » ; `start vava_time` → la page revient. |

## 7. Saisons et métiers

Avec le mode cycle (§ 0) pour passer d'une saison à l'autre, ou en attendant le vrai changement de saison.

| # | Faire | Attendu |
|---|---|---|
| 1 | En hiver, semer une carotte (30 min de pousse), arroser, noter l'avancement après dix minutes (`/agriculture parcelle <id>`) ; recommencer au printemps. | En hiver l'avancement est cinq fois plus faible qu'au printemps (× 0,25 contre × 1,25) ; l'humidité baisse deux fois moins vite qu'au printemps. |
| 2 | En été, arroser puis suivre l'humidité. | Elle baisse une fois et demie plus vite qu'au printemps : il faut arroser plus souvent. |
| 3 | En hiver, vider un nœud de sauge (Prairie Haute), attendre. | Ses charges reviennent quatre fois moins vite ; chaque récolte d'herbes rend moitié moins (au moins une) ; un filon de la Mine du Val, lui, revient comme d'habitude. |
| 4 | À l'automne, une piste de lièvre. | Charges qui reviennent plus vite, un peu plus de viande. |
| 5 | `stop vava_time`, puis récolter et cultiver. | Tout revient aux valeurs sans saison ; aucune erreur dans la console. |

## 8. Redémarrages et arrêt

| # | Faire | Attendu |
|---|---|---|
| 1 | Figer l'heure à 05:00, imposer et figer « Brouillard » ; `restart vava_time`. | Après le redémarrage : 05:00 figée, brouillard, sans fondu ; l'outil se rouvre sur le même état. |
| 2 | Même chose, puis redémarrer tout le serveur. | Même état retrouvé (table `vava_time_state`). |
| 3 | `stop vava_time`. | Chez chaque joueur, l'horloge rend la main au jeu (elle file à nouveau à la vitesse de GTA) et le ciel aussi ; plus de traces dans la neige ; aucune erreur. |
| 4 | `start vava_time`. | Heure et ciel du royaume reviennent dans les secondes qui suivent, sans reconnexion. |
| 5 | `restart vava_admin` pendant que l'outil est fermé, puis `F10` → Outils. | Le bouton « Ciel et heure » est de nouveau là. |
