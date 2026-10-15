# Konfigurasi alamat server

Ubah `SIGNALING_URL` pada kedua file berikut ketika pindah server:

- Android: `android_agent/config/server.json`
- Desktop: `desktop_controller/config/server.json`

Isi kedua file dengan alamat backend yang sama, misalnya:

```json
{
  "SIGNALING_URL": "ws://192.168.1.10:3000"
}
```

Gunakan port backend yang sebenarnya. Untuk domain HTTPS/ngrok, gunakan
`wss://domain-server.example`. Untuk IP lokal tanpa TLS, gunakan
`ws://IP_SERVER:PORT`. Jangan memakai `localhost` di Android untuk mengakses
server di komputer; gunakan IP LAN komputer yang dapat dijangkau HP.

Dari folder utama proyek, build kedua aplikasi dengan:

```powershell
.\build_all.ps1
```

Atau jalankan secara terpisah dari folder masing-masing aplikasi:

```powershell
# Dari android_agent
flutter run --dart-define-from-file=config/server.json
flutter build apk --release --dart-define-from-file=config/server.json

# Dari desktop_controller
flutter run -d windows --dart-define-from-file=config/server.json
flutter build windows --release --dart-define-from-file=config/server.json
```

Konfigurasi dimasukkan saat build. Setelah mengubah JSON, build ulang dan
pasang APK serta distribusikan ulang aplikasi desktop. Mengedit JSON sesudah
aplikasi terpasang tidak mengubah alamat server pada aplikasi tersebut.

Build tanpa `--dart-define-from-file` memakai alamat bawaan di
`lib/server_config.dart` masing-masing aplikasi. Opsi lama
`--dart-define=SIGNALING_URL=wss://domain-server.example` juga tetap tersedia.
