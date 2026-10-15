# QA Printable Checklist

## Project: QuickSupport Remote Control

### Scope
Android Agent + Backend Signaling + Desktop Controller

---

## A. PRE-TEST CHECKLIST

### 1. Environment
- [ ] Node.js installed
- [ ] Backend dependencies installed
- [ ] Backend server started
- [ ] Android Studio installed
- [ ] Emulator or physical Android device available
- [ ] Device visible through `adb devices`
- [ ] Desktop app can launch

### 2. Backend
- [ ] Run `npm install` in backend folder
- [ ] Run `node src/server.js`
- [ ] Confirm backend starts without error
- [ ] Confirm `http://localhost:3000/health` is reachable
- [ ] Confirm signaling socket is active

### 3. Android Agent
- [ ] App installed on emulator/device
- [ ] Device registration form completed
- [ ] Device ID generated and unique
- [ ] Device name, model, Android version, app version entered
- [ ] Registration submitted successfully
- [ ] Internet permission granted
- [ ] Network state permission granted
- [ ] Foreground service permission granted
- [ ] Notifications permission granted
- [ ] MediaProjection permission granted
- [ ] Accessibility Service enabled
- [ ] App shows `Waiting for remote control request`

### 4. Desktop Controller
- [ ] Desktop app started
- [ ] Device list visible
- [ ] Device appears in available list
- [ ] Controller connected to backend
- [ ] Session ready to request

### 5. Safety / Setup
- [ ] Tester has approval to test remote access
- [ ] Test is run in a controlled environment
- [ ] Device screen is visible before control begins

---

## B. PAIRING FLOW

### On Android
- [ ] Open Android Agent app
- [ ] Complete registration
- [ ] Grant all permissions
- [ ] If Accessibility Service is off, open Android Settings and enable it
- [ ] Tap `Approve` when desktop requests access

### On Desktop
- [ ] Open desktop controller
- [ ] Select target device
- [ ] Wait for signal handshake
- [ ] Confirm device appears as connected
- [ ] Confirm stream loads in remote session screen

---

## C. POST-PAIR TEST CHECKLIST

### Connection
- [ ] Remote stream visible
- [ ] Stream stable for 2–5 minutes
- [ ] No blank screen or repeated disconnects
- [ ] Reconnect works after temporary socket drop

### Mouse / Touch
- [ ] Single tap works
- [ ] Long press works
- [ ] Drag works
- [ ] Scroll works
- [ ] Pointer matches visible UI target

### Keyboard
- [ ] Typing works in focused field
- [ ] Backspace works
- [ ] Enter works
- [ ] Space works
- [ ] Tab works
- [ ] Ctrl+C works for copy
- [ ] Ctrl+V works for paste

### Device / Navigation
- [ ] Back works
- [ ] Home works
- [ ] Recent apps works
- [ ] Rotate works
- [ ] Volume up works
- [ ] Volume down works
- [ ] Power action works

### Clipboard / Focus
- [ ] Copy from selection works
- [ ] Paste into text input works
- [ ] Focus remains on active app after input
- [ ] No unintentional actions trigger while idle

### Error Recovery
- [ ] Accessibility Service warning appears when disabled
- [ ] Android Settings can be opened from app
- [ ] Re-enabling the service restores control
- [ ] Reconnect recovers after loss of signaling

---

## D. PASS / FAIL SUMMARY

### Result
- [ ] PASS
- [ ] FAIL

### Defect summary
- Issue 1:
- Issue 2:
- Issue 3:

### Tester name
- ___________________________

### Date
- ___________________________

### Device info
- Device model: ___________________________
- Android version: ___________________________
- App version: ___________________________

---

## E. QUICK TEST SCRIPT FOR ANDROID STUDIO

### Step 1: Start backend
```bash
cd backend
npm install
node src/server.js
```

### Step 2: Start emulator/device
```bash
adb devices
```

### Step 3: Run Android Agent
1. Open Android project in Android Studio.
2. Select emulator/device.
3. Run app.
4. Fill registration form.
5. Grant all permissions.
6. If Accessibility Service is off, enable it in Android Settings.
7. Wait until app says `Waiting for remote control request`.

### Step 4: Run Desktop Controller
1. Open desktop controller project.
2. Launch app.
3. Select the device.
4. Approve pairing on Android.
5. Confirm stream appears.

### Step 5: Validate controls
- Tap / drag / scroll
- Type text
- Use Back / Home / Recent
- Try Rotate / Volume / Power
- Try Copy / Paste
- Check reconnect behavior

### Step 6: Record result
- Mark pass/fail in summary section
- Add issues and screenshots if needed
