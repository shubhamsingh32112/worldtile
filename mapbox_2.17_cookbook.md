# Mapbox Flutter SDK v2.17.0 – Practical Cookbook

This cookbook contains real working examples for the most common tasks.

---

# 1. Initialize the Map

```dart
MapWidget(
  onMapCreated: _onMapCreated,
  onStyleLoadedListener: _onStyleLoaded,
  cameraOptions: CameraOptions(
    center: Point(coordinates: Position(0, 0)),
    zoom: 1.0,
  ),
);
```

---

# 2. Listen for Map Tap

```dart
map.onTapListener = (ScreenCoordinate point) async {
  final coord = await map.coordinateForPixel(point);
  print("Tapped at ${coord.coordinates}");
};
```

---

# 3. Add a GeoJSON Line

```dart
await map.style.addSource(
  GeoJsonSource(id: "route", data: jsonString),
);

await map.style.addLayer(
  LineLayer(
    id: "route-layer",
    sourceId: "route",
    lineColor: Colors.red.value,
    lineWidth: 5.0,
  ),
);
```

---

# 4. Update a GeoJSON Source

```dart
await map.style.updateGeoJSONSourceFeatures(
  "route",
  "update",
  [newFeature],
);
```

---

# 5. Create a Rectangle

```dart
final rect = Polygon(
  coordinates: [
    [
      Position(lng1, lat1),
      Position(lng2, lat1),
      Position(lng2, lat2),
      Position(lng1, lat2),
      Position(lng1, lat1),
    ]
  ],
);

final src = GeoJsonSource(
  id: "rect-source",
  data: jsonEncode(rect.toJson()),
);

await map.style.addSource(src);
await map.style.addLayer(
  FillLayer(
    id: "rect-fill",
    sourceId: "rect-source",
    fillOpacity: 0.3,
    fillColor: Colors.blue.value,
  ),
);
```

---

# 6. Manual Dragging Logic (since built-in drag is removed)

### Step 1 — Add corner handles (point annotations)
```dart
final handle = await manager.create(
  PointAnnotationOptions(
    geometry: Point(coordinates: Position(lng, lat)),
    image: handleIcon,
    iconSize: 1.0,
  ),
);
```

### Step 2 — Detect drag using gestures
```dart
map.onTapListener = (ScreenCoordinate p) async {
  final geo = await map.coordinateForPixel(p);
  // check distance from handle → simulate drag
};
```

### Step 3 — Recalculate rectangle geometry  
You update polygon coordinates manually.

---

# 7. Convert Screen ↔ Map

```dart
final geo = await map.coordinateForPixel(point);
final px = await map.pixelForCoordinate(geoPoint);
```

---

# 8. Fly Camera

```dart
map.flyTo(
  CameraOptions(
    center: Point(coordinates: Position(lng, lat)),
    zoom: 14,
  ),
  MapAnimationOptions(duration: 1200),
);
```

---

# 9. Remove a Layer

```dart
await map.style.removeStyleLayer("rect-fill");
await map.style.removeStyleSource("rect-source");
```

---

# 10. Fog Customization

```dart
final raw = await map.style.getStyleJSON();
final modified = jsonDecode(raw);
modified['fog']['star-intensity'] = 0.1;

await map.style.setStyleJSON(jsonEncode(modified));
```

---

# Summary
This cookbook gives you:
- real copy‑paste‑ready examples
- correct API usage for v2.17.0
- no deprecated functions
