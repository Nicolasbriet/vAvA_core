# scripts/lib/manifeste.awk — lecteur des chaînes d'un fxmanifest.lua, partagé par scripts/audit-reseau.sh (règles des
# motifs livrés) et scripts/poids-client.sh (ce que télécharge un joueur), pour ne pas tenir deux lecteurs.
# Appel : awk -v Q="'" [-v MODE=liste] -f scripts/lib/manifeste.awk fxmanifest.lua…  (mawk et gawk)
#
# Lecture du Lua : commentaires de fin de ligne et blocs (`--[[ ]]`, `--[==[ ]==]`) ignorés, chaînes courtes et longues
# (`[[…]]`, `[==[…]==]`, sur plusieurs lignes) lues. Directives suivies : `files`, `file`, `ui_page`, `loadscreen`,
# `shared_script(s)`, `client_script(s)`, `server_script(s)`, en forme simple (`file 'x'`) ou en table (`{ … }`, tables
# imbriquées comprises). Chaque chaîne est normalisée (`\` → `/`, `./` et `/./` retirés, `//` réduit).
#
# MODE vide (audit) : une ligne par constat, « étiquette<TAB>chemin:ligne:contenu de la ligne où commence la chaîne »
# (une seule fois par étiquette et par ligne) :
#   W — (T-012) chaîne de `files`, `file`, `ui_page` ou `loadscreen` qui couvrirait web/dev/ : refusée si elle contient
#       `**`, ou si sa première partie peut valoir `web` et que sa deuxième peut valoir `dev` (`web/dev…`, `web/de?`,
#       `web/dev*`, `web/*`, `*/dev/x.js`) ou qu'une partie de dossier porte un joker (`web/*/x.js`) ;
#   C — (T-132) chaîne de `shared_script(s)`, `client_script(s)`, `files` ou `file` dont le motif couvre `config.lua`
#       (préfixe `@<ressource>/` retiré ; un motif `**/…` est aussi essayé sans ce préfixe) : config.lua servi aux
#       joueurs ;
#   S — (T-132) chaîne de `server_script(s)` qui couvre `config_client.lua` : il ne serait pas servi aux joueurs.
# MODE=liste : une ligne par chaîne, « chemin<TAB>client|serveur<TAB>directive<TAB>chaîne normalisée » (côté client :
# tout sauf `server_script(s)`).

function norm(m) {
    gsub(/\\/, "/", m)
    gsub(/\/\/+/, "/", m)
    while (gsub(/\/\.\//, "/", m)) {}
    while (sub(/^\.\//, "", m)) {}
    sub(/^\/+/, "", m)
    return m
}
function glob2re(g,    i, ch, r) {
    r = ""
    for (i = 1; i <= length(g); i++) {
        ch = substr(g, i, 1)
        if (ch == "*") r = r ".*"
        else if (ch == "?") r = r "."
        else if (ch == "[" && index(substr(g, i + 1), "]")) {
            r = r "["; i++
            if (substr(g, i, 1) == "!") { r = r "^"; i++ }
            while (substr(g, i, 1) != "]") { r = r substr(g, i, 1); i++ }
            r = r "]"
        }
        else if (ch ~ /[].[+^$(){}|]/) r = r "\\" ch
        else r = r ch
    }
    return "^" r "$"
}
function couvre(g, mot) { return mot ~ glob2re(g) }
function dangereux(m,    n, p, i) {
    m = norm(m)
    if (index(m, "**")) return 1
    n = split(m, p, "/")
    if (n < 2 || !couvre(p[1], "web")) return 0
    if (couvre(p[2], "dev")) return 1
    for (i = 1; i < n; i++) if (p[i] ~ /[*?[]/) return 1
    return 0
}
# vrai si le motif m (déjà normalisé, sans `@ressource/`) couvre le fichier `nom` à la racine de la ressource
function couvreRacine(m, nom) {
    if (couvre(m, nom)) return 1
    if (substr(m, 1, 3) == "**/" && couvre(substr(m, 4), nom)) return 1
    return 0
}
function suivie(mot) {
    return mot == "files" || mot == "file" || mot == "ui_page" || mot == "loadscreen" ||
        mot == "shared_script" || mot == "shared_scripts" || mot == "client_script" || mot == "client_scripts" ||
        mot == "server_script" || mot == "server_scripts"
}
function livre(d) { return d == "files" || d == "file" || d == "ui_page" || d == "loadscreen" }
function constat(etiquette) {
    if (!((etiquette, FILENAME ":" debut) in vu)) {
        vu[etiquette, FILENAME ":" debut] = 1
        print etiquette "\t" FILENAME ":" debut ":" ldebut
    }
}
function valeur(s,    d, m) {
    d = (prof > 0) ? dans : attente
    if (prof == 0) attente = ""
    if (d == "") return
    m = norm(s)
    if (MODE == "liste") {
        gsub(/\n/, "", m)
        print FILENAME "\t" (d ~ /^server_script/ ? "serveur" : "client") "\t" d "\t" m
        return
    }
    if (livre(d) && dangereux(s)) constat("W")
    sub(/^@[^\/]*\//, "", m)
    if ((d ~ /^(shared|client)_scripts?$/ || d == "files" || d == "file") && couvreRacine(m, "config.lua"))
        constat("C")
    if (d ~ /^server_scripts?$/ && couvreRacine(m, "config_client.lua")) constat("S")
}
FNR == 1 { mode = ""; ferme = ""; attente = ""; dans = ""; prof = 0; chaine = "" }
{
    l = $0; sub(/\r$/, "", l); n = length(l); i = 1
    while (i <= n) {
        if (mode != "") {   # dans un bloc de commentaire (C) ou une chaîne longue (L)
            k = index(substr(l, i), ferme)
            if (!k) { if (mode == "L") chaine = chaine substr(l, i) "\n"; break }
            if (mode == "L") valeur(chaine substr(l, i, k - 1))
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
            ferme = "]" substr(l, i + 1, RLENGTH - 2) "]"; mode = "L"; chaine = ""; debut = FNR; ldebut = l
            i += RLENGTH; continue
        }
        if (ch == "\"" || ch == Q) {
            j = i + 1; s = ""
            while (j <= n && substr(l, j, 1) != ch) {
                if (substr(l, j, 1) == "\\") { s = s substr(l, j, 2); j += 2 } else { s = s substr(l, j, 1); j++ }
            }
            debut = FNR; ldebut = l; valeur(s); i = j + 1; continue
        }
        if (ch ~ /[A-Za-z_]/) {
            match(substr(l, i), /^[A-Za-z_][A-Za-z0-9_]*/); mot = substr(l, i, RLENGTH); i += RLENGTH
            if (prof == 0) attente = suivie(mot) ? mot : ""
            continue
        }
        if (ch == "{") {
            if (prof > 0) prof++
            else if (attente != "") { prof = 1; dans = attente; attente = "" }
        }
        else if (ch == "}") { if (prof > 0) { prof--; if (prof == 0) dans = "" } }
        else if (ch !~ /[ \t(),;]/ && prof == 0) attente = ""
        i++
    }
}
