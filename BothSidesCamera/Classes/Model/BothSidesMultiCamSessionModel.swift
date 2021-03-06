//
//  BothSidesMultiCamSessionModel.swift
//  BothSidesCamera
//
//  Created by 永田大祐 on 2019/11/18.
//  Copyright © 2019 永田大祐. All rights reserved.
//

import UIKit
import Photos
import AVFoundation

final class BothSidesMultiCamSessionModel: NSObject, AVCaptureAudioDataOutputSampleBufferDelegate,
AVCaptureVideoDataOutputSampleBufferDelegate  {

    var normalizedPipFrame                       = CGRect.zero
    var currentPiPSampleBuffer                   : CMSampleBuffer?
    var videoMixer                               : BothSidesMixer?
    var movieRecorder                            : BothSidesRecorder?
    var backCameraVideoDataOutput                : AVCaptureVideoDataOutput?
    var pipDevicePosition                        : AVCaptureDevice.Position = .front

    var transFormCheck                           = CGAffineTransform()
    var bothObservarModel                        = IsRunningModel()
    var sameRatioModel                           = SameRatioModel()
    var orientationModel                         = InterfaceOrientation()
    let vm                                       = BothObserveViewModel()

    private var videoTrackSourceFormatDescription: CMFormatDescription?
    private var frontCameraVideoDataOutput       : AVCaptureVideoDataOutput?
    private var backMicrophoneAudioDataOutput    : AVCaptureAudioDataOutput?
    private var frontMicrophoneAudioDataOutput   : AVCaptureAudioDataOutput?
    private var callBack                         = { () -> Void in }

    override init() {
        videoMixer = BothSidesMixer()
    }

    func dataOutput(backdataOutput : AVCaptureVideoDataOutput? = nil,
                    frontDataOutput: AVCaptureVideoDataOutput? = nil,
                    backicrophoneDataOutput: AVCaptureAudioDataOutput? = nil,
                    fronticrophoneDataOutput: AVCaptureAudioDataOutput? = nil) {
        reset()
        backCameraVideoDataOutput = backdataOutput
        frontCameraVideoDataOutput = frontDataOutput
        backMicrophoneAudioDataOutput = backicrophoneDataOutput
        frontMicrophoneAudioDataOutput = fronticrophoneDataOutput

    }

    func recorderSet(bind: () -> ()) {
        movieRecorder = BothSidesRecorder(audioSettings:  createAudioSettings(), videoSettings:  createVideoSettings(),videoTransform: createVideoTransform())
        bind()
    }

    func sameRatioFlg() {
        vm.sameValueSet(sameRatioModel)
        vm.observe(for: vm.sameRatioModel ?? BothObservable()) { v in
            self.sameRatioModel.sameRatio = v.sameRatio
        }
    }

    private func reset() {
        backCameraVideoDataOutput = nil
        frontCameraVideoDataOutput = nil
        backMicrophoneAudioDataOutput = nil
        frontMicrophoneAudioDataOutput = nil
    }

    private func processPiPSampleBuffer(_ pipSampleBuffer: CMSampleBuffer) {
        currentPiPSampleBuffer = pipSampleBuffer
    }

    private func processFullScreenSampleBuffer(_ fullScreenSampleBuffer: CMSampleBuffer, _ sameRatio: Bool) {
        guard let fullScreenPixelBuffer = CMSampleBufferGetImageBuffer(fullScreenSampleBuffer),
            let formatDescription = CMSampleBufferGetFormatDescription(fullScreenSampleBuffer) else {
                print("AVCaptureMultiCamSessionModel_formatDescription")
                return
        }

        guard let pipSampleBuffer = currentPiPSampleBuffer,
            let pipPixelBuffer = CMSampleBufferGetImageBuffer(pipSampleBuffer) else {
                print("AVCaptureMultiCamSessionModel_pipPixelBuffer")
                return
        }

        videoMixer?.prepare(with: formatDescription, outputRetainedBufferCountHint: 3)
        videoMixer?.pipFrame = normalizedPipFrame
        guard let mixedPixelBuffer = videoMixer?.mix(fullScreenPixelBuffer: fullScreenPixelBuffer,
                                                    pipPixelBuffer: pipPixelBuffer,
                                                    sameRatio) else {
                                                        print("AVCaptureMultiCamSessionModel_mixedPixelBuffer")
                                                        return
        }
        if let recorder = movieRecorder {
            guard let finalVideoSampleBuffer = createVideoSampleBufferWithPixelBuffer(mixedPixelBuffer,
                                                                                           presentationTime: CMSampleBufferGetPresentationTimeStamp(fullScreenSampleBuffer)) else {
                                                                                            print("AVCaptureMultiCamSessionModel_finalVideoSampleBuffer")
                                                                                            return
            }
            recorder.recordVideo(sampleBuffer: finalVideoSampleBuffer)
        }
    }

    private func createVideoSampleBufferWithPixelBuffer(_ pixelBuffer: CVPixelBuffer, presentationTime: CMTime) -> CMSampleBuffer? {
        guard let videoTrackSourceFormatDescription = videoTrackSourceFormatDescription else {
            print("BothSidesMultiCamSessionModel_createVideoSampleBufferWithPixelBuffer")
            return nil
        }
        var sampleBuffer: CMSampleBuffer?
        var timingInfo = CMSampleTimingInfo(duration: .invalid, presentationTimeStamp: presentationTime, decodeTimeStamp: .invalid)
        let err = CMSampleBufferCreateForImageBuffer(allocator: kCFAllocatorDefault,
                                                     imageBuffer: pixelBuffer,
                                                     dataReady: true,
                                                     makeDataReadyCallback: nil,
                                                     refcon: nil,
                                                     formatDescription: videoTrackSourceFormatDescription,
                                                     sampleTiming: &timingInfo,
                                                     sampleBufferOut: &sampleBuffer)

        if sampleBuffer == nil { print("sampleBuffer: \(err))") }
        return sampleBuffer
    }
}

extension BothSidesMultiCamSessionModel {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {

        if let videoDataOutput = output as? AVCaptureVideoDataOutput {
            processVideoSampleBuffer(sampleBuffer, fromOutput: videoDataOutput)
        } else if let audioDataOutput = output as? AVCaptureAudioDataOutput {
            processsAudioSampleBuffer(sampleBuffer, fromOutput: audioDataOutput)
        }
    }

    private func processVideoSampleBuffer(_ sampleBuffer: CMSampleBuffer, fromOutput videoDataOutput: AVCaptureVideoDataOutput) {

        if videoTrackSourceFormatDescription == nil { videoTrackSourceFormatDescription = CMSampleBufferGetFormatDescription( sampleBuffer ) }

        var fullScreenSampleBuffer: CMSampleBuffer?
        var pipSampleBuffer: CMSampleBuffer?

        switch pipDevicePosition {
        case .back:
            videoDataOutput == backCameraVideoDataOutput  ? pipSampleBuffer = sampleBuffer: nil
            videoDataOutput == frontCameraVideoDataOutput ? fullScreenSampleBuffer = sampleBuffer: nil
        case.front:
            videoDataOutput == backCameraVideoDataOutput  ? fullScreenSampleBuffer = sampleBuffer: nil
            videoDataOutput == frontCameraVideoDataOutput ? pipSampleBuffer = sampleBuffer: nil
        default: break
        }

        if let fullScreenSampleBuffer = fullScreenSampleBuffer { processFullScreenSampleBuffer(fullScreenSampleBuffer, self.sameRatioModel.sameRatio) }

        if let pipSampleBuffer = pipSampleBuffer { processPiPSampleBuffer(pipSampleBuffer) }
    }

    private func processsAudioSampleBuffer(_ sampleBuffer: CMSampleBuffer, fromOutput audioDataOutput: AVCaptureAudioDataOutput) {

        guard (pipDevicePosition == .back && audioDataOutput == backMicrophoneAudioDataOutput) ||
            (pipDevicePosition == .front && audioDataOutput == frontMicrophoneAudioDataOutput) else {
                // 常に通る
                print("PiPVideoMixer_makeTextureFromCVPixelBuffer")
                return
        }

        if let recorder = movieRecorder { recorder.recordAudio(sampleBuffer: sampleBuffer) }
    }
}

extension BothSidesMultiCamSessionModel {

    func recordAction(completion: @escaping() -> Void) {

        vm.observe(for: vm.model ?? BothObservable()) { value in
            if value.isRunning == true {
                self.movieRecorder?.startRecording()
            } else {
                self.movieRecorder?.stopRecording { movieURL in
                    self.saveMovieToPhotoLibrary(movieURL, call: completion )
                }
            }
        }
    }

    private func saveMovieToPhotoLibrary(_ movieURL: URL, call: @escaping () -> Void) {
        PHPhotoLibrary.requestAuthorization { status in
            if status == .authorized {
                PHPhotoLibrary.shared().performChanges({
                    let options = PHAssetResourceCreationOptions()
                    options.shouldMoveFile = true
                    let creationRequest = PHAssetCreationRequest.forAsset()
                    creationRequest.addResource(with: .video, fileURL: movieURL, options: options)
                }, completionHandler: { success, error in
                    if !success {
                        print("\(Bundle.main.applicationName) couldn't save the movie to your photo library: \(String(describing: error))")
                    } else {
                        self.callBack = call
                        self.callBack()
                        if FileManager.default.fileExists(atPath: movieURL.path) {
                            do {
                                try FileManager.default.removeItem(atPath: movieURL.path)
                            } catch {
                                print("Could not remove file at url: \(movieURL)")
                            }
                        }
                    }
                })
            }
        }
    }

    private func createAudioSettings() -> [String: NSObject]? {
        [backMicrophoneAudioDataOutput?.recommendedAudioSettingsForAssetWriter(writingTo: .mov) as? [String: NSObject],
         frontMicrophoneAudioDataOutput?.recommendedAudioSettingsForAssetWriter(writingTo: .mov) as? [String: NSObject]].compactMap{ settings in
            return settings
        }.last
    }

    private func createVideoSettings() -> [String: NSObject]? {
        [backCameraVideoDataOutput?.recommendedVideoSettingsForAssetWriter(writingTo: .mov) as? [String: NSObject],
         frontCameraVideoDataOutput?.recommendedVideoSettingsForAssetWriter(writingTo: .mov) as? [String: NSObject]].compactMap{ settings in
            return settings
        }.last
    }

    private func createVideoTransform() -> CGAffineTransform? {
        guard let backCameraVideoConnection = backCameraVideoDataOutput?.connection(with: .video) else {
            print("AVCaptureMultiCamSessionModel_createVideoTransform")
            return nil
        }
        let deviceOrientation = UIDevice.current.orientation
        let videoOrientation = AVCaptureVideoOrientation(rawValue: deviceOrientation.rawValue) ?? .portraitUpsideDown
        if UIInterfaceOrientation.landscapeRight.rawValue == UIDevice.current.orientation.rawValue  {
            transFormCheck = backCameraVideoConnection.videoOrientationTransform(relativeTo: .landscapeRight)
        } else {
            if UIDevice.current.orientation.isFlat == true {
                transFormCheck = transFormCheck == CGAffineTransform(rotationAngle: CGFloat.pi/180 * -0.01) ?
                    backCameraVideoConnection.videoOrientationTransform(relativeTo: .portrait) :
                    backCameraVideoConnection.videoOrientationTransform(relativeTo: .landscapeLeft)
            } else {
                transFormCheck = backCameraVideoConnection.videoOrientationTransform(relativeTo: videoOrientation)
            }
        }
        return transFormCheck
    }
}

// Save PhotosAlbum
extension BothSidesMultiCamSessionModel {

    func screenShot(call: @escaping () -> Void, orientation: UIInterfaceOrientation) {
        movieRecorder?.screenShot { movieURL in

            let orientationFlg = orientation.isPortrait == true ? UIImage.Orientation.up : UIImage.Orientation.right

            let asset = AVURLAsset(url: movieURL, options: nil)
            let lastFrameSeconds: Float64 = CMTimeGetSeconds(asset.duration)
            let capturingTime: CMTime = CMTimeMakeWithSeconds(lastFrameSeconds * asset.duration.seconds, preferredTimescale: 1)
            let imageGenerator: AVAssetImageGenerator = AVAssetImageGenerator(asset: asset)
            do {
                let cgImage: CGImage = try imageGenerator.copyCGImage(at: capturingTime, actualTime: nil)
                let uiImage = UIImage(cgImage: cgImage, scale: 0, orientation: orientationFlg)
                //Save it to the camera roll
                UIImageWriteToSavedPhotosAlbum(uiImage, nil, nil, nil)
                call()
            } catch {
                print("not save it to the camera roll,\(error)")
            }
        }
    }
}
