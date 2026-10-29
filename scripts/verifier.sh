#!/usr/bin/env bash
# scripts/verifier.sh — contrôle avant chaque commit d'agent et en CI.
#   1. lint (luacheck) : fichiers Lua modifiés depuis BASE, ou tout le dépôt avec --tout
#   2. tests unitaires (busted)
#   3. audit réseau et sécurité statique (scripts/audit-reseau.sh)
# Code de sortie 0 seulement si tout passe.
set -uo pipefail
cd "$(dirname "$0")/.."

BASE="${BASE:-agents/integration}"
MODE="${1:-}"
export PATH="$HOME/.luarocks/bin:$PATH"
# sous Windows : outils posés dans .outils/ par scripts/outils-windows.sh
[[ -d .outils ]] && export PATH="$PWD/.outils/rocks/bin:$PWD/.outils/lua54/bin:$PATH"
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

titre "Audit réseau et sécurité"
# shellcheck disable=SC2086
./scripts/audit-reseau.sh $fichiers_tous || echec=1

echo
if [[ $echec -eq 0 ]]; then echo "VÉRIFICATION : OK"; else echo "VÉRIFICATION : ÉCHEC"; fi
exit $echec
