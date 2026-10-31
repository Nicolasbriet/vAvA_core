# T-145 — Menu pause `vava_pause` : partie interface (NUI)

Compte rendu de `vava-dev-nui`, 31 octobre 2026, branche `agents/T-145-nui`. Le Lua, les docs, la procédure en jeu et le
rapport principal sont ceux du développeur Lua (autre worktree). Aucun fichier Lua ni `fxmanifest.lua` n'a été touché.

## Ce qui est fait

| Module | Fichiers | Contenu |
|---|---|---|
| `vava_pause` | `web/index.html`, `web/css/pause.css`, `web/js/{strings,bridge,model,views,nav,app}.js`, `web/img/charges.svg` | la bannière (tringle, tissu à la teinte royale ou de la confrérie, surpiqûres, blason, queue fourchue), rubriques Personnage, Codex (attente / fermé), Carte, Réglages (Interface, Voix, Touches), Le Conseil, dialogue Quitter, plaque ; bannière réduite à terre ; déroulé 250 ms, panneau 200 ms décalé de 80 ms, repli 180 ms ; clavier et manette |
| `vava_pause` | `web/dev/devmock.js`, `web/dev/essais.js` (jamais livrés) | données simulées, un paramètre par rubrique et par état ; 26 essais lancés par `verifier.sh` |
| `vava_codex` | `web/js/dock.js` (nouveau), `web/js/app.js`, `web/index.html`, `web/css/style.css`, `web/dev/devmock.js`, `web/dev/essais.js` | mode panneau : `open.dock` relu (mêmes règles que `shared/dock.lua`), classe `is-docked`, livre placé par `--dock-*`, sans voile, tranche dans le rectangle, légende masquée ; `?dock=1` ; 2 essais |
| `vava_hud` | `web/js/hud.js`, `web/css/style.css`, `web/dev/devmock.js` | message `settings { scale, durationMs }` (et `init.settings`) ; jauges, notifications et progression grandies par `transform` depuis leur coin ; `?scale=` et `?notify=` |
| dépôt | `scripts/verifier.sh` | `modules/vava_pause/web/dev/essais.js` ajouté à `ESSAIS_PAGES` |

Commits : `7d43b93`, `d5b2e2d`, `c5bf1f5`, `2afa9c1`, `b3705aa` (`vava_pause 1.0.0 : page …`), `5325d39` (`vava_codex 1.6.0`),
`b1e8f93` (`vava_hud 1.5.0`).

Règles tenues : tout texte venu du jeu par `textContent` (aucun `innerHTML`, `outerHTML`, `insertAdjacentHTML` : un essai le
vérifie ; le devmock injecte un libellé de touche hostile qui reste du texte) ; couleurs de confrérie et encres revérifiées
`^#[0-9a-f]{6}$` avant `style.setProperty` ; meuble du blason pris dans une liste fermée (`croix`) ; aucun filtre, flou,
`color-mix`, `:has` (essai) ; animations sur `opacity` et `transform` seulement ; polices, grain, cadre, filet, losange de
`nui://vava_ui/…` avec repli ; aucune adresse externe (essai) ; aucune boucle : une minuterie unique au repli et pour effacer un
avis.

## Contrat NUI tel qu'appliqué par la page

Messages : `SendNUIMessage({ action = …, payload = … })`, comme `vava_codex` et `vava_hud`. Page → Lua : `fetch` vers la
ressource, corps JSON, réponse attendue `{ ok, … }`.

**Lua → page**

| `action` | `payload` lu par la page |
|---|---|
| `open` | `rubric` (`personnage`, `carte`, `reglages`, `conseil` ; toute autre valeur → `personnage`), `downed` (booléen), `local = { name, health (0–1), hunger, thirst (0–100), plaque = { time, season } (déjà mis en forme), voice = { label, distance } }`, `data` (§ 6.1 ; absent ou `null` : « se consulte… » ; `false` : « ne répond pas »), `settings = { defs, values }` (`defs` = les lignes de `config.settings.list` déjà filtrées par `uses`, `values` = valeurs effectives), `keyLabels = { [nom] = touche liée }`, `resources = { codex, sheet, voice, council }` (booléens ; `false` masque ou désactive), `closeKey` (≤ 16 caractères, « Échap » par défaut), `gamepad` (booléen) |
| `data` | l'instantané (`skills`, `guild`, `people`, `council`, `request`, `keys`) ; `false` ou `{ unavailable = true }` : échec |
| `refused` | `{ reason }` : la page se replie (180 ms) |
| `close` | `{}` : la page se replie (idempotent) |
| `nav` | `{ dir }` ∈ `up`, `down`, `left`, `right`, `accept`, `back`, `prevTab`, `nextTab`, `resume` |
| `codexClosed` | `{ rubric }` : retour à cette rubrique (sinon la précédente) ; pris en compte seulement si le Codex est ouvert ou s'ouvre |
| `native` | `{ hidden }` : page masquée (`visibility`) pendant un menu natif, puis focus sur la rubrique active |

**Page → Lua** (rappels)

| Rappel | Corps | Réponse attendue |
|---|---|---|
| `ready` | `{}` | — (envoyé au chargement de la page) |
| `close` | `{}` | `{ ok }` ; la page s'est déjà repliée : le Lua rend le focus |
| `rubric` | `{ id }`, `id` ∈ `personnage`, `codex`, `carte`, `reglages`, `conseil` | `{ ok }` ; envoyé à chaque changement de panneau (aussi aux flèches) et avant `codex` ; jamais pour `quitter` (dialogue) |
| `codex` | `{}` | `{ ok = true }` quand `openDocked` a réussi (la page masque alors son panneau et son voile) ; sinon `{ ok = false, error }` → « Le Codex est fermé pour l'instant. » |
| `map`, `gameSettings`, `keyBindings`, `sheet` | `{}` | `{ ok }` ; `false` → avis « Action impossible pour l'instant. » ; pour `sheet`, le Lua ferme la bannière (`close`) |
| `setting` | `{ key, value }` (valeur prise dans `choices`, ou booléen pour un levier) | `{ ok, value }` (valeur retenue) ; refus → valeur d'avant remise, « Ce réglage n'a pas été pris en compte. » |
| `resetSettings` | `{}` | `{ ok, values }` (toutes les valeurs effectives) |
| `council` | `{ kind, text, withPosition }` (`text` ≤ 500 octets, ≥ 10 caractères, vérifié par la page avant l'envoi ; `withPosition` forcé à `true` pour `player`) | `{ ok, request = { id, kind, state, age } }` ou `{ ok = false, error, wait }` |
| `leave` | `{ mode }` ∈ `disconnect`, `quit` | `{ ok }` ; `false` → boutons rendus, avis |

## Écarts au contrat NUI

Ajouts, tous facultatifs (la page a un défaut si le champ manque) ; aucun champ du § 9.10 n'est retiré ni renommé.

1. **À terre** (décision 2 du porteur du projet, absente du § 9.10) : `open.downed` (booléen), `data.downed` (booléen, le
   serveur tranche), et un message **`downed { downed }`** si l'état change bannière ouverte (sinon le Lua la replie, comme
   prévu par la veille). À terre, la page ne montre que Reprendre, Paramètres du jeu et Quitter Eldoria (les autres entrées
   absentes), aucun panneau, la ligne « Vous êtes à terre : seuls ces choix vous restent. », la plaque.
2. **`open.royal`** (`{ cloth, clothDark, field, charge }` de `config.royal`) et **`open.rankInks`** (`config.rankInks`) :
   la page a les mêmes valeurs par défaut (`model.js`), le Lua n'a besoin de les envoyer que si la config change.
3. **`open.rollMs`** (`config.open.rollMs`, borné 0–1000 ; 0 = sans animation) : le § 4.1 dit « la page le lit » sans le
   placer dans un message.
4. **`data = false`** (ou `{ unavailable = true }`) pour « Le registre ne répond pas. » ; `data` absent = « se consulte… ».
5. **Habitants** : `data.people` (nombre, mis en forme par la page) ou `data.plaque.people` (texte déjà formé) ; les deux
   sont lus.
6. **Touches** : si `data.keys` manque (version inchangée), la page garde la liste de l'ouverture précédente ; le Lua
   peut aussi renvoyer sa liste gardée à chaque ouverture (plus sûr après un `restart` de la page).
7. **Portée de la voix** : la touche « changer de portée » est la première entrée de `keys` dont `module == 'vava_voice'`
   (aujourd'hui `vava_voice_portee`), touche liée par `keyLabels` d'abord.
8. **`vava_hud`** : message `settings { scale, durationMs }` où `scale` est déjà le multiplicateur (`config.scales[115]` =
   1.15, borné 0,5–2 par la page) et `durationMs` la durée finale (`notifications.durationMs × notifyDurations[…]`, bornée
   500–60 000 ms) ; aussi accepté dans `init.settings`. Une valeur hors bornes est ignorée.
9. **`vava_codex`** : `open.dock = { left, top, width, height }` (vw, vh) ; invalide → plein écran comme avant. Rien d'autre.

## Écarts aux maquettes

- Commandes en EB Garamond gras bas-de-casse (« ouvrir la fiche complète », « Sceller et envoyer », tampons, leviers) au lieu
  des capitales Cinzel des maquettes (décision du porteur du projet, § 9.1). Rubriques, titres, intitulés et signets restent
  en Cinzel.
- Feuillet clair : `--ui-page-surface` + éclairage radial, sans `paper.webp` ; encres de `vava_ui` (#241b12, #56442f,
  #7a6750) au lieu de celles des maquettes. Losange de la rubrique active en SVG teinté par `currentColor` (pas de
  `filter`).
- Réglages : seulement les trois réglages branchés (taille, durée des notifications, cercle de portée) ; « Bulles de
  discussion », « Jauges toujours visibles », « Effets visuels allégés » absents (§ 2, hors périmètre).
- Carte : panneau réduit du § 9.5 (texte et « ouvrir la carte (provisoire) »), sans carte dessinée ni filtres.
- Personnage : ligne « Grade » seulement avec une confrérie, « Rang » seulement avec un métier ; « Métier : Aucun encore »
  sous Apprenti ; « revenir aux principaux » pour replier la liste dépliée.
- Le Conseil : compteur en octets (« 312 / 500 », la borne du serveur) ; un accent compte pour deux.
- Quitter : panneau masqué derrière le dialogue, seule « Quitter Eldoria » marquée active, comme `HD_Quitter`.
- Taille de l'interface : `html { font-size }` plafonné à 1,92vh pour que la bannière (820 px de maquette sur 900) tienne
  toujours en hauteur. À 115 %, la page grandit d'environ 8 % sur un écran 16:9 ou 16:10 (la hauteur limite), de 15 % sur
  un écran plus haut ; 90 % s'applique entier. À 115 %, la pointe de la rubrique active peut toucher le bord gauche du
  Codex en panneau (rectangle fixe en vw de `config.codex.rect`).

## Poids de la page

Fichiers livrés : **94 278 octets** (index 3,4 Ko, CSS 24,6 Ko, JS 65,8 Ko, SVG 0,6 Ko), sous le plafond de 100 Ko vérifié
par `web/dev/essais.js`, au-dessus de l'estimation de 90 Ko du § 9.12. Polices et grain : `vava_ui` (déjà en cache). Une copie
de travail en fins de ligne CRLF ajoute environ 1,5 Ko.

## `files` pour les manifestes

`modules/vava_pause/fxmanifest.lua` (exactement le § 3.1, `web/dev/` jamais cité) :

```lua
files { 'web/index.html', 'web/css/*.css', 'web/js/*.js', 'web/img/*.svg' }
ui_page 'web/index.html'
dependency 'vava_ui'
```

Ce que couvrent ces motifs : `web/index.html`, `web/css/pause.css`, `web/js/strings.js`, `web/js/bridge.js`,
`web/js/model.js`, `web/js/views.js`, `web/js/nav.js`, `web/js/app.js`, `web/img/charges.svg`.

`vava_codex` : `web/js/*.js` couvre déjà `web/js/dock.js` ; seule la version change (1.6.0). `vava_hud` : `files` inchangé
(1.5.0).

## Ce que le Lua doit faire pour la page

- `client/nui.lua` : `send(action, payload)` au format `{ action, payload }` ; rappels isolés (une erreur → `{ ok = false,
  error = 'client_error' }`), comme `vava_codex/client/nui.lua`.
- `codex` : rendre le focus (`SetNuiFocus(false, false)`), `openDocked(nil, cfg.codex.rect)`, répondre `{ ok }`. Au crochet
  `vava_codex:closed` hors `run` : `SetNuiFocus(true, true)` puis `codexClosed { rubric }`. Le même crochet arrivé pendant
  l'appel (échec) n'est pas gênant : la page attend la réponse de `codex`.
- `map`, `gameSettings`, `keyBindings` : `native { hidden = true }` à l'ouverture du menu natif, `native { hidden = false }`
  au retour (la page reprend le focus sur sa rubrique).
- Bornes à revérifier côté Lua (la page les respecte déjà) : `rubric.id` énuméré (5 valeurs), `setting.key` connue et
  `value` permise, `council.kind` énuméré, `text` ≤ 500 octets, `withPosition` booléen, `leave.mode` énuméré.

## Essais

- `node modules/vava_pause/web/dev/essais.js` : 26 essais (entrées et bannière réduite à terre, rubrique de départ,
  couleurs et confrérie, sous-titre et tableau des savoir-faire, nombres en lettres, encart et refus du Conseil, octets
  UTF-8 et coupe, plaque, réglages, touches, textes des commandes, aucun HTML écrit, aucun filtre ni adresse externe, poids).
- `node modules/vava_codex/web/dev/essais.js` : 52 essais (2 nouveaux : rectangle valide, rectangles refusés).
- `./scripts/verifier.sh` : **OK** (lint, 1 997 tests busted, essais de pages, audit, essai de l'audit).
- Hors dépôt : la vraie page sous jsdom avec son devmock (rubriques, signets, à terre, refus, données lentes ou absentes,
  envoi au Conseil : trop court, envoyé, `too_soon` ; position forcée pour un signalement ; Codex ouvert puis refermé ;
  Codex absent ; Quitter et Échap ; manette : croix, A, B, LB / RB ; menu natif ; dépliage des savoir-faire ; sans
  animation), mode panneau du Codex et réglages du HUD ; captures Edge sans fenêtre en 1440 × 900 et 1280 × 720 à 115 %,
  comparées aux maquettes `HD_*` et `Confrerie`.

Devmock : `modules/vava_pause/web/index.html?rubric=personnage|codex|carte|reglages|conseil|quitter`, `&tab=interface|voix|touches`,
`&guild=1`, `&request=sent|claimed|closed`, `&loading=1`, `&nodata=1`, `&slow=1`, `&refused=combat`, `&downed=1`,
`&gamepad=1`, `&scale=90|115`, `&novice=1`, `&council=0`, `&voice=0`, `&codex=0`, `&motion=0` ; pavé numérique = manette.
`modules/vava_codex/web/index.html?dock=1` ; `modules/vava_hud/web/index.html?scale=115&notify=longue`.

## À vérifier en jeu (page)

1. `img/charges.svg#croix` (vue SVG par fragment dans un `<img>`) dans le navigateur du jeu.
2. Deux pages superposées (bannière et Codex en panneau) : clics et focus vont bien au Codex quand il a le focus.
3. Anneau de focus visible à la manette (la page bascule en mode clavier à chaque message `nav`).
4. Lisibilité en 1280 × 720 et 2560 × 1440, à 90, 100 et 115 %.
