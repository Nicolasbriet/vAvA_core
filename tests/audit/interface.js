'use strict';
// tests/audit/interface.js : cas écrits pour le script d'audit en mode essai (script d'une interface)
const NS = 'http://www.w3.org/2000/svg'; // -- attendu: rien
fetch(`https://${GetParentResourceName()}/ready`); // -- attendu: rien
fetch('https://cfx-nui-vava_ui/web/css/vava_ui.css'); // -- attendu: rien
const SVG = 'http://www.w3.org/2000/svg'; fetch('http://exemple.invalid/'); // -- attendu: BLOQUANT
const AUTRE = 'http://www.w3.org/2000/svg/../../exemple'; // -- attendu: BLOQUANT
el.innerHTML = NS + SVG + AUTRE; // -- attendu: AVERTISSEMENT
// relecture : seuls les rappels NUI exacts sont permis
const resource = GetParentResourceName(); fetch(`https://${resource}/ready`); // -- attendu: rien
fetch(`https://${hote}/vol`); // -- attendu: BLOQUANT
fetch(`https://${resource}.exemple.invalid/vol`); // -- attendu: BLOQUANT
fetch('https://cfx-nui-vava_ui.exemple.invalid/vol'); // -- attendu: BLOQUANT
fetch('https://cfx-nui-/vol'); // -- attendu: BLOQUANT
// relecture : WebSocket et adresses sans protocole
const ws = new WebSocket('wss://exemple.invalid/'); // -- attendu: BLOQUANT
const ws2 = new WebSocket('ws://exemple.invalid/'); // -- attendu: BLOQUANT
img.src = '//exemple.invalid/a.png'; // -- attendu: BLOQUANT
img.src = 'dev/devmock.js'; // une adresse relative, et ce commentaire // -- attendu: rien
