# QuickSupport signaling server

```powershell
npm install
npm start
npm test
```

Port default 3000; dapat diatur melalui `PORT`. Server mendengarkan pada semua
antarmuka jaringan. Endpoint `/health` menampilkan status dan jumlah perangkat/sesi.

Protokol WebSocket: `hello` -> `ready`; desktop mengirim `session_request`
berdasarkan ID, Android menjawab `session_response`. Hanya sesi yang disetujui
boleh meneruskan `offer`, `answer`, `candidate`, dan `control_event`.
`session_end`, pemutusan socket, penolakan, atau timeout mengakhiri sesi.

ID perangkat disimpan di `data/device-identities.json` (override: `IDENTITY_FILE`).
Simpan file ini untuk mempertahankan ID antar-restart. Server menyimpan hash
identitas instalasi, bukan token mentah. Endpoint registrasi manual lama dihapus.

Lihat [panduan koneksi melalui ID](../CONNECT_BY_ID.md).

Untuk akses internet sementara, jalankan `ngrok http 3000` di terminal kedua.
Lihat [panduan ngrok dan TURN](../NGROK_SETUP.md). Konfigurasi TURN tersedia
di `.env.example`; backend memvalidasinya ketika mulai dan mengirimkannya
hanya kepada peserta sesi yang telah disetujui.
