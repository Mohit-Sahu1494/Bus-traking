import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:driver_app/providers/auth_provider.dart';
import 'package:driver_app/providers/trip_provider.dart';
import 'package:driver_app/services/api_client.dart';
import 'package:driver_app/services/device_location.dart';
import 'package:driver_app/services/socket_service.dart';
import 'package:driver_app/screens/home_screen.dart';
import 'package:driver_app/screens/profile_screen.dart';

class FakeApiClient extends ApiClient {
  @override
  Future<dynamic> get(String path) async {
    if (path == '/api/driver/profile') {
      return {
        'name': 'Raj Kumar',
        'email': 'driver@dhsgu.ac.in',
        'phone': '9876543210',
        'busNumber': 'BUS-04',
        'totalTrips': 14,
        'completedTrips': 13,
        'skippedStops': 1,
      };
    }
    if (path == '/api/driver/buses') {
      return [
        {'id': 'b1', 'busNumber': 'BUS-01', 'isCurrent': false, 'inUse': false},
        {'id': 'b2', 'busNumber': 'BUS-02', 'isCurrent': false, 'inUse': true, 'reason': 'Currently in use'},
        {'id': 'b3', 'busNumber': 'BUS-03', 'isCurrent': false, 'inUse': false},
        {'id': 'b4', 'busNumber': 'BUS-04', 'isCurrent': true, 'inUse': false},
      ];
    }
    if (path == '/api/driver/live') {
      return {
        'bus': {'busNumber': 'BUS-04', 'status': 'INACTIVE'},
        'tripsToday': 2,
        'live': null,
      };
    }
    return {};
  }
}

class FakeLocationService extends DeviceLocationService {
  @override
  Future<bool> ensurePermission() async => true;
}

class FakeSocketService extends SocketService {
  @override
  void on(String event, SocketHandler handler) {}
  @override
  void emit(String event, dynamic payload) {}
}

void main() {
  const screenWidths = [320.0, 360.0, 375.0, 390.0, 412.0, 430.0];

  for (final width in screenWidths) {
    testWidgets('Driver HomeScreen renders without overflow at ${width}px', (tester) async {
      FlutterError.onError = (details) {
        FlutterError.presentError(details);
      };
      tester.view.physicalSize = Size(width * 2, 800 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final api = FakeApiClient();
      final auth = AuthProvider(api);
      auth.profile = DriverProfile(
        name: 'Raj Kumar',
        email: 'driver@dhsgu.ac.in',
        phone: '9876543210',
        busNumber: 'BUS-04',
        totalTrips: 14,
        completedTrips: 13,
        skippedStops: 1,
      );
      final socket = FakeSocketService();
      final loc = FakeLocationService();
      final trip = TripProvider(api, socket, loc);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: auth),
            ChangeNotifierProvider<TripProvider>.value(value: trip),
          ],
          child: const MaterialApp(
            home: HomeScreen(),
          ),
        ),
      );

      await tester.pump();
      final err = tester.takeException();
      if (err != null) {
        // ignore: avoid_print
        print('HomeScreen Exception at $width: $err');
      }
      expect(err, isNull);
    });

    testWidgets('Driver ProfileScreen renders without overflow at ${width}px', (tester) async {
      tester.view.physicalSize = Size(width * 2, 800 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final api = FakeApiClient();
      final auth = AuthProvider(api);
      auth.profile = DriverProfile(
        name: 'Raj Kumar',
        email: 'driver@dhsgu.ac.in',
        phone: '9876543210',
        busNumber: 'BUS-04',
        totalTrips: 14,
        completedTrips: 13,
        skippedStops: 1,
      );
      final socket = FakeSocketService();
      final loc = FakeLocationService();
      final trip = TripProvider(api, socket, loc);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: auth),
            ChangeNotifierProvider<TripProvider>.value(value: trip),
          ],
          child: const MaterialApp(
            home: ProfileScreen(),
          ),
        ),
      );

      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }
}
