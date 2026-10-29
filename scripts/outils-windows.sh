#!/usr/bin/env bash
# scripts/outils-windows.sh — installe sous Windows, sans droits d'administrateur, les outils de scripts/verifier.sh :
#   Lua 5.4 compilé avec MSVC, LuaRocks, luacheck et busted, dans .outils/ (ignoré par git ; verifier.sh l'ajoute au PATH).
# Prérequis : Git Bash, Visual Studio Build Tools avec les outils C++ (MSVC x64) et un SDK Windows.
# Usage : ./scripts/outils-windows.sh — à relancer si le dépôt change de place (les lanceurs .bat de LuaRocks gardent des
# chemins absolus). Chaque archive est contrôlée par son empreinte SHA-256 avant usage ; .outils/ est refait à neuf.
set -euo pipefail
cd "$(dirname "$0")/.."

LUA_VERSION=5.4.9
LUA_SHA256=2335b6c582a52654f94612bf10d2f4672805d05329aa6568b1d8cd9e5c6fb8e6        # publiée sur https://www.lua.org/ftp/
LUAROCKS_VERSION=3.13.0
LUAROCKS_SHA256=0897ade5d459d55cd1962a948153745a6749feb345403c68aaa9207388557ab9   # zip à signature PGP vérifiée (H. Muhammad)
LUACHECK_ROCK=1.2.0-1
BUSTED_ROCK=2.3.0-1

OUTILS="$PWD/.outils"
TMP="$OUTILS/tmp"
LUA="$OUTILS/lua54"
win() { cygpath -w "$1"; }

VSWHERE="/c/Program Files (x86)/Microsoft Visual Studio/Installer/vswhere.exe"
[[ -x "$VSWHERE" ]] || { echo "Visual Studio Build Tools introuvable (pas de vswhere.exe)"; exit 1; }
vs=$("$VSWHERE" -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath | tr -d '\r')
[[ -n "$vs" ]] || { echo "Outils C++ de Visual Studio absents (composant « MSVC x64 »)"; exit 1; }
VCVARS="$vs\\VC\\Auxiliary\\Build\\vcvars64.bat"

echo "== Téléchargement"
rm -rf "$OUTILS"; mkdir -p "$TMP"
curl -fsSL -o "$TMP/lua-$LUA_VERSION.tar.gz" "https://www.lua.org/ftp/lua-$LUA_VERSION.tar.gz"
curl -fsSL -o "$TMP/luarocks.zip" "https://luarocks.github.io/luarocks/releases/luarocks-$LUAROCKS_VERSION-windows-64.zip"
(cd "$TMP" && sha256sum -c) <<EOF
$LUA_SHA256  lua-$LUA_VERSION.tar.gz
$LUAROCKS_SHA256  luarocks.zip
EOF
tar -xzf "$TMP/lua-$LUA_VERSION.tar.gz" -C "$TMP"
unzip -q "$TMP/luarocks.zip" -d "$TMP"

echo "== Compilation de Lua $LUA_VERSION (MSVC, mêmes options que la compilation officielle)"
SRC="$TMP/lua-$LUA_VERSION/src"
cat > "$TMP/compiler.bat" <<EOF
@echo off
call "$VCVARS" >nul 2>nul || exit /b 1
cd /d "$(win "$SRC")" || exit /b 1
cl /nologo /MD /O2 /W3 /c /DLUA_BUILD_AS_DLL /DLUA_COMPAT_5_3 *.c >cl.log || (type cl.log & exit /b 1)
ren lua.obj lua.o || exit /b 1
del /q luac.obj
link /nologo /DLL /IMPLIB:lua54.lib /OUT:lua54.dll *.obj >nul || exit /b 1
link /nologo /OUT:lua.exe lua.o lua54.lib >nul || exit /b 1
EOF
cmd.exe //c "$(win "$TMP/compiler.bat")"
mkdir -p "$LUA/bin" "$LUA/include" "$LUA/lib"
cp "$SRC/lua.exe" "$LUA/bin/lua.exe"
cp "$SRC/lua.exe" "$LUA/bin/lua5.4.exe"
cp "$SRC/lua54.dll" "$LUA/bin/"
cp "$SRC/lua54.lib" "$LUA/lib/"
cp "$SRC"/{lua.h,luaconf.h,lualib.h,lauxlib.h,lua.hpp} "$LUA/include/"
cp "$TMP/luarocks-$LUAROCKS_VERSION-windows-64/luarocks.exe" "$LUA/bin/"

echo "== luacheck et busted"
cat > "$OUTILS/luarocks-config.lua" <<EOF
-- écrit par scripts/outils-windows.sh : tout reste dans .outils/
lua_version = "5.4"
local_cache = [[$(win "$OUTILS/cache")]]
rocks_trees = { { name = "outils", root = [[$(win "$OUTILS/rocks")]] } }
variables = {
    LUA_DIR = [[$(win "$LUA")]],
    LUA_BINDIR = [[$(win "$LUA/bin")]],
    LUA_INCDIR = [[$(win "$LUA/include")]],
    LUA_LIBDIR = [[$(win "$LUA/lib")]],
    LUALIB = "lua54.lib",
}
EOF
cat > "$TMP/rocks.bat" <<EOF
@echo off
call "$VCVARS" >nul 2>nul || exit /b 1
set "LUAROCKS_CONFIG=$(win "$OUTILS/luarocks-config.lua")"
"$(win "$LUA/bin/luarocks.exe")" install luacheck $LUACHECK_ROCK >nul || exit /b 1
"$(win "$LUA/bin/luarocks.exe")" install busted $BUSTED_ROCK >nul || exit /b 1
EOF
cmd.exe //c "$(win "$TMP/rocks.bat")"
rm -rf "$TMP" "$OUTILS/cache"

export PATH="$OUTILS/rocks/bin:$LUA/bin:$PATH"
lua -v
luacheck.bat --version | head -1
busted.bat --version
echo "OUTILS : OK (.outils/)"
