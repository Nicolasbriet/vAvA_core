# vava_hud — l'affichage en jeu

Retire l'interface native de GTA (minimap et ses barres de vie, argent, noms de rue, munitions, notifications) et la
remplace par l'affichage du royaume : des médaillons de cuir à anneau de laiton (santé, faim, soif, voix…), des
notifications en cartes de cuir et une barre de progression des actions longues (récolte, artisanat, leçon…). Les
autres modules s'en servent par exports ; le HUD ne décide de rien et n'envoie rien au serveur. Ressource cliente
uniquement : aucun RPC, aucune table, aucun évènement réseau.

Ordre de démarrage : après `vAvA_core` (≥ 0.3.0) et `vava_ui` (≥ 1.0.0, polices et grain de la page). Les deux sont
déclarés en dépendance : FXServer démarre `vava_ui` d'office s'il ne l'est pas encore. Ne jamais arrêter `vava_ui` sur
un serveur ouvert (il arrêterait aussi le HUD).

## Règles (config_client.lua)

Ressource cliente uniquement : tous ses réglages sont lus par le client, dans `config_client.lua` (nommé `config.lua`
avant 1.5.0, T-132 : `config.lua` est réservé aux réglages du seul serveur, jamais téléchargés). **Mise à jour vers
1.5.0** : un `config.lua` modifié est gardé par l'installeur de la Chancellerie, qui le signale (« reportez vos
réglages dans config_client.lua »), mais il n'est plus au manifeste et n'est plus lu : reportez vos réglages dans
`config_client.lua`, puis supprimez l'ancien fichier.

| Règle | Défaut | Clé |
|---|---|---|
| Position des jauges | coin inférieur gauche, `1.5vw` / `3vh` | `position` |
| Interface native retirée | minimap et HUD de GTA ; le menu pause et le chat restent ; réappliqué si le jeu les réaffiche | `native` |
| Notifications | 4,5 s à l'écran, 4 à la fois, 200 caractères au plus, natures `info`, `warning`, `danger` | `notifications` |
| Barre de progression | une seule à la fois, de 250 ms à 120 s, libellé de 60 caractères au plus, indice « Peut être interrompue » | `progress` |
| Menu pause, fondus | vérifiés toutes les 250 ms : jauges et barre masquées pendant ce temps | `pollMs` |
| Bannière du royaume (1.6.0) | jauges et barre masquées pendant la bannière de `vava_pause` (jamais interrompues), notifications visibles | `pauseResource` |
| Taille de l'interface (1.6.0) | réglage `ui.scale` de la bannière : 90 → 0,9, 100 → 1, 115 → 1,15 | `scales` |
| Durée des notifications (1.6.0) | réglage `hud.notifyDuration` : courte × 0,6, normale × 1, longue × 1,6 | `notifyDurations` |
| Bornes d'une jauge | 12 jauges, identifiant de 64 caractères, libellé de 32, icône de 200, ordre de 0 à 1 000 | `maxGauges`… |

## Pour les autres modules

Exports client (`defineGauge`, `setGauge`, `setGaugeActive`, `removeGauge`, `notify`, `progress`, `cancelProgress`,
`currentProgress`), hooks `vava_hud:progressDone` et `vava_hud:progressCancelled` : `docs/api.md`, section `vava_hud`.
L'icône d'une jauge est une image `nui://<ressource>/<chemin>` citée dans les `files` de son module.

## Bannière du royaume (1.6.0)

`client/pause.lua` suit la bannière de `vava_pause` sans en dépendre : crochet client `vava_pause:state` (`{ open }`,
remis à « repliée » à l'arrêt de `vava_pause`) ; réglages `ui.scale` et `hud.notifyDuration` lus par l'export client
`setting` de `vava_pause` (isolé) au démarrage et quand `vava_pause` démarre, puis suivis par le crochet
`vava_pause:settingChanged`. La page reçoit les valeurs effectives : `init` porte `settings = { scale, durationMs }`, puis
un message `settings` (`{ scale, durationMs }`) à chaque changement seulement. Sans `vava_pause` : `{ scale = 1,
durationMs = notifications.durationMs }`, comportement d'avant.

## Interface

`web/index.html`, `web/css/style.css`, `web/js/hud.js` : sans framework, textes reçus insérés par `textContent`. La
page lie `nui://vava_ui/web/css/vava_ui.css` avant sa feuille : polices Cinzel et EB Garamond, grain du cuir
(`var(--ui-grain, none)`). Sans `vava_ui`, elle reste lisible (polices de repli, cuir sans grain). Aucune animation par
image : l'anneau ne change qu'à une mise à jour, la barre avance par une seule transition CSS.

Hors jeu : ouvrir `web/index.html` dans un navigateur depuis le dépôt (Edge ou Chrome : option
`--allow-file-access-from-files` pour les polices en `file://`). La ligne hors jeu de la page charge
`modules/vava_ui/web/dev/horsjeu.js` puis les données simulées de `web/dev/devmock.js` (jamais livrés : `web/dev/`
n'est pas dans `files`). Paramètres : `?values=0.8,0.62,0.08,0.5` (santé, faim, soif, voix), `&talking=1` (lueur du
médaillon de la voix), `&progress=1` (barre de 8 s menée à son terme) ou `&progress=cancel` (interrompue à 60 %).

## À vérifier en jeu

- Bannière (1.6.0) : HUD masqué dès qu'elle se déroule, rendu à sa fermeture et après `restart vava_pause` bannière
  ouverte ; 115 % agrandit les médaillons aussitôt ; « Longue » laisse un message ≈ 7 s (`docs/tests/pause.md` § 6).

- `docs/tests/interfaces.md` § Pilote : polices et grain servis par `nui://vava_ui/…` sans erreur CORS, allure
  identique à avant, aucune requête vers `dev/`.
- Jauges, notifications et barre de progression : procédures des modules qui s'en servent (`besoins.md`, `sante.md`,
  `voix.md`, `metiers.md`).
