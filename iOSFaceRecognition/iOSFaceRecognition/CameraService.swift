//
//  CameraService.swift
//  iOSFaceRecognition
//

import Foundation
import Combine
import AVFoundation
import UIKit
import Vision

@MainActor
final class CameraService: NSObject, ObservableObject {

    // MARK: - Published State
    @Published var isRunning: Bool = false
    @Published var lastPhoto: UIImage? = nil
    @Published var faceDetected: Bool = false
    @Published var faceObservations: [VNFaceObservation] = []
    @Published var lastError: String? = nil

    /// Increments by 1 each time a blink is detected (open→closed→open transition).
    /// Reset with `resetBlink()` between verification sessions.
    @Published var blinkCount: Int = 0

    /// VNFaceObservation.confidence of the most recent detection frame (0.0–1.0).
    /// Updated every video frame. Sample at capture-button tap time to score registration quality.
    @Published var currentFaceConfidence: Float = 0.0

    // MARK: - AVFoundation
    let session = AVCaptureSession()

    private let photoOutput = AVCapturePhotoOutput()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let queue = DispatchQueue(label: "camera.queue")

    private var isConfigured = false
    private var isStarting = false

    // MARK: - Blink detection state (only accessed from camera.queue)
    // EAR threshold: eye height/width ratio below this = eyes closed
    private let earClosedThreshold: Float = 0.22
    nonisolated(unsafe) private var _eyeWasClosed: Bool = false

    override init() {
        super.init()
        configureIfNeeded()
    }

    // MARK: - Public

    func start() {
        configureIfNeeded()
        guard !session.isRunning else { isRunning = true; return }
        guard !isStarting else { return }
        isStarting = true
        queue.async { [weak self] in
            guard let self else { return }
            self.session.startRunning()
            DispatchQueue.main.async {
                self.isRunning = true
                self.isStarting = false
            }
        }
    }

    func stop() {
        guard session.isRunning else { isRunning = false; return }
        queue.async { [weak self] in
            guard let self else { return }
            self.session.stopRunning()
            DispatchQueue.main.async { self.isRunning = false }
        }
    }

    func capture() {
        if !session.isRunning {
            start()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                self?._captureNow()
            }
            return
        }
        _captureNow()
    }

    /// Resets the blink counter — call before starting a new liveness check.
    func resetBlink() {
        blinkCount = 0
        _eyeWasClosed = false
    }

    // MARK: - Private capture

    private func _captureNow() {
        guard let conn = photoOutput.connection(with: .video), conn.isEnabled else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                guard let self else { return }
                guard let conn2 = self.photoOutput.connection(with: .video), conn2.isEnabled else {
                    self.lastError = "Camera not ready. Try again."
                    return
                }
                self.photoOutput.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
            }
            return
        }
        photoOutput.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
    }

    // MARK: - Configure

    private func configureIfNeeded() {
        guard !isConfigured else { return }
        isConfigured = true
        session.beginConfiguration()
        session.sessionPreset = .photo

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                   for: .video,
                                                   position: .front) else {
            session.commitConfiguration()
            lastError = "Front camera not available."
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: device)
            guard session.canAddInput(input) else {
                session.commitConfiguration()
                lastError = "Cannot add camera input."
                return
            }
            session.addInput(input)
        } catch {
            session.commitConfiguration()
            lastError = "Camera input error: \(error.localizedDescription)"
            return
        }

        if session.canAddOutput(photoOutput) { session.addOutput(photoOutput) }

        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: queue)
        if session.canAddOutput(videoOutput) { session.addOutput(videoOutput) }

        session.commitConfiguration()
    }

    // MARK: - Vision face detection (runs on camera.queue, updates main)

    nonisolated private func detectFace(in pixelBuffer: CVPixelBuffer) {
        let request = VNDetectFaceLandmarksRequest { [weak self] req, _ in
            guard let self else { return }
            let results = (req.results as? [VNFaceObservation]) ?? []
            DispatchQueue.main.async {
                self.faceObservations = results
                self.faceDetected = !results.isEmpty
                self.currentFaceConfidence = results.first.map { Float($0.confidence) } ?? 0.0
            }
            // Blink detection from first face's landmarks
            if let face = results.first, let landmarks = face.landmarks {
                self.updateBlinkDetection(landmarks: landmarks)
            }
        }

        let handler = VNImageRequestHandler(
            cvPixelBuffer: pixelBuffer,
            orientation: .leftMirrored,
            options: [:]
        )
        try? handler.perform([request])
    }

    // MARK: - Blink Detection (nonisolated — runs on camera.queue)

    /// Calculates an Eye Aspect Ratio proxy: height / width of the eye bounding box.
    /// A lower value indicates a more closed eye.
    nonisolated private func eyeOpenness(_ region: VNFaceLandmarkRegion2D) -> Float {
        let count = region.pointCount
        guard count >= 4 else { return 1.0 }
        var minX = Float.infinity, maxX = -Float.infinity
        var minY = Float.infinity, maxY = -Float.infinity
        for i in 0..<count {
            let p = region.normalizedPoints[i]
            // Explicit Float() cast handles both Float and CGFloat SDK variants
            let px = Float(p.x), py = Float(p.y)
            minX = min(minX, px); maxX = max(maxX, px)
            minY = min(minY, py); maxY = max(maxY, py)
        }
        let w = maxX - minX
        let h = maxY - minY
        guard w > 0.001 else { return 1.0 }
        return h / w
    }

    nonisolated private func updateBlinkDetection(landmarks: VNFaceLandmarks2D) {
        guard let leftEye  = landmarks.leftEye,
              let rightEye = landmarks.rightEye else { return }

        let leftEAR  = eyeOpenness(leftEye)
        let rightEAR = eyeOpenness(rightEye)
        let avgEAR   = (leftEAR + rightEAR) / 2.0

        let eyeClosed = avgEAR < earClosedThreshold

        if _eyeWasClosed && !eyeClosed {
            // Eyes just re-opened after being closed → complete blink
            DispatchQueue.main.async { [weak self] in
                self?.blinkCount += 1
            }
        }
        _eyeWasClosed = eyeClosed
    }
}

// MARK: - Video frames

extension CameraService: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(_ output: AVCaptureOutput,
                                   didOutput sampleBuffer: CMSampleBuffer,
                                   from connection: AVCaptureConnection) {
        guard let pb = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        detectFace(in: pb)
    }
}

// MARK: - Photo capture

extension CameraService: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput,
                                 didFinishProcessingPhoto photo: AVCapturePhoto,
                                 error: Error?) {
        if let error {
            DispatchQueue.main.async { [weak self] in self?.lastError = error.localizedDescription }
            return
        }
        guard let data = photo.fileDataRepresentation(),
              let img = UIImage(data: data) else { return }
        DispatchQueue.main.async { [weak self] in self?.lastPhoto = img }
    }
}
