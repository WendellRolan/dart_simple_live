import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:simple_live_tv_app/app/app_focus_node.dart';
import 'package:simple_live_tv_app/app/app_style.dart';
import 'package:simple_live_tv_app/app/sites.dart';
import 'package:simple_live_tv_app/modules/multi_room/multi_room_models.dart';
import 'package:simple_live_tv_app/routes/app_navigation.dart';
import 'package:simple_live_tv_app/services/follow_user_service.dart';
import 'package:simple_live_tv_app/widgets/app_scaffold.dart';
import 'package:simple_live_tv_app/widgets/button/highlight_button.dart';
import 'package:simple_live_tv_app/widgets/card/anchor_card.dart';

class FollowUserPage extends StatelessWidget {
  const FollowUserPage({super.key});

  static final RxBool _multiSelectMode = false.obs;
  static final RxSet<String> _selectedRoomKeys = <String>{}.obs;

  void _toggleMultiSelectMode() {
    _multiSelectMode.value = !_multiSelectMode.value;
    if (!_multiSelectMode.value) {
      _selectedRoomKeys.clear();
    }
  }

  void _toggleRoom(dynamic item) {
    if (item.liveStatus.value != 2) {
      SmartDialog.showToast("当前状态不是直播中，请先刷新关注状态");
      return;
    }
    if (_selectedRoomKeys.contains(item.id)) {
      _selectedRoomKeys.remove(item.id);
    } else {
      _selectedRoomKeys.add(item.id);
    }
  }

  void _openSelectedRooms() {
    final selected = FollowUserService.instance.list
        .where(
          (item) =>
              _selectedRoomKeys.contains(item.id) &&
              item.liveStatus.value == 2 &&
              Sites.allSites.containsKey(item.siteId),
        )
        .map(MultiRoomItem.fromFollow)
        .toList();
    if (selected.length < 2) {
      SmartDialog.showToast("请至少选择 2 个直播中的主播");
      return;
    }
    AppNavigator.toMultiRoom(selected);
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      child: Column(
        children: [
          AppStyle.vGap32,
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AppStyle.hGap48,
              HighlightButton(
                focusNode: AppFocusNode(),
                iconData: Icons.arrow_back,
                text: "返回",
                autofocus: true,
                onTap: () {
                  Get.back();
                },
              ),
              AppStyle.hGap32,
              Text(
                "我的关注",
                style: AppStyle.titleStyleWhite.copyWith(
                  fontSize: 36.w,
                  fontWeight: FontWeight.bold,
                ),
              ),
              AppStyle.hGap24,
              const Spacer(),
              HighlightButton(
                focusNode: AppFocusNode(),
                iconData: Icons.refresh,
                text: "刷新",
                onTap: () {
                  FollowUserService.instance.refreshData();
                },
              ),
              AppStyle.hGap24,
              Obx(
                () => HighlightButton(
                  focusNode: AppFocusNode(),
                  iconData: _multiSelectMode.value
                      ? Icons.grid_view
                      : Icons.dashboard,
                  text: _multiSelectMode.value
                      ? "开始同播(${_selectedRoomKeys.length})"
                      : "多屏同播",
                  onTap: _multiSelectMode.value
                      ? _openSelectedRooms
                      : _toggleMultiSelectMode,
                ),
              ),
              AppStyle.hGap24,
              Obx(
                () => Visibility(
                  visible: _multiSelectMode.value,
                  child: HighlightButton(
                    focusNode: AppFocusNode(),
                    iconData: Icons.close,
                    text: "取消",
                    onTap: _toggleMultiSelectMode,
                  ),
                ),
              ),
              AppStyle.hGap48,
            ],
          ),
          AppStyle.vGap48,
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: Obx(
                    () => MasonryGridView.count(
                      padding: AppStyle.edgeInsetsH48,
                      itemCount: FollowUserService.instance.list.length,
                      crossAxisCount: 3,
                      crossAxisSpacing: 48.w,
                      mainAxisSpacing: 40.w,
                      itemBuilder: (_, i) {
                        var item = FollowUserService.instance.list[i];
                        return Obx(
                          () => Stack(
                            children: [
                              AnchorCard(
                                face: item.face,
                                name: item.userName,
                                siteId: item.siteId,
                                liveStatus: item.liveStatus.value,
                                roomId: item.roomId,
                                onTap: _multiSelectMode.value
                                    ? () => _toggleRoom(item)
                                    : null,
                              ),
                              if (_selectedRoomKeys.contains(item.id))
                                Positioned(
                                  right: 12.w,
                                  bottom: 12.w,
                                  child: const Icon(
                                    Icons.check_circle,
                                    color: Colors.lightGreenAccent,
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
                Obx(
                  () => Visibility(
                    visible: FollowUserService.instance.canLoadMore.value,
                    child: Padding(
                      padding: AppStyle.edgeInsetsA16,
                      child: HighlightButton(
                        focusNode: AppFocusNode(),
                        iconData: Icons.expand_more,
                        text: "加载更多",
                        onTap: FollowUserService.instance.loadData,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
