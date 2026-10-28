'use strict';
/*
 * web/js/sound.js
 * Rôle : sons de la magie, fabriqués à la volée (Web Audio) : aucun fichier à télécharger. Carillon d'un murmure
 *        reçu, souffle d'un projectile, impact, boule qui s'éteint, glace qui se brise, vague, craquement du sol,
 *        grondement, sifflement de la vapeur. Volume donné par le jeu (distance). Un fichier déclaré dans la config
 *        (`sounds.files`, reçu à l'initialisation) remplace le son fabriqué du même nom.
 */

const Sound = (() => {
  let context = null;
  // fichiers déclarés par la config (nom → chemin dans web/), et leur premier chargement
  let files = {};
  const loaded = {};

  function audio() {
    if (!context) {
      const Context = window.AudioContext || window.webkitAudioContext;
      if (!Context) return null;
      context = new Context();
    }
    if (context.state === 'suspended') context.resume();
    return context;
  }

  /** Bruit blanc de `seconds` secondes. */
  function noise(ctx, seconds) {
    const buffer = ctx.createBuffer(1, Math.ceil(ctx.sampleRate * seconds), ctx.sampleRate);
    const data = buffer.getChannelData(0);
    for (let i = 0; i < data.length; i += 1) data[i] = Math.random() * 2 - 1;
    const source = ctx.createBufferSource();
    source.buffer = buffer;
    return source;
  }

  function envelope(ctx, volume, attack, release) {
    const gain = ctx.createGain();
    const now = ctx.currentTime;
    gain.gain.setValueAtTime(0.0001, now);
    gain.gain.exponentialRampToValueAtTime(Math.max(0.0002, volume), now + attack);
    gain.gain.exponentialRampToValueAtTime(0.0001, now + attack + release);
    gain.connect(ctx.destination);
    return gain;
  }

  const voices = {
    chime(ctx, volume) {
      [880, 1318.5, 1760].forEach((frequency, index) => {
        const osc = ctx.createOscillator();
        osc.type = 'sine';
        osc.frequency.value = frequency;
        osc.connect(envelope(ctx, volume * (0.22 / (index + 1)), 0.01, 1.6));
        osc.start();
        osc.stop(ctx.currentTime + 1.7);
      });
    },
    whoosh(ctx, volume) {
      const source = noise(ctx, 0.7);
      const filter = ctx.createBiquadFilter();
      filter.type = 'bandpass';
      filter.Q.value = 1.4;
      filter.frequency.setValueAtTime(300, ctx.currentTime);
      filter.frequency.exponentialRampToValueAtTime(1800, ctx.currentTime + 0.6);
      source.connect(filter);
      filter.connect(envelope(ctx, volume * 0.5, 0.08, 0.55));
      source.start();
    },
    impact(ctx, volume) {
      const source = noise(ctx, 0.8);
      const filter = ctx.createBiquadFilter();
      filter.type = 'lowpass';
      filter.frequency.value = 900;
      source.connect(filter);
      filter.connect(envelope(ctx, volume * 0.7, 0.005, 0.7));
      source.start();
      const thump = ctx.createOscillator();
      thump.type = 'sine';
      thump.frequency.setValueAtTime(90, ctx.currentTime);
      thump.frequency.exponentialRampToValueAtTime(40, ctx.currentTime + 0.4);
      thump.connect(envelope(ctx, volume * 0.6, 0.005, 0.45));
      thump.start();
      thump.stop(ctx.currentTime + 0.5);
    },
    shatter(ctx, volume) {
      const source = noise(ctx, 0.35);
      const filter = ctx.createBiquadFilter();
      filter.type = 'highpass';
      filter.frequency.value = 3200;
      source.connect(filter);
      filter.connect(envelope(ctx, volume * 0.45, 0.002, 0.3));
      source.start();
      [2637, 3520, 4186].forEach((frequency, index) => {
        const osc = ctx.createOscillator();
        osc.type = 'triangle';
        osc.frequency.value = frequency;
        osc.connect(envelope(ctx, volume * (0.12 / (index + 1)), 0.002, 0.35 + index * 0.1));
        osc.start(ctx.currentTime + index * 0.03);
        osc.stop(ctx.currentTime + 0.7);
      });
    },
    splash(ctx, volume) {
      const source = noise(ctx, 1.2);
      const filter = ctx.createBiquadFilter();
      filter.type = 'lowpass';
      filter.Q.value = 0.8;
      filter.frequency.setValueAtTime(2400, ctx.currentTime);
      filter.frequency.exponentialRampToValueAtTime(300, ctx.currentTime + 1.1);
      source.connect(filter);
      filter.connect(envelope(ctx, volume * 0.6, 0.06, 1.05));
      source.start();
    },
    crack(ctx, volume) {
      const source = noise(ctx, 0.25);
      const filter = ctx.createBiquadFilter();
      filter.type = 'bandpass';
      filter.Q.value = 2.5;
      filter.frequency.value = 1400;
      source.connect(filter);
      filter.connect(envelope(ctx, volume * 0.55, 0.001, 0.2));
      source.start();
      const low = ctx.createOscillator();
      low.type = 'sine';
      low.frequency.setValueAtTime(70, ctx.currentTime);
      low.connect(envelope(ctx, volume * 0.35, 0.01, 0.8));
      low.start();
      low.stop(ctx.currentTime + 0.9);
    },
    rumble(ctx, volume) {
      const source = noise(ctx, 1.6);
      const filter = ctx.createBiquadFilter();
      filter.type = 'lowpass';
      filter.frequency.value = 220;
      source.connect(filter);
      filter.connect(envelope(ctx, volume * 0.9, 0.04, 1.5));
      source.start();
      const thump = ctx.createOscillator();
      thump.type = 'sine';
      thump.frequency.setValueAtTime(55, ctx.currentTime);
      thump.frequency.exponentialRampToValueAtTime(30, ctx.currentTime + 1.2);
      thump.connect(envelope(ctx, volume * 0.7, 0.02, 1.2));
      thump.start();
      thump.stop(ctx.currentTime + 1.3);
    },
    hiss(ctx, volume) {
      const source = noise(ctx, 1.0);
      const filter = ctx.createBiquadFilter();
      filter.type = 'highpass';
      filter.frequency.value = 1500;
      source.connect(filter);
      filter.connect(envelope(ctx, volume * 0.4, 0.03, 0.9));
      source.start();
    },
    fizzle(ctx, volume) {
      const source = noise(ctx, 0.5);
      const filter = ctx.createBiquadFilter();
      filter.type = 'highpass';
      filter.frequency.value = 2200;
      source.connect(filter);
      filter.connect(envelope(ctx, volume * 0.35, 0.02, 0.45));
      source.start();
    },
  };

  /** Fichiers de la config : { nom: 'sounds/<fichier>.ogg' }. */
  function setFiles(map) {
    files = map && typeof map === 'object' ? map : {};
  }

  /** D'où vient un son : 'file' (fichier déclaré), 'synth' (fabriqué), ou null (inconnu). */
  function source(name) {
    if (files[name]) return 'file';
    if (voices[name]) return 'synth';
    return null;
  }

  function playFile(name, volume) {
    let base = loaded[name];
    if (!base) {
      base = new Audio(new URL(files[name], document.baseURI).href);
      base.preload = 'auto';
      loaded[name] = base;
    }
    // une copie par lecture : plusieurs sons semblables peuvent se chevaucher
    const node = base.cloneNode();
    node.volume = Math.min(1, volume);
    const played = node.play();
    if (played && typeof played.catch === 'function') played.catch(() => {});
  }

  function play(name, volume = 1) {
    if (!(volume > 0)) return;
    if (files[name]) {
      playFile(name, volume);
      return;
    }
    const voice = voices[name];
    const ctx = voice && audio();
    if (!ctx) return;
    voice(ctx, Math.min(1, volume));
  }

  return { play, setFiles, source };
})();
