# Remote desktop tanpa TURN

Desktop terbaru meminta transport `relay`. Android menangkap layar setelah pemilik
menyetujui remote dan dialog berbagi layar Android. Gambar PNG diperkecil (lebar
maksimal 720 piksel, maksimal 800.000 karakter base64) dan diteruskan backend
WebSocket. Koordinat kontrol tetap memakai ukuran layar asli, termasuk landscape.
Desktop mengonfirmasi setiap frame yang berhasil didekode; Android hanya mengirim
satu frame sebelum menunggu konfirmasi. Interval minimal 250 ms; kecepatan nyata
bergantung pada capture, encoding, dan jaringan. Ini cocok untuk bantuan dan
kontrol dasar, bukan streaming video berkecepatan tinggi. Audio tidak dikirim.

## Mulai uji coba

1. Tutup aplikasi desktop lama. Pasang APK Android terbaru tanpa menghapus data
   aplikasi, lalu buka aplikasi dan pastikan Aksesibilitas QuickSupport aktif.
2. Restart backend agar negosiasi transport relay tersedia:

   ```powershell
   cd D:\quicksupport-remote\backend
   npm.cmd start
   ```

   Jika terminal backend lama masih berjalan, hentikan dengan Ctrl+C terlebih dahulu.
3. Biarkan `ngrok http 3000` berjalan dengan domain yang sesuai `server_config.dart`
   pada kedua aplikasi. Build bawaan memakai
   `wss://unsaved-broaden-bazooka.ngrok-free.dev`.
4. Jalankan desktop terbaru dari folder Release, masukkan ID HP, lalu izinkan
   permintaan dan berbagi **seluruh layar** di HP.
5. Status desktop menjadi **Remote aktif melalui relay server (tanpa TURN)**.
   Klik untuk tap, tahan untuk tekan lama, seret untuk swipe. Tombol Home,
   Kembali, aplikasi terbaru, volume, dan keyboard tetap memakai Aksesibilitas.

Tidak perlu VPS, Laravel, atau port UDP WebRTC. Android dan desktop cukup dapat
menjangkau backend yang sama; ngrok memungkinkan subnet berbeda. Backend lokal
dan ngrok harus tetap hidup selama sesi. Pada LAN yang saling terjangkau, kedua
aplikasi dapat dibangun dengan URL lokal yang sama, misalnya
`--dart-define=SIGNALING_URL=ws://IP_KOMPUTER:3000`, tanpa ngrok. Pastikan port
TCP 3000 diizinkan untuk akses LAN.

## File hasil build

- APK: `android_agent/build/app/outputs/flutter-apk/app-release.apk`
- EXE: `desktop_controller/build/windows/x64/runner/Release/quicksupport_desktop_controller.exe`

Jika memindahkan desktop ke komputer lain, salin **seluruh folder Release**,
termasuk DLL dan direktori `data`, bukan EXE saja.

## Pemeriksaan kegagalan

- Backend belum mendukung relay: restart Node dari source backend terbaru.
- Menunggu layar terus: pastikan APK terbaru dan izin berbagi seluruh layar telah
  diberikan. APK lama hanya mengirim offer WebRTC.
- Desktop tidak menerima layar: periksa internet, tunnel ngrok, dan apakah desktop
  masih terbuka. Hubungkan ulang sesi setelah jaringan pulih.
- Gambar terlihat tetapi kontrol tidak bekerja: aktifkan ulang layanan
  Aksesibilitas QuickSupport. Konten dengan proteksi screenshot dapat tampak hitam.
- Rotate dan Power belum didukung oleh service Android; gunakan kontrol yang
  tersedia. Tombol khusus keyboard membutuhkan Android 13 atau lebih baru sesuai
  implementasi service saat ini.

Sesi WebRTC tetap tersedia untuk controller lama/web; mode default desktop baru
adalah relay gambar. File web Laravel tidak diperlukan untuk alur ini.

## Validasi

```powershell
cd D:\quicksupport-remote\backend
npm.cmd test
cd D:\quicksupport-remote\android_agent
flutter analyze
flutter test
flutter build apk --release
cd D:\quicksupport-remote\desktop_controller
flutter analyze
flutter test
flutter build windows --release
```

Tes protokol membuktikan persetujuan, negosiasi relay, penerusan frame, konfirmasi,
kontrol, dan penghentian sesi. Tes encoder membuktikan ukuran payload dibatasi dan
koordinat asli dipertahankan. Pengujian tangkapan layar serta kontrol pada perangkat
Android fisik tetap diperlukan.
