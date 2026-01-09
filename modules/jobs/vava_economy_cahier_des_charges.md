# 📘 Cahier des Charges — Module `vava_economy`
### Système d’économie automatique, centralisé et auto‑adaptatif  
Compatible Framework **vAvA_core**  
Version : 1.0.0  
Auteur : vAvA

---

# 1. 🎯 Objectif du module

Le module **vava_economy** a pour but de fournir une économie :

- **Centralisée** : un seul fichier contrôle toute l’économie du serveur  
- **Automatique** : prix, salaires, shops, récompenses, taxes  
- **Auto‑adaptative** : ajustements dynamiques selon l’activité des joueurs  
- **Cohérente** : tout suit une logique mathématique stable  
- **Modulaire** : compatible avec tous les modules vAvA_core  
- **Facile à maintenir** : changer l’économie en 10 secondes  
- **Durable** : impossible à casser, même avec des ajouts futurs  

Ce système doit éliminer la gestion manuelle des prix et garantir une économie stable, équilibrée et évolutive.

---

# 2. 🧩 Intégration avec vAvA_core

## 2.1. Dépendances internes
- Module **database**  
- Module **locales**  
- Module **player**  
- Module **inventory**  
- Module **jobs**  
- Module **shops**  
- Module **utils**

## 2.2. Points d’entrée (API)
- `GetPrice(item)`  
- `GetSalary(job)`  
- `GetShopMultiplier(shop)`  
- `ApplyTax(type, amount)`  
- `RecalculateEconomy()`  

## 2.3. Compatibilité
- Items  
- Shops  
- Jobs  
- Crafting  
- Véhicules  
- Housing  
- Téléphone  
- Inventaire  
- Scripts tiers via API  

---

# 3. 🧱 Architecture du module
vava_core/
modules/
economy/
server/
shared/
config/
locales/
utils/


---

# 4. ⚙️ Fonctionnement général

## 4.1. Fichier central `economy.lua`
Contient :
- Prix des items  
- Salaires des jobs  
- Multiplicateurs globaux  
- Taxes  
- Profils économiques  
- Paramètres d’auto‑adaptation  

## 4.2. Multiplicateur global
Permet de modifier toute l’économie instantanément :

```lua
Economy.baseMultiplier = 1.0
```
## 4.3. Profils économiques
EconomyProfiles = {
  hardcore = 0.5,
  normal = 1.0,
  riche = 2.0,
  ultra_riche = 5.0
}


## 4.4. Calcul automatique des prix

```lua 
prix_final = prix_base × baseMultiplier × shopMultiplier × rarityMultiplier × taxes
```
## 4.5. Rareté des items
Chaque item possède une rareté (1 à 10) :

```lua 
Items = {
  diamant = { rarity = 10 },
  pain = { rarity = 1 }
}
```
Le module calcule automatiquement le prix.

## 5. 🔄 Système auto‑adaptatif
## 5.1. Ajustement dynamique des prix
Le prix d’un item évolue selon :

Fréquence d’achat

Fréquence de vente

Quantité en circulation

Activité globale des joueurs

Formule :
```lua 
nouveau_prix = prix_actuel × (1 + (taux_achat - taux_vente) × 0.05)
```

## 5.2. Ajustement des salaires
Les salaires s’adaptent selon :

Nombre de joueurs dans le job

Importance du job

Activité économique globale

## 5.3. Ajustement des shops
Chaque shop possède un multiplicateur dynamique :

Zone riche → prix plus élevés

Zone pauvre → prix plus bas

Shop premium → multiplicateur x2

## 6. 🛍️ Gestion des shops
## 6.1. Multiplicateurs par shop

```lua 
Shops = {
  binco = 0.8,
  suburban = 1.2,
  ponsonbys = 2.0
}
```

## 6.2. Prix automatiques
```lua 
prix_final = prix_base × shopMultiplier × baseMultiplier
```

## 6.3. API shop
GetShopMultiplier(shop)

GetFinalPrice(item, shop)

# 7. 💼 Gestion des jobs

## 7.1. Salaires automatiques

Chaque job possède un salaire de base défini dans la configuration :

```lua
Jobs = {
  police = { baseSalary = 150 },
  mecanicien = { baseSalary = 120 },
  taxi = { baseSalary = 100 }
}
```
Le module applique automatiquement la formule suivante :

```lua
salaire_final = baseSalary × baseMultiplier × jobBonus
```
Paramètres influençant le salaire :
baseSalary : valeur fixe définie par le serveur

baseMultiplier : multiplicateur global de l’économie

jobBonus : bonus spécifique selon l’importance du job

inflation (optionnel) : ajustement automatique selon l’économie globale

## 7.2. Bonus par job

Chaque job peut avoir un bonus de rôle permettant d’ajuster automatiquement son salaire final.

Exemple de configuration :

```lua
Jobs = {
  police = { baseSalary = 150, bonus = 1.2 },
  ems = { baseSalary = 140, bonus = 1.3 },
  mecanicien = { baseSalary = 120, bonus = 1.0 }
}
```
Le bonus est appliqué dans la formule suivante :
```lua 
salaire_final = baseSalary × baseMultiplier × jobBonus
```

Règles :
Les jobs essentiels (police, EMS, mécano) ont un bonus plus élevé.

Les jobs RP ont un bonus standard.

Les jobs illégaux ont un bonus variable, mais contrôlé par cooldown.

# 8. 💰 Taxes

## 8.1. Types de taxes

Le module gère plusieurs types de taxes :

- Taxe d’achat  
- Taxe de vente  
- Taxe sur les salaires  
- Taxe sur les transferts bancaires  
- Taxe sur les véhicules  
- Taxe immobilière  

## 8.2. Exemple de configuration

```lua
Taxes = {
  achat = 0.05,
  vente = 0.03,
  salaire = 0.02,
  transfert = 0.01
}
```

## 8.3. Application automatique

Le module applique automatiquement les taxes via la formule suivante :

```lua 
montant_final = montant × (1 + taxe)
```


Les taxes sont appliquées dans tous les modules compatibles :  
- achats en shops  
- ventes d’items  
- salaires  
- transferts bancaires  
- achats de véhicules  
- achats immobiliers  

Le système garantit une cohérence totale entre tous les modules du framework.

---

# 9. 🧱 Règles économiques avancées (cohérence globale)

## 9.1. Règle fondamentale  
**1 unité = 1 minute de travail d’un job basique**

Cette unité est la base de toute l’économie du serveur.  
Elle permet de maintenir une cohérence globale entre les prix, les salaires et les récompenses.

---

## 9.2. Règle d’équilibre  
Un joueur doit pouvoir vivre correctement avec un job basique.

Cela implique que les prix essentiels doivent rester accessibles :

- Nourriture : **1–3 unités**  
- Eau : **1 unité**  
- Transport basique : **2–5 unités**  
- Vêtements basiques : **5–10 unités**  

---

## 9.3. Règle de progression  
Chaque tier économique doit coûter **×2 à ×3** par rapport au précédent.

| Tier | Exemple | Coût |
|------|---------|------|
| Basique | Pain, eau, t-shirt | 1–5 unités |
| Intermédiaire | Outils, vêtements stylés | 10–20 unités |
| Avancé | Armes légales, véhicules | 50–200 unités |
| Luxe | Villas, supercars | 500–2000 unités |

Cette règle garantit une progression naturelle et évite les déséquilibres.

---

## 9.4. Règle de rareté  
Chaque item possède une rareté (1 à 10).  
Le prix final est calculé automatiquement :

```lua 
prix = rareté × baseMultiplier × shopMultiplier
```


Plus un item est rare, plus son prix augmente de manière cohérente.

---

## 9.5. Règle d’offre et demande  
Le prix d’un item évolue selon son utilisation réelle par les joueurs :

- Trop acheté → prix augmente  
- Trop vendu → prix baisse  

Formule :

```lua 
nouveau_prix = prix_actuel × (1 + (taux_achat - taux_vente) × 0.05)
```

Ce système crée une économie vivante et dynamique.

---

## 9.6. Règle des salaires  
Hiérarchie des salaires :

1. **Jobs essentiels** (police, EMS, mécano) → salaire × 1.5  
2. **Jobs RP** (serveur, taxi, livreur) → salaire × 1.0  
3. **Illégal** → variable, mais contrôlé par cooldown  

Cette règle maintient un équilibre entre utilité, risque et récompense.

---

## 9.7. Règle des shops  
Chaque shop applique un multiplicateur propre :

```lua 
prix_final = prix_base × shopMultiplier × baseMultiplier
```

Exemples :
- Binco → 0.8  
- Suburban → 1.2  
- Ponsonbys → 2.0  

---

## 9.8. Règle des taxes  
Les taxes servent à stabiliser l’économie et éviter l’inflation.  
Elles doivent être cohérentes et proportionnelles.

---

## 9.9. Règle anti‑inflation  
Pour éviter les dérives :

- **Prix minimum** : 1 unité  
- **Prix maximum** : 10 000 unités  

Le module empêche automatiquement tout dépassement.

---

## 9.10. Règle de cohérence globale  
Tout doit respecter une logique économique :

- Nourriture < Vêtements < Véhicules < Immobilier  
- Jobs basiques < Jobs essentiels < Illégal  
- Items basiques < Items rares < Items luxe  

Si un prix casse cette logique, le module le corrige automatiquement.

---

## 9.11. Règle de modularité  
Tous les scripts doivent utiliser l’API économie :

- `GetPrice()`  
- `GetSalary()`  
- `ApplyTax()`  

Aucun prix ne doit être codé en dur dans un script externe.

---

## 9.12. Règle de stabilité  
Les ajustements automatiques sont limités à :

- **±10 % par cycle**  
- **1 cycle toutes les 24h**  

Cela évite les fluctuations violentes.

---

## 9.13. Règle de monitoring  
Tous les changements économiques doivent être loggés :

- Prix  
- Salaires  
- Taxes  
- Inflation  
- Recalcul global  

Ces logs permettent un suivi précis de l’évolution de l’économie.

---

# 10. 🗄️ Base de données

## 10.1. Table `economy_logs`

Champs :
- `id`  
- `type`  
- `item`  
- `old_price`  
- `new_price`  
- `timestamp`  

## 10.2. Table `economy_state`

Champs :
- `inflation`  
- `baseMultiplier`  
- `lastUpdate`  

---

# 11. 🔐 Sécurité

## 11.1. Vérifications serveur
- Aucun prix négatif  
- Aucun salaire au‑delà d’un plafond  
- Anti‑cheat sur les prix client  
- Vérification des shops autorisés  

## 11.2. Logs
- Changement de prix  
- Changement de salaire  
- Changement de taxe  
- Inflation  
- Recalcul global  

---

# 12. 🌍 Multilingue

## 12.1. Structure
locales/
fr.lua
en.lua
es.lua


## 12.2. Clés essentielles
- Messages d’erreur  
- Messages de confirmation  
- Logs  
- UI admin  

---

# 13. 🧪 Tests

## 13.1. Tests unitaires
- Calcul des prix  
- Calcul des salaires  
- Application des taxes  
- Multiplicateurs  

## 13.2. Tests de charge
- 100 joueurs simultanés  
- 1000 achats/minute  

## 13.3. Tests de cohérence
- Prix cohérents entre shops  
- Salaires équilibrés  
- Inflation stable  

---

# 14. 📦 Livrables

## 14.1. Code source
- `server/main.lua`  
- `shared/economy.lua`  
- `config/economy.lua`  
- `locales/`  
- `utils/`  
- `fxmanifest.lua`  

## 14.2. Documentation
- README  
- Guide d’intégration  
- Guide développeur  
- Guide utilisateur  
- Guide “Créer une économie personnalisée”  

---

# 15. 🧱 Philosophie du module

- Centralisé  
- Automatique  
- Auto‑adaptatif  
- Cohérent  
- Performant  
- Sécurisé  
- Modulaire  
- Facile à maintenir  
- Pensé pour durer  

# 16. 🖥️ Interface Admin — Tableau de Bord Économique (Dashboard)

L’interface admin du module **vava_economy** doit permettre une **visualisation claire**, **en temps réel**, et **interactive** de l’économie du serveur.  
Elle doit être pensée comme un véritable **outil d’analyse économique**, accessible uniquement aux administrateurs autorisés.

---

## 16.1. Objectifs de l’interface admin

- Offrir une **vision globale** de l’économie du serveur  
- Permettre un **suivi en temps réel** des variations de prix, salaires et taxes  
- Fournir des **graphiques dynamiques** pour analyser les tendances  
- Permettre des **ajustements manuels** si nécessaire  
- Garantir une **transparence totale** sur les changements automatiques  
- Servir d’outil de **diagnostic** en cas de déséquilibre économique  

---

## 16.2. Fonctionnalités principales

### 🔹 1. Tableau de bord général (Overview)
- Inflation actuelle  
- Multiplicateur global actif  
- Nombre total d’items affectés  
- Nombre de jobs actifs  
- Dernier recalcul automatique  
- Prochain recalcul prévu  

### 🔹 2. Graphiques dynamiques
L’interface doit afficher plusieurs graphiques interactifs :

#### 📊 Graphique 1 : Évolution des prix (items)
- Courbe sur 7 jours / 30 jours  
- Filtre par rareté  
- Filtre par catégorie (nourriture, vêtements, armes, etc.)  

#### 📈 Graphique 2 : Activité économique
- Nombre d’achats par heure  
- Nombre de ventes par heure  
- Volume total de transactions  

#### 📉 Graphique 3 : Inflation
- Courbe d’inflation globale  
- Comparaison avant/après recalcul  

#### 💼 Graphique 4 : Salaires
- Évolution des salaires par job  
- Comparaison jobs essentiels / RP / illégal  

---

## 16.3. Tableaux interactifs

### 📋 Tableau 1 : Liste des items
Colonnes :
- Nom  
- Rareté  
- Prix actuel  
- Prix précédent  
- Variation (%)  
- Shop multiplier  
- Dernière mise à jour  

### 📋 Tableau 2 : Liste des jobs
Colonnes :
- Nom du job  
- Salaire de base  
- Bonus  
- Salaire final  
- Variation (%)  
- Nombre de joueurs actifs  

### 📋 Tableau 3 : Taxes
Colonnes :
- Type de taxe  
- Valeur actuelle  
- Valeur précédente  
- Variation (%)  

---

## 16.4. Contrôles administrateur

### 🎚️ Ajustements manuels
- Modifier le **baseMultiplier**  
- Modifier les **taxes**  
- Modifier les **bonus de job**  
- Modifier la **rareté d’un item**  
- Modifier le **prix d’un item** (override manuel)  

### 🔄 Recalcul global
Bouton :
- **Recalculer l’économie maintenant**

Avec confirmation obligatoire.

### 🧹 Réinitialisation
Bouton :
- **Réinitialiser l’économie aux valeurs par défaut**

Avec double confirmation.

---

## 16.5. Logs visibles dans l’interface

L’admin doit pouvoir consulter :
- Historique des variations de prix  
- Historique des variations de salaires  
- Historique des variations de taxes  
- Historique des recalculs automatiques  
- Historique des overrides manuels  
- Historique des anomalies détectées  

Chaque log doit afficher :
- Date  
- Type d’action  
- Ancienne valeur  
- Nouvelle valeur  
- Source (auto / admin)  

---

## 16.6. Sécurité de l’interface admin

- Accès réservé aux administrateurs via permissions vAvA_core  
- Toutes les actions doivent être loggées  
- Double confirmation pour les actions critiques  
- Protection anti‑spam (cooldown sur les recalculs manuels)  
- Vérification serveur obligatoire pour chaque modification  

---

## 16.7. Technologies recommandées

- UI en **NUI** (HTML/CSS/JS)  
- Framework JS moderne (Vue.js ou React recommandé)  
- Graphiques via **Chart.js** ou **ECharts**  
- Communication via **callbacks sécurisés**  
- Données en JSON compressé pour performance  

---

## 16.8. Philosophie UX

L’interface doit être :

- **Clairvoyante** : l’admin comprend l’état de l’économie en 5 secondes  
- **Visuelle** : graphiques avant tableaux  
- **Interactive** : filtres, zoom, survols, comparaisons  
- **Sécurisée** : aucune action dangereuse sans confirmation  
- **Éducative** : chaque valeur doit avoir un tooltip explicatif  
- **Moderne** : animations douces, transitions propres  

---

## 16.9. Exemple de structure UI

vava_economy_admin/
ui/
index.html
style.css
app.js
components/
dashboard.vue
charts.vue
items.vue
jobs.vue
taxes.vue
logs.vue
settings.vue


---

## 16.10. Résultat attendu

L’interface admin doit permettre :

- Une **maîtrise totale** de l’économie  
- Une **compréhension immédiate** des tendances  
- Une **réactivité** en cas de déséquilibre  
- Une **transparence** sur les actions automatiques  
- Une **simplicité d’utilisation**, même pour un admin non technique  

Elle devient un **véritable outil d’analyse économique**, digne d’un framework professionnel.



