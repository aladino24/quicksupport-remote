<!doctype html>
<html lang="id">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="theme-color" content="#112b29">
    <title>QuickSupport · Remote Android</title>
    <link rel="stylesheet" href="{{ asset('controller.css') }}">
</head>
<body>
<header><a class="brand" href="/" aria-label="QuickSupport beranda"><span class="logo">Q</span> QuickSupport <small>WEB CONTROLLER</small></a><span class="browser-label">Remote dari browser Anda</span></header>
<main>
    <aside>
        <p class="eyebrow">PERANGKAT ANDROID, DALAM JANGKAUAN</p>
        <h1>Bantu dari<br>mana saja.</h1>
        <p class="intro">Hubungkan perangkat, lihat layar, dan bantu menyelesaikan pekerjaan langsung dari browser.</p>
        <section class="card">
            <h2>Hubungkan perangkat</h2>
            <form id="connect-form">
                <label for="device-id">ID pada aplikasi QuickSupport Android</label>
                <input id="device-id" inputmode="numeric" autocomplete="off" placeholder="123 456 789" maxlength="15" required aria-describedby="id-help">
                <p id="id-help" class="hint">Akses dimulai setelah pemilik HP menyetujui permintaan.</p>
                <button id="connect" class="primary" type="submit">Hubungkan perangkat <span>↗</span></button>
            </form>
            <button id="disconnect" class="danger" hidden>Hentikan sesi</button>
            <div class="status-line"><span id="status-dot" class="dot"></span><p id="status" role="status" aria-live="polite">Siap menghubungkan perangkat</p></div>
        </section>
        <section class="instructions"><h2>Cara memulai</h2><ol><li>Buka QuickSupport pada HP Android.</li><li>Masukkan ID perangkat di atas.</li><li>Izinkan remote dan berbagi layar di HP.</li></ol></section>
        <p class="privacy">◈ Anda memegang kendali. Pemilik HP dapat menghentikan sesi kapan saja.</p>
    </aside>
    <section class="workspace" aria-label="Layar dan kontrol perangkat">
        <div class="workspace-header"><div><span class="eyebrow">LAYAR PERANGKAT</span><h2 id="device-label">Belum ada perangkat</h2></div><div class="view-tools"><button id="zoom-out" aria-label="Perkecil layar">−</button><output id="zoom-label">100%</output><button id="zoom-in" aria-label="Perbesar layar">+</button><button id="fullscreen" aria-label="Layar penuh">⛶</button></div></div>
        <div id="screen-stage" class="screen-stage">
            <div id="empty-state"><div class="phone-icon">↗</div><h3>Ruang untuk layar Anda</h3><p>Layar Android akan tampil di sini<br>setelah koneksi disetujui.</p></div>
            <video id="remote-video" autoplay playsinline muted tabindex="0" aria-label="Layar Android. Klik atau sentuh untuk mengontrol" hidden></video>
            <button id="play-video" hidden>Tampilkan video</button>
        </div>
        <div class="control-bar" id="remote-controls"><button data-nav="back" disabled>← <span>Kembali</span></button><button data-nav="home" disabled>○ <span>Home</span></button><button data-nav="recent" disabled>▢ <span>Aplikasi</span></button><span class="divider"></span><button data-nav="volume_down" disabled>− <span>Volume</span></button><button data-nav="volume_up" disabled>+ <span>Volume</span></button><button id="toggle-screen" disabled>Sembunyikan</button></div>
        <form id="text-form" class="text-form"><label class="sr-only" for="remote-text">Teks untuk HP</label><input id="remote-text" placeholder="Kirim teks ke kolom yang aktif di HP…" disabled maxlength="2000"><button id="send-text" disabled>Kirim teks ↗</button></form>
        <p class="workspace-hint">Sentuh untuk mengetuk · Tahan untuk tekan lama · Geser untuk swipe · Saat zoom, gulir area layar untuk menggeser tampilan</p>
        <details><summary>Detail koneksi</summary><p id="connection-detail">Belum ada sesi aktif.</p><p>Jika ICE gagal, periksa firewall, isolasi Wi-Fi, atau TURN. Controller web tetap memerlukan jalur media WebRTC.</p></details>
    </section>
</main>
<footer>QuickSupport Remote <span>Dengan persetujuan. Selalu.</span></footer>
<script id="controller-config" type="application/json">{!! json_encode(['signalingUrl' => $signalingUrl], JSON_HEX_TAG | JSON_HEX_AMP | JSON_HEX_APOS | JSON_HEX_QUOT) !!}</script>
<script type="module" src="{{ asset('controller.mjs') }}"></script>
</body>
</html>
