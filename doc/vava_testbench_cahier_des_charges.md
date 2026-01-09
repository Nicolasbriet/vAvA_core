# 📘 Cahier des Charges — Module `vava_testbench`
### Module de test complet, automatique et adaptatif pour le framework vAvA_core  
Version : 1.0.0  
Auteur : vAvA

---

# 1. 🎯 Objectif du module

Le module **vava_testbench** a pour objectif de fournir un environnement complet permettant de :

- Tester **toutes les fonctionnalités** du framework vAvA_core  
- Vérifier la **compatibilité** entre les modules  
- Détecter les **erreurs**, **incohérences**, **performances anormales**  
- Simuler des **scénarios réels** (économie, jobs, inventaire, shops, etc.)  
- Offrir une **interface admin dédiée** pour lancer et visualiser les tests  
- Permettre un développement **rapide**, **fiable**, **sans polluer le serveur final**  
- S’adapter automatiquement aux **nouveaux modules ajoutés** au framework  

Ce module est **strictement interne** et ne doit pas être utilisé en production.

---

# 2. 🧩 Intégration avec vAvA_core

## 2.1. Modules testés
Le testbench doit couvrir automatiquement :

- vava_core (base)  
- vava_player  
- vava_creator  
- vava_inventory  
- vava_jobs  
- vava_shops  
- vava_economy  
- vava_vehicles  
- vava_housing  
- vava_utils  
- vava_admin  
- **Tous les modules futurs**  

## 2.2. API utilisée
Le testbench doit utiliser **uniquement** les exports officiels :

- `GetPlayerData()`  
- `GetPrice()`  
- `GetSalary()`  
- `AddItem()`  
- `RemoveItem()`  
- `AddMoney()`  
- `RemoveMoney()`  
- `SetJob()`  
- `OpenCreator()`  

Aucun accès direct à la base de données.

---

# 3. 🧱 Architecture du module

vava_core/
modules/
testbench/
client/
server/
ui/
tests/
auto/
unit/
integration/
stress/
security/
logs/
config.lua
fxmanifest.lua



---

# 4. 🖥️ Interface Admin (UI)

Le module doit inclure une interface admin dédiée permettant de :

- Lancer des tests unitaires  
- Lancer des tests d’intégration  
- Lancer des tests de charge  
- Lancer des tests de sécurité  
- Voir les résultats en temps réel  
- Voir les logs  
- Voir les erreurs  
- Voir les performances  

## 4.1. Éléments UI
- Dashboard général  
- Liste des modules détectés  
- Liste des tests par module  
- Boutons “Lancer test”  
- Graphiques de performance  
- Logs en direct  
- Résultats détaillés  

---

# 5. 🧪 Types de tests

## 5.1. Tests unitaires
Testent chaque fonction individuellement :

- API économie  
- API inventaire  
- API jobs  
- API shops  
- API player  
- API utils  

## 5.2. Tests d’intégration
Testent les interactions entre modules :

- Acheter un item → inventaire + économie  
- Changer de job → salaire + permissions  
- Acheter un vêtement → shops + creator  
- Créer un personnage → DB + player  

## 5.3. Tests de charge
Simulent :

- 50 joueurs  
- 100 joueurs  
- 200 joueurs  

Actions simulées :

- achats massifs  
- salaires massifs  
- craft en boucle  
- spawn véhicules  
- interactions shops  

## 5.4. Tests de cohérence
Vérifient :

- cohérence des prix  
- cohérence des salaires  
- cohérence des taxes  
- cohérence des shops  
- cohérence des items  

## 5.5. Tests de sécurité
Vérifient :

- anti-cheat  
- validation serveur  
- injections d’events  
- bypass économie  
- bypass inventaire  

---

# 6. 📊 Résultats & Logs

## 6.1. Logs automatiques
Chaque test doit générer un log :

- date  
- module testé  
- résultat  
- erreurs  
- temps d’exécution  

## 6.2. Résultats visuels
L’UI doit afficher :

- ✔️ Succès  
- ❌ Échec  
- ⚠️ Avertissement  
- ⏱️ Temps d’exécution  

## 6.3. Export
Possibilité d’exporter les résultats en JSON.

---

# 7. ⚙️ Configuration

## 7.1. config.lua
Contient :

- activation/désactivation du testbench  
- niveau de logs  
- tests automatiques au démarrage  
- tests programmés (cron)  
- paramètres de charge  

---

# 8. 🔐 Sécurité

- Accès réservé aux admins  
- Logs obligatoires  
- Aucun impact sur l’économie réelle  
- Aucun impact sur les joueurs réels  
- Sandbox interne pour les tests destructifs  

---

# 9. 🚀 Scénarios de test prévus

## 9.1. Scénario “Cycle économique complet”
1. Donner un job  
2. Recevoir un salaire  
3. Acheter un item  
4. Vendre un item  
5. Acheter un vêtement  
6. Acheter un véhicule  
7. Vérifier cohérence économie  

## 9.2. Scénario “Création de personnage”
1. Ouvrir creator  
2. Modifier morphologie  
3. Modifier vêtements  
4. Sauvegarder  
5. Charger personnage  
6. Vérifier DB  

## 9.3. Scénario “Inventaire”
1. Ajouter item  
2. Retirer item  
3. Stack  
4. Métadonnées  
5. Drop au sol  

## 9.4. Scénario “Jobs”
1. Changer job  
2. Recevoir salaire  
3. Vérifier permissions  

---

# 10. 🔄 Adaptativité du module `vava_testbench`

## 10.1. Détection automatique des modules
Le testbench doit :

- scanner automatiquement `vava_core/modules/`  
- détecter chaque module présent  
- vérifier s’il contient un dossier `tests/`  
- charger automatiquement tous les tests trouvés  
- ajouter automatiquement le module dans l’UI  

Aucune configuration manuelle.

---

## 10.2. Structure standardisée des tests

modules/<nom_du_module>/tests/
unit/
integration/
stress/
security/


---

## 10.3. API adaptative
Le testbench doit détecter automatiquement les exports d’un module et générer des tests basiques.

---

## 10.4. Interface admin adaptative
L’UI doit afficher automatiquement :

- les modules détectés  
- leurs tests  
- leurs résultats  
- leurs logs  

---

## 10.5. Hooks automatiques

```lua
Testbench:RegisterTest("inventory", "unit", "AddItem", function(assert)
    assert(IsFunction(exports.vava_inventory.AddItem))
end)
```
## 10.6. Tests automatiques au démarrage

Le module `vava_testbench` doit être capable d’exécuter automatiquement une série de **tests critiques** au démarrage du serveur, afin de détecter immédiatement :

- des modules cassés  
- des exports manquants  
- des incohérences économiques  
- des erreurs d’intégration  
- des problèmes de performance  

### Fonctionnement attendu :

1. Le serveur démarre  
2. Le testbench scanne tous les modules  
3. Il exécute les tests marqués comme **critiques**  
4. Il génère un rapport dans la console et dans un fichier log  
5. Il affiche un résumé clair :

Exemple :

[TESTBENCH] vava_inventory : OK (12 tests) [TESTBENCH] vava_jobs : OK (8 tests) [TESTBENCH] vava_economy : WARNING (1 incohérence détectée) [TESTBENCH] vava_creator : ERROR (callback manquant)



Les erreurs critiques doivent être clairement identifiées pour éviter d’ouvrir un serveur instable.

---

## 10.7. Compatibilité future

Le module `vava_testbench` doit être conçu pour fonctionner **sans aucune modification**, même si :

- de nouveaux modules sont ajoutés  
- de nouvelles catégories de tests apparaissent  
- de nouvelles API sont créées  
- la structure interne de vAvA_core évolue  
- des modules tiers sont intégrés  

### Exigences :

- Aucun nom de module ne doit être codé en dur  
- Le testbench doit s’adapter automatiquement à la structure du framework  
- Le système doit être **auto‑évolutif**  
- Les tests doivent être chargés dynamiquement  
- L’interface admin doit se mettre à jour automatiquement  

Le testbench doit être pensé comme un **système vivant**, capable de suivre l’évolution du framework.

---

## 10.8. Résultat attendu

Le module `vava_testbench` doit devenir un **outil de QA complet**, offrant :

- une vision claire de l’état du framework  
- une détection automatique des erreurs  
- une validation des modules avant mise en production  
- une interface admin intuitive  
- un système de logs détaillé  
- une compatibilité totale avec les modules futurs  
- une automatisation maximale  

En résumé, `vava_testbench` doit être :

- **auto‑configuré**  
- **auto‑adaptatif**  
- **auto‑documenté**  
- **indispensable** au développement du framework vAvA_core  

---

# 11. 🧱 Philosophie du module

Le module `vava_testbench` doit respecter les principes suivants :

- **Fiabilité** : détecter les erreurs avant qu’elles n’impactent le serveur  
- **Automatisation** : réduire au maximum les interventions manuelles  
- **Transparence** : logs complets, résultats clairs  
- **Performance** : tests rapides, non bloquants  
- **Modularité** : compatible avec tous les modules actuels et futurs  
- **Sécurité** : sandbox interne, aucun impact sur les joueurs réels  
- **Durabilité** : conçu pour évoluer avec le framework  

