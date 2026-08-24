import 'package:socket_io_client/socket_io_client.dart' as IO;

class SocketService {
  SocketService._();

  static final SocketService instance = SocketService._();

  late IO.Socket socket;

  bool _connected = false;

  void connect(String userId) {
    if (_connected) return;

    socket = IO.io(
      "http://10.238.223.39:5000",
      IO.OptionBuilder()
          .setTransports(["websocket"])
          .disableAutoConnect()
          .build(),
    );

    socket.connect();

    socket.onConnect((_) {
      _connected = true;

      print("🟢 Socket Connected");

      socket.emit("join", userId);
    });

    socket.onDisconnect((_) {
      _connected = false;

      print("🔴 Socket Disconnected");
    });
  }

  void on(String event, Function(dynamic) callback) {
    socket.on(event, callback);
  }

  void off(String event) {
    socket.off(event);
  }

  void emit(String event, dynamic data) {
    socket.emit(event, data);
  }

  void disconnect() {
    _connected = false;
    socket.dispose();
  }
}