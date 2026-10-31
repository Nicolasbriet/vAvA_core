# Archives de l'Atelier

Dossier des fichiers JSON écrits et lus par `/atelier_archives exporter` et `/atelier_archives importer` (Souverain ou
console du serveur). L'Atelier ne lit et n'écrit **que** dans ce dossier, et seulement des noms au motif
`^[A-Za-z0-9_-]+\.json$` (64 octets au plus, ni barre ni `..`). Il n'est **jamais** dans les `files` du manifeste :
rien de ce qui est ici n'est servi aux joueurs.

- Un export ne contient que les versions **publiées** (ni brouillons, ni historique), au format décrit dans
  `docs/api.md` → `vava_atelier` → « Archives ».
- Un fichier lu pèse au plus `archives.maxBytes` (4 Mo). Chaque fiche est revue comme une saisie (forme, lieu, monde,
  module) ; une seule fiche refusée et rien n'est écrit pour son atelier.
- Pour passer du serveur de test au serveur de jeu : exporter ici, copier le fichier dans le même dossier de l'autre
  serveur, puis `/atelier_archives importer <fichier>` et `/atelier_archives confirmer`.

Les fichiers de ce dossier ne sont pas suivis par le dépôt (un export de test se supprime à la main).
