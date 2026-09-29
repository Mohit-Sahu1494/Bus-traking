import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:student_app/providers/live_provider.dart';
import 'package:student_app/services/api_client.dart';
import 'package:student_app/services/device_location.dart';
import 'package:student_app/services/socket_service.dart';

class MockApiClient extends ApiClient {
  String? lastGetPath;
  String? lastSendMethod;
  String? lastSendPath;

  @override
  Future<dynamic> get(String path) async {
    lastGetPath = path;
    if (path == '/api/student/live') {
      return {
        'busStatus': 'ACTIVE',
        'busNumber': 'BUS-04',
        'trip': {
          'busNumber': 'BUS-04',
          'location': {'latitude': 23.8388, 'longitude': 78.7745},
          'currentSequence': 1,
        },
        'waiting': [],
        'isWaiting': false,
      };
    }
    return {};
  }

  @override
  Future<dynamic> send(String method, String path, {Map<String, dynamic>? body, bool auth = true}) async {
    lastSendMethod = method;
    lastSendPath = path;
    if (path == '/api/student/waiting') {
      return {
        'stops': [
          {'stop': 'Library', 'count': 1},
        ],
      };
    }
    return {};
  }
}

class MockSocketService extends SocketService {
  final Map<String, SocketHandler> handlers = {};

  @override
  void on(String event, SocketHandler handler) {
    handlers[event] = handler;
  }

  void trigger(String event, dynamic payload) {
    if (handlers.containsKey(event)) {
      handlers[event]!(payload);
    }
  }

  @override
  Future<void> connect(String token) async {
    connected = true;
  }

  @override
  Future<void> disconnect() async {
    connected = false;
  }
}

class MockLocationService extends DeviceLocationService {
  @override
  Future<bool> ensurePermission() async => true;

  @override
  Future<Position?> current() async => Position(
        latitude: 23.8350,
        longitude: 78.7710,
        timestamp: DateTime.now(),
        accuracy: 5.0,
        altitude: 0.0,
        altitudeAccuracy: 0.0,
        heading: 0.0,
        headingAccuracy: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
      );

  @override
  Stream<Position> stream() => const Stream<Position>.empty();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Student App - LiveProvider State and Bus Visibility Tests', () {
    late MockApiClient mockApi;
    late MockSocketService mockSocket;
    late MockLocationService mockLocation;
    late LiveProvider liveProvider;

    setUp(() async {
      mockApi = MockApiClient();
      mockSocket = MockSocketService();
      mockLocation = MockLocationService();
      liveProvider = LiveProvider(mockApi, mockSocket, mockLocation);
      await liveProvider.start('dummy-token');
    });

    test('Initializes with default route stops and INACTIVE bus before start', () {
      final unstarted = LiveProvider(mockApi, mockSocket, mockLocation);
      expect(unstarted.busStatus, 'INACTIVE');
      expect(unstarted.busLatLng, isNull);
      expect(unstarted.routeStops, isNotEmpty);
    });

    test('Refresh acquires live trip data and updates bus position', () async {
      await liveProvider.refresh();

      expect(mockApi.lastGetPath, '/api/student/live');
      expect(liveProvider.busStatus, 'ACTIVE');
      expect(liveProvider.busNumber, 'BUS-04');
      expect(liveProvider.busLatLng, isNotNull);
      expect(liveProvider.busLatLng!.latitude, 23.8388);
      expect(liveProvider.busLatLng!.longitude, 78.7745);
      expect(liveProvider.isRefreshing, isFalse);
    });

    test('Preserves bus coordinates when status transitions to OFFLINE', () async {
      await liveProvider.refresh();
      expect(liveProvider.busLatLng, isNotNull);

      // Now trigger socket event that bus is OFFLINE (heartbeat missed)
      mockSocket.trigger('bus_status_updated', {
        'busStatus': 'OFFLINE',
        'busNumber': 'BUS-04',
      });

      // Status is OFFLINE, but the marker coordinates are preserved!
      expect(liveProvider.busStatus, 'OFFLINE');
      expect(liveProvider.busLatLng, isNotNull);
      expect(liveProvider.busLatLng!.latitude, 23.8388);
    });

    test('Automatically recovers from OFFLINE to ACTIVE when new GPS coords arrive', () async {
      await liveProvider.refresh();
      mockSocket.trigger('bus_status_updated', {
        'busStatus': 'OFFLINE',
        'busNumber': 'BUS-04',
      });
      expect(liveProvider.busStatus, 'OFFLINE');

      // GPS update arrives from driver
      mockSocket.trigger('driver_location_updated', {
        'latitude': 23.8400,
        'longitude': 78.7760,
      });

      expect(liveProvider.busStatus, 'ACTIVE');
      expect(liveProvider.busLatLng!.latitude, 23.8400);
      expect(liveProvider.busLatLng!.longitude, 78.7760);
    });

    test('Clears bus coordinates ONLY when trip explicitly ENDS / becomes INACTIVE', () async {
      await liveProvider.refresh();
      expect(liveProvider.busLatLng, isNotNull);

      mockSocket.trigger('driver_trip_ended', {});

      expect(liveProvider.busStatus, 'INACTIVE');
      expect(liveProvider.busLatLng, isNull);
      expect(liveProvider.currentStop, isNull);
    });

    test('imWaiting and cancelWaiting toggle isTogglingWaiting correctly', () async {
      expect(liveProvider.isTogglingWaiting, isFalse);
      expect(liveProvider.isWaiting, isFalse);

      final waitFuture = liveProvider.imWaiting();
      // Operation completes
      await waitFuture;

      expect(mockApi.lastSendMethod, 'POST');
      expect(mockApi.lastSendPath, '/api/student/waiting');
      expect(liveProvider.isWaiting, isTrue);
      expect(liveProvider.isTogglingWaiting, isFalse);

      // Cancel waiting
      final cancelFuture = liveProvider.cancelWaiting();
      await cancelFuture;

      expect(mockApi.lastSendMethod, 'DELETE');
      expect(mockApi.lastSendPath, '/api/student/waiting');
      expect(liveProvider.isWaiting, isFalse);
      expect(liveProvider.isTogglingWaiting, isFalse);
    });
  });
}
