# Mapbox Flutter SDK Migration Guide (v2.12 → v2.17)

This document provides a clear **“use this instead of this”** breakdown for updating Mapbox Flutter codebases to **SDK v2.17.0**.

---

## 1. 📌 Annotation Dragging — REMOVED

### ❌ Old API (v2.12)
```dart
manager.addOnPointAnnotationDragListener(...)
annotationOptions.draggable = true;
```

### ✅ v2.17 Reality
Mapbox REMOVED all built‑in dragging for annotations.

### ✔ Replacement
You *must* implement custom dragging:

1. Listen for map gestures  
2. Convert pixel → geo coordinate  
3. Move your polygons/rectangles manually

---

## 2. 📌 Tap / Gesture Listeners — CHANGED

### ❌ Old API
```dart
map.onMapClickListener = ...
map.onCameraChangedListener = ...
```

### ✔ New API
```dart
map.gestures.onTap.listen(...)
map.camera.onCameraChanged.listen(...)
```

---

## 3. 📌 GeoJSON Source Updates — CHANGED

### ❌ Old API
```dart
style.updateGeoJsonSource(id, GeoJsonSourceData(...));
```

### ✔ New API
```dart
style.setStyleSourceProperty(id, "data", jsonString);
```

---

## 4. 📌 Layers — Constructor Names CHANGED

### ❌ Old API
```dart
FillLayer(
  id: "...",
  properties: FillLayerProperties(...)
)
```

### ✔ New API
```dart
FillLayer(
  id: "...",
  fillLayerProperties: FillLayerProperties(...)
)
```

Same applies to:

- LineLayer  
- CircleLayer  
- SymbolLayer  

---

## 5. 📌 Annotation Manager — CHANGES

### ❌ Old
```dart
createPointAnnotationManager()
manager.createMulti(optionsList)
manager.deleteAll()
```

### ✔ New
```dart
final manager = await map.annotations.createPointAnnotationManager();
await manager.create(options);
await manager.delete(annotation);
```

`createMulti()` and `deleteAll()` removed.

---

## 6. 📌 Position API — CHANGED

### ❌ Old
```dart
pos.lon
pos.lat
```

### ✔ New
```dart
pos.lng
pos.lat
```

---

## 7. 📌 ScreenCoordinate → Geo — CHANGED

### ❌ Old
```dart
map.pixelToCoordinate(point)
```

### ✔ New
```dart
final coord = await map.coordinateForPixel(point);
coord.coordinates.lng
coord.coordinates.lat
```

---

## 8. Gesture Settings Actually Exist in v2.17.0

Here is the exact real API, straight from settings.dart (your error log points to it):

GesturesSettings({ bool rotateEnabled, bool pinchToZoomEnabled, bool simultaneousRotateAndPinchToZoomEnabled, bool pitchEnabled, bool scrollEnabled, bool doubleTapToZoomInEnabled, bool doubleTouchToZoomOutEnabled, bool quickZoomEnabled })

🔥 Notice: THERE IS NO zoomEnabled.
Zoom is controlled by:

pinchToZoomEnabled

doubleTapToZoomInEnabled

doubleTouchToZoomOutEnabled

quickZoomEnabled
---

