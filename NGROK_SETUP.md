# Akses internet sementara dengan ngrok

**Pembaruan desktop:** controller desktop terbaru meminta relay gambar melalui
backend, sehingga tidak memerlukan TURN. Ikuti [panduan desktop relay](DESKTOP_RELAY.md).
Bagian WebRTC/TURN di bawah berlaku untuk controller web/lama yang memakai WebRTC.

Backend tetap berjalan di komputer Anda. Ngrok menyediakan alamat HTTPS/WSS
publik sehingga Android dan desktop bisa terhubung dari jaringan berbeda.
APK dan EXE terbaru sudah memakai server bawaan; pengguna aplikasi hanya memakai ID.
Pengaturan berikut untuk administrator server, bukan pengguna HP atau desktop.

## 1. Siapkan ngrok sekali

Unduh CLI dari https://ngrok.com/download dan masuk ke dashboard ngrok.
Jalankan perintah berikut di terminal pribadi dengan authtoken akun Anda:

```powershell
ngrok config add-authtoken TOKEN_ANDA
```

Authtoken hanya untuk CLI ngrok. Jangan masukkan authtoken ke APK, alamat server,
repository, atau formulir ID perangkat.

## 2. Jalankan backend dan tunnel

Terminal pertama:

```powershell
cd D:\quicksupport-remote\backend
npm start
```

Terminal kedua:

```powershell
ngrok http 3000
```

Build saat ini langsung terhubung ke:

```text
wss://unsaved-broaden-bazooka.ngrok-free.dev
```

Pastikan Forwarding ngrok memakai domain tersebut dan menuju port 3000.
Biarkan kedua terminal tetap berjalan. Di HP cukup buka aplikasi dan tunggu
ID muncul, lalu masukkan ID di desktop dan tekan Connect. Tidak ada kolom URL.

Jika ngrok memberikan domain berbeda, administrator harus membangun ulang kedua
aplikasi (atau menggunakan kembali domain server yang sama):

```powershell
cd D:\quicksupport-remote\android_agent
flutter build apk --release --dart-define=SIGNALING_URL=wss://DOMAIN_BARU
cd D:\quicksupport-remote\desktop_controller
flutter build windows --release --dart-define=SIGNALING_URL=wss://DOMAIN_BARU
```

Ganti DOMAIN_BARU dengan domain sebenarnya. Pasang/distribusikan ulang hasil build.
ID tetap sama selama data backend dan identitas instalasi Android dipertahankan.

## 3. Relay video untuk jaringan berbeda

Ngrok dipakai untuk mencari ID, persetujuan, pertukaran SDP/ICE, dan pesan kontrol.
Desktop terbaru mengirim layar melalui relay PNG pada backend. Controller web/lama
masih memakai WebRTC untuk layar.
STUN membantu koneksi langsung, tetapi tidak menjamin dua jaringan Wi-Fi berbeda
bisa terhubung. Jika NAT/firewall menghalangi, WebRTC memerlukan TURN publik.
TURN adalah relay media WebRTC, bukan pengiriman gambar melalui backend Node.

Desktop selalu memasang tampilan video dengan ukuran penuh, dan baru menampilkan
status siap setelah frame pertama diterima. Jika 30 detik belum menerima gambar,
status menjelaskan kegagalan menunggu; sesi tetap dapat dihentikan pengguna.
Uji pada Wi-Fi yang sama terlebih dahulu untuk membedakan masalah jaringan dari
masalah tangkapan/decoder video. Status ICE gagal pada jaringan berbeda belum
membuktikan ada masalah pada izin berbagi layar.

Siapkan TURN dari penyedia layanan atau coturn pada server publik. Isikan
konfigurasi di `backend/.env` (buat dari `.env.example` hanya jika `.env` belum ada):

```dotenv
PORT=3000
TURN_URLS=turn:relay.example.com:3478?transport=udp,turns:relay.example.com:5349?transport=tcp
TURN_USERNAME=USERNAME_DARI_PENYEDIA
TURN_CREDENTIAL=PASSWORD_DARI_PENYEDIA
ICE_TRANSPORT_POLICY=all
```

Ganti seluruh nilai contoh dengan alamat dan kredensial TURN yang nyata.
Gunakan port/protokol yang disediakan layanan Anda; contoh bukan layanan gratis
yang siap digunakan. Domain ngrok HTTP tidak dapat dipakai sebagai TURN_URLS.
Restart backend lalu buat sesi baru. Backend memberikan konfigurasi ICE kepada
kedua peserta setelah HP menyetujui sesi; tidak perlu build ulang aplikasi
untuk mengganti TURN.

Untuk menguji relay, ubah `ICE_TRANSPORT_POLICY=relay`, restart backend,
dan hubungkan kembali. Jika video WebRTC tampil pada mode ini, koneksi memakai TURN.
Sesudah pengujian, kembalikan ke `all` agar koneksi langsung tetap diprioritaskan.
Kredensial TURN sementara harus diperbarui sebelum kedaluwarsa.

## Pemeriksaan

- URL `https://DOMAIN_NGROK/health` harus merespons status backend. Jika browser
  menampilkan halaman pemberitahuan ngrok, lanjutkan ke situs terlebih dahulu.
- Uji HP memakai data seluler dan desktop memakai Wi-Fi lain.
- ID muncul tetapi layar kosong: perbarui kedua aplikasi, izinkan berbagi layar,
  uji pada Wi-Fi yang sama, lalu periksa TURN untuk jaringan berbeda.
- Server offline: periksa terminal Node, terminal ngrok, dan kecocokan domain dengan server bawaan build.
- Tunnel berhenti atau komputer server mati: sesi terputus. Jalankan kembali
  backend/tunnel lalu minta sesi baru; persetujuan HP tetap diperlukan.

Belum ada tunnel akun ngrok atau server TURN aktif yang dibuat otomatis.
Tes otomatis memverifikasi konfigurasi dan protokol, bukan koneksi video melalui internet.

Sumber: [WebSocket melalui ngrok](https://ngrok.com/docs/using-ngrok-with/websockets),
[TURN untuk WebRTC](https://webrtc.org/getting-started/turn-server).
