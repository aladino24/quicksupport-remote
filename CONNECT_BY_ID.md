# Remote dengan ID Android

Android tidak lagi meminta formulir registrasi. Setelah tersambung ke server,
aplikasi menampilkan ID 9 digit. Desktop memasukkan ID tersebut dan menekan
**Connect**. HP harus menekan **Izinkan remote** dan menyetujui dialog berbagi
layar Android sebelum video atau kontrol diteruskan.

## Penggunaan aplikasi

1. Administrator menjalankan backend dan ngrok sesuai [panduan server](NGROK_SETUP.md).
2. Buka APK terbaru di HP yang terhubung internet. ID 9 digit muncul otomatis.
3. Buka EXE terbaru di desktop, masukkan ID HP, lalu tekan **Connect**.
4. Di HP, aktifkan aksesibilitas jika diminta, tekan **Izinkan remote**,
   lalu setujui dialog berbagi layar Android.
5. Hentikan melalui **Hentikan sesi** di HP atau kembali dari sesi desktop.

Pengguna tidak memasukkan URL, nama perangkat, atau data registrasi.
Server bawaan build ini adalah `wss://unsaved-broaden-bazooka.ngrok-free.dev`.
Alamat server lama yang tersimpan di Android tidak digunakan lagi.
Backend dan tunnel ngrok harus tetap aktif agar ID dapat diperoleh dan sesi tersambung.
Jika domain server berubah, administrator perlu membangun ulang kedua aplikasi
menggunakan file `config/server.json` masing-masing aplikasi sesuai
[panduan konfigurasi server](SERVER_CONFIG.md).

## ID dan sesi

- Identitas rahasia instalasi dibuat otomatis dan disimpan di penyimpanan
  privat Android. Tidak ada nama, model HP, akun, atau formulir yang perlu diisi.
- Server menetapkan ID unik dan menyimpan pemetaannya dalam
  `backend/data/device-identities.json`. Jangan hapus file ini jika ingin ID
  tetap sama setelah server restart. Menghapus data aplikasi juga mengubah identitas.
- Satu HP menerima satu permintaan/sesi pada satu waktu. Permintaan tanpa
  jawaban kedaluwarsa setelah 60 detik. ID offline dan perangkat sibuk dilaporkan.
- Mengetahui ID saja tidak memberikan akses. Backend memeriksa persetujuan,
  peserta sesi, dan arah setiap pesan. HP meminta izin berbagi layar per sesi.
- HP menyambung ulang ke server jika koneksi terputus; sesi lama berakhir dan
  desktop perlu meminta persetujuan baru.

## Build dan hasil

```powershell
cd D:\quicksupport-remote\android_agent
flutter build apk --release --dart-define-from-file=config/server.json
cd D:\quicksupport-remote\desktop_controller
flutter build windows --release --dart-define-from-file=config/server.json
```

- APK: `android_agent/build/app/outputs/flutter-apk/app-release.apk`
- EXE: `desktop_controller/build/windows/x64/runner/Release/quicksupport_desktop_controller.exe`
- Paket Windows: `desktop_controller/build/quicksupport-desktop-windows-x64.zip`

Ekstrak seluruh paket Windows; DLL dan folder `data` harus tetap bersama EXE.
APK menggunakan kunci debug untuk pengujian lokal. Gunakan kedua build baru
bersama backend baru; protokol registrasi lama telah diganti.

## Batas pengujian dan penggunaan internet

Tes otomatis mencakup protokol ID/persetujuan, penolakan, timeout, pemutusan,
isolasi peserta, ID persisten, dan tampilan awal kedua aplikasi. Pengujian
berbagi layar serta sentuhan pada HP fisik masih perlu dilakukan.

Layar hanya dikirim melalui WebRTC. Backend/ngrok menangani pencarian ID,
persetujuan, pertukaran SDP/ICE, dan pesan kontrol. Jalur gambar PNG melalui
backend sudah dihapus. Koneksi langsung antardua Wi-Fi dapat terhalang NAT/firewall;
untuk kondisi tersebut diperlukan TURN atau perubahan jaringan.

Koneksi video memakai STUN secara default. Backend kini mendukung TURN melalui
`TURN_URLS`, `TURN_USERNAME`, dan `TURN_CREDENTIAL` di `.env`. Konfigurasi
dibagikan ke peserta setelah persetujuan HP. Layanan TURN nyata belum disediakan;
lihat [panduan ngrok dan TURN](NGROK_SETUP.md) untuk mengaturnya.

Kontrol power/rotasi belum didukung. Input tombol khusus memerlukan Android 13+;
sentuhan, teks, serta tombol navigasi bergantung pada izin dan dukungan
aksesibilitas aplikasi yang sedang dibuka.

Implementasi berbagi layar mengikuti [MediaProjection Android](https://developer.android.com/media/grow/media-projection),
dengan izin pengguna dan foreground service bertipe `mediaProjection`.

## Mengatur ukuran layar di desktop

Pada halaman remote, gunakan tombol Perbesar/Perkecil untuk zoom 100–300%.
Sesuaikan layar mengembalikan zoom ke 100%. Perluas area layar menyembunyikan
panel status dan tombol bawah agar video mendapat ruang lebih besar.
Saat diperbesar, aktifkan ikon tangan lalu seret untuk melihat bagian lain.
Matikan ikon tangan untuk kembali mengontrol HP; kontrol HP dijeda selama mode geser.
Ukuran jendela Windows juga dapat diperbesar atau dimaksimalkan seperti biasa.

Tombol khusus panel remote: **Minimize layar HP** menyembunyikan video tanpa
mengakhiri sesi. **Tampilkan kembali layar HP** memunculkannya lagi.
**Maximize layar HP** memperluas panel video di dalam aplikasi dengan menyembunyikan
panel status; **Kembalikan tampilan** mengembalikan susunan awal.
Tombol ini berbeda dari minimize/maximize jendela Windows.
# Mode desktop tanpa TURN

Untuk APK dan desktop terbaru, ikuti [panduan relay desktop](DESKTOP_RELAY.md).
Mode ini mengirim gambar layar melalui backend setelah persetujuan di HP, sehingga
tidak memerlukan koneksi WebRTC langsung antarperangkat.

