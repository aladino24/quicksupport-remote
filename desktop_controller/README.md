# Desktop Controller

Masukkan ID 9 digit yang tampil di Android dan tekan **Connect**. HP akan
menerima permintaan izin. Desktop menampilkan layar setelah HP menyetujui
berbagi layar. Daftar perangkat contoh telah dihapus.

Lihat [panduan koneksi melalui ID](../CONNECT_BY_ID.md) untuk alur lengkap.

## Build Windows

Diperlukan Visual Studio Build Tools 2022 dengan compiler C++, CMake, dan Windows SDK.

```powershell
flutter build windows --release --dart-define-from-file=config/server.json
```

Alamat server diatur di `config/server.json`; lihat [panduan konfigurasi server](../SERVER_CONFIG.md).

EXE: `build/windows/x64/runner/Release/quicksupport_desktop_controller.exe`.
Sertakan seluruh folder `Release` (DLL dan `data`) saat mendistribusikan aplikasi.
Paket siap ekstrak: `build/quicksupport-desktop-windows-x64.zip`.
