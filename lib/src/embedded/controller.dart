import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import '../models/models.dart';

/// Controller for a single MapBox Navigation instance running on the host platform.
class MapBoxNavigationViewController {
  late MethodChannel _methodChannel;
  late EventChannel _eventChannel;

  ValueSetter<RouteEvent>? _routeEventNotifier;

  MapBoxNavigationViewController(
      int id, ValueSetter<RouteEvent>? eventNotifier) {
    _methodChannel = new MethodChannel('flutter_mapbox_navigation/$id');
    _methodChannel.setMethodCallHandler(_handleMethod);

    _eventChannel = EventChannel('flutter_mapbox_navigation/$id/events');
    _routeEventNotifier = eventNotifier;
  }

  Stream<RouteEvent>? _onRouteEvent;
  late StreamSubscription<RouteEvent> _routeEventSubscription;

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

  ///Build the Route Used for the Navigation
  ///
  /// [wayPoints] must not be null. A collection of [WayPoint](longitude, latitude and name). Must be at least 2 or at most 25. Cannot use drivingWithTraffic mode if more than 3-waypoints.
  /// [options] options used to generate the route and used while navigating
  ///
  Future<bool> buildRoute(
      {required List<WayPoint> wayPoints, MapBoxOptions? options}) async {
    assert(wayPoints.length > 1);
    if (Platform.isIOS && wayPoints.length > 3 && options?.mode != null) {
      assert(options!.mode != MapBoxNavigationMode.drivingWithTraffic,
          "Error: Cannot use drivingWithTraffic Mode when you have more than 3 Stops");
    }
    List<Map<String, Object?>> pointList = [];

    for (int i = 0; i < wayPoints.length; i++) {
      var wayPoint = wayPoints[i];
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

    Map<String, dynamic> args = Map<String, dynamic>();
    if (options != null) args = options.toMap();
    args["wayPoints"] = wayPointMap;

    _routeEventSubscription = _streamRouteEvent!.listen(_onProgressData);
    return await _methodChannel
        .invokeMethod('buildRoute', args)
        .then<bool>((dynamic result) {
      print("MAPBOX PACKAGE - BUILD ROUTE NAVIGATION: $result");
      return result;
    });
  }

  ///Update route of Navigation
  ///
  /// [wayPoints] must not be null. A collection of [WayPoint](longitude, latitude and name). Must be at least 2 or at most 25. Cannot use drivingWithTraffic mode if more than 3-waypoints.
  /// [options] options used to generate the route and used while navigating
  ///
  Future<bool> updateNavigation({
    required List<WayPoint> wayPoints,
  }) async {
    assert(wayPoints.length > 0);
    List<Map<String, Object?>> pointList = [];

    for (int i = 0; i < wayPoints.length; i++) {
      var wayPoint = wayPoints[i];
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

    Map<String, dynamic> args = Map<String, dynamic>();
    args["wayPoints"] = wayPointMap;
    return await _methodChannel
        .invokeMethod('updateNavigation', args)
        .then<bool>((dynamic result) {
      print("MAPBOX PACKAGE - UPDATE ROUTE NAVIGATION: $result");
      return result;
    });
  }

  /// starts listening for events
  Future<void> initialize() async {
    //_routeEventSubscription = _streamRouteEvent!.listen(_onProgressData);
  }

  /// Clear the built route and resets the map
  Future<bool?> clearRoute() async {
    return await _methodChannel
        .invokeMethod('clearRoute', null)
        .then<bool>((dynamic result) {
      print("MAPBOX PACKAGE - Clear ROUTE NAVIGATION: $result");
      return result;
    });
  }

  /// Starts the Navigation
  Future<bool?> startNavigation({MapBoxOptions? options}) async {
    Map<String, dynamic>? args;
    if (options != null) args = options.toMap();
    //_routeEventSubscription = _streamRouteEvent!.listen(_onProgressData);
    return await _methodChannel
        .invokeMethod('startNavigation', args)
        .then<bool>(
      (dynamic value) {
        print("MAPBOX PACKAGE - START NAVIGATION: $value");
        return value;
      },
    );
  }

  ///Ends Navigation and Closes the Navigation View
  Future<bool?> finishNavigation() async {
    var success = await _methodChannel.invokeMethod('finishNavigation', null);
    return success;
  }

  Future<bool?> reCenterCamera() async {
    var success = await _methodChannel.invokeMethod('reCenter', null);
    return success;
  }

  Future<bool?> moveToOverview() async {
    var success = await _methodChannel.invokeMethod('toOverview', null);
    return success;
  }

  /// Generic Handler for Messages sent from the Platform
  Future<dynamic> _handleMethod(MethodCall call) async {
    switch (call.method) {
      case 'sendFromNative':
        String? text = call.arguments as String?;
        return new Future.value("Text from native: $text");
    }
  }

  void _onProgressData(RouteEvent event) {
    if (_routeEventNotifier != null) _routeEventNotifier!(event);

    if (event.eventType == MapBoxEvent.navigation_finished)
      _routeEventSubscription.cancel();

    print("ONPROGRESS DATA ${event.data}");
  }

  Stream<RouteEvent>? get _streamRouteEvent {
    if (_onRouteEvent == null) {
      _onRouteEvent = _eventChannel
          .receiveBroadcastStream()
          .map((dynamic event) => _parseRouteEvent(event));
    }
    return _onRouteEvent;
  }

  RouteEvent _parseRouteEvent(String jsonString) {
    RouteEvent event;
    var map = json.decode(jsonString);
    var progressEvent = RouteProgressEvent.fromJson(map);
    if (progressEvent.isProgressEvent!) {
      event = RouteEvent(
          eventType: MapBoxEvent.progress_change, data: progressEvent);
    } else
      event = RouteEvent.fromJson(map);
    //print("MAPBOX EVENT: ${event.data}");
    return event;
  }
}
