Tu travailles en autonomie sur vAvA_core (serveur FiveM Eldoria). Personne ne répondra à tes questions pendant
cette session : décide, documente tes décisions, avance.

1. Lis `CLAUDE.md`, puis `docs/plan/BACKLOG.md` (ses règles en tête).
2. Choisis la PREMIÈRE tâche éligible selon ces règles. S'il n'y en a aucune, écris exactement
   `AUCUNE_TACHE_ELIGIBLE` dans `.agents/tache-courante` et arrête-toi.
3. Écris son identifiant seul (ex. `T-030`) dans `.agents/tache-courante`. Passe son statut à `en cours`.
4. Réalise-la en suivant « Façon de travailler » de `CLAUDE.md` : spec par `vava-architecte` si c'est un nouveau
   système, implémentation par l'agent indiqué, `./scripts/verifier.sh` jusqu'à ce qu'il passe, relectures
   `vava-securite` et `vava-reseau-perf` (et `vava-gardien-lore` si des règles ou des textes changent), corrections.
5. Mets à jour la doc, la version du module et le backlog (statut `à tester en jeu`, ou `bloquée` avec une ligne
   `Blocage :` si tu ne peux pas aboutir sans décision humaine).
6. Écris un rapport court dans `docs/plan/rapports/<ID>.md` : ce qui a été fait, fichiers, RPC et évènements ajoutés
   avec leur cible, verdicts des relectures, avertissements d'audit justifiés, décisions à confirmer, ce qu'il faut
   tester en jeu.
7. Commit avec un message au format du dépôt (`vava_xxx 1.2.0 : …`). Ne pousse rien, ne change pas de branche.

Une seule tâche par session. Ne touche à rien hors de son périmètre.
