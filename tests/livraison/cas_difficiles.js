/*
 * tests/livraison/cas_difficiles.js
 * Rôle : script valide truffé des pièges de l'allègement des pages (T-160, spec § 12.1 cas JS 3 à 29, § 12.2) :
 *        commentaires dans des chaînes et des gabarits, gabarits imbriqués, expressions régulières (barres échappées,
 *        classes), divisions et expressions régulières selon ce qui précède, commentaires de plusieurs lignes, licence
 *        gardée. Exécuté avant et après allègement par tests/livraison/essais-pages.js : mêmes valeurs, et la même
 *        ligne pour l'erreur de `faute()` (V8 lui-même prouve que les lignes sont gardées). Jamais servi aux joueurs.
 * Dépendances : aucune.
 */
/*! licence gardée */
//@ directive gardée
'use strict';

var r = 'x', n = 'y', a = 6, b = 3, c = 'c';   	
var s3 = "a // b"; // c
var s4 = '/* pas */'; /* c */
var t5 = `https://${r}/${n}`; // c
var t6 = [`${a} / ${b}`, a / b / 2]; // c
var t7 = `a${ {x: `b${c /* in */}`}.x }d`;
var t8 = `ligne   
// pas un commentaire
`; // c
var r9 = /\/\/ x/g; // c
var r10 = /[/*]/.test('*'); // c
var arr = [a];
var q11 = [a / b / 2, (a) / 2, arr[0] / 2, 3 / 2]; // c
var r12 = false, i12 = 0;
if (a) /re/.test('re') && (r12 = true); // c
while (i12 < 1) /re/g.exec('re') && (i12 += 1); // c
var x13 = a ? /b/ : /c/; var y13 = [/a/, /b/]; var f13 = () => /a/; function g13(s) { return /a\//.test(s); } // c
var x14 = a++ / 2; // c
var x15 = typeof/**/a;
var x16 = 1 /* a */ + 2;
var x17 = 1; /* x
 y */ var y17 = 2;
var s21 = "a\
// dans la chaîne";
		var tab = 1; // indentation gardée
var s24 = '\\'; // c
var r25 = /a/g// c
var x25 = 1//c
var y25 = .5/* c */
var z25 = 0x1F// c
var w25 = 1e-5// c
class A26 { #x = 6; f() { return this.#x / 2; } } // c
var i27 = 2, n27 = 0; while (i27-- > 0) { n27 += 1; } // c
var s28 = 'é'; // c

/*
 * plusieurs lignes de commentaire
 * avant la fonction fautive
 */
// encore une ligne
function faute() {
  // la ligne suivante lève : sa ligne doit être la même avant et après allègement
  throw new Error('faute voulue');
}

// dernière expression : toutes les valeurs calculées
({
  s3, s4, t5, t6, t7, t8, r9, r10, q11, r12, i12, x13, y13, f13: f13(), g13: [g13('a/'), g13('b')], x14, x15, x16, x17,
  y17, s21, tab, s24, r25, x25, y25, z25, w25, a26: new A26().f(), n27, s28, faute,
});
