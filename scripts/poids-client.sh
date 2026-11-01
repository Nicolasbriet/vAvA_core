#!/usr/bin/env bash
# scripts/poids-client.sh — ce que télécharge un joueur, ressource par ressource (T-132). Informatif (code de sortie 0,
# 2 pour une option mal écrite) ; scripts/verifier.sh n'en lance que --liste (T-154).
# Usage : poids-client.sh [--detail | --liste] [--dossier <dossier>] [ressource…]
#   sans ressource : le core (racine du dépôt, vAvA_core), puis chaque modules/* et examples/* à manifeste ; une
#   ressource se nomme vava_xxx, vAvA_core, ou par son dossier ;
#   --dossier <d> (T-154) : mesure une copie disposée comme par l'installeur de la Chancellerie ou par
#   `node scripts/livraison.js --sortie <d>` : ressources <d>/[catégorie]/<nom> et <d>/<nom>, nommées par leur dossier ;
#   --liste (T-154) : chemins servis, sans calcul de taille : « ressource<TAB>chemin » par fichier servi (manifeste
#   compris), puis « ressource@conseil<TAB>chemin » par fichier du côté conseil de manifeste.awk (`vava_conseil_lua`,
#   `vava_conseil_web` : paquet du Conseil, T-157) ; recoupé par scripts/verifier.sh avec scripts/livraison.js --liste.
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
set -uo pipefail
ORIGINE=$PWD
cd "$(dirname "$0")/.."
shopt -s nullglob globstar

DETAIL=0; LISTE=0; COPIE=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --detail) DETAIL=1; shift ;;
        --liste) LISTE=1; shift ;;
        --dossier)
            if [[ $# -lt 2 || -z "$2" ]]; then echo "usage : poids-client.sh --dossier <dossier>" >&2; exit 2; fi
            COPIE="${2%/}"; shift 2
            [[ "$COPIE" == /* || "$COPIE" =~ ^[A-Za-z]: ]] || COPIE="$ORIGINE/$COPIE"
            if [[ ! -d "$COPIE" ]]; then echo "dossier introuvable : $COPIE" >&2; exit 2; fi ;;
        *) break ;;
    esac
done

nom() { if [[ "$1" == "." ]]; then echo vAvA_core; else echo "${1##*/}"; fi; }

dossiers=()
if [[ -n "$COPIE" ]]; then
    # copie disposée comme par l'installeur : <copie>/[catégorie]/<ressource>, ou <copie>/<ressource>
    for m in "$COPIE"/\[*\]/*/fxmanifest.lua "$COPIE"/*/fxmanifest.lua; do
        r="${m%/fxmanifest.lua}"
        if [[ $# -eq 0 ]]; then dossiers+=("$r"); continue; fi
        for voulu in "$@"; do [[ "${r##*/}" == "${voulu%/}" ]] && dossiers+=("$r"); done
    done
elif [[ $# -gt 0 ]]; then
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
[[ $LISTE -eq 1 ]] || ligne ressource lua lua_gz autres autres_gz manifeste manif_gz stream stream_gz total total_gz
for d in "${dossiers[@]}"; do
    declare -A vus=() vusc=() R=()
    res=$(nom "$d")
    conseil=()
    for k in lb lg ab ag mb mg sb sg; do R[$k]=0; done
    compter() { # fichier colonne(l, a, m, s)
        local f="$1" col="$2" brut gz
        [[ -f "$f" && -z "${vus[$f]:-}" ]] || return 0
        vus[$f]=1
        if [[ $LISTE -eq 1 ]]; then printf '%s\t%s\n' "$res" "${f#"$d"/}"; return 0; fi
        read -r brut gz < <(taille "$f")
        if [[ "$col" == a && "$f" == *.lua ]]; then col=l; fi
        R[${col}b]=$(( ${R[${col}b]} + brut )); R[${col}g]=$(( ${R[${col}g]} + gz ))
        [[ $DETAIL -eq 1 ]] && printf '  %-20s %-48s %8s %8s\n' "$res" "${f#"$d"/}" "$brut" "$gz"
        return 0
    }
    compter "$d/fxmanifest.lua" m
    for f in "$d"/stream/**; do compter "$f" s; done
    while IFS=$'\t' read -r _ cote _ motif; do
        [[ "$cote" != serveur && -n "$motif" && "$motif" != @* ]] || continue
        if [[ "$motif" == /* || "/$motif/" == */../* ]]; then
            echo "$(nom "$d") : motif refusé (absolu ou avec ..) : $motif" >&2; continue
        fi
        if [[ "$cote" == conseil ]]; then conseil+=("$motif"); continue; fi
        for f in "$d"/$motif; do compter "$f" a; done    # motif développé exprès (joker), dans la ressource seule
    done < <(awk -v Q="'" -v MODE=liste -f scripts/lib/manifeste.awk "$d/fxmanifest.lua" | tr -d '\r')
    if [[ $LISTE -eq 1 ]]; then
        # côté conseil (paquet du Conseil, T-157) : listé à part, jamais compté chez le joueur
        for motif in "${conseil[@]}"; do
            for f in "$d"/$motif; do
                [[ -f "$f" && -z "${vusc[$f]:-}" ]] || continue
                vusc[$f]=1
                printf '%s@conseil\t%s\n' "$res" "${f#"$d"/}"
            done
        done
        unset vus vusc R
        continue
    fi
    ligne "$(nom "$d")" "${R[lb]}" "${R[lg]}" "${R[ab]}" "${R[ag]}" "${R[mb]}" "${R[mg]}" "${R[sb]}" "${R[sg]}" \
        $(( R[lb] + R[ab] + R[mb] + R[sb] )) $(( R[lg] + R[ag] + R[mg] + R[sg] ))
    for k in lb lg ab ag mb mg sb sg; do T[$k]=$(( ${T[$k]} + ${R[$k]} )); done
    unset vus vusc R
done
[[ $LISTE -eq 1 ]] && exit 0
ligne total "${T[lb]}" "${T[lg]}" "${T[ab]}" "${T[ag]}" "${T[mb]}" "${T[mg]}" "${T[sb]}" "${T[sg]}" \
    $(( T[lb] + T[ab] + T[mb] + T[sb] )) $(( T[lg] + T[ag] + T[mg] + T[sg] ))
exit 0
