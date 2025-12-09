# Physical Device Setup Guide

## 🔧 Problem: Connection Error on Physical Devices

When testing on a **physical mobile device**, you'll get a "Connection error" because:
- Physical devices can't access `localhost` or `10.0.2.2`
- They need your **computer's actual IP address** on the local network

## ✅ Solution: Configure API Base URL

### Step 1: Find Your Computer's IP Address

#### Windows:
```bash
ipconfig
```
Look for **IPv4 Address** under your active network adapter (usually `192.168.x.x` or `10.x.x.x`)

#### Mac/Linux:
```bash
ifconfig
# or
ip addr show
```
Look for `inet` address (usually `192.168.x.x` or `10.x.x.x`)

### Step 2: Update `.env` File

1. Open `frontend_app/assets/.env`
2. Add your computer's IP address:

```env
MAPBOX_PUBLIC_TOKEN=pk.your_token_here

# IMPORTANT: Replace 192.168.1.100 with YOUR computer's IP address
API_BASE_URL=http://192.168.1.100:3000/api
```

**Example:**
If your computer's IP is `192.168.1.50`, use:
```env
API_BASE_URL=http://192.168.1.50:3000/api
```

### Step 3: Update Backend Server

The backend server has been updated to:
- ✅ Listen on `0.0.0.0` (accepts connections from other devices)
- ✅ Allow CORS from all origins in development

**Make sure your backend is running:**
```bash
cd backend
npm run dev
```

You should see:
```
🚀 Server running on port 3000
🌐 Server accessible at:
   - http://localhost:3000
   - http://0.0.0.0:3000
   - Use your computer's IP address for mobile devices
   - Example: http://192.168.1.XXX:3000
```

### Step 4: Ensure Same Network

**IMPORTANT:** Your phone and computer must be on the **same Wi-Fi network**!

- ✅ Both connected to same Wi-Fi
- ❌ Phone on mobile data, computer on Wi-Fi
- ❌ Different Wi-Fi networks

### Step 5: Test Connection

1. Make sure backend is running
2. Update `.env` with your IP address
3. Rebuild the Flutter app:
   ```bash
   cd frontend_app
   flutter clean
   flutter pub get
   flutter run
   ```

## 🔍 Troubleshooting

### Still Getting Connection Error?

1. **Check Firewall:**
   - Windows: Allow Node.js through Windows Firewall
   - Mac: System Preferences → Security → Firewall

2. **Verify IP Address:**
   - Make sure you're using the correct IP (not `127.0.0.1`)
   - IP should be in format `192.168.x.x` or `10.x.x.x`

3. **Test Backend from Phone:**
   - Open browser on your phone
   - Go to: `http://YOUR_IP:3000/health`
   - Should see: `{"status":"OK","message":"WorldTile API is running"}`

4. **Check Network:**
   - Ensure phone and computer are on same Wi-Fi
   - Try disabling VPN if active

5. **Verify .env File:**
   - Make sure `API_BASE_URL` is set correctly
   - No extra spaces or quotes
   - Format: `API_BASE_URL=http://192.168.1.100:3000/api`

## 📱 Platform-Specific Notes

### Android Physical Device
- Must set `API_BASE_URL` in `.env`
- Cannot use `10.0.2.2` (only works in emulator)

### iOS Physical Device
- Must set `API_BASE_URL` in `.env`
- Cannot use `localhost` (only works in simulator)

### Android/iOS Emulator
- Can use default settings (no `API_BASE_URL` needed)
- Android emulator: `10.0.2.2` works automatically
- iOS simulator: `localhost` works automatically

## 🎯 Quick Checklist

- [ ] Found computer's IP address
- [ ] Updated `assets/.env` with `API_BASE_URL`
- [ ] Backend server is running
- [ ] Phone and computer on same Wi-Fi
- [ ] Tested backend from phone browser (`/health` endpoint)
- [ ] Rebuilt Flutter app after .env changes

---

**Need Help?** If you're still having issues, check:
1. Backend server logs for connection attempts
2. Phone's browser can access `http://YOUR_IP:3000/health`
3. Firewall isn't blocking port 3000

