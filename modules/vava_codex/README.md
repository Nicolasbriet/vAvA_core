# vava_codex — le Codex

Toutes les commandes et toutes les touches du serveur dans un livre ouvert : classées par chapitre (un par module),
cherchées, composées par un formulaire selon le type de chaque argument, lancées. Signets, dernières pages et réglage
« rester ouvert » par personnage. Onglet des touches, avec la touche réellement liée par le joueur.

Le Codex ne contient aucune commande : il lit le registre `core:commands` du core, que chaque module remplit depuis
sa config (`server/commands.lua`, voir `docs/api.md` → « Registre des commandes »). Le serveur décide de ce que chaque
joueur voit (public, droit du Conseil, console en lecture seule) ; la ligne est lancée chez le joueur comme s'il
l'avait tapée, et chaque commande garde ses contrôles.

## Ce qui passe sur le réseau (1.2.0)

La page garde le contenu (entrées, chapitres, commandes non décrites) et les préférences d'une ouverture à l'autre. À
chaque ouverture, le client envoie leurs deux versions ; le serveur recalcule ce que le joueur peut voir avec ses droits
du moment, en prend l'empreinte (`shared/fingerprint.lua`) et ne renvoie que ce qui a changé. Mesuré hors jeu avec les
déclarations de tous les modules du dépôt (taille msgpack estimée) :

| Ouverture | Joueur (35 entrées) | Souverain (52 entrées) |
| --- | --- | --- |
| Avant 1.2.0, à chaque `F1` | 7,5 Ko | 16,9 Ko |
| Première ouverture, ou contenu changé | 7,5 Ko | 17,0 Ko |
| Ouverture suivante sans changement | 56 o | 56 o |
| Préférences seules changées (24 signets, 12 pages au plus) | 1 Ko au plus | 1 Ko au plus |

Le contenu repart dès qu'il change, quelle qu'en soit la cause : module démarré ou arrêté, rang donné ou retiré, droit
d'un rang, ACE, commande non décrite apparue. Les préférences repartent après un signet, un réglage, une commande
lancée (du Codex ou du chat) ou un changement de personnage. Les touches du joueur sont relues dans le jeu à chaque
ouverture. Le champ `vava_codex:prefs` est lu du seul serveur (`private`) : il ne part plus vers le client à chaque
commande lancée. Coût serveur d'une ouverture : environ 1 ms pour un joueur, 2,5 ms pour un Souverain (calcul du
contenu et de son empreinte, mesuré hors jeu), borné par `rateLimits.open`.

## Prérequis

`vAvA_core` ≥ 0.7.0. Facultatifs : `vava_admin` (rangs et droits du Conseil ; sans lui, ACE `vava_codex.staff` et les
ACE déclarés avec les commandes), `vava_hud` (notifications), `vava_chat` (dernières pages des commandes tapées).

## Fichiers

| Fichier | Rôle |
| --- | --- |
| `config.lua` | touche (`F1`) et commande (`/codex`), bornes des signets et dernières pages, commandes non décrites, ACE, rayon des joueurs proposés hors du Conseil (`players.nearbyRadius`), débits, textes |
| `bridge/server.lua` | seul point de contact avec le core et les modules : joueurs (tous, ou les seuls proches), Conseil, exports `codexList`, commandes du jeu |
| `server/catalog.lua` | entrées visibles d'un joueur, chapitres, non décrites, valeurs d'un argument |
| `shared/prefs.lua` | logique pure : préférences ramenées aux maximums de la config (testée : `tests/spec/codex_prefs_spec.lua`) |
| `shared/fingerprint.lua` | logique pure : empreinte d'une valeur (version du contenu et des préférences), réponse à l'ouverture (testée : `tests/spec/codex_fingerprint_spec.lua`) |
| `server/prefs.lua` | champ de personnage : signets, dernières pages, réglage |
| `server/main.lua` | déclaration du module, RPC |
| `client/keys.lua` | touche réellement liée par le joueur (lue dans le jeu) |
| `client/main.lua` | ouverture, relais des gestes, lancement par `ExecuteCommand`, export `noteCommand` |
| `web/` | le livre : `index.html` s'ouvre dans un navigateur (`?staff=0` : vue d'un simple joueur) |

## Tests en jeu

1. `F1` : le livre s'ouvre, le curseur est dans la recherche. `Échap` le ferme. `/codex` fait de même. Changer la
   touche dans Paramètres › Raccourcis › FiveM : la nouvelle touche ouvre le Codex et l'onglet Touches la montre.
2. En simple joueur : seules les commandes publiques (chat, signalement, magie, Chancellerie…) et les touches ; aucun
   sceau « Conseil », aucune section « Non décrites ».
3. Au Conseil (`vava_conseil <compte> souverain`) : les commandes du Conseil apparaissent avec leur sceau, celles de la
   console grisées et non lançables, la section « Non décrites » en bas de « Tout ».
4. Taper « vital » : deux résultats, « État des zones » (sa description parle de vitalité) puis « Fixer la vitalité
   d'une zone » ; la première est choisie d'office, `↓` choisit la seconde (taper « fixer la vital » ne garde qu'elle).
   `Entrée` passe au premier champ ; la liste des zones vient du serveur (vraies zones) ; choisir. La vitalité est vide
   (« Il manque « vitalité ». », « Lancer » grisé) tant qu'elle n'est pas choisie : régler le curseur ou taper une
   valeur, `Entrée` : la commande part, le chat répond, la ligne monte dans « Dernières pages ».
5. `/metiers niveau` : la liste des joueurs en jeu porte les noms de personnage ; la liste des compétences vient du
   registre ; le niveau (« de 0 à 100 ») n'a aucune valeur d'office ; une valeur tapée hors bornes ou à virgule part
   ramenée dans les bornes et arrondie (150 → 100, 42,7 → 43) ; la ligne composée s'écrit en direct.
   En simple joueur, `/mp` : la liste ne propose que les joueurs à moins de 5 m (`players.nearbyRadius`), dans la même
   instance ; un joueur plus loin n'y est pas, mais son numéro tapé à la main reste accepté. Au Conseil : tous.
6. Signet depuis le détail : un ruban apparaît en haut du livre ; cliquer le ruban ouvre la commande ; au-delà de
   `favorites.max`, refus propre. Abaisser `favorites.max` ou `recent.max` sous ce qu'un personnage a déjà : à
   l'ouverture suivante ses listes sont tronquées (premiers signets, dernières pages les plus récentes) et « Lancer »
   fonctionne.
7. Réglage « Rester ouvert » décoché : « Lancer » ferme le Codex. Coché : il reste ouvert, sauf pour une commande qui
   ouvre une interface (`/conseil`, `/grimoire`, `/catalogue`…), qui le ferme d'abord.
8. Onglet Touches : toutes les touches par chapitre ; cliquer une touche montre son cabochon en grand.
9. Taper une commande dans le chat (`/me …`) : elle apparaît dans « Dernières pages » à la prochaine ouverture (greffe
   vava_chat). Taper deux fois `/mp <n°> …` : une seule ligne « Message privé » (seule une sous-commande déclarée,
   comme `/metiers niveau …`, est retenue ; rien du message n'est gardé).
10. Se déconnecter puis revenir : signets, dernières pages et réglage retrouvés (champ de personnage).
11. Livre ouvert : `restart vava_codex` : le livre disparaît, souris et clavier reviennent au jeu ; `F1` le rouvre.
12. Ouvrir, fermer, rouvrir sans rien changer : le livre est le même (signets, dernières pages, touches) et le serveur
    ne renvoie que deux versions (compteur réseau ou `netgraph`). Donner un rang (`vava_conseil <compte> senechal`), ou
    `restart` d'un module qui déclare des commandes : à l'ouverture suivante, le contenu change aussitôt.
