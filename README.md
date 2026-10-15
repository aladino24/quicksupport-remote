# QuickSupport Remote

Desktop terbaru mendukung remote melalui relay gambar WebSocket tanpa TURN atau
VPS. Lihat [panduan desktop relay](DESKTOP_RELAY.md) untuk APK/EXE terbaru dan
langkah uji coba lokal dengan backend serta ngrok.

Starter implementation for the Android remote-control platform described in `requirements.md`.

## Architecture

- Android Agent: Flutter app that registers device, requests permissions, captures screen, and sends control events.
- Desktop Controller: Flutter desktop app that shows device list, connects to a device, and sends remote input.
- Backend Server: Express + WebSocket signaling server with device registry and session orchestration.

## Project layout

- `backend/` — signaling server and device registry
- `android_agent/` — Android client skeleton
- `desktop_controller/` — desktop app skeleton

## Run backend

```bash
cd backend
npm install
npm start
```

The server listens on `http://localhost:3000` and WebSocket signaling on the same port.

## Notes

This repository is a working starter that reflects the requirements and can be expanded into a complete production implementation.
