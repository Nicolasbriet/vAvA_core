# 🔧 Corrections et Tests - Module Concess

> **Date:** 9 janvier 2026  
> **Problèmes résolus:** Interface qui ne s'ouvre pas + logos manquants

---

## ✅ Corrections Appliquées

### 1. **Dossier img/ créé**
- Création de `html/img/` (manquant)
- Ajout de `default.svg` (logo par défaut)
- Le manifest référençait ce dossier mais il n'existait pas

### 2. **Images par défaut**
- Modification de `html/js/app.js`
- Utilisation de `img/default.svg` si aucune image
- Fallback automatique en cas d'erreur de chargement

### 3. **Commande de test ajoutée**
- Nouvelle commande: `/testconcess [id]`
- Permet d'ouvrir le concess sans se déplacer
- IDs disponibles listés si erreur

---

## 🎮 Comment Tester

### Méthode 1: Commande de test (Recommandée)
```
/testconcess
/testconcess cars_civilian
/testconcess cars_job
/testconcess boats
```

### Méthode 2: Se déplacer aux marqueurs
Téléportations possibles:
```lua
-- Concess voitures civiles
/tp -56.79 -1096.67 27.44

-- Concess voitures job
/tp -31.83 -1110.47 27.42

-- Concess bateaux
/tp -737.11 -1333.98 1.6

-- Concess hélicoptères
/tp -1144.53 -2864.01 13.95

-- Concess avions
/tp -1144.53 -2864.01 13.95
```

Ensuite appuyez sur **E** sur le marqueur.

---

## 🐛 Si l'Interface ne S'Ouvre Toujours Pas

### Vérifications à faire:

1. **Console F8** - Vérifier les erreurs JavaScript
2. **Serveur** - Vérifier les logs serveur
3. **Base de données** - Table `vehicles` existe ?

### Commande de diagnostic:
```
/fixcam  -- Reset caméra et interface
```

### Debug serveur:
Vérifier que le serveur répond à l'event:
```lua
RegisterNetEvent('vcore_concess:requestVehicles')
```

---

## 📦 Ajout de Véhicules

### Option 1: Fichier vehicles.json
Créer/modifier `vehicles.json`:
```json
{
  "adder": {
    "name": "Adder",
    "category": "super",
    "price": 1000000,
    "stock": 5,
    "image": "img/adder.png"
  }
}
```

### Option 2: Base de données
Insérer dans la table `vehicles`:
```sql
INSERT INTO vehicles (model, name, category, price, stock, vehicleType, isJobOnly)
VALUES ('adder', 'Adder', 'super', 1000000, 5, 'cars', 0);
```

---

## 🖼️ Ajout de Logos Personnalisés

1. **Placer les images** dans `html/img/`
   - Format: PNG ou SVG recommandé
   - Nom: `{model}.png` (ex: `adder.png`)
   - Dimensions: 300x200px recommandé

2. **Ou spécifier dans vehicles.json**:
```json
{
  "adder": {
    "image": "img/adder.png"
  }
}
```

3. **Si pas d'image** → `default.svg` sera utilisé automatiquement

---

## 🧪 Tests à Effectuer

- [ ] `/testconcess` ouvre l'interface
- [ ] Les véhicules s'affichent
- [ ] Le logo par défaut apparaît
- [ ] Recherche fonctionne
- [ ] Tri par prix fonctionne
- [ ] Sélection d'un véhicule
- [ ] Rotation du véhicule (flèches)
- [ ] Achat d'un véhicule
- [ ] Fermeture avec ESC

---

## 📝 Checklist Problèmes Courants

| Problème | Solution |
|----------|----------|
| Interface ne s'ouvre pas | `/fixcam` puis réessayer |
| Pas de véhicules | Vérifier table `vehicles` en BDD |
| Logos manquants | Normal, utilise `default.svg` |
| Caméra bloquée | `/fixcam` |
| NUI freeze | F8 → vérifier erreurs JS |
| Achat ne fonctionne pas | Vérifier argent du joueur |

---

## 🔄 Si Tout Échoue

**Reset complet:**
```
1. /fixcam
2. Restart vAvA_core
3. /testconcess
```

**Vérifier dépendances:**
- vAvA_core démarré ?
- oxmysql connecté ?
- Tables BDD créées ?

---

*Module Concess - vAvA Core v1.1.0*
