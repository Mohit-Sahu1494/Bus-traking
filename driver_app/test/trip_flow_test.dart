import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:driver_app/core/errors.dart';
import 'package:driver_app/providers/trip_provider.dart';
import 'package:driver_app/services/api_client.dart';
import 'package:driver_app/services/device_location.dart';
import 'package:driver_app/services/socket_service.dart';

class MockApiClient extends ApiClient {
  dynamic lastPayload;
  String? lastPath;
  String? lastMethod;

  @override
  Future<dynamic> send(String method, String path, {Map<String, dynamic>? body, bool auth = true}) async {
    lastMethod = method;
    lastPath = path;
    lastPayload = body;
    if (path == '/api/driver/trip/start') {
      return {
        'tripId': 'trip-123',
        'route': 'Main Loop',
        'status': 'ACTIVE',
      };
    }
    return {};
  }
}

class MockSocketService extends SocketService {
  final Map<String, dynamic> emittedEvents = {};

  @override
  void emit(String event, dynamic payload) {
    emittedEvents[event] = payload;
  }

  @override
  void on(String event, SocketHandler handler) {}
}

class MockLocationService extends DeviceLocationService {
  bool serviceEnabled = true;
  LocationPermission permission = LocationPermission.always;
  Position? currentPosition;
  bool shouldThrowAcquisition = false;

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async => permission;

  @override
  Future<Position?> current({Duration timeout = const Duration(seconds: 7)}) async {
    if (shouldThrowAcquisition) return null;
    return currentPosition ??
        Position(
          longitude: 78.7745,
          latitude: 23.8388,
          timestamp: DateTime.now(),
          accuracy: 5.0,
          altitude: 0.0,
          altitudeAccuracy: 0.0,
          heading: 0.0,
          headingAccuracy: 0.0,
          speed: 0.0,
          speedAccuracy: 0.0,
        );
  }

  @override
  Stream<Position> stream({String busNumber = 'Bus'}) {
    return const Stream<Position>.empty();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Driver App - Start Trip & GPS Validation Tests', () {
    late MockApiClient mockApi;
    late MockSocketService mockSocket;
    late MockLocationService mockLocation;
    late TripProvider tripProvider;

    setUp(() {
      mockApi = MockApiClient();
      mockSocket = MockSocketService();
      mockLocation = MockLocationService();
      tripProvider = TripProvider(mockApi, mockSocket, mockLocation);
    });

    test('Throws GpsDisabledException when device GPS is turned OFF without calling API', () async {
      mockLocation.serviceEnabled = false;

      try {
        await tripProvider.startTrip();
        fail('Should have thrown GpsDisabledException');
      } catch (e) {
        expect(e, isA<GpsDisabledException>());
      }

      // Verify no API request was sent
      expect(mockApi.lastPath, isNull);
      expect(tripProvider.isStartingTrip, isFalse);
      expect(tripProvider.isActive, isFalse);
    });

    test('Throws LocationPermissionException when location permission is denied', () async {
      mockLocation.serviceEnabled = true;
      mockLocation.permission = LocationPermission.denied;

      try {
        await tripProvider.startTrip();
        fail('Should have thrown LocationPermissionException');
      } catch (e) {
        expect(e, isA<LocationPermissionException>());
      }

      expect(mockApi.lastPath, isNull);
      expect(tripProvider.isStartingTrip, isFalse);
      expect(tripProvider.isActive, isFalse);
    });

    test('Throws LocationAcquisitionException when GPS signal cannot be acquired', () async {
      mockLocation.serviceEnabled = true;
      mockLocation.permission = LocationPermission.always;
      mockLocation.shouldThrowAcquisition = true;

      try {
        await tripProvider.startTrip();
        fail('Should have thrown LocationAcquisitionException');
      } catch (e) {
        expect(e, isA<LocationAcquisitionException>());
      }

      expect(mockApi.lastPath, isNull);
      expect(tripProvider.isStartingTrip, isFalse);
      expect(tripProvider.isActive, isFalse);
    });

    test('Successfully acquires location and sends initial coords in startTrip API', () async {
      mockLocation.serviceEnabled = true;
      mockLocation.permission = LocationPermission.always;
      mockLocation.currentPosition = Position(
        latitude: 23.8388,
        longitude: 78.7745,
        timestamp: DateTime.now(),
        accuracy: 4.0,
        altitude: 0.0,
        altitudeAccuracy: 0.0,
        heading: 90.0,
        headingAccuracy: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
      );

      await tripProvider.startTrip();

      expect(mockApi.lastPath, '/api/driver/trip/start');
      expect(mockApi.lastPayload, isNotNull);
      expect(mockApi.lastPayload!['latitude'], 23.8388);
      expect(mockApi.lastPayload!['longitude'], 78.7745);
      expect(mockApi.lastPayload!['heading'], 90.0);
      expect(mockApi.lastPayload!['speed'], 0.0);

      // Loading state cleared and trip marked active
      expect(tripProvider.isStartingTrip, isFalse);
      expect(tripProvider.isActive, isTrue);
    });

    test('humanizeError translates all error categories gracefully without sensitive leaks', () {
      expect(
        humanizeError(const GpsDisabledException()),
        'Device GPS is turned off. Please enable Location in settings.',
      );
      expect(
        humanizeError(const LocationPermissionException('Permission denied')),
        'Permission denied',
      );
      expect(
        humanizeError(const LocationAcquisitionException()),
        contains('Unable to get your current location'),
      );
      expect(
        humanizeError(Exception('TimeoutException after 0:00:10.000000')),
        'The server is taking too long to respond.',
      );
      expect(
        humanizeError(Exception('SocketException: Failed host lookup')),
        'Internet unavailable. Check your connection.',
      );
    });
  });
}
