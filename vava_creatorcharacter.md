# 📘 Cahier des Charges — Module `vava_creator`
### Système complet de création de personnage + Shops de vêtements  
Compatible Framework **vAvA_core**  
Version : 1.0.0  
Auteur : vAvA

---

# 1. 🎯 Objectif du module

Le module **vava_creator** a pour objectif de fournir un système complet, intuitif et visuel de création de personnage, entièrement compatible avec le framework **vAvA_core**.

Le module doit être :

- 🧩 **Modulaire**
- 🎨 **Très visuel**
- 👶 **Débutant‑friendly**
- 🧬 **Ultra personnalisable**
- 🌍 **Multilingue**
- ⚡ **Performant**
- 🔐 **Sécurisé**

Il inclut également un **système complet de shops de vêtements**, permettant aux joueurs de modifier leur apparence après la création du personnage.

---

# 2. 🧩 Intégration avec vAvA_core

## 2.1. Dépendances internes
- Module **player**
- Module **database**
- Module **locales**
- Module **utils**
- Module **inventory** (optionnel pour les shops)
- Module **money** (pour les achats de vêtements)

## 2.2. Points d’entrée
- `vava_creator:open` (serveur)
- `vava_creator:startUI` (client)
- `vava_creator:saveCharacter` (callback serveur)
- `exports.vava_creator:OpenCreator(source)`

## 2.3. Compatibilité
- Multi‑personnages  
- Système de skins (freemode ou ped custom)  
- Système de shops de vêtements  
- Inventaire (si accessoires)  
- Économie (achats de vêtements)

---

# 3. 🖥️ Interface Utilisateur (UI)

## 3.1. Principes UX
- Interface moderne, fluide, minimaliste  
- Navigation par étapes (wizard)  
- Aperçu 3D en temps réel  
- Boutons larges et lisibles  
- Feedback visuel immédiat  
- Support manette (optionnel)

## 3.2. Étapes du créateur
1. Choix du sexe  
2. Morphologie générale  
3. Visage détaillé  
4. Cheveux & pilosité  
5. Peau & imperfections  
6. Vêtements de départ  
7. Identité du personnage  
8. Résumé & validation  

## 3.3. Navigation
- Suivant / Précédent  
- Réinitialiser  
- Aperçu aléatoire  
- Sauvegarder  

---

# 4. 🧬 Personnalisation du personnage

## 4.1. Morphologie
- Taille  
- Poids  
- Musculature  
- Silhouette  

## 4.2. Visage (détaillé)
- Forme du visage  
- Yeux (forme, couleur)  
- Nez (largeur, hauteur, profondeur)  
- Bouche  
- Mâchoire  
- Menton  
- Pommettes  
- Sourcils  

## 4.3. Cheveux & pilosité
- Coupe  
- Couleur primaire  
- Couleur secondaire  
- Barbe (style + couleur)  

## 4.4. Peau & détails
- Teint  
- Taches de rousseur  
- Cicatrices  
- Rides  
- Imperfections  
- Maquillage  

## 4.5. Vêtements de départ
- Haut  
- Bas  
- Chaussures  
- Accessoires  

## 4.6. Identité
- Prénom  
- Nom  
- Âge  
- Genre  
- Histoire courte  
- Nationalité  

---

# 5. 🛍️ Shops de vêtements (module intégré)

## 5.1. Objectif
Permettre aux joueurs de modifier leur tenue **après la création du personnage**, via des boutiques de vêtements immersives et configurables.

## 5.2. Fonctionnalités principales
- Boutiques configurables dans un fichier `config.lua`
- Aperçu 3D en temps réel dans le shop
- Navigation intuitive par catégories :
  - Hauts
  - Bas
  - Chaussures
  - Accessoires
  - Chapeaux
  - Lunettes
  - Masques
  - Gants
- Prix configurables par item
- Achat sécurisé via vAvA_core.money
- Sauvegarde automatique du skin après achat
- Possibilité d’essayer avant d’acheter
- Système de rotation caméra
- Support des sexes (male/female)
- Support des DLC clothes

## 5.3. Intégration avec vAvA_core
- Utilisation du module **money** pour les paiements  
- Utilisation du module **player** pour appliquer le skin  
- Utilisation du module **database** pour sauvegarder les vêtements  
- Utilisation du module **locales** pour les textes du shop  

## 5.4. Structure des shops
```lua
Config.Shops = {
  {
    name = "Binco",
    coords = vector3(75.3, -1392.9, 29.4),
    categories = {"tops", "pants", "shoes", "accessories"},
    multiplier = 1.0
  },
  {
    name = "Suburban",
    coords = vector3(125.6, -223.4, 54.5),
    categories = {"tops", "pants", "shoes", "accessories", "hats", "glasses"},
    multiplier = 1.3
  }
}

## 5.5. 🛍️ UI du shop

- Interface similaire au créateur  
- Catégories affichées à gauche  
- Aperçu 3D du personnage au centre  
- Prix affiché en bas de l’écran  

### Boutons disponibles
- **Acheter**  
- **Annuler**  
- **Essayer**  
- **Tourner la caméra**  

---

## 6. 🗄️ Base de données

### 6.1. Table `characters`

Champs :
- `id`
- `user_id`
- `firstname`
- `lastname`
- `age`
- `gender`
- `skin_data` (JSON)
- `clothes_data` (JSON)
- `story`
- `created_at`
- `updated_at`

### 6.2. Migrations
- Création automatique de la table  
- Mise à jour si ajout de nouvelles options  

---

## 7. 🔐 Sécurité

### 7.1. Vérifications serveur
- Validation des données morphologiques  
- Vérification des valeurs extrêmes  
- Anti‑cheat sur les vêtements non autorisés  
- Vérification du propriétaire du personnage  

### 7.2. Logs
- Création de personnage  
- Modification de skin  
- Achats de vêtements  
- Tentatives invalides  

---

## 8. 🌍 Multilingue

### 8.1. Structure
locales/
fr.lua
en.lua
es.lua


### 8.2. Clés essentielles
- UI du créateur  
- UI du shop  
- Messages d’erreur  
- Labels des sliders  
- Catégories de vêtements  

---

## 9. ⚙️ Performances

### 9.1. Client
- Aucun thread inutile  
- Préchargement des assets  
- Compression JSON  

### 9.2. Serveur
- DAL optimisé  
- Requêtes préparées  
- Sauvegarde asynchrone  

---

## 10. 🧪 Tests

### 10.1. Tests unitaires
- Validation des données  
- Sauvegarde SQL  
- Chargement du skin  

### 10.2. Tests UX
- Joueurs débutants  
- Joueurs expérimentés  

### 10.3. Tests de compatibilité
- Multi‑personnages  
- Inventaire  
- Jobs  
- Shops  

---

## 11. 📦 Livrables

### 11.1. Code source
- `client/main.lua`  
- `client/shop.lua`  
- `server/main.lua`  
- `server/shop.lua`  
- `ui/`  
- `locales/`  
- `config.lua`  
- `fxmanifest.lua`  

### 11.2. Documentation
- README  
- Guide d’intégration  
- Guide développeur  
- Guide utilisateur  

---

## 12. 🎨 Style visuel recommandé

- UI moderne  
- Couleurs sobres  
- Icônes vectorielles  
- Animations douces  
- Aperçu 3D fluide  

---

## 13. 🧱 Philosophie du module

- Intuitif  
- Complet  
- Modulaire  
- Sécurisé  
- Performant  
- Traduisible  
- Pensé pour durer  

