'use strict';
// tests/audit/interface.js : cas écrits pour le script d'audit en mode essai (script d'une interface)
const NS = 'http://www.w3.org/2000/svg'; // -- attendu: rien
fetch(`https://${GetParentResourceName()}/ready`); // -- attendu: rien
fetch('https://cfx-nui-vava_ui/web/css/vava_ui.css'); // -- attendu: rien
const SVG = 'http://www.w3.org/2000/svg'; fetch('http://exemple.invalid/'); // -- attendu: BLOQUANT
const AUTRE = 'http://www.w3.org/2000/svg/../../exemple'; // -- attendu: BLOQUANT
el.innerHTML = NS + SVG + AUTRE; // -- attendu: AVERTISSEMENT
