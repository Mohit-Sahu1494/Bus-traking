import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme.dart';
import 'providers/auth_provider.dart';
import 'providers/trip_provider.dart';
import 'screens/login_screen.dart';
import 'screens/shell_screen.dart';
import 'screens/splash_screen.dart';
import 'services/api_client.dart';
import 'services/device_location.dart';
import 'services/socket_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final api = ApiClient();
  final socket = SocketService();
  final location = DeviceLocationService();
  final auth = AuthProvider(api);
  final trip = TripProvider(api, socket, location);

  runApp(CampusDriverApp(api: api, auth: auth, trip: trip));
}

class CampusDriverApp extends StatefulWidget {
  const CampusDriverApp({
    super.key,
    required this.api,
    required this.auth,
    required this.trip,
  });

  final ApiClient api;
  final AuthProvider auth;
  final TripProvider trip;

  @override
  State<CampusDriverApp> createState() => _CampusDriverAppState();
}

class _CampusDriverAppState extends State<CampusDriverApp> {
  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    await widget.auth.restore();
    if (widget.auth.isAuthenticated) {
      final token = await widget.api.getToken();
      if (token != null) {
        unawaited(widget.trip.startSession(token));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider.value(value: widget.api),
        ChangeNotifierProvider.value(value: widget.auth),
        ChangeNotifierProvider.value(value: widget.trip),
      ],
      child: Consumer<AuthProvider>(
        builder: (context, authState, _) {
          return MaterialApp(
            title: 'Campus Driver',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            home: authState.loading
                ? const SplashScreen()
                : (authState.isAuthenticated
                    ? const ShellScreen()
                    : const LoginScreen()),
          );
        },
      ),
    );
  }
}
