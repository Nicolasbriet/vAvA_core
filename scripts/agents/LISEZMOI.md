# Faire travailler les agents en continu

## Une fois

1. Installer Claude Code et s'y connecter (voir la documentation officielle de Claude Code).
2. Installer les outils de vérification :
   ```bash
   # Linux (ou WSL)
   sudo apt install lua5.4 liblua5.4-dev luarocks
   luarocks --lua-version 5.4 install luacheck
   luarocks --lua-version 5.4 install busted
   # Windows (Git Bash, Visual Studio Build Tools avec les outils C++), sans droits d'administrateur :
   ./scripts/outils-windows.sh     # Lua 5.4, luacheck et busted dans .outils/, que verifier.sh trouve seul
   ```
3. Vérifier que tout est en place : `./scripts/verifier.sh --tout` (il échoue sur les avertissements luacheck de
   base, 14 au 29 octobre 2026, tant que T-001 n'est pas faite : c'est normal).
4. `.agents/`, `STOP` et `.outils/` sont déjà dans le `.gitignore`.

## Deux façons de travailler

**Accompagnée (conseillée au début)** : lancer `claude` dans le dossier du dépôt et dire « prends la prochaine tâche
éligible du backlog ». Tu vois chaque étape, tu corriges le tir, tu apprends comment les agents se comportent.

**En continu** : `MAX=5 ./scripts/agents/boucle.sh`. Chaque tâche a sa session neuve, sa branche `agents/T-xxx`,
et n'est fusionnée dans `agents/integration` que si `verifier.sh` passe. La boucle s'arrête seule quand plus aucune
tâche n'est éligible (en général : une porte de phase t'attend). Pour l'arrêter plus tôt : `touch STOP`.

Les sessions headless acceptent les modifications de fichiers et n'ont accès qu'à une liste d'outils fermée
(lecture, écriture, git sans push, scripts de vérification). Lancer la boucle dans une copie du dépôt dédiée ou un
conteneur reste plus prudent.

## Après une boucle

1. Lire `docs/plan/rapports/` et `.agents/journaux/boucle.log`.
2. Pour chaque tâche « à tester en jeu » : la tester avec sa procédure de `docs/tests/`, puis la passer à
   `validée` ou ajouter une tâche de correction.
3. Revue de `agents/integration` (`git log main..agents/integration`), puis fusion dans `main` quand une phase est
   propre ; la Chancellerie propose la mise à jour au serveur de test.
4. Les tâches `bloquée` contiennent la raison : trancher la décision, remettre `à faire`.

## Coût

Chaque session consomme ton quota ou ton budget Claude Code ; `TOURS` (80 par défaut) borne une session.
Commence avec `MAX=1` ou `MAX=2` pour voir la consommation réelle d'une tâche avant d'augmenter.
