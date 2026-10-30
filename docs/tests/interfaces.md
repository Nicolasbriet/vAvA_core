# Interfaces et fichiers web communs (`vava_ui`) — procédure de test en jeu

Procédure pour vérifier que les interfaces prennent leurs polices, textures et ornements dans la ressource commune
`vava_ui` (T-012) au lieu d'en livrer chacune une copie. Rien ne doit changer à l'écran : le seul gain est un premier
téléchargement plus léger. Le point que le dépôt n'a jamais vu en jeu est le **chargement d'une police depuis une autre
ressource** (`nui://vava_ui/…`, règle CORS du navigateur du jeu) : c'est le premier test.

T-012 se fait en deux temps. **Maintenant : le pilote** (§ 0), seul `vava_hud` 1.4.0 a basculé ; les autres interfaces
gardent leurs copies et ne doivent pas avoir bougé. **Ensuite** (§ 1 à 6), quand les quatorze autres auront basculé.
Les tests à deux joueurs sont marqués **(2 joueurs)**. Pour chaque écart : le test (« interfaces 0-3 »), ce que vous
avez vu, les lignes de la console du client (`F8`) et de l'onglet Console des outils de la page.

## 0. Pilote : `vava_hud` 1.4.0

Préparation : serveur de test à jour (Chancellerie 1.6.2, `vava_ui` 1.0.0, `vava_hud` 1.4.0). Pour comparer, gardez
sous la main les captures du rapport `docs/plan/rapports/T-012.md` (HUD avant / après, hors jeu) ou une capture
d'écran du HUD prise avant la mise à jour.

| # | Faire | Attendu |
|---|---|---|
| 1 | Chancellerie → Ressources. | `vava_ui` listée avec « Polices, textures et ornements communs des interfaces (aucun script) ». Une fois cochée et le `server.cfg` enregistré, sa ligne `ensure vava_ui` est juste après `ensure vAvA_core`. |
| 2 | Démarrer le serveur. | Console : `Started resource vava_ui` avant `vava_chat` et avant `vava_hud` ; `module 'vava_hud'…` sans erreur ; aucune ligne `Couldn't start resource` ni `dependency`. |
| 3 | `vava_ui` **décochée** (aucune ligne `ensure vava_ui`) : redémarrer le serveur. | `vava_ui` démarre quand même, juste avant `vava_hud` (dépendance déclarée) ; le HUD s'affiche normalement en jeu. Recocher ensuite `vava_ui`. |
| 4 | En jeu, console du client (`F8`) → `resmon 1`. | `vava_ui` absent de la liste ou à 0,00 ms (aucun script). `vava_hud` comme avant. |
| 5 | Personnage en jeu, rien d'ouvert : regarder les médaillons (santé, faim, soif, voix) en bas à gauche. | Cuir **grainé** (fin grain irrégulier, pas un dégradé lisse), lunette de laiton, anneaux comme avant. |
| 6 | Provoquer une notification (boire, ou `/besoins` sur le serveur de test) : carte en haut à droite. | Texte en **EB Garamond** : lettres fines et serrées, petites minuscules ; **pas** la police large et ronde de Georgia (à texte égal, Georgia prend nettement plus de largeur). Carte grainée, liseré coloré à gauche. Même allure que les notifications d'avant. |
| 7 | Lancer une action longue (couper un arbre, `vava_gathering`). | Barre au centre bas : libellé en **capitales Cinzel** (empattements fins, « VOUS ABATTEZ UN CHÊNE »), indice « Peut être interrompue » en **italique** EB Garamond distinct du droit. |
| 8 | `F8` → `nui_devtools` ; dans la fenêtre des outils, choisir le cadre de `vava_hud` (menu des contextes en haut de l'onglet Console, ou cadre `cfx-nui-vava_hud` dans Éléments). Onglet **Réseau**, cocher « Désactiver le cache », puis recharger la page du HUD (`Ctrl+R` dans les outils, ou `restart vava_hud` en console serveur). Relancer une notification et une action longue. | Requêtes **toutes servies** (statut 200, aucune ligne rouge) : `vava_ui.css`, `eb_garamond.woff2`, `grain.webp` ; `cinzel.woff2` et `eb_garamond_italic.woff2` dès que la barre de progression s'affiche (une police n'est demandée que quand un texte l'emploie). Leur adresse commence par `nui://vava_ui/web/` (ou `https://cfx-nui-vava_ui/web/`). **Aucune** requête vers `devmock.js` ni `/dev/`. |
| 9 | Même fenêtre, onglet **Console** du cadre `vava_hud`. | **Aucune** erreur contenant `CORS`, `Access-Control-Allow-Origin`, `blocked` ou `Failed to decode downloaded font`. |
| 10 | Onglet **Éléments** : sélectionner une notification (`.toast`), puis Calculé (Computed) → tout en bas « Polices rendues » (Rendered Fonts). | `EB Garamond` — « Network resource » (ou « ressource réseau »), **pas** `Georgia` ni `Palatino Linotype`. Même contrôle sur `.progress-label` pendant une action : `Cinzel`. |
| 11 | Ouvrir une autre interface, encore sur ses propres copies (inventaire `I`, Codex `F1`, chat `T`). | Inchangée : mêmes polices et textures qu'avant la mise à jour. |
| 12 | **(2 joueurs)** Second client : vider le cache de FiveM (dossier `FiveM.app/data/cache`), se connecter pendant que le premier est en jeu. | HUD juste dès la première connexion (tests 5 à 7). |
| 13 | Serveur de test seulement : `stop vava_ui` en console serveur. | FXServer arrête aussi `vava_hud` (il en dépend) : le HUD disparaît. Si `vava_hud` reste démarré, noter ce qui s'affiche (attendu : polices de repli, cuir sans grain, tout lisible). **Redémarrer le serveur** pour revenir à l'état normal (jamais sur un serveur ouvert). |

**Si le test 8, 9 ou 10 échoue** (polices refusées, erreur CORS) : noter le message exact et l'adresse de la requête.
Le HUD reste lisible (police de repli). La suite de T-012 attend : la correction essaiera d'abord l'adresse
`https://cfx-nui-vava_ui/…` (une chaîne à changer par page et dans `vava_ui.css`), puis, avec votre accord, une feuille
de polices intégrée (`data:`, environ 50 Ko de plus). Si **seules** les polices échouent et que `grain.webp` est servi,
le dire : c'est le cas attendu d'un refus CORS.

## 1. Démarrage (après la bascule des 15 interfaces)

| # | Faire | Attendu |
|---|---|---|
| 1 | Démarrer le serveur (Chancellerie, `server.cfg` régénéré). | Console : `Started resource vava_ui` juste après `vAvA_core`, avant `vava_chat` ; chaque module affiche `module 'xxx' vY prêt` ; aucune ligne `Couldn't start resource` ni `dependency`. |
| 2 | Serveur existant mis à jour, **sans** ligne `ensure vava_ui` : redémarrer. | `vava_ui` démarre quand même, avant `vava_chat` (dépendance) ; Chancellerie → Ressources : `vava_ui` listée avec sa description, placée après `vAvA_core` quand on la coche. |
| 3 | `resmon 1` au repos. | `vava_ui` n'apparaît pas (ou 0,00 ms) : aucun script. |

## 2. Rendu de chaque interface

Pour chacune : titres en Cinzel (capitales à empattements fins, pas les capitales de Georgia), texte en EB Garamond
(italique distinct du droit), grain sur le cuir, papier sur les parchemins qui en avaient, coins de laiton aux cadres ;
allure identique aux captures « après » du rapport.

| # | Faire | Attendu |
|---|---|---|
| 1 | Se connecter (écran de sélection et de création). | `vava_characters_ui` comme avant : losanges, blason, cadre. |
| 2 | En jeu : regarder le HUD ; lancer une action longue (récolte). | Médaillons au grain fin, barre de progression en Cinzel. |
| 3 | Ouvrir l'inventaire, le Codex (`F1`), le chat (`T`). | Cuir grainé, cadres de laiton, filets et losanges (inventaire, Codex), papier du chat. |
| 4 | Compétences, invite de récolte, menu d'une forge, menu d'un emplacement de champ. | Parchemins au papier, coins de laiton, rien de changé. |
| 5 | `/aterre` (outil de développement) puis aide. | Écran de la santé : filet et losange, grain. |
| 6 | Conseil : Registre (`F10`), outil « Ciel et heure », éditeur des zones de voix, mur des caméras. | Grands titres en Cinzel Decorative à la même graisse qu'avant (voix, caméras : pas plus fins). |
| 7 | Magie : roue, grimoire, registre des murmures. | Cinzel Decorative 400 et 700, papier, runes, cadre. |

## 3. Outils de développement de la NUI

| # | Faire | Attendu |
|---|---|---|
| 1 | `F8` → `nui_devtools`, cadre de `vava_hud`, onglet Réseau, puis recharger la page (ou `restart vava_hud`). | `vava_ui.css`, `eb_garamond.woff2`, `cinzel.woff2`, `grain.webp` : tous servis (200) ; **aucune** erreur CORS ni requête en rouge ; aucune requête vers `devmock.js` ni `/dev/`. |
| 2 | Même chose dans le cadre de `vava_crafting` (menu ouvert). | `paper.webp`, `frame.svg` servis ; Éléments → texte → « Rendered Fonts » : `EB Garamond`, pas `Georgia`. |

## 4. Première connexion **(2 joueurs)**

| # | Faire | Attendu |
|---|---|---|
| 1 | Second client : vider le cache de FiveM, se connecter pendant que le premier est en jeu. | Écran de sélection et toutes les interfaces justes dès la première connexion. Noter le volume téléchargé si le client l'affiche (repris à T-019). |

## 5. Arrêt de `vava_ui` (serveur de test seulement)

| # | Faire | Attendu |
|---|---|---|
| 1 | `stop vava_ui` en console. | FXServer arrête aussi les modules qui en dépendent (console). Redémarrer le serveur pour revenir à l'état normal. Si les modules restent démarrés, noter ce qui s'affiche (attendu : polices de repli, dégradés sans grain ni coins, tout reste lisible). |

## 6. Textures WebP

| # | Faire | Attendu |
|---|---|---|
| 1 | Registre (`F10`) en grand, panneaux de cuir les plus larges. | Grain régulier, **aucune ligne ni raccord** visible entre les tuiles. |
| 2 | Menu d'une forge, compétences : parchemin. | Papier identique à avant (comparer à une capture d'écran prise avant la mise à jour). |
