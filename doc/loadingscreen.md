# 📘 Cahier des Charges — Module `vava_loadingscreen`
### Écran de chargement immersif avec image de fond  
Compatible Framework **vAvA_core**  
Version : 1.0.0  
Auteur : vAvA

---

# 1. 🎯 Objectif du module

Le module **vava_loadingscreen** a pour but d’offrir un écran de chargement :

- Immersif  
- Moderne  
- Léger et performant  
- Entièrement personnalisable  
- Multilingue  
- Compatible avec tous les modules du framework **vAvA_core**

Il doit afficher une **image de fond**, des **informations dynamiques**, et une **interface fluide** pendant que le joueur se connecte au serveur.

---

# 2. 🧩 Intégration avec vAvA_core

## 2.1. Dépendances internes
- Module **locales**  
- Module **config**  
- Module **utils** (pour les animations, timers, etc.)

## 2.2. Points d’entrée
- Chargement automatique via `loadscreen` dans `fxmanifest.lua`
- Option d’ouverture manuelle via :
  - `exports.vava_loadingscreen:Show()`
  - `exports.vava_loadingscreen:Hide()`

## 2.3. Compatibilité
- Fonctionne avec tous les scripts du serveur  
- Aucun conflit avec les modules UI existants  
- Support des résolutions 16:9, 21:9, 32:9, 4:3  

---

# 3. 🎨 Design & Interface Utilisateur

## 3.1. Image de fond
- Image personnalisable via `config.lua`
- Support PNG / JPG / WEBP
- Option pour :
  - flou  
  - opacité  
  - filtre de couleur  
  - animation (zoom lent, parallax)

## 3.2. Éléments affichés
- Logo du serveur (optionnel)
- Nom du serveur
- Slogan / phrase d’ambiance
- Barre de chargement animée
- Informations dynamiques :
  - version du serveur  
  - nombre de joueurs connectés  
  - modules en cours de chargement  
  - messages aléatoires (tips RP, règles, infos)

## 3.3. Style visuel
- Minimaliste  
- Moderne  
- Animations douces (fade, slide, opacity)  
- Typographie lisible  
- Couleurs configurables  

---

# 4. ⚙️ Fonctionnalités

## 4.1. Barre de chargement
- Animation fluide  
- Progression réelle ou simulée  
- Couleur personnalisable  
- Style personnalisable (ligne, bloc, cercle)

## 4.2. Messages dynamiques
- Liste configurable dans `locales/`  
- Affichage aléatoire ou séquentiel  
- Timer configurable  
- Support multilingue

## 4.3. Musique (optionnelle)
- Fichier audio personnalisable  
- Volume réglable  
- Lecture automatique ou manuelle  
- Bouton mute/unmute

## 4.4. Effets visuels
- Flou dynamique  
- Parallax sur l’image de fond  
- Particules (neige, pluie, poussière) optionnelles  
- Animation du logo

---

# 5. 🗄️ Configuration

## 5.1. Fichier `config.lua`
Contient :
- Chemin de l’image de fond  
- Chemin du logo  
- Liste des messages  
- Activation/désactivation de la musique  
- Volume par défaut  
- Style de la barre de chargement  
- Couleurs principales  
- Activation des effets visuels  

## 5.2. Locales

locales/
fr.lua
en.lua
es.lua


---

# 6. 🧪 Tests

## 6.1. Tests UX
- Vérification de la lisibilité  
- Vérification du confort visuel  
- Tests sur écrans 1080p, 1440p, 4K  
- Tests sur écrans ultrawide  

## 6.2. Tests techniques
- Temps de chargement  
- Compatibilité avec les autres ressources  
- Vérification du comportement en cas de lag  
- Test du mute/unmute  

---

# 7. 📦 Livrables

## 7.1. Code source
- `ui/index.html`  
- `ui/style.css`  
- `ui/app.js`  
- `locales/`  
- `config.lua`  
- `fxmanifest.lua`  

## 7.2. Documentation
- README  
- Guide d’installation  
- Guide de personnalisation  
- Guide développeur  

---

# 8. 🧱 Philosophie du module

- Immersif  
- Léger  
- Personnalisable  
- Multilingue  
- Compatible  
- Pensé pour durer  

