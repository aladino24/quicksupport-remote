import {RemoteSession, mapPoint} from './session.mjs';
const $ = id => document.getElementById(id);
const video = $('remote-video');
const config = JSON.parse($('controller-config').textContent);
let hidden = false, zoom = 1, gesture = null, frameCallback = null;
const session = new RemoteSession({
    onStatus(message, active) {
        $('status').textContent = message;
        $('status-dot').classList.toggle('active', active);
        $('connect').disabled = active;
        $('device-id').disabled = active;
        $('disconnect').hidden = !active;
        if (!active) $('device-label').textContent = 'Belum ada perangkat';
    },
    onStream(stream) {
        if (frameCallback !== null && video.cancelVideoFrameCallback) video.cancelVideoFrameCallback(frameCallback);
        frameCallback = null;
        video.srcObject = stream;
        video.hidden = !stream || hidden;
        $('empty-state').hidden = !!stream && !hidden;
        $('play-video').hidden = true;
        if (stream) {
            video.play().catch(() => { $('play-video').hidden = false; });
            if (video.requestVideoFrameCallback) {
                const check = () => {
                    if (video.srcObject !== stream) return;
                    session.videoReady();
                    frameCallback = video.requestVideoFrameCallback(check);
                };
                frameCallback = video.requestVideoFrameCallback(check);
            }
        }
    },
    onReady(ready) {
        gesture = null;
        document.querySelectorAll('[data-nav], #toggle-screen, #remote-text, #send-text').forEach(el => el.disabled = !ready);
    },
    onDetail(message) { $('connection-detail').textContent = message; },
});
video.addEventListener('timeupdate', () => { if (video.videoWidth && video.currentTime > 0) session.videoReady(); });
$('play-video').onclick = () => video.play().then(() => { $('play-video').hidden = true; }).catch(() => {});
$('connect-form').onsubmit = event => {
    event.preventDefault();
    const id = $('device-id').value.replace(/[\s-]/g, '');
    try {
        hidden = false;
        zoom = 1;
        updateZoom();
        $('toggle-screen').textContent = 'Sembunyikan';
        session.connect(config.signalingUrl, id);
        $('device-label').textContent = `Android · ${id.replace(/(.{3})(.{3})(.{3})/, '$1 $2 $3')}`;
        $('connection-detail').textContent = 'Menunggu persetujuan perangkat.';
    } catch (error) { session.fail(error.message); }
};
$('disconnect').onclick = () => session.fail('Sesi dihentikan. Anda dapat menghubungkan perangkat lain.');
window.addEventListener('pagehide', () => session.disconnect());
document.querySelectorAll('[data-nav]').forEach(button => button.onclick = () => session.control('navigation', {action: button.dataset.nav}));
$('text-form').onsubmit = event => {
    event.preventDefault();
    if (!session.ready || !$('remote-text').value) return;
    // Native Android mapper accepts text in `key` and appends to the focused field.
    session.control('keyboard', {action: 'key_down', key: $('remote-text').value});
    $('remote-text').value = '';
};
const point = e => mapPoint(e.clientX, e.clientY, video.getBoundingClientRect(), video.videoWidth, video.videoHeight);
video.onpointerdown = event => {
    if (!session.ready || event.button !== 0 || gesture) return;
    const start = point(event);
    if (!start) return;
    event.preventDefault();
    video.focus({preventScroll: true});
    video.setPointerCapture(event.pointerId);
    gesture = {start, clientX: event.clientX, clientY: event.clientY, time: performance.now(), pointerId: event.pointerId};
};
video.onpointerup = event => {
    if (!gesture || gesture.pointerId !== event.pointerId) return;
    const down = gesture;
    gesture = null;
    const end = point(event);
    if (!end || !session.ready) return;
    const distance = Math.hypot(event.clientX - down.clientX, event.clientY - down.clientY);
    const elapsed = performance.now() - down.time;
    if (distance > 12) {
        session.control('mouse', {...down.start, action: 'drag', startX: down.start.x, startY: down.start.y, endX: end.x, endY: end.y});
    } else if (elapsed >= 600) {
        session.control('mouse', {...down.start, action: 'long_press'});
    } else {
        // Dispatch each tap immediately; two successive taps also work on touch devices.
        session.control('mouse', {...end, action: 'tap'});
    }
};
video.onpointercancel = video.onlostpointercapture = () => { gesture = null; };
video.oncontextmenu = event => {
    event.preventDefault();
    const p = point(event);
    if (p) session.control('mouse', {...p, action: 'long_press'});
};
video.addEventListener('wheel', event => {
    if (!session.ready || !event.deltaY) return;
    event.preventDefault();
    session.control('mouse', {action: 'scroll', direction: event.deltaY > 0 ? 'down' : 'up', delta: Math.abs(event.deltaY)});
}, {passive: false});
video.onkeydown = event => {
    if (!session.ready || event.key === 'Tab' || event.metaKey || event.altKey) return;
    const special = ['Backspace', 'Delete', 'Enter', 'Escape', ' '];
    if (event.ctrlKey && !['c', 'v'].includes(event.key.toLowerCase())) return;
    if (!event.ctrlKey && event.key.length !== 1 && !special.includes(event.key)) return;
    event.preventDefault();
    session.control('keyboard', {action: event.ctrlKey ? 'combo' : 'key_down', key: event.key === ' ' ? 'space' : event.key, ...(event.ctrlKey ? {combo: `ctrl+${event.key.toLowerCase()}`} : {})});
};
function updateZoom() {
    video.style.width = `${zoom * 100}%`;
    video.style.height = `${zoom * 100}%`;
    // Keep enlarged content reachable from its top-left corner.
    $('screen-stage').style.justifyContent = zoom > 1 ? 'flex-start' : 'center';
    $('screen-stage').style.alignItems = zoom > 1 ? 'flex-start' : 'center';
    $('zoom-label').textContent = `${Math.round(zoom * 100)}%`;
    $('zoom-out').disabled = zoom <= 1;
    $('zoom-in').disabled = zoom >= 3;
}
$('zoom-in').onclick = () => { zoom = Math.min(3, zoom + .25); updateZoom(); };
$('zoom-out').onclick = () => { zoom = Math.max(1, zoom - .25); updateZoom(); };
$('fullscreen').onclick = async () => {
    try {
        if (document.fullscreenElement) await document.exitFullscreen();
        else if ($('screen-stage').requestFullscreen) await $('screen-stage').requestFullscreen();
        else if (video.webkitEnterFullscreen && video.srcObject) video.webkitEnterFullscreen();
        else $('status').textContent = 'Layar penuh tidak tersedia di browser ini.';
    } catch { $('status').textContent = 'Browser tidak mengizinkan layar penuh.'; }
};
$('toggle-screen').onclick = () => {
    hidden = !hidden;
    video.hidden = hidden;
    $('empty-state').hidden = !hidden;
    $('toggle-screen').textContent = hidden ? 'Tampilkan' : 'Sembunyikan';
};
updateZoom();
