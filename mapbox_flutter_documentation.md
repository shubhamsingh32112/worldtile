Listening for interactions:


The Maps SDK for Flutter has an extensive system for listening to Tap and Long Press gestures on the map. Add your preferred listener to MapWidget to receive these events.

// Add an onTapListener to the `MapWidget`
final MapWidget mapWidget = MapWidget(
  key: ValueKey("mapWidget"),
  onTapListener: _onTap,
);

// Print out map coordinates and screen position at tapped location
_onTap(MapContentGestureContext context) {
  print("OnTap coordinate: {${context.point.coordinates.lng}, ${context.point.coordinates.lat}}" +
      " point: {x: ${context.touchPosition.x}, y: ${context.touchPosition.y}}");
}

Camera position
On this page
Set camera position
Set camera on map initialization
Set camera after map initialization
Fit the camera to a given shape
Listen for camera changes
Get camera position
Restrict camera
The Mapbox Maps SDK for Flutter gives you complete control over the position of the map camera. The camera’s location and behavior is defined by the following properties:

center: The longitude and latitude at which the camera is pointed.
bearing: The visual rotation of the map. The bearing value is the compass direction the camera points to show the user which way is "up". For example, a bearing of 90° orients the map so that east is up.
pitch: The visual tilt of the map. A pitch of 0° is perpendicular to the surface, looking straight down at the map, while a greater value like 60° looks ahead towards the horizon.
zoom: The zoom level specifies how close the camera is to the features being viewed. At zoom level 0, the viewport shows continents and oceans. A middle value of 11 shows city-level details, and at a higher zoom level the map begins to show buildings and points of interest.
padding: Insets from each edge of the map, which impacts the location at which the center point is rendered.
anchor: The point in the map’s coordinate system about which zoom and bearing should be applied. This is mutually exclusive with center.



Set camera position
The Mapbox Maps SDK for Flutter allows you to set the camera's position on map initialization, or after the map has already been initialized. You can also set the camera's position based on the user's location or fit the camera to a specific shape.

Set camera on map initialization
You can specify the camera position when you initialize the map by defining CameraOptions, passing those options to MapWidget, and using those options when initializing the map. This approach is best if you know what part of the world you want to show to the user first. Since the SDK will load the tiles around the specified location first, the map may appear to load faster.

// Define center coordinates, zoom, pitch, bearing
let cameraOptions = CameraOptions(
  center: Point(
      coordinates: Position(
    6.0033416748046875,
    43.70908256335716,
  )),
  zoom: 3.0,
  bearing: -17.6,
  pitch: 45);

// Pass camera options to the `MapWidget` when initializing the map
MapWidget(
  key: ValueKey("mapWidget"),
  cameraOptions: cameraOptions);

Set camera after map initialization
In some cases you may want to set the camera's position after the map has been initialized based on an event or user interaction. For example, you may want to center the map camera on an annotation when a user taps on it. Use mapboxMap.setCamera() to set the camera to you preferred options:

mapboxMap.setCamera(CameraOptions(
  center: Point(
      coordinates: Position(
    0.381457,
    6.687337,
  )),
  padding: MbxEdgeInsets(top: 1, left: 2, bottom: 3, right: 4),
  anchor: ScreenCoordinate(x: 1, y: 1),
  zoom: 3,
  bearing: 20,
  pitch: 30));
Fit the camera to a given shape
You can position the camera to fit a specified shape within the viewport.

To fit a camera for a given geometry, call .mapboxMap.cameraForGeometry().
To fit the camera to a set of rectangular coordinate bounds (in other words, a bounding box), call .mapboxMap.cameraForCoordinateBounds().
This example fits the camera to a collection of coordinates, adjusting the provided CameraOptions:

// The reference camera options are applied before calculating a camera fitting the given coordinates.
// If any of the fields in this referenceCamera options are not provided then the current value from the map will be used.
let referenceCamera = CameraOptions(zoom: 5, bearing: 45)

// Fit camera to the given coordinates.
let camera = mapboxMap.cameraForCoordinatesCameraOptions(
  [
    Point(
      coordinates: Position(
      43.274580742195845, -2.938070297241211
    ),
    Point(
      coordinates: Position(
      43.258768377941465, -2.9680252075195312
    ),
    Point(
      coordinates: Position(
      43.24063848114794, -2.912750244140625
    ),
    Point(
      coordinates: Position(
      43.24063848114794, -2.912750244140625
    )
  ],
  referenceCamera,
  coordinatesPadding: .zero,
  ScreenBox(
    min: ScreenCoordinate(x: 0, y: 0),
    max: ScreenCoordinate(x: 100, y: 100)));

mapboxMap.setCamera(camera);
This example fits the camera to a bounding box:

// Define bounding box
let bounds = CoordinateBounds(
  southwest: Point(
      coordinates: Position(
    1.0,
    2.0,
  )),
  northeast: Point(
      coordinates: Position(
    3.0,
    4.0,
  )),
  infiniteBounds: true);

// Center the camera on the bounds
let camera = mapboxMap.cameraForCoordinateBounds(bounds);
mapboxMap.setCamera(camera);
Listen for camera changes
To listen to camera updates, you can add an onCameraChangeListener to your MapWidget.

// Add an onCameraChangeListener to the `MapWidget`
final MapWidget mapWidget = MapWidget(
  key: ValueKey("mapWidget"),
  onCameraChangeListener: _onCameraChangeListener,
);

// Print out the timestamp every time the camera changes
_onCameraChangeListener(CameraChangedEventData data) {
  print("CameraChangedEventData: timestamp: ${data.timestamp}");
}
Get camera position
Once the map has been initialized, you can retrieve the camera's position to understand what the user is viewing, and other camera-related information, by calling .mapboxMap.getCameraState().

For example, you could display the camera's latitude, longitude, zoom, bearing, and pitch as text:

let cameraState = mapboxMap.getCameraState()

Restrict camera
Use .mapboxMap.setBounds() function to restrict a user's panning to limit the map camera to a chosen area.

For example, you could create a location-specific app experience in which a user's panning behavior is limited to a specific country, like Iceland.

let bounds = CoordinateBounds(
  southwest: Point(
      coordinates: Position(
    63.33, 
    -25.52,
  )),
  northeast: Point(
      coordinates: Position(
    66.61,
    -13.47,
  )),
  infiniteBounds: true)

// Restrict the camera to `bounds`
mapboxMap.setBounds(CameraBoundsOptions(
  bounds: bounds, 
  maxZoom: 10, 
  minZoom: 4
)