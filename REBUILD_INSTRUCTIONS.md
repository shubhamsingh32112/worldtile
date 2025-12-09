# 🔄 Rebuild Instructions for .env Changes

## ⚠️ IMPORTANT: .env Changes Require Full Rebuild

When you update the `.env` file, you **MUST** do a full rebuild. Hot reload/hot restart **WILL NOT** pick up `.env` changes!

## ✅ Correct Steps:

### 1. Stop the App Completely
- Press `q` in the terminal where Flutter is running, OR
- Close the app completely on your device

### 2. Clean Build Cache
```bash
cd frontend_app
flutter clean
```

### 3. Get Dependencies
```bash
flutter pub get
```

### 4. Rebuild and Run
```bash
flutter run
```

## 🔍 Verify .env is Loaded

After rebuilding, check the console output. You should see:
- `🌐 Using API_BASE_URL from .env: http://192.168.1.15:3000/api`

If you see:
- `⚠️ API_BASE_URL not set in .env, using platform default`

Then the .env file isn't being loaded correctly.

## 📝 Current .env Configuration

Your `assets/.env` should contain:
```env
MAPBOX_PUBLIC_TOKEN=pk.eyJ1IjoiYXJoYWFuMjEiLCJhIjoiY21peGh0d2NlMDRzbzNncG12MnNsNXZwbiJ9.4wZsgTRYZNNbZRkJlCUobQ
API_BASE_URL=http://192.168.1.15:3000/api
```

## ❌ What NOT to Do

- ❌ Don't just hot reload (press `r`)
- ❌ Don't just hot restart (press `R`)
- ❌ Don't skip `flutter clean`

## ✅ What TO Do

- ✅ Always do `flutter clean` after .env changes
- ✅ Always do full rebuild with `flutter run`
- ✅ Check console logs to verify the URL is loaded

---

**After rebuilding, the app should connect to `http://192.168.1.15:3000/api` instead of `10.0.2.2`**

