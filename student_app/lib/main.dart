import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme.dart';
import 'providers/auth_provider.dart';
import 'providers/live_provider.dart';
import 'screens/login_screen.dart';
import 'screens/shell_screen.dart';
import 'services/api_client.dart';
import 'services/device_location.dart';
import 'services/socket_service.dart';

import 'services/fcm_service.dart';

Future<void> main() async {
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

  await auth.restore();
  if (auth.isAuthenticated) {
    final token = await api.getToken();
    if (token != null) await live.start(token);
  }
  runApp(CampusStudentApp(api: api, socket: socket, auth: auth, live: live));
}

class CampusStudentApp extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider.value(value: api),
        Provider.value(value: socket),
        ChangeNotifierProvider.value(value: auth),
        ChangeNotifierProvider.value(value: live),
      ],
      child: Consumer<AuthProvider>(
        builder: (context, authState, _) {
          return MaterialApp(
            title: 'Campus Bus',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            home: authState.isAuthenticated ? const ShellScreen() : const LoginScreen(),
          );
        },
      ),
    );
  }
}
