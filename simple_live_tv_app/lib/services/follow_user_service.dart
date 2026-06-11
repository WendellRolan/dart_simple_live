import 'dart:async';
import 'dart:collection';

import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:simple_live_core/simple_live_core.dart';
import 'package:simple_live_tv_app/app/constant.dart';
import 'package:simple_live_tv_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_tv_app/app/controller/base_controller.dart';
import 'package:simple_live_tv_app/app/event_bus.dart';
import 'package:simple_live_tv_app/app/log.dart';
import 'package:simple_live_tv_app/app/sites.dart';
import 'package:simple_live_tv_app/app/utils.dart';
import 'package:simple_live_tv_app/models/db/follow_user.dart';
import 'package:simple_live_tv_app/services/current_room_service.dart';
import 'package:simple_live_tv_app/services/db_service.dart';

class FollowUserService extends BasePageController<FollowUser> {
  static const Duration updateStatusCooldown = Duration(seconds: 10);
  static const int paginationThreshold = 400;

  static FollowUserService get instance => Get.find<FollowUserService>();

  StreamSubscription<dynamic>? subscription;
  RxList<FollowUser> allList = RxList<FollowUser>();
  RxList<FollowUser> livingList = RxList<FollowUser>();
  var currentDisplayPage = 1.obs;
  var totalDisplayPages = 1.obs;
  var paginationEnabled = false.obs;
  var updating = false.obs;

  Timer? updateTimer;
  bool needUpdate = true;
  int _updateGeneration = 0;
  DateTime? _lastUpdateStatusStartedAt;
  bool _forceNextStatusRefresh = false;
  DateTime? _douyinLimitedUntil;
  int _douyinLimitGeneration = 0;

  FollowUserService() {
    pageSize = AppSettingsController.kFollowPageSizeDefault;
  }

  @override
  void onInit() {
    subscription = EventBus.instance.listen(Constant.kUpdateFollow, (p0) {
      needUpdate = false;
      refreshData(forceStatus: false);
    });

    if (list.isEmpty) {
      refreshData();
    }
    initTimer();
    super.onInit();
  }

  void initTimer() {
    if (AppSettingsController.instance.autoUpdateFollowEnable.value) {
      updateTimer?.cancel();
      updateTimer = Timer.periodic(
        Duration(
          minutes:
              AppSettingsController.instance.autoUpdateFollowDuration.value,
        ),
        (_) {
          if (updating.value) {
            Log.logPrint("上一轮仍在刷新，跳过本次自动刷新");
            return;
          }
          Log.logPrint("Update Follow Timer");
          refreshData(forceStatus: false);
        },
      );
    } else {
      updateTimer?.cancel();
    }
  }

  @override
  Future refreshData({bool forceStatus = true}) async {
    pageSize = AppSettingsController.instance.followPageSize.value;
    _forceNextStatusRefresh = forceStatus;
    await super.refreshData();
  }

  @override
  Future<List<FollowUser>> getData(int page, int pageSize) async {
    if (page == 1) {
      this.pageSize = AppSettingsController.instance.followPageSize.value;
      allList.assignAll(_sortFollowUsers(DBService.instance.getFollowList()));
      updateLivingList();
      if (needUpdate) {
        unawaited(
          startUpdateStatus(
            allList.toList(),
            force: _forceNextStatusRefresh,
          ),
        );
      }
      _forceNextStatusRefresh = false;
      needUpdate = true;
      if (allList.isEmpty) {
        updating.value = false;
      }
    }

    paginationEnabled.value = allList.length > paginationThreshold;
    if (!paginationEnabled.value) {
      currentDisplayPage.value = 1;
      totalDisplayPages.value = 1;
      return allList.toList();
    }

    final effectivePageSize = _effectivePageSizeFor(allList.length);
    final pageCount = _pageCountFor(allList.length);
    final safePage = currentDisplayPage.value.clamp(1, pageCount);
    currentDisplayPage.value = safePage;
    totalDisplayPages.value = pageCount;

    final start = (safePage - 1) * effectivePageSize;
    if (start >= allList.length) {
      return [];
    }
    final end = (start + effectivePageSize).clamp(0, allList.length).toInt();
    return allList.sublist(start, end);
  }

  void sortList() {
    allList.assignAll(_sortFollowUsers(allList));
    paginationEnabled.value = allList.length > paginationThreshold;
    if (!paginationEnabled.value) {
      currentDisplayPage.value = 1;
      totalDisplayPages.value = 1;
      list.assignAll(allList);
    } else {
      final pageCount = _pageCountFor(allList.length);
      totalDisplayPages.value = pageCount;
      if (currentDisplayPage.value > pageCount) {
        currentDisplayPage.value = pageCount;
      }
      if (currentDisplayPage.value < 1) {
        currentDisplayPage.value = 1;
      }
      final pageSize = _effectivePageSizeFor(allList.length);
      final start = (currentDisplayPage.value - 1) * pageSize;
      final end = (start + pageSize).clamp(0, allList.length).toInt();
      list.assignAll(allList.sublist(start, end));
    }
    currentPage = currentDisplayPage.value;
    canLoadMore.value = false;
    updateLivingList();
  }

  int _effectivePageSizeFor(int total) {
    if (total <= paginationThreshold) {
      return total <= 0 ? pageSize : total;
    }
    final maxPageSize = ((total / 2).floor() + 1).clamp(2, total).toInt();
    final effective = AppSettingsController.instance.followPageSize.value
        .clamp(2, maxPageSize)
        .toInt();
    if (effective != AppSettingsController.instance.followPageSize.value) {
      AppSettingsController.instance.setFollowPageSize(effective);
    }
    pageSize = effective;
    return effective;
  }

  int _pageCountFor(int total) {
    if (total <= paginationThreshold) {
      return 1;
    }
    return (total / _effectivePageSizeFor(total)).ceil().clamp(1, total);
  }

  void applyPageSizeSetting() {
    currentDisplayPage.value = 1;
    sortList();
  }

  List<FollowUser> get currentPageNormalTargets =>
      list.where((item) => !item.isSpecialFollow).toList();

  Future<void> refreshCurrentPageStatus() async {
    final targets = paginationEnabled.value
        ? currentPageNormalTargets
        : allList.where((item) => !item.isSpecialFollow).toList();
    await startUpdateStatus(
      _buildRefreshTargets(targets),
      force: true,
    );
  }

  Future<void> refreshAllStatus() async {
    await startUpdateStatus(
      _buildRefreshTargets(allList, includeAllNormals: true),
      force: true,
    );
  }

  List<FollowUser> _buildRefreshTargets(
    Iterable<FollowUser> normalTargets, {
    bool includeAllNormals = false,
  }) {
    final specials = allList.where((item) => item.isSpecialFollow).toList();
    final normals = includeAllNormals
        ? allList.where((item) => !item.isSpecialFollow).toList()
        : normalTargets.where((item) => !item.isSpecialFollow).toList();
    return _distinctFollowUsers([
      ..._sortFollowUsers(specials),
      ..._sortFollowUsers(normals),
    ]);
  }

  List<FollowUser> _distinctFollowUsers(Iterable<FollowUser> items) {
    final result = <FollowUser>[];
    final seenIds = <String>{};
    for (final item in items) {
      final uniqueId = item.id.trim().isNotEmpty
          ? item.id.trim()
          : "${item.siteId}_${item.roomId}";
      if (seenIds.add(uniqueId)) {
        result.add(item);
      }
    }
    return result;
  }

  void goToNextPage() {
    if (!paginationEnabled.value ||
        currentDisplayPage.value >= totalDisplayPages.value) {
      return;
    }
    currentDisplayPage.value += 1;
    sortList();
  }

  void goToPreviousPage() {
    if (!paginationEnabled.value || currentDisplayPage.value <= 1) {
      return;
    }
    currentDisplayPage.value -= 1;
    sortList();
  }

  List<FollowUser> _sortFollowUsers(Iterable<FollowUser> items) {
    return items.toList()..sort(compareFollowUsers);
  }

  int compareFollowUsers(FollowUser a, FollowUser b) {
    if (a.isSpecialFollow != b.isSpecialFollow) {
      return a.isSpecialFollow ? -1 : 1;
    }
    final aLiving = a.liveStatus.value == 2;
    final bLiving = b.liveStatus.value == 2;
    if (aLiving != bLiving) {
      return aLiving ? -1 : 1;
    }
    return b.addTime.compareTo(a.addTime);
  }

  void updateLivingList() {
    livingList.assignAll(
      _sortFollowUsers(allList.where((x) => x.liveStatus.value == 2)),
    );
  }

  int _getConcurrency(int total) {
    if (total <= 0) {
      return 1;
    }
    final currentSiteId = CurrentRoomService.instance.siteId.value;
    final maxWhenPlayingDouyin = currentSiteId == Constant.kDouyin ? 4 : null;
    int cap(int value) {
      if (maxWhenPlayingDouyin == null) {
        return value;
      }
      return value.clamp(1, maxWhenPlayingDouyin).toInt();
    }

    final manual =
        AppSettingsController.instance.effectiveUpdateFollowThreadCount;
    if (manual > 0) {
      return cap(manual.clamp(1, total).toInt());
    }
    if (total <= 300) {
      return cap(total < 48 ? total : 48);
    }
    if (total <= 1000) {
      return cap(32);
    }
    if (total <= 3000) {
      return cap(20);
    }
    if (total <= 5000) {
      return cap(12);
    }
    return cap(8);
  }

  String _getConcurrencyMode() {
    final manual =
        AppSettingsController.instance.effectiveUpdateFollowThreadCount;
    return manual > 0 ? "手动($manual)" : "自动";
  }

  List<FollowUser> _interleaveByPlatform(List<FollowUser> items) {
    final grouped = <String, Queue<FollowUser>>{};
    for (final item in items) {
      grouped.putIfAbsent(item.siteId, () => Queue<FollowUser>()).add(item);
    }

    final result = <FollowUser>[];
    while (grouped.values.any((queue) => queue.isNotEmpty)) {
      for (final queue in grouped.values) {
        if (queue.isNotEmpty) {
          result.add(queue.removeFirst());
        }
      }
    }
    return result;
  }

  List<FollowUser> _deprioritizeCurrentRoom(List<FollowUser> items) {
    final currentKey = CurrentRoomService.instance.currentKey;
    if (currentKey.isEmpty) {
      return items;
    }
    final currentItems = <FollowUser>[];
    final others = <FollowUser>[];
    for (final item in items) {
      if (item.id == currentKey) {
        currentItems.add(item);
      } else {
        others.add(item);
      }
    }
    return [...others, ...currentItems];
  }

  Future<void> startUpdateStatus(
    List<FollowUser> followList, {
    bool force = false,
  }) async {
    final now = DateTime.now();
    final lastStartedAt = _lastUpdateStatusStartedAt;
    if (!force &&
        lastStartedAt != null &&
        now.difference(lastStartedAt) < updateStatusCooldown) {
      Log.logPrint("关注状态刷新过于频繁，已跳过本次网络刷新");
      updating.value = false;
      sortList();
      return;
    }

    _lastUpdateStatusStartedAt = now;
    final generation = ++_updateGeneration;
    if (updating.value) {
      Log.logPrint("已有关注状态刷新任务，旧任务会被新任务替换");
    }
    updating.value = true;

    try {
      if (followList.isEmpty) {
        sortList();
        return;
      }

      final concurrency = _getConcurrency(followList.length);
      Log.logPrint(
        "开始更新关注状态，并发数: $concurrency，模式: ${_getConcurrencyMode()}，总数: ${followList.length}",
      );

      final taskQueue = Queue<FollowUser>.from(
        _deprioritizeCurrentRoom(_interleaveByPlatform(followList)),
      );

      Future<void> worker() async {
        while (taskQueue.isNotEmpty) {
          if (generation != _updateGeneration) {
            return;
          }
          final item = taskQueue.removeFirst();
          await updateLiveStatus(item, generation: generation);
        }
      }

      final workers = <Future<void>>[];
      for (var i = 0; i < concurrency; i++) {
        workers.add(worker());
      }
      await Future.wait(workers);

      if (generation != _updateGeneration) {
        return;
      }
      sortList();
      Log.logPrint("关注状态更新完成");
    } finally {
      if (generation == _updateGeneration) {
        updating.value = false;
      }
    }
  }

  Future<void> updateLiveStatus(FollowUser item, {int? generation}) async {
    try {
      if (_shouldSkipDouyinByLimit(item)) {
        item.liveStatus.value = 0;
        return;
      }
      final site = Sites.allSites[item.siteId]!;
      final isLiving = await site.liveSite.getLiveStatus(roomId: item.roomId);
      if (generation != null && generation != _updateGeneration) {
        return;
      }
      item.liveStatus.value = isLiving ? 2 : 1;
    } catch (e) {
      if (generation != null && generation != _updateGeneration) {
        return;
      }
      if (_isDouyinLimited(item, e)) {
        _handleDouyinLimited(generation: generation);
      }
      Log.logPrint(e);
    }
  }

  bool _shouldSkipDouyinByLimit(FollowUser item) {
    if (item.siteId != Constant.kDouyin) {
      return false;
    }
    final until = _douyinLimitedUntil;
    return until != null && DateTime.now().isBefore(until);
  }

  bool _isDouyinLimited(FollowUser item, Object error) {
    return item.siteId == Constant.kDouyin &&
        error is CoreError &&
        error.statusCode == 444;
  }

  void _handleDouyinLimited({int? generation}) {
    _douyinLimitedUntil = DateTime.now().add(const Duration(minutes: 10));
    if (generation != null && _douyinLimitGeneration == generation) {
      return;
    }
    _douyinLimitGeneration = generation ?? _updateGeneration;
    Log.w("抖音访问受限，后续抖音关注刷新将跳过，10 分钟后再试");
    SmartDialog.showToast("抖音访问受限，请稍后再试");
  }

  void removeItem(FollowUser item, {bool refresh = true}) async {
    final result = await Utils.showAlertDialog(
      "确定要取消关注 ${item.userName} 吗?",
      title: "取消关注",
    );
    if (!result) {
      return;
    }
    await DBService.instance.followBox.delete(item.id);
    if (refresh) {
      refreshData(forceStatus: false);
    } else {
      allList.remove(item);
      list.remove(item);
      livingList.remove(item);
    }
  }

  @override
  void onClose() {
    _updateGeneration++;
    updating.value = false;
    updateTimer?.cancel();
    subscription?.cancel();
    super.onClose();
  }
}
