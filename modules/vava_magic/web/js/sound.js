'use strict';
/*
 * web/js/sound.js
 * Rôle : sons de la magie, fabriqués à la volée (Web Audio) : aucun fichier à télécharger. Carillon d'un murmure
 *        reçu, souffle d'une boule de feu, impact, boule qui s'éteint. Volume donné par le jeu (distance).
 */

const Sound = (() => {
  let context = null;

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

  function play(name, volume = 1) {
    const voice = voices[name];
    const ctx = voice && audio();
    if (!ctx || !(volume > 0)) return;
    voice(ctx, Math.min(1, volume));
  }

  return { play };
})();
