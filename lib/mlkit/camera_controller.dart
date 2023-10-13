// ignore_for_file: non_constant_identifier_names

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

class CameraController extends GetxController {
  late final MethodChannel _platform = const MethodChannel('camera_channel');
  RxBool overlayVisible = RxBool(true);
  RxInt? currentTimer = RxInt(-1);
  RxString savedVideo = RxString("");
  String CAMERA_FACING = 'front';
  RxBool recording = RxBool(false);
  RxBool isCameraPermited = RxBool(false);
  RxInt selectedPose = RxInt(0);
  RxBool startedCountdown = RxBool(false);
  RxInt recordTimer = RxInt(3);
  RxInt selectedTimer = RxInt(8);
  Rx<Orientation> orientation = Orientation.portrait.obs;

  @override
  Future<void> onInit() async {
    orientation(Orientation.portrait);
    var status = await Permission.camera.status;

    isCameraPermited(status.isGranted);
    update(['camera_body']);
    orientation.listen((p0) {
      //recreateCameraSource();
      update(['camera_body']);
    });

    Timer(
      const Duration(seconds: 5),
      () {
        // recreateCameraSource();
        update(['camera_body']);
        overlayVisible(false);
      },
    );
    super.onInit();
  }

  @override
  Future<void> onClose() async {
    super.onClose();
    await _platform.invokeMethod("dispose");
  }

  Future<void> swapCameras() async {
    if (GetPlatform.isAndroid) {
      await _platform.invokeMethod("SWAP_CAMERA", {
        "facing": CAMERA_FACING,
      });
      if (CAMERA_FACING == "back") {
        CAMERA_FACING = "front";
      } else {
        CAMERA_FACING = "back";
      }
    } else {
      await _platform.invokeMethod("switchCamera", {});
    }
  }

  // Future<void> changeGraphicOverlay([int? id = 1]) async {
  //   selectedPose(id);
  //   print(GetPlatform.isAndroid);
  //   if (GetPlatform.isAndroid) {
  //     await _platform.invokeMethod("CHANGE_POSE_GRAPHIC", {
  //       "id": id,
  //     });
  //   } else {
  //     await _platform.invokeMethod("changePoseGraphic", {
  //       "graphic": id,
  //     });
  //   }
  // }
}
