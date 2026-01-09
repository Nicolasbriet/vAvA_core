# 📁 Assets Folder

Ce dossier contient les ressources visuelles et audio du loading screen.

## Fichiers requis

### background.png
- **Description**: Image de fond du loading screen
- **Format**: PNG, JPG ou WEBP
- **Résolution recommandée**: 1920x1080 minimum, 4K pour une meilleure qualité
- **Conseil**: Utilisez une image sombre ou avec des zones neutres pour que le texte soit lisible

### logo.png
- **Description**: Logo de votre serveur
- **Format**: PNG avec transparence
- **Résolution recommandée**: 512x512 pixels
- **Conseil**: Utilisez un logo avec fond transparent

### music.mp3 (optionnel)
- **Description**: Musique d'ambiance pendant le chargement
- **Format**: MP3 ou OGG
- **Durée recommandée**: 2-5 minutes en boucle
- **Volume**: Réglez le volume dans config.lua (0.0 à 1.0)

## Exemple de structure

```
assets/
├── background.png    # Votre image de fond
├── logo.png          # Votre logo
├── music.mp3         # Votre musique (optionnel)
└── README.md         # Ce fichier
```

## Conseils

1. **Optimisez vos images** pour réduire le temps de chargement
2. **Utilisez des couleurs sombres** pour le fond pour une meilleure lisibilité
3. **Testez sur différentes résolutions** (1080p, 1440p, 4K, ultrawide)
4. **Compressez la musique** sans trop perdre en qualité (128-192 kbps)
