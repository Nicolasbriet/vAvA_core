# T-102 — Rapport de l'interface (pages web)

Partie « pages » de T-102 (spec `docs/plan/specs/T-102.md`, § 9), faite dans `agents/T-102-nui`. Le Lua, les docs, la
procédure et le rapport principal sont faits à part (`agents/T-102`). Aucun fichier Lua, aucun `fxmanifest.lua` touché.

## Ce qui est fait

### `vava_atelier/web` (1.3.0)

- `js/placing.js` (nouveau) : fonctions pures du placement (forme reconnue, type enfant à lieu, lieu nettoyé selon sa
  forme, repère GPS, phrase du lieu, compte « 5 points, dont 1 nouveau », marques des lignes, corbeille, étapes,
  fantôme, phrase d'apparence, charge de `placeStart`) et les trois blocs du volet :
  - **Lieu** : « Pas encore placée. » / « Posée à 32 m de vous, rayon 120 m » (polygone : « , 6 sommets ») ; bouton
    « Placer la zone » / « Déplacer la zone » (« Déplacer le point », « Déplacer le panneau »), qui enregistre d'abord une
    fiche nouvelle ou modifiée, comme l'essai de T-101 ;
  - **Prochain point à poser** : champs `template` du type enfant ; un `select` à `source` devient un segmenté des deux
    derniers choix + « Autre… » (liste cherchable, une seule demande `options` à la première ouverture, choix gardés
    pour la séance) ; deux champs chiffrés côte à côte (maquette), aide en infobulle ; phrase « Apparence : chêne de GTA,
    modèle provisoire. Il sera remplacé… » tirée de `ghost.models` ; « Poser des points » (désactivé tant que la zone n'a
    pas de lieu) ; valeurs du modèle gardées d'une ouverture à l'autre ;
  - **Points de la zone** : compte, une ligne par enfant (titre ; « nouveau » vert, « retiré » rouge barré, « modifié »
    et « brouillon d'un autre membre » en ocre ; indice du serveur ; « Aller à » ; corbeille), ligne nouvelle sur
    `#dbe6cf`, clic sur le titre : fiche du point dans le volet, « retour » ramène à la zone.
  Les blocs se posent avant le premier groupe replié (`env.between` de `form.js`) : nom, Lieu, Prochain point, Points,
  Réglages de la zone, comme la maquette.
- `js/view-entry.js` : étapes cochées (✓ vert pour une étape faite, en cours en gras sur pastille sombre, à venir creuse).
- `js/app.js` : `children` à l'ouverture d'une fiche à lieu qui a un type enfant placé ou un parent ; visée demandée
  (`placeStart`) ; messages `placing`, `placed`, `placeRefused`, `undone`, `suspended` ; volet atténué (0,85, sans
  pointeur) pendant la visée ; mise en page « page » : cadre et voile cachés, bandeau et barre seuls ; essai joué :
  `suspend` après un essai réussi d'un atelier `trialPlay`, puis bandeau seul (sans bouton retour) ; `placeStop` si la
  fiche visée quitte l'écran ; touches de la page ignorées pendant la visée et l'essai joué ; retour d'une fiche enfant
  vers sa fiche parent (aussi après abandon ou retrait publié).
- `js/components.js` : icônes `pin` et `trash` ; bandeau sans bouton retour possible. `js/bridge.js` : `placeStop`,
  `templateChanged`, `goTo`, `suspend` hors de la file (locaux, ne lisent aucun module). `js/strings.js` : textes
  `place` (genre et nombre lus dans la déclaration du type). `css/style.css` : section « Placement (T-102) ».
- Tout texte venu du jeu passe par `textContent` (`h(…, { text })`) ; aucun `innerHTML`. Aucune ressource externe.
  Aucun message à chaque image, aucun minuteur rapide : un seul `setTimeout` (800 ms, une fois) pour relire le lieu après
  une annulation si `undone` ne le porte pas.

### `vava_gathering/web` (1.8.0)

Étiquette « Essai » devant le geste de l'invite quand `prompt.trial === true` (`index.html`, `js/view-prompt.js`,
`js/strings.js`, `css/style.css`) ; devmock : une invite d'essai dans la suite `?view=prompt`.

## Écarts au contrat NUI (§ 9.2)

Ajouts seulement ; tout le reste suit le § 9.2 tel quel.

1. **`placeStart` en mode `children`** : `kind` = le type **enfant** (`node`), `id = ''`, `rev = 0`, plus deux clés :
   `parent` (identifiant de la fiche ouverte, la zone) et `label` (libellé du choix `autoTitle` courant, « Chêne », pour
   que le jeu étiquette le candidat « Chêne 4 »). `parentRev` = révision de la zone. `title` = titre de la zone (« Hors
   de %s », « Forêt de Brume, rayon 120 m »). En mode `self` : `kind`, `id`, `rev` de la fiche, `ghost` tiré de son champ
   `ghost.field` (panneau : la valeur du champ `modele`). `rules` = `rules` du type visé, `{}` s'il n'en a pas. `ghost`
   = `{ model, label, provisional }`. Ces clés reprennent celles du RPC `place` (`KIND`, `ENTRY_OR_NEW`, `PARENT`).
2. **`templateChanged`** porte aussi `label` (même rôle). Il n'est envoyé que pendant une visée de points ; or le volet
   est sans pointeur et le focus au jeu pendant la visée : en pratique il ne part pas aujourd'hui (le modèle part avec
   `placeStart`).
3. **Distance du bloc Lieu** (« Posée à 32 m de vous ») : la page lit un nombre `distance` (mètres, calculé par le Lua
   depuis la position du personnage) dans la réponse de `read`, dans `children.self.distance` et dans `placed.distance`.
   Absent : « Posée, rayon 120 m ». Après une pose sans `distance`, la distance précédente est oubliée.
4. **`undone`** peut porter `place` (lieu rétabli de la fiche ouverte). Sans lui, la page relit une fois `children`
   800 ms après la dernière annulation.
5. **Bandeau pendant la visée** : la ligne « Mode édition : les cercles et étiquettes ne sont visibles que par vous » est
   un texte de la page (`STRINGS.place.editLine`) ; le Lua n'a pas à envoyer `mode` pour la visée. Le titre reste celui
   du bandeau reçu (`mode.banner.title`, aujourd'hui le libellé de l'atelier « Récolte » ; la maquette dit « Atelier de
   la récolte »).
6. **`suspended`** sans `line` : la page compose `texts.trialLine` de l'atelier + « · F9 : revenir à l'Atelier » (touche
   `closeKey` reçue à l'ouverture).
7. **`placed`** : si `parent` est absent alors qu'une visée de points est en cours sur la fiche ouverte, la ligne `row`
   est quand même ajoutée (cas d'un brouillon de zone déjà tenu, dont la révision ne change pas).
8. **Corbeille d'un point jamais publié** : la ligne n'a pas de révision ; la page relit la fiche du point (`read`) puis
   appelle `discard` avec sa `rev`. Point publié : `retire`. Ensuite `children`, puis `read` de la zone (pied et état)
   si elle n'est pas modifiée.

## Poids de la page de l'Atelier

Fichiers servis (`index.html`, `css/*.css`, `js/*.js`), fins de ligne LF, avant (8024daf) → après :

| | Avant | Après | Écart |
|---|---|---|---|
| Brut | 122 291 o | 153 691 o | **+31 400 o** |
| gzip -9 (fichier par fichier) | 38 567 o | 48 215 o | +9 648 o |

Détail brut : `placing.js` +17,1 Ko, `app.js` +9,2 Ko, `css` +2,3 Ko, `strings.js` +1,7 Ko, le reste +1 Ko. **La cible
de la spec (≤ 12 Ko de plus) n'est pas tenue** : la liste distante en segmenté, la corbeille par ligne, l'ouverture d'un
point et le retour, l'essai joué et les messages d'annulation pèsent plus que prévu. Pistes si le porteur du projet veut
revenir sous la cible : retirer le segmenté « deux derniers choix » (un sélecteur simple), retirer la relecture de la
zone après une corbeille. `vava_gathering/web` : +0,4 Ko.

## `files` à déclarer

Rien de nouveau : `web/js/placing.js` est couvert par `'web/js/*.js'` du manifeste de `vava_atelier` ; `web/dev/` reste
hors des `files` (devmock et essais jamais livrés). `vava_gathering` : aucun fichier nouveau.

## Vérification

- `./scripts/verifier.sh` : **OK** (avertissements d'audit antérieurs, aucun dans ces pages).
- `node modules/vava_atelier/web/dev/essais.js` : 241 essais (79 nouveaux) — fonctions pures de `placing.js`, textes de
  la maquette, et sur une page factice : `children` à l'ouverture, charge exacte de `placeStart` (points et zone),
  bandeau et barre de la visée, pose, refus, annulation, fin de visée, `placeStop` en quittant, corbeille (`read` puis
  `discard` à la révision lue, puis `children`), ouverture d'un point et retour à la zone, « Placer la zone » qui
  enregistre d'abord, `suspend` après l'essai, bandeau seul sans retour.
- Hors dépôt, sous jsdom (vraie page + devmock, 74 vérifications) : chaque écran du § 9.4, ordre des blocs, clics dans le
  volet (Aller à, Autre…, corbeille, ouverture du point), visée simulée jusqu'aux poses ; anciens écrans sans erreur.
  Note : sous jsdom récent, les scripts écrits par `document.write` arrivent après `DOMContentLoaded` ; le harnais le
  relance (les anciens harnais `test_*_web.js` du dossier d'outils échouent pour cette seule raison).
- Captures (Edge sans fenêtre) en 1440×900, 1280×720 et 2560×1440 : volet conforme à la maquette `Recolte` ; en
  1280×720, la liste est sous le pli, d'où la ligne posée ramenée en vue à chaque pose.

## Hors jeu

`web/index.html` dans un navigateur, avec : `?screen=entry&editor=recolte&step=2` (maquette), `&step=1` (zone nouvelle),
`&refused=1` ; `?screen=placing&shape=oriented|circle|polygon`, `&layout=page` (panneau), `?screen=placing&picked=1` ;
`?screen=suspended` (F9 pour revenir). Pendant une visée simulée : clic (un sur trois refusé en mode points), clic droit,
Entrée (tracé), Échap. `vava_gathering/web/index.html?view=prompt` : l'invite d'essai paraît à 10,5 s.

## À vérifier en jeu (interface)

- Volet atténué et sans pointeur pendant la visée ; la liste suit les poses ; la barre des touches est celle du mode.
- « Placer la zone » sur une zone nouvelle : enregistrée puis visée, sans double clic.
- Essai : la page se range, bandeau seul ; F9 la rend telle qu'elle était.
- Corbeille d'un point nouveau et d'un point publié ; « Aller à » pose le repère.
- Lisibilité en 1280×720 et 2560×1440.
