import 'package:socket_io_client/socket_io_client.dart' as io;
import '../core/config.dart';

typedef SocketHandler = void Function(dynamic data);

class SocketService {
  io.Socket? _socket;
  bool connected = false;
  final Map<String, List<SocketHandler>> _handlers = {};

  void on(String event, SocketHandler handler) {
    _handlers.putIfAbsent(event, () => []).add(handler);
    _socket?.on(event, handler);
  }

  void emit(String event, dynamic payload) {
    _socket?.emit(event, payload);
  }

  Future<void> connect(String token) async {
    await disconnect();
    final socket = io.io(
      AppConfig.apiBaseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .enableAutoConnect()
          .enableReconnection()
          .setAuth({'token': token})
          .build(),
    );
    _socket = socket;
    socket.onConnect((_) {
      connected = true;
      _local('connection_status', {'connected': true});
    });
    socket.onDisconnect((_) {
      connected = false;
      _local('connection_status', {'connected': false});
    });
    for (final entry in _handlers.entries) {
      for (final h in entry.value) {
        socket.on(entry.key, h);
      }
    }
    socket.connect();
  }

  void _local(String event, dynamic data) {
    for (final h in _handlers[event] ?? const []) {
      h(data);
    }
  }

  Future<void> disconnect() async {
    _socket?.dispose();
    _socket = null;
    connected = false;
  }
}
