import 'dart:async';
import 'package:signalr_netcore/signalr_client.dart';
import 'package:simple_live_tv_app/app/log.dart';
import 'package:simple_live_tv_app/app/utils.dart';

enum SignalRConnectionState {
  connecting,
  connected,
  disconnected,
}

class SignalRService {
  static const String kUrl = "https://sync1.nsapps.cn/sync";

  SignalRConnectionState state = SignalRConnectionState.connecting;

  final _stateStreamController =
      StreamController<SignalRConnectionState>.broadcast();
  Stream<SignalRConnectionState> get stateStream =>
      _stateStreamController.stream;

  final _onFavoriteStreamController =
      StreamController<(bool, String)>.broadcast();
  Stream<(bool, String)> get onFavoriteStream =>
      _onFavoriteStreamController.stream;

  final _onHistoryStreamController =
      StreamController<(bool, String)>.broadcast();
  Stream<(bool, String)> get onHistoryStream =>
      _onHistoryStreamController.stream;

  final _onShieldWordStreamController =
      StreamController<(bool, String)>.broadcast();
  Stream<(bool, String)> get onShieldWordStream =>
      _onShieldWordStreamController.stream;

  final _onBiliAccountStreamController =
      StreamController<(bool, String)>.broadcast();
  Stream<(bool, String)> get onBiliAccountStream =>
      _onBiliAccountStreamController.stream;

  final _onRoomDestroyedStreamController = StreamController<String>.broadcast();
  Stream<String> get onRoomDestroyedStream =>
      _onRoomDestroyedStreamController.stream;

  final _onRoomUserUpdatedStreamController =
      StreamController<List<RoomUser>>.broadcast();
  Stream<List<RoomUser>> get onRoomUserUpdatedStream =>
      _onRoomUserUpdatedStreamController.stream;

  HubConnection? hubConnection;
  Future<void> connect() async {
    try {
      hubConnection = HubConnectionBuilder().withUrl(kUrl).build();
      hubConnection!.onclose(({Exception? error}) {
        Log.d("SignalR disconnected: $error");
        state = SignalRConnectionState.disconnected;
        _stateStreamController.add(state);
      });
      hubConnection!.onreconnected(({String? connectionId}) {
        Log.d("SignalR reconnected: $connectionId");
        state = SignalRConnectionState.connected;
        _stateStreamController.add(state);
      });
      await hubConnection!.start();
      state = SignalRConnectionState.connected;
      _stateStreamController.add(state);
      _listen();
    } catch (e) {
      Log.logPrint(e);
      state = SignalRConnectionState.disconnected;
      _stateStreamController.add(state);
      rethrow;
    }
  }

  void _listen() {
    hubConnection?.on("onFavoriteReceived", (args) {
      final data = _readBoolStringArgs(args);
      if (data != null) {
        _onFavoriteStreamController.add(data);
      }
    });
    hubConnection?.on("onHistoryReceived", (args) {
      final data = _readBoolStringArgs(args);
      if (data != null) {
        _onHistoryStreamController.add(data);
      }
    });
    hubConnection?.on("onShieldWordReceived", (args) {
      final data = _readBoolStringArgs(args);
      if (data != null) {
        _onShieldWordStreamController.add(data);
      }
    });
    hubConnection?.on("onBiliAccountReceived", (args) {
      final data = _readBoolStringArgs(args);
      if (data != null) {
        _onBiliAccountStreamController.add(data);
      }
    });
    hubConnection?.on("onRoomDestroyed", (args) {
      _onRoomDestroyedStreamController.add(args![0].toString());
    });
    hubConnection?.on("onUserUpdated", (args) {
      final rawUsers = args?.isNotEmpty == true ? args![0] : const [];
      final list = rawUsers is List
          ? rawUsers.map((e) => RoomUser.fromObject(e)).toList()
          : <RoomUser>[];
      _onRoomUserUpdatedStreamController.add(list);
    });
  }

  (bool, String)? _readBoolStringArgs(List<Object?>? args) {
    if (args == null || args.length < 2) {
      Log.d("SignalR 收到异常同步消息: $args");
      return null;
    }
    return (args[0] == true, args[1]?.toString() ?? "");
  }

  Future<void> disconnect() async {
    await hubConnection?.stop();
    state = SignalRConnectionState.disconnected;
    _stateStreamController.add(state);
  }

  Future<Resp<String>> createRoom() async {
    if (state != SignalRConnectionState.connected) {
      throw Exception("not connected");
    }
    String app = "Simple Live TV";
    String platform = 'tv';
    String version = Utils.packageInfo.version;
    var resp = await hubConnection
        ?.invoke("CreateRoom", args: [app, platform, version]);
    return Resp<String>.fromObject(resp);
  }

  Future<Resp> joinRoom(String roomId) async {
    if (state != SignalRConnectionState.connected) {
      throw Exception("not connected");
    }
    String app = "Simple Live TV";
    String platform = 'tv';
    String version = Utils.packageInfo.version;
    var resp = await hubConnection
        ?.invoke("JoinRoom", args: [roomId, app, platform, version]);
    return Resp.fromObject(resp);
  }

  Future<Resp> sendContent({
    required String roomName,
    required String action,
    required bool overlay,
    required String content,
  }) async {
    if (state != SignalRConnectionState.connected) {
      throw Exception("not connected");
    }
    var resp =
        await hubConnection?.invoke(action, args: [roomName, overlay, content]);
    return Resp.fromObject(resp);
  }

  void dispose() {
    _stateStreamController.close();
    _onFavoriteStreamController.close();
    _onHistoryStreamController.close();
    _onShieldWordStreamController.close();
    _onBiliAccountStreamController.close();
    _onRoomDestroyedStreamController.close();
    _onRoomUserUpdatedStreamController.close();

    hubConnection?.stop();
  }
}

class Resp<T> {
  final bool isSuccess;
  final String message;
  final T? data;
  Resp(this.isSuccess, this.message, this.data);

  factory Resp.fromJson(Map<String, dynamic> json) {
    return Resp(
      json['isSuccess'] == true,
      json['message'] ?? "",
      json['data'],
    );
  }

  factory Resp.fromObject(Object? obj) {
    if (obj is Map) {
      return Resp.fromJson(Map<String, dynamic>.from(obj));
    }
    if (obj == null) {
      return Resp(false, "服务无响应", null);
    }
    return Resp(false, "服务返回格式异常：$obj", null);
  }
}

class RoomUser {
  final String connectionId;
  final String shortId;
  final String platform;
  final String version;
  final String app;
  final bool? isCreator;

  RoomUser({
    required this.connectionId,
    required this.shortId,
    required this.platform,
    required this.version,
    required this.app,
    this.isCreator = false,
  });

  factory RoomUser.fromJson(Map<String, dynamic> json) {
    return RoomUser(
      connectionId: json['connectionId']?.toString() ?? "",
      shortId: json['shortId']?.toString() ?? "",
      platform: json['platform']?.toString() ?? "",
      version: json['version']?.toString() ?? "",
      app: json['app']?.toString() ?? "",
      isCreator: json['isCreator'] == true,
    );
  }

  factory RoomUser.fromObject(Object? obj) {
    if (obj is Map) {
      return RoomUser.fromJson(Map<String, dynamic>.from(obj));
    }
    return RoomUser(
      connectionId: "",
      shortId: "",
      platform: "",
      version: "",
      app: "",
    );
  }
}
