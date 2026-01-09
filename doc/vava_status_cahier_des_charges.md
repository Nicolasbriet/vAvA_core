# 📘 Cahier des Charges — Module `vava_status`
### Système de faim & soif + intégration HUD + compatibilité charte graphique  
Version : 1.0.0  
Auteur : vAvA

---

# 1. 🎯 Objectif du module

Le module **vava_status** a pour objectif de gérer les statuts vitaux du joueur :

- Faim  
- Soif  

Il doit être :

- **Centralisé**  
- **Performant**  
- **Modulaire**  
- **Compatible HUD**  
- **Compatible charte graphique**  
- **Compatible vava_testbench**  
- **Facile à maintenir**  

Ce module ne doit jamais gérer l’HUD lui-même :  
👉 il **envoie les données**, l’HUD **affiche**.

---

# 2. 🧩 Intégration avec vAvA_core

## 2.1. Modules concernés
- vava_player  
- vava_inventory  
- vava_shops  
- vava_economy  
- vava_hud  
- vava_chartegraphique  
- vava_testbench  

## 2.2. API utilisée
- `OnItemConsumed`  
- `AddItem()` / `RemoveItem()`  
- `GetPrice()`  
- `TriggerClientEvent()`  
- `SendNUIMessage()` (via HUD)  

---

# 3. 🧱 Architecture du module

vava_core/
modules/
status/
server/
client/
shared/
config/
locales/
fxmanifest.lua


---

# 4. 🔧 Fonctionnement général

## 4.1. Variables principales

Chaque joueur possède :

- `status.hunger` (0 → 100)  
- `status.thirst` (0 → 100)  

100 = plein  
0 = danger

## 4.2. Décrémentation automatique

Toutes les X minutes (configurable) :

- faim : -1 à -3  
- soif : -2 à -4  

La soif descend plus vite que la faim.

## 4.3. Effets selon les niveaux

### 70–100 : Normal  
Aucun effet.

### 40–70 : Léger inconfort  
- stamina réduite légèrement  

### 20–40 : Avertissement  
- écran sombre  
- stamina réduite  
- message RP  

### 0–20 : Danger  
- perte de vie progressive  
- flou visuel  
- ralentissement  

### 0 : Effondrement  
- KO  
- respawn selon config  

---

# 5. 🍎 Consommation d’items

Les items consommables sont définis dans l’inventaire :

```lua
Items = {
  water = { thirst = 25 },
  sandwich = { hunger = 30 },
  soda = { thirst = 15 },
  burger = { hunger = 45 }
}
```
Le module écoute :

```lua 
OnItemConsumed(itemName)
```

Et applique automatiquement les effets.

# 6. 💰 Interaction avec l’économie

Le système de faim/soif doit être cohérent avec le module `vava_economy` afin de maintenir une logique économique globale dans le serveur.

## 6.1. Prix des consommables
Les prix des items liés à la faim et à la soif doivent être calculés automatiquement via :

- le multiplicateur global  
- le multiplicateur du shop  
- la rareté de l’item  
- les taxes  

Aucun prix ne doit être codé en dur.

## 6.2. Importance des métiers
Les métiers liés à la restauration (restaurants, bars, food trucks, agriculture, pêche) doivent être valorisés :

- meilleure marge de profit  
- items plus variés  
- raretés différentes  
- interactions cohérentes avec l’économie  

## 6.3. Impact sur l’économie globale
Le système de faim/soif doit influencer :

- la demande en nourriture  
- la demande en boissons  
- la valeur des items consommables  
- les revenus des shops alimentaires  

Le module doit être capable de fonctionner même si l’économie évolue.

---

# 7. 🖥️ Intégration HUD

## 7.1. Principe fondamental
Le module `vava_status` **ne doit jamais dessiner l’HUD**.  
Il doit uniquement **envoyer les données** au module `vava_hud`.

## 7.2. Envoi des données au client

```lua
TriggerClientEvent("vava_status:update", playerId, hunger, thirst)
```
## 7.3. HUD dynamique

L’HUD doit être capable d’afficher en temps réel les valeurs de faim et de soif envoyées par le module `vava_status`.  
Le module `vava_status` **ne doit jamais gérer l’affichage lui-même** : il transmet uniquement les données.

### Exigences HUD :
- Affichage clair et lisible des barres de faim et de soif  
- Mise à jour en temps réel à chaque événement `vava_hud:setStatus`  
- Adaptation automatique aux valeurs (0 → 100)  
- Support des futurs statuts (stress, fatigue, alcool, etc.)  
- Aucune logique métier dans l’HUD (affichage uniquement)  

### Exemple de message envoyé à l’HUD :

```lua
TriggerEvent("vava_hud:setStatus", {
    hunger = hunger,
    thirst = thirst
})
```

# 8. 🎨 Compatibilité charte graphique

Le module HUD doit respecter la charte graphique officielle du framework vAvA_core.  
Cette charte est définie dans :

```lua 
vava_core/docs/chartegraphique.md
```

# 9. 🔌 API du module

Le module `vava_status` doit exposer une API simple, sécurisée et centralisée permettant aux autres modules d’interagir avec les statuts vitaux du joueur.

```lua
exports("GetHunger", function(playerId) end)
exports("GetThirst", function(playerId) end)

exports("SetHunger", function(playerId, value) end)
exports("SetThirst", function(playerId, value) end)

exports("AddHunger", function(playerId, amount) end)
exports("AddThirst", function(playerId, amount) end)

exports("ConsumeItem", function(playerId, itemName) end)
```

##Contraintes API :
Toutes les valeurs doivent être validées côté serveur

Les valeurs doivent toujours rester entre 0 et 100

Les appels doivent être loggés si activé dans la configuration

Aucun module externe ne doit modifier faim/soif sans passer par cette API

L’API 

# 10. 🧪 Intégration avec `vava_testbench`

Le module `vava_status` doit être entièrement testable via le module `vava_testbench`.  
Tous les comportements critiques doivent être vérifiés automatiquement afin de garantir la stabilité du framework.

## 10.1. Tests unitaires

Les tests unitaires doivent vérifier :

- La décrémentation automatique de la faim et de la soif  
- La consommation d’items (augmentation correcte des valeurs)  
- Le respect strict des limites (0–100)  
- Le rejet des valeurs invalides (négatives, supérieures à 100, non numériques)  
- Le bon fonctionnement de chaque export du module  
- La cohérence des valeurs envoyées au client  

## 10.2. Tests d’intégration

Les tests d’intégration doivent vérifier les interactions entre `vava_status` et les autres modules :

- Interaction avec l’inventaire (consommation d’items)  
- Interaction avec l’économie (prix des consommables)  
- Interaction avec les shops (achats de nourriture/boissons)  
- Interaction avec l’HUD (réception correcte des données)  
- Interaction avec les jobs (métiers liés à la restauration)  

## 10.3. Tests HUD

Le testbench doit vérifier :

- Que l’HUD reçoit bien les valeurs envoyées par `vava_status`  
- Que les valeurs affichées sont cohérentes  
- Que l’HUD ne reçoit jamais de valeurs invalides  
- Que l’HUD applique correctement la charte graphique  
- Que les messages NUI sont envoyés sans surcharge  

## 10.4. Tests de charge

Le module doit rester stable sous forte activité :

- 100 joueurs simultanés → stable  
- 1000 updates/minute → stable  
- Aucun freeze NUI  
- Aucun overflow d’événements  
- Aucun impact notable sur les performances serveur  

## 10.5. Tests charte graphique

Le testbench doit vérifier que :

- L’HUD utilise bien les valeurs définies dans `chartegraphique.md`  
- Aucune couleur n’est codée en dur  
- Aucune police n’est codée en dur  
- Les marges, arrondis et animations respectent la charte  
- Toute modification de la charte se reflète correctement dans l’HUD  

---

# 11. 🔐 Sécurité

Le module doit garantir une sécurité maximale :

- Les valeurs faim/soif ne doivent **jamais** être négatives  
- Les valeurs faim/soif ne doivent **jamais** dépasser 100  
- Toute modification doit être validée côté serveur  
- Anti‑cheat sur la consommation d’items  
- Protection contre le spam d’updates HUD  
- Logs optionnels pour le debug  
- Aucun calcul critique ne doit être effectué côté client  
- Les données envoyées au client doivent être minimales et sécurisées  

---

# 12. 🌍 Multilingue

Le module doit supporter plusieurs langues via un système de locales :

locales/
fr.lua
en.lua
es.lua


### Contraintes :
- Aucun texte ne doit être codé en dur dans le code  
- Tous les messages doivent passer par les locales  
- Le module doit être compatible avec les futures langues du framework  

---

# 13. 📦 Livrables

Le module `vava_status` doit fournir :

- Le **code source complet**  
- La **documentation technique**  
- L’**API détaillée**  
- L’intégration HUD  
- L’intégration testbench  
- Le fichier `config.lua`  
- Les fichiers de **localisation**  
- Un exemple d’implémentation HUD  
- Un exemple de test automatisé  

---

# 14. 🧱 Philosophie du module

Le module doit être :

- **Simple** : facile à comprendre et à maintenir  
- **Modulaire** : indépendant, mais compatible avec tout le framework  
- **Cohérent** : respecte la logique globale de vAvA_core  
- **Performant** : aucun impact notable sur le client ou le serveur  
- **Compatible** : HUD, économie, inventaire, testbench  
- **Durable** : pensé pour évoluer  
- **Centralisé** : aucune duplication de logique  
- **Respectueux de la charte graphique**  
- **Testable automatiquement**  


