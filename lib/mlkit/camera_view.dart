import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'package:get/get.dart';
import 'package:nflutter_native_mlkit/mlkit/camera_controller.dart';

class CameraView extends StatelessWidget {
  final viewType = "Camera-View";
  final globalKey = GlobalKey();
  final controller = Get.put(CameraController());

  CameraView({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.blue,
      child: Stack(
        children: [
          const Center(
            child: SizedBox(
              height: 100,
              width: 100,
              child: CircularProgressIndicator(),
            ),
          ),
          Center(
            child: OrientationBuilder(builder: (context, orientation) {
              controller.orientation(orientation);
              return Visibility(
                visible: true,
                child: Builder(builder: (context) {
                  if (GetPlatform.isIOS) {
                    return UiKitView(
                      viewType: "Camera-View",
                      layoutDirection: TextDirection.ltr,
                      creationParams: {
                        "height": Get.height,
                        "width": Get.width,
                      },
                      creationParamsCodec: const StandardMessageCodec(),
                    );
                  }
                  return PlatformViewLink(
                    viewType: viewType,
                    surfaceFactory: (context, controller) {
                      return AndroidViewSurface(
                        controller: controller as AndroidViewController,
                        gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
                        hitTestBehavior: PlatformViewHitTestBehavior.transparent,
                      );
                    },
                    onCreatePlatformView: (params) {
                      return PlatformViewsService.initAndroidView(
                        id: params.id,
                        viewType: viewType,
                        layoutDirection: TextDirection.ltr,
                        creationParams: {},
                        creationParamsCodec: const StandardMessageCodec(),
                        onFocus: () {
                          params.onFocusChanged(true);
                        },
                      )
                        ..addOnPlatformViewCreatedListener(params.onPlatformViewCreated)
                        ..create();
                    },
                  );
                }),
              );
            }),
          ),
        ],
      ),
    );
  }
}
