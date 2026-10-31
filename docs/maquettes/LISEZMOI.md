# Maquettes de l'Atelier du Conseil

Maquettes validées des éditeurs en jeu (version 1). Elles s'ouvrent dans un navigateur (`Main.html` d'abord ; les
flèches de retour mènent à l'accueil). Ce sont des **références visuelles et de vocabulaire**, pas du code à
reprendre tel quel : l'interface réelle est construite dans `vava_atelier` avec les polices de `vava_ui` (ici
chargées depuis Google Fonts pour l'aperçu seulement : jamais de ressource externe en jeu).

| Fichier | Écran | Tâche |
|---|---|---|
| `Main.html` | Accueil de l'Atelier | T-100 |
| `Recolte.html` | Créateur de récolte, placement en jeu | T-102 |
| `Confrerie.html` | Créateur de confréries (jobs), grille grades × droits | T-105 |
| `Combat.html` | Éditeur d'une technique de combat, frise des phases | T-121 |
| `Sort.html` | Sort offensif, menu « Ajouter un effet » ouvert | T-122, T-123 |
| `Protection.html` | Sort de protection, règle de cumul | T-123 |
| `Chargement.html` | Écran de chargement (hors Atelier) : ouverture, paysage peint par le code, feux de veille des étapes. Le panneau « Prototype » n'existe pas en jeu | T-020 |
| `menu-pause/HD_*.dc.html` | Menu pause « la bannière », version finale avec le thème du serveur : Personnage, Réglages, Le Conseil, Quitter | T-145 |
| `menu-pause/Codex.dc.html`, `Carte.dc.html`, `Confrerie.dc.html` | Menu pause : B1 Codex, B2 Carte, B6 bannière aux couleurs de la confrérie (ce que la version finale ne montre pas) ; les autres fichiers du dossier sont les étapes de travail | T-145 |

Les valeurs affichées pour la Boule de feu (8 dégâts, 20 m, 0,45 s, 4 s) viennent de la config réelle de
`vava_magic`.

Le dossier `menu-pause/` est copié du canevas « Menu pause d'Eldoria — propositions » (31 octobre 2026). Ses fichiers
`.dc.html` sont la source d'un canevas de conception : ils ne s'ouvrent pas seuls dans un navigateur (`support.js` et les
`/_blob/…` sont ceux du canevas). Les `/_blob/…` sont les polices et textures que `vava_ui` fournit déjà (Cinzel
Decorative, Cinzel, EB Garamond, `grain.webp`, `paper.webp`). `canvas.json` donne le titre et la place de chaque écran.
