#!/usr/bin/env bash
# scripts/verifier.sh — contrôle avant chaque commit d'agent et en CI.
#   1. lint (luacheck) : fichiers Lua modifiés depuis BASE, ou tout le dépôt avec --tout
#   2. tests unitaires (busted)
#   3. essais des fonctions pures des pages (node, s'il est présent ; sinon un message, sans échec)
#   4. Lua livré sans commentaires (T-154) : essais du lexeur et de la livraison (node), allègement du Lua suivi par git
#      prouvé par le compilateur Lua 5.4 (scripts/lib/meme-code.lua), liste des fichiers allégés recoupée avec
#      scripts/lib/manifeste.awk ; hors --tout, seuls les .lua modifiés sont prouvés et les listes ne sont recoupées
#      que si un manifeste a changé, sauf si l'outillage de la livraison a changé (tout alors) ; node absent :
#      message, échec en CI ; lua absent : échec
#   5. audit réseau et sécurité statique (scripts/audit-reseau.sh), puis son essai sur les cas de tests/audit/
# Code de sortie 0 seulement si tout passe.
set -uo pipefail
cd "$(dirname "$0")/.."

BASE="${BASE:-agents/integration}"
MODE="${1:-}"
export PATH="$HOME/.luarocks/bin:$PATH"
# sous Windows : outils posés dans .outils/ par scripts/outils-windows.sh ; dans un worktree (sans .outils), ceux de la
# copie principale (relecture réseau R-4 de T-141)
outils_de() { [[ -d "$1/.outils" ]] && export PATH="$1/.outils/rocks/bin:$1/.outils/lua54/bin:$PATH"; }
outils_de "$PWD" || outils_de "$(cd "$(git rev-parse --git-common-dir 2>/dev/null)/.." 2>/dev/null && pwd)"
echec=0

titre() { printf '\n== %s\n' "$1"; }

# Sous Windows, LuaRocks pose des lanceurs luacheck.bat et busted.bat, qui fixent déjà l'interpréteur ; un .bat passe
# par cmd.exe, limité à 8 191 caractères par ligne : la liste des fichiers est donc découpée par xargs.
lanceur() { if command -v "$1" >/dev/null; then echo "$1"; elif command -v "$1.bat" >/dev/null; then echo "$1.bat"; fi; }
LUACHECK=$(lanceur luacheck); BUSTED=$(lanceur busted)

if [[ "$MODE" == "--tout" ]] || ! git rev-parse --verify -q "$BASE" >/dev/null; then
    fichiers_lua=$(git ls-files '*.lua')
    fichiers_tous=$(git ls-files)
else
    fichiers_lua=$(git diff --name-only --diff-filter=ACMR "$BASE"...HEAD -- '*.lua'; git diff --name-only --diff-filter=ACMR -- '*.lua')
    fichiers_tous=$(git diff --name-only --diff-filter=ACMR "$BASE"...HEAD; git diff --name-only --diff-filter=ACMR)
fi
fichiers_lua=$(printf '%s\n' $fichiers_lua | sort -u | grep -v '^$' || true)
fichiers_tous=$(printf '%s\n' $fichiers_tous | sort -u | grep -v '^$' || true)

titre "Lint"
if [[ -z "$LUACHECK" ]]; then
    echo "luacheck absent : luarocks --lua-version 5.4 install luacheck (Windows : ./scripts/outils-windows.sh)"; echec=1
elif [[ -z "$fichiers_lua" ]]; then
    echo "aucun fichier Lua modifié"
else
    printf '%s\n' "$fichiers_lua" | xargs -s 7000 "$LUACHECK" --formatter plain -q || echec=1
fi

titre "Tests unitaires"
if [[ -z "$BUSTED" ]]; then
    echo "busted absent : luarocks --lua-version 5.4 install busted (Windows : ./scripts/outils-windows.sh)"; echec=1
elif [[ "$BUSTED" == *.bat ]]; then
    "$BUSTED" -o utfTerminal || echec=1
else
    busted --lua=lua5.4 -o utfTerminal || echec=1
fi

titre "Essais de pages"
# fonctions pures d'une page (sans dépendance), lancées par node ; node manquant : rien n'échoue, on le dit
ESSAIS_PAGES=(modules/vava_loading/web/dev/essais.js modules/vava_codex/web/dev/essais.js modules/vava_atelier/web/dev/essais.js modules/vava_provisions/web/dev/essais.js modules/vava_pause/web/dev/essais.js modules/vava_hud/web/dev/essais.js)
if ! command -v node >/dev/null; then
    echo "node absent : essais de pages non lancés (${ESSAIS_PAGES[*]})"
else
    for essai in "${ESSAIS_PAGES[@]}"; do
        if [[ -f "$essai" ]]; then node "$essai" || echec=1
        else echo "$essai introuvable"; echec=1; fi
    done
fi

titre "Lua livré sans commentaires (T-154)"
# allègement des fichiers Lua suivis par git par le lexeur de la Chancellerie, prouvé par le compilateur Lua 5.4
# (scripts/lib/meme-code.lua) ; liste des fichiers allégés recoupée avec scripts/lib/manifeste.awk ; essais du lexeur.
# Hors --tout (relecture réseau R-6) : seuls les .lua modifiés sont prouvés, les listes ne sont recoupées que si un
# manifeste a changé ; tout est repris si l'outillage de la livraison a changé (en --tout, il est dans la liste).
# node absent : rien n'est lancé (échec en CI) ; lua absent : échec (comme busted)
OUTILLAGE_LIVRAISON='^(chancellerie/lib/(luastrip|delivery|installer)\.js|scripts/livraison\.js|scripts/lib/(meme-code\.lua|manifeste\.awk)|scripts/poids-client\.sh|scripts/verifier\.sh|tests/livraison/)'
LUA=$(command -v lua5.4 || command -v lua || true)
if ! command -v node >/dev/null; then
    echo "node absent : livraison non essayée"; [[ -n "${CI:-}" ]] && echec=1
elif [[ -z "$LUA" ]]; then
    echo "lua absent : preuve de la livraison non lancée"; echec=1
else
    tmp=$(mktemp -d)
    node tests/livraison/essais.js || echec=1
    preuve=()   # vide : tout le Lua suivi
    if ! grep -Eq "$OUTILLAGE_LIVRAISON" <<< "$fichiers_tous"; then
        mapfile -t preuve < <(printf '%s\n' "$fichiers_lua" | grep -v '^$' || true)
        [[ ${#preuve[@]} -eq 0 ]] && echo "aucun fichier Lua modifié : preuve sans objet"
    fi
    if grep -Eq "$OUTILLAGE_LIVRAISON" <<< "$fichiers_tous" || [[ ${#preuve[@]} -gt 0 ]]; then
        node scripts/livraison.js --essai "$tmp/allege" "${preuve[@]}" > "$tmp/liste.txt" || echec=1
        "$LUA" scripts/lib/meme-code.lua "$tmp/allege" < "$tmp/liste.txt" || echec=1
    fi
    if grep -Eq "$OUTILLAGE_LIVRAISON|(^|/)fxmanifest\.lua$" <<< "$fichiers_tous"; then
        node scripts/livraison.js --liste | cut -f1,2 | sort -u > "$tmp/js.txt" || echec=1
        ./scripts/poids-client.sh --liste | grep -i '\.lua$' | sort -u > "$tmp/awk.txt"
        if ! diff -u "$tmp/awk.txt" "$tmp/js.txt"; then
            echo "ÉCART : la livraison (chancellerie/lib/delivery.js) et scripts/lib/manifeste.awk ne voient pas les mêmes fichiers Lua servis"
            echec=1
        fi
    else
        echo "aucun manifeste modifié : listes non recoupées"
    fi
    rm -rf "$tmp"
fi

titre "Audit réseau et sécurité"
# shellcheck disable=SC2086
./scripts/audit-reseau.sh $fichiers_tous || echec=1

titre "Essai du script d'audit"
# les contrôles de l'audit lancés sur les cas écrits de tests/audit/ : chacun doit dire ce que la ligne attend
./scripts/audit-reseau.sh --essai || echec=1

echo
if [[ $echec -eq 0 ]]; then echo "VÉRIFICATION : OK"; else echo "VÉRIFICATION : ÉCHEC"; fi
exit $echec
