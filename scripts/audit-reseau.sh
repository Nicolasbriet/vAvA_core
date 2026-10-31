#!/usr/bin/env bash
# scripts/audit-reseau.sh — garde-fous statiques (motifs interdits). Ne remplace pas la relecture des agents.
# Usage : audit-reseau.sh [fichiers…]  (sans argument : tout le dépôt)
#         (manifestes lus : modules/*/fxmanifest.lua et examples/*/fxmanifest.lua, par scripts/lib/manifeste.awk)
#         audit-reseau.sh --essai      contrôles lancés sur les cas écrits de tests/audit/ (avec
#                                      tests/audit/exceptions.txt), comparés à ce que chaque ligne attend en fin de
#                                      ligne (« -- attendu: BLOQUANT | AVERTISSEMENT | rien ») ; code 1 au moindre écart.
#                                      Cas : *.lua (code Lua), fxmanifest.lua (motifs livrés, config), *.css, *.svg, *.html,
#                                      *.js (interfaces), chemins.txt (chemins fictifs de fichiers livrés, un par ligne),
#                                      exceptions.txt (une exception refusée est signalée sur sa ligne)
set -uo pipefail
cd "$(dirname "$0")/.."

ESSAI=0
if [[ "${1:-}" == "--essai" ]]; then ESSAI=1; shift; fi

# Exceptions justifiées : une par ligne « chemin<TAB>extrait exact du contenu de la ligne<TAB>raison » ; un chemin qui
# finit par « / » couvre les constats de fichier (« [fichier] ») de tout le dossier, et rien d'autre.
EXCEPTIONS="scripts/audit-exceptions.txt"
lua=(); web=(); chemins=(); manifestes=()
declare -A lieu_chemin=()   # essai : chemin fictif → « tests/audit/chemins.txt:ligne »
if [[ $ESSAI -eq 1 ]]; then
    EXCEPTIONS="tests/audit/exceptions.txt"
    for f in tests/audit/*.lua; do [[ -f "$f" ]] && lua+=("$f"); done
    for f in tests/audit/*.css tests/audit/*.svg tests/audit/*.html tests/audit/*.js; do [[ -f "$f" ]] && web+=("$f"); done
    [[ -f tests/audit/fxmanifest.lua ]] && manifestes+=(tests/audit/fxmanifest.lua)
    if [[ -f tests/audit/chemins.txt ]]; then
        n=0
        while IFS= read -r ligne || [[ -n "$ligne" ]]; do
            n=$((n + 1)); ligne="${ligne%$'\r'}"
            [[ -z "$ligne" || "$ligne" == \#* ]] && continue
            c="${ligne%%[[:space:]]*}"; chemins+=("$c"); lieu_chemin["$c"]="tests/audit/chemins.txt:$n"
        done < tests/audit/chemins.txt
    fi
else
    if [[ $# -gt 0 ]]; then fichiers=("$@"); else mapfile -t fichiers < <(git ls-files); fi
    for f in "${fichiers[@]}"; do
        [[ -f "$f" ]] || continue
        case "$f" in modules/*/web/*) chemins+=("$f") ;; esac
        case "$f" in modules/*/fxmanifest.lua|examples/*/fxmanifest.lua) manifestes+=("$f") ;; esac
        case "$f" in
            chancellerie/*|tests/*|examples/*) ;;
            *.lua) lua+=("$f") ;;
            */web/*.js|*/web/*.html|*/web/*.css|*/web/*.svg) web+=("$f") ;;
        esac
    done
fi

# Exceptions lues une fois. Refusées (signalées BLOQUANT, sans effet) : extrait vide (il couvrirait toute ligne du
# fichier) ; exception de dossier dont l'extrait n'est pas « [fichier] » (elle couvrirait le code de tout le dossier).
exc_chemin=(); exc_extrait=(); exc_invalides=""
if [[ -f "$EXCEPTIONS" ]]; then
    n=0
    while IFS= read -r ligne || [[ -n "$ligne" ]]; do
        n=$((n + 1)); ligne="${ligne%$'\r'}"   # fichier d'exceptions extrait en CRLF sous Windows
        [[ -z "$ligne" || "$ligne" == \#* ]] && continue
        chemin="${ligne%%$'\t'*}"; extrait=""
        if [[ "$ligne" == *$'\t'* ]]; then extrait="${ligne#*$'\t'}"; extrait="${extrait%%$'\t'*}"; fi
        if [[ -z "$chemin" || -z "$extrait" ]] || [[ "$chemin" == */ && "$extrait" != "[fichier]" ]]; then
            exc_invalides+="$EXCEPTIONS:$n:$ligne"$'\n'; continue
        fi
        exc_chemin+=("$chemin"); exc_extrait+=("$extrait")
    done < "$EXCEPTIONS"
fi

filtrer() { # retire les commentaires Lua (sauf « filtrer code » : déjà retirés par l'appelant) et les lignes couvertes par
            # une exception ou marquées « audit: ok » (sauf « filtrer code strict » : seules les exceptions du fichier
            # comptent, pour les règles des manifestes ; relecture sécurité S-2 de T-132)
    local deja="${1:-}" strict="${2:-}"
    local ligne contenu chemin extrait garde i
    while IFS= read -r ligne; do
        [[ -z "$ligne" ]] && continue
        [[ -z "$strict" && "$ligne" == *"audit: ok"* ]] && continue
        contenu="${ligne#*:}"; contenu="${contenu#*:}"   # « chemin:ligne:contenu » (grep -H)
        [[ -z "$deja" && "$contenu" =~ ^[[:space:]]*-- ]] && continue
        garde=1
        for i in "${!exc_chemin[@]}"; do
            chemin="${exc_chemin[$i]}"; extrait="${exc_extrait[$i]}"
            if [[ "$chemin" == */ ]]; then
                if [[ "$ligne" == "$chemin"* && "$contenu" == "$extrait "* ]]; then garde=0; break; fi
            elif [[ "$ligne" == "$chemin:"* && "$contenu" == *"$extrait"* ]]; then garde=0; break; fi
        done
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

noter BLOQUANT "exception refusée (extrait vide, ou dossier dont l'extrait n'est pas [fichier]) : elle ne couvre rien" \
    "${exc_invalides%$'\n'}"

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

# --- Abonnements de zone (T-014) : les évènements vAvA:zone:* sont envoyés et écoutés par le seul core. Un module qui
# les nomme (envoi, écoute, déclenchement local) contourne core.zones : interdit dans modules/ (et dans les cas d'essai).
zone_lua=(); for f in "${lua[@]}"; do [[ $ESSAI -eq 1 || "$f" == modules/* ]] && zone_lua+=("$f"); done
if [[ ${#zone_lua[@]} -gt 0 ]]; then
    res=$(grep -HnE 'vAvA:zone:' "${zone_lua[@]}" 2>/dev/null | filtrer || true)
    noter BLOQUANT "évènement des abonnements de zone (vAvA:zone:*) nommé par un module : passer par core.zones" "$res"
fi
# --- fin du bloc T-014

signal AVERTISSEMENT 'GlobalState\[[^]]+\][[:space:]]*=' "écriture GlobalState (envoyée à TOUS les joueurs : petite, rare, utile à tous ?)"
signal AVERTISSEMENT 'Wait\(0\)' "Wait(0) : uniquement pendant un état actif temporaire"
signal AVERTISSEMENT 'GetGamePool' "GetGamePool : à éviter dans une boucle"

# --- Classe %c (T-133) : elle suit la locale du système (sous Windows, elle prend aussi les octets 0x81, 0x8D, 0x8F,
# 0x90, 0x9D, 0xAD de « Á », « Í », « í »… et laisse passer les contrôles C1). Cherchée dans les seules chaînes du code
# Lua (commentaires retirés, `--[[ … ]]` compris ; chaînes longues lues) : un nombre impair de % devant le c compte
# (`%%c` est un « %c » littéral). Écrire les contrôles octet par octet : '[\0-\31\127]'.
CLASSE_C_AWK='
function chaine(s) { if (s ~ /(^|[^%])(%%)*%c/) { print FILENAME ":" FNR ":" ligne; vu = 1 } }
FNR == 1 { mode = "" }
{
    l = $0; sub(/\r$/, "", l); ligne = l; n = length(l); i = 1; vu = 0
    while (i <= n && !vu) {
        if (mode == "C" || mode == "L") {
            k = index(substr(l, i), ferme)
            if (!k) { if (mode == "L") chaine(substr(l, i)); break }
            if (mode == "L") chaine(substr(l, i, k - 1))
            i += k - 1 + length(ferme); mode = ""; continue
        }
        ch = substr(l, i, 1)
        if (ch == "-" && substr(l, i + 1, 1) == "-") {
            if (match(substr(l, i + 2), /^\[=*\[/)) {
                ferme = "]" substr(l, i + 3, RLENGTH - 2) "]"; mode = "C"; i += 2 + RLENGTH; continue
            }
            break
        }
        if (ch == "[" && match(substr(l, i), /^\[=*\[/)) {
            ferme = "]" substr(l, i + 1, RLENGTH - 2) "]"; mode = "L"; i += RLENGTH; continue
        }
        if (ch == "\"" || ch == Q) {
            j = i + 1; s = ""
            while (j <= n && substr(l, j, 1) != ch) {
                if (substr(l, j, 1) == "\\") { s = s substr(l, j, 2); j += 2 } else { s = s substr(l, j, 1); j++ }
            }
            chaine(s); i = j + 1; continue
        }
        i++
    }
}
'
if [[ ${#lua[@]} -gt 0 ]]; then
    res=$(awk -v Q="'" "$CLASSE_C_AWK" "${lua[@]}" 2>/dev/null | filtrer code || true)
    noter BLOQUANT "classe %c dans un motif : elle suit la locale (« Á », « í » coupés sous Windows) ; écrire '[\\0-\\31\\127]'" "$res"
fi
# --- fin du bloc T-133

# Adresse externe dans une interface : cherchée après avoir retiré les seules sous-chaînes permises — espaces de noms
# (`xmlns="http://www.w3.org/…"`, guillemets simples ou doubles ; la chaîne exacte 'http://www.w3.org/2000/svg' et
# ses sœurs xlink et xhtml), rappels NUI exacts (`https://cfx-nui-<ressource>/`, `https://${resource}/`,
# `https://${GetParentResourceName()}/`). Le reste de la ligne compte toujours. Cherchés : `http(s)://`, `ws(s)://`,
# et les adresses sans protocole (`src=//…`, `href=//…`, `url(//…)`).
EXTERNE_AWK='
{
    l = $0; sub(/\r$/, "", l); c = l
    gsub("xmlns(:[A-Za-z]+)?=[\"" Q "]http://www[.]w3[.]org/[^\"" Q "]*[\"" Q "]", "", c)
    gsub("[\"" Q "]http://www[.]w3[.]org/(2000/svg|1999/xlink|1999/xhtml)[\"" Q "]", "", c)
    gsub(/https:\/\/cfx-nui-[A-Za-z0-9_-]+\//, "", c)
    gsub(/https:\/\/[$][{]resource[}]\//, "", c)
    gsub(/https:\/\/[$][{]GetParentResourceName[(][)][}]\//, "", c)
    if (c ~ /(https?|wss?):\/\// || c ~ ("(src|href)[ \t]*=[ \t]*[\"" Q "]?//") || c ~ ("url[(][ \t]*[\"" Q "]?//"))
        print FILENAME ":" FNR ":" l
}
'
if [[ ${#web[@]} -gt 0 ]]; then
    res=$(awk -v Q="'" "$EXTERNE_AWK" "${web[@]}" 2>/dev/null | filtrer || true)
    noter BLOQUANT "ressource externe dans une interface" "$res"
    res=$(grep -HnE '\.innerHTML[[:space:]]*\+?=' "${web[@]}" 2>/dev/null | filtrer || true)
    noter AVERTISSEMENT "innerHTML : jamais avec une donnée venant d'un joueur (marquer '// audit: ok' si sûr)" "$res"
    svgs=(); for f in "${web[@]}"; do [[ "$f" == *.svg ]] && svgs+=("$f"); done
    if [[ ${#svgs[@]} -gt 0 ]]; then
        res=$(grep -HniE '<script|foreignObject|(^|[[:space:]])on[a-z]+[[:space:]]*=|javascript:' "${svgs[@]}" 2>/dev/null | filtrer || true)
        noter BLOQUANT "SVG actif dans une interface (script, foreignObject, attribut on…= ou javascript:)" "$res"
    fi
fi

# Fichiers communs des interfaces (T-012) : polices, textures et ornements communs vivent dans vava_ui seul ; les
# données simulées d'une page (devmock.js) restent dans web/dev/, qu'aucun motif `files` ne livre. Un constat de
# fichier s'écrit « chemin:1:[fichier] chemin » (une exception de dossier : « modules/x/web/<TAB>[fichier]<TAB>… »).
relocaliser() { # essai : ramène un chemin fictif à sa ligne de tests/audit/chemins.txt
    local l c
    while IFS= read -r l; do
        [[ -z "$l" ]] && continue
        if [[ $ESSAI -eq 1 ]]; then c="${l%%:1:\[fichier\] *}"; printf '%s:%s\n' "${lieu_chemin[$c]:-$c:1}" "${l#*:1:}"
        else printf '%s\n' "$l"; fi
    done
}
if [[ ${#chemins[@]} -gt 0 ]]; then
    devmocks=""; copies=""
    # données simulées : partout sauf directement sous modules/<module>/web/dev/ (vava_ui compris) ; polices : partout
    # sous web/ hors de vava_ui ; textures et ornements communs : sous web/fonts/ et web/img/ hors de vava_ui (un
    # web/items/paper.svg propre à un module reste permis)
    for c in "${chemins[@]}"; do
        nom="${c##*/}"
        if [[ "$nom" == *devmock*.js && ! "$c" =~ ^modules/[^/]+/web/dev/ ]]; then devmocks+="$c:1:[fichier] $c"$'\n'; fi
        [[ "$c" =~ ^modules/vava_ui/ ]] && continue
        case "$nom" in
            *.woff2|*.woff|*.ttf|*.otf) copies+="$c:1:[fichier] $c"$'\n' ;;
            grain.*|paper.*|frame.svg|divider.svg|diamond.svg)
                [[ "$c" =~ ^modules/[^/]+/web/(fonts|img)/ ]] && copies+="$c:1:[fichier] $c"$'\n' ;;
        esac
    done
    noter BLOQUANT "données simulées livrées aux joueurs (les mettre dans web/dev/, hors des files) (T-012)" \
        "$(printf '%s' "$devmocks" | filtrer | relocaliser || true)"
    noter BLOQUANT "police ou texture commune hors de vava_ui (la prendre par nui://vava_ui/…, T-012)" \
        "$(printf '%s' "$copies" | filtrer | relocaliser || true)"
fi

# Motifs des manifestes, lus par scripts/lib/manifeste.awk (partagé avec scripts/poids-client.sh ; règles détaillées
# en tête du fichier). Lecture du Lua : commentaires ignorés, chaînes courtes et longues lues ; chaque chaîne est
# normalisée (`\` → `/`, `./` et `/./` retirés, `//` réduit). Constats par étiquette :
#  W — (T-012) chaîne de `files`, `file`, `ui_page` ou `loadscreen` qui couvrirait web/dev/ (`**`, `web/dev…`,
#      `web/*`, `*/dev/x.js`, joker dans un dossier sous web/) ;
#  C — (T-132) `config.lua` couvert par une chaîne de `shared_script(s)`, `client_script(s)`, `files`, `file`,
#      `ui_page` ou `loadscreen` (sans tenir compte de la casse) ;
#  S — (T-132) `config_client.lua` couvert par une chaîne de `server_script(s)` ;
#  D — (T-132) chemin qui sort de la ressource (`..` de trop) ;
#  X — (T-132) directive suivie d'autre chose qu'une chaîne ou une table de chaînes (illisible, donc refusée).
# Pour W, « audit: ok » ne fait rien taire : seules les exceptions du fichier comptent. C, S, D et X ne se taisent
# jamais, ni par « audit: ok » ni par une exception : les exceptions transitoires des lots de T-132 sont toutes retirées
# (T-143), aucun manifeste n'a plus de raison d'en avoir.
if [[ ${#manifestes[@]} -gt 0 ]]; then
    lus=$(awk -v Q="'" -f scripts/lib/manifeste.awk "${manifestes[@]}" 2>/dev/null || true)
    # « audit: ok » ne fait rien taire ici : seules les exceptions de scripts/audit-exceptions.txt comptent (S-2), et
    # pour W seulement ; C, S, D, X : rien ne les fait taire (T-143)
    etiquette() { printf '%s\n' "$lus" | sed -n "s/^$1"$'\t'"//p" | filtrer code strict || true; }
    etiquette_stricte() { printf '%s\n' "$lus" | sed -n "s/^$1"$'\t'"//p" || true; }
    noter BLOQUANT "motif livré qui couvrirait web/dev/ (données simulées) : ni web/dev, ni **, ni joker dans un dossier sous web/ (T-012)" \
        "$(etiquette W)"
    noter BLOQUANT "config.lua servi aux joueurs : il est réservé au serveur ; ce que le client lit va dans config_client.lua (T-132)" \
        "$(etiquette_stricte C)"
    noter BLOQUANT "config_client.lua servi au seul serveur : les joueurs ne le recevraient pas (shared_scripts, ou client_scripts pour un module sans partie serveur) (T-132)" \
        "$(etiquette_stricte S)"
    noter BLOQUANT "motif qui sort de la ressource (.. de trop) (T-132)" "$(etiquette_stricte D)"
    noter BLOQUANT "directive suivie d'autre chose qu'une chaîne ou une table de chaînes (nom, concaténation, appel) : écrire chaque chemin en toutes lettres (T-132)" \
        "$(etiquette_stricte X)"
fi

if [[ $ESSAI -eq 1 ]]; then
    # attendus : « chemin:ligne<TAB>NIVEAU » (rien : aucun constat permis sur la ligne)
    declare -A attendu=() trouve=()
    cas=0; ecarts=0
    while IFS= read -r ligne; do
        [[ -z "$ligne" ]] && continue
        position="${ligne%%:-- attendu:*}"; niveau="${ligne##*-- attendu: }"; niveau="${niveau%%[[:space:]]*}"
        attendu["$position"]="$niveau"; cas=$((cas + 1))
    done < <(grep -HnoE -- '-- attendu: (BLOQUANT|AVERTISSEMENT|rien)' "${lua[@]}" "${web[@]}" \
        "${manifestes[@]}" tests/audit/chemins.txt "$EXCEPTIONS" 2>/dev/null | sort -u || true)
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
