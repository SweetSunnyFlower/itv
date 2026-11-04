import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:dlna_dart/dlna.dart';

class DlnaService extends GetxController {
  DLNAManager? _manager;
  StreamSubscription? _deviceSub;

  final devices = <DLNADevice>[].obs;
  final isCasting = false.obs;
  final castingDeviceName = ''.obs;
  DLNADevice? _castingDevice;

  void startSearch() {
    stopSearch();
    devices.clear();
    _manager = DLNAManager();
    _manager!.start(reusePort: true).then((dm) {
      _deviceSub = dm.devices.stream.listen((deviceMap) {
        final list = deviceMap.values.toList();
        devices.assignAll(list);
      });
    }).catchError((e) {
      debugPrint('[DLNA] search error: $e');
    });
  }

  void stopSearch() {
    _deviceSub?.cancel();
    _deviceSub = null;
    _manager?.stop();
    _manager = null;
  }

  Future<bool> castTo(DLNADevice device, String url, String title) async {
    try {
      await device.setUrl(url, title: title);
      await device.play();
      _castingDevice = device;
      isCasting.value = true;
      castingDeviceName.value = device.info.friendlyName;
      return true;
    } catch (e) {
      debugPrint('[DLNA] cast error: $e');
      return false;
    }
  }

  Future<void> stopCast() async {
    try {
      await _castingDevice?.stop();
    } catch (_) {}
    _castingDevice = null;
    isCasting.value = false;
    castingDeviceName.value = '';
  }

  @override
  void onClose() {
    stopSearch();
    stopCast();
    super.onClose();
  }
}
