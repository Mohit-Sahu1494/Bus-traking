import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../core/config.dart';
import '../models/models.dart';
import '../services/api_client.dart';
import '../services/device_location.dart';
import '../services/socket_service.dart';

class LiveProvider extends ChangeNotifier {
  LiveProvider(this._api, this._socket, this._location);

  final ApiClient _api;
  final SocketService _socket;
  final DeviceLocationService _location;

  String busStatus = 'INACTIVE';
  String? busNumber;
  LatLng? busLatLng;
  LatLng? studentLatLng;
  RouteStopInfo? currentStop;
  RouteStopInfo? nextStop;
  String etaLabel = 'Calculating...';
  double? distanceToNextStopM;
  List<RouteStopInfo> routeStops = List<RouteStopInfo>.from(AppConfig.defaultRouteStops);
  List<WaitingCount> waiting = [];
  List<int> skippedSequences = [];
  List<int> completedSequences = [];
  int? currentSequence;
  bool isWaiting = false;
  bool socketConnected = false;
  String? skipBanner;
  String? pauseMessage;
  String? gpsError;
  List<Map<String, dynamic>> notifications = [];

  int get unreadNotificationsCount =>
      notifications.where((n) => n['readAt'] == null).length;

  Future<void> start(String token) async {
    _bindSockets();
    await _socket.connect(token);
    await Future.wait([
      refresh(),
      loadNotifications(),
      _startStudentGps(),
    ]);
  }

  Future<void> refresh() async {
    try {
      final data = Map<String, dynamic>.from(await _api.get('/api/student/live') as Map);
      _applyLive(data);
      waiting = ((data['waiting'] as List?) ?? [])
          .map((e) => WaitingCount.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      isWaiting = data['isWaiting'] == true;

      if (routeStops.isEmpty) {
        final routes = await _api.get('/api/routes');
        if (routes is List && routes.isNotEmpty) {
          final id = (routes.first as Map)['_id'] ?? (routes.first as Map)['id'];
          if (id != null) {
            final detail = await _api.get('/api/routes/$id');
            final stops = (detail as Map)['stops'] as List? ?? [];
            routeStops = stops.map((e) => RouteStopInfo.fromJson(Map<String, dynamic>.from(e as Map))).toList();
          }
        }
      }
      notifyListeners();
    } catch (_) {
      notifyListeners();
    }
  }

  Future<List<StopInfo>> loadStops() async {
    try {
      final data = await _api.get('/api/stops');
      final list = (data as List).map((e) => StopInfo.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      if (list.isNotEmpty) return list;
    } catch (_) {}
    // Fallback to distinct verified campus stops
    final seen = <String>{};
    final list = <StopInfo>[];
    for (final rs in AppConfig.defaultRouteStops) {
      if (seen.add(rs.stop.name)) {
        list.add(rs.stop);
      }
    }
    return list;
  }

  Future<void> imWaiting() async {
    final data = await _api.send('POST', '/api/student/waiting');
    waiting = ((data['stops'] as List?) ?? [])
        .map((e) => WaitingCount.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    isWaiting = true;
    notifyListeners();
  }

  Future<void> cancelWaiting() async {
    final data = await _api.send('DELETE', '/api/student/waiting');
    waiting = ((data['stops'] as List?) ?? [])
        .map((e) => WaitingCount.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    isWaiting = false;
    notifyListeners();
  }

  Future<void> loadNotifications() async {
    try {
      final data = await _api.get('/api/notifications');
      if (data is List) {
        notifications = data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> markNotificationRead(String id) async {
    try {
      await _api.send('PATCH', '/api/notifications/$id/read');
      final idx = notifications.indexWhere((n) => (n['_id'] ?? n['id'])?.toString() == id);
      if (idx != -1) {
        notifications[idx]['readAt'] = DateTime.now().toIso8601String();
        notifyListeners();
      }
    } catch (_) {}
  }

  void dismissSkipBanner() {
    skipBanner = null;
    notifyListeners();
  }

  void dismissPauseBanner() {
    pauseMessage = null;
    notifyListeners();
  }

  void stop() {
    _socket.disconnect();
  }

  void _bindSockets() {
    void apply(String event, dynamic raw) {
      final data = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
      switch (event) {
        case 'connection_status':
          socketConnected = data['connected'] == true;
          if (socketConnected) refresh();
          break;
        case 'driver_trip_started':
        case 'driver_trip_resumed':
        case 'bus_status_updated':
          busStatus = (data['busStatus'] ?? data['status'] ?? busStatus).toString();
          busNumber = data['busNumber']?.toString() ?? busNumber;
          pauseMessage = null;
          _applyTripFields(data);
          break;
        case 'driver_trip_paused':
          busStatus = 'PAUSED';
          pauseMessage = 'Bus is temporarily paused by the driver.';
          break;
        case 'driver_trip_ended':
          busStatus = 'INACTIVE';
          busLatLng = null;
          currentStop = null;
          nextStop = null;
          pauseMessage = null;
          isWaiting = false;
          skippedSequences = [];
          completedSequences = [];
          currentSequence = null;
          distanceToNextStopM = null;
          etaLabel = 'Calculating...';
          break;
        case 'driver_location_updated':
          final lat = (data['latitude'] as num?)?.toDouble();
          final lng = (data['longitude'] as num?)?.toDouble();
          if (lat != null && lng != null) busLatLng = LatLng(lat, lng);
          if (data['currentSequence'] != null) {
            currentSequence = (data['currentSequence'] as num).toInt();
          }
          if (data['nextStop'] is Map) {
            nextStop = RouteStopInfo.fromJson(Map<String, dynamic>.from(data['nextStop'] as Map));
          }
          if (data['currentStop'] is Map) {
            currentStop = RouteStopInfo.fromJson(Map<String, dynamic>.from(data['currentStop'] as Map));
          }
          _resolveSequenceStops();
          _updateLiveEtaAndDistance(data['etaLabel']?.toString());
          break;
        case 'next_stop_updated':
        case 'route_updated':
          _applyTripFields(data);
          break;
        case 'stop_reached':
          _applyTripFields(data);
          if (data['reachedStop'] is Map && data['reachedStop']['sequence'] != null) {
            final s = (data['reachedStop']['sequence'] as num).toInt();
            currentSequence = s;
            if (!completedSequences.contains(s)) completedSequences.add(s);
          }
          _resolveSequenceStops();
          _updateLiveEtaAndDistance();
          break;
        case 'stop_skipped':
          skipBanner = data['skippedStop']?['name']?.toString() ?? 'A stop';
          _applyTripFields(data);
          if (data['skippedStop'] is Map && data['skippedStop']['sequence'] != null) {
            final s = (data['skippedStop']['sequence'] as num).toInt();
            if (!skippedSequences.contains(s)) skippedSequences.add(s);
          }
          _resolveSequenceStops();
          _updateLiveEtaAndDistance();
          break;
        case 'student_waiting_updated':
          waiting = ((data['stops'] as List?) ?? [])
              .map((e) => WaitingCount.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
          break;
        case 'notification_created':
          loadNotifications();
          break;
      }
      notifyListeners();
    }

    const events = [
      'connection_status',
      'driver_trip_started',
      'driver_location_updated',
      'driver_trip_paused',
      'driver_trip_resumed',
      'driver_trip_ended',
      'stop_reached',
      'stop_skipped',
      'next_stop_updated',
      'student_waiting_updated',
      'bus_status_updated',
      'route_updated',
      'notification_created',
    ];
    for (final e in events) {
      _socket.on(e, (data) => apply(e, data));
    }
  }

  void _applyLive(Map<String, dynamic> data) {
    busStatus = (data['busStatus'] ?? 'INACTIVE').toString();
    final trip = data['trip'];
    if (trip is Map) {
      _applyTripFields(Map<String, dynamic>.from(trip));
    } else {
      busLatLng = null;
      currentStop = null;
      nextStop = null;
      skippedSequences = [];
      completedSequences = [];
      currentSequence = null;
      distanceToNextStopM = null;
      etaLabel = 'Calculating...';
    }
    if (routeStops.isEmpty) {
      routeStops = List<RouteStopInfo>.from(AppConfig.defaultRouteStops);
    }
  }

  void _applyTripFields(Map<String, dynamic> data) {
    busNumber = data['busNumber']?.toString() ?? busNumber;
    if (data['busStatus'] != null) busStatus = data['busStatus'].toString();
    if (data['etaLabel'] != null) etaLabel = data['etaLabel'].toString();
    if (data['currentStop'] is Map) {
      currentStop = RouteStopInfo.fromJson(Map<String, dynamic>.from(data['currentStop'] as Map));
    }
    if (data['nextStop'] is Map) {
      nextStop = RouteStopInfo.fromJson(Map<String, dynamic>.from(data['nextStop'] as Map));
    } else if (data.containsKey('nextStop') && data['nextStop'] == null) {
      nextStop = null;
    }
    if (data['routeStops'] is List && (data['routeStops'] as List).isNotEmpty) {
      routeStops = (data['routeStops'] as List)
          .map((e) => RouteStopInfo.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    if (data['skippedSequences'] is List) {
      skippedSequences = (data['skippedSequences'] as List).map((e) => (e as num).toInt()).toList();
    }
    if (data['completedSequences'] is List) {
      completedSequences = (data['completedSequences'] as List).map((e) => (e as num).toInt()).toList();
    }
    if (data['currentSequence'] != null) {
      currentSequence = (data['currentSequence'] as num).toInt();
    }
    final loc = data['location'];
    if (loc is Map) {
      final lat = (loc['latitude'] as num?)?.toDouble();
      final lng = (loc['longitude'] as num?)?.toDouble();
      if (lat != null && lng != null) busLatLng = LatLng(lat, lng);
    }

    _resolveSequenceStops();
    _updateLiveEtaAndDistance(data['etaLabel']?.toString());
  }

  /// Sequence-based nextStop and currentStop resolver:
  /// Handles Center Point occurring multiple times (sequences 1, 4, 7)
  /// without ambiguity, and advances past skipped sequences.
  void _resolveSequenceStops() {
    if (routeStops.isEmpty) return;
    final currSeq = currentSequence ?? 0;
    final skipped = skippedSequences.toSet();
    final ordered = List<RouteStopInfo>.from(routeStops)
      ..sort((a, b) => a.sequence.compareTo(b.sequence));

    // Next stop: lowest sequence > currentSequence that is not skipped
    RouteStopInfo? validNext;
    for (final rs in ordered) {
      if (rs.sequence > currSeq && !skipped.contains(rs.sequence)) {
        validNext = rs;
        break;
      }
    }
    nextStop = validNext;

    // Current stop: stop with sequence == currentSequence
    if (currSeq > 0) {
      for (final rs in ordered) {
        if (rs.sequence == currSeq) {
          currentStop = rs;
          break;
        }
      }
    } else {
      currentStop = null;
    }
  }

  /// Real-time distance and ETA update using real bus GPS location
  void _updateLiveEtaAndDistance([String? backendEta]) {
    if (busLatLng == null || nextStop == null) {
      distanceToNextStopM = null;
      if (backendEta != null && backendEta.isNotEmpty) {
        etaLabel = backendEta;
      }
      return;
    }
    final nextLatLng = LatLng(nextStop!.latitude, nextStop!.longitude);
    final distM = const Distance().as(LengthUnit.Meter, busLatLng!, nextLatLng);
    distanceToNextStopM = distM;

    if (distM <= 45) {
      etaLabel = 'Arriving now';
    } else if (distM <= 200) {
      etaLabel = '< 1 min (${distM.round()}m)';
    } else {
      final mins = (distM / 300).ceil();
      if (mins <= 1) {
        etaLabel = '1 min (${distM.round()}m)';
      } else {
        final kmStr = (distM / 1000).toStringAsFixed(1);
        etaLabel = '$mins mins ($kmStr km)';
      }
    }
  }

  Future<void> _startStudentGps() async {
    final ok = await _location.ensurePermission();
    if (!ok) {
      gpsError = 'Location permission denied or GPS is off.';
      notifyListeners();
      return;
    }
    gpsError = null;
    final pos = await _location.current();
    if (pos != null) studentLatLng = LatLng(pos.latitude, pos.longitude);
    notifyListeners();
    _location.stream().listen((Position p) {
      studentLatLng = LatLng(p.latitude, p.longitude);
      notifyListeners();
    });
  }

  int waitingAt(String? stopName) {
    if (stopName == null) return 0;
    for (final w in waiting) {
      if (w.name == stopName) return w.studentsWaiting;
    }
    return 0;
  }
}
