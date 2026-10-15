# QuickStart Tester Guide

Gunakan panduan ini saat tester menjalankan app langsung di emulator Android Studio atau device nyata.

## 1. Checklist sebelum pairing

### Backend
- [ ] Backend sudah running di `http://localhost:3000`
- [ ] `/health` bisa diakses
- [ ] Device list masih kosong sampai agent terdaftar

### Android Agent
- [ ] App terinstall di emulator/device
- [ ] Registration form sudah diisi dan dikirim
- [ ] Device ID unik
- [ ] Akses internet, network state, foreground, notification, media projection, dan accessibility sudah diberikan
- [ ] Accessibility Service aktif di Android Settings
- [ ] Status app berada di `Waiting for remote control request`

### Desktop Controller
- [ ] App desktop terbuka
- [ ] Device muncul di daftar
- [ ] Session ready untuk request

---

## 2. Step-by-step untuk emulator Android Studio

### A. Start backend
1. Buka terminal di folder `backend`
2. Jalankan:
   ```bash
   npm install
   node src/server.js
   ```
3. Pastikan server log menunjukkan `QuickSupport backend running`
4. Cek health:
   ```bash
   curl http://localhost:3000/health
   ```

### B. Start emulator di Android Studio
1. Buka Android Studio
2. Jalankan emulator dari Device Manager
3. Pastikan emulator terdeteksi:
   ```bash
   adb devices
   ```
4. Jika real device dipakai, aktifkan USB debugging dan pastikan muncul di `adb devices`

### C. Run Android Agent
1. Buka project Android Agent di Android Studio
2. Pilih emulator/device
3. Run aplikasi
4. Isi form registration
5. Submit registration
6. Pada permission screen:
   - grant semua permission yang diminta
   - jika Accessibility Service belum aktif, buka Android Settings dan aktifkan
7. Pastikan app masuk ke state `Waiting for remote control request`

### D. Run Desktop Controller
1. Buka project Desktop Controller
2. Jalankan aplikasi desktop
3. Pilih device yang muncul di daftar
4. Tunggu sampai stream mulai tampil
5. Pastikan floating shortcut toolbar muncul di bawah stream

### E. Approve pairing
1. Di Android app, pilih `Approve`
2. Pastikan dari desktop muncul stream aktif
3. Jika stream masih blank, cek koneksi signaling dan ulang reconnect

---

## 3. Checklist setelah pairing

### Session health
- [ ] Stream terlihat
- [ ] Tidak blank atau lag terlalu berat
- [ ] Session bertahan selama 2-5 menit tanpa disconnect
- [ ] Reconnect berfungsi saat koneksi terputus sementara

### Input
- [ ] Tap bekerja
- [ ] Long press bekerja
- [ ] Drag bekerja
- [ ] Scroll bekerja
- [ ] Keyboard text masuk ke field aktif
- [ ] Enter / Backspace / Tab / Space berfungsi
- [ ] Ctrl+C / Ctrl+V berfungsi jika aplikasi mendukung

### Shortcut
- [ ] Back
- [ ] Home
- [ ] Recent
- [ ] Rotate
- [ ] Volume Up
- [ ] Volume Down
- [ ] Power

### Fallback
- [ ] Jika Accessibility Service dimatikan, app memberi peringatan
- [ ] Tester bisa membuka Android Settings dari app
- [ ] Setelah diaktifkan kembali, session bisa lanjut

---

## 4. Acceptance criteria

Tester berhasil jika:
- Mobile device register dengan backend
- Desktop dapat melihat device
- Stream muncul dan stabil
- Mouse, keyboard, dan shortcut bekerja
- Accessibility Service aktif dan fallback berfungsi
- Reconnect berhasil setelah transient disconnect

---

## 5. Catatan tester saat sedang menjalankan app

Saat sesi sedang berjalan, tester bisa mengikuti urutan ini:

1. Pastikan backend aktif
2. Pastikan emulator/device aktif
3. Pastikan app Android sudah register dan siap
4. Pastikan desktop terhubung
5. Approve pairing
6. Cek stream
7. Ubah fokus ke aplikasi target
8. Uji tap / drag / scroll / keyboard
9. Uji shortcut dan copy paste
10. Rekam error bila ada
11. Uji reconnect bila terjadi drop sinyal

---

## 6. Troubleshooting singkat

### Device tidak muncul di desktop
- Cek backend running
- Cek device sudah register
- Cek Android app tidak error saat submit form

### Stream blank
- Pastikan approval sudah diberikan
- Cek signaling handshake
- Cek WebSocket backend log

### Accessibility tidak bekerja
- Masuk ke Android Settings > Accessibility > QuickSupport Agent
- Aktifkan service
- Kembali ke app dan cek status

### Keyboard tidak masuk ke field aktif
- Pastikan fokus app benar
- Pastikan remote session aktif
- Coba ketik di aplikasi lain yang punya input field

---

## 7. Sumber info

- Backend: `backend/src/server.js`
- Android app: `android_agent/`
- Desktop app: `desktop_controller/`
- Runbook lengkap: `TESTING_RUNBOOK.md`
