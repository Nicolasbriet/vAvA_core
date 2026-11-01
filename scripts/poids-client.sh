#!/usr/bin/env bash
# scripts/poids-client.sh — ce que télécharge un joueur, ressource par ressource (T-132). Informatif : hors de
# scripts/verifier.sh, code de sortie 0.
# Usage : poids-client.sh [--detail] [ressource…]   (sans ressource : le core (racine du dépôt, vAvA_core), puis chaque
#                                                    modules/* et examples/* à manifeste ; une ressource se nomme
#                                                    vava_xxx, vAvA_core, ou par son dossier)
# Lit les chaînes des manifestes avec le lecteur de l'audit (scripts/lib/manifeste.awk) : directives servies aux
# joueurs (`shared_script(s)`, `client_script(s)`, `files`, `file`, `ui_page`, `loadscreen`), `@ressource/…` ignoré.
# Chaque motif est développé depuis le dossier de la ressource, sans doublon ; un motif absolu ou qui contient `..`
# est refusé (signalé, non compté : on ne lit rien hors de la ressource). Comptés aussi : le `fxmanifest.lua` lui-même
# (servi à chaque joueur) et tout le dossier `stream/` (servi d'office par FXServer). Tailles en octets : brut (`wc -c`)
# et compressé (`gzip -9c`, fichier par fichier : borne basse si un mandataire compresse). Fichiers texte comptés en
# fins de ligne LF, comme dans le dépôt (une copie Windows en CRLF sert un octet de plus par ligne) ; fichiers binaires
# (polices, images, modèles) tels quels.
# Sortie : une ligne par ressource « ressource  lua  lua_gz  autres  autres_gz  manifeste  manif_gz  stream  stream_gz
# total  total_gz », puis le total ; --detail : une ligne par fichier (« ressource  chemin  brut  gzip »), avant celle
# de sa ressource.
# T-157 : les fichiers des directives `vava_conseil_lua` et `vava_conseil_web` (code du seul Conseil, livré à la demande
# par la ressource) ne comptent pas chez le joueur ; ils ont leur ligne « <ressource>@conseil », après celle de la
# ressource et hors du total : lua et autres en brut (le paquet part en latent, sans compression : colonnes gzip « - »),
# total = taille exacte du paquet (« VAVAPAQ1 », en-tête de chaque fichier et fins de ligne compris) ; avec --detail,
# ses fichiers avant elle (« <ressource>@conseil  chemin  brut  - »).
set -uo pipefail
cd "$(dirname "$0")/.."
shopt -s nullglob globstar

DETAIL=0
if [[ "${1:-}" == "--detail" ]]; then DETAIL=1; shift; fi

nom() { if [[ "$1" == "." ]]; then echo vAvA_core; else echo "${1##*/}"; fi; }

dossiers=()
if [[ $# -gt 0 ]]; then
    for r in "$@"; do
        r="${r%/}"
        if [[ "$r" == vAvA_core || "$r" == . ]]; then dossiers+=(".")
        elif [[ -f "modules/$r/fxmanifest.lua" ]]; then dossiers+=("modules/$r")
        elif [[ -f "examples/$r/fxmanifest.lua" ]]; then dossiers+=("examples/$r")
        elif [[ "$r" != *..* && -f "$r/fxmanifest.lua" ]]; then dossiers+=("$r")
        else echo "ressource introuvable : $r" >&2; fi
    done
else
    dossiers+=(".")
    for m in modules/*/fxmanifest.lua examples/*/fxmanifest.lua; do dossiers+=("${m%/fxmanifest.lua}"); done
fi

taille() { # fichier → « brut gzip » (texte en LF)
    case "$1" in
        *.lua|*.js|*.css|*.html|*.htm|*.svg|*.json|*.txt|*.md)
            printf '%s %s\n' "$(tr -d '\r' < "$1" | wc -c)" "$(tr -d '\r' < "$1" | gzip -9c | wc -c)" ;;
        *) printf '%s %s\n' "$(wc -c < "$1")" "$(gzip -9c < "$1" | wc -c)" ;;
    esac
}

declare -A T=()
for k in lb lg ab ag mb mg sb sg; do T[$k]=0; done
ligne() { printf '%-22s %9s %8s %9s %8s %9s %8s %9s %8s %10s %9s\n' "$@"; }
ligne ressource lua lua_gz autres autres_gz manifeste manif_gz stream stream_gz total total_gz
for d in "${dossiers[@]}"; do
    declare -A vus=() R=() cvus=()
    cl=0; ca=0; cpaq=0; cdet=
    for k in lb lg ab ag mb mg sb sg; do R[$k]=0; done
    compter() { # fichier colonne(l, a, m, s)
        local f="$1" col="$2" brut gz
        [[ -f "$f" && -z "${vus[$f]:-}" ]] || return 0
        vus[$f]=1
        read -r brut gz < <(taille "$f")
        if [[ "$col" == a && "$f" == *.lua ]]; then col=l; fi
        R[${col}b]=$(( ${R[${col}b]} + brut )); R[${col}g]=$(( ${R[${col}g]} + gz ))
        [[ $DETAIL -eq 1 ]] && printf '  %-20s %-48s %8s %8s\n' "$(nom "$d")" "${f#"$d"/}" "$brut" "$gz"
        return 0
    }
    conseil() { # fichier du paquet du Conseil : brut seulement, en-tête « <genre> <chemin> <octets>\n » et fin de ligne
        local f="$1" brut rel
        [[ -f "$f" && -z "${cvus[$f]:-}" ]] || return 0
        cvus[$f]=1
        brut=$(tr -d '\r' < "$f" | wc -c); brut=$((brut + 0))
        rel="${f#"$d"/}"
        if [[ "$f" == *.lua ]]; then cl=$((cl + brut)); else ca=$((ca + brut)); fi
        [[ $cpaq -eq 0 ]] && cpaq=9    # « VAVAPAQ1\n »
        cpaq=$(( cpaq + 2 + ${#rel} + 1 + ${#brut} + 1 + brut + 1 ))
        [[ $DETAIL -eq 1 ]] && cdet+=$(printf '  %-20s %-48s %8s %8s' "$(nom "$d")@conseil" "$rel" "$brut" "-")$'\n'
        return 0
    }
    compter "$d/fxmanifest.lua" m
    for f in "$d"/stream/**; do compter "$f" s; done
    while IFS=$'\t' read -r _ cote _ motif; do
        [[ ( "$cote" == client || "$cote" == conseil ) && -n "$motif" && "$motif" != @* ]] || continue
        if [[ "$motif" == /* || "/$motif/" == */../* ]]; then
            echo "$(nom "$d") : motif refusé (absolu ou avec ..) : $motif" >&2; continue
        fi
        if [[ "$cote" == conseil ]]; then
            for f in "$d"/$motif; do conseil "$f"; done    # paquet du Conseil (T-157), dans la ressource seule
            continue
        fi
        for f in "$d"/$motif; do compter "$f" a; done    # motif développé exprès (joker), dans la ressource seule
    done < <(awk -v Q="'" -v MODE=liste -f scripts/lib/manifeste.awk "$d/fxmanifest.lua" | tr -d '\r')
    ligne "$(nom "$d")" "${R[lb]}" "${R[lg]}" "${R[ab]}" "${R[ag]}" "${R[mb]}" "${R[mg]}" "${R[sb]}" "${R[sg]}" \
        $(( R[lb] + R[ab] + R[mb] + R[sb] )) $(( R[lg] + R[ag] + R[mg] + R[sg] ))
    for k in lb lg ab ag mb mg sb sg; do T[$k]=$(( ${T[$k]} + ${R[$k]} )); done
    if [[ $cpaq -gt 0 ]]; then
        printf '%s' "$cdet"
        ligne "$(nom "$d")@conseil" "$cl" - "$ca" - 0 - 0 - "$cpaq" -
    fi
    unset vus R cvus
done
ligne total "${T[lb]}" "${T[lg]}" "${T[ab]}" "${T[ag]}" "${T[mb]}" "${T[mg]}" "${T[sb]}" "${T[sg]}" \
    $(( T[lb] + T[ab] + T[mb] + T[sb] )) $(( T[lg] + T[ag] + T[mg] + T[sg] ))
exit 0
