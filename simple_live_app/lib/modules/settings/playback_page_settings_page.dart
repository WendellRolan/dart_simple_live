import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/app/constant.dart';
import 'package:simple_live_app/modules/settings/indexed_settings/indexed_settings_controller.dart';
import 'package:simple_live_app/widgets/settings/settings_card.dart';

class PlaybackPageSettingsPage extends GetView<IndexedSettingsController> {
  const PlaybackPageSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("播放页设置"),
      ),
      body: ListView(
        padding: AppStyle.pagePadding(),
        children: [
          Padding(
            padding: AppStyle.edgeInsetsA12.copyWith(top: 0),
            child: Text(
              "播放页标签顺序",
              style: Get.textTheme.titleSmall,
            ),
          ),
          SettingsCard(
            child: Obx(
              () => ReorderableListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                onReorder: controller.updateLiveRoomTabSort,
                children: controller.liveRoomTabSort.map(
                  (key) {
                    final item = Constant.allLiveRoomTabs[key]!;
                    return ListTile(
                      key: ValueKey("tab_$key"),
                      title: Text(item.title),
                      subtitle:
                          item.subtitle == null ? null : Text(item.subtitle!),
                      visualDensity: VisualDensity.compact,
                      leading: Icon(item.iconData),
                      trailing: _buildTrailingAction(key),
                    );
                  },
                ).toList(),
              ),
            ),
          ),
          Padding(
            padding: AppStyle.edgeInsetsA12.copyWith(top: 24),
            child: Text(
              "全屏长按快捷入口",
              style: Get.textTheme.titleSmall,
            ),
          ),
          SettingsCard(
            child: Obx(
              () => ReorderableListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                onReorder: controller.updateLiveRoomQuickAccessSort,
                children: controller.liveRoomQuickAccessSort.map(
                  (key) {
                    final item = Constant.allLiveRoomQuickAccess[key]!;
                    final enabled =
                        controller.liveRoomQuickAccessEnabled.contains(key);
                    return ListTile(
                      key: ValueKey("quick_$key"),
                      leading: Icon(item.iconData),
                      title: Text(item.title),
                      subtitle: Text(item.subtitle),
                      visualDensity: VisualDensity.compact,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Switch(
                            value: enabled,
                            onChanged: (value) {
                              controller.setLiveRoomQuickAccessEnabled(
                                key,
                                value,
                              );
                            },
                          ),
                          const Icon(Icons.drag_handle),
                        ],
                      ),
                    );
                  },
                ).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrailingAction(String key) {
    if (key == "contribution_rank") {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Obx(
            () => Switch(
              value: controller.contributionRankEnable.value,
              onChanged: controller.setContributionRankEnable,
            ),
          ),
          const Icon(Icons.drag_handle),
        ],
      );
    }
    if (key == "event_flow") {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Obx(
            () => Switch(
              value: controller.liveEventFlowEnable.value,
              onChanged: controller.setLiveEventFlowEnable,
            ),
          ),
          const Icon(Icons.drag_handle),
        ],
      );
    }
    return const Icon(Icons.drag_handle);
  }
}
