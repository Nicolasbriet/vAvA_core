'use strict';
/*
 * lib/http.js
 * Rôle : le serveur web de la Chancellerie : fichiers de l'interface (dossier web/, rien au-dehors), réponses
 *        JSON, lecture des corps de requête (JSON seulement, taille bornée), flux d'évènements (console en direct).
 *        Les adresses /api/ sont confiées aux routes.
 */

const fs = require('fs');
const http = require('http');
const path = require('path');
const security = require('./security');

const WEB = path.join(__dirname, '..', 'web');
const BODY_LIMIT = 64 * 1024;
const MIME = Object.freeze({
  '.html': 'text/html; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.svg': 'image/svg+xml',
  '.png': 'image/png',
  '.woff2': 'font/woff2',
  '.txt': 'text/plain; charset=utf-8',
  '.ico': 'image/x-icon',
});
// les polices et images ne changent pas d'une page à l'autre ; le reste est revalidé à chaque fois
const LONG_CACHE = new Set(['.woff2', '.png']);

function sendJson(res, status, body, headers = {}) {
  const text = JSON.stringify(body);
  res.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store', ...headers });
  res.end(text);
}

/** Corps JSON d'une requête ; { error } si absent, trop gros ou illisible. */
function readJson(req) {
  return new Promise((resolve) => {
    if (!String(req.headers['content-type'] || '').startsWith('application/json')) {
      req.resume();
      resolve({ error: 'bad_request' });
      return;
    }
    let size = 0;
    const chunks = [];
    let aborted = false;
    req.on('data', (chunk) => {
      if (aborted) return;
      size += chunk.length;
      if (size > BODY_LIMIT) {
        aborted = true;
        resolve({ error: 'too_large' });
        return;
      }
      chunks.push(chunk);
    });
    req.on('end', () => {
      if (aborted) return;
      try {
        const value = JSON.parse(Buffer.concat(chunks).toString('utf8'));
        resolve(value !== null && typeof value === 'object' && !Array.isArray(value) ? { value } : { error: 'bad_request' });
      } catch (error) {
        resolve({ error: 'bad_request' });
      }
    });
    req.on('error', () => resolve({ error: 'bad_request' }));
  });
}

function serveStatic(req, res) {
  if (req.method !== 'GET' && req.method !== 'HEAD') {
    sendJson(res, 405, { ok: false, error: 'method' });
    return;
  }
  let route;
  try {
    route = decodeURIComponent(new URL(req.url, 'http://chancellerie').pathname);
  } catch (error) {
    sendJson(res, 400, { ok: false, error: 'bad_request' });
    return;
  }
  const file = path.normalize(path.join(WEB, route === '/' ? 'index.html' : route));
  // aucun fichier hors du dossier de l'interface, même par ../
  if (!file.startsWith(WEB + path.sep) || route.includes('\0')) {
    sendJson(res, 404, { ok: false, error: 'not_found' });
    return;
  }
  fs.stat(file, (error, stat) => {
    if (error || !stat.isFile()) {
      sendJson(res, 404, { ok: false, error: 'not_found' });
      return;
    }
    const extension = path.extname(file).toLowerCase();
    res.writeHead(200, {
      'Content-Type': MIME[extension] || 'application/octet-stream',
      'Content-Length': stat.size,
      'Cache-Control': LONG_CACHE.has(extension) ? 'public, max-age=86400' : 'no-cache',
    });
    if (req.method === 'HEAD') {
      res.end();
      return;
    }
    fs.createReadStream(file).on('error', () => res.destroy()).pipe(res);
  });
}

/** Ouvre un flux d'évènements ; renvoie une fonction d'envoi (nom, données). */
function openStream(res) {
  res.writeHead(200, { 'Content-Type': 'text/event-stream; charset=utf-8', 'Cache-Control': 'no-store', Connection: 'keep-alive', 'X-Accel-Buffering': 'no' });
  res.write('retry: 3000\n\n');
  return (event, data) => res.write(`event: ${event}\ndata: ${JSON.stringify(data)}\n\n`);
}

/**
 * @param {{ host: string }} options
 * @param {(req: http.IncomingMessage, res: http.ServerResponse, route: string) => void} handleApi
 */
function createServer(options, handleApi) {
  return http.createServer((req, res) => {
    security.applyHeaders(res);
    if (!security.hostAllowed(req, options.host)) {
      sendJson(res, 421, { ok: false, error: 'bad_host' });
      return;
    }
    let route;
    try {
      route = new URL(req.url, 'http://chancellerie').pathname;
    } catch (error) {
      sendJson(res, 400, { ok: false, error: 'bad_request' });
      return;
    }
    if (route.startsWith('/api/')) {
      Promise.resolve(handleApi(req, res, route)).catch((error) => {
        console.error(`[Chancellerie] erreur sur ${req.method} ${route} : ${error.stack || error.message}`);
        if (!res.headersSent) sendJson(res, 500, { ok: false, error: 'internal' });
        else res.end();
      });
      return;
    }
    serveStatic(req, res);
  });
}

module.exports = { createServer, sendJson, readJson, openStream };
