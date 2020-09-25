part of navigation;

/// Turn-By-Turn Navigation Provider
class MapBoxNavigation implements IMapBoxNavigation {
  factory MapBoxNavigation({ValueSetter<RouteEvent> onRouteEvent}) {
    if (_instance == null) {
      final MethodChannel methodChannel =
      const MethodChannel('flutter_mapbox_navigation');
      final EventChannel eventChannel =
      const EventChannel('flutter_mapbox_navigation/events');
      _instance =
          MapBoxNavigation.private(methodChannel, eventChannel, onRouteEvent);
    }
    return _instance;
  }

  @visibleForTesting
  MapBoxNavigation.private(
      this._methodChannel, this._routeEventchannel, this._routeEventNotifier);

  static MapBoxNavigation _instance;

  final MethodChannel _methodChannel;
  final EventChannel _routeEventchannel;
  final ValueSetter<RouteEvent> _routeEventNotifier;

  Stream<RouteEvent> _onRouteEvent;
  StreamSubscription<RouteEvent> _routeEventSubscription;

  ///Current Device OS Version
  Future<String> get platformVersion => _methodChannel
      .invokeMethod('getPlatformVersion')
      .then<String>((dynamic result) => result);

  ///Total distance remaining in meters along route.
  Future<double> get distanceRemaining => _methodChannel
      .invokeMethod<double>('getDistanceRemaining')
      .then<double>((dynamic result) => result);

  ///Total seconds remaining on all legs.
  Future<double> get durationRemaining => _methodChannel
      .invokeMethod<double>('getDurationRemaining')
      .then<double>((dynamic result) => result);

  ///Show the Navigation View and Begins Direction Routing
  ///
  /// [origin] must not be null. It must have a longitude, latitude and name.
  /// [destination] must not be null. It must have a longitude, latitude and name.
  /// [options] options used to generate the route and used while navigating
  ///
  /// Begins to generate Route Progress
  ///
  Future startNavigation(
      {WayPoint origin,
        WayPoint destination,
        MapBoxOptions options}) async {
    assert(origin != null);
    assert(origin.name != null);
    assert(origin.latitude != null);
    assert(origin.longitude != null);
    assert(destination != null);
    assert(destination.name != null);
    assert(destination.latitude != null);
    assert(destination.longitude != null);
    final Map<String, Object> wayPointMap = <String, dynamic>{
      "originName": origin.name,
      "originLatitude": origin.latitude,
      "originLongitude": origin.longitude,
      "destinationName": destination.name,
      "destinationLatitude": destination.latitude,
      "destinationLongitude": destination.longitude
    };

    var args = {};
    args.addAll(wayPointMap);
    args.addAll(options.toMap());

    _routeEventSubscription = _streamRouteEvent.listen(_onProgressData);
    await _methodChannel
        .invokeMethod('startNavigation', args)
        .then<String>((dynamic result) => result);
  }

  ///Show the Navigation View and Begins Direction Routing
  ///
  /// [wayPoints] must not be null. A collection of [WayPoint](longitude, latitude and name). Must be at least 2 or at most 25. Cannot use drivingWithTraffic mode if more than 3-waypoints.
  /// [options] options used to generate the route and used while navigating
  /// Begins to generate Route Progress
  ///
  Future startNavigationWithWayPoints(
      {List<WayPoint> wayPoints, MapBoxOptions options}) async {
    assert(wayPoints != null);
    assert(wayPoints.length > 1);
    if (Platform.isIOS && wayPoints.length > 3) {
      assert(options.mode != MapBoxNavigationMode.drivingWithTraffic,
      "Error: Cannot use drivingWithTraffic Mode when you have more than 3 Stops");
    }
    var pointList = List<Map<String, Object>>();

    for (int i = 0; i < wayPoints.length; i++) {
      var wayPoint = wayPoints[i];
      assert(wayPoint != null);
      assert(wayPoint.name != null);
      assert(wayPoint.latitude != null);
      assert(wayPoint.longitude != null);

      final pointMap = <String, dynamic>{
        "Order": i,
        "Name": wayPoint.name,
        "Latitude": wayPoint.latitude,
        "Longitude": wayPoint.longitude,
      };
      pointList.add(pointMap);
    }
    var i = 0;
    var wayPointMap =
    Map.fromIterable(pointList, key: (e) => i++, value: (e) => e);

    var  args = options.toMap();
    args["wayPoints"] = wayPointMap;

    _routeEventSubscription = _streamRouteEvent.listen(_onProgressData);
    await _methodChannel
        .invokeMethod('startNavigationWithWayPoints', args)
        .then<String>((dynamic result) => result);
  }

  ///Ends Navigation and Closes the Navigation View
  Future<bool> finishNavigation() async {
    var success = await _methodChannel.invokeMethod('finishNavigation', null);
    return success;
  }

  void _onProgressData(RouteEvent event) {
    if (_routeEventNotifier != null) _routeEventNotifier(event);

    if (event.eventType == MapBoxEvent.on_arrival)
      _routeEventSubscription.cancel();
  }

  Stream<RouteEvent> get _streamRouteEvent {
    if (_onRouteEvent == null) {
      _onRouteEvent = _routeEventchannel
          .receiveBroadcastStream()
          .map((dynamic event) => _parseRouteEvent(event));
    }
    return _onRouteEvent;
  }

  RouteEvent _parseRouteEvent(String jsonString) {
    RouteEvent event;
    var map = json.decode(jsonString);
    var progressEvent = RouteProgressEvent.fromJson(map);
    if (progressEvent != null && progressEvent.isProgressEvent) {
      event = RouteEvent(
          eventType: MapBoxEvent.progress_change, data: progressEvent);
    } else
      event = RouteEvent.fromJson(map);
    return event;
  }
}

///Option to specify the mode of transportation.
@Deprecated("Use MapBoxNavigationMode instead")
enum NavigationMode { walking, cycling, driving, drivingWithTraffic }

///Option to specify the mode of transportation.
enum MapBoxNavigationMode { walking, cycling, driving, drivingWithTraffic }

///Whether or not the units used inside the voice instruction's string are in imperial or metric.
enum VoiceUnits { imperial, metric }