// Public ICE endpoints and optional TURN credentials are delivered only to
// participants after the Android device approves their session.
export function loadRtcConfig(env = process.env) {
  const iceServers = [{ urls: 'stun:stun.l.google.com:19302' }];
  const urls = (env.TURN_URLS || '').split(',').map(value => value.trim()).filter(Boolean);
  if (urls.length) {
    if (urls.some(url => !/^turns?:[^\s]+$/.test(url))) throw new Error('TURN_URLS must contain turn: or turns: URLs');
    if (!env.TURN_USERNAME || !env.TURN_CREDENTIAL) throw new Error('TURN_USERNAME and TURN_CREDENTIAL are required with TURN_URLS');
    iceServers.push({ urls, username: env.TURN_USERNAME, credential: env.TURN_CREDENTIAL });
  }
  const policy = env.ICE_TRANSPORT_POLICY || 'all';
  if (!['all', 'relay'].includes(policy)) throw new Error('ICE_TRANSPORT_POLICY must be all or relay');
  if (policy === 'relay' && !urls.length) throw new Error('Relay mode requires TURN_URLS');
  return { iceServers, iceTransportPolicy: policy };
}
