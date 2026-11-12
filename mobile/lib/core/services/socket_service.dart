import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

import '../config/app_config.dart';
import 'storage_service.dart';

/// Single real-time connection for chat, calls and notifications.
///
/// Listeners are kept in a registry and attached whenever a socket exists, so
/// screens can subscribe before the connection is up (or after a reconnect)
/// without silently missing events such as incoming calls.
class SocketService {
  SocketService._();

  static final SocketService instance = SocketService._();

  io.Socket? socket;
  String? _userId;
  bool _connecting = false;
  final Map<String, List<Function(dynamic)>> _listeners = {};
  final _status = StreamController<bool>.broadcast();

  bool get isConnected => socket?.connected == true;

  /// Emits true/false as the connection comes and goes.
  Stream<bool> get status => _status.stream;

  Future<void> connect(String userId) async {
    _userId = userId;
    if (isConnected || _connecting) return;
    _connecting = true;

    final token = await StorageService.getToken();
    if (token == null) {
      _connecting = false;
      return;
    }

    socket?.dispose();
    final s = io.io(
      AppConfig.socketUrl,
      io.OptionBuilder()
          .setTransports(["websocket"])
          .setAuth({"token": token})
          .enableReconnection()
          .setReconnectionDelay(1500)
          .disableAutoConnect()
          .build(),
    );
    socket = s;

    // Attach everything registered so far.
    _listeners.forEach((event, callbacks) {
      for (final cb in callbacks) {
        s.on(event, cb);
      }
    });

    s.onConnect((_) {
      _connecting = false;
      s.emit("join", _userId);
      _status.add(true);
    });
    s.onDisconnect((_) => _status.add(false));
    s.onConnectError((_) {
      _connecting = false;
      _status.add(false);
    });

    s.connect();
  }

  /// Reconnects with the last user if the connection dropped. Returns true when connected.
  Future<bool> ensureConnected({Duration wait = const Duration(seconds: 6)}) async {
    if (isConnected) return true;
    final id = _userId;
    if (id == null) return false;
    if (socket == null) {
      await connect(id);
    } else {
      socket!.connect();
    }
    try {
      await status.firstWhere((ok) => ok).timeout(wait);
    } catch (_) {}
    return isConnected;
  }

  void on(String event, Function(dynamic) callback) {
    final list = _listeners.putIfAbsent(event, () => []);
    if (list.contains(callback)) return;
    list.add(callback);
    socket?.on(event, callback);
  }

  /// Removes one listener, or every listener for [event] when [callback] is null.
  void off(String event, [Function(dynamic)? callback]) {
    if (callback == null) {
      _listeners.remove(event);
      socket?.off(event);
      return;
    }
    _listeners[event]?.remove(callback);
    socket?.off(event, callback);
  }

  void emit(String event, dynamic data) {
    socket?.emit(event, data);
  }

  void disconnect() {
    _connecting = false;
    _userId = null;
    socket?.dispose();
    socket = null;
    _status.add(false);
  }
}
