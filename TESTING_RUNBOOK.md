# QuickSupport Testing Runbook

This runbook is intended for real-device and emulator validation of the Android agent, backend signaling server, and desktop controller. It is designed to be used before pairing (pre-flight checklist) and after pairing (post-pair validation checklist).

## 1. Preconditions

### Environment

- Node.js installed and available in PATH.
- Backend dependencies installed via `npm install` in the backend folder.
- Android Studio installed with an emulator or a physical Android device connected via USB debugging.
- Flutter SDK installed if you want to build and run the Android app from source.
- Desktop controller project available and launchable with Flutter.

### Backend verification

1. Open a terminal in the backend folder.
2. Run:
   ```bash
   npm install
   node src/server.js
   ```
3. Confirm the server starts without errors.
4. Verify the health endpoint:
   ```bash
   curl http://localhost:3000/health
   ```
5. Expected response includes `status: "ok"` and a valid JSON payload.

### Device prerequisites

- Android device or emulator with USB debugging enabled.
- For real device: enable Developer Options and allow USB debugging.
- For emulator: ensure the device is booted and visible in `adb devices`.
- Check device connectivity:
  ```bash
  adb devices
  ```
- For Android 11+ or newer, ensure Accessibility Service is allowed after installation.

---

## 2. Pre-pairing checklist (before pairing)

Use this checklist before the remote session is approved.

### A. Backend

- [ ] Backend is running on `http://localhost:3000`
- [ ] `/health` returns HTTP 200
- [ ] WebSocket signaling server is listening
- [ ] Device registry endpoint is available

### B. Android Agent

- [ ] App is installed on emulator or real device
- [ ] Device registration form is completed
- [ ] Device ID is unique and persistent
- [ ] Device name / model / Android version are filled
- [ ] Internet permission granted
- [ ] Network State permission granted
- [ ] Foreground service permission granted
- [ ] Notifications permission granted
- [ ] MediaProjection permission granted
- [ ] Accessibility Service is enabled in Android Settings
- [ ] Agent is in “Waiting for remote control request” state

### C. Desktop Controller

- [ ] Desktop app starts without crash
- [ ] Device list is visible
- [ ] Backend connection is active
- [ ] Target device appears in the available list
- [ ] Controller is ready to request a session

### D. Safety checks

- [ ] User approves the remote-control session on the device
- [ ] Device screen is visible before control starts
- [ ] No unnecessary permissions remain unapproved
- [ ] Test is performed in a controlled environment

---

## 3. Pairing flow (device + desktop)

### Step 1: Start the backend

```bash
cd backend
npm install
node src/server.js
```

### Step 2: Launch the Android Agent

1. Build and run the app on the emulator or physical device.
2. Fill in the registration form.
3. Submit the device registration.
4. Continue through the permissions screen.
5. If the app says Accessibility Service is not enabled, open Android Settings and enable it.
6. Confirm the app reaches the “Waiting for remote control request” state.

### Step 3: Open the desktop controller

1. Start the desktop app.
2. Select the Android device from the list.
3. Wait for the signaling handshake to complete.
4. Confirm that the controller and agent both show the session as active.

### Step 4: Approve pairing on the Android device

1. The Android screen should show a remote request prompt.
2. Tap “Approve”.
3. The device should show that the remote session has started.
4. The desktop app should show the remote stream once the peer connection is ready.

### Step 5: Confirm the stream appears

Check the following:

- Desktop stream is not blank
- Stream resolution is present and stable
- Mouse interaction is accepted
- Keyboard focus is active on the currently visible app

---

## 4. Post-pairing checklist (after pairing)

This checklist validates that the session is truly usable.

### Connectivity and session health

- [ ] Remote stream loads successfully
- [ ] Session remains stable for at least 2–5 minutes
- [ ] No repeated disconnects or blank screen loops
- [ ] Reconnect logic triggers if the socket drops temporarily
- [ ] Controller can request reconnect without restarting the app

### Mouse / touch controls

- [ ] Single tap works on the target app
- [ ] Long press works for context actions
- [ ] Drag works for selection/slide gestures
- [ ] Scroll works in lists and web content
- [ ] Pointer coordinates remain aligned with visible UI

### Keyboard controls

- [ ] Typing enters text in the focused Android field
- [ ] Enter / Backspace / Tab / Space work correctly
- [ ] Ctrl+C and Ctrl+V trigger copy/paste actions when supported
- [ ] Keyboard focus remains on the active app after sending input

### Navigation and device controls

- [ ] Back button works
- [ ] Home button works
- [ ] Recent apps button works
- [ ] Rotate action works if supported
- [ ] Volume Up works
- [ ] Volume Down works
- [ ] Power action behaves as expected

### Clipboard and app interaction

- [ ] Copy from Android app works when text is selected
- [ ] Paste into an input field works
- [ ] Shortcuts do not break active app focus
- [ ] No random background actions fire when no input is expected

### Recovery / fallback

- [ ] If Accessibility Service gets disabled, the app warns the user
- [ ] User can open Android Settings from within the app
- [ ] Re-enabling access restores control flow
- [ ] Controller can reconnect after temporary backend interruption

---

## 5. Acceptance criteria

The test is considered successful when all of the following are true:

- Device is registered and visible in the desktop list.
- Pairing request is approved on the Android side.
- Remote stream appears and remains stable.
- Mouse, keyboard, and system shortcuts respond correctly.
- Accessibility fallback path works when the service is disabled.
- Reconnect flow recovers cleanly after a socket interruption.

---

## 6. Troubleshooting quick fixes

### Device not showing in desktop list

- Verify backend is running.
- Check the device is registered successfully.
- Confirm the Android app sent a valid registration payload.

### Stream stays blank

- Verify device approval is complete.
- Check WebRTC signaling messages in the backend logs.
- Confirm Android app and desktop app are connected to the same backend instance.

### Accessibility not working

- Go to Android Settings > Accessibility > QuickSupport Agent.
- Turn on the service.
- Return to the app and re-run the permission check.

### Keyboard input not reaching the active app

- Ensure the app is focused on the target field.
- Confirm the remote session is still active.
- Re-send the event and confirm the focus stays on the target window.

---

## 7. Recommended tester checklist

Before testing:

- [ ] Backend served correctly
- [ ] Device online and registered
- [ ] Accessibility enabled
- [ ] App permission set complete
- [ ] Session request ready

After pairing:

- [ ] Stream visible
- [ ] Mouse works
- [ ] Keyboard works
- [ ] Navigation works
- [ ] Copy/paste works
- [ ] Reconnect works
- [ ] Exit flow is controlled and safe
