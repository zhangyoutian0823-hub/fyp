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
    @Published var faceObservations: [VNFaceObservation] = []  // NEW: for overlay
    @Published var lastError: String? = nil

    // MARK: - AVFoundation
    let session = AVCaptureSession()

    private let photoOutput = AVCapturePhotoOutput()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let queue = DispatchQueue(label: "camera.queue")

    private var isConfigured = false
    private var isStarting = false

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
            let results = (req.results as? [VNFaceObservation]) ?? []
            DispatchQueue.main.async {
                self?.faceObservations = results
                self?.faceDetected = !results.isEmpty
            }
        }

        let handler = VNImageRequestHandler(
            cvPixelBuffer: pixelBuffer,
            orientation: .leftMirrored,
            options: [:]
        )
        try? handler.perform([request])
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
