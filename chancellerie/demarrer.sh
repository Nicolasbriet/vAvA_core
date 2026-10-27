#!/usr/bin/env bash
# demarrer.sh — lance la Chancellerie (panneau web du serveur vAvA) sous Linux.
# Node.js est cherché d'abord à côté de ce fichier (node/bin/node), puis sur la machine ; absent ou plus ancien que
# NODE_MIN (le bot Discord utilise le WebSocket de Node 22), il est téléchargé depuis nodejs.org (version LTS fixée
# ci-dessous, empreinte SHA-256 vérifiée) dans node/. Téléchargement impossible : un Node.js NODE_FLOOR ou plus récent
# déjà installé sert quand même, sans le bot Discord.
# Code de sortie 75 : la Chancellerie vient de se mettre à jour et demande à être relancée. Si la nouvelle version
# s'arrête avant d'avoir démarré, l'ancienne est remise (data/updates/chancellerie-precedente) et relancée.
# Arrêt (Ctrl+C, systemd, panel d'hébergeur, ou « quit » sur l'entrée standard) : la Chancellerie arrête d'abord
# FXServer proprement (personnages sauvegardés).
# Chez un hébergeur (conteneur) : CHANCELLERIE_HOST=0.0.0.0 et CHANCELLERIE_PORT=<port attribué> fixent l'écoute du
# panneau ; la commande de démarrage est « exec bash ./chancellerie/demarrer.sh ».
#
#   bash demarrer.sh             lance la Chancellerie dans ce terminal
#   sudo bash demarrer.sh --service [utilisateur]
#                                l'installe comme service systemd (lancée au démarrage de la machine, relancée si elle
#                                tombe) ; utilisateur : celui qui la fera tourner (par défaut, celui qui a lancé sudo)

set -u
HOME_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
export CHANCELLERIE_HOME="$HOME_DIR"
cd "$HOME_DIR" || exit 1
NODE_VERSION="v22.23.4"
NODE_MIN=22
# plus ancienne version avec laquelle la Chancellerie démarre (sans le bot Discord)
NODE_FLOOR=18
UPDATES="$HOME_DIR/data/updates"
SERVICE_NAME="vava-chancellerie"

say() { printf '  %s\n' "$*"; }

# Service systemd ------------------------------------------------------------------------------------------------------

if [ "${1:-}" = "--service" ]; then
  if [ "$(id -u)" -ne 0 ]; then
    say "Il faut les droits root : sudo bash demarrer.sh --service"
    exit 1
  fi
  RUN_AS="${2:-${SUDO_USER:-root}}"
  if ! id "$RUN_AS" >/dev/null 2>&1; then
    say "Utilisateur inconnu : $RUN_AS"
    exit 1
  fi
  chown -R "$RUN_AS": "$HOME_DIR"
  cat > "/etc/systemd/system/$SERVICE_NAME.service" <<EOF
[Unit]
Description=La Chancellerie (panneau du serveur vAvA)
After=network-online.target mariadb.service mysql.service
Wants=network-online.target

[Service]
Type=simple
User=$RUN_AS
WorkingDirectory=$HOME_DIR
ExecStart=/usr/bin/env bash $HOME_DIR/demarrer.sh
# arrêt : seul le lanceur reçoit le signal ; il le passe à la Chancellerie, qui arrête FXServer proprement
KillMode=mixed
KillSignal=SIGTERM
TimeoutStopSec=90
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload
  systemctl enable --now "$SERVICE_NAME"
  say "Service $SERVICE_NAME installé et lancé (utilisateur $RUN_AS)."
  say "Code d'accès du premier lancement et messages : journalctl -u $SERVICE_NAME -f"
  say "Arrêter : sudo systemctl stop $SERVICE_NAME    Relancer : sudo systemctl restart $SERVICE_NAME"
  exit 0
fi

# Node.js --------------------------------------------------------------------------------------------------------------

# node_ok <exécutable> [version minimale, NODE_MIN par défaut]
node_ok() {
  local major
  major="$("$1" -p 'process.versions.node.split(".")[0]' 2>/dev/null)" || return 1
  [ -n "$major" ] && [ "$major" -ge "${2:-$NODE_MIN}" ]
}

fetch() {
  if command -v curl >/dev/null 2>&1; then curl -fsSL "$1" -o "$2"
  elif command -v wget >/dev/null 2>&1; then wget -q "$1" -O "$2"
  else return 1
  fi
}

download_node() {
  local arch name base tmp expected actual
  case "$(uname -m)" in
    x86_64|amd64) arch="x64" ;;
    aarch64|arm64) arch="arm64" ;;
    *) say "Processeur $(uname -m) : installez Node.js $NODE_MIN ou plus récent vous-même."; return 1 ;;
  esac
  name="node-$NODE_VERSION-linux-$arch"
  base="https://nodejs.org/dist/$NODE_VERSION"
  say "Node.js $NODE_MIN ou plus récent est introuvable : téléchargement de Node.js $NODE_VERSION depuis nodejs.org…"
  tmp="$(mktemp -d)" || return 1
  if ! fetch "$base/$name.tar.gz" "$tmp/node.tar.gz" || ! fetch "$base/SHASUMS256.txt" "$tmp/SHASUMS256.txt"; then
    say "Téléchargement impossible (curl ou wget, et l'accès à nodejs.org, sont nécessaires)."
    rm -rf "$tmp"
    return 1
  fi
  expected="$(grep " $name.tar.gz\$" "$tmp/SHASUMS256.txt" | awk '{print $1}')"
  actual="$(sha256sum "$tmp/node.tar.gz" | awk '{print $1}')"
  if [ -z "$expected" ] || [ "$expected" != "$actual" ]; then
    say "Empreinte de Node.js incorrecte : téléchargement refusé."
    rm -rf "$tmp"
    return 1
  fi
  rm -rf "$HOME_DIR/node"
  mkdir -p "$HOME_DIR/node"
  tar -xzf "$tmp/node.tar.gz" -C "$HOME_DIR/node" --strip-components=1
  rm -rf "$tmp"
  say "Node.js est installé dans node/."
}

NODE=""
if [ -x "$HOME_DIR/node/bin/node" ] && node_ok "$HOME_DIR/node/bin/node"; then NODE="$HOME_DIR/node/bin/node"
elif command -v node >/dev/null 2>&1 && node_ok "$(command -v node)"; then NODE="$(command -v node)"
elif download_node && node_ok "$HOME_DIR/node/bin/node"; then NODE="$HOME_DIR/node/bin/node"
else
  # secours : un Node.js plus ancien déjà là (le téléchargement n'a remplacé node/ que s'il a réussi)
  for candidate in "$HOME_DIR/node/bin/node" "$(command -v node 2>/dev/null)"; do
    if [ -n "$candidate" ] && [ -x "$candidate" ] && node_ok "$candidate" "$NODE_FLOOR"; then
      NODE="$candidate"
      say "Node.js $NODE_MIN n'a pas pu être téléchargé : la Chancellerie démarre avec Node.js $("$NODE" -v), sans le bot Discord."
      break
    fi
  done
fi
if [ -z "$NODE" ]; then
  say "Node.js $NODE_FLOOR ou plus récent est introuvable et Node.js $NODE_MIN n'a pas pu être téléchargé."
  say "Installez-le (https://nodejs.org/, version LTS) puis relancez."
  exit 1
fi

# Lancement ------------------------------------------------------------------------------------------------------------

CHILD=""
STOPPING=0
# arrêt (systemd, panel d'hébergeur, Ctrl+C) : le signal passe à la Chancellerie, qui s'arrête proprement. Dans un
# conteneur, seul ce lanceur reçoit le signal ; dans un terminal, Ctrl+C atteint aussi la Chancellerie directement :
# elle ignore ce doublon.
on_stop() {
  STOPPING=1
  [ -n "$CHILD" ] && kill -TERM "$CHILD" 2>/dev/null
}
trap on_stop TERM HUP INT

while true; do
  # l'entrée du lanceur passe à la Chancellerie (console d'un panel d'hébergeur : « quit » l'arrête proprement)
  "$NODE" "$HOME_DIR/index.js" <&0 &
  CHILD=$!
  # wait rend la main à chaque signal reçu (code > 128) : tant que la Chancellerie vit, on l'attend encore
  while true; do
    wait "$CHILD"
    CODE=$?
    if [ "$CODE" -gt 128 ] && kill -0 "$CHILD" 2>/dev/null; then continue; fi
    break
  done
  CHILD=""
  [ "$STOPPING" -eq 1 ] && break
  [ "$CODE" -eq 75 ] && continue
  if [ -f "$UPDATES/chancellerie-a-verifier" ]; then
    echo
    say "La nouvelle version de la Chancellerie n'a pas démarré : retour à la version précédente."
    # le lanceur en cours ne se réécrit pas : sa copie est écartée avant de tout remettre
    rm -f "$UPDATES/chancellerie-precedente/demarrer.sh"
    cp -a "$UPDATES/chancellerie-precedente/." "$HOME_DIR/"
    rm -f "$UPDATES/chancellerie-a-verifier"
    echo "annulee" > "$UPDATES/chancellerie-annulee"
    continue
  fi
  break
done
echo
say "La Chancellerie est arrêtée."
exit "$CODE"
