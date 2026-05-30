//
//  BECTests.swift
//  BECTests
//
//  Created by YD on 4/25/26.
//

import Testing
import CoreLocation
@testable import BEC

struct BECTests {

    // MARK: - isInManhattan

    @Test func reportedBugCoordinatesNotInManhattan() {
        // 40.70022, -73.99549 is in the East River / Brooklyn side of the Brooklyn Bridge,
        // not Manhattan — this was incorrectly returning true before the polygon fix.
        let location = CLLocation(latitude: 40.70022, longitude: -73.99549)
        #expect(LocationManager.isInManhattan(location) == false)
    }

    @Test func timesSquareIsInManhattan() {
        let location = CLLocation(latitude: 40.7580, longitude: -73.9855)
        #expect(LocationManager.isInManhattan(location) == true)
    }

    @Test func brooklynHeightsNotInManhattan() {
        let location = CLLocation(latitude: 40.6960, longitude: -73.9942)
        #expect(LocationManager.isInManhattan(location) == false)
    }

    @Test func astoriaNotInManhattan() {
        let location = CLLocation(latitude: 40.7721, longitude: -73.9302)
        #expect(LocationManager.isInManhattan(location) == false)
    }

    @Test func inwoodIsInManhattan() {
        let location = CLLocation(latitude: 40.8650, longitude: -73.9260)
        #expect(LocationManager.isInManhattan(location) == true)
    }

}
