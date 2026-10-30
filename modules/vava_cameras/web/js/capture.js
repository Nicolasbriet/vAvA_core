'use strict';
/*
 * web/js/capture.js
 * Rôle : filmer l'écran du joueur pour le Conseil, et seulement à l'ordre du serveur. L'image du jeu (sans les
 *        interfaces : ni Windows, ni Discord, ni les pages du jeu) est reliée à une texture WebGL par la séquence
 *        propre à FiveM (celle de screenshot-basic) et dessinée dans un canevas hors de l'écran. Une seule capture,
 *        partagée par tous ceux qui regardent : chacun a sa connexion WebRTC, avec sa qualité (réduite pour une case
 *        de mur, pleine pour une vue en grand) et sa part du débit montant, donnée par le serveur et revue par lui à
 *        chaque arrivée ou départ. L'offre part une fois les candidats réseau réunis (une seule négociation).
 *        Personne ne regarde : plus rien ne tourne, ni dessin ni capture.
 */

const Capture = (() => {
  const canvas = document.getElementById('capture');
  const ICE_WAIT_MS = 4000;
  // marge sous l'intervalle entre deux images : une image du jeu qui arrive un peu tôt n'est pas sautée
  const FRAME_SLACK_MS = 2;
  const sessions = new Map();
  let gl = null;
  let stream = null;
  let track = null;
  let frame = null;
  let interval = 0;
  let lastDraw = 0;

  // Image du jeu -------------------------------------------------------------------------------------------------

  // l'image du jeu arrive déjà dans le bon sens : pas de retournement
  const VERTEX = `attribute vec2 p; varying vec2 uv;
    void main() { uv = vec2((p.x + 1.0) * 0.5, (p.y + 1.0) * 0.5); gl_Position = vec4(p, 0.0, 1.0); }`;
  const FRAGMENT = `precision mediump float; varying vec2 uv; uniform sampler2D game;
    void main() { gl_FragColor = vec4(texture2D(game, uv).rgb, 1.0); }`;

  function shader(type, source) {
    const node = gl.createShader(type);
    gl.shaderSource(node, source);
    gl.compileShader(node);
    if (!gl.getShaderParameter(node, gl.COMPILE_STATUS)) throw new Error(gl.getShaderInfoLog(node));
    return node;
  }

  /** Contexte WebGL, programme et texture reliée à l'image du jeu (une fois pour toutes). */
  function gameView() {
    if (gl) return;
    gl = canvas.getContext('webgl', { antialias: false, depth: false, stencil: false, alpha: false, preserveDrawingBuffer: false });
    if (!gl) throw new Error('webgl');
    const program = gl.createProgram();
    gl.attachShader(program, shader(gl.VERTEX_SHADER, VERTEX));
    gl.attachShader(program, shader(gl.FRAGMENT_SHADER, FRAGMENT));
    gl.linkProgram(program);
    if (!gl.getProgramParameter(program, gl.LINK_STATUS)) throw new Error(gl.getProgramInfoLog(program));
    gl.useProgram(program);
    const quad = gl.createBuffer();
    gl.bindBuffer(gl.ARRAY_BUFFER, quad);
    gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1, -1, 1, -1, -1, 1, 1, 1]), gl.STATIC_DRAW);
    const position = gl.getAttribLocation(program, 'p');
    gl.enableVertexAttribArray(position);
    gl.vertexAttribPointer(position, 2, gl.FLOAT, false, 0, 0);
    const texture = gl.createTexture();
    gl.activeTexture(gl.TEXTURE0);
    gl.bindTexture(gl.TEXTURE_2D, texture);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
    gl.pixelStorei(gl.UNPACK_ALIGNMENT, 1);
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGB, 1, 1, 0, gl.RGB, gl.UNSIGNED_BYTE, new Uint8Array(3));
    // séquence reconnue par FiveM : la texture devient l'image du jeu (même ordre que screenshot-basic)
    gl.texParameterf(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
    gl.texParameterf(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.MIRRORED_REPEAT);
    gl.texParameterf(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT);
    gl.uniform1i(gl.getUniformLocation(program, 'game'), 0);
  }

  /** Dessin cadencé sur la capture : pas plus d'images que la capture n'en prend. */
  function draw(now) {
    frame = requestAnimationFrame(draw);
    if (now - lastDraw < interval - FRAME_SLACK_MS) return;
    lastDraw = now;
    gl.viewport(0, 0, canvas.width, canvas.height);
    gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4);
  }

  /** Capture partagée, ouverte au premier spectateur. */
  function ensureStream(capture) {
    if (track) return;
    canvas.width = capture.width;
    canvas.height = capture.height;
    gameView();
    stream = canvas.captureStream(capture.fps);
    [track] = stream.getVideoTracks();
    interval = 1000 / capture.fps;
    lastDraw = 0;
    frame = requestAnimationFrame(draw);
  }

  /** Dernier spectateur parti : dessin et capture arrêtés. */
  function releaseStream() {
    if (sessions.size || !track) return;
    cancelAnimationFrame(frame);
    frame = null;
    track.stop();
    track = null;
    stream = null;
  }

  // WebRTC ---------------------------------------------------------------------------------------------------------

  /** Attend la fin de la collecte des candidats (bornée) : l'offre part entière, en un seul message. */
  function gathered(peer) {
    if (peer.iceGatheringState === 'complete') return Promise.resolve();
    return new Promise((resolve) => {
      const timer = setTimeout(resolve, ICE_WAIT_MS);
      peer.addEventListener('icegatheringstatechange', () => {
        if (peer.iceGatheringState !== 'complete') return;
        clearTimeout(timer);
        resolve();
      });
    });
  }

  function end(id, reason, tell) {
    const session = sessions.get(id);
    if (!session) return;
    sessions.delete(id);
    session.peer.close();
    releaseStream();
    if (tell) Bridge.post('capture:failed', { session: id, reason });
  }

  /**
   * Qualité du spectateur : taille réduite, cadence et débit bornés. Le débit est la part que le serveur lui donne
   * dans le budget montant du joueur (revue à chaque arrivée ou départ d'un spectateur) : la caméra ne prend pas la
   * connexion du joueur. Appliqué par `setParameters`, sans renégociation (une seule offre par caméra).
   */
  async function limit(session) {
    const parameters = session.sender.getParameters();
    const base = (parameters.encodings && parameters.encodings[0]) || {};
    parameters.encodings = [{
      ...base, scaleResolutionDownBy: session.quality.scale, maxFramerate: session.quality.fps, maxBitrate: session.kbps * 1000,
    }];
    await session.sender.setParameters(parameters).catch(() => {});
  }

  /** Applique la part actuelle, l'une après l'autre (deux `setParameters` mêlés seraient refusés). */
  function apply(session) {
    if (!session.ready) return session.chain;
    session.chain = session.chain.then(() => limit(session)).catch(() => {});
    return session.chain;
  }

  /** Parts revues par le serveur : seules changent celles des caméras de ce joueur qui sont encore ouvertes. */
  function rates({ rates: list }) {
    if (!Array.isArray(list)) return;
    for (const { session: id, kbps } of list) {
      const session = sessions.get(id);
      if (!session || !Number.isInteger(kbps) || kbps < 1) continue;
      session.kbps = kbps;
      apply(session);
    }
  }

  async function start({ session: id, iceServers, capture, quality }) {
    if (sessions.has(id) || !capture || !quality) return;
    if (typeof RTCPeerConnection !== 'function' || typeof canvas.captureStream !== 'function') {
      Bridge.post('capture:failed', { session: id, reason: 'unsupported' });
      return;
    }
    try {
      ensureStream(capture);
      const peer = new RTCPeerConnection({ iceServers: (iceServers || []).map((url) => ({ urls: url })) });
      // ready : description locale posée, le débit peut s'appliquer (une part arrivée avant attend ce moment)
      const session = { peer, sender: null, quality, kbps: quality.bitrateKbps, ready: false, chain: Promise.resolve() };
      sessions.set(id, session);
      session.sender = peer.addTrack(track, stream);
      peer.addEventListener('connectionstatechange', () => {
        if (peer.connectionState === 'failed') end(id, 'connection_failed', true);
        else if (peer.connectionState === 'closed') end(id, 'closed', true);
      });
      const offer = await peer.createOffer();
      await peer.setLocalDescription(offer);
      session.ready = true;
      await apply(session);
      await gathered(peer);
      if (!sessions.has(id)) return;
      Bridge.post('capture:offer', { session: id, sdp: peer.localDescription.sdp });
    } catch (error) {
      end(id, 'capture_failed', false);
      Bridge.post('capture:failed', { session: id, reason: 'capture_failed' });
    }
  }

  async function answer({ session: id, sdp }) {
    const session = sessions.get(id);
    if (!session) return;
    try {
      await session.peer.setRemoteDescription({ type: 'answer', sdp });
    } catch (error) {
      end(id, 'connection_failed', true);
    }
  }

  Bridge.on('capture:', { start, answer, rates, stop: ({ session: id }) => end(id, 'closed', false) });

  return { count: () => sessions.size };
})();
