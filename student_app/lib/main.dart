import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme.dart';
import 'providers/auth_provider.dart';
import 'providers/live_provider.dart';
import 'screens/login_screen.dart';
import 'screens/shell_screen.dart';
import 'screens/splash_screen.dart';
import 'services/api_client.dart';
import 'services/device_location.dart';
import 'services/fcm_service.dart';
import 'services/socket_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final api = ApiClient();
  final socket = SocketService();
  final location = DeviceLocationService();
  final auth = AuthProvider(api);
  api.onUnauthorized = () {
    auth.handleSessionExpired();
  };
  final live = LiveProvider(api, socket, location);

  FcmService().onForegroundNotificationReceived = (_) {
    live.loadNotifications();
  };
  FcmService().onNotificationTapped = (_) {
    live.loadNotifications();
  };

  runApp(CampusStudentApp(api: api, socket: socket, auth: auth, live: live));
}

class CampusStudentApp extends StatefulWidget {
  const CampusStudentApp({
    super.key,
    required this.api,
    required this.socket,
    required this.auth,
    required this.live,
  });

  final ApiClient api;
  final SocketService socket;
  final AuthProvider auth;
  final LiveProvider live;

  @override
  State<CampusStudentApp> createState() => _CampusStudentAppState();
}

class _CampusStudentAppState extends State<CampusStudentApp> {
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
        unawaited(widget.live.start(token));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider.value(value: widget.api),
        Provider.value(value: widget.socket),
        ChangeNotifierProvider.value(value: widget.auth),
        ChangeNotifierProvider.value(value: widget.live),
      ],
      child: Consumer<AuthProvider>(
        builder: (context, authState, _) {
          return MaterialApp(
            title: 'Campus Bus',
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
