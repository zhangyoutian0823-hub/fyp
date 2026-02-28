//
//  FaceMatchServiceTests.swift
//  iOSFaceRecognitionTests
//

import XCTest
@testable import iOSFaceRecognition

final class FaceMatchServiceTests: XCTestCase {

    let service = FaceMatchService.shared

    // MARK: - Cosine Similarity

    func testIdenticalVectorsHaveMaxSimilarity() {
        let v: [Float] = [1, 0, 0, 0]
        let sim = service.similarity(v, v)
        XCTAssertEqual(sim, 1.0, accuracy: 1e-5)
    }

    func testOrthogonalVectorsHaveZeroSimilarity() {
        let a: [Float] = [1, 0, 0]
        let b: [Float] = [0, 1, 0]
        let sim = service.similarity(a, b)
        XCTAssertEqual(sim, 0.0, accuracy: 1e-5)
    }

    func testOppositeVectorsHaveMinusSimilarity() {
        let a: [Float] = [1, 0, 0]
        let b: [Float] = [-1, 0, 0]
        let sim = service.similarity(a, b)
        XCTAssertEqual(sim, -1.0, accuracy: 1e-5)
    }

    func testEmptyVectorsReturnZero() {
        XCTAssertEqual(service.similarity([], []), 0.0)
    }

    func testMismatchedLengthsReturnZero() {
        XCTAssertEqual(service.similarity([1, 2], [1, 2, 3]), 0.0)
    }

    // MARK: - Threshold Matching

    func testMatchReturnsTrueAboveThreshold() {
        service.threshold = 0.75
        let a: [Float] = [1, 0, 0]
        // same vector → similarity = 1.0
        XCTAssertTrue(service.match(query: a, against: a))
    }

    func testMatchReturnsFalseBelowThreshold() {
        service.threshold = 0.75
        let a: [Float] = [1, 0, 0]
        let b: [Float] = [0, 1, 0]   // similarity = 0.0
        XCTAssertFalse(service.match(query: a, against: b))
    }

    // MARK: - Percent String

    func testSimilarityPercentFormat() {
        let a: [Float] = [1, 0, 0]
        let pct = service.similarityPercent(a, a)
        XCTAssertEqual(pct, "100%")
    }

    // MARK: - Best Match

    func testBestMatchFindsHighestScore() {
        let query: [Float]  = [1, 0, 0]
        let low: [Float]    = [0, 1, 0]    // sim = 0
        let high: [Float]   = [1, 0, 0]    // sim = 1

        service.threshold = 0.75
        let (matched, score) = service.bestMatch(query: query, candidates: [low, high])
        XCTAssertTrue(matched)
        XCTAssertEqual(score, 1.0, accuracy: 1e-5)
    }

    func testBestMatchWithEmptyCandidates() {
        let (matched, score) = service.bestMatch(query: [1, 0], candidates: [])
        XCTAssertFalse(matched)
        XCTAssertEqual(score, 0.0)
    }
}
