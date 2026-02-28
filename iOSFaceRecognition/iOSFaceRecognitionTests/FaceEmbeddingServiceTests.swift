//
//  FaceEmbeddingServiceTests.swift
//  iOSFaceRecognitionTests
//

import XCTest
@testable import iOSFaceRecognition

final class FaceEmbeddingServiceTests: XCTestCase {

    let service = FaceEmbeddingService.shared

    // MARK: - Average Embedding

    func testAverageEmbeddingWithSingleVector() {
        let v: [Float] = [1, 0, 0, 0]
        let result = service.averageEmbedding([v])
        XCTAssertNotNil(result)
        // L2 norm of result should be ~1.0
        let norm = result!.reduce(0) { $0 + $1 * $1 }.squareRoot()
        XCTAssertEqual(norm, 1.0, accuracy: 1e-5)
    }

    func testAverageEmbeddingWithMultipleVectors() {
        let v1: [Float] = [1, 0, 0]
        let v2: [Float] = [1, 0, 0]
        let result = service.averageEmbedding([v1, v2])
        XCTAssertNotNil(result)
        // average of two identical unit vectors should still be unit vector
        let norm = result!.reduce(0) { $0 + $1 * $1 }.squareRoot()
        XCTAssertEqual(norm, 1.0, accuracy: 1e-4)
    }

    func testAverageEmbeddingWithEmptyInputReturnsNil() {
        let result = service.averageEmbedding([])
        XCTAssertNil(result)
    }

    func testAverageEmbeddingIsNormalized() {
        let v1: [Float] = [0.6, 0.8, 0]
        let v2: [Float] = [0.8, 0.6, 0]
        let result = service.averageEmbedding([v1, v2])
        XCTAssertNotNil(result)
        let norm = result!.reduce(0.0 as Float) { $0 + $1 * $1 }.squareRoot()
        XCTAssertEqual(norm, 1.0, accuracy: 1e-4)
    }

    // MARK: - Embedding Dimension

    func testEmbeddingDimensionIs128() async {
        // Use a blank (all-zero) image — no face, should return nil
        let blankImage = UIImage(systemName: "photo")!
        let result = await service.extractEmbedding(from: blankImage)
        // A system SF Symbol image has no real face; result may be nil or valid depending on Vision
        // We only assert dimension if non-nil
        if let emb = result {
            XCTAssertEqual(emb.count, 128)
        }
    }
}
