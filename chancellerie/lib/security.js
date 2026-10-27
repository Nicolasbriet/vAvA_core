'use strict';
/*
 * lib/security.js
 * Rôle : défenses HTTP de la Chancellerie : en-têtes (aucune page encadrable, aucun script extérieur), protection
 *        contre les requêtes forgées depuis un autre site (en-tête maison + origine vérifiée) et contre le rebond
 *        DNS (nom d'hôte vérifié), limites de débit par adresse (gardées en mémoire, jamais écrites), cookies.
 */

const HEADERS = Object.freeze({
  'X-Frame-Options': 'DENY',
  'X-Content-Type-Options': 'nosniff',
  'Referrer-Policy': 'no-referrer',
  'Cross-Origin-Opener-Policy': 'same-origin',
  'Content-Security-Policy': "default-src 'self'; img-src 'self' data:; style-src 'self'; script-src 'self'; connect-src 'self'; frame-ancestors 'none'; base-uri 'none'; form-action 'self'",
});
// en-tête qu'un formulaire d'un autre site ne peut pas envoyer
const CSRF_HEADER = 'x-chancellerie';

function applyHeaders(res) {
  for (const [name, value] of Object.entries(HEADERS)) res.setHeader(name, value);
}

/** Une requête qui modifie quelque chose vient-elle bien de la Chancellerie elle-même ? */
function sameOrigin(req) {
  if (req.headers[CSRF_HEADER] !== '1') return false;
  const origin = req.headers.origin;
  if (!origin) return true;
  try {
    return new URL(origin).host === req.headers.host;
  } catch (error) {
    return false;
  }
}

const LOOPBACK = new Set(['127.0.0.1', 'localhost', '[::1]', '::1']);

/**
 * Le nom demandé est-il bien celui de la Chancellerie ? Sur une écoute locale, seuls les noms locaux sont admis :
 * une page piégée qui ferait pointer son propre nom vers 127.0.0.1 (rebond DNS) est refusée.
 */
function hostAllowed(req, listenHost) {
  if (!LOOPBACK.has(listenHost)) return true;
  const host = String(req.headers.host || '');
  const name = host.startsWith('[') ? host.slice(0, host.indexOf(']') + 1) : host.split(':')[0];
  return LOOPBACK.has(name.toLowerCase());
}

function parseCookies(header) {
  const cookies = {};
  for (const part of String(header || '').split(';')) {
    const index = part.indexOf('=');
    if (index <= 0) continue;
    try {
      cookies[part.slice(0, index).trim()] = decodeURIComponent(part.slice(index + 1).trim());
    } catch (error) {
      // cookie mal formé : ignoré
    }
  }
  return cookies;
}

/** Seau à jetons par clé (adresse) : `capacity` coups, rechargés de `perSecond` par seconde. */
function limiter(capacity, perSecond) {
  const buckets = new Map();
  return function allow(key) {
    const now = Date.now();
    const bucket = buckets.get(key) || { tokens: capacity, at: now };
    bucket.tokens = Math.min(capacity, bucket.tokens + ((now - bucket.at) / 1000) * perSecond);
    bucket.at = now;
    const allowed = bucket.tokens >= 1;
    if (allowed) bucket.tokens -= 1;
    buckets.set(key, bucket);
    // ménage : un seau plein n'apprend plus rien
    if (buckets.size > 1000) for (const [k, b] of buckets) if (b.tokens >= capacity) buckets.delete(k);
    return allowed;
  };
}

module.exports = { applyHeaders, sameOrigin, hostAllowed, parseCookies, limiter, CSRF_HEADER };
