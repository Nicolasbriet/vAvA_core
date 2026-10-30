# vava_ui — polices, textures et ornements communs des interfaces

Une seule copie des fichiers que toutes les interfaces du royaume emploient : les polices (Cinzel, EB Garamond droit et
italique, Cinzel Decorative 400 et 700), le grain du cuir, le papier des parchemins et les ornements de laiton (coins,
filet, losange). Chaque page les prend ici par `nui://vava_ui/…` au lieu d'en livrer sa propre copie : un joueur ne les
télécharge qu'une fois. La ressource n'a **aucun script** (rien au resmon, aucun réseau) et rien à régler.

Ordre de démarrage : juste après `vAvA_core`, avant `vava_chat` (première ressource à page). Aucune dépendance.

**Ne jamais arrêter ni relancer `vava_ui` sur un serveur ouvert.** Les ressources à page qui l'emploient déclarent
`dependency 'vava_ui'` : FXServer démarre `vava_ui` d'office avant elles (même sans ligne `ensure vava_ui` dans le
`server.cfg`), mais `stop` ou `restart vava_ui` les arrêterait aussi. N'ayant pas de code, `vava_ui` n'a jamais de raison
d'être relancé à chaud : une nouvelle version s'applique au redémarrage du serveur (ce que fait la Chancellerie).

## Contenu (livré aux joueurs)

| Fichier | Poids | Rôle |
|---|---|---|
| `web/css/vava_ui.css` | 3 574 o | `@font-face` des cinq polices et jetons `--ui-*` sur `:root` ; aucune règle d'élément ni de classe |
| `web/fonts/cinzel.woff2` | 25 904 o | Cinzel 400 à 700 (titres, capitales) |
| `web/fonts/eb_garamond.woff2` | 44 336 o | EB Garamond 400 à 700 (texte, commandes) |
| `web/fonts/eb_garamond_italic.woff2` | 47 940 o | EB Garamond italique 400 à 700 |
| `web/fonts/cinzel_decorative_400.woff2` | 14 416 o | Cinzel Decorative 400 (grands titres) |
| `web/fonts/cinzel_decorative_700.woff2` | 15 488 o | Cinzel Decorative 700 |
| `web/img/grain.webp` | 26 776 o | grain du cuir, WebP sans perte (PNG d'origine : 38 251 o) |
| `web/img/paper.webp` | 43 682 o | papier des parchemins, WebP sans perte (PNG d'origine : 57 122 o) |
| `web/img/frame.svg`, `divider.svg`, `diamond.svg` | 1 628 o | coins de laiton, filet, losange |

Une police déclarée n'est téléchargée par une page que si elle y sert : déclarer Cinzel Decorative partout ne coûte
rien aux pages qui ne l'emploient pas.

Restent dans le dépôt sans être livrés : les licences `web/fonts/OFL_*.txt` (SIL Open Font License 1.1 : Cinzel et
Cinzel Decorative de Natanael Gama, EB Garamond de Georg Duffner et Octavio Pardo) et `web/dev/` (outils hors jeu).

## S'en servir dans une page

```html
<head>
  …
  <link rel="stylesheet" href="nui://vava_ui/web/css/vava_ui.css">   <!-- AVANT la feuille du module -->
  <link rel="stylesheet" href="css/style.css">
</head>
<body>
  …
  <!-- hors jeu seulement : vava_ui pris dans le dépôt, puis les données simulées (jamais livrées) -->
  <script>typeof GetParentResourceName === 'function' || document.write('<script src="../../vava_ui/web/dev/horsjeu.js"><\/script><script src="dev/devmock.js"><\/script>');</script>
  <script src="js/bridge.js"></script>
```

- `fxmanifest.lua` du module : `dependency 'vava_ui'` (après `vAvA_core`) ; plus de `web/fonts/` ni de textures communes
  dans `files` ; `web/dev/` jamais cité.
- Familles : `"Cinzel"`, `"EB Garamond"` (droit et italique, 400 à 700), `"Cinzel Decorative"` (400, 700). Les piles
  des modules finissent par `"Palatino Linotype", Georgia, serif` : sans `vava_ui`, la page reste lisible.
- Images : toujours par un jeton **avec repli**, `var(--ui-grain, none)` (sans le `, none`, toute la déclaration
  `background` deviendrait invalide si `vava_ui` manquait, et le panneau perdrait aussi ses dégradés).

| Jeton | Valeur | Rôle |
|---|---|---|
| `--ui-grain` | `url("nui://vava_ui/web/img/grain.webp")` | grain du cuir (**fonds sombres seulement**) |
| `--ui-paper` | `url("nui://vava_ui/web/img/paper.webp")` | papier des parchemins qui l'emploient déjà |
| `--ui-frame` | `url("nui://vava_ui/web/img/frame.svg")` | coins de laiton (`border-image: var(--ui-frame, none) 18 / 1.3rem`) |
| `--ui-divider` | `url("nui://vava_ui/web/img/divider.svg")` | filet de séparation |
| `--ui-diamond` | `url("nui://vava_ui/web/img/diamond.svg")` | losange de laiton |
| `--ui-font-display` | `"Cinzel", "Palatino Linotype", Georgia, serif` | titres (capitales) |
| `--ui-font-body` | `"EB Garamond", "Palatino Linotype", Georgia, serif` | texte et commandes |
| `--ui-font-decorative` | `"Cinzel Decorative", "Cinzel", Georgia, serif` | grands titres du Conseil et de la magie |
| `--ui-ink`, `--ui-ink-muted`, `--ui-ink-faint` | `#241b12`, `#56442f`, `#7a6750` | encres des fonds clairs |
| `--ui-rule` | `rgba(70, 48, 24, 0.3)` | filets des fonds clairs |
| `--ui-page`, `--ui-page-deep` | `#ece1c8`, `#dccdab` | parchemin uni |
| `--ui-page-surface` | dégradé `#f3ead6` → `--ui-page` → `--ui-page-deep` | fond clair : éclairé en haut, sans grain |
| `--ui-field`, `--ui-field-rule` | `#f6eedb`, `#b39463` | champ crème à filet de laiton |
| `--ui-edge` | `#070504` | arête sombre des cadres |
| `--ui-brass`, `--ui-brass-bright` | `#b39463`, `#dcc08a` | laiton |
| `--ui-text`, `--ui-text-muted`, `--ui-text-faint` | `#ece1c8`, `#a69881`, `#786c5c` | texte sur cuir |

Les modules existants gardent leurs propres jetons de couleur (`--ink`, `--paper`, `--brass-rgb`…) : ils ne prennent ici
que les polices et les images. Les jetons de couleur `--ui-*` servent aux interfaces nouvelles (écran de chargement,
Atelier) et aux modules qu'on retouchera. Le préfixe `--ui-` est réservé à `vava_ui`.

## Règles d'évolution

- Un fichier entre dans `vava_ui` dès que **deux ressources** l'emploient ; une image d'un seul module reste dans le
  module (objets, icônes de jauge, blason…). Pas d'icône commune en 1.0.0 : `web/icons/` sera créé quand il en faudra.
- Semver : une version **mineure ajoute** (fichier, jeton) ; **retirer ou renommer** un fichier ou un jeton est une
  version **majeure**, faite dans le même chantier que la mise à jour de toutes les pages qui l'emploient.
- `vava_ui.css` ne contient que `@font-face` et `:root` ; les jetons d'image et la table de `web/dev/horsjeu.js` restent
  identiques.
- Images en SVG ou WebP ; un WebP n'est retenu que s'il gagne plus de 20 % sur le PNG, sinon le PNG reste.
- **Retouches rares et groupées** : toute modification d'un fichier livré fait retélécharger la ressource à tous les
  joueurs à leur connexion suivante. On réunit les ajouts dans une même version plutôt que d'en publier une par
  fichier ; jamais de retouche « pour voir ».
- `files` : exactement `web/css/vava_ui.css`, `web/fonts/*.woff2`, `web/img/*.webp`, `web/img/*.svg` ; jamais de `**`
  ni de joker dans un nom de dossier (un motif plus large livrerait `web/dev/`) ; ni `ui_page`, ni `loadscreen`, ni script. `tests/spec/ui_shared_spec.lua` le vérifie.

## Hors jeu

- `web/dev/horsjeu.js` : chargé par la ligne hors jeu des pages ; remplace `nui://vava_ui/` (inconnu d'un navigateur)
  par le chemin de `vava_ui` dans le dépôt, pour la feuille et les jetons d'image. Ne fait rien en jeu.
- `web/dev/apercu.html` : planche de contrôle (les cinq polices, cuir, papier, parchemin uni, champ, cadre, filet,
  losange, et les textures PNG et WebP côte à côte). Dans Edge ou Chrome, les polices lues en `file://` demandent
  l'option `--allow-file-access-from-files`.

## À vérifier en jeu

Procédure : `docs/tests/interfaces.md`. Par ordre d'importance :
1. les **polices** d'une page chargées depuis `nui://vava_ui/` sans erreur CORS (`nui_devtools`, onglet Réseau) : le
   seul point que le dépôt n'a jamais vu en jeu ;
2. `vava_ui` démarré seul comme dépendance quand le `server.cfg` n'a pas sa ligne ;
3. le WebP lu par le navigateur du jeu, sans raccord entre les tuiles ;
4. aucune différence d'allure des interfaces basculées ;
5. ce que fait FXServer à `stop vava_ui` (serveur de test seulement).

Si les polices sont refusées entre ressources, échelle de repli (une chaîne à changer par page, tâche de correction) :
`https://cfx-nui-vava_ui/…` au lieu de `nui://vava_ui/…`, puis, avec l'accord du porteur du projet, une feuille de
polices en `data:`.
