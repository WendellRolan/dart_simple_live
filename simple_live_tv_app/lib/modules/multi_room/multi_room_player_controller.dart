import 'dart:async';

import 'package:get/get.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:simple_live_core/simple_live_core.dart';
import 'package:simple_live_tv_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_tv_app/app/log.dart';
import 'package:simple_live_tv_app/modules/multi_room/multi_room_models.dart';

class MultiRoomPlayerController extends GetxController {
  final MultiRoomItem item;

  MultiRoomPlayerController(this.item);

  late final Player player = Player(
    configuration: PlayerConfiguration(
      title: item.userName,
      logLevel: MPVLogLevel.error,
    ),
  );
  late final VideoController videoController = VideoController(
    player,
    configuration: AppSettingsController.instance.playerCompatMode.value
        ? const VideoControllerConfiguration(
            vo: 'mediacodec_embed',
            hwdec: 'mediacodec',
          )
        : VideoControllerConfiguration(
            enableHardwareAcceleration:
                AppSettingsController.instance.hardwareDecode.value,
            androidAttachSurfaceAfterVideoParameters: false,
          ),
  );

  final detail = Rx<LiveRoomDetail?>(null);
  final loading = true.obs;
  final liveStatus = false.obs;
  final errorText = "".obs;
  final muted = true.obs;
  final qualityInfo = "".obs;
  final lineInfo = "".obs;

  List<LivePlayQuality> _qualities = const [];
  List<String> _playUrls = const [];
  Map<String, String>? _playHeaders;
  int _qualityIndex = -1;
  int _lineIndex = 0;
  int _mediaErrorRetryCount = 0;
  bool _disposed = false;
  StreamSubscription<String>? _errorSubscription;
  StreamSubscription<bool>? _completedSubscription;
  StreamSubscription? _logSubscription;

  String get title {
    final roomTitle = detail.value?.title.trim();
    if (roomTitle != null && roomTitle.isNotEmpty) {
      return roomTitle;
    }
    return item.userName;
  }

  @override
  void onInit() {
    super.onInit();
    _initPlayerStreams();
    unawaited(load());
  }

  void _initPlayerStreams() {
    _errorSubscription = player.stream.error.listen((event) {
      Log.d("多屏同播播放器错误：${item.site.id}/${item.roomId} $event");
      if (event.contains('no sound.')) {
        return;
      }
      unawaited(_handleMediaError(event));
    });
    _completedSubscription = player.stream.completed.listen((event) {
      if (event) {
        unawaited(_handleMediaEnd());
      }
    });
    _logSubscription = player.stream.log.listen((event) {
      Log.d("多屏同播播放器日志：${item.site.id}/${item.roomId} ${event.text}");
    });
  }

  Future<void> load() async {
    loading.value = true;
    errorText.value = "";
    liveStatus.value = false;
    try {
      await player.stop();
      final roomDetail =
          await item.site.liveSite.getRoomDetail(roomId: item.roomId);
      if (_disposed) {
        return;
      }
      detail.value = roomDetail;
      liveStatus.value = roomDetail.status || roomDetail.isRecord;
      if (!liveStatus.value) {
        errorText.value = "未开播";
        return;
      }
      await _loadQualities(roomDetail);
      await _loadPlayUrls(roomDetail);
      await _openCurrentUrl();
    } catch (e) {
      Log.e(
        "多屏同播加载失败：${item.site.id}/${item.roomId} $e",
        StackTrace.current,
      );
      errorText.value = e.toString();
    } finally {
      if (!_disposed) {
        loading.value = false;
      }
    }
  }

  Future<void> _loadQualities(LiveRoomDetail roomDetail) async {
    _qualities = await item.site.liveSite.getPlayQualites(detail: roomDetail);
    if (_qualities.isEmpty) {
      throw Exception("无法读取播放清晰度");
    }
    final qualityLevel = AppSettingsController.instance.qualityLevel.value;
    if (qualityLevel == 2) {
      _qualityIndex = 0;
    } else if (qualityLevel == 0) {
      _qualityIndex = _qualities.length - 1;
    } else {
      _qualityIndex = (_qualities.length / 2).floor();
    }
    qualityInfo.value = _qualities[_qualityIndex].quality;
  }

  Future<void> _loadPlayUrls(LiveRoomDetail roomDetail) async {
    final playUrl = await item.site.liveSite.getPlayUrls(
      detail: roomDetail,
      quality: _qualities[_qualityIndex],
    );
    if (playUrl.urls.isEmpty) {
      throw Exception("无法读取播放地址");
    }
    _playUrls = playUrl.urls;
    _playHeaders = playUrl.headers;
    _lineIndex = 0;
    _mediaErrorRetryCount = 0;
    lineInfo.value = "线路${_lineIndex + 1}";
  }

  Future<void> _openCurrentUrl() async {
    if (_playUrls.isEmpty || _lineIndex < 0 || _lineIndex >= _playUrls.length) {
      throw Exception("播放线路为空");
    }
    errorText.value = "";
    await player.open(Media(_playUrls[_lineIndex], httpHeaders: _playHeaders));
    await player.setVolume(muted.value ? 0 : 100);
    Log.d(
      "多屏同播播放链接：${item.site.id}/${item.roomId} "
      "线路${_lineIndex + 1}/${_playUrls.length} ${_playUrls[_lineIndex]}",
    );
  }

  Future<void> _handleMediaEnd() async {
    if (_disposed || loading.value || _playUrls.isEmpty) {
      return;
    }
    if (_lineIndex < _playUrls.length - 1) {
      _lineIndex += 1;
      _mediaErrorRetryCount = 0;
      lineInfo.value = "线路${_lineIndex + 1}";
      await _openCurrentUrl();
      return;
    }
    errorText.value = "播放已结束";
  }

  Future<void> _handleMediaError(String error) async {
    if (_disposed || loading.value || _playUrls.isEmpty) {
      return;
    }
    if (_mediaErrorRetryCount < 2) {
      _mediaErrorRetryCount += 1;
      await Future<void>.delayed(const Duration(seconds: 1));
      if (!_disposed) {
        await _openCurrentUrl();
      }
      return;
    }
    if (_lineIndex < _playUrls.length - 1) {
      _lineIndex += 1;
      _mediaErrorRetryCount = 0;
      lineInfo.value = "线路${_lineIndex + 1}";
      await _openCurrentUrl();
      return;
    }
    errorText.value = "播放失败：$error";
  }

  Future<void> refreshRoom() async {
    await load();
  }

  Future<void> toggleMute() async {
    muted.value = !muted.value;
    await player.setVolume(muted.value ? 0 : 100);
  }

  @override
  void onClose() {
    _disposed = true;
    unawaited(_errorSubscription?.cancel());
    unawaited(_completedSubscription?.cancel());
    unawaited(_logSubscription?.cancel());
    unawaited(player.stop());
    unawaited(player.dispose());
    super.onClose();
  }
}
