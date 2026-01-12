# Guide de Test des Commandes d'Argent vAvA_core

## Installation

1. Redémarrer le serveur ou faire un `refresh` et `restart vAvA_core`
2. Les nouvelles commandes seront automatiquement disponibles

## Commandes Disponibles

### `/givemoney [id] [type] [montant]`
- **Description**: Donner de l'argent à un joueur
- **Types**: `cash`, `bank`, `black_money`
- **Exemple**: `/givemoney 1 cash 5000`

### `/removemoney [id] [type] [montant]`
- **Description**: Retirer de l'argent à un joueur
- **Types**: `cash`, `bank`, `black_money`
- **Exemple**: `/removemoney 1 bank 2000`

### `/setmoney [id] [type] [montant]`
- **Description**: Définir le montant exact d'argent d'un joueur
- **Types**: `cash`, `bank`, `black_money`
- **Exemple**: `/setmoney 1 cash 10000`

### `/checkmoney [id]`
- **Description**: Vérifier l'argent d'un joueur (optionnel: sans ID = soi-même)
- **Exemple**: `/checkmoney 1` ou `/checkmoney`

### `/debugmoney [id]`
- **Description**: Debug complet du système d'argent (console + notification)
- **Exemple**: `/debugmoney 1`

## Tests Recommandés

### Test 1: Vérification initiale
```
/checkmoney
```
Vérifie votre argent actuel

### Test 2: Ajout d'argent
```
/givemoney 1 cash 5000
/checkmoney 1
```

### Test 3: Retrait d'argent
```
/removemoney 1 cash 2000
/checkmoney 1
```

### Test 4: Définition exacte
```
/setmoney 1 bank 50000
/checkmoney 1
```

### Test 5: Debug complet
```
/debugmoney 1
```
Affiche les détails techniques dans la console

## Permissions Requises

Les commandes nécessitent les permissions admin suivantes:
- `command.givemoney`
- `command.removemoney`
- `command.setmoney`
- `command.checkmoney`

Ces permissions sont vérifiées via le système ACE de txAdmin ou les groupes vAvA_core.

## Intégration avec le Concessionnaire

Le système d'argent est déjà intégré avec le concessionnaire:
- Achat de véhicules utilise `vCore.RemovePlayerMoney()`
- Affichage des prix avec taxes dans l'interface
- Vérification automatique des fonds disponibles

## Logs

Toutes les opérations d'argent sont loggées automatiquement:
- Nom de l'admin qui effectue l'action
- Joueur cible
- Type d'argent modifié
- Montant
- Horodatage

## Troubleshooting

Si les commandes ne fonctionnent pas:
1. Vérifiez les permissions dans txAdmin
2. Utilisez `/debugmoney` pour diagnostiquer
3. Vérifiez les logs du serveur
4. Testez avec la console serveur (permissions automatiques)

## Script de Test Automatique

Un script de test est disponible:
```
exec test_money_commands.lua
```
Affiche l'état du système et la liste des joueurs avec leur argent.