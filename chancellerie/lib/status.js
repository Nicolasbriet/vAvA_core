'use strict';
/*
 * lib/status.js
 * Rôle : ce que dit le serveur de jeu lui-même, par ses adresses locales : joueurs connectés (players.json),
 *        réduits au numéro, au nom et à la latence (aucun identifiant ni adresse) ; ressources lancées (info.json) ;
 *        durée des ticks de ses fils principaux (/perf/, au format Prometheus, comme txAdmin la lit). Réponses
 *        gardées quelques secondes : plusieurs navigateurs ouverts n'interrogent pas le serveur plus souvent.
 *        FXServer ne donne les vrais joueurs de players.json qu'à qui présente son jeton `sv_playersToken` (sinon
 *        « Player », numéro 0, latence 0) : un jeton est tiré à chaque lancement et lui est passé sur la ligne de
 *        commande, comme la clé du pont ; celui du server.cfg est repris s'il y en a un (le fichier passe après).
 */

const crypto = require('crypto');
const http = require('http');
const servercfg = require('./servercfg');

const PLAYERS_TOKEN_BYTES = 24;
const PLAYERS_TOKEN_CONVAR = 'sv_playersToken';
const PLAYERS_TOKEN_HEADER = 'X-Players-Token';
const CACHE_MS = 5000;
const INFO_CACHE_MS = 2000;
const TIMEOUT_MS = 2500;
const BODY_MAX = 2 * 1024 * 1024;
const RESOURCE_PATTERN = /^[A-Za-z0-9_.-]{1,64}$/;
// fils de FXServer suivis : principal (scripts), réseau, synchronisation OneSync
const PERF_THREADS = { svMain: 'main', svNetwork: 'network', svSync: 'sync' };
const PERF_LINE = /^tickTime_(count|sum)\{name="(svMain|svNetwork|svSync)"\}\s+(\S+)/;

let cache = { key: '', at: 0, value: null };
let infoCache = { key: '', at: 0, value: null };
let playersToken = null;

/** Arguments ajoutés au lancement de FXServer : le jeton de players.json, sauf si le server.cfg fixe le sien. */
function launchArgs() {
  const cfg = servercfg.current();
  const own = cfg ? cfg.secrets.playersToken : '';
  cache = { key: '', at: 0, value: null };
  if (own) {
    playersToken = own;
    return [];
  }
  playersToken = crypto.randomBytes(PLAYERS_TOKEN_BYTES).toString('hex');
  return ['+set', PLAYERS_TOKEN_CONVAR, playersToken];
}

/** Valeurs à masquer dans la console de FXServer. */
function secrets() {
  return playersToken ? [playersToken] : [];
}

/** Adresse locale du serveur de jeu : 0.0.0.0 s'interroge par 127.0.0.1. */
function localHost(bind) {
  return !bind || bind === '0.0.0.0' ? '127.0.0.1' : bind;
}

/** Corps d'une réponse 200 en texte, ou null. */
function getText(host, port, route, headers) {
  return new Promise((resolve) => {
    const request = http.get({ host, port, path: route, headers, timeout: TIMEOUT_MS }, (response) => {
      if (response.statusCode !== 200) {
        response.resume();
        resolve(null);
        return;
      }
      let size = 0;
      const chunks = [];
      response.on('data', (chunk) => {
        size += chunk.length;
        if (size > BODY_MAX) request.destroy();
        else chunks.push(chunk);
      });
      response.on('end', () => resolve(Buffer.concat(chunks).toString('utf8')));
      response.on('aborted', () => resolve(null));
    });
    request.on('timeout', () => request.destroy());
    request.on('error', () => resolve(null));
  });
}

async function getJson(host, port, route, headers) {
  const text = await getText(host, port, route, headers);
  try {
    return text === null ? null : JSON.parse(text);
  } catch (error) {
    return null;
  }
}

/**
 * Joueurs connectés : [{ id, name, ping }], ou null si le serveur ne répond pas.
 * @param {{ bind: string, port: number }} endpoint
 */
async function players(endpoint) {
  const key = `${endpoint.bind}:${endpoint.port}`;
  if (cache.key === key && Date.now() - cache.at < CACHE_MS) return cache.value;
  const headers = playersToken ? { [PLAYERS_TOKEN_HEADER]: playersToken } : undefined;
  const list = await getJson(localHost(endpoint.bind), endpoint.port, '/players.json', headers);
  const value = Array.isArray(list)
    ? list.map((p) => ({ id: Number(p.id) || 0, name: String(p.name || '').slice(0, 64), ping: Number(p.ping) || 0 })).sort((a, b) => a.id - b.id)
    : null;
  cache = { key, at: Date.now(), value };
  return value;
}

/**
 * Noms des ressources lancées, d'après info.json ; null si le serveur ne répond pas.
 * @param {{ bind: string, port: number }} endpoint
 */
async function started(endpoint) {
  const key = `${endpoint.bind}:${endpoint.port}`;
  if (infoCache.key === key && Date.now() - infoCache.at < INFO_CACHE_MS) return infoCache.value;
  const info = await getJson(localHost(endpoint.bind), endpoint.port, '/info.json');
  const value = info && Array.isArray(info.resources)
    ? info.resources.map(String).filter((name) => RESOURCE_PATTERN.test(name))
    : null;
  infoCache = { key, at: Date.now(), value };
  return value;
}

/**
 * Compteurs cumulés des ticks : { main: { count, sum }, network, sync } (sum en secondes), ou null si /perf/ ne
 * répond pas.
 * @param {{ bind: string, port: number }} endpoint
 */
async function perf(endpoint) {
  const text = await getText(localHost(endpoint.bind), endpoint.port, '/perf/');
  if (!text || !text.includes('tickTime_')) return null;
  const out = {};
  for (const line of text.split('\n')) {
    const match = PERF_LINE.exec(line);
    if (!match) continue;
    const thread = PERF_THREADS[match[2]];
    out[thread] = out[thread] || { count: 0, sum: 0 };
    out[thread][match[1]] = Number(match[3]) || 0;
  }
  return Object.keys(out).length ? out : null;
}

/** Oublie les dernières réponses (serveur arrêté ou relancé, ressource lancée ou arrêtée). */
function reset() {
  cache = { key: '', at: 0, value: null };
  infoCache = { key: '', at: 0, value: null };
}

module.exports = { players, started, perf, reset, launchArgs, secrets };
