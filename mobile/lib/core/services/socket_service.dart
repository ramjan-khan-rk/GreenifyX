import 'package:socket_io_client/socket_io_client.dart' as IO;

import '../config/app_config.dart';
import 'storage_service.dart';

class SocketService {
  SocketService._();

  static final SocketService instance = SocketService._();

  IO.Socket? socket;

  bool _connected = false;
  bool _connecting = false;

  Future<void> connect(String userId) async {
    if (_connected || _connecting) return;
    _connecting = true;

    final token = await StorageService.getToken();
    if (token == null) {
      _connecting = false;
      return;
    }

    socket = IO.io(
      AppConfig.socketUrl,
      IO.OptionBuilder()
          .setTransports(["websocket"])
          .setAuth({"token": token})
          .disableAutoConnect()
          .build(),
    );

    socket!.connect();

    socket!.onConnect((_) {
      _connected = true;
      _connecting = false;
      socket!.emit("join", userId);
    });

    socket!.onDisconnect((_) {
      _connected = false;
      _connecting = false;
    });

    socket!.onConnectError((_) {
      _connecting = false;
    });
  }

  void on(String event, Function(dynamic) callback) {
    socket?.on(event, callback);
  }

  void off(String event) {
    socket?.off(event);
  }

  void emit(String event, dynamic data) {
    socket?.emit(event, data);
  }

  void disconnect() {
    _connected = false;
    _connecting = false;
    socket?.dispose();
    socket = null;
  }
}
