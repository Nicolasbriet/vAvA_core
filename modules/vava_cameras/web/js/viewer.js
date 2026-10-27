'use strict';
/*
 * web/js/viewer.js
 * Rôle : côté spectateur d'une caméra : accepte l'offre du joueur filmé (réception seule), rend la réponse une fois
 *        les candidats réseau réunis, et remet l'image reçue. Aucune image n'est envoyée par le spectateur.
 */

const Viewer = (() => {
  const ICE_WAIT_MS = 4000;

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

  /**
   * Accepte une offre : { peer, sdp } (réponse à renvoyer). `onStream(stream)` reçoit l'image, `onFailed()` est
   * appelé si la connexion se perd.
   */
  async function accept(offer, iceServers, { onStream, onFailed }) {
    const peer = new RTCPeerConnection({ iceServers: (iceServers || []).map((url) => ({ urls: url })) });
    peer.addEventListener('track', (event) => onStream(event.streams[0] || new MediaStream([event.track])));
    peer.addEventListener('connectionstatechange', () => {
      if (peer.connectionState === 'failed') onFailed();
    });
    try {
      await peer.setRemoteDescription({ type: 'offer', sdp: offer });
      await peer.setLocalDescription(await peer.createAnswer());
      await gathered(peer);
    } catch (error) {
      peer.close();
      throw error;
    }
    return { peer, sdp: peer.localDescription.sdp };
  }

  return { accept };
})();
