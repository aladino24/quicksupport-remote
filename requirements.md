# Android Remote Control Application
## Software Requirements Specification

Version: 1.0.0
Platform:
- Android Agent
- Windows Desktop Controller
- Backend Server

---

# 1. Overview

Aplikasi Android Remote Control adalah sistem yang memungkinkan perangkat
Android dikontrol dari aplikasi desktop melalui jaringan internet maupun
jaringan lokal.

Sistem terdiri dari:

1. Android Agent
2. Desktop Controller
3. Backend / Signaling Server
4. Realtime Communication Layer

Contoh alur:

Android Device
      │
      │ Register Device
      ▼
Backend / Signaling Server
      ▲
      │ Request Connection
      │
Desktop Controller

Setelah koneksi berhasil:

Desktop Controller
      │
      │ Control Input
      ▼
Android Device

Android Device
      │
      │ Screen Stream
      ▼
Desktop Controller

---

# 2. Project Goals

Aplikasi harus mampu:

- Menampilkan layar Android secara realtime pada desktop.
- Melakukan remote control Android dari desktop.
- Mengirim input mouse desktop sebagai touch Android.
- Mengirim keyboard desktop sebagai input Android.
- Menjalankan koneksi melalui LAN maupun internet.
- Mengidentifikasi setiap perangkat dengan Device ID.
- Memerlukan persetujuan pengguna untuk sesi remote.
- Menampilkan status perangkat online/offline.
- Mengamankan komunikasi antara Android dan desktop.
- Mendukung reconnect ketika koneksi terputus.

Target pengalaman penggunaan mirip:

Desktop
┌────────────────────────────────────────────┐
│ Device: Samsung Tablet                     │
│ Status: ONLINE                             │
├────────────────────────────────────────────┤
│                                            │
│              ANDROID SCREEN                │
│                                            │
│                                            │
├────────────────────────────────────────────┤
│ Back | Home | Recent | Rotate | Disconnect │
└────────────────────────────────────────────┘

---

# 3. System Architecture

Recommended architecture:

┌─────────────────────┐
│   Android Device    │
│                     │
│ Flutter UI          │
│ Kotlin Native       │
│ MediaProjection     │
│ Accessibility       │
│ WebRTC Client       │
└─────────┬───────────┘
          │
          │ HTTPS / WSS
          ▼
┌─────────────────────┐
│ Backend Server      │
│                     │
│ Authentication      │
│ Device Registry     │
│ Signaling           │
│ Session Management  │
└─────────┬───────────┘
          │
          │ WebRTC / WSS
          ▼
┌─────────────────────┐
│ Desktop Controller  │
│                     │
│ Flutter Desktop     │
│ WebRTC Client       │
│ Keyboard / Mouse    │
└─────────────────────┘

---

# 4. Technology Stack

## 4.1 Android Agent

Framework:

- Flutter
- Dart
- Kotlin native Android

Recommended Flutter architecture:

- GetX / Riverpod
- Dio
- WebSocket
- WebRTC

Native Android components:

- MediaProjection API
- AccessibilityService
- Foreground Service
- Notification Service
- Device Information API

Android native functionality accessed using:

Flutter
      │
      ▼
MethodChannel
      │
      ▼
Kotlin
      │
      ├── MediaProjection
      ├── AccessibilityService
      └── ForegroundService

---

## 4.2 Desktop Application

Primary target:

- Windows 10
- Windows 11

Framework:

- Flutter Desktop

Responsibilities:

- Login
- Device management
- Remote session
- Screen rendering
- Mouse input
- Keyboard input
- Session monitoring

Future platform:

- macOS
- Linux

---

## 4.3 Backend

Recommended:

Option A:
- Node.js
- Express / Fastify
- Socket.IO / WebSocket

Option B:
- Go
- Gin / Fiber
- Gorilla WebSocket

Database:

- PostgreSQL

Cache / session:

- Redis

Communication:

- REST API
- WebSocket
- WebRTC signaling

Deployment:

- Docker
- Ubuntu VPS
- Nginx
- HTTPS/WSS

---

# 5. Android Application Requirements

## 5.1 Device Registration

Saat aplikasi pertama kali dibuka:

System generates:

- device_id
- device_uuid
- device_name
- device_model
- android_version
- app_version

Example:

Device ID:
DV-849-221-991

Device Name:
Samsung SM-X115

Android:
Android 13

Status:
ONLINE

---

# 6. Device Pairing

Desktop harus dapat melakukan pairing dengan Android.

Metode pairing:

### Method 1 - Device ID

Android menampilkan:

Device ID:
849 221 991

Password:
572941

Desktop memasukkan:

Device ID
Password

### Method 2 - QR Code

Desktop menampilkan QR Code.

Android scan QR.

### Method 3 - Account

Android dan Desktop login menggunakan akun yang sama.

Device otomatis muncul pada daftar perangkat.

---

# 7. Android Permissions

Android Agent membutuhkan permission sesuai fitur yang digunakan.

Potential permissions:

INTERNET

ACCESS_NETWORK_STATE

FOREGROUND_SERVICE

FOREGROUND_SERVICE_MEDIA_PROJECTION

POST_NOTIFICATIONS

MediaProjection permission

Accessibility Service permission

User harus secara eksplisit mengaktifkan permission yang diperlukan.

Aplikasi tidak boleh mengaktifkan Accessibility Service secara diam-diam.

---

# 8. Screen Capture

Screen capture menggunakan:

Android MediaProjection API

Flow:

Desktop request remote
        │
        ▼
Android menerima request
        │
        ▼
User Approve
        │
        ▼
MediaProjection Permission
        │
        ▼
Screen Capture
        │
        ▼
Video Encoder
        │
        ▼
WebRTC
        │
        ▼
Desktop

Target:

Resolution:
720p default

Optional:
1080p

FPS:
15 - 30 FPS

Adaptive bitrate:

500 Kbps - 8 Mbps

---

# 9. Remote Control

Remote control dilakukan melalui AccessibilityService.

Supported actions:

- Tap
- Double Tap
- Long Press
- Swipe
- Scroll
- Back
- Home
- Recent Apps

Desktop mouse mapping:

Left Click
→ Android Tap

Click + Hold
→ Long Press

Drag
→ Swipe

Mouse Wheel
→ Scroll

---

# 10. Coordinate Mapping

Desktop screen size dapat berbeda dengan Android.

Example:

Android:
1080 x 2400

Desktop viewer:
540 x 1200

Mapping:

androidX =
desktopX / viewerWidth * androidWidth

androidY =
desktopY / viewerHeight * androidHeight

Desktop harus mengirim koordinat berdasarkan Android screen coordinate.

---

# 11. Keyboard Input

Desktop keyboard harus dapat digunakan sebagai input Android.

Supported:

- Alphabet
- Number
- Space
- Backspace
- Enter

Optional:

- Ctrl+C
- Ctrl+V
- Text Paste

Architecture:

Desktop Keyboard
       │
       ▼
Input Event
       │
       ▼
WebRTC DataChannel
       │
       ▼
Android
       │
       ▼
Accessibility Service

---

# 12. Android Navigation

Desktop menyediakan tombol:

[ BACK ]

[ HOME ]

[ RECENT ]

[ ROTATE ]

[ VOLUME + ]

[ VOLUME - ]

[ POWER ]

Catatan:

Tidak semua system action tersedia pada seluruh versi/perangkat Android.
Implementasi harus mengikuti kemampuan dan izin resmi Android.

---

# 13. Remote Session Approval

Default mode harus membutuhkan persetujuan pengguna Android.

Android notification/dialog:

Incoming Remote Connection

Computer:
DESKTOP-OFFICE-01

User:
admin@example.com

[ DECLINE ]

[ ALLOW ]

Session tidak boleh dimulai sebelum permission/authorization yang
diperlukan diberikan.

---

# 14. Device Status

Device memiliki status:

ONLINE

OFFLINE

BUSY

REMOTE SESSION

Desktop menampilkan:

Device Name

Device ID

Android Version

Battery

Network

Last Online

Current Status

---

# 15. Desktop Dashboard

Example:

Remote Device Manager

Search Device...

┌──────────────────────────────────────────┐
│ Samsung SM-X115                         │
│ Android 13                              │
│ ● Online                                │
│                          [ CONNECT ]     │
└──────────────────────────────────────────┘

┌──────────────────────────────────────────┐
│ Xiaomi Redmi Note                       │
│ Android 14                              │
│ ● Offline                               │
│                          [ CONNECT ]     │
└──────────────────────────────────────────┘

---

# 16. Remote Viewer

Desktop Remote Viewer:

┌──────────────────────────────────────────────────┐
│ Samsung SM-X115                    ● Connected   │
├──────────────────────────────────────────────────┤
│                                                  │
│                                                  │
│                ANDROID SCREEN                    │
│                                                  │
│                                                  │
├──────────────────────────────────────────────────┤
│ Back | Home | Recent | Rotate | Screenshot       │
├──────────────────────────────────────────────────┤
│ FPS: 28     Latency: 74ms      Bitrate: 2 Mbps   │
└──────────────────────────────────────────────────┘

---

# 17. WebRTC

Recommended transport:

WebRTC Video Track
→ Android screen streaming

WebRTC DataChannel
→ control commands

Example control message:

{
  "type": "tap",
  "x": 540,
  "y": 1200
}

Swipe:

{
  "type": "swipe",
  "startX": 200,
  "startY": 900,
  "endX": 200,
  "endY": 300,
  "duration": 500
}

Keyboard:

{
  "type": "keyboard",
  "text": "Hello World"
}

Navigation:

{
  "type": "navigation",
  "action": "BACK"
}

---

# 18. Signaling Server

WebRTC membutuhkan signaling server.

Responsibilities:

- Device discovery
- Session request
- SDP exchange
- ICE candidate exchange
- Session authentication
- Connection state

WebSocket events:

device.register

device.online

device.offline

session.request

session.accept

session.reject

webrtc.offer

webrtc.answer

webrtc.ice

session.disconnect

---

# 19. STUN / TURN Server

Untuk remote melalui internet gunakan:

STUN Server

dan

TURN Server

Recommended TURN server:

Coturn

Architecture:

Android
   │
   │
   ▼
STUN / TURN
   │
   ▼
Desktop

TURN digunakan ketika peer-to-peer connection tidak dapat terbentuk
karena NAT atau firewall.

---

# 20. REST API

Base URL:

/api/v1

Authentication:

POST /auth/login

POST /auth/logout

POST /auth/refresh

Device:

POST /devices/register

GET /devices

GET /devices/{deviceId}

POST /devices/{deviceId}/heartbeat

Session:

POST /sessions/request

POST /sessions/{sessionId}/accept

POST /sessions/{sessionId}/reject

POST /sessions/{sessionId}/disconnect

---

# 21. Database

## users

id
name
email
password_hash
created_at
updated_at

## devices

id
device_id
user_id
device_name
device_model
android_version
app_version
last_online
status
created_at

## remote_sessions

id
device_id
user_id
desktop_name
started_at
ended_at
status
ip_address

## device_tokens

id
device_id
token
expired_at

---

# 22. Authentication

Authentication:

JWT / OAuth-style token

Token:

access_token

refresh_token

Access token should have short expiration.

Refresh token should be revocable.

---

# 23. Security

Mandatory security requirements:

- HTTPS
- WSS
- WebRTC encryption
- Authentication
- Session authorization
- Device pairing
- Short-lived session token
- Rate limiting
- Audit logging
- Session expiration
- Device revoke

Never send passwords as plaintext.

Never store passwords as plaintext.

---

# 24. Remote Session Token

Setiap remote session harus memiliki token sendiri.

Example:

session_id:
SES-2948201

session_token:
random-secure-token

expires:
5 minutes

Token hanya berlaku untuk satu session.

---

# 25. Session Logging

System menyimpan:

- User
- Device
- Desktop
- Connection time
- Disconnect time
- IP address
- Session status

Example:

User:
admin@example.com

Device:
Samsung SM-X115

Start:
2026-09-17 14:01

Finish:
2026-09-17 14:42

Duration:
41 minutes

---

# 26. Heartbeat

Android Agent mengirim heartbeat.

Interval:

30 seconds

Example:

POST /devices/{deviceId}/heartbeat

Response:

{
  "status": "success"
}

Jika heartbeat tidak diterima selama threshold tertentu:

status = OFFLINE

---

# 27. Reconnection

Jika internet terputus:

CONNECTED
   │
   ▼
CONNECTION LOST
   │
   ▼
RECONNECTING
   │
   ├── success → CONNECTED
   │
   └── timeout → DISCONNECTED

Recommended:

Retry:

1 sec
2 sec
5 sec
10 sec
30 sec

---

# 28. Network Quality

Desktop menampilkan:

Latency

FPS

Bitrate

Packet Loss

Connection Type

Example:

FPS      : 28
Latency  : 72 ms
Bitrate  : 2.4 Mbps
Packet   : 0.2%

---

# 29. Screenshot

Desktop dapat mengambil screenshot dari remote screen.

Format:

PNG

Filename:

remote_{deviceId}_{timestamp}.png

Screenshot disimpan di desktop.

---

# 30. Clipboard

Optional feature:

Desktop → Android clipboard

Android → Desktop clipboard

Clipboard synchronization harus dapat dinonaktifkan.

---

# 31. File Transfer

Phase 2:

Desktop → Android

Android → Desktop

Features:

Upload

Download

Progress

Cancel

Resume

Maximum file size configurable.

---

# 32. Foreground Service

Android Agent menjalankan foreground service selama remote session.

Notification:

Remote Session Active

Connected from:
DESKTOP-OFFICE

[ DISCONNECT ]

User harus selalu dapat menghentikan remote session.

---

# 33. Android Application Pages

Required pages:

Splash Screen

Login

Device Information

Permission Setup

Remote Request

Active Session

Settings

Connection History

About

---

# 34. Desktop Application Pages

Required pages:

Login

Dashboard

Device List

Device Detail

Remote Viewer

Session History

Settings

---

# 35. Flutter Project Structure

Android:

lib/

core/
    api/
    network/
    socket/
    webrtc/
    security/

models/

controllers/

services/
    device_service.dart
    remote_service.dart
    signaling_service.dart
    webrtc_service.dart

pages/
    login/
    home/
    device/
    remote/
    settings/

widgets/

Native:

android/app/src/main/kotlin/

remote/
    ScreenCaptureService.kt
    RemoteAccessibilityService.kt
    ForegroundRemoteService.kt
    RemoteInputHandler.kt

---

# 36. Desktop Structure

lib/

core/

models/

controllers/

services/
    api_service.dart
    signaling_service.dart
    remote_service.dart
    webrtc_service.dart

pages/
    login/
    dashboard/
    devices/
    remote/
    history/
    settings/

widgets/

---

# 37. Backend Structure

src/

controllers/

services/

models/

routes/

middleware/

websocket/

webrtc/

auth/

devices/

sessions/

database/

config/

---

# 38. MVP Scope

Version 1.0 MVP:

Android:

[x] Device registration

[x] Login

[x] Device online/offline

[x] Screen capture

[x] Foreground service

[x] Remote permission

[x] Touch control

[x] Swipe

[x] Back/Home/Recent

Desktop:

[x] Login

[x] Device list

[x] Connect device

[x] Screen viewer

[x] Mouse control

[x] Keyboard input

[x] Disconnect

Backend:

[x] Authentication

[x] Device registry

[x] WebSocket signaling

[x] WebRTC signaling

[x] Session management

[x] Device heartbeat

Infrastructure:

[x] HTTPS

[x] WSS

[x] STUN

[x] TURN

---

# 39. Phase 2

Future features:

- File Transfer
- Clipboard Sync
- Multi Device Remote
- Remote Camera
- Remote Audio
- Device Information
- Device Storage Information
- Application Management
- Network Information
- Session Recording
- Screenshot
- Remote Notification
- Remote Terminal for authorized managed devices
- Device Groups
- Role Based Access Control

---

# 40. Non-Functional Requirements

Performance:

Screen latency target:

LAN:
< 100 ms

Internet:
< 300 ms where network conditions permit

FPS:

Minimum:
15 FPS

Target:
30 FPS

Resolution:

Default:
720p

Maximum:
1080p

Application should automatically reduce bitrate/resolution when network
quality decreases.

---

# 41. Security Requirements

Remote control MUST:

1. Require authenticated user.
2. Require authorized device.
3. Require session token.
4. Use encrypted transport.
5. Show active remote session notification.
6. Allow Android user to terminate session.
7. Log remote sessions.
8. Expire unused session tokens.
9. Protect against replay attacks.
10. Rate-limit connection requests.

---

# 42. Recommended Development Order

Phase 1

Android Device Registration
        ↓
Backend Device Registry
        ↓
Desktop Device List

Phase 2

Android MediaProjection
        ↓
WebRTC Screen Streaming
        ↓
Desktop Screen Viewer

Phase 3

Desktop Mouse
        ↓
WebRTC DataChannel
        ↓
Android AccessibilityService
        ↓
Tap / Swipe

Phase 4

Keyboard
Navigation Button
Reconnect
Network Monitoring

Phase 5

Authentication
Pairing
Session Token
Audit Log
Security Hardening

Phase 6

TURN Server
Internet Remote
Production Deployment

---

# 43. Final Architecture

                         INTERNET

                            │
                    ┌───────▼────────┐
                    │ Backend Server │
                    │                │
                    │ REST API       │
                    │ WebSocket      │
                    │ Authentication │
                    │ Device Registry│
                    └───────┬────────┘
                            │
                 ┌──────────┴──────────┐
                 │                     │
          ┌──────▼──────┐       ┌──────▼───────┐
          │ Android     │       │ Desktop      │
          │ Agent       │       │ Controller   │
          │             │       │              │
          │ Flutter     │       │ Flutter      │
          │ Kotlin      │       │ Windows      │
          └──────┬──────┘       └──────▲───────┘
                 │                     │
                 │      WebRTC         │
                 └─────────────────────┘
                         │
                 ┌───────▼───────┐
                 │ STUN / TURN   │
                 │ Coturn        │
                 └───────────────┘