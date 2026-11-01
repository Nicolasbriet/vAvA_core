'use strict';
/*
 * tests/livraison/essais.js
 * Rôle : essais de l'allègement du Lua livré (T-154, docs/plan/specs/T-154.md § 12.1), lancés par scripts/verifier.sh
 *        (node, module assert intégré, sans dépendance) : lexeur (chancellerie/lib/luastrip.js), lecture des manifestes
 *        et allègement d'une copie (lib/delivery.js), fusion de l'installeur sur des fichiers allégés, garde-fous de
 *        scripts/livraison.js. Écrit seulement dans des dossiers temporaires. « ESSAIS LIVRAISON : OK (n) », code 1 au
 *        premier échec.
 * Dépendances : node ≥ 18.
 */

const assert = require('assert');
const fs = require('fs');
const os = require('os');
const path = require('path');
const http = require('http');
const { spawnSync, execFileSync } = require('child_process');

const ROOT = path.resolve(__dirname, '..', '..');
const TMP = fs.mkdtempSync(path.join(os.tmpdir(), 'vava-livraison-'));
process.env.CHANCELLERIE_HOME = path.join(TMP, 'chancellerie');   // l'installeur ne lit ni n'écrit rien d'autre

const luastrip = require('../../chancellerie/lib/luastrip');
const delivery = require('../../chancellerie/lib/delivery');
const installer = require('../../chancellerie/lib/installer');
const dl = require('../../chancellerie/lib/download');
const livraison = require('../../scripts/livraison');

let count = 0;
function fail(name, error) {
  process.stdout.write(`ÉCHEC ${name}\n${error.stack || error.message}\n`);
  fs.rmSync(TMP, { recursive: true, force: true });
  process.exit(1);
}
function essai(name, fn) {
  try {
    fn();
    count += 1;
  } catch (error) {
    fail(name, error);
  }
}
async function essaiAsync(name, fn) {
  try {
    await fn();
    count += 1;
  } catch (error) {
    fail(name, error);
  }
}

// texte UTF-8 → texte d'octets (comme un fichier lu en latin1), et retour
const bytes = (s) => Buffer.from(s, 'utf8').toString('latin1');
const utf8 = (s) => Buffer.from(s, 'latin1').toString('utf8');
const newlines = (s) => (s.match(/\r\n|\n\r|\n|\r/g) || []).length;
function lean(input) {
  const result = luastrip.strip(bytes(input));
  if (!result.ok) return result;
  return { ...result, text: utf8(result.text) };
}

// Lexeur : sorties exactes (§ 12.1, cas 1 à 28) ----------------------------------------------------------------------

const BOM = '﻿';
const CASES = [
  [1, 'local a = 1 -- note\n', 'local a = 1\n'],
  [2, '--[[ en-tête\n  sur deux lignes ]]\nlocal a = 1\n', '\n\nlocal a = 1\n'],
  [3, 'local s = "a -- b" -- c\n', 'local s = "a -- b"\n'],
  [4, 'local s = \'--[[ pas un commentaire ]]\'\n', null],
  [5, 'local s = [[ -- dedans\n]] -- dehors\n', 'local s = [[ -- dedans\n]]\n'],
  [6, 'local s = [==[ ]] ]=] ]==] x = 1\n', null],
  [7, '--[==[ ]] ]=] ]==]x = 1\n', ' x = 1\n'],
  [8, 'local x = a--[[c]]or b\n', 'local x = a or b\n'],
  [9, 'local t = "\\\\" -- c\n', 'local t = "\\\\"\n'],
  [10, "local t = 'l\\'a -- ici' -- c\n", "local t = 'l\\'a -- ici'\n"],
  [11, 'local s = "a\\z\n   -- dans la chaîne"\n', null],
  [12, 'local s = "a\\\n-- dans la chaîne"\n', null],
  [13, 'x = 1 ---[[ court\ny = 2\n--]]\n', 'x = 1\ny = 2\n\n'],
  [14, '--[ court\n--[=x court\n', '\n\n'],
  [16, `${BOM}-- c\nx = 1\n`, `${BOM}\nx = 1\n`],
  [17, 'a = 1 -- c\r\nb = 2\r\n--[[ x\r\n y ]]\r\n', 'a = 1\r\nb = 2\r\n\r\n\r\n'],
  [18, 'a = 1   \t\n', 'a = 1\n'],
  [18, 's = [[a   \n]]\n', null],
  [19, 'x = 1--2\n', 'x = 1\n'],
  [19, 'x = 0x1p-4 -- c\n', 'x = 0x1p-4\n'],
  [19, 'x = 1e-5--c\n', 'x = 1e-5\n'],
  [20, 'h = `a -- b` -- c\n', 'h = `a -- b`\n'],
  [21, '\t\tlocal a = 1 -- c\n', '\t\tlocal a = 1\n'],
  [22, 'x = a - b -- c\n', 'x = a - b\n'],
  [22, 'x = a - -b\n', null],
  [23, 'x = 1 --', 'x = 1'],
  [24, '--[=[ ]] ]=]x = 1\n', ' x = 1\n'],
  [25, 'a = 1 --[[ x ]] + 2\n', 'a = 1  + 2\n'],
  [26, '', ''],
  [26, '-- a\n-- b\n-- c\n', '\n\n\n'],
  [28, 'local é = 1 -- c\n', 'local é = 1\n'],
  // compléments : fins de ligne échappées en CRLF, \z sur plusieurs lignes, \n\r compté pour une
  [29, 'local s = "a\\\r\n-- dans la chaîne" -- c\r\n', 'local s = "a\\\r\n-- dans la chaîne"\r\n'],
  [29, 'local s = "a\\z\r\n\r\n  -- encore" -- c\n', 'local s = "a\\z\r\n\r\n  -- encore"\n'],
  [29, 'a = 1 -- c\n\rb = 2\n', 'a = 1\n\rb = 2\n'],
  [29, 'local x = 1 --[==[ a\n]] ]=] b ]==] + 2 -- c\n', 'local x = 1\n + 2\n'],
];
for (const [n, input, expected] of CASES) {
  essai(`lexeur, cas ${n} : ${JSON.stringify(input)}`, () => {
    const result = lean(input);
    assert.strictEqual(result.ok, true, result.reason);
    assert.strictEqual(result.text, expected === null ? input : expected);
    assert.strictEqual(newlines(result.text), newlines(input), 'nombre de fins de ligne');
  });
}

const ERRORS = [
  ['s = "abc\n', 1, 'chaîne non fermée'],
  ['s = [[abc', 1, 'chaîne longue non fermée'],
  ['--[[ abc', 1, 'commentaire long non fermé'],
  ["s = 'abc", 1, 'chaîne non fermée'],
  ['x = 1\ny = 2\ns = [==[ a ]] ]=]\n', 3, 'chaîne longue non fermée'],
  ['s = "a\\', 1, 'chaîne non fermée'],
  // relecture sécurité S-1 : une première ligne `#` est refusée (Lua la finit au seul `\n`), BOM ou non
  ['#!/usr/bin/lua\n-- c\nx = 1\n', 1, 'première ligne « # » refusée'],
  [`${BOM}#!/usr/bin/lua\r\nx = 1 -- c\r\n`, 1, 'première ligne « # » refusée'],
  // relecture sécurité S-7 : `/*` hors chaîne et hors commentaire (commentaire de CfxLua)
  ['x = 1\ny = 2 /* c -- */\n', 2, '« /* » hors chaîne (syntaxe de CfxLua)'],
  ['x = a/*b*/c\n', 1, '« /* » hors chaîne (syntaxe de CfxLua)'],
];
for (const [input, line, reason] of ERRORS) {
  essai(`lexeur, refus : ${JSON.stringify(input)}`, () => {
    const result = lean(input);
    assert.strictEqual(result.ok, false);
    assert.strictEqual(result.line, line);
    assert.strictEqual(result.reason, reason);
  });
}

essai('lexeur : nombres lus comme read_numeral (exposant signé, hexadécimal, lettre collée)', () => {
  const kinds = (s) => luastrip.scan(s).filter((e) => e.kind !== 'ws').map((e) => `${e.kind}:${s.slice(e.start, e.end)}`);
  assert.deepStrictEqual(kinds('1e-5--c'), ['number:1e-5', 'comment:--c']);
  assert.deepStrictEqual(kinds('0x1p-4'), ['number:0x1p-4']);
  assert.deepStrictEqual(kinds('3.5E+2 .5 0xA.8P1'), ['number:3.5E+2', 'number:.5', 'number:0xA.8P1']);
  assert.deepStrictEqual(kinds('1--2'), ['number:1', 'comment:--2']);
  assert.deepStrictEqual(kinds('0x1e-2'), ['number:0x1e', 'punct:-', 'number:2']);
  assert.deepStrictEqual(kinds('12abc'), ['number:12abc']);
  assert.deepStrictEqual(kinds('a.b..c'), ['name:a', 'punct:.', 'name:b', 'punct:.', 'punct:.', 'name:c']);
});

essai('lexeur : `#` et `/*` acceptés dans une chaîne ou un commentaire, `/` seul accepté (S-1, S-7)', () => {
  for (const ok of ['x = "/*" -- /* c\n', "x = '#' --[[ /* ]]\n", 'x = a / b // c\n', '\n#t\n', 'x = [[/*]]\n']) {
    const result = lean(ok);
    assert.strictEqual(result.ok, true, ok);
  }
});

essai('lexeur : un commentaire court en fin de fichier, une chaîne longue en clé', () => {
  assert.strictEqual(lean('t[ [[k]] ] = #"--" --[[x]]').text, 't[ [[k]] ] = #"--"');
});

essai('signature : lexèmes collés, ligne, commentaires ignorés', () => {
  assert.notDeepStrictEqual(luastrip.signature('a or b'), luastrip.signature('aor b'));
  assert.notDeepStrictEqual(luastrip.signature('a\nb'), luastrip.signature('a b'));
  assert.deepStrictEqual(luastrip.signature('x = 1 -- c'), luastrip.signature('x = 1'));
  assert.notDeepStrictEqual(luastrip.signature('x = a == b'), luastrip.signature('x = a = = b'));
  assert.strictEqual(luastrip.signature('s = "abc'), null);
});

essai('contrôle : un allègement faussé est refusé', () => {
  // doublures d'un allègement fautif : deux lexèmes collés, un lexème changé de ligne, une fin de ligne perdue, une
  // chaîne coupée
  const bad = [
    ['local x = a--[[c]]or b\n', 'local x = aor b\n'],
    ['a = 1\nb = 2\n', 'a = 1 b = 2\n\n'],
    ['a = 1 -- c\n\nb = 2\n', 'a = 1\nb = 2\n'],
    ['s = "a -- b"\n', 's = "a \n'],
  ];
  for (const [original, faulty] of bad) {
    const result = luastrip.control(original, faulty);
    assert.strictEqual(result.ok, false, faulty);
    assert.strictEqual(result.reason, 'contrôle après allègement');
  }
  assert.strictEqual(luastrip.control('local x = a--[[c]]or b\n', 'local x = a or b\n').ok, true);
});

essai('lexeur : cas_difficiles.lua s\'allège, l\'original n\'est pas touché', () => {
  const file = path.join(ROOT, 'tests', 'livraison', 'cas_difficiles.lua');
  const before = fs.readFileSync(file);
  const result = luastrip.strip(before.toString('latin1'));
  assert.strictEqual(result.ok, true, result.reason);
  assert.ok(result.removed > 0);
  assert.ok(fs.readFileSync(file).equals(before));
});

// Lecture des manifestes (servedLua) ----------------------------------------------------------------------------------

function tree(dir, files) {
  for (const [relative, content] of Object.entries(files)) {
    const file = path.join(dir, relative);
    fs.mkdirSync(path.dirname(file), { recursive: true });
    fs.writeFileSync(file, content);
  }
  return dir;
}
const listOf = (served) => served.files.map((f) => `${f.council ? '@' : ''}${f.path}:${f.state}`);
const LUA = '-- commentaire\nlocal x = 1 -- fin\nreturn x\n';

const plain = tree(path.join(TMP, 'res', 'plain'), {
  'fxmanifest.lua': [
    '-- en-tête',
    "fx_version 'cerulean'",
    "shared_script 'a.lua'",
    'shared_scripts { \'b.lua\', "c.lua" }',
    "client_scripts({ 'd.lua' })",
    'client_script [[e.lua]]',
    "client_scripts { { 'f.lua' } }",
    "server_scripts { 'g.lua', 'srv.lua' }",
    "client_script 'g.lua'",
    "shared_scripts { 'config_client.lua', 'config.lua', 'config/shared.lua' }",
    "files { 'h.lua', 'web/x.js' }",
    "client_scripts { '@autre/i.lua', '../j.lua', './k.lua', 'l\\\\m.lua' }",
    "client_scripts { 'client/*.lua' }",
    "shared_scripts { 'sh/**/*.lua' }",
    "-- client_script 'n.lua'",
    "--[[ client_script 'o.lua' ]]",
    "dependencies { 'vAvA_core', nom }",
    '',
  ].join('\n'),
  'a.lua': LUA, 'b.lua': LUA, 'c.lua': LUA, 'd.lua': LUA, 'e.lua': LUA, 'f.lua': LUA, 'g.lua': LUA, 'srv.lua': LUA,
  'config_client.lua': LUA, 'config.lua': LUA, 'config/shared.lua': LUA, 'h.lua': LUA, 'web/x.js': '// x\n',
  'k.lua': LUA, 'l/m.lua': LUA, 'client/x.lua': LUA, 'client/sous/y.lua': LUA, 'sh/z.lua': LUA,
  'sh/deep/w.lua': LUA, 'sh/.cache/v.lua': LUA, 'n.lua': LUA, 'o.lua': LUA,
});
tree(path.join(TMP, 'res'), { 'j.lua': LUA });

essai('manifeste : formes simples, tables, réglages, files, chemins, jokers, commentaires', () => {
  const served = delivery.servedLua(plain);
  assert.strictEqual(served.ok, true, served.reason);
  assert.deepStrictEqual(listOf(served), [
    'fxmanifest.lua:lean', 'a.lua:lean', 'b.lua:lean', 'c.lua:lean', 'd.lua:lean', 'e.lua:lean', 'f.lua:lean',
    'g.lua:lean', 'config_client.lua:kept-config', 'config.lua:kept-config', 'config/shared.lua:kept-config',
    'h.lua:kept-files', 'k.lua:lean', 'l/m.lua:lean', 'client/x.lua:lean', 'sh/deep/w.lua:lean', 'sh/z.lua:lean',
  ]);
});

essai('manifeste : `client/**/*.lua` prend aussi les sous-dossiers', () => {
  const dir = tree(path.join(TMP, 'res', 'globstar'), {
    'fxmanifest.lua': "client_scripts { 'client/**/*.lua' }\n", 'client/x.lua': LUA, 'client/sous/y.lua': LUA,
  });
  assert.deepStrictEqual(listOf(delivery.servedLua(dir)), ['fxmanifest.lua:lean', 'client/sous/y.lua:lean', 'client/x.lua:lean']);
  // `**` ne suit pas un lien (ici une boucle vers la ressource elle-même), comme bash
  fs.symlinkSync(dir, path.join(dir, 'client', 'boucle'), 'junction');
  assert.deepStrictEqual(listOf(delivery.servedLua(dir)), ['fxmanifest.lua:lean', 'client/sous/y.lua:lean', 'client/x.lua:lean']);
});

const UNREADABLE = [
  "client_scripts { nom }\n",
  "client_script 'a' .. 'b.lua'\n",
  "client_script(liste())\n",
  "vava_conseil_lua { nom }\n",
  "shared_scripts liste\n",
  "client_scripts { 'client/' .. 'a.lua' }\n",
];
UNREADABLE.forEach((manifest, k) => {
  essai(`manifeste illisible : ${JSON.stringify(manifest)}`, () => {
    const dir = tree(path.join(TMP, 'res', `illisible${k}`), { 'fxmanifest.lua': manifest, 'a.lua': LUA });
    const served = delivery.servedLua(dir);
    assert.strictEqual(served.ok, false);
    assert.match(served.reason, /forme illisible/);
  });
});

const council = tree(path.join(TMP, 'res', 'conseil'), {
  'fxmanifest.lua': [
    "shared_scripts { 'shared/p.lua' }",
    "server_scripts { 'config_conseil.lua', 'config.lua' }",
    '-- T-157 : code du seul Conseil',
    'vava_conseil_lua {',
    "    'config_conseil.lua',",
    "    'shared/p.lua',",
    "    'client/q.lua',",
    '}',
    "vava_conseil_lua 'config.lua'",
    "vava_conseil_lua 'config_client.lua'",
    "vava_conseil_lua 'client/r.lua'",
    "vava_conseil_web { 'web/js/a.js', 'web/css/b.css' }",
    '',
  ].join('\n'),
  'shared/p.lua': LUA, 'config_conseil.lua': LUA, 'config.lua': LUA, 'config_client.lua': LUA, 'client/q.lua': LUA,
  'client/r.lua': LUA, 'web/js/a.js': '// a\n', 'web/css/b.css': '/* b */\n',
});

essai('manifeste : paquet du Conseil (vava_conseil_lua) allégé, réglages gardés (config_conseil.lua compris)', () => {
  assert.deepStrictEqual(listOf(delivery.servedLua(council)), [
    'fxmanifest.lua:lean', 'shared/p.lua:lean', '@config_conseil.lua:kept-config', '@shared/p.lua:lean', '@client/q.lua:lean',
    '@config.lua:kept-config', '@config_client.lua:kept-config', '@client/r.lua:lean',
  ]);
});

// Allègement d'une copie (leanResources) ------------------------------------------------------------------------------

essai('allègement : fichiers servis allégés une fois, le reste intact', () => {
  const summary = delivery.leanResources([{ name: 'conseil', dir: council }]);
  assert.deepStrictEqual(summary.refused, []);
  assert.deepStrictEqual(summary.skipped, []);
  assert.strictEqual(summary.files, 4);   // manifeste, shared/p, client/q, client/r
  const read = (relative) => fs.readFileSync(path.join(council, relative), 'utf8');
  assert.strictEqual(read('shared/p.lua'), '\nlocal x = 1\nreturn x\n');
  assert.strictEqual(read('config_conseil.lua'), LUA);   // réglage de l'exploitant (relecture réseau R-5 de T-157)
  assert.strictEqual(read('config.lua'), LUA);
  assert.strictEqual(read('config_client.lua'), LUA);
  assert.strictEqual(read('web/js/a.js'), '// a\n');
  assert.ok(!read('fxmanifest.lua').includes('T-157'));
  assert.strictEqual(newlines(read('fxmanifest.lua')), 12);
});

essai('allègement : manifeste illisible, fichier refusé, fichier trop gros, lien hors de la ressource', () => {
  const unreadable = tree(path.join(TMP, 'res', 'skip'), { 'fxmanifest.lua': "client_scripts { nom } -- c\n", 'a.lua': LUA });
  const broken = '-- c\nlocal s = "non fermée\n';
  const big = `-- ${'x'.repeat(delivery.MAX_BYTES)}\n`;
  const refused = tree(path.join(TMP, 'res', 'refus'), {
    'fxmanifest.lua': "client_scripts { 'a.lua', 'b.lua', 'grand.lua', 'lien/c.lua' }\n",
    'a.lua': broken, 'b.lua': LUA, 'grand.lua': big,
  });
  const outside = tree(path.join(TMP, 'dehors'), { 'c.lua': LUA });
  fs.symlinkSync(outside, path.join(refused, 'lien'), 'junction');
  const summary = delivery.leanResources([{ name: 'skip', dir: unreadable }, { name: 'refus', dir: refused }]);
  assert.deepStrictEqual(summary.skipped.map((s) => s.resource), ['skip']);
  assert.strictEqual(fs.readFileSync(path.join(unreadable, 'fxmanifest.lua'), 'utf8'), "client_scripts { nom } -- c\n");
  assert.deepStrictEqual(summary.refused.map((r) => [r.file, r.line, r.reason]), [
    ['refus/a.lua', 2, 'chaîne non fermée'],
    ['refus/grand.lua', 0, 'fichier trop gros'],
    ['refus/lien/c.lua', 0, 'lien ou chemin hors de la ressource'],
  ]);
  assert.strictEqual(fs.readFileSync(path.join(refused, 'a.lua'), 'utf8'), broken);
  assert.strictEqual(fs.readFileSync(path.join(refused, 'grand.lua'), 'utf8'), big);
  assert.strictEqual(fs.readFileSync(path.join(outside, 'c.lua'), 'utf8'), LUA);
  assert.strictEqual(fs.readFileSync(path.join(refused, 'b.lua'), 'utf8'), '\nlocal x = 1\nreturn x\n');
  assert.strictEqual(summary.files, 2);   // b.lua et le manifeste
  const tooBig = delivery.leanText(Buffer.from(big, 'latin1'));
  assert.deepStrictEqual([tooBig.ok, tooBig.reason], [false, 'fichier trop gros']);
  assert.strictEqual(delivery.leanText(Buffer.from(big.slice(4), 'latin1')).ok, true);   // 1 Mio tout juste
  assert.strictEqual(delivery.MAX_BYTES, 1024 * 1024);   // relecture sécurité S-3
});

essai('allègement : jokers comparés sans retour arrière ni expression régulière (S-2)', () => {
  const name = `${'a'.repeat(200)}.lua`;
  const dir = tree(path.join(TMP, 'res', 'jokers'), {
    'fxmanifest.lua': `client_scripts { '${'*a'.repeat(40)}*b', '[z-a].lua', 'c[b-d].lua', 'x[!0-9].lua', '[.lua' }\n`,
    [name]: LUA, 'z.lua': LUA, 'a.lua': LUA, 'cc.lua': LUA, 'xa.lua': LUA, 'x1.lua': LUA, '[.lua': LUA,
  });
  const started = Date.now();
  const served = delivery.servedLua(dir);
  assert.ok(Date.now() - started < 1000, `${Date.now() - started} ms`);
  assert.deepStrictEqual(listOf(served), ['fxmanifest.lua:lean', 'cc.lua:lean', 'xa.lua:lean', '[.lua:lean']);
});

essai('allègement : écriture atomique ; une erreur d\'écriture est levée, l\'original reste (S-4)', () => {
  const dir = tree(path.join(TMP, 'res', 'ecriture'), { 'fxmanifest.lua': "client_script 'a.lua'\n", 'a.lua': LUA, 'a.lua.tmp/x': 'x' });
  assert.throws(() => delivery.leanFile(path.join(dir, 'a.lua')));
  assert.strictEqual(fs.readFileSync(path.join(dir, 'a.lua'), 'utf8'), LUA);
  assert.throws(() => delivery.leanResources([{ name: 'ecriture', dir }]));
  fs.rmSync(path.join(dir, 'a.lua.tmp'), { recursive: true });
  assert.strictEqual(delivery.leanFile(path.join(dir, 'a.lua')).ok, true);
  assert.deepStrictEqual(fs.readdirSync(dir).sort(), ['a.lua', 'fxmanifest.lua']);
});

// Installeur : fusion inchangée, sur des fichiers allégés -------------------------------------------------------------

essai('installeur : userOwned inchangé après son déménagement', () => {
  assert.strictEqual(installer.userOwned, delivery.userOwned);
  for (const yes of ['config.lua', 'config_client.lua', 'config/a.lua', 'sous/config.lua']) assert.strictEqual(installer.userOwned(yes), true, yes);
  for (const no of ['client/config.lua.bak', 'configs/a.lua', 'config_conseil.lua.bak', 'client/main.lua']) assert.strictEqual(installer.userOwned(no), false, no);
  // réglages du paquet du Conseil (T-157) : gardés à la mise à jour (relecture réseau R-5 de T-157)
  for (const yes of ['config_conseil.lua', 'Config_Conseil.lua']) assert.strictEqual(installer.userOwned(yes), true, yes);
  // sans la casse (S-5)
  for (const yes of ['Config_Client.lua', 'CONFIG.LUA', 'Config/a.lua', 'sous/Config.Lua']) assert.strictEqual(installer.userOwned(yes), true, yes);
});

essai('manifeste : un réglage écrit avec une autre casse reste gardé (S-5)', () => {
  const dir = tree(path.join(TMP, 'res', 'casse'), { 'fxmanifest.lua': "shared_scripts { 'Config_Client.lua' }\n", 'Config_Client.lua': LUA });
  assert.deepStrictEqual(listOf(delivery.servedLua(dir)), ['fxmanifest.lua:lean', 'Config_Client.lua:kept-config']);
});

function resourceV(version, comment) {
  return {
    'fxmanifest.lua': "-- manifeste\nshared_script 'config_client.lua'\nclient_scripts { 'client/a.lua', 'client/b.lua' }\n"
      + "server_scripts { 'config_conseil.lua', 'config.lua', 'server/s.lua' }\nvava_conseil_lua { 'config_conseil.lua' }\n",
    'config_conseil.lua': `-- réglages du placement\nreturn { reach = ${version === 1 ? 60 : 70} }\n`,
    'config_client.lua': '-- réglage expliqué\nreturn { a = 1 }\n',
    'config.lua': '-- réglage serveur\nreturn { b = 2 }\n',
    'client/a.lua': `-- ${comment}\nlocal a = ${version}\nreturn a\n`,
    'client/b.lua': '-- b\nreturn 2\n',
    'server/s.lua': '-- serveur\nreturn 3\n',
  };
}

essai('installeur : première mise à jour allégée, puis une version qui ne change qu\'un commentaire', () => {
  const base = path.join(TMP, 'fusion');
  // installé par une Chancellerie 1.8.6 : fichiers commentés, empreintes commentées
  const target = tree(path.join(base, 'installe'), resourceV(1, 'premier'));
  const baseline = dl.hashTree(target);
  fs.writeFileSync(path.join(target, 'client/b.lua'), '-- modifié sur place\nreturn 20\n');
  fs.writeFileSync(path.join(target, 'config.lua'), '-- à ma façon\nreturn { b = 5 }\n');
  // la même version, téléchargée et allégée
  const staged = tree(path.join(base, 'v1'), resourceV(1, 'premier'));
  const summary = delivery.leanResources([{ name: 'r', dir: staged }]);
  assert.deepStrictEqual(summary.refused, []);
  const incoming = dl.hashTree(staged);
  const p1 = installer.plan(target, incoming, baseline);
  assert.deepStrictEqual(p1.copy.sort(), ['client/a.lua', 'fxmanifest.lua']);
  assert.deepStrictEqual(p1.sideLocal, ['client/b.lua']);
  assert.deepStrictEqual(p1.keepLocal, ['config.lua']);
  assert.deepStrictEqual(p1.sideNew, []);
  assert.deepStrictEqual(p1.remove, []);
  assert.strictEqual(fs.readFileSync(path.join(staged, 'config_client.lua'), 'utf8'), '-- réglage expliqué\nreturn { a = 1 }\n');
  assert.strictEqual(fs.readFileSync(path.join(staged, 'server/s.lua'), 'utf8'), '-- serveur\nreturn 3\n');
  // installée : le disque devient la copie allégée (réglage local gardé), empreintes allégées retenues
  const installed = path.join(base, 'installe2');
  fs.cpSync(staged, installed, { recursive: true });
  fs.writeFileSync(path.join(installed, 'config.lua'), '-- à ma façon\nreturn { b = 5 }\n');
  // version suivante : seul un commentaire d'un fichier livré change → même empreinte, aucune action
  const staged2 = tree(path.join(base, 'v2'), resourceV(1, 'commentaire retouché'));
  delivery.leanResources([{ name: 'r', dir: staged2 }]);
  const incoming2 = dl.hashTree(staged2);
  assert.strictEqual(incoming2['client/a.lua'], incoming['client/a.lua']);
  const p2 = installer.plan(installed, incoming2, incoming);
  assert.deepStrictEqual(p2, { copy: [], keepLocal: ['config.lua'], sideNew: [], sideLocal: [], remove: [], orphans: [] });
  assert.strictEqual(installer.changes(p2), 0);
});

essai('installeur : config_conseil.lua adapté sur place et changé en amont → gardé, « .nouveau » à côté, jamais allégé', () => {
  const base = path.join(TMP, 'fusion-conseil');
  const target = tree(path.join(base, 'installe'), resourceV(1, 'premier'));
  const baseline = dl.hashTree(target);
  fs.writeFileSync(path.join(target, 'config_conseil.lua'), '-- à ma façon\nreturn { reach = 40 }\n');
  const staged = tree(path.join(base, 'v2'), resourceV(2, 'second'));
  delivery.leanResources([{ name: 'r', dir: staged }]);
  assert.strictEqual(fs.readFileSync(path.join(staged, 'config_conseil.lua'), 'utf8'), '-- réglages du placement\nreturn { reach = 70 }\n');
  const p = installer.plan(target, dl.hashTree(staged), baseline);
  assert.deepStrictEqual(p.sideNew, ['config_conseil.lua']);
  assert.ok(!p.copy.includes('config_conseil.lua') && !p.sideLocal.includes('config_conseil.lua'));
});

// scripts/livraison.js : garde-fous ------------------------------------------------------------------------------------

essai('livraison.js : dossier de sortie refusé (non vide, dans le dépôt, contenant le dépôt, par une jonction)', () => {
  const full = tree(path.join(TMP, 'plein'), { 'x.txt': 'x' });
  assert.match(livraison.refusal(full), /non vide/);
  assert.match(livraison.refusal(path.join(ROOT, 'jamais-cree', 'sortie')), /dans le dépôt/);
  assert.match(livraison.refusal(ROOT), /dans le dépôt/);
  assert.match(livraison.refusal(path.dirname(ROOT)), /contient le dépôt/);
  const link = path.join(TMP, 'vers-depot');
  fs.symlinkSync(ROOT, link, 'junction');
  assert.match(livraison.refusal(path.join(link, 'sortie')), /dans le dépôt/);
  assert.match(livraison.refusal(link), /dans le dépôt/);
  fs.mkdirSync(path.join(TMP, 'vide'));
  assert.strictEqual(livraison.refusal(path.join(TMP, 'vide')), null);
  assert.strictEqual(livraison.refusal(path.join(TMP, 'neuf', 'sous')), null);
  // toute copie git, pas seulement ce dépôt (S-6) : dossier `.git` ou fichier `.git` d'un worktree
  const clone = tree(path.join(TMP, 'clone'), { '.git/HEAD': 'ref: refs/heads/main\n' });
  assert.match(livraison.refusal(path.join(clone, 'sortie')), /copie git/);
  const worktree = tree(path.join(TMP, 'worktree'), { '.git': 'gitdir: ailleurs\n' });
  assert.match(livraison.refusal(path.join(worktree, 'a', 'b')), /copie git/);
  assert.ok(!fs.existsSync(path.join(ROOT, 'jamais-cree')));
});

essai('livraison.js : la ligne de commande refuse avant d\'écrire', () => {
  const run = (...args) => spawnSync(process.execPath, [path.join(ROOT, 'scripts', 'livraison.js'), ...args], { encoding: 'utf8' });
  const full = path.join(TMP, 'plein');
  let out = run('--essai', full);
  assert.strictEqual(out.status, 1);
  assert.match(out.stderr, /non vide/);
  out = run('--sortie', path.join(ROOT, 'jamais-cree'));
  assert.strictEqual(out.status, 1);
  assert.match(out.stderr, /dans le dépôt/);
  assert.ok(!fs.existsSync(path.join(ROOT, 'jamais-cree')));
  out = run('--sortie', path.dirname(ROOT));
  assert.strictEqual(out.status, 1);
  assert.match(out.stderr, /contient le dépôt/);
  assert.strictEqual(run('--essai').status, 2);
  assert.strictEqual(run('--autre', 'x').status, 2);
  assert.deepStrictEqual(fs.readdirSync(full), ['x.txt']);
  // --essai suivi de chemins : ces seuls fichiers (verifier.sh hors --tout, relecture réseau R-6)
  out = run('--essai', path.join(TMP, 'essai-partiel'), 'tests/livraison/cas_difficiles.lua', 'absent.lua');
  assert.strictEqual(out.status, 0, out.stderr);
  assert.strictEqual(out.stdout, 'depot\ttests/livraison/cas_difficiles.lua\n');
  assert.ok(fs.existsSync(path.join(TMP, 'essai-partiel', 'tests', 'livraison', 'cas_difficiles.lua')));
  assert.strictEqual(run('--sortie', path.join(TMP, 'sortie-x'), 'a.lua').status, 2);
});

// Installeur : fetchSource allège la copie téléchargée (updates.leanLua), avant toute empreinte ---------------------------

const TAR = process.platform === 'win32' ? path.join(process.env.SystemRoot || 'C:\\Windows', 'System32', 'tar.exe') : 'tar';

async function fetchEssais() {
  // archive comme celles de GitHub : un seul dossier « auteur-dépôt-commit/ »
  tree(path.join(TMP, 'archive', 'auteur-depot-abc'), {
    'fxmanifest.lua': "-- racine\nshared_scripts { 'shared/a.lua', 'config/shared.lua' }\nserver_script 'server/s.lua'\n",
    'shared/a.lua': LUA, 'config/shared.lua': LUA, 'server/s.lua': LUA,
    'modules/vava_m/fxmanifest.lua': "client_script 'client/b.lua'\nshared_script 'config_client.lua'\n",
    'modules/vava_m/client/b.lua': LUA, 'modules/vava_m/config_client.lua': LUA,
    'modules/vava_n/fxmanifest.lua': "client_scripts { nom }\n", 'modules/vava_n/client/c.lua': LUA,
    'modules/vava_o/fxmanifest.lua': "client_script 'client/d.lua'\n", 'modules/vava_o/client/d.lua': 'local s = "x\n',
  });
  const archive = path.join(TMP, 'source.tar.gz');
  execFileSync(TAR, ['-czf', archive, '-C', path.join(TMP, 'archive'), 'auteur-depot-abc'], { windowsHide: true });
  // archive dont un fichier livré ne peut pas être réécrit (un dossier occupe la place de son fichier temporaire)
  tree(path.join(TMP, 'archive2', 'auteur-depot-bad'), {
    'fxmanifest.lua': "client_script 'client/b.lua'\n", 'client/b.lua': LUA, 'client/b.lua.tmp/x': 'x',
  });
  const archive2 = path.join(TMP, 'source2.tar.gz');
  execFileSync(TAR, ['-czf', archive2, '-C', path.join(TMP, 'archive2'), 'auteur-depot-bad'], { windowsHide: true });
  const server = http.createServer((request, response) => {
    response.writeHead(200, { 'content-type': 'application/gzip' });
    fs.createReadStream(request.url.endsWith('/bad') ? archive2 : archive).pipe(response);
  });
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  const codeload = `http://127.0.0.1:${server.address().port}`;
  try {
    await essaiAsync('installeur : fetchSource allège la copie téléchargée et le dit au journal', async () => {
      const said = [];
      const job = { say: (m) => said.push(m), track() {} };
      const root = await installer.fetchSource({ codeload, repo: 'a/b', leanLua: true }, 'abc', job);
      assert.strictEqual(path.basename(root), 'auteur-depot-abc');
      assert.strictEqual(job.lean, 'Lua allégé : 5 fichiers, 1 refusés');   // repris dans le résumé de l'opération
      const read = (relative) => fs.readFileSync(path.join(root, relative), 'utf8');
      assert.strictEqual(read('shared/a.lua'), '\nlocal x = 1\nreturn x\n');
      assert.strictEqual(read('modules/vava_m/client/b.lua'), '\nlocal x = 1\nreturn x\n');
      assert.strictEqual(read('fxmanifest.lua').startsWith('\nshared_scripts'), true);
      for (const kept of ['config/shared.lua', 'server/s.lua', 'modules/vava_m/config_client.lua', 'modules/vava_n/client/c.lua']) {
        assert.strictEqual(read(kept), LUA, kept);
      }
      assert.strictEqual(read('modules/vava_n/fxmanifest.lua'), 'client_scripts { nom }\n');
      assert.strictEqual(read('modules/vava_o/client/d.lua'), 'local s = "x\n');
      assert.match(said[0], /^Lua servi aux joueurs allégé de ses commentaires : 5 fichiers, \d+ → \d+ Ko\.$/);
      assert.deepStrictEqual(said.slice(1), [
        'Laissé avec ses commentaires (ligne 1 : chaîne non fermée) : vava_o/client/d.lua',
        'Ressource vava_n laissée telle quelle : manifeste illisible pour l\'allègement (forme illisible (ligne 1)).',
      ]);
      // empreintes calculées ensuite sur ce qui est sur le disque : celles des fichiers allégés
      const planned = installer.layout(root).resources.find((r) => r.name === 'vava_m');
      assert.strictEqual(dl.hashTree(planned.dir)['client/b.lua'], dl.hashFile(path.join(root, 'modules/vava_m/client/b.lua')));
    });
    await essaiAsync('installeur : updates.leanLua à false livre la copie telle quelle', async () => {
      const said = [];
      const root = await installer.fetchSource({ codeload, repo: 'a/b', leanLua: false }, 'abd', { say: (m) => said.push(m), track() {} });
      assert.strictEqual(fs.readFileSync(path.join(root, 'shared/a.lua'), 'utf8'), LUA);
      assert.strictEqual(fs.readFileSync(path.join(root, 'modules/vava_m/client/b.lua'), 'utf8'), LUA);
      assert.deepStrictEqual(said, ['Allègement du Lua livré désactivé (updates.leanLua) : fichiers livrés avec leurs commentaires.']);
    });
    await essaiAsync('installeur : sans journal (job absent), l\'allègement se fait sans erreur', async () => {
      const root = await installer.fetchSource({ codeload, repo: 'a/b' }, 'abe');
      assert.strictEqual(fs.readFileSync(path.join(root, 'shared/a.lua'), 'utf8'), '\nlocal x = 1\nreturn x\n');
    });
    await essaiAsync('installeur : une erreur d\'écriture fait échouer l\'opération avant le serveur (S-4)', async () => {
      await assert.rejects(installer.fetchSource({ codeload, repo: 'a/b' }, 'bad'), (error) => {
        assert.strictEqual(error.code, 'lean_failed');
        assert.match(error.message, /rien n'a été changé sur le serveur/);
        return true;
      });
    });
  } finally {
    server.close();
  }
}

fetchEssais().then(() => {
  fs.rmSync(TMP, { recursive: true, force: true });
  process.stdout.write(`ESSAIS LIVRAISON : OK (${count})\n`);
}, (error) => fail('essais de fetchSource', error));
