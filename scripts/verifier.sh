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
#   5. pages livrées sans commentaires (T-160) : essais des lexeurs et de la livraison des pages (node), allègement des
#      pages suivies par git (JS, CSS, HTML) prouvé par un second lecteur et par V8 (scripts/lib/meme-page.js), liste des
#      pages servies recoupée avec scripts/lib/manifeste.awk, essais de pages relancés sur une copie allégée
#      (`livraison.js --sortie`) ; hors --tout, seules les pages modifiées sont prouvées, les listes recoupées si un
#      manifeste a changé, les essais relancés si une page ou un manifeste de module a changé, sauf si l'outillage a
#      changé (tout alors) ; essais des lexeurs seulement si une page ou l'outillage a changé ; liste de
#      poids-client.sh --liste calculée une fois pour les étapes 4 et 5 ; node absent : message, échec en CI
#   6. audit réseau et sécurité statique (scripts/audit-reseau.sh), puis son essai sur les cas de tests/audit/
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

# chemins servis selon scripts/lib/manifeste.awk (poids-client.sh --liste), calculés une fois et partagés par les étapes
# T-154 et T-160 (relecture réseau R-4 de T-160) : `liste_poids` remplit le fichier $LISTE_POIDS au premier appel (hors
# d'un sous-shell) ; retiré à la sortie
LISTE_POIDS=""
liste_poids() { if [[ -z "$LISTE_POIDS" ]]; then LISTE_POIDS=$(mktemp); ./scripts/poids-client.sh --liste > "$LISTE_POIDS"; fi; }
trap 'if [[ -n "$LISTE_POIDS" ]]; then rm -f "$LISTE_POIDS"; fi' EXIT

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
        liste_poids
        grep -i '\.lua$' "$LISTE_POIDS" | sort -u > "$tmp/awk.txt"
        if ! diff -u "$tmp/awk.txt" "$tmp/js.txt"; then
            echo "ÉCART : la livraison (chancellerie/lib/delivery.js) et scripts/lib/manifeste.awk ne voient pas les mêmes fichiers Lua servis"
            echec=1
        fi
    else
        echo "aucun manifeste modifié : listes non recoupées"
    fi
    rm -rf "$tmp"
fi

titre "Pages livrées sans commentaires (T-160)"
# pages (JS, CSS, HTML) des fichiers suivis par git allégées par webstrip (Chancellerie), prouvées par un second lecteur
# et par V8 (scripts/lib/meme-page.js) ; liste recoupée avec scripts/lib/manifeste.awk ; essais des pages relancés sur
# la copie allégée (mêmes fichiers d'essai, chemins inchangés : chacun lit ses pages depuis son propre dossier). Hors
# --tout : essais des lexeurs et preuve seulement si une page (ou l'outillage) a changé, et des seules pages modifiées ;
# listes recoupées si un manifeste a changé ; essais relancés si une page ou un manifeste de module a changé ; tout si
# l'outillage a changé (relecture réseau R-4). node absent : échec en CI.
OUTILLAGE_PAGES='^(chancellerie/lib/(webstrip|delivery|installer)\.js|scripts/livraison\.js|scripts/lib/(meme-page\.js|manifeste\.awk)|scripts/poids-client\.sh|scripts/verifier\.sh|tests/livraison/)'
if ! command -v node >/dev/null; then
    echo "node absent : pages livrées non essayées"; [[ -n "${CI:-}" ]] && echec=1
else
    tmp=$(mktemp -d)
    tout_pages=0
    if [[ "$MODE" == "--tout" ]] || grep -Eq "$OUTILLAGE_PAGES" <<< "$fichiers_tous"; then tout_pages=1; fi
    mapfile -t pages < <(grep -iE '\.(js|css|html?)$' <<< "$fichiers_tous" || true)
    if [[ $tout_pages -eq 1 || ${#pages[@]} -gt 0 ]]; then
        node tests/livraison/essais-pages.js || echec=1
    else
        echo "aucune page ni outillage modifié : essais des lexeurs de pages non lancés"
    fi
    if [[ $tout_pages -eq 1 ]]; then
        node scripts/livraison.js --essai-pages "$tmp/pages" > "$tmp/pages.txt" || echec=1
        node scripts/lib/meme-page.js "$tmp/pages" < "$tmp/pages.txt" || echec=1
    elif [[ ${#pages[@]} -gt 0 ]]; then
        node scripts/livraison.js --essai-pages "$tmp/pages" "${pages[@]}" > "$tmp/pages.txt" || echec=1
        node scripts/lib/meme-page.js "$tmp/pages" < "$tmp/pages.txt" || echec=1
    else
        echo "aucune page modifiée : preuve sans objet"
    fi
    if [[ $tout_pages -eq 1 ]] || grep -Eq '(^|/)fxmanifest\.lua$' <<< "$fichiers_tous"; then
        node scripts/livraison.js --liste-pages | cut -f1,2 | sort -u > "$tmp/js.txt" || echec=1
        liste_poids
        grep -iE '\.(js|css|html?)$' "$LISTE_POIDS" | sort -u > "$tmp/awk.txt"
        if ! diff -u "$tmp/awk.txt" "$tmp/js.txt"; then
            echo "ÉCART : la livraison (chancellerie/lib/delivery.js) et scripts/lib/manifeste.awk ne voient pas les mêmes pages servies"
            echec=1
        fi
    else
        echo "aucun manifeste modifié : listes des pages non recoupées"
    fi
    if [[ $tout_pages -eq 1 ]] || grep -Eq '^modules/[^/]+/(web/|fxmanifest\.lua$)' <<< "$fichiers_tous"; then
        node scripts/livraison.js --sortie "$tmp/copie" > "$tmp/sortie.txt" || { cat "$tmp/sortie.txt"; echec=1; }
        for essai in "${ESSAIS_PAGES[@]}"; do
            m=${essai#modules/}; m=${m%%/*}
            # lancé depuis le dossier de la ressource : sous Git Bash, un chemin à crochets passé à node n'est pas
            # converti en chemin Windows
            ( cd "$tmp/copie/[vava]/$m" && node "${essai#modules/"$m"/}" ) || { echo "essai sur la copie allégée en échec : $essai"; echec=1; }
        done
    else
        echo "aucune page ni manifeste modifié : essais de pages non relancés sur la copie"
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
