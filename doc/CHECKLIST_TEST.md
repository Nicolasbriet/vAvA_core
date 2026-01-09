# ✅ CHECKLIST DE TEST - vAvA_core v3.0.0

> Utilisez cette checklist pour valider que toutes les intégrations fonctionnent correctement.

---

## 🔧 PRÉPARATION

- [ ] Serveur redémarré avec dernière version
- [ ] `vAvA_economy` est démarré avant `vAvA_core`
- [ ] Base de données `economy_system.sql` exécutée
- [ ] Aucune erreur dans les logs au démarrage

---

## 1️⃣ MODULE ECONOMY - CORE

### Démarrage
- [ ] Economy module démarre sans erreur
- [ ] Dashboard ouvrable avec `/economy` ou `F10`
- [ ] Données affichées correctement (inflation, multiplicateur, items, jobs)

### Fonctions de base
- [ ] Commande `/economy` fonctionne
- [ ] Onglets du dashboard fonctionnels (Overview, Items, Jobs, Taxes, Logs)
- [ ] Bouton "Recalculer" fonctionne (cooldown 1h)
- [ ] Modifications sauvegardées en base de données

---

## 2️⃣ MODULE INVENTORY - INTÉGRATION ECONOMY

### Achats avec Economy
- [ ] Event `buyItem` fonctionne
- [ ] Prix calculé via economy (ou fallback si désactivé)
- [ ] Taxe appliquée correctement
- [ ] Transaction enregistrée dans economy
- [ ] Notification affiche le prix correct
- [ ] Item ajouté dans l'inventaire

### Ventes avec Economy
- [ ] Event `sellItem` fonctionne
- [ ] Prix à 75% du prix d'achat
- [ ] Taxe appliquée
- [ ] Transaction enregistrée
- [ ] Argent ajouté au joueur
- [ ] Item retiré de l'inventaire

### Interface Admin
- [ ] Commande `/invadmin` accessible (admin uniquement)
- [ ] Panel s'ouvre correctement
- [ ] **Onglet Items:**
  - [ ] Liste des items affichée
  - [ ] Recherche fonctionne
  - [ ] Bouton "Créer" ouvre le modal
  - [ ] Création d'item fonctionne (sauvegarde BDD + cache)
  - [ ] Modification d'item fonctionne
  - [ ] Suppression d'item fonctionne
- [ ] **Onglet Joueurs:**
  - [ ] Liste des joueurs en ligne
  - [ ] Stats affichées (items, poids)
  - [ ] Clic sur joueur ouvre son inventaire
- [ ] **Onglet Logs:**
  - [ ] Logs affichés (si disponibles)
  - [ ] Filtres fonctionnent
- [ ] Fermeture avec ESC ou bouton X
- [ ] NUI Focus retiré après fermeture

---

## 3️⃣ MODULE JOBS - INTÉGRATION ECONOMY

### Salaires Dynamiques
- [ ] Commande `/salary` affiche le bon salaire
- [ ] Salaire calculé via economy (ou fallback)
- [ ] Taxe appliquée sur le salaire (affichée)
- [ ] Grade bonus pris en compte

### Auto-Paie
- [ ] Thread auto-paie actif (vérifier logs après 30min)
- [ ] Salaires versés uniquement aux joueurs "on duty"
- [ ] Notification reçue lors du paiement
- [ ] Argent ajouté à la banque du joueur
- [ ] Transaction enregistrée dans economy
- [ ] Log créé pour le paiement

### Commande Admin
- [ ] `/paysalary [id]` fonctionne (admin)
- [ ] Salaire versé immédiatement
- [ ] Notification pour admin et joueur
- [ ] Log dans console

---

## 4️⃣ MODULE CONCESS - INTÉGRATION ECONOMY

### Achat Véhicules
- [ ] Ouvrir concessionnaire fonctionne
- [ ] Liste véhicules affichée
- [ ] Sélection véhicule + couleurs fonctionne
- [ ] Prix calculé via economy (+ taxe 20%)
- [ ] Prix total affiché dans notification
- [ ] Paiement cash OU banque fonctionne
- [ ] Argent retiré du joueur
- [ ] Véhicule spawné avec plaque unique
- [ ] Véhicule enregistré en BDD
- [ ] Clés données automatiquement
- [ ] Transaction enregistrée dans economy

### Fallback
- [ ] Si economy désactivé, prix de `vehicles.json` utilisé
- [ ] Achat fonctionne quand même

---

## 5️⃣ MODULE GARAGE - INTÉGRATION ECONOMY

### Fourrière
- [ ] Ouvrir fourrière avec ox_target (job police)
- [ ] Liste véhicules en fourrière affichée
- [ ] Sélection véhicule fonctionne
- [ ] Prix fourrière calculé via economy (+ taxe)
- [ ] Prix affiché dans notification
- [ ] Paiement cash OU banque fonctionne
- [ ] Argent retiré du joueur
- [ ] Véhicule spawné
- [ ] Véhicule retiré de fourrière (BDD)
- [ ] Transaction enregistrée dans economy

### Fallback
- [ ] Si economy désactivé, prix de config utilisé
- [ ] Fourrière fonctionne quand même

---

## 6️⃣ MODULE JOBSHOP - INTÉGRATION ECONOMY

### Achats Boutique Job
- [ ] Ouvrir boutique job fonctionne
- [ ] Liste items affichée avec stock
- [ ] Sélection item + quantité fonctionne
- [ ] Prix calculé via economy (base × shop multiplier + taxe)
- [ ] Prix total affiché dans notification
- [ ] Paiement fonctionne (cash/banque selon config)
- [ ] Argent retiré du joueur
- [ ] Item ajouté à l'inventaire
- [ ] Stock diminué en BDD
- [ ] Caisse boutique augmentée
- [ ] Transaction enregistrée dans economy

### Fallback
- [ ] Si economy désactivé, prix BDD utilisé
- [ ] Achat fonctionne quand même

---

## 7️⃣ SYSTÈME DE FALLBACK

### Test Economy Désactivé
- [ ] Stopper `vAvA_economy`
- [ ] Restart `vAvA_core`
- [ ] Messages "economy non trouvé" dans console
- [ ] **Inventory:** Prix fixes utilisés (bread=5, water=3, etc.)
- [ ] **Jobs:** Salaires fixes utilisés (police=500, etc.)
- [ ] **Concess:** Prix vehicles.json utilisés
- [ ] **Garage:** Prix config utilisés
- [ ] **JobShop:** Prix BDD utilisés
- [ ] Tout fonctionne sans erreur

### Test Economy Activé
- [ ] Redémarrer `vAvA_economy`
- [ ] Restart `vAvA_core`
- [ ] Messages "economy détecté et activé" dans console
- [ ] Prix dynamiques utilisés partout
- [ ] Taxes appliquées
- [ ] Transactions enregistrées

---

## 8️⃣ LOGS ET MONITORING

### Logs Economy
- [ ] Dashboard economy → onglet Logs
- [ ] Transactions visibles (achat, vente, salaire)
- [ ] Détails corrects (joueur, item, montant, date)
- [ ] Filtre par type fonctionne

### Logs Serveur
- [ ] Aucune erreur Lua dans F8
- [ ] Messages de démarrage corrects
- [ ] Transactions loguées en console (si debug activé)

---

## 9️⃣ PERFORMANCE

### Charge Serveur
- [ ] Pas de freeze lors utilisation inventory
- [ ] Pas de freeze lors achat véhicule
- [ ] Dashboard economy réactif
- [ ] Admin panel inventory fluide
- [ ] Auto-paie ne cause pas de lag

### Base de Données
- [ ] Requêtes async (pas de blocage)
- [ ] Cache utilisé correctement
- [ ] Pas de doublons dans BDD
- [ ] Transactions sauvegardées

---

## 🔟 INTÉGRITÉ DES DONNÉES

### Base de Données
- [ ] Table `economy_state` contient données
- [ ] Table `economy_items` contient items (50+)
- [ ] Table `economy_jobs` contient jobs (8)
- [ ] Table `economy_transactions` enregistre transactions
- [ ] Table `economy_logs` contient historique
- [ ] Table `inventory_items` contient items
- [ ] Table `player_inventories` sauvegarde inventaires
- [ ] Table `player_hotbar` sauvegarde raccourcis

### Cache Mémoire
- [ ] Items chargés en cache au démarrage
- [ ] Inventaires chargés au login joueur
- [ ] Hotbar chargée au login joueur
- [ ] Cache synchronisé avec BDD

---

## ✅ RÉSULTAT FINAL

**Date du test:** _____________

**Testeur:** _____________

**Nombre de tests réussis:** _____ / 90

**Problèmes rencontrés:**
- _______________________________
- _______________________________
- _______________________________

**Notes:**
_______________________________
_______________________________
_______________________________

---

## 🚀 STATUT

- [ ] ✅ **TOUS LES TESTS PASSÉS** - Production Ready
- [ ] ⚠️ **TESTS PARTIELS** - Corrections nécessaires
- [ ] ❌ **ÉCHEC** - Debug requis

---

## 📝 SIGNATURES

**Développeur:** _____________  
**Date:** _____________

**Validateur:** _____________  
**Date:** _____________

---

**Version testée:** 3.0.0  
**Date de création checklist:** 9 Janvier 2026
