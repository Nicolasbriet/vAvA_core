#!/usr/bin/env bash
# scripts/poids-client.sh — ce que télécharge un joueur, ressource par ressource (T-132). Informatif : hors de
# scripts/verifier.sh, code de sortie 0.
# Usage : poids-client.sh [--detail] [ressource…]   (sans ressource : chaque modules/* et examples/* à manifeste ;
#                                                    une ressource se nomme vava_xxx ou par son dossier)
# Lit les chaînes des manifestes avec le lecteur de l'audit (scripts/lib/manifeste.awk) : directives servies aux
# joueurs (`shared_script(s)`, `client_script(s)`, `files`, `file`, `ui_page`, `loadscreen`), `@ressource/…` ignoré.
# Chaque motif est développé depuis le dossier de la ressource, sans doublon. Tailles en octets : brut (`wc -c`) et
# compressé (`gzip -9c`, fichier par fichier : borne basse si un mandataire compresse), les `.lua` à part du reste.
# Fichiers texte comptés en fins de ligne LF, comme dans le dépôt (une copie Windows en CRLF sert un octet de plus par
# ligne) ; fichiers binaires (polices, images matricielles) tels quels.
# Sortie : une ligne par ressource « ressource  lua_brut  lua_gzip  autres_brut  autres_gzip », puis le total ;
# --detail : une ligne par fichier (« ressource  chemin  brut  gzip »), avant celle de sa ressource.
set -uo pipefail
cd "$(dirname "$0")/.."
shopt -s nullglob globstar

DETAIL=0
if [[ "${1:-}" == "--detail" ]]; then DETAIL=1; shift; fi

dossiers=()
if [[ $# -gt 0 ]]; then
    for r in "$@"; do
        r="${r%/}"
        if [[ -f "$r/fxmanifest.lua" ]]; then dossiers+=("$r")
        elif [[ -f "modules/$r/fxmanifest.lua" ]]; then dossiers+=("modules/$r")
        elif [[ -f "examples/$r/fxmanifest.lua" ]]; then dossiers+=("examples/$r")
        else echo "ressource introuvable : $r" >&2; fi
    done
else
    for m in modules/*/fxmanifest.lua examples/*/fxmanifest.lua; do dossiers+=("${m%/fxmanifest.lua}"); done
fi

taille() { # fichier → « brut gzip » (texte en LF)
    case "$1" in
        *.lua|*.js|*.css|*.html|*.htm|*.svg|*.json|*.txt|*.md)
            printf '%s %s\n' "$(tr -d '\r' < "$1" | wc -c)" "$(tr -d '\r' < "$1" | gzip -9c | wc -c)" ;;
        *) printf '%s %s\n' "$(wc -c < "$1")" "$(gzip -9c < "$1" | wc -c)" ;;
    esac
}

t_lb=0; t_lg=0; t_ab=0; t_ag=0
printf '%-26s %10s %10s %12s %12s\n' ressource lua_brut lua_gzip autres_brut autres_gzip
for d in "${dossiers[@]}"; do
    declare -A vus=()
    lb=0; lg=0; ab=0; ag=0
    while IFS=$'\t' read -r _ cote _ motif; do
        [[ "$cote" == client && -n "$motif" && "$motif" != @* ]] || continue
        for f in "$d"/$motif; do
            [[ -f "$f" && -z "${vus[$f]:-}" ]] || continue
            vus[$f]=1
            read -r brut gz < <(taille "$f")
            if [[ "$f" == *.lua ]]; then lb=$((lb + brut)); lg=$((lg + gz)); else ab=$((ab + brut)); ag=$((ag + gz)); fi
            [[ $DETAIL -eq 1 ]] && printf '  %-24s %-48s %8s %8s\n' "${d##*/}" "${f#"$d"/}" "$brut" "$gz"
        done
    done < <(awk -v Q="'" -v MODE=liste -f scripts/lib/manifeste.awk "$d/fxmanifest.lua" | tr -d '\r')
    unset vus
    printf '%-26s %10s %10s %12s %12s\n' "${d##*/}" "$lb" "$lg" "$ab" "$ag"
    t_lb=$((t_lb + lb)); t_lg=$((t_lg + lg)); t_ab=$((t_ab + ab)); t_ag=$((t_ag + ag))
done
printf '%-26s %10s %10s %12s %12s\n' total "$t_lb" "$t_lg" "$t_ab" "$t_ag"
exit 0
