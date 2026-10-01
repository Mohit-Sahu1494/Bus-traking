import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../core/config.dart';
import '../core/errors.dart';
import '../services/api_client.dart';
import '../services/device_location.dart';
import '../services/socket_service.dart';

enum GpsStatusResult {
  ready,
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
}

class TripProvider extends ChangeNotifier {
  TripProvider(this._api, this._socket, this._location);

  final ApiClient _api;
  final SocketService _socket;
  final DeviceLocationService _location;

  String busNumber = '';
  String? busId;
  String tripStatus = 'NOT_STARTED';
  String busStatus = 'INACTIVE';
  bool gpsOn = false;
  bool socketConnected = false;
  String? gpsError;
  int tripsToday = 0;
  Map<String, dynamic>? live;
  List<Map<String, dynamic>> history = [];
  List<Map<String, dynamic>> availableBuses = [];
  bool loadingBuses = false;
  bool isStartingTrip = false;

  Position? currentPosition;
  String currentAreaDescription = 'GPS LIVE';

  StreamSubscription<Position>? _gpsSub;
  Timer? _heartbeatTimer;
  DateTime? _lastEmit;
  Position? _lastEmittedPosition;
  final List<Map<String, dynamic>> _locationBuffer = [];

  bool get isActive => tripStatus == 'ACTIVE';
  bool get isPaused => tripStatus == 'PAUSED';

  LatLng? get currentLatLng =>
      currentPosition != null ? LatLng(currentPosition!.latitude, currentPosition!.longitude) : null;

  Future<void> startSession(String token) async {
    _bind();
    await _socket.connect(token);
    await checkGpsStatus();
    await Future.wait([
      refresh(),
      loadHistory(),
      fetchAvailableBuses(),
    ]);
  }

  Future<GpsStatusResult> checkGpsStatus() async {
    final enabled = await _location.isLocationServiceEnabled();
    if (!enabled) {
      gpsOn = false;
      gpsError = 'Location (GPS) is turned off.';
      notifyListeners();
      return GpsStatusResult.serviceDisabled;
    }

    final perm = await _location.checkPermission();
    if (perm == LocationPermission.denied) {
      gpsOn = false;
      gpsError = 'Location permission is required.';
      notifyListeners();
      return GpsStatusResult.permissionDenied;
    }
    if (perm == LocationPermission.deniedForever) {
      gpsOn = false;
      gpsError = 'Location permission permanently denied.';
      notifyListeners();
      return GpsStatusResult.permissionDeniedForever;
    }

    gpsOn = true;
    gpsError = null;
    notifyListeners();
    return GpsStatusResult.ready;
  }

  Future<void> onAppResumed() async {
    debugPrint('[TripProvider] onAppResumed: checking GPS & refreshing state');
    await checkGpsStatus();
    if (isActive || isPaused) {
      await _ensureGps();
    }
    await refresh();
  }

  Future<void> refresh() async {
    try {
      final data = Map<String, dynamic>.from(await _api.get('/api/driver/live') as Map);
      busNumber = data['bus']?['busNumber']?.toString() ?? busNumber;
      busId = data['bus']?['id']?.toString() ?? busId;
      busStatus = data['bus']?['status']?.toString() ?? busStatus;
      tripsToday = (data['tripsToday'] as num?)?.toInt() ?? 0;
      live = data['live'] is Map ? Map<String, dynamic>.from(data['live'] as Map) : null;
      tripStatus = live?['status']?.toString() ?? 'NOT_STARTED';

      if (isActive || isPaused) {
        await _ensureGps();
      } else {
        await _stopGps();
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> loadHistory() async {
    try {
      final data = await _api.get('/api/driver/trips');
      if (data is List) {
        history = data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> fetchAvailableBuses() async {
    loadingBuses = true;
    notifyListeners();
    try {
      final res = await _api.get('/api/driver/buses');
      if (res is List) {
        availableBuses = res.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return availableBuses;
    } catch (_) {
      return availableBuses;
    } finally {
      loadingBuses = false;
      notifyListeners();
    }
  }

  Future<void> assignBus(String selectedBusId) async {
    final res = await _api.send('POST', '/api/driver/bus/assign', body: {'busId': selectedBusId});
    if (res is Map && res['busNumber'] != null) {
      busNumber = res['busNumber'].toString();
      busId = res['busId']?.toString() ?? selectedBusId;
    }
    await refresh();
    await fetchAvailableBuses();
  }

  Future<void> startTrip() async {
    if (isStartingTrip) return;
    isStartingTrip = true;
    notifyListeners();

    try {
      debugPrint('[TripProvider] START_TRIP_CLICKED at ${DateTime.now().toIso8601String()}');

      // 1. Immediately check whether location services/GPS are enabled
      final serviceEnabled = await _location.isLocationServiceEnabled();
      debugPrint('[TripProvider] LOCATION_SERVICE_STATUS: $serviceEnabled');
      if (!serviceEnabled) {
        gpsOn = false;
        gpsError = 'Device GPS is turned off. Please enable Location in settings.';
        notifyListeners();
        throw const GpsDisabledException(
          'Location (GPS) is turned off. Please enable Location in your device settings to start tracking.',
        );
      }

      // 2. Check and request permission
      var perm = await _location.checkPermission();
      debugPrint('[TripProvider] LOCATION_PERMISSION_STATUS (check): $perm');
      if (perm == LocationPermission.denied) {
        perm = await _location.requestPermission();
        debugPrint('[TripProvider] LOCATION_PERMISSION_STATUS (requested): $perm');
      }

      if (perm == LocationPermission.denied) {
        gpsOn = false;
        gpsError = 'Location permission is denied.';
        notifyListeners();
        throw const LocationPermissionException('Location permission is required to start the trip.');
      }

      if (perm == LocationPermission.deniedForever) {
        gpsOn = false;
        gpsError = 'Location permission permanently denied.';
        notifyListeners();
        throw const LocationPermissionException(
          'Location permission is permanently denied. Please enable location access in App Settings.',
          permanentlyDenied: true,
        );
      }

      gpsOn = true;
      gpsError = null;

      // 3. Acquire valid current location with timeout before starting on backend
      debugPrint('[TripProvider] LOCATION_ACQUISITION_STARTED at ${DateTime.now().toIso8601String()}');
      final pos = await _location.current(timeout: const Duration(seconds: 7));
      if (pos == null) {
        debugPrint('[TripProvider] LOCATION_ACQUISITION_FAILED: Timeout or unable to get position');
        throw const LocationAcquisitionException(
          'Unable to get your current location. Please make sure GPS is enabled and you are in an area with a location signal.',
        );
      }

      debugPrint('[TripProvider] LOCATION_ACQUIRED: (${pos.latitude}, ${pos.longitude}) acc=${pos.accuracy}m');
      currentPosition = pos;
      _updateAreaDescription(pos);

      // 4. Send Start Trip request with initial coordinates
      debugPrint('[TripProvider] START_TRIP_API_STARTED at ${DateTime.now().toIso8601String()}');
      final body = {
        'latitude': pos.latitude,
        'longitude': pos.longitude,
        'speed': pos.speed,
        'heading': pos.heading,
        'accuracy': pos.accuracy,
      };

      try {
        final res = await _api.send('POST', '/api/driver/trip/start', body: body);
        debugPrint('[TripProvider] START_TRIP_API_RESPONSE received successfully');
        live = Map<String, dynamic>.from(res as Map);
        tripStatus = 'ACTIVE';
        busStatus = 'ACTIVE';
        gpsError = null;
      } on ApiException catch (e) {
        if (e.message.toLowerCase().contains('already have an active trip') ||
            e.message.contains('TRIP_ALREADY_ACTIVE')) {
          debugPrint('[TripProvider] Trip already active on server, syncing state...');
          await refresh();
          if (tripStatus != 'ACTIVE') {
            tripStatus = 'ACTIVE';
            busStatus = 'ACTIVE';
          }
          gpsError = null;
        } else {
          rethrow;
        }
      }

      // 5. Start streaming GPS
      await _ensureGps();
      notifyListeners();
    } catch (e) {
      debugPrint('[TripProvider] START_TRIP_API_FAILED: $e');
      rethrow;
    } finally {
      isStartingTrip = false;
      notifyListeners();
    }
  }

  Future<void> pauseTrip(String reason) async {
    live = Map<String, dynamic>.from(await _api.send('POST', '/api/driver/trip/pause', body: {'reason': reason}) as Map);
    tripStatus = 'PAUSED';
    busStatus = 'PAUSED';
    notifyListeners();
  }

  Future<void> resumeTrip() async {
    live = Map<String, dynamic>.from(await _api.send('POST', '/api/driver/trip/resume') as Map);
    tripStatus = 'ACTIVE';
    busStatus = 'ACTIVE';
    await _ensureGps();
    notifyListeners();
  }

  Future<void> endTrip() async {
    await _api.send('POST', '/api/driver/trip/end');
    tripStatus = 'COMPLETED';
    busStatus = 'INACTIVE';
    live = null;
    await _stopGps();
    await loadHistory();
    await refresh();
  }

  Future<void> skipStop() async {
    final nextId = live?['nextStop']?['id'];
    live = Map<String, dynamic>.from(await _api.send(
      'POST',
      '/api/driver/stop/skip',
      body: nextId != null ? {'routeStopId': nextId} : null,
    ) as Map);
    notifyListeners();
  }

  Future<void> reachStop() async {
    final nextId = live?['nextStop']?['id'];
    live = Map<String, dynamic>.from(await _api.send(
      'POST',
      '/api/driver/stop/reach',
      body: nextId != null ? {'routeStopId': nextId} : null,
    ) as Map);
    notifyListeners();
  }

  Future<void> stop() async {
    await _stopGps();
    await _socket.disconnect();
  }

  void _bind() {
    const events = [
      'connection_status',
      'driver_trip_started',
      'driver_location_updated',
      'stop_reached',
      'stop_skipped',
      'next_stop_updated',
      'driver_trip_paused',
      'driver_trip_resumed',
      'driver_trip_ended',
      'bus_status_updated',
      'student_waiting_updated',
    ];
    for (final e in events) {
      _socket.on(e, (raw) async {
        if (e == 'connection_status') {
          socketConnected = raw is Map && raw['connected'] == true;
          if (socketConnected) {
            if (currentPosition != null) {
              _socket.emit('driver:location', {
                'latitude': currentPosition!.latitude,
                'longitude': currentPosition!.longitude,
                'speed': currentPosition!.speed,
                'heading': currentPosition!.heading,
                'accuracy': currentPosition!.accuracy,
                'timestamp': DateTime.now().toIso8601String(),
              });
            }
            _locationBuffer.clear();
            await refresh();
          }
        } else if (e == 'student_waiting_updated' && raw is Map) {
          live ??= {};
          live!['waiting'] = raw['stops'];
        } else if (e == 'driver_location_updated' && raw is Map) {
          if (raw['tripId'] == live?['tripId']) {
            live ??= {};
            if (raw['currentStop'] != null) live!['currentStop'] = raw['currentStop'];
            if (raw['nextStop'] != null) live!['nextStop'] = raw['nextStop'];
            if (raw['etaLabel'] != null) live!['etaLabel'] = raw['etaLabel'];
            if (raw['currentSequence'] != null) live!['currentSequence'] = raw['currentSequence'];
          }
        } else if (e == 'next_stop_updated' && raw is Map) {
          live ??= {};
          if (raw['nextStop'] != null) live!['nextStop'] = raw['nextStop'];
          if (raw['currentStop'] != null) live!['currentStop'] = raw['currentStop'];
          if (raw['etaLabel'] != null) live!['etaLabel'] = raw['etaLabel'];
          if (raw['isFinalStopReached'] != null) {
            live!['isFinalStopReached'] = raw['isFinalStopReached'];
          }
        } else {
          await refresh();
        }
        notifyListeners();
      });
    }
  }

  Future<void> _ensureGps() async {
    final serviceEnabled = await _location.isLocationServiceEnabled();
    if (!serviceEnabled) {
      gpsOn = false;
      gpsError = 'Location (GPS) is turned off.';
      await _stopGps();
      notifyListeners();
      return;
    }

    final ok = await _location.ensurePermission();
    if (!ok) {
      gpsOn = false;
      gpsError = 'Location permission is denied or GPS is turned off.';
      await _stopGps();
      notifyListeners();
      return;
    }
    gpsError = null;
    gpsOn = true;

    // Start streaming position with foreground notification
    final assignedBus = busNumber.isNotEmpty ? busNumber : 'BUS-04';
    if (_gpsSub == null) {
      _gpsSub = _location.stream(busNumber: assignedBus).listen(
        _onPosition,
        onError: (err) {
          debugPrint('[TripProvider] GPS Signal lost or stream error: $err');
          _gpsSub?.cancel();
          _gpsSub = null;
          gpsError = 'GPS Signal Lost: $err';
          gpsOn = false;
          notifyListeners();
        },
      );
    }

    // Initial position sample
    final pos = await _location.current();
    if (pos != null) _onPosition(pos);

    _startHeartbeatTimer();
  }

  void _onPosition(Position pos) {
    currentPosition = pos;
    gpsOn = true;
    gpsError = null;
    _updateAreaDescription(pos);

    final now = DateTime.now();
    final payload = {
      'latitude': pos.latitude,
      'longitude': pos.longitude,
      'speed': pos.speed,
      'heading': pos.heading,
      'accuracy': pos.accuracy,
      'timestamp': now.toIso8601String(),
    };

    // Buffer location if socket temporarily disconnected
    if (!socketConnected) {
      _locationBuffer.add(payload);
      if (_locationBuffer.length > 20) {
        _locationBuffer.removeAt(0);
      }
      notifyListeners();
      return;
    }

    // Optimization: throttle frequency to at least 1.5 seconds
    if (_lastEmit != null && now.difference(_lastEmit!).inMilliseconds < 1500) {
      notifyListeners();
      return;
    }

    // Optimization: avoid duplicate transmissions if device hasn't moved
    if (_lastEmittedPosition != null) {
      final moved = Geolocator.distanceBetween(
        _lastEmittedPosition!.latitude,
        _lastEmittedPosition!.longitude,
        pos.latitude,
        pos.longitude,
      );
      if (moved < 3.0 && pos.speed < 0.5 && now.difference(_lastEmit!).inSeconds < 8) {
        notifyListeners();
        return;
      }
    }

    _lastEmit = now;
    _lastEmittedPosition = pos;

    // Transmit location to backend
    _socket.emit('driver:location', payload);

    notifyListeners();
  }

  void _updateAreaDescription(Position pos) {
    const stops = [
      {'name': 'Computer Science Department', 'lat': 23.824232, 'lng': 78.782155},
      {'name': 'Criminology Department', 'lat': 23.823290, 'lng': 78.783108},
      {'name': 'Center Point', 'lat': 23.826769, 'lng': 78.772078},
      {'name': 'Boys Hostel', 'lat': 23.822333, 'lng': 78.770270},
      {'name': 'Girls Hostel', 'lat': 23.831797, 'lng': 78.782346},
    ];

    double minDistance = double.infinity;
    String closestName = '';

    for (final s in stops) {
      final d = Geolocator.distanceBetween(
        pos.latitude,
        pos.longitude,
        s['lat'] as double,
        s['lng'] as double,
      );
      if (d < minDistance) {
        minDistance = d;
        closestName = s['name'] as String;
      }
    }

    if (minDistance <= 120) {
      currentAreaDescription = 'At $closestName';
    } else if (minDistance <= 350) {
      currentAreaDescription = 'Near $closestName area';
    } else {
      final speedKmh = (pos.speed * 3.6).round();
      currentAreaDescription = speedKmh > 3 ? 'In Transit ($speedKmh km/h)' : 'Campus Main Route';
    }
  }

  void _startHeartbeatTimer() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if ((isActive || isPaused) && socketConnected && currentPosition != null) {
        final now = DateTime.now();
        if (_lastEmit == null || now.difference(_lastEmit!).inSeconds >= 6) {
          _socket.emit('driver:heartbeat', {
            'latitude': currentPosition!.latitude,
            'longitude': currentPosition!.longitude,
            'speed': currentPosition!.speed,
            'heading': currentPosition!.heading,
            'accuracy': currentPosition!.accuracy,
            'timestamp': now.toIso8601String(),
          });
          _lastEmit = now;
        }
      }
    });
  }

  Future<void> _stopGps() async {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    await _gpsSub?.cancel();
    _gpsSub = null;
    gpsOn = false;
  }

  String? get currentStopName => live?['currentStop']?['stop']?['name']?.toString();
  String? get nextStopName => live?['nextStop']?['stop']?['name']?.toString();
  String get etaLabel => live?['etaLabel']?.toString() ?? 'Calculating...';

  bool get isFinalStopReached {
    if (live?['isFinalStopReached'] == true) return true;
    final lastSeq = routeStops.isNotEmpty
        ? (routeStops.last['sequence'] as num?)?.toInt() ?? 7
        : 7;
    return currentSequence >= lastSeq && completed.contains(lastSeq);
  }

  int waitingFor(String? name) {
    if (name == null) return 0;
    final list = live?['waiting'] as List? ?? [];
    for (final item in list) {
      if (item is Map && item['name'] == name) {
        return (item['studentsWaiting'] as num?)?.toInt() ?? 0;
      }
    }
    return 0;
  }

  int selectedFor(String? name) {
    if (name == null) return 0;
    final list = live?['waiting'] as List? ?? [];
    for (final item in list) {
      if (item is Map && item['name'] == name) {
        return (item['studentsSelected'] as num?)?.toInt() ?? 0;
      }
    }
    return 0;
  }

  String? get pauseReason => live?['pauseReason']?.toString();

  List<Map<String, dynamic>> get routeStops {
    final list = live?['routeStops'] as List? ?? [];
    if (list.isNotEmpty) {
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return AppConfig.defaultRouteStops;
  }

  Set<int> get skipped => {...((live?['skippedSequences'] as List?) ?? []).map((e) => (e as num).toInt())};
  Set<int> get completed => {...((live?['completedSequences'] as List?) ?? []).map((e) => (e as num).toInt())};
  int get currentSequence => (live?['currentSequence'] as num?)?.toInt() ?? 0;
}
