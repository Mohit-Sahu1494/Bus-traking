import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:student_app/providers/auth_provider.dart';
import 'package:student_app/providers/live_provider.dart';
import 'package:student_app/screens/forgot_password_screen.dart';
import 'package:student_app/screens/login_screen.dart';
import 'package:student_app/services/api_client.dart';
import 'package:student_app/services/device_location.dart';
import 'package:student_app/services/socket_service.dart';

class FakeApiClient extends ApiClient {
  @override
  Future<String?> getToken() async => null;

  @override
  Future<String?> getUserData() async => null;

  @override
  Future<dynamic> send(String method, String path, {dynamic body, bool auth = true}) async {
    if (path == '/api/auth/student/forgot-password') {
      return {
        'success': true,
        'message': 'Password reset code sent',
        'data': {
          'email': 'st****@dhsgu.ac.in',
          'unmaskedEmail': 'student@dhsgu.ac.in',
        }
      };
    }
    if (path == '/api/auth/student/reset-password') {
      return {
        'success': true,
        'message': 'Password reset successfully',
      };
    }
    return {};
  }
}

class FakeSocketService extends SocketService {
  @override
  Future<void> connect(String token) async {}

  @override
  Future<void> disconnect() async {}

  @override
  void on(String event, SocketHandler handler) {}
}

class FakeLocationService extends DeviceLocationService {
  @override
  Future<bool> ensurePermission() async => true;

  @override
  Future<Position?> current() async => Position(
        latitude: 23.8350,
        longitude: 78.7710,
        timestamp: DateTime.now(),
        accuracy: 10,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );
}

void main() {
  testWidgets('ForgotPasswordScreen renders and validates empty email', (tester) async {
    final fakeApi = FakeApiClient();
    final authProv = AuthProvider(fakeApi);

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<AuthProvider>.value(
          value: authProv,
          child: const ForgotPasswordScreen(),
        ),
      ),
    );

    expect(find.text('Forgot Password?'), findsOneWidget);
    expect(find.text('SEND RESET CODE'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);

    // Tap submit with empty email
    await tester.tap(find.text('SEND RESET CODE'));
    await tester.pumpAndSettle();

    expect(find.text('Please enter your student email address.'), findsOneWidget);
  });

  testWidgets('ForgotPasswordScreen accepts initialEmail and moves to verify step on submit', (tester) async {
    final fakeApi = FakeApiClient();
    final authProv = AuthProvider(fakeApi);

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<AuthProvider>.value(
          value: authProv,
          child: const ForgotPasswordScreen(initialEmail: 'student@dhsgu.ac.in'),
        ),
      ),
    );

    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.controller?.text, 'student@dhsgu.ac.in');

    // Tap submit
    await tester.tap(find.text('SEND RESET CODE'));
    await tester.pumpAndSettle();

    // Verifies transition to reset step
    expect(find.text('Reset Your Password'), findsOneWidget);
    expect(find.text('RESET PASSWORD'), findsOneWidget);
    expect(find.text('New Password'), findsOneWidget);
    expect(find.text('Confirm New Password'), findsOneWidget);
  });

  testWidgets('LoginScreen displays Forgot Password button', (tester) async {
    final fakeApi = FakeApiClient();
    final authProv = AuthProvider(fakeApi);
    final liveProv = LiveProvider(fakeApi, FakeSocketService(), FakeLocationService());

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ApiClient>.value(value: fakeApi),
          ChangeNotifierProvider<AuthProvider>.value(value: authProv),
          ChangeNotifierProvider<LiveProvider>.value(value: liveProv),
        ],
        child: const MaterialApp(
          home: LoginScreen(),
        ),
      ),
    );

    expect(find.text('Forgot Password?'), findsOneWidget);
  });

  for (final width in [320.0, 360.0, 375.0, 390.0, 412.0, 430.0]) {
    testWidgets('Student LoginScreen renders without overflow at ${width}px', (tester) async {
      tester.view.physicalSize = Size(width * 2, 800 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final fakeApi = FakeApiClient();
      final authProv = AuthProvider(fakeApi);
      final liveProv = LiveProvider(fakeApi, FakeSocketService(), FakeLocationService());

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<ApiClient>.value(value: fakeApi),
            ChangeNotifierProvider<AuthProvider>.value(value: authProv),
            ChangeNotifierProvider<LiveProvider>.value(value: liveProv),
          ],
          child: const MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );

      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('Campus Bus'), findsOneWidget);
      expect(find.text('SIGN IN'), findsOneWidget);
    });
  }
}
