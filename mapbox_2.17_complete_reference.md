# Mapbox Flutter SDK 2.17.0 — Complete Developer Reference (Hybrid A+B+C)

This document functions as:
- **A — Official-style API Reference**
- **B — Practical Cookbook**
- **C — Migration Guide**

---

# 1. Overview of SDK 2.17.0

Mapbox Flutter 2.17.0 aligns versioning with iOS/Android v11.17.0.

### ⚠️ Important breaking changes:
- Annotation dragging **removed**
- Annotation listeners refactored
- GeoJSON source API changed
- Layer constructors refactored  
- Many v2.12 examples online are **invalid**

---

# 2. Map Initialization (Reference)

```dart
MapWidget(
  key: ValueKey("mapWidget"),
  onMapCreated: _onMapCreated,
  onStyleLoadedListener: _onStyleLoaded,
  cameraOptions: CameraOptions(
    center: Point(coordinates: Position(0,0)),
    zoom: 3,
  ),
  styleUri: MapboxStyles.MAPBOX_STREETS,
);
```

---

# 3. Gesture System (Reference)

## 3.1 Tap
```dart
mapboxMap!.gestures.onTap.listen((ScreenCoordinate point) async {
  final coord = await mapboxMap!.coordinateForPixel(point);
});
```

## 3.2 Long Press
```dart
mapboxMap!.gestures.onLongTap.listen(...)
```

## 3.3 Camera Change
```dart
mapboxMap!.camera.onCameraChanged.listen((data) {
  print(data.cameraState?.zoom);
});
```

---

# 4. GeoJSON Sources (Reference)

## Add source
```dart
style.addSource(GeoJsonSource(id: "polygon-source", data: "{}"));
```

## Update source
```dart
style.setStyleSourceProperty(
  "polygon-source",
  "data",
  jsonEncode(newFeatureCollection),
);
```

### ❌ `updateGeoJsonSource()` NO LONGER EXISTS

---

# 5. Layers (Reference)

## 5.1 Fill Layer
```dart
await style.addLayer(
  FillLayer(
    id: "polygon-fill",
    sourceId: "polygon-source",
    fillLayerProperties: FillLayerProperties(
      fillColor: Colors.blue.value,
      fillOpacity: 0.4,
    ),
  ),
);
```

## 5.2 Line Layer
```dart
await style.addLayer(
  LineLayer(
    id: "polygon-line",
    sourceId: "polygon-source",
    lineLayerProperties: LineLayerProperties(
      lineColor: Colors.white.value,
      lineWidth: 2.0,
    ),
  ),
);
```

---

# 6. Annotation System (Reference)

## 6.1 Create manager
```dart
final manager = await map.annotations.createPointAnnotationManager();
```

## 6.2 Create annotation
```dart
final ann = await manager.create(PointAnnotationOptions(
  geometry: Point(coordinates: Position(lng, lat)),
  image: bytes,
  iconSize: 1.0,
));
```

## 6.3 Delete annotation
```dart
await manager.delete(ann);
```

---

# 7. Annotation Dragging (Cookbook)

⚠️ **Draggable annotations DO NOT EXIST in SDK 2.17.0**

### How to implement custom dragging:

---

## 7.1 Detect tap start
```dart
map.gestures.onTap.listen((ScreenCoordinate p) {
  // Check if user tapped near a handle.
});
```

---

## 7.2 Detect drag using pointer events
Inside your widget:

```dart
Listener(
  onPointerMove: (event) {
    final pixel = ScreenCoordinate(
      x: event.localPosition.dx,
      y: event.localPosition.dy,
    );
    final coord = await map.coordinateForPixel(pixel);
    moveRectangleTo(coord);
  },
  child: MapWidget(...),
);
```

---

# 8. Rectangle Drawing (Cookbook)

## 8.1 Create rectangle polygon
```dart
Polygon(
  coordinates: [
    [
      Position(lng1, lat1),
      Position(lng2, lat2),
      Position(lng3, lat3),
      Position(lng4, lat4),
      Position(lng1, lat1),
    ]
  ],
);
```

## 8.2 Update via setStyleSourceProperty
```dart
style.setStyleSourceProperty(
  "rectangle-source",
  "data",
  jsonEncode(fc),
);
```

---

# 9. Migration Guide (Integrated Summary)

| Feature | Old | New |
|--------|------|------|
| Dragging | `draggable = true` | ❌ Removed |
| Drag Listener | `addDragListener()` | ❌ Removed |
| GeoJSON update | `updateGeoJsonSource()` | `setStyleSourceProperty()` |
| Tap listener | `onMapClickListener` | `gestures.onTap.listen()` |
| Camera listener | `onCameraChangedListener` | `camera.onCameraChanged.listen()` |
| Position fields | `.lon` | `.lng` |

---

# 10. FAQs

### ❓ Why did Mapbox remove draggable annotations?
Performance + cross-platform parity.  
You must now implement **custom drag logic**.

### ❓ Is this similar to Mapbox iOS/Android v11?
Yes — this SDK is a wrapper around the v11 native system.

---

# 11. Best Practices

### ✔ Create ONE annotation manager  
### ✔ Reuse handles, don't recreate constantly  
### ✔ Use setStyleSourceProperty for all GeoJSON updates  
### ✔ Never mutate Style JSON before style loads fully  
### ✔ Always wrap drag logic in throttle/debounce  

---

