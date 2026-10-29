#!/usr/bin/env bash
# scripts/audit-reseau.sh — garde-fous statiques (motifs interdits). Ne remplace pas la relecture des agents.
# Usage : audit-reseau.sh [fichiers…]  (sans argument : tout le dépôt)
set -uo pipefail
cd "$(dirname "$0")/.."

if [[ $# -gt 0 ]]; then fichiers=("$@"); else mapfile -t fichiers < <(git ls-files); fi
lua=(); web=()
for f in "${fichiers[@]}"; do
    [[ -f "$f" ]] || continue
    case "$f" in
        chancellerie/*|tests/*|examples/*) ;;
        *.lua) lua+=("$f") ;;
        */web/*.js|*/web/*.html) web+=("$f") ;;
    esac
done

# Exceptions justifiées : scripts/audit-exceptions.txt, une par ligne « chemin<TAB>extrait exact de la ligne<TAB>raison »
EXCEPTIONS="scripts/audit-exceptions.txt"
filtrer() { # retire les commentaires Lua et les lignes couvertes par une exception ou marquées « audit: ok »
    local ligne contenu chemin extrait garde
    while IFS= read -r ligne; do
        [[ -z "$ligne" || "$ligne" == *"audit: ok"* ]] && continue
        contenu="${ligne#*:}"; contenu="${contenu#*:}"   # « chemin:ligne:contenu » (grep -H)
        [[ "$contenu" =~ ^[[:space:]]*-- ]] && continue
        garde=1
        if [[ -f "$EXCEPTIONS" ]]; then
            while IFS=$'\t' read -r chemin extrait _; do
                extrait="${extrait%$'\r'}"   # fichier d'exceptions extrait en CRLF sous Windows
                [[ -z "$chemin" || "$chemin" == \#* ]] && continue
                if [[ "$ligne" == "$chemin:"* && "$ligne" == *"$extrait"* ]]; then garde=0; break; fi
            done < "$EXCEPTIONS"
        fi
        [[ $garde -eq 1 ]] && printf '%s\n' "$ligne"
    done
}

bloquant=0; avert=0
signal() { # niveau motif message
    local niveau="$1" motif="$2" message="$3" res
    [[ ${#lua[@]} -eq 0 ]] && return
    res=$(grep -HnE "$motif" "${lua[@]}" 2>/dev/null | filtrer || true)
    [[ -z "$res" ]] && return
    echo "[$niveau] $message"; echo "$res" | sed 's/^/    /'
    if [[ "$niveau" == BLOQUANT ]]; then bloquant=1; else avert=1; fi
}

signal BLOQUANT 'TriggerClientEvent\([^,]+,[[:space:]]*-1[[:space:]]*[,)]' "broadcast à tous les joueurs (cibler les joueurs concernés)"
signal BLOQUANT 'TriggerLatentClientEvent\([^,]+,[[:space:]]*-1[[:space:]]*[,)]' "broadcast latent à tous les joueurs"
signal BLOQUANT '(query|single|scalar|insert|update|execute|prepare)[A-Za-z]*\([[:space:]]*[^,]*\.\.' "SQL construit par concaténation (utiliser ?)"
signal BLOQUANT 'loadstring\(|[=(,][[:space:]]*load\([[:space:]]*["'"'"'a-z_]+[^)]*\)\(\)' "exécution de code dynamique"
lua_sans_chancellerie=(); for f in "${lua[@]}"; do [[ "$f" == modules/vava_chancellerie/* ]] || lua_sans_chancellerie+=("$f"); done
if [[ ${#lua_sans_chancellerie[@]} -gt 0 ]]; then
    res=$(grep -HnE 'PerformHttpRequest\(' "${lua_sans_chancellerie[@]}" 2>/dev/null | filtrer || true)
    if [[ -n "$res" ]]; then echo "[BLOQUANT] requête HTTP sortante depuis un module de jeu"; echo "$res" | sed 's/^/    /'; bloquant=1; fi
fi

# RegisterNetEvent serveur hors du core RPC (exceptions connues listées ici)
mapfile -t srv < <(printf '%s\n' "${lua[@]}" | grep -E '(^|/)server/|/bridge/server' | grep -vE '^server/core/rpc\.lua$|^modules/vava_chat/server/compat\.lua$' || true)
if [[ ${#srv[@]} -gt 0 ]]; then
    res=$(grep -HnE '^\s*RegisterNetEvent\(|[^.]RegisterNetEvent\([^)]' "${srv[@]}" 2>/dev/null | grep -vE 'local RegisterNetEvent' | filtrer || true)
    if [[ -n "$res" ]]; then echo "[BLOQUANT] évènement réseau serveur hors core.rpc.register"; echo "$res" | sed 's/^/    /'; bloquant=1; fi
fi

signal AVERTISSEMENT 'GlobalState\[[^]]+\][[:space:]]*=' "écriture GlobalState (envoyée à TOUS les joueurs : petite, rare, utile à tous ?)"
signal AVERTISSEMENT 'Wait\(0\)' "Wait(0) : uniquement pendant un état actif temporaire"
signal AVERTISSEMENT 'GetGamePool' "GetGamePool : à éviter dans une boucle"

if [[ ${#web[@]} -gt 0 ]]; then
    res=$(grep -HnE 'https?://' "${web[@]}" 2>/dev/null | grep -vE 'xmlns|w3\.org|nui://|https://cfx-nui-|https://\$\{' | filtrer || true)
    if [[ -n "$res" ]]; then echo "[BLOQUANT] ressource externe dans une interface"; echo "$res" | sed 's/^/    /'; bloquant=1; fi
    res=$(grep -HnE '\.innerHTML[[:space:]]*\+?=' "${web[@]}" 2>/dev/null | filtrer || true)
    if [[ -n "$res" ]]; then echo "[AVERTISSEMENT] innerHTML : jamais avec une donnée venant d'un joueur (marquer '// audit: ok' si sûr)"; echo "$res" | sed 's/^/    /'; avert=1; fi
fi

# poids de l'écran de chargement
if [[ -d modules/vava_loading ]]; then
    poids=$(du -sb modules/vava_loading | cut -f1)
    if (( poids > 1572864 )); then echo "[BLOQUANT] vava_loading pèse $poids octets (> 1,5 Mo)"; bloquant=1
    else echo "vava_loading : $poids octets (≤ 1,5 Mo)"; fi
fi

if [[ $bloquant -eq 1 ]]; then echo "AUDIT : BLOQUANT"; exit 1; fi
if [[ $avert -eq 1 ]]; then echo "AUDIT : OK avec avertissements (à justifier dans le rapport de tâche)"; else echo "AUDIT : OK"; fi
exit 0
