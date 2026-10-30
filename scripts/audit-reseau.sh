#!/usr/bin/env bash
# scripts/audit-reseau.sh — garde-fous statiques (motifs interdits). Ne remplace pas la relecture des agents.
# Usage : audit-reseau.sh [fichiers…]  (sans argument : tout le dépôt)
#         audit-reseau.sh --essai      contrôles Lua lancés sur les cas écrits de tests/audit/*.lua (avec
#                                      tests/audit/exceptions.txt), comparés à ce que chaque ligne attend en fin de
#                                      ligne (« -- attendu: BLOQUANT | AVERTISSEMENT | rien ») ; code 1 au moindre écart
set -uo pipefail
cd "$(dirname "$0")/.."

ESSAI=0
if [[ "${1:-}" == "--essai" ]]; then ESSAI=1; shift; fi

# Exceptions justifiées : une par ligne « chemin<TAB>extrait exact de la ligne<TAB>raison »
EXCEPTIONS="scripts/audit-exceptions.txt"
lua=(); web=()
if [[ $ESSAI -eq 1 ]]; then
    EXCEPTIONS="tests/audit/exceptions.txt"
    for f in tests/audit/*.lua; do [[ -f "$f" ]] && lua+=("$f"); done
else
    if [[ $# -gt 0 ]]; then fichiers=("$@"); else mapfile -t fichiers < <(git ls-files); fi
    for f in "${fichiers[@]}"; do
        [[ -f "$f" ]] || continue
        case "$f" in
            chancellerie/*|tests/*|examples/*) ;;
            *.lua) lua+=("$f") ;;
            */web/*.js|*/web/*.html) web+=("$f") ;;
        esac
    done
fi

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

# Constats rangés avant d'être écrits : « NIVEAU<TAB>chemin:ligne » (pour l'essai), puis la sortie habituelle.
constats=()
bloquant=0; avert=0
noter() { # niveau message résultat (lignes « chemin:ligne:contenu », déjà filtrées)
    local niveau="$1" message="$2" res="$3" ligne chemin reste
    [[ -z "$res" ]] && return
    while IFS= read -r ligne; do
        [[ -z "$ligne" ]] && continue
        chemin="${ligne%%:*}"; reste="${ligne#*:}"
        constats+=("$niveau"$'\t'"$chemin:${reste%%:*}")
    done <<< "$res"
    if [[ $ESSAI -eq 0 ]]; then echo "[$niveau] $message"; echo "$res" | sed 's/^/    /'; fi
    if [[ "$niveau" == BLOQUANT ]]; then bloquant=1; else avert=1; fi
}

signal() { # niveau motif message
    local niveau="$1" motif="$2" message="$3" res
    [[ ${#lua[@]} -eq 0 ]] && return
    res=$(grep -HnE "$motif" "${lua[@]}" 2>/dev/null | filtrer || true)
    noter "$niveau" "$message" "$res"
}

signal BLOQUANT 'TriggerClientEvent\([^,]+,[[:space:]]*-1[[:space:]]*[,)]' "broadcast à tous les joueurs (cibler les joueurs concernés)"
signal BLOQUANT 'TriggerLatentClientEvent\([^,]+,[[:space:]]*-1[[:space:]]*[,)]' "broadcast latent à tous les joueurs"

# Envois à tous déguisés, en une passe awk par lot de fichiers (mawk et gawk). Sortie : « contrôle<TAB>niveau<TAB>
# chemin:ligne:contenu ».
#  C — constante valant -1 en cible : noms posés à -1 dans le fichier (`local NOM = -1`, `A.B = -1`, nom pris en dernier
#      composant), puis `Trigger(Latent)?ClientEvent(évènement, NOM…` dont la cible finit par l'un d'eux. Limite connue :
#      une constante d'un autre fichier n'est pas vue (core.net refuse -1 à l'exécution pour ce qui passe par lui).
#  B — boucle sur tous les joueurs qui envoie : en-tête `for … GetPlayers( | GetActivePlayers( | sessions.all( |
#      players.all( | ActivePlayers(` ou `forEach…Active(` ; corps jusqu'au premier `end` d'indentation au plus celle
#      de l'en-tête (ou la même ligne) ; un envoi (`Trigger(Latent)?ClientEvent(`, `net.send(`, `net.sendWith(`, pas
#      sendNear) est BLOQUANT si aucun `if` ne le précède dans la boucle, AVERTISSEMENT sinon.
DEGUISES_AWK='
function sendPos(s) {
    if (match(s, /Trigger(Latent)?ClientEvent[ \t]*\(|net\.send(With)?[ \t]*\(/)) return RSTART
    return 0
}
function hasIf(s) { return s ~ /(^|[^A-Za-z0-9_])if([^A-Za-z0-9_]|$)/ }
function hasEnd(s) { return s ~ /(^|[^A-Za-z0-9_])end([^A-Za-z0-9_]|$)/ }
function comment(s) { return s ~ /^[ \t]*--/ }
function process(file, n,    i, j, l, b, name, rest, m, target, indent, p, seenIf) {
    split("", minus)
    for (i = 1; i <= n; i++) {
        l = lines[i]
        if (comment(l)) continue
        if (l ~ /^[ \t]*local[ \t]+[A-Za-z_][A-Za-z0-9_]*[ \t]*=[ \t]*-1[ \t]*(--.*)?$/) {
            name = l; sub(/^[ \t]*local[ \t]+/, "", name); sub(/[ \t]*=.*$/, "", name); minus[name] = 1
        } else if (l ~ /^[ \t]*[A-Za-z_][A-Za-z0-9_]*(\.[A-Za-z_][A-Za-z0-9_]*)+[ \t]*=[ \t]*-1[ \t]*(--.*)?$/) {
            name = l; sub(/[ \t]*=.*$/, "", name); sub(/^.*\./, "", name); sub(/^[ \t]*/, "", name); minus[name] = 1
        }
    }
    for (i = 1; i <= n; i++) {
        l = lines[i]
        if (comment(l)) continue
        rest = l
        while (match(rest, /Trigger(Latent)?ClientEvent\([^,]+,[ \t]*[A-Za-z_][A-Za-z0-9_.]*[ \t]*[,)]/)) {
            m = substr(rest, RSTART, RLENGTH)
            rest = substr(rest, RSTART + RLENGTH)
            target = m; sub(/^[^,]*,[ \t]*/, "", target); sub(/[ \t]*[,)]$/, "", target); sub(/^.*\./, "", target)
            if (target in minus) { print "C\tBLOQUANT\t" file ":" i ":" l; break }
        }
    }
    for (i = 1; i <= n; i++) {
        l = lines[i]
        if (comment(l)) continue
        if (!(l ~ /^[ \t]*for[ \t].*(GetPlayers|GetActivePlayers|sessions\.all|players\.all|ActivePlayers)[ \t]*\(/) &&
            !(l ~ /forEach[A-Za-z]*Active[ \t]*\(/)) continue
        match(l, /^[ \t]*/); indent = RLENGTH
        p = sendPos(l)
        if (p > 0) print "B\t" (hasIf(substr(l, 1, p - 1)) ? "AVERTISSEMENT" : "BLOQUANT") "\t" file ":" i ":" l
        if (hasEnd(l)) continue
        seenIf = 0
        for (j = i + 1; j <= n; j++) {
            b = lines[j]
            if (comment(b)) continue
            match(b, /^[ \t]*/)
            if (RLENGTH <= indent && b ~ /^[ \t]*end([^A-Za-z0-9_]|$)/) break
            p = sendPos(b)
            if (p > 0) {
                print "B\t" ((seenIf || hasIf(substr(b, 1, p - 1))) ? "AVERTISSEMENT" : "BLOQUANT") "\t" file ":" j ":" b
            }
            if (hasIf(b)) seenIf = 1
        }
    }
}
FNR == 1 && NR > 1 { process(current, count) }
FNR == 1 { current = FILENAME; count = 0; split("", lines) }
{ sub(/\r$/, ""); lines[++count] = $0 }
END { if (NR > 0) process(current, count) }
'
if [[ ${#lua[@]} -gt 0 ]]; then
    deguises=$(awk "$DEGUISES_AWK" "${lua[@]}" 2>/dev/null || true)
    noter BLOQUANT "envoi à tous par une constante valant -1 (cibler les joueurs concernés)" \
        "$(printf '%s\n' "$deguises" | sed -n $'s/^C\tBLOQUANT\t//p' | filtrer || true)"
    noter BLOQUANT "boucle sur tous les joueurs qui envoie sans filtre (core.net.sendNear, une liste, ou les abonnements de zone)" \
        "$(printf '%s\n' "$deguises" | sed -n $'s/^B\tBLOQUANT\t//p' | filtrer || true)"
    noter AVERTISSEMENT "boucle sur tous les joueurs qui envoie après un filtre (vérifier que c'est une portée calculée côté serveur ; sinon core.net.sendNear)" \
        "$(printf '%s\n' "$deguises" | sed -n $'s/^B\tAVERTISSEMENT\t//p' | filtrer || true)"
fi

signal BLOQUANT '(query|single|scalar|insert|update|execute|prepare)[A-Za-z]*\([[:space:]]*[^,]*\.\.' "SQL construit par concaténation (utiliser ?)"
signal BLOQUANT 'loadstring\(|[=(,][[:space:]]*load\([[:space:]]*["'"'"'a-z_]+[^)]*\)\(\)' "exécution de code dynamique"
lua_sans_chancellerie=(); for f in "${lua[@]}"; do [[ "$f" == modules/vava_chancellerie/* ]] || lua_sans_chancellerie+=("$f"); done
if [[ ${#lua_sans_chancellerie[@]} -gt 0 ]]; then
    res=$(grep -HnE 'PerformHttpRequest\(' "${lua_sans_chancellerie[@]}" 2>/dev/null | filtrer || true)
    noter BLOQUANT "requête HTTP sortante depuis un module de jeu" "$res"
fi

# RegisterNetEvent serveur hors du core RPC (exceptions connues listées ici)
mapfile -t srv < <(printf '%s\n' "${lua[@]}" | grep -E '(^|/)server/|/bridge/server' | grep -vE '^server/core/rpc\.lua$|^modules/vava_chat/server/compat\.lua$' || true)
if [[ ${#srv[@]} -gt 0 ]]; then
    res=$(grep -HnE '^\s*RegisterNetEvent\(|[^.]RegisterNetEvent\([^)]' "${srv[@]}" 2>/dev/null | grep -vE 'local RegisterNetEvent' | filtrer || true)
    noter BLOQUANT "évènement réseau serveur hors core.rpc.register" "$res"
fi

signal AVERTISSEMENT 'GlobalState\[[^]]+\][[:space:]]*=' "écriture GlobalState (envoyée à TOUS les joueurs : petite, rare, utile à tous ?)"
signal AVERTISSEMENT 'Wait\(0\)' "Wait(0) : uniquement pendant un état actif temporaire"
signal AVERTISSEMENT 'GetGamePool' "GetGamePool : à éviter dans une boucle"

if [[ ${#web[@]} -gt 0 ]]; then
    res=$(grep -HnE 'https?://' "${web[@]}" 2>/dev/null | grep -vE 'xmlns|w3\.org|nui://|https://cfx-nui-|https://\$\{' | filtrer || true)
    noter BLOQUANT "ressource externe dans une interface" "$res"
    res=$(grep -HnE '\.innerHTML[[:space:]]*\+?=' "${web[@]}" 2>/dev/null | filtrer || true)
    noter AVERTISSEMENT "innerHTML : jamais avec une donnée venant d'un joueur (marquer '// audit: ok' si sûr)" "$res"
fi

if [[ $ESSAI -eq 1 ]]; then
    # attendus : « chemin:ligne<TAB>NIVEAU » (rien : aucun constat permis sur la ligne)
    declare -A attendu=() trouve=()
    cas=0; ecarts=0
    while IFS= read -r ligne; do
        [[ -z "$ligne" ]] && continue
        position="${ligne%%:-- attendu:*}"; niveau="${ligne##*-- attendu: }"; niveau="${niveau%%[[:space:]]*}"
        attendu["$position"]="$niveau"; cas=$((cas + 1))
    done < <(grep -HnoE -- '-- attendu: (BLOQUANT|AVERTISSEMENT|rien)' "${lua[@]}" 2>/dev/null || true)
    for c in "${constats[@]}"; do
        niveau="${c%%$'\t'*}"; position="${c#*$'\t'}"
        trouve["$position"]="${trouve[$position]:+${trouve[$position]} }$niveau"
    done
    for position in "${!attendu[@]}"; do
        niveau="${attendu[$position]}"; vu="${trouve[$position]:-}"
        if [[ "$niveau" == rien ]]; then
            [[ -z "$vu" ]] || { echo "ÉCART $position : rien attendu, signalé $vu"; ecarts=$((ecarts + 1)); }
        elif [[ " $vu " != *" $niveau "* ]]; then
            echo "ÉCART $position : $niveau attendu, signalé ${vu:-rien}"; ecarts=$((ecarts + 1))
        fi
    done
    for position in "${!trouve[@]}"; do
        [[ -n "${attendu[$position]:-}" ]] || { echo "ÉCART $position : signalé ${trouve[$position]} sans être attendu"; ecarts=$((ecarts + 1)); }
    done
    if [[ $cas -eq 0 ]]; then echo "ESSAI : ÉCHEC (aucun cas dans tests/audit/)"; exit 1; fi
    if [[ $ecarts -gt 0 ]]; then echo "ESSAI : ÉCHEC ($ecarts écart(s) sur $cas cas)"; exit 1; fi
    echo "ESSAI : OK ($cas cas)"
    exit 0
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
