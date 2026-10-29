#!/usr/bin/env bash
# scripts/agents/boucle.sh — enchaîne les tâches du backlog, une session Claude Code headless par tâche.
#   MAX=5 ./scripts/agents/boucle.sh        (5 tâches au plus)
# Arrêt propre : créer un fichier STOP à la racine (pris en compte entre deux tâches).
# Chaque tâche : branche agents/T-xxx depuis agents/integration → session → verifier.sh → fusion si OK.
# main n'est jamais touchée.
set -euo pipefail
cd "$(dirname "$0")/../.."

MAX="${MAX:-5}"
TOURS="${TOURS:-80}"            # tours maximum par session
INTEGRATION="agents/integration"
OUTILS='Read,Grep,Glob,Edit,Write,Task,Agent,TodoWrite,Bash(./scripts/verifier.sh:*),Bash(./scripts/audit-reseau.sh:*),Bash(luacheck:*),Bash(busted:*),Bash(git status:*),Bash(git diff:*),Bash(git log:*),Bash(git add:*),Bash(git commit:*),Bash(grep:*),Bash(du:*),Bash(ls:*),Bash(mkdir:*)'
mkdir -p .agents/journaux

journal() { printf '[%s] %s\n' "$(date '+%F %T')" "$*" | tee -a .agents/journaux/boucle.log; }

if [[ -n "$(git status --porcelain --untracked-files=no)" ]]; then
    journal "arbre de travail non propre : committer ou ranger avant de lancer la boucle"; exit 1
fi
git rev-parse --verify -q "$INTEGRATION" >/dev/null || git branch "$INTEGRATION" main

for ((n = 1; n <= MAX; n++)); do
    [[ -f STOP ]] && { journal "fichier STOP présent : arrêt"; break; }

    git checkout -q "$INTEGRATION"
    tmp="agents/en-cours-$(date +%s)"
    git checkout -q -b "$tmp"
    rm -f .agents/tache-courante

    journal "session $n/$MAX sur $tmp"
    claude -p "$(cat scripts/agents/prompt-tache.md)" \
        --permission-mode acceptEdits \
        --allowedTools "$OUTILS" \
        --max-turns "$TOURS" \
        --output-format json > ".agents/journaux/session-$(date +%Y%m%d-%H%M%S).json" || journal "session terminée avec une erreur"

    tache="$(cat .agents/tache-courante 2>/dev/null || echo '')"
    if [[ "$tache" == "AUCUNE_TACHE_ELIGIBLE" || -z "$tache" ]]; then
        journal "aucune tâche éligible (ou session vide) : arrêt — à toi de tester et valider"
        git checkout -q "$INTEGRATION"; git branch -q -D "$tmp"; break
    fi
    git branch -q -m "$tmp" "agents/$tache"

    # deuxième chance : une session de correction si la vérification échoue
    if ! ./scripts/verifier.sh > ".agents/journaux/verif-$tache.txt" 2>&1; then
        journal "$tache : vérification en échec, session de correction"
        claude -p "La vérification de la tâche $tache échoue. Lis CLAUDE.md, puis .agents/journaux/verif-$tache.txt. Corrige sans affaiblir aucun test ni règle, relance ./scripts/verifier.sh jusqu'à ce qu'il passe, puis commit." \
            --permission-mode acceptEdits --allowedTools "$OUTILS" --max-turns 40 \
            --output-format json > ".agents/journaux/correction-$tache.json" || true
    fi

    if ./scripts/verifier.sh > ".agents/journaux/verif-$tache.txt" 2>&1 && [[ -z "$(git status --porcelain --untracked-files=no)" ]]; then
        git checkout -q "$INTEGRATION"
        git merge -q --no-ff "agents/$tache" -m "Intégration $tache"
        journal "$tache : vérifiée et intégrée dans $INTEGRATION"
    else
        git add -A && git commit -qm "$tache : travail en cours (vérification en échec)" || true
        git checkout -q "$INTEGRATION"
        sed -i "/^### $tache /,/^### /{s/Statut : [^·]*\$/Statut : bloquée/;/Statut : bloquée/a\\- Blocage : vérification en échec, voir la branche agents/$tache et .agents/journaux/verif-$tache.txt
}" docs/plan/BACKLOG.md
        git add docs/plan/BACKLOG.md && git commit -qm "$tache : bloquée (vérification en échec)" || true
        journal "$tache : bloquée, branche agents/$tache gardée pour revue"
    fi
done
journal "fin de la boucle"
