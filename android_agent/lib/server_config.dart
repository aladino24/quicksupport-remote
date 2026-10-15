// Konfigurasi server: config/server.json.
// flutter build apk --release --dart-define-from-file=config/server.json
// Nilai bawaan dipakai jika build dijalankan tanpa file konfigurasi.
const signalingServerUrl = String.fromEnvironment(
  'SIGNALING_URL',
  defaultValue: 'wss://unsaved-broaden-bazooka.ngrok-free.dev',
);
