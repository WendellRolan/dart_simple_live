import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:floating/floating.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:path/path.dart' as p;
import 'package:remixicon/remixicon.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/app/constant.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/modules/live_room/live_room_controller.dart';
import 'package:simple_live_app/modules/live_room/player/player_controls.dart';
import 'package:simple_live_app/modules/live_room/widgets/live_contribution_rank_panel.dart';
import 'package:simple_live_app/services/live_subtitle_service.dart';
import 'package:simple_live_app/widgets/keep_alive_wrapper.dart';
import 'package:simple_live_app/widgets/net_image.dart';
import 'package:simple_live_app/widgets/settings/settings_action.dart';
import 'package:simple_live_app/widgets/settings/settings_card.dart';
import 'package:simple_live_app/widgets/settings/settings_menu.dart';
import 'package:simple_live_app/widgets/settings/settings_number.dart';
import 'package:simple_live_app/widgets/settings/settings_switch.dart';
import 'package:simple_live_app/widgets/status/app_empty_widget.dart';
import 'package:simple_live_app/widgets/superchat_card.dart';
import 'package:simple_live_core/simple_live_core.dart';
import 'package:url_launcher/url_launcher_string.dart';

class LiveRoomPage extends GetView<LiveRoomController> {
  static const double _desktopSidePanelWidth = 300.0;

  const LiveRoomPage({Key? key}) : super(key: key);

  double _bottomSafeInset(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final viewPadding = mediaQuery.viewPadding.bottom;
    final padding = mediaQuery.padding.bottom;
    return viewPadding > padding ? viewPadding : padding;
  }

  double _bottomActionInset(BuildContext context) {
    if (Platform.isIOS &&
        MediaQuery.of(context).orientation == Orientation.landscape) {
      return 0;
    }
    final safeInset = _bottomSafeInset(context);
    if (!Platform.isIOS) {
      return safeInset;
    }
    return safeInset.clamp(0.0, 16.0).toDouble();
  }

  Widget _buildRoomTitleText() {
    return Obx(
      () => Text(
        controller.detail.value?.title ?? "直播间",
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildMobileAppBarTitle(BuildContext context) {
    return SizedBox(
      height: kToolbarHeight,
      child: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: kToolbarHeight),
              child: Center(
                child: _buildRoomTitleText(),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: () => _handleBack(context),
              icon: const Icon(Icons.arrow_back),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              onPressed: showMore,
              icon: const Icon(Icons.more_horiz),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLandscapeAppBarTitle(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final sidePanelWidth = constraints.maxWidth > _desktopSidePanelWidth
            ? _desktopSidePanelWidth
            : 0.0;
        final playerWidth = constraints.maxWidth - sidePanelWidth;
        return SizedBox(
          height: kToolbarHeight,
          child: Row(
            children: [
              SizedBox(
                width: playerWidth,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.only(
                          left: kToolbarHeight,
                          right: 16,
                        ),
                        child: Center(
                          child: _buildRoomTitleText(),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        onPressed: () => _handleBack(context),
                        icon: const Icon(Icons.arrow_back),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: sidePanelWidth,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    onPressed: showMore,
                    icon: const Icon(Icons.more_horiz),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final page = Obx(() {
      if (controller.loadError.value) {
        return Scaffold(
          appBar: AppBar(
            title: const Text("直播间加载失败"),
          ),
          body: Padding(
            padding: AppStyle.edgeInsetsA12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                LottieBuilder.asset(
                  'assets/lotties/error.json',
                  height: 140,
                  repeat: false,
                ),
                const Text(
                  "直播间加载失败",
                  textAlign: TextAlign.center,
                ),
                AppStyle.vGap4,
                Text(
                  controller.error?.toString() ?? "未知错误",
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                AppStyle.vGap4,
                Text(
                  "${controller.rxSite.value.id} - ${controller.rxRoomId.value}",
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton.icon(
                      onPressed: controller.copyErrorDetail,
                      icon: const Icon(Remix.file_copy_line),
                      label: const Text("复制信息"),
                    ),
                    TextButton.icon(
                      onPressed: controller.refreshRoom,
                      icon: const Icon(Remix.refresh_line),
                      label: const Text("刷新"),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }
      if (controller.fullScreenState.value) {
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            controller.exitPlayerWindowMode();
          },
          child: Scaffold(
            body: buildMediaPlayer(),
          ),
        );
      }
      return buildPageUI();
    });
    if (!Platform.isAndroid) {
      return page;
    }
    return PiPSwitcher(
      floating: controller.pip,
      childWhenDisabled: page,
      childWhenEnabled: buildMediaPlayer(),
    );
  }

  Widget buildPageUI() {
    return OrientationBuilder(
      builder: (context, orientation) {
        final usePortraitLayout = Platform.isAndroid &&
            !controller.fullScreenState.value &&
            !controller.smallWindowState.value;
        final effectiveOrientation =
            usePortraitLayout ? Orientation.portrait : orientation;
        final hasLandscapeActionPanel =
            effectiveOrientation == Orientation.landscape;
        final scaffold = Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            titleSpacing: 0,
            title: hasLandscapeActionPanel
                ? _buildLandscapeAppBarTitle(context)
                : _buildMobileAppBarTitle(context),
          ),
          body: effectiveOrientation == Orientation.portrait
              ? buildPhoneUI(context)
              : buildTabletUI(context),
        );
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) {
              return;
            }
            await _handleBack(context);
          },
          child: scaffold,
        );
      },
    );
  }

  Future<void> _handleBack(BuildContext context) async {
    await controller.cancelAutoPipOnLeave();
    if (context.mounted) {
      Navigator.of(context).pop();
    }
  }

  Widget buildPhoneUI(BuildContext context) {
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: buildMediaPlayer(),
        ),
        buildUserProfile(context),
        buildMessageArea(),
        buildBottomActions(context),
      ],
    );
  }

  Widget buildTabletUI(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: buildMediaPlayer(),
              ),
              SizedBox(
                width: _desktopSidePanelWidth,
                child: Column(
                  children: [
                    buildUserProfile(context),
                    buildMessageArea(),
                  ],
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            border: Border(
              top: BorderSide(
                color: Colors.grey.withAlpha(25),
              ),
            ),
          ),
          padding: AppStyle.edgeInsetsV4.copyWith(
            bottom: _bottomActionInset(context) + 4,
          ),
          child: Row(
            children: [
              TextButton.icon(
                style: TextButton.styleFrom(
                  textStyle: const TextStyle(fontSize: 14),
                ),
                onPressed: controller.refreshRoom,
                icon: const Icon(Remix.refresh_line),
                label: const Text("刷新"),
              ),
              AppStyle.hGap4,
              Obx(
                () => controller.followed.value
                    ? TextButton.icon(
                        style: TextButton.styleFrom(
                          textStyle: const TextStyle(fontSize: 14),
                        ),
                        onPressed: controller.removeFollowUser,
                        icon: const Icon(Remix.heart_fill),
                        label: const Text("取消关注"),
                      )
                    : TextButton.icon(
                        style: TextButton.styleFrom(
                          textStyle: const TextStyle(fontSize: 14),
                        ),
                        onPressed: controller.followUser,
                        icon: const Icon(Remix.heart_line),
                        label: const Text("关注"),
                      ),
              ),
              const Expanded(child: Center()),
              TextButton.icon(
                style: TextButton.styleFrom(
                  textStyle: const TextStyle(fontSize: 14),
                ),
                onPressed: controller.share,
                icon: const Icon(Remix.share_line),
                label: const Text("分享"),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(
                  textStyle: const TextStyle(fontSize: 14),
                ),
                onPressed: controller.copyUrl,
                icon: const Icon(Remix.file_copy_line),
                label: const Text("复制链接"),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(
                  textStyle: const TextStyle(fontSize: 14),
                ),
                onPressed: controller.copyPlayUrl,
                icon: const Icon(Remix.file_copy_line),
                label: const Text("复制播放直链"),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget buildMediaPlayer() {
    var boxFit = BoxFit.contain;
    double? aspectRatio;
    if (AppSettingsController.instance.scaleMode.value == 0) {
      boxFit = BoxFit.contain;
    } else if (AppSettingsController.instance.scaleMode.value == 1) {
      boxFit = BoxFit.fill;
    } else if (AppSettingsController.instance.scaleMode.value == 2) {
      boxFit = BoxFit.cover;
    } else if (AppSettingsController.instance.scaleMode.value == 3) {
      boxFit = BoxFit.contain;
      aspectRatio = 16 / 9;
    } else if (AppSettingsController.instance.scaleMode.value == 4) {
      boxFit = BoxFit.contain;
      aspectRatio = 4 / 3;
    }
    return Stack(
      children: [
        const Positioned.fill(
          child: ColoredBox(color: Colors.black),
        ),
        Video(
          key: controller.globalPlayerKey,
          controller: controller.videoController,
          pauseUponEnteringBackgroundMode:
              !AppSettingsController.instance.allowBackgroundPlayback.value,
          resumeUponEnteringForegroundMode:
              !AppSettingsController.instance.allowBackgroundPlayback.value,
          controls: (state) {
            return playerControls(state, controller);
          },
          aspectRatio: aspectRatio,
          fit: boxFit,
          // 自己实现
          wakelock: false,
        ),
        Obx(
          () => Visibility(
            visible: !controller.liveStatus.value,
            child: const Center(
              child: Text(
                "未开播",
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget buildUserProfile(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          top: BorderSide(
            color: Colors.grey.withAlpha(25),
          ),
          bottom: BorderSide(
            color: Colors.grey.withAlpha(25),
          ),
        ),
      ),
      padding: AppStyle.edgeInsetsA8.copyWith(
        left: 12,
        right: 12,
      ),
      child: Obx(
        () => Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.withAlpha(50)),
                borderRadius: AppStyle.radius24,
              ),
              child: NetImage(
                controller.detail.value?.userAvatar ?? "",
                width: 48,
                height: 48,
                borderRadius: 24,
              ),
            ),
            AppStyle.hGap12,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    controller.detail.value?.userName ?? "",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  AppStyle.vGap4,
                  Row(
                    children: [
                      Image.asset(
                        controller.site.logo,
                        width: 20,
                      ),
                      AppStyle.hGap4,
                      Text(
                        controller.site.name,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            AppStyle.hGap12,
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Remix.fire_fill,
                  size: 20,
                  color: Colors.orange,
                ),
                AppStyle.hGap4,
                Text(
                  Utils.onlineToString(
                    controller.online.value,
                  ),
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget buildBottomActions(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          top: BorderSide(
            color: Colors.grey.withAlpha(25),
          ),
        ),
      ),
      padding: EdgeInsets.only(bottom: _bottomActionInset(context)),
      child: Row(
        children: [
          Expanded(
            child: Obx(
              () => controller.followed.value
                  ? TextButton.icon(
                      style: TextButton.styleFrom(
                        textStyle: const TextStyle(fontSize: 14),
                      ),
                      onPressed: controller.removeFollowUser,
                      icon: const Icon(Remix.heart_fill),
                      label: const Text("取消关注"),
                    )
                  : TextButton.icon(
                      style: TextButton.styleFrom(
                        textStyle: const TextStyle(fontSize: 14),
                      ),
                      onPressed: controller.followUser,
                      icon: const Icon(Remix.heart_line),
                      label: const Text("关注"),
                    ),
            ),
          ),
          Expanded(
            child: TextButton.icon(
              style: TextButton.styleFrom(
                textStyle: const TextStyle(fontSize: 14),
              ),
              onPressed: controller.refreshRoom,
              icon: const Icon(Remix.refresh_line),
              label: const Text("刷新"),
            ),
          ),
          Expanded(
            child: TextButton.icon(
              style: TextButton.styleFrom(
                textStyle: const TextStyle(fontSize: 14),
              ),
              onPressed: controller.share,
              icon: const Icon(Remix.share_line),
              label: const Text("分享"),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildMessageArea() {
    return Obx(() {
      final hasSuperChatTab = controller.site.id == Constant.kBiliBili ||
          controller.site.id == Constant.kHuya;
      final hasContributionRankTab = controller.supportsContributionRank &&
          AppSettingsController.instance.contributionRankEnable.value;
      final tabs = <Widget>[];
      final pages = <Widget>[];
      void addTab(String key) {
        switch (key) {
          case "chat":
            tabs.add(const Tab(text: "聊天"));
            pages.add(buildChatList());
            break;
          case "super_chat":
            if (!hasSuperChatTab) return;
            tabs.add(
              Tab(
                child: Text(
                  controller.superChats.isNotEmpty
                      ? "${controller.site.id == Constant.kHuya ? "头条" : "SC"}(${controller.superChats.length})"
                      : controller.site.id == Constant.kHuya
                          ? "头条"
                          : "SC",
                ),
              ),
            );
            pages.add(buildSuperChats());
            break;
          case "follow":
            tabs.add(const Tab(text: "关注"));
            pages.add(buildFollowList());
            break;
          case "settings":
            tabs.add(const Tab(text: "设置"));
            pages.add(buildSettings());
            break;
        }
      }

      for (final key in AppSettingsController.instance.liveRoomTabSort) {
        addTab(key);
      }
      if (hasContributionRankTab) {
        tabs.add(
          Tab(
            text: controller.site.id == Constant.kDouyu ? "亲密榜" : "贡献榜",
          ),
        );
        pages.add(
          KeepAliveWrapper(
            child: LiveContributionRankPanel(controller: controller),
          ),
        );
      }
      return Expanded(
        child: DefaultTabController(
          length: tabs.length,
          child: Column(
            children: [
              TabBar(
                indicatorSize: TabBarIndicatorSize.tab,
                labelPadding: EdgeInsets.zero,
                indicatorWeight: 1.0,
                tabs: tabs,
              ),
              Expanded(
                child: TabBarView(
                  children: pages,
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget buildChatList() {
    return Stack(
      children: [
        ListView.separated(
          controller: controller.scrollController,
          reverse: false,
          separatorBuilder: (_, i) => SizedBox(
            // *2与原来的EdgeInsets.symmetric(vertical: )做兼容
            height: AppSettingsController.instance.chatTextGap.value * 2,
          ),
          padding: AppStyle.edgeInsetsA12,
          itemCount: controller.messages.length,
          itemBuilder: (_, i) {
            var item = controller.messages[i];
            return buildMessageItem(item);
          },
        ),
        Visibility(
          visible: controller.disableAutoScroll.value,
          child: Positioned(
            right: 12,
            bottom: 12,
            child: ElevatedButton.icon(
              onPressed: () {
                controller.forceChatScrollToBottom();
              },
              icon: const Icon(Icons.expand_more),
              label: const Text("最新"),
            ),
          ),
        ),
      ],
    );
  }

  Widget buildMessageItem(LiveMessage message) {
    if (message.userName == "LiveSysMessage") {
      return Obx(
        () => Text(
          message.message,
          style: TextStyle(
            color: Colors.grey,
            fontSize: AppSettingsController.instance.chatTextSize.value,
          ),
        ),
      );
    }

    Widget buildMessageContent({
      required TextStyle userStyle,
      required TextStyle messageStyle,
    }) {
      final remark = controller.getUserRemark(message.userName);
      return _InteractiveChatText(
        userName: message.userName,
        remark: remark,
        message: message.message,
        imageUrls: AppSettingsController.instance.danmuRenderEmoji.value
            ? message.imageUrls
            : null,
        spans: AppSettingsController.instance.danmuRenderEmoji.value
            ? message.spans
            : null,
        userStyle: userStyle,
        messageStyle: messageStyle,
        onUserTap: () => controller.showUserActions(
          message.userName,
          messageContent: message.message,
        ),
        onUserLongPress: () => controller.copyUserName(message.userName),
      );
    }

    return Obx(
      () => AppSettingsController.instance.chatBubbleStyle.value
          ? Row(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Flexible(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.blueGrey.withAlpha(25),
                      //borderRadius: AppStyle.radius8,
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(12),
                        bottomLeft: Radius.circular(12),
                        bottomRight: Radius.circular(12),
                      ),
                    ),
                    padding:
                        AppStyle.edgeInsetsA4.copyWith(left: 12, right: 12),
                    child: buildMessageContent(
                      userStyle: TextStyle(
                        color: Colors.grey,
                        fontSize:
                            AppSettingsController.instance.chatTextSize.value,
                      ),
                      messageStyle: TextStyle(
                        color:
                            Get.isDarkMode ? Colors.white : AppColors.black333,
                        fontSize:
                            AppSettingsController.instance.chatTextSize.value,
                      ),
                    ),
                  ),
                ),
              ],
            )
          : buildMessageContent(
              userStyle: TextStyle(
                color: Colors.grey,
                fontSize: AppSettingsController.instance.chatTextSize.value,
              ),
              messageStyle: TextStyle(
                color: Get.isDarkMode ? Colors.white : AppColors.black333,
                fontSize: AppSettingsController.instance.chatTextSize.value,
              ),
            ),
    );
  }

  Widget buildSuperChats() {
    return KeepAliveWrapper(
      child: Obx(
        () => controller.superChats.isEmpty
            ? AppEmptyWidget(
                message: controller.site.id == Constant.kHuya
                    ? "当前直播间无头条内容"
                    : "当前直播间无 SC 内容",
              )
            : ListView.separated(
                padding: AppStyle.edgeInsetsA12,
                itemCount: controller.superChats.length,
                separatorBuilder: (_, i) => AppStyle.vGap12,
                itemBuilder: (_, i) {
                  var item = controller.sortedSuperChats[i];
                  return SuperChatCard(
                    item,
                    remark: controller.getUserRemark(item.userName),
                    key: ValueKey(
                      item.id ??
                          "${item.userName}|${item.message}|${item.price}|${item.startTime.millisecondsSinceEpoch}",
                    ),
                    onExpire: () {
                      controller.removeSuperChats();
                    },
                    onUserTap: () => controller.showUserActions(
                      item.userName,
                      messageContent: item.message,
                    ),
                    onUserLongPress: () =>
                        controller.copyUserName(item.userName),
                  );
                },
              ),
      ),
    );
  }

  Widget buildSettings() {
    return ListView(
      padding: AppStyle.edgeInsetsA12,
      children: [
        Obx(
          () => Visibility(
            visible: controller.autoExitEnable.value,
            child: ListTile(
              leading: const Icon(Icons.timer_outlined),
              visualDensity: VisualDensity.compact,
              title: Text("${parseDuration(controller.countdown.value)}后自动关闭"),
            ),
          ),
        ),
        Padding(
          padding: AppStyle.edgeInsetsA12,
          child: Text(
            "聊天区",
            style: Get.textTheme.titleSmall,
          ),
        ),
        SettingsCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Obx(
                () => SettingsNumber(
                  title: "文字大小",
                  value:
                      AppSettingsController.instance.chatTextSize.value.toInt(),
                  min: 8,
                  max: 36,
                  onChanged: (e) {
                    AppSettingsController.instance
                        .setChatTextSize(e.toDouble());
                  },
                ),
              ),
              AppStyle.divider,
              Obx(
                () => SettingsNumber(
                  title: "上下间隔",
                  value:
                      AppSettingsController.instance.chatTextGap.value.toInt(),
                  min: 0,
                  max: 12,
                  onChanged: (e) {
                    AppSettingsController.instance.setChatTextGap(e.toDouble());
                  },
                ),
              ),
              AppStyle.divider,
              Obx(
                () => SettingsSwitch(
                  title: "气泡样式",
                  value: AppSettingsController.instance.chatBubbleStyle.value,
                  onChanged: (e) {
                    AppSettingsController.instance.setChatBubbleStyle(e);
                  },
                ),
              ),
              AppStyle.divider,
              Obx(
                () => SettingsSwitch(
                  title: "播放器中显示SC",
                  value:
                      AppSettingsController.instance.playershowSuperChat.value,
                  onChanged: (e) {
                    AppSettingsController.instance.setPlayerShowSuperChat(e);
                  },
                ),
              ),
              AppStyle.divider,
              Obx(
                () => SettingsMenu<bool>(
                  title: controller.site.id == Constant.kHuya ? "头条排序" : "SC排序",
                  value: AppSettingsController.instance.superChatSortDesc.value,
                  valueMap: const {
                    false: "按消失时间正序",
                    true: "按消失时间倒序",
                  },
                  onChanged: (e) {
                    AppSettingsController.instance.setSuperChatSortDesc(e);
                    controller.superChats.refresh();
                  },
                ),
              ),
              AppStyle.divider,
              Obx(
                () => SettingsSwitch(
                  title: "重复弹幕过滤",
                  subtitle: "同一用户在最近若干条内重复刷同一句时只显示一次",
                  value: AppSettingsController.instance.danmuDedupeEnable.value,
                  onChanged: (e) {
                    AppSettingsController.instance.setDanmuDedupeEnable(e);
                  },
                ),
              ),
              AppStyle.divider,
              Obx(
                () => SettingsNumber(
                  title: "过滤窗口",
                  subtitle: "默认 10 条；窗口越大越容易过滤刷屏",
                  value: AppSettingsController.instance.danmuDedupeWindow.value,
                  min: 1,
                  max: 100,
                  onChanged: (e) {
                    AppSettingsController.instance.setDanmuDedupeWindow(e);
                  },
                ),
              ),
              if (controller.supportsContributionRank) ...[
                AppStyle.divider,
                Obx(
                  () => SettingsSwitch(
                    title: controller.site.id == Constant.kDouyu
                        ? "显示亲密榜"
                        : "显示贡献榜",
                    subtitle: "关闭后会隐藏排行榜标签页，降低对官方功能的替代感",
                    value: AppSettingsController
                        .instance.contributionRankEnable.value,
                    onChanged: (e) {
                      AppSettingsController.instance
                          .setContributionRankEnable(e);
                      if (e) {
                        controller.fetchContributionRank(forceRefresh: true);
                      }
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
        Padding(
          padding: AppStyle.edgeInsetsA12,
          child: Text(
            "实时字幕",
            style: Get.textTheme.titleSmall,
          ),
        ),
        buildSubtitleSettingsCard(),
        Padding(
          padding: AppStyle.edgeInsetsA12,
          child: Text(
            "更多设置",
            style: Get.textTheme.titleSmall,
          ),
        ),
        SettingsCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SettingsAction(
                title: "关键词屏蔽",
                onTap: controller.showDanmuShield,
              ),
              AppStyle.divider,
              SettingsAction(
                title: "弹幕设置",
                onTap: controller.showDanmuSettingsSheet,
              ),
              AppStyle.divider,
              SettingsAction(
                title: "直播设置",
                onTap: controller.showLiveSettingsSheet,
              ),
              AppStyle.divider,
              SettingsAction(
                title: "定时关闭",
                onTap: controller.showAutoExitSheet,
              ),
              AppStyle.divider,
              SettingsAction(
                title: "画面尺寸",
                onTap: controller.showPlayerSettingsSheet,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget buildFollowList() {
    return KeepAliveWrapper(
      child: controller.buildFollowUserSelection(
        onClose: () {},
      ),
    );
  }

  void showMore() {
    showModalBottomSheet(
      context: Get.context!,
      constraints: const BoxConstraints(
        maxWidth: 600,
      ),
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => Container(
        padding: EdgeInsets.only(
          bottom: AppStyle.bottomBarHeight + _bottomSafeInset(context),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.refresh),
              title: const Text("刷新"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                controller.refreshRoom();
              },
            ),
            ListTile(
              leading: const Icon(Icons.play_circle_outline),
              title: const Text("切换清晰度"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Get.back();
                controller.showQualitySheet();
              },
            ),
            ListTile(
              leading: const Icon(Icons.switch_video_outlined),
              title: const Text("切换线路"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Get.back();
                controller.showPlayUrlsSheet();
              },
            ),
            ListTile(
              leading: const Icon(Icons.aspect_ratio_outlined),
              title: const Text("画面尺寸"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Get.back();
                controller.showPlayerSettingsSheet();
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text("截图"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                controller.saveScreenshot();
              },
            ),
            Visibility(
              visible: Platform.isAndroid,
              child: ListTile(
                leading: const Icon(Icons.picture_in_picture),
                title: const Text("小窗播放"),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Get.back();
                  controller.enablePIP();
                },
              ),
            ),
            ListTile(
              leading: const Icon(Icons.timer_outlined),
              title: const Text("定时关闭"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Get.back();
                controller.showAutoExitSheet();
              },
            ),
            ListTile(
              leading: const Icon(Icons.subtitles_outlined),
              title: const Text("实时字幕"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Get.back();
                showSubtitleSettingsSheet();
              },
            ),
            ListTile(
              leading: const Icon(Icons.history_outlined),
              title: const Text("观看历史"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Get.back();
                controller.openHistoryPage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.interests_outlined),
              title: const Text("同类推荐"),
              subtitle: Text(controller.currentRecommendationSubtitle),
              trailing: const Icon(Icons.chevron_right),
              enabled: controller.hasCategoryRecommendation,
              onTap: !controller.hasCategoryRecommendation
                  ? null
                  : () {
                      Get.back();
                      controller.openCategoryRecommendation();
                    },
            ),
            ListTile(
              leading: const Icon(Icons.share_sharp),
              title: const Text("分享直播间"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Get.back();
                controller.share();
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text("复制链接"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Get.back();
                controller.copyUrl();
              },
            ),
            ListTile(
              leading: const Icon(Icons.open_in_new),
              title: const Text("APP中打开"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Get.back();
                controller.openNaviteAPP();
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline_rounded),
              title: const Text("播放信息"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Get.back();
                controller.showDebugInfo();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget buildSubtitleSettingsCard() {
    final settings = AppSettingsController.instance;
    return SettingsCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Obx(
            () => SettingsSwitch(
              title: "启用实时字幕",
              subtitle:
                  "需要先选择本机模型路径，${LiveSubtitleService.instance.platformStatusLabel}",
              value: settings.liveSubtitleEnable.value,
              onChanged: (e) async {
                if (e) {
                  final hasModel = await LiveSubtitleService.instance
                      .validateModelPath(settings.liveSubtitleModelPath.value);
                  if (!hasModel) {
                    SmartDialog.showToast("请先选择有效的字幕模型路径");
                    return;
                  }
                }
                settings.setLiveSubtitleEnable(e);
                await LiveSubtitleService.instance.syncPreviewFromSettings();
              },
            ),
          ),
          AppStyle.divider,
          Obx(
            () {
              final modelPath = settings.liveSubtitleModelPath.value;
              final label = modelPath.isEmpty ? "未选择" : p.basename(modelPath);
              return SettingsAction(
                title: "模型路径",
                subtitle: modelPath.isEmpty ? "不内置模型，需用户自行下载并选择" : modelPath,
                value: label,
                onTap: pickSubtitleModelPath,
              );
            },
          ),
          AppStyle.divider,
          SettingsAction(
            title: "模型推荐下载",
            subtitle: "按设备性能选择高级 / 中级 / 甜点级模型",
            onTap: showSubtitleModelRecommendations,
          ),
          AppStyle.divider,
          Obx(
            () => SettingsMenu<String>(
              title: "字幕语言",
              value: settings.liveSubtitleLanguage.value,
              valueMap: const {
                "auto": "自动",
                "zh": "中文",
                "en": "英语",
                "ja": "日语",
                "ko": "韩语",
              },
              onChanged: (e) async {
                settings.setLiveSubtitleLanguage(e);
                await LiveSubtitleService.instance.syncPreviewFromSettings();
              },
            ),
          ),
          AppStyle.divider,
          Obx(
            () => SettingsNumber(
              title: "字幕字号",
              value: settings.liveSubtitleFontSize.value.toInt(),
              min: 12,
              max: 36,
              unit: "px",
              onChanged: (e) {
                settings.setLiveSubtitleFontSize(e.toDouble());
              },
            ),
          ),
          AppStyle.divider,
          Obx(
            () => SettingsMenu<int>(
              title: "字幕位置",
              value: settings.liveSubtitlePosition.value,
              valueMap: const {
                0: "上方",
                1: "中间",
                2: "下方",
              },
              onChanged: (e) {
                settings.setLiveSubtitlePosition(e);
              },
            ),
          ),
        ],
      ),
    );
  }

  void showSubtitleSettingsSheet() {
    showModalBottomSheet(
      context: Get.context!,
      constraints: const BoxConstraints(maxWidth: 600),
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => SafeArea(
        top: false,
        child: ListView(
          shrinkWrap: true,
          padding: AppStyle.edgeInsetsA12.copyWith(
            bottom: AppStyle.bottomBarHeight,
          ),
          children: [
            Padding(
              padding: AppStyle.edgeInsetsH12.copyWith(bottom: 8),
              child: Text(
                "实时字幕",
                style: Get.textTheme.titleMedium,
              ),
            ),
            buildSubtitleSettingsCard(),
          ],
        ),
      ),
    );
  }

  Future<void> pickSubtitleModelPath() async {
    final result = await FilePicker.platform.pickFiles();
    final selectedPath = result?.files.single.path;
    if (selectedPath == null || selectedPath.isEmpty) {
      return;
    }
    if (!await LiveSubtitleService.instance.validateModelPath(selectedPath)) {
      SmartDialog.showToast("模型路径不存在");
      return;
    }
    AppSettingsController.instance.setLiveSubtitleModelPath(selectedPath);
    await LiveSubtitleService.instance.syncPreviewFromSettings();
  }

  void showSubtitleModelRecommendations() {
    Get.dialog(
      AlertDialog(
        title: const Text("字幕模型推荐"),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  "蓝奏云、百度网盘镜像链接请查看 README。下面保留 HuggingFace 原始页面，方便核对文件名。",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
              _SubtitleModelTile(
                title: "高级",
                subtitle:
                    "Whisper large-v3 int8。需要 encoder、decoder 和 tokens 文件。",
                url:
                    "https://huggingface.co/csukuangfj/sherpa-onnx-whisper-large-v3",
              ),
              _SubtitleModelTile(
                title: "中级",
                subtitle: "Paraformer zh int8。需要 model、tokens、config 和 am.mvn。",
                url:
                    "https://huggingface.co/csukuangfj/sherpa-onnx-paraformer-zh-2023-09-14",
              ),
              _SubtitleModelTile(
                title: "甜点级",
                subtitle:
                    "Streaming Zipformer bilingual zh-en int8。需要 encoder、decoder、joiner、tokens、bpe 文件。",
                url:
                    "https://huggingface.co/csukuangfj/sherpa-onnx-streaming-zipformer-bilingual-zh-en-2023-02-20",
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text("关闭"),
          ),
        ],
      ),
    );
  }

  String parseDuration(int sec) {
    // 转为时分秒
    var h = sec ~/ 3600;
    var m = (sec % 3600) ~/ 60;
    var s = sec % 60;
    if (h > 0) {
      return "${h.toString().padLeft(2, '0')}小时${m.toString().padLeft(2, '0')}分钟${s.toString().padLeft(2, '0')}秒";
    }
    if (m > 0) {
      return "${m.toString().padLeft(2, '0')}分钟${s.toString().padLeft(2, '0')}秒";
    }
    return "${s.toString().padLeft(2, '0')}秒";
  }
}

class _SubtitleModelTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String url;

  const _SubtitleModelTile({
    required this.title,
    required this.subtitle,
    required this.url,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.open_in_new),
      onTap: () {
        launchUrlString(url, mode: LaunchMode.externalApplication);
      },
    );
  }
}

class _InteractiveChatText extends StatelessWidget {
  final String userName;
  final String? remark;
  final String message;
  final List<String>? imageUrls;
  final List<LiveMessageSpan>? spans;
  final TextStyle userStyle;
  final TextStyle messageStyle;
  final VoidCallback onUserTap;
  final VoidCallback onUserLongPress;

  const _InteractiveChatText({
    required this.userName,
    this.remark,
    required this.message,
    this.imageUrls,
    this.spans,
    required this.userStyle,
    required this.messageStyle,
    required this.onUserTap,
    required this.onUserLongPress,
  });

  TextSpan _buildTextSpan() {
    final richSpans = spans ?? const <LiveMessageSpan>[];
    return TextSpan(
      style: messageStyle,
      children: [
        TextSpan(
          text: '$userName：',
          style: userStyle,
        ),
        if ((remark ?? "").trim().isNotEmpty)
          TextSpan(
            text: '[${remark!.trim()}] ',
            style: userStyle.copyWith(
              color: userStyle.color?.withAlpha(180),
              fontSize: (userStyle.fontSize ?? 14) - 1,
            ),
          ),
        if (richSpans.isNotEmpty)
          for (final span in richSpans)
            if (span.isText)
              TextSpan(text: span.text)
            else if (span.isImage)
              _buildImageSpan(span.imageUrl!.trim())
            else ...[
              TextSpan(text: message),
              for (final url in imageUrls ?? const <String>[])
                if (url.trim().isNotEmpty) _buildImageSpan(url.trim()),
            ],
      ],
    );
  }

  WidgetSpan _buildImageSpan(String url) {
    return WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: NetImage(
          url,
          width: (messageStyle.fontSize ?? 14) * 1.35,
          height: (messageStyle.fontSize ?? 14) * 1.35,
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textSpan = _buildTextSpan();

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: onUserTap,
      onLongPress: onUserLongPress,
      child: Text.rich(
        textSpan,
        softWrap: true,
        textWidthBasis: TextWidthBasis.parent,
      ),
    );
  }
}
