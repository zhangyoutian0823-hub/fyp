//
//  CameraService.swift
//  iOSFaceRecognition
//
//  Created by mac on 2026/2/24.
//

import Foundation
import Combine
import AVFoundation
import UIKit
import Vision

@MainActor
final class CameraService: NSObject, ObservableObject {

    // MARK: - SwiftUI states
    @Published var isRunning: Bool = false
    @Published var lastPhoto: UIImage? = nil
    @Published var faceDetected: Bool = false
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

        guard !session.isRunning else {
            isRunning = true
            return
        }
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
        guard session.isRunning else {
            isRunning = false
            return
        }

        queue.async { [weak self] in
            guard let self else { return }
            self.session.stopRunning()
            DispatchQueue.main.async {
                self.isRunning = false
            }
        }
    }

    func capture() {
        // session 没跑就先跑，再延迟拍照，避免 “No active video connection”
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
        // 检查是否有可用 video connection
        guard let conn = photoOutput.connection(with: .video), conn.isEnabled else {
            // 再等一下重试（模拟器/刚启动时常见）
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                guard let self else { return }
                guard let conn2 = self.photoOutput.connection(with: .video), conn2.isEnabled else {
                    self.lastError = "Camera not ready (no active video connection). Try again."
                    return
                }
                let settings = AVCapturePhotoSettings()
                self.photoOutput.capturePhoto(with: settings, delegate: self)
            }
            return
        }

        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    // MARK: - Configure
    private func configureIfNeeded() {
        guard !isConfigured else { return }
        isConfigured = true

        session.beginConfiguration()
        session.sessionPreset = .photo

        // 1) Front camera input
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
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
            lastError = "Failed to create camera input: \(error.localizedDescription)"
            return
        }

        // 2) Photo output
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        } else {
            lastError = "Cannot add photo output."
        }

        // 3) Video output (for face detection)
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: queue)

        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        } else {
            lastError = "Cannot add video output."
        }

        session.commitConfiguration()
    }

    // MARK: - Vision
    private func detectFace(in pixelBuffer: CVPixelBuffer) {
        let request = VNDetectFaceRectanglesRequest { [weak self] req, _ in
            let hasFace = (req.results as? [VNFaceObservation])?.isEmpty == false
            DispatchQueue.main.async {
                self?.faceDetected = hasFace
            }
        }

        let handler = VNImageRequestHandler(
            cvPixelBuffer: pixelBuffer,
            orientation: .leftMirrored,
            options: [:]
        )

        do {
            try handler.perform([request])
        } catch {
            DispatchQueue.main.async { [weak self] in
                self?.lastError = error.localizedDescription
            }
        }
    }
}

// MARK: - Video frames
extension CameraService: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let pb = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        detectFace(in: pb)
    }
}

// MARK: - Photo capture delegate
extension CameraService: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        if let error {
            DispatchQueue.main.async { [weak self] in
                self?.lastError = error.localizedDescription
            }
            return
        }

        guard let data = photo.fileDataRepresentation(),
              let img = UIImage(data: data) else { return }

        DispatchQueue.main.async { [weak self] in
            self?.lastPhoto = img
        }
    }
}
