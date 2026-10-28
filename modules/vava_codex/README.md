# vava_codex — le Codex

Toutes les commandes et toutes les touches du serveur dans un livre ouvert : classées par chapitre (un par module),
cherchées, composées par un formulaire selon le type de chaque argument, lancées. Signets, dernières pages et réglage
« rester ouvert » par personnage. Onglet des touches, avec la touche réellement liée par le joueur.

Le Codex ne contient aucune commande : il lit le registre `core:commands` du core, que chaque module remplit depuis
sa config (`server/commands.lua`, voir `docs/api.md` → « Registre des commandes »). Le serveur décide de ce que chaque
joueur voit (public, droit du Conseil, console en lecture seule) ; la ligne est lancée chez le joueur comme s'il
l'avait tapée, et chaque commande garde ses contrôles.

## Prérequis

`vAvA_core` ≥ 0.7.0. Facultatifs : `vava_admin` (rangs et droits du Conseil ; sans lui, ACE `vava_codex.staff` et les
ACE déclarés avec les commandes), `vava_hud` (notifications), `vava_chat` (dernières pages des commandes tapées).

## Fichiers

| Fichier | Rôle |
| --- | --- |
| `config.lua` | touche (`F1`) et commande (`/codex`), bornes des signets et dernières pages, commandes non décrites, ACE, débits, textes |
| `bridge/server.lua` | seul point de contact avec le core et les modules : joueurs, Conseil, exports `codexList`, commandes du jeu |
| `server/catalog.lua` | entrées visibles d'un joueur, chapitres, non décrites, valeurs d'un argument |
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
4. Taper « vital » : la ligne « Fixer la vitalité d'une zone » est choisie d'office ; `Entrée` passe au premier champ ;
   la liste des zones vient du serveur (vraies zones) ; choisir, régler le curseur, `Entrée` : la commande part, le chat
   répond, la ligne monte dans « Dernières pages ».
5. `/metiers niveau` : la liste des joueurs en jeu porte les noms de personnage ; la liste des compétences vient du
   registre ; le niveau est borné 0–100 ; la ligne composée s'écrit en direct.
6. Signet depuis le détail : un ruban apparaît en haut du livre ; cliquer le ruban ouvre la commande ; au-delà de
   `favorites.max`, refus propre.
7. Réglage « Rester ouvert » décoché : « Lancer » ferme le Codex. Coché : il reste ouvert, sauf pour une commande qui
   ouvre une interface (`/conseil`, `/grimoire`, `/catalogue`…), qui le ferme d'abord.
8. Onglet Touches : toutes les touches par chapitre ; cliquer une touche montre son cabochon en grand.
9. Taper une commande dans le chat (`/me …`) : elle apparaît dans « Dernières pages » à la prochaine ouverture (greffe
   vava_chat).
10. Se déconnecter puis revenir : signets, dernières pages et réglage retrouvés (champ de personnage).
