import UIKit
import Flutter
import AVFoundation
import MLKit
import MLImage
import GLKit
import MetalKit

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
      GeneratedPluginRegistrant.register(with: self)
      let PLUGIN_NAME = "br.obi.tec.bodyway/iosdelegate"
      let VIEW_PLUGIN_NAME = "br.obi.tec.bodyway/iosdelegateview"
      weak var registrar = self.registrar(forPlugin: "plugin-name")
      let factory = FLNativeViewFactory(messenger: registrar!.messenger())
      self.registrar(forPlugin: PLUGIN_NAME)!.register(factory, withId: "Camera-View")

      return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

class FLNativeViewFactory: NSObject, FlutterPlatformViewFactory {
    private var messenger: FlutterBinaryMessenger
    let channel: FlutterMethodChannel

    init(messenger: FlutterBinaryMessenger){
        self.messenger = messenger
        channel = FlutterMethodChannel(name: "camera_channel", binaryMessenger: messenger)
        super.init()
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        return FlutterStandardMessageCodec.sharedInstance()
    }

    func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
        let newArgs = args as! [String: Double]
        let view = FLPLView(frame: CGRect(x: 0, y: 0, width: newArgs["width"] ?? 0, height: newArgs["height"] ?? 0))
        self.channel.setMethodCallHandler({
            (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
            switch call.method {
             
                case "changePoseGraphic":
                    view.changePoseGraphic(graphic: (call.arguments as! [String: Int])["graphic"]!)
                    result(true)
                case "dispose":
                    view.dispose()
                    result(true)
                case "switchCamera":
                    view.switchCamera()
                    result(true)
            default:
                result(FlutterMethodNotImplemented)
            }
        })
        return view
    }
}



class FLPLView: NSObject, FlutterPlatformView {

    var frame: CGRect
    var cameraView: CameraView

    init( frame: CGRect) {
        self.frame = frame
        cameraView = CameraView(frame: frame)
    }

  

    func switchCamera() {
        self.cameraView.switchCamera()
    }

    func dispose(){
        self.cameraView.dispose()
    }

    func changePoseGraphic(graphic: Int){
        self.cameraView.changePoseGraphic(graphic: graphic)
    }

    deinit {
        print("dispose do camera view")
        self.cameraView.dispose()
    }

    func view() -> UIView {
        return cameraView
    }
}
