import AVFoundation
import MLImage
import MLKit
import UIKit

class CameraView: UIView {
    private var poseDetector: PoseDetector? = nil
    var session: AVCaptureSession!
    var previewLayer = AVCaptureVideoPreviewLayer()
    let output = AVCaptureVideoDataOutput()
    private var lastFrame: CMSampleBuffer?
    var graphic:Int = 0
    private var camera = CameraType.Front
    func changePoseGraphic(graphic: Int){
        self.graphic = graphic
    }
    private var assetWriter: AVAssetWriter?
    private var assetWriterInput: AVAssetWriterInput?
    private var adapter: AVAssetWriterInputPixelBufferAdaptor?
    private var time: Double = 0
    var poseArray : [Pose] = []
    private lazy var previewOverlayView: UIImageView = {
        let previewOverlayView = UIImageView(frame: bounds)
        previewOverlayView.contentMode = UIView.ContentMode.scaleAspectFill
        previewOverlayView.translatesAutoresizingMaskIntoConstraints = false
        return previewOverlayView
    }()
    private lazy var annotationOverlayView: UIView = {
      let annotationOverlayView = UIView(frame: bounds)
      annotationOverlayView.contentMode = UIView.ContentMode.scaleAspectFill
      annotationOverlayView.translatesAutoresizingMaskIntoConstraints = false
      return annotationOverlayView
    }()

    deinit {
        print("deinit")
        poseDetector = nil
        session?.stopRunning()
    }
    
    func dispose(){
        poseDetector = nil
        session?.stopRunning()
    }

    required override init(frame: CGRect) {
        super.init(frame: frame)
        layer.addSublayer(previewLayer)
        backgroundColor = .red
        layer.frame = frame
        print(layer.frame)
        previewLayer.frame = bounds
        previewLayer.backgroundColor = UIColor.black.cgColor
        checkCameraPermission()
        let options = AccuratePoseDetectorOptions()
        poseDetector = PoseDetector.poseDetector(options: options)
        addSubview(previewOverlayView)
        addSubview(annotationOverlayView)
    }
    
    
    private enum _CaptureState{
        case idle, start, capturing, end
    }
    
    private
    enum CameraType {
       case Front, Back
    }
    
    func switchCamera(){
        if camera == CameraType.Front {
            camera = CameraType.Back
        } else {
            camera = CameraType.Front
        }
        session.stopRunning()
        DispatchQueue.main.async {
            self.setupCamera()
        }
    }
    
    
    private var captureState = _CaptureState.idle
    
    func capture(){
        switch captureState {
            case .idle:
                captureState = .start
            case .capturing:
                captureState = .end
            default:
                break
        }
    }

    
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSublayers(of layer: CALayer){
        super.layoutSublayers(of: layer)
    }

    
    func checkCameraPermission(){
        switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .notDetermined:
                print("Start request camera")
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    guard granted else {
                        return
                    }
                    DispatchQueue.main.async {
                        self.setupCamera()
                    }
                }
            case .restricted:
                break
            case .denied:
                break
            case .authorized:
                setupCamera()
            @unknown default:
                break
        }
    }

    private func setupCamera(){
        print("Starting stupCamera")
        session = AVCaptureSession()
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.frame = self.bounds

        var cameraOrientation: AVCaptureDevice.Position = .front

        if self.camera == CameraType.Front {
            cameraOrientation = .front
        } else {
            cameraOrientation = .back
        }
        
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: cameraOrientation){
            do{
                let input = try AVCaptureDeviceInput(device: device)
                
                if session.canAddInput(input){
                    print("Can add input")
                    session.addInput(input)
                }
                
               
                if session.canAddOutput(output){
                    session.beginConfiguration()
                    session.sessionPreset = .hd1280x720
                    
                    output.videoSettings = [
                        (kCVPixelBufferPixelFormatTypeKey as String): kCVPixelFormatType_32BGRA
                    ]
                    
                    output.alwaysDiscardsLateVideoFrames = true
                    
                    let outputQueue = DispatchQueue(label: "videoDataOutputQueueLabel")
                    
                    output.setSampleBufferDelegate(self, queue: outputQueue)
                    session.addOutput(output)
                    session.commitConfiguration()
                }
                
                previewLayer.videoGravity = .resizeAspectFill
                previewLayer.session = session


                session.startRunning()
                // self.session = session
                print("StartRunning")
                
            } catch {
                print(error)
            }
        }
    }
    
    private func detectPose(in image: MLImage, width: CGFloat, height: CGFloat){
        if let poseDetector = self.poseDetector {
            var poses: [Pose] = []
              var detectionError: Error?
              do {
                poses = try poseDetector.results(in: image)
              } catch let error {
                detectionError = error
              }
              weak var weakSelf = self
              DispatchQueue.main.sync {
                guard let strongSelf = weakSelf else {
                  print("Self is nil!")
                  return
                }
                strongSelf.updatePreviewOverlayViewWithLastFrame()
                if let detectionError = detectionError {
                  print("Failed to detect poses with error: \(detectionError.localizedDescription).")
                  return
                }
                guard !poses.isEmpty else {
                  print("Pose detector returned no results.")
                  return
                }
                poses.forEach { pose in
                        var poseOverlayView: UIView
                        if self.graphic == 0 {
                        poseOverlayView = UIUtilities.createPoseOverlayViewGreen(
                        forPose: pose,
                        inViewWithBounds: self.annotationOverlayView.bounds,
                        lineWidth: 3,
                        dotRadius: 0,
                        positionTransformationClosure: { (position) -> CGPoint in
                        return strongSelf.normalizedPoint(
                        fromVisionPoint: position, width: width, height: height)
                        }
                    )
                            strongSelf.annotationOverlayView.addSubview(poseOverlayView)

                }
                }
            }
        }
    }
    
    private func normalizedPoint(
        fromVisionPoint point: VisionPoint,
        width: CGFloat,
        height: CGFloat
      ) -> CGPoint {
        let cgPoint = CGPoint(x: point.x, y: point.y)
        var normalizedPoint = CGPoint(x: cgPoint.x / width, y: cgPoint.y / height)
        normalizedPoint = previewLayer.layerPointConverted(fromCaptureDevicePoint: normalizedPoint)
        return normalizedPoint
      }
    
    
    private func updatePreviewOverlayViewWithLastFrame() {
        guard let lastFrame = lastFrame,
          let imageBuffer = CMSampleBufferGetImageBuffer(lastFrame)
        else {
          return
        }
        self.updatePreviewOverlayViewWithImageBuffer(imageBuffer)

        previewOverlayView.frame = self.bounds
        annotationOverlayView.frame = self.bounds
        previewLayer.bounds = self.bounds
        self.removeDetectionAnnotations()
    }
    
    private func removeDetectionAnnotations() {
        for annotationView in annotationOverlayView.subviews {
          annotationView.removeFromSuperview()
        }
    }

    private func updatePreviewOverlayViewWithImageBuffer(_ imageBuffer: CVImageBuffer?) {
        guard let imageBuffer = imageBuffer else {
          return
        }
        let orientation: UIImage.Orientation = UIUtilities.imageOrientation(fromDevicePosition: camera == CameraType.Front ? .front : .back)
        let image = UIUtilities.createUIImage(from: imageBuffer, orientation: orientation)
        previewOverlayView.image = image
      }
}

extension CameraView: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds
        lastFrame = sampleBuffer
        switch captureState {
        case .start:
         
           
        
         

            self.captureState = .capturing
            self.time = timestamp
        case .capturing:
            print("Capturing")
            DispatchQueue.main.sync {
                self.updatePreviewOverlayViewWithLastFrame()
            }
            if self.assetWriterInput?.isReadyForMoreMediaData == true {
                let time = CMTime(seconds: timestamp - self.time, preferredTimescale: CMTimeScale(600))
                self.adapter?.append(CMSampleBufferGetImageBuffer(sampleBuffer)!, withPresentationTime: time)
            }
            break
        case .end:
            print("end")

            guard self.assetWriterInput?.isReadyForMoreMediaData == true, self.assetWriter!.status != .failed else {
                break
            }

            assetWriterInput?.markAsFinished()

            DispatchQueue.main.async {
                self.assetWriter?.finishWriting {
                    [weak self] in
                    self?.captureState = .idle
                    self?.assetWriter = nil
                    self?.assetWriterInput = nil
                    print("finish writing")

                }
            }
            
            print("Finish end")


        default:
            guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                print("Failed to get image buffer from sample buffer.")
                return
            }

            let orientation = UIUtilities.imageOrientation(
                fromDevicePosition: camera == CameraType.Front ? .front : .back
            )


            guard let inputImage = MLImage(sampleBuffer: sampleBuffer) else {
              print("Failed to create MLImage from sample buffer.")
              return
            }
            inputImage.orientation = orientation

            
            let imageWidth = CGFloat(CVPixelBufferGetWidth(imageBuffer))
            let imageHeight = CGFloat(CVPixelBufferGetHeight(imageBuffer))

            detectPose(in: inputImage, width: imageWidth, height: imageHeight)
        }

        

    }
}


/// Defines UI-related utilitiy methods for vision detection.
public class UIUtilities {
    
  public static func addLineSegment(
    fromPoint: CGPoint, toPoint: CGPoint, inView: UIView, color: UIColor, width: CGFloat
  ) {
    let path = UIBezierPath()
    path.move(to: fromPoint)
    path.addLine(to: toPoint)
    let lineLayer = CAShapeLayer()
    lineLayer.path = path.cgPath
    lineLayer.strokeColor = color.cgColor
    lineLayer.fillColor = nil
    lineLayer.opacity = 1.0
    lineLayer.lineWidth = width
    let lineView = UIView()
    lineView.layer.addSublayer(lineLayer)
    lineView.isAccessibilityElement = true
    lineView.accessibilityIdentifier = Constants.lineViewIdentifier
    inView.addSubview(lineView)
  }
 
  public static func imageOrientation(
    fromDevicePosition devicePosition: AVCaptureDevice.Position = .back
  ) -> UIImage.Orientation {
    var deviceOrientation = UIDevice.current.orientation
    if deviceOrientation == .faceDown || deviceOrientation == .faceUp
      || deviceOrientation
        == .unknown
    {
      deviceOrientation = currentUIOrientation()
    }
    switch deviceOrientation {
    case .portrait:
      return devicePosition == .front ? .leftMirrored : .right
    case .landscapeLeft:
      return devicePosition == .front ? .downMirrored : .up
    case .portraitUpsideDown:
      return devicePosition == .front ? .rightMirrored : .left
    case .landscapeRight:
      return devicePosition == .front ? .upMirrored : .down
    case .faceDown, .faceUp, .unknown:
      return .up
    @unknown default:
      fatalError()
    }
  }
    
   


  /// Converts an image buffer to a `UIImage`.
  ///
  /// @param imageBuffer The image buffer which should be converted.
  /// @param orientation The orientation already applied to the image.
  /// @return A new `UIImage` instance.
  public static func createUIImage(
    from imageBuffer: CVImageBuffer,
    orientation: UIImage.Orientation
  ) -> UIImage? {
    let ciImage = CIImage(cvPixelBuffer: imageBuffer)
    let context = CIContext(options: nil)
    guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
    return UIImage(cgImage: cgImage, scale: Constants.originalScale, orientation: orientation)
  }

  /// Converts a `UIImage` to an image buffer.
  ///
  /// @param image The `UIImage` which should be converted.
  /// @return The image buffer. Callers own the returned buffer and are responsible for releasing it
  ///     when it is no longer needed. Additionally, the image orientation will not be accounted for
  ///     in the returned buffer, so callers must keep track of the orientation separately.
  public static func createImageBuffer(from image: UIImage) -> CVImageBuffer? {
    guard let cgImage = image.cgImage else { return nil }
    let width = cgImage.width
    let height = cgImage.height

    var buffer: CVPixelBuffer? = nil
    CVPixelBufferCreate(
      kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, nil,
      &buffer)
    guard let imageBuffer = buffer else { return nil }

    let flags = CVPixelBufferLockFlags(rawValue: 0)
    CVPixelBufferLockBaseAddress(imageBuffer, flags)
    let baseAddress = CVPixelBufferGetBaseAddress(imageBuffer)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer)
    let context = CGContext(
      data: baseAddress, width: width, height: height, bitsPerComponent: 8,
      bytesPerRow: bytesPerRow, space: colorSpace,
      bitmapInfo: (CGImageAlphaInfo.premultipliedFirst.rawValue
        | CGBitmapInfo.byteOrder32Little.rawValue))

    if let context = context {
      let rect = CGRect.init(x: 0, y: 0, width: width, height: height)
      context.draw(cgImage, in: rect)
      CVPixelBufferUnlockBaseAddress(imageBuffer, flags)
      return imageBuffer
    } else {
      CVPixelBufferUnlockBaseAddress(imageBuffer, flags)
      return nil
    }
  }
    
    public static func createPoseOverlayViewGreen(
      forPose pose: Pose, inViewWithBounds bounds: CGRect, lineWidth: CGFloat, dotRadius: CGFloat,
      positionTransformationClosure: (VisionPoint) -> CGPoint
    ) -> UIView {
        let overlayView = UIView(frame: bounds)

     

        let nearZColor = UIColor.red
        let farZColor = UIColor.systemBlue
          
        let nose: PoseLandmark = pose.landmark(ofType: PoseLandmarkType.nose)
         
          let leftEar: PoseLandmark = pose.landmark(ofType: PoseLandmarkType.leftEar)
          let rightEar: PoseLandmark = pose.landmark(ofType: PoseLandmarkType.rightEar)
         

          let leftShoulder: PoseLandmark = pose.landmark(ofType: PoseLandmarkType.leftShoulder)
          let rightShoulder: PoseLandmark = pose.landmark(ofType: PoseLandmarkType.rightShoulder)
          let leftElbow: PoseLandmark = pose.landmark(ofType: PoseLandmarkType.leftElbow)
          let rightElbow: PoseLandmark = pose.landmark(ofType: PoseLandmarkType.rightElbow)
          let leftWrist: PoseLandmark = pose.landmark(ofType: PoseLandmarkType.leftWrist)
          let rightWrist: PoseLandmark = pose.landmark(ofType: PoseLandmarkType.rightWrist)
          let leftHip: PoseLandmark = pose.landmark(ofType: PoseLandmarkType.leftHip)
          let rightHip: PoseLandmark = pose.landmark(ofType: PoseLandmarkType.rightHip)
          let leftKnee: PoseLandmark = pose.landmark(ofType: PoseLandmarkType.leftKnee)
          let rightKnee: PoseLandmark = pose.landmark(ofType: PoseLandmarkType.rightKnee)
          let leftAnkle: PoseLandmark = pose.landmark(ofType: PoseLandmarkType.leftAnkle)
          let rightAnkle: PoseLandmark = pose.landmark(ofType: PoseLandmarkType.rightAnkle)

          let leftPinky: PoseLandmark = pose.landmark(ofType: PoseLandmarkType.leftPinkyFinger)
          let rightPinky: PoseLandmark = pose.landmark(ofType: PoseLandmarkType.rightPinkyFinger)
          let leftIndex: PoseLandmark = pose.landmark(ofType: PoseLandmarkType.leftIndexFinger)
          let rightIndex: PoseLandmark = pose.landmark(ofType: PoseLandmarkType.rightIndexFinger)
          let leftHeel: PoseLandmark = pose.landmark(ofType: PoseLandmarkType.leftHeel)
          let rightHeel: PoseLandmark = pose.landmark(ofType: PoseLandmarkType.rightHeel)
          let leftFootIndex: PoseLandmark = pose.landmark(ofType: PoseLandmarkType.leftToe)
          let rightFootIndex: PoseLandmark = pose.landmark(ofType: PoseLandmarkType.rightToe)

          var start: CGPoint!
          var end: CGPoint!
          var med: CGPoint!
          var bottomNeckX, bottomNeckY, upNeckX, upNeckY, headX, headY, rightHandX, rightHandY, leftHandX, leftHandY, chestX, chestY, centralX, centralY, rightAnkleX, rightAnkleY, leftAnkleX, leftAnkleY, rightUpFootX, rightUpFootY, leftUpFootX, leftUpFootY, tx,ty: Double
          
          
          start = positionTransformationClosure(leftShoulder.position)
          end  = positionTransformationClosure(rightShoulder.position)
          bottomNeckX = (start.x + end.x) / 2
          bottomNeckY = (start.y + end.y) / 2
          start = positionTransformationClosure(leftEar.position)
          end = positionTransformationClosure(rightEar.position)
          tx = (start.x + end.x) / 2
          ty = (start.y + end.y) / 2
          bottomNeckX = Double(bottomNeckX + (tx - bottomNeckX) * 0.2)
          bottomNeckY =  Double(bottomNeckY + (ty - bottomNeckY) * 0.2)
          upNeckX = Double(bottomNeckX + (tx - bottomNeckX) * 0.5)
          upNeckY = Double(bottomNeckY + (ty - bottomNeckY) * 0.5)
          headX = Double(upNeckX + (tx - upNeckX) * 2.2)
          headY = Double(upNeckY + (ty - upNeckY) * 2.2)
          start = positionTransformationClosure(leftAnkle.position)
          end = positionTransformationClosure(leftHeel.position)
          leftAnkleX = (start.x + end.x) / 2
          leftAnkleY = (start.y + end.y) / 2
          start = positionTransformationClosure(rightAnkle.position)
          end = positionTransformationClosure(rightHeel.position)
          rightAnkleX = (start.x + end.x) / 2
          rightAnkleY = (start.y + end.y) / 2
          start = positionTransformationClosure(leftFootIndex.position)
          end = positionTransformationClosure(leftHeel.position)
          leftUpFootX = (start.x + end.x) / 2
          leftUpFootY = (start.y + end.y) / 2
          start = positionTransformationClosure(rightFootIndex.position)
          end = positionTransformationClosure(rightHeel.position)
          rightUpFootX = (start.x + end.x) / 2
          rightUpFootY = (start.y + end.y) / 2
          start = positionTransformationClosure(leftPinky.position)
          end = positionTransformationClosure(leftIndex.position)
          tx = (start.x + end.x) / 2
          ty = (start.y + end.y) / 2
          med = positionTransformationClosure(leftWrist.position)
          leftHandX = tx + (tx - med.x)
          leftHandY = ty + (ty - med.y)
          start = positionTransformationClosure(rightPinky.position)
          end = positionTransformationClosure(rightIndex.position)
          tx = (start.x + end.x) / 2
          ty = (start.y + end.y) / 2
          med = positionTransformationClosure(rightWrist.position)
          rightHandX = tx + (tx - med.x)
          rightHandY = ty + (ty - med.y)
          start = positionTransformationClosure(rightHip.position)
          end = positionTransformationClosure(leftHip.position)
          tx = (start.x + end.x) / 2
          ty = (start.y + end.y) / 2
          centralX = Double(tx + (bottomNeckX - tx) * 0.25)
          centralY = Double(ty + (bottomNeckY - ty) * 0.25)
          chestX = Double(tx + (bottomNeckX - tx) * 0.62)
          chestY = Double(ty + (bottomNeckY - ty) * 0.62)

         
          
          
          let bottomNeck = CGPoint(x: bottomNeckX, y: bottomNeckY)
          let upNeck = CGPoint(x: upNeckX, y: upNeckY)
          let head: CGPoint = CGPoint(x: headX, y: headY)
          let leftAnkleNew: CGPoint = CGPoint(x: leftAnkleX, y: leftAnkleY)
          let rightAnkleNew: CGPoint = CGPoint(x: rightAnkleX, y: rightAnkleY)
          let leftUpFoot: CGPoint = CGPoint(x: leftUpFootX, y: leftUpFootY)
          let rightUpFoot: CGPoint = CGPoint(x: rightUpFootX, y: rightUpFootY)
          let leftHand: CGPoint = CGPoint(x: leftHandX, y: leftHandY)
          let rightHand: CGPoint = CGPoint(x: rightHandX, y: rightHandY)
          let central: CGPoint = CGPoint(x: centralX, y: centralY)
          let chest: CGPoint = CGPoint(x: chestX, y: chestY)

        UIUtilities.addLineSegment(fromPoint: positionTransformationClosure(leftHip.position), toPoint: positionTransformationClosure(rightHip.position), inView: overlayView, color: farZColor, width: lineWidth)
        UIUtilities.addLineSegment(fromPoint: positionTransformationClosure(leftShoulder.position), toPoint: positionTransformationClosure(leftElbow.position), inView: overlayView, color: farZColor, width: lineWidth)
        UIUtilities.addLineSegment(fromPoint: positionTransformationClosure(leftElbow.position), toPoint: positionTransformationClosure(leftWrist.position), inView: overlayView, color: farZColor, width: lineWidth)
        UIUtilities.addLineSegment(fromPoint: positionTransformationClosure(leftHip.position), toPoint: positionTransformationClosure(leftKnee.position), inView: overlayView, color: farZColor, width: lineWidth)
        UIUtilities.addLineSegment(fromPoint: positionTransformationClosure(rightShoulder.position), toPoint: positionTransformationClosure(rightElbow.position), inView: overlayView, color: farZColor, width: lineWidth)
        UIUtilities.addLineSegment(fromPoint: positionTransformationClosure(rightElbow.position), toPoint: positionTransformationClosure(rightWrist.position), inView: overlayView, color: farZColor, width: lineWidth)
        UIUtilities.addLineSegment(fromPoint: positionTransformationClosure(rightHip.position), toPoint: positionTransformationClosure(rightKnee.position), inView: overlayView, color: farZColor, width: lineWidth)
        
        UIUtilities.addLineSegment(fromPoint: head, toPoint: positionTransformationClosure(nose.position), inView: overlayView, color: farZColor, width: lineWidth)
        UIUtilities.addLineSegment(fromPoint: positionTransformationClosure(nose.position), toPoint: upNeck, inView: overlayView, color: farZColor, width: lineWidth)
        UIUtilities.addLineSegment(fromPoint: head, toPoint: upNeck, inView: overlayView, color: farZColor, width: lineWidth)
        UIUtilities.addLineSegment(fromPoint: upNeck, toPoint: bottomNeck, inView: overlayView, color: farZColor, width: lineWidth)
        UIUtilities.addLineSegment(fromPoint: bottomNeck, toPoint: positionTransformationClosure(leftShoulder.position), inView: overlayView, color: farZColor, width: lineWidth)
        UIUtilities.addLineSegment(fromPoint: bottomNeck, toPoint: positionTransformationClosure(rightShoulder.position), inView: overlayView, color: farZColor, width: lineWidth)
        UIUtilities.addLineSegment(fromPoint: positionTransformationClosure(leftShoulder.position), toPoint: chest, inView: overlayView, color: farZColor, width: lineWidth)
        UIUtilities.addLineSegment(fromPoint: positionTransformationClosure(rightShoulder.position), toPoint: chest, inView: overlayView, color: farZColor, width: lineWidth)
        UIUtilities.addLineSegment(fromPoint: chest, toPoint: central, inView: overlayView, color: farZColor, width: lineWidth)
        UIUtilities.addLineSegment(fromPoint: central, toPoint: positionTransformationClosure(leftHip.position), inView: overlayView, color: farZColor, width: lineWidth)
        UIUtilities.addLineSegment(fromPoint: central, toPoint: positionTransformationClosure(rightHip.position), inView: overlayView, color: farZColor, width: lineWidth)
        UIUtilities.addLineSegment(fromPoint: positionTransformationClosure(leftWrist.position), toPoint: leftHand, inView: overlayView, color: farZColor, width: lineWidth)
        UIUtilities.addLineSegment(fromPoint: positionTransformationClosure(rightWrist.position), toPoint: rightHand, inView: overlayView, color: farZColor, width: lineWidth)
        UIUtilities.addLineSegment(fromPoint: positionTransformationClosure(leftKnee.position), toPoint:leftAnkleNew, inView: overlayView, color: farZColor, width: lineWidth)
        UIUtilities.addLineSegment(fromPoint: positionTransformationClosure(rightKnee.position), toPoint: rightAnkleNew, inView: overlayView, color: farZColor, width: lineWidth)
        UIUtilities.addLineSegment(fromPoint: leftAnkleNew, toPoint: leftUpFoot, inView: overlayView, color: farZColor, width: lineWidth)
        UIUtilities.addLineSegment(fromPoint: rightAnkleNew, toPoint: rightUpFoot, inView: overlayView, color: farZColor, width: lineWidth)
        UIUtilities.addLineSegment(fromPoint: positionTransformationClosure(leftFootIndex.position), toPoint: leftUpFoot, inView: overlayView, color: farZColor, width: lineWidth)
        UIUtilities.addLineSegment(fromPoint: positionTransformationClosure(rightFootIndex.position), toPoint: rightUpFoot, inView: overlayView, color: farZColor, width: lineWidth)
          
        return overlayView
    }

   
   
  /// Returns a color interpolated between to other colors.
  ///
  /// - Parameters:
  ///   - fromColor: The start color of the interpolation.
  ///   - toColor: The end color of the interpolation.
  ///   - ratio: The ratio in range [0, 1] by which the colors should be interpolated. Passing 0
  ///         results in `fromColor` and passing 1 results in `toColor`, whereas passing 0.5 results
  ///         in a color that is half-way between `fromColor` and `startColor`. Values are clamped
  ///         between 0 and 1.
  /// - Returns: The interpolated color.
  private static func interpolatedColor(
    fromColor: UIColor, toColor: UIColor, ratio: CGFloat
  ) -> UIColor {
    var fromR: CGFloat = 0
    var fromG: CGFloat = 0
    var fromB: CGFloat = 0
    var fromA: CGFloat = 0
    fromColor.getRed(&fromR, green: &fromG, blue: &fromB, alpha: &fromA)

    var toR: CGFloat = 0
    var toG: CGFloat = 0
    var toB: CGFloat = 0
    var toA: CGFloat = 0
    toColor.getRed(&toR, green: &toG, blue: &toB, alpha: &toA)

    let clampedRatio = max(0.0, min(ratio, 1.0))

    let interpolatedR = fromR + (toR - fromR) * clampedRatio
    let interpolatedG = fromG + (toG - fromG) * clampedRatio
    let interpolatedB = fromB + (toB - fromB) * clampedRatio
    let interpolatedA = fromA + (toA - fromA) * clampedRatio

    return UIColor(
      red: interpolatedR, green: interpolatedG, blue: interpolatedB, alpha: interpolatedA)
  }

  /// Returns the distance between two 3D points.
  ///
  /// - Parameters:
  ///   - fromPoint: The starting point.
  ///   - endPoint: The end point.
  /// - Returns: The distance.
  private static func distance(fromPoint: Vision3DPoint, toPoint: Vision3DPoint) -> CGFloat {
    let xDiff = fromPoint.x - toPoint.x
    let yDiff = fromPoint.y - toPoint.y
    let zDiff = fromPoint.z - toPoint.z
    return CGFloat(sqrt(xDiff * xDiff + yDiff * yDiff + zDiff * zDiff))
  }

  // MARK: - Private

  /// Returns the minimum subset of all connected pose landmarks. Each key represents a start
  /// landmark, and each value in the key's value array represents an end landmark which is
  /// connected to the start landmark. These connections may be used for visualizing the landmark
  /// positions on a pose object.
  private static func poseConnections() -> [PoseLandmarkType: [PoseLandmarkType]] {
    struct PoseConnectionsHolder {
      static var connections: [PoseLandmarkType: [PoseLandmarkType]] = [
        PoseLandmarkType.leftEar: [PoseLandmarkType.leftEyeOuter],
        PoseLandmarkType.leftEyeOuter: [PoseLandmarkType.leftEye],
        PoseLandmarkType.leftEye: [PoseLandmarkType.leftEyeInner],
        PoseLandmarkType.leftEyeInner: [PoseLandmarkType.nose],
        PoseLandmarkType.nose: [PoseLandmarkType.rightEyeInner],
        PoseLandmarkType.rightEyeInner: [PoseLandmarkType.rightEye],
        PoseLandmarkType.rightEye: [PoseLandmarkType.rightEyeOuter],
        PoseLandmarkType.rightEyeOuter: [PoseLandmarkType.rightEar],
        PoseLandmarkType.mouthLeft: [PoseLandmarkType.mouthRight],
        PoseLandmarkType.leftShoulder: [
          PoseLandmarkType.rightShoulder,
          PoseLandmarkType.leftHip,
        ],
        PoseLandmarkType.rightShoulder: [
          PoseLandmarkType.rightHip,
          PoseLandmarkType.rightElbow,
        ],
        PoseLandmarkType.rightWrist: [
          PoseLandmarkType.rightElbow,
          PoseLandmarkType.rightThumb,
          PoseLandmarkType.rightIndexFinger,
          PoseLandmarkType.rightPinkyFinger,
        ],
        PoseLandmarkType.leftHip: [PoseLandmarkType.rightHip, PoseLandmarkType.leftKnee],
        PoseLandmarkType.rightHip: [PoseLandmarkType.rightKnee],
        PoseLandmarkType.rightKnee: [PoseLandmarkType.rightAnkle],
        PoseLandmarkType.leftKnee: [PoseLandmarkType.leftAnkle],
        PoseLandmarkType.leftElbow: [PoseLandmarkType.leftShoulder],
        PoseLandmarkType.leftWrist: [
          PoseLandmarkType.leftElbow, PoseLandmarkType.leftThumb,
          PoseLandmarkType.leftIndexFinger,
          PoseLandmarkType.leftPinkyFinger,
        ],
        PoseLandmarkType.leftAnkle: [PoseLandmarkType.leftHeel, PoseLandmarkType.leftToe],
        PoseLandmarkType.rightAnkle: [PoseLandmarkType.rightHeel, PoseLandmarkType.rightToe],
        PoseLandmarkType.rightHeel: [PoseLandmarkType.rightToe],
        PoseLandmarkType.leftHeel: [PoseLandmarkType.leftToe],
        PoseLandmarkType.rightIndexFinger: [PoseLandmarkType.rightPinkyFinger],
        PoseLandmarkType.leftIndexFinger: [PoseLandmarkType.leftPinkyFinger],
      ]
    }
    return PoseConnectionsHolder.connections
  }

  private static func currentUIOrientation() -> UIDeviceOrientation {
    let deviceOrientation = { () -> UIDeviceOrientation in
      switch UIApplication.shared.statusBarOrientation {
      case .landscapeLeft:
        return .landscapeRight
      case .landscapeRight:
        return .landscapeLeft
      case .portraitUpsideDown:
        return .portraitUpsideDown
      case .portrait, .unknown:
        return .portrait
      @unknown default:
        fatalError()
      }
    }
    guard Thread.isMainThread else {
      var currentOrientation: UIDeviceOrientation = .portrait
      DispatchQueue.main.sync {
        currentOrientation = deviceOrientation()
      }
      return currentOrientation
    }
    return deviceOrientation()
  }
}

// MARK: - Constants

private enum Constants {
  static let circleViewAlpha: CGFloat = 0.7
  static let rectangleViewAlpha: CGFloat = 0.3
  static let shapeViewAlpha: CGFloat = 0.3
  static let rectangleViewCornerRadius: CGFloat = 10.0
  static let maxColorComponentValue: CGFloat = 255.0
  static let originalScale: CGFloat = 1.0
  static let bgraBytesPerPixel = 4
  static let circleViewIdentifier = "MLKit Circle View"
  static let lineViewIdentifier = "MLKit Line View"
  static let rectangleViewIdentifier = "MLKit Rectangle View"
}

// MARK: - Extension

extension CGRect {
  /// Returns a `Bool` indicating whether the rectangle's values are valid`.
  func isValid() -> Bool {
    return
      !(origin.x.isNaN || origin.y.isNaN || width.isNaN || height.isNaN || width < 0 || height < 0)
  }
}
