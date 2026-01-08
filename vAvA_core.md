# vAvA_core
Framework FiveM modulaire, sécurisé et multilingue  
Version : 1.0.0  
Auteur : vAvA

---

# 📌 Présentation

**vAvA_core** est un framework FiveM moderne, performant et entièrement modulaire.  
Il fournit une base solide pour construire un serveur RP ou semi‑RP sans dépendre d’ESX ou QBCore.

Le framework est :
- 🧩 **Modulaire**
- ⚡ **Optimisé**
- 🔐 **Sécurisé**
- 🌍 **Multilingue**
- 🧱 **Facile à maintenir**
- 🛠️ **Pensé pour les développeurs**

---

# 🏛️ Architecture générale

```
vAvA_core/
  client/
  server/
  shared/
  modules/
  locales/
  config/
  database/
  utils/
```

### 🔹 Caractéristiques
- Séparation claire client / serveur / shared
- Modules indépendants et activables
- API propre (exports, events, callbacks)
- Gestion centralisée des logs et erreurs
- Système de configuration global

---

# 👤 Gestion des joueurs

### 🔹 Identification
- License Rockstar
- Steam (optionnel)
- Discord (optionnel)
- Support multi‑identifiants

### 🔹 Chargement / sauvegarde
- Chargement automatique au login
- Sauvegarde automatique (intervalle configurable)
- Sauvegarde manuelle via event
- Multi‑personnages (optionnel)

### 🔹 Données joueur
- Argent liquide / banque
- Inventaire
- Job + grade
- Position
- Status (faim, soif, stress…)
- Permissions
- Métadonnées personnalisées

---

# 🗄️ Base de données

### 🔹 Technologie
- Utilisation d’**oxmysql**
- Couche DAL (Data Access Layer) propre

### 🔹 Fonctionnalités
- Requêtes préparées
- Transactions
- Système de migrations
- Cache intelligent (items, jobs, joueurs)
- Logs SQL automatiques
- Gestion des erreurs SQL

### 🔹 Tables principales
- users
- characters
- inventories
- items
- jobs
- vehicles
- bans
- logs

---

# 🌍 Système multilingue

### 🔹 Structure
```
locales/
  fr.lua
  en.lua
  es.lua
```

### 🔹 Utilisation
```lua
Lang("clé")
Lang("argent_reçu", { amount = 500 })
```

### �� Avantages
- Traductions simples
- Support des variables
- Ajout de langues illimité

---

# 💼 Système de jobs

### 🔹 Fonctionnalités
- Jobs configurables
- Grades illimités
- Permissions par job et grade
- Actions métier via callbacks
- API pour créer des jobs custom
- Événements sécurisés

---

# 💰 Économie

### 🔹 Types d’argent
- Liquide
- Banque
- Argent sale (optionnel)

### 🔹 Fonctionnalités
- Transactions sécurisées
- Logs automatiques
- API : addMoney, removeMoney, setMoney
- Vérification serveur obligatoire

---

# 🎒 Inventaire

### 🔹 Fonctionnalités
- Items stackables ou non
- Poids ou slots
- Items utilisables (callbacks)
- Items consommables
- Items avec métadonnées
- Système de drop au sol
- Gestion des armes
- Inventaires secondaires : coffres, véhicules, shops

---

# ❤️ Status & HUD

### 🔹 Status
- Faim
- Soif
- Stress
- Santé mentale (optionnel)
- API pour ajouter des status custom

### 🔹 HUD
- Barre de vie
- Faim / soif
- Notifications
- Messages système
- UI traduisible

---

# 🚗 Gestion des véhicules

### 🔹 Fonctionnalités
- Propriété véhicule
- Garage
- Assurance (optionnelle)
- Véhicules temporaires
- Véhicules de job
- Système de clés (optionnel)

---

# 🔐 Sécurité

### 🔹 Fonctionnalités
- Vérification serveur sur toutes les actions sensibles
- Anti‑trigger intégré
- Rate limit sur les events
- Logs automatiques (argent, items, jobs, véhicules)
- Détection d’events suspects
- Système de ban intégré

---

# 🧩 Modules optionnels

- Housing
- Crafting
- Shops
- Téléphone
- Compétences
- Quêtes
- Factions

---

# 🛠️ Outils développeur

### 🔹 Dev Tools
- Commandes admin
- Debug mode
- Logs détaillés
- Reload des modules sans restart complet
- API documentée

---

# 🎯 Philosophie du vava_core

- Minimaliste
- Modulaire
- Sécurisé
- Performant
- Traduisible
- Documenté
- Pensé pour durer
- Adapté aux développeurs exigeants
