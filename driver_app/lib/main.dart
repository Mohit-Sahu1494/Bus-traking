import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme.dart';
import 'providers/auth_provider.dart';
import 'providers/trip_provider.dart';
import 'screens/login_screen.dart';
import 'screens/shell_screen.dart';
import 'services/api_client.dart';
import 'services/device_location.dart';
import 'services/socket_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final api = ApiClient();
  final socket = SocketService();
  final location = DeviceLocationService();
  final auth = AuthProvider(api);
  final trip = TripProvider(api, socket, location);
  await auth.restore();
  if (auth.isAuthenticated) {
    final token = await api.getToken();
    if (token != null) await trip.startSession(token);
  }
  runApp(CampusDriverApp(api: api, auth: auth, trip: trip));
}

class CampusDriverApp extends StatelessWidget {
  const CampusDriverApp({super.key, required this.api, required this.auth, required this.trip});
  final ApiClient api;
  final AuthProvider auth;
  final TripProvider trip;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider.value(value: api),
        ChangeNotifierProvider.value(value: auth),
        ChangeNotifierProvider.value(value: trip),
      ],
      child: MaterialApp(
        title: 'Campus Driver',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: auth.isAuthenticated ? const ShellScreen() : const LoginScreen(),
      ),
    );
  }
}
