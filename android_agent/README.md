# Android Agent

QuickSupport menampilkan ID 9 digit secara otomatis setelah terhubung ke server.
Tidak ada formulir registrasi. Desktop meminta akses melalui ID, dan pemilik HP
mengizinkan sesi serta berbagi layar melalui dialog Android.

Lihat [panduan koneksi melalui ID](../CONNECT_BY_ID.md) untuk penggunaan,
alamat server, izin, batas fitur, dan hasil build.

```powershell
flutter build apk --release --dart-define-from-file=config/server.json
```

Alamat server diatur di `config/server.json`; lihat [panduan konfigurasi server](../SERVER_CONFIG.md).

Konfigurasi Gradle dan metadata embedding v2 harus tetap tersedia. WebRTC telah
diperbarui karena versi 0.11.x memakai API Android embedding yang telah dihapus.
Kotlin incremental compilation dinonaktifkan untuk mendukung cache Pub dan
proyek Windows pada drive yang berbeda. APK memakai kunci debug untuk tes lokal.
