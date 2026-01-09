# Guide d'Installation et Configuration - Module Jobs

## 📦 Installation Complète

### Étape 1: Base de données

1. Ouvrez votre gestionnaire MySQL (HeidiSQL, phpMyAdmin, etc.)
2. Sélectionnez votre base de données FiveM
3. Exécutez le fichier SQL:
   ```bash
   source /path/to/vAvA_core/database/sql/jobs_system.sql
   ```

Cela créera toutes les tables nécessaires:
- ✅ `jobs_config` - Configuration des jobs
- ✅ `job_grades` - Grades et salaires
- ✅ `job_interactions` - Points d'interaction
- ✅ `job_vehicles` - Véhicules de service
- ✅ `job_outfits` - Tenues de job
- ✅ `job_farm_items` - Items farmables
- ✅ `job_craft_recipes` - Recettes de craft
- ✅ `job_sell_items` - Items vendables
- ✅ `job_accounts` - Comptes société
- ✅ `job_logs` - Logs d'actions

### Étape 2: Configuration du serveur

Ajoutez au `server.cfg`:
```cfg
# Core principal
ensure vAvA_core

# Module Jobs
ensure jobs

# Dépendances
ensure oxmysql
ensure ox_lib  # Optionnel mais recommandé
```

### Étape 3: Configuration du module

Éditez `modules/jobs/config.lua`:

```lua
-- Distance d'interaction (en mètres)
JobsConfig.InteractionDistance = 2.5

-- Activer les salaires automatiques
JobsConfig.EnablePaycheck = true
JobsConfig.PaycheckInterval = 600000 -- 10 minutes

-- Groupes admin pour la création de jobs
JobsConfig.AdminGroups = {'admin', 'god', 'superadmin'}
```

## 🎮 Guide de Démarrage Rapide

### Pour les Admins

#### 1. Créer votre premier job personnalisé

Connectez-vous au serveur et tapez:
```
/createbaker
```

Cela créera le job "baker" (boulangerie) avec:
- 4 grades (Apprenti → Patron)
- Salaires progressifs
- Permissions configurées
- Compte société

#### 2. Configurer les points d'interaction

```
/setupbaker
```

Cela créera:
- Point de prise de service
- Vestiaire
- Point de farm (farine)
- Point de craft (four)
- Point de vente
- Coffre
- Menu patron

#### 3. Ajouter items et recettes

```
/setupbakeritems
```

#### 4. Ajouter véhicules et tenues

```
/setupbakervehicles
/setupbakeroutfits
```

#### 5. Donner le job à un joueur

```
/givejob [id] baker 0
```

### Pour les Joueurs

#### Démarrer sa journée de travail

1. **Aller à la prise de service**
   - Repérez le marker vert
   - Appuyez sur `E`
   - Vous êtes maintenant en service

2. **Changer de tenue**
   - Allez au vestiaire (marker bleu)
   - Appuyez sur `E`
   - Choisissez votre tenue

3. **Prendre un véhicule**
   - Allez au garage (marker jaune)
   - Appuyez sur `E`
   - Choisissez un véhicule
   - Il spawn automatiquement

#### Travailler

**Farm (Récolte)**
1. Allez au point de farm
2. Appuyez sur `E`
3. Attendez la barre de progression
4. Recevez l'item

**Craft (Fabrication)**
1. Allez au point de craft
2. Appuyez sur `E`
3. Choisissez une recette
4. Vérifiez que vous avez les ingrédients
5. Craftez

**Vente**
1. Allez au point de vente
2. Appuyez sur `E`
3. Choisissez l'item à vendre
4. Vendez tout votre stock
5. Recevez l'argent

#### Fin de service

1. Rangez votre véhicule au garage
2. Changez de tenue (civil)
3. Fin de service au point duty

## 🔧 Configuration Avancée

### Jobs EMS (Ambulance)

Le job EMS est pré-configuré avec:

**Grades:**
- 0: Recrue
- 1: Ambulancier (peut réanimer)
- 2: Médecin (pharmacie)
- 3: Médecin Chef (gestion)
- 4: Directeur (boss)

**Points d'interaction recommandés:**
```lua
-- Hôpital Pillbox Hill
duty: vector3(311.27, -596.87, 43.28)
wardrobe: vector3(302.51, -598.45, 43.28)
vehicle: vector3(295.75, -603.19, 43.28)
storage: vector3(307.68, -601.45, 43.28)
boss: vector3(335.57, -594.29, 43.28)
pharmacy: vector3(309.77, -597.98, 43.28)
```

**Véhicules recommandés:**
- ambulance
- firetruk (pour les pompiers)

### Jobs Police

Le job Police est pré-configuré avec:

**Grades:**
- 0: Cadet
- 1: Officier (menotter, fouiller, amende)
- 2: Sergent (prison, fourrière)
- 3: Lieutenant (gestion)
- 4: Commissaire (boss)

**Points d'interaction recommandés:**
```lua
-- Commissariat Mission Row
duty: vector3(440.74, -975.13, 30.69)
wardrobe: vector3(461.31, -998.11, 30.69)
vehicle: vector3(448.16, -1026.33, 28.59)
storage: vector3(452.35, -980.09, 30.69)
boss: vector3(459.51, -985.57, 30.69)
armory: vector3(453.08, -980.14, 30.69)
```

**Véhicules recommandés:**
- police
- police2
- police3
- policeb (moto)
- riot (SWAT)

### Jobs Mechanic

Le job Mechanic est pré-configuré avec:

**Grades:**
- 0: Apprenti (réparation)
- 1: Novice (fourrière)
- 2: Expérimenté (customs)
- 3: Chef d'atelier (gestion)
- 4: Patron (boss)

**Points d'interaction recommandés:**
```lua
-- Garage Benny's
duty: vector3(-205.68, -1310.58, 31.29)
wardrobe: vector3(-191.17, -1301.43, 31.29)
vehicle: vector3(-198.59, -1291.62, 31.29)
storage: vector3(-202.99, -1315.77, 31.29)
boss: vector3(-188.75, -1314.12, 31.29)
customs: vector3(-212.02, -1324.84, 30.89)
```

**Véhicules recommandés:**
- flatbed (dépanneuse)
- towtruck
- towtruck2
- sadler (pickup)

## 📊 Système de Permissions

### Permissions Communes

| Permission | Description | Grade typique |
|-----------|-------------|---------------|
| `hire` | Recruter des employés | 2-3 |
| `fire` | Licencier des employés | 2-3 |
| `promote` | Promouvoir | 3 |
| `demote` | Rétrograder | 3 |
| `manage` | Gérer le job | 3-4 |
| `withdraw` | Retirer argent société | 4 |
| `deposit` | Déposer argent société | Tous |
| `all` | Toutes permissions | 4 |

### Permissions EMS

| Permission | Description |
|-----------|-------------|
| `revive` | Réanimer les joueurs |
| `heal` | Soigner |
| `pharmacy` | Accès pharmacie |

### Permissions Police

| Permission | Description |
|-----------|-------------|
| `cuff` | Menotter |
| `search` | Fouiller |
| `fine` | Donner amendes |
| `jail` | Mettre en prison |
| `impound` | Mettre en fourrière |

### Permissions Mechanic

| Permission | Description |
|-----------|-------------|
| `repair` | Réparer véhicules |
| `impound` | Sortir de fourrière |
| `customs` | Customiser véhicules |

## 🎨 Personnalisation des Markers

Dans `config.lua`, modifiez `JobsConfig.DefaultMarkers`:

```lua
JobsConfig.DefaultMarkers = {
    duty = {
        type = 27,
        size = {x = 1.5, y = 1.5, z = 1.0},
        color = {r = 0, g = 255, b = 0, a = 100}
    },
    -- etc.
}
```

**Types de markers:**
- 0-43: Différents styles (cylindres, flèches, etc.)
- 27: Cercle au sol (recommandé)
- 1: Cylindre vertical

## 🔍 Debugging

Activez le mode debug:

```lua
JobsConfig.Debug = true
```

Puis consultez:
- F8 (console client)
- `server-console.log`
- `txAdmin console`

## 🤝 Intégration avec d'autres ressources

### Avec ox_inventory

Le système détecte automatiquement ox_inventory pour:
- Coffres de job
- Vérification d'items
- Ajout/retrait d'items

### Avec esx_skin / qb-clothing

Compatible avec les systèmes de tenues:
- Sauvegarde de la tenue civile
- Application des tenues de job
- Restauration automatique

### Avec ox_lib

Utilisation automatique de:
- Progress bars
- Context menus
- Input dialogs
- Notifications

## 📞 Support et Aide

### Problèmes courants

**Les interactions ne s'affichent pas**
- Vérifiez que vous avez le bon job
- Vérifiez le grade minimum
- Vérifiez que vous êtes en service (si requis)
- Consultez les logs

**Les véhicules ne spawn pas**
- Vérifiez que le modèle existe
- Vérifiez l'espace disponible
- Consultez la console F8

**Le craft ne fonctionne pas**
- Vérifiez les ingrédients
- Vérifiez le grade requis
- Vérifiez que la recette est activée en DB

### Commandes utiles (Admin)

```
/createjob [nom] - Créer un job
/deletejob [nom] - Supprimer un job
/givejob [id] [job] [grade] - Donner un job
/setduty [id] [true/false] - Mettre en service
/reloadjobs - Recharger les jobs depuis la DB
```

## 📝 Checklist Post-Installation

- [ ] SQL exécuté sans erreurs
- [ ] Module démarré dans server.cfg
- [ ] Jobs par défaut créés (EMS, Police, Mechanic)
- [ ] Points d'interaction configurés
- [ ] Véhicules ajoutés
- [ ] Tenues configurées
- [ ] Items et recettes créés
- [ ] Tests effectués avec un joueur
- [ ] Système de salaire testé
- [ ] Menu patron testé

## 🎉 C'est prêt !

Votre système de jobs est maintenant opérationnel. Les joueurs peuvent:
- Choisir leur métier
- Travailler (farm, craft, vente)
- Utiliser les véhicules de service
- Gérer leur entreprise (patrons)

Les admins peuvent:
- Créer des jobs illimités
- Configurer tous les aspects
- Surveiller l'activité via les logs
- Gérer les employés

Bonne chance ! 🚀
