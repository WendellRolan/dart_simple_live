import 'package:get/get.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';

class IndexedSettingsController extends GetxController {
  RxList<String> siteSort = RxList<String>();
  RxList<String> homeSort = RxList<String>();
  RxList<String> liveRoomTabSort = RxList<String>();
  @override
  void onInit() {
    siteSort = AppSettingsController.instance.siteSort;
    homeSort = AppSettingsController.instance.homeSort;
    liveRoomTabSort = AppSettingsController.instance.liveRoomTabSort;
    super.onInit();
  }

  void updateSiteSort(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final String item = siteSort.removeAt(oldIndex);
    siteSort.insert(newIndex, item);
    // ignore: invalid_use_of_protected_member
    AppSettingsController.instance.setSiteSort(siteSort.value);
  }

  void updateHomeSort(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final String item = homeSort.removeAt(oldIndex);
    homeSort.insert(newIndex, item);
    // ignore: invalid_use_of_protected_member
    AppSettingsController.instance.setHomeSort(homeSort.value);
  }

  void updateLiveRoomTabSort(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final String item = liveRoomTabSort.removeAt(oldIndex);
    liveRoomTabSort.insert(newIndex, item);
    // ignore: invalid_use_of_protected_member
    AppSettingsController.instance.setLiveRoomTabSort(liveRoomTabSort.value);
  }
}
