# Mapbox Flutter SDK v2.17.0 – Official Developer Reference

## 1. Overview
Mapbox Flutter SDK v2.17.0 aligns with Mapbox Maps SDK v11.17.0. Several old APIs were removed or replaced.

This document covers ONLY APIs that exist in 2.17.0.

---

## 2. Map Initialization

```dart
MapWidget(
  key: ValueKey("map"),
  onMapCreated: _onMapCreated,
  onStyleLoadedListener: _onStyleLoaded,
  cameraOptions: CameraOptions(
    center: Point(coordinates: Position(0, 0)),
    zoom: 2.0,
  ),
  styleUri: MapboxStyles.SATELLITE,
);
```

### Map creation handler

```dart
void _onMapCreated(MapboxMap controller) async {
  map = controller;
}
```

---

## 3. Camera API

### Move immediately
```dart
map.setCamera(CameraOptions(
  center: Point(coordinates: Position(lng, lat)),
  zoom: 12,
));
```

### Animate
```dart
map.flyTo(
  CameraOptions(center: Point(coordinates: Position(lng, lat)), zoom: 15),
  MapAnimationOptions(duration: 1500),
);
```

---

## 4. Screen ↔ Coordinate Conversion

### Screen → Map
```dart
final point = await map.coordinateForPixel(screenCoordinate);
```

### Map → Screen
```dart
final pixel = await map.pixelForCoordinate(point);
```

---

## 5. Style API (Layers & Sources)

### Add source
```dart
await map.style.addSource(
  GeoJsonSource(id: "my-source", data: geojsonString),
);
```

### Add layer
```dart
await map.style.addLayer(
  LineLayer(
    id: "route-layer",
    sourceId: "my-source",
    lineJoin: LineJoin.ROUND,
    lineCap: LineCap.ROUND,
    lineColor: Colors.red.value,
    lineWidth: 3.0,
  ),
);
```

### Update source
```dart
await map.style.updateGeoJSONSourceFeatures(
  "my-source",
  "updated",
  [myNewFeature],
);
```

---

## 6. Annotation API

### 6.1 Point Annotations

Create manager:
```dart
final manager = await map.annotations.createPointAnnotationManager();
```

Create:
```dart
final point = await manager.create(
  PointAnnotationOptions(
    geometry: Point(coordinates: Position(lng, lat)),
    image: myImageBytes,
    iconSize: 1.0,
  ),
);
```

Delete:
```dart
await manager.delete(point);
```

### ❌ Removed in 2.17.0
- `isDraggable`
- `addOnPointAnnotationDragEndListener`
- `addOnPointAnnotationDragListener`
- Any annotation dragging callbacks

**There is NO built-in drag for point annotations.**  
Dragging must be implemented manually using:
- gesture event streams
- coordinateForPixel()

---

## 7. Gesture Events

### Tap
```dart
map.onTapListener = (ScreenCoordinate coord) {
  print(coord.x);
};
```

### Camera change
```dart
map.onCameraChangeListener = (CameraChangedEventData data) {
  final zoom = data.cameraState?.zoom;
};
```

---

## 8. Fog, Atmosphere & Style JSON Modifications

### Get style JSON
```dart
final json = await map.style.getStyleJSON();
```

### Override fog
```dart
map.style.setStyleJSON(modifiedJsonString);
```

---

## 9. Limitations (Important!)

### ❌ NO annotation dragging  
You must create your own drag logic.

### ❌ NO polygon/line dragging  
Only custom drag simulation is possible.

### ✔ rectangle editing requires:
- custom corner handles  
- manual geometry updates  

---

## 10. Feature Matrix

| Feature | Supported |
|--------|-----------|
| Add layers | ✔ |
| Update sources | ✔ |
| Listen for taps | ✔ |
| Fly camera | ✔ |
| Convert screen → map | ✔ |
| Annotation dragging | ❌ Removed |
| Polygon dragging | ❌ Removed |
| Custom gesture logic | ✔ |

