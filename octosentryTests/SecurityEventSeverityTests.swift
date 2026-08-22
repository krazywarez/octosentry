//
//  SecurityEventSeverityTests.swift
//  octosentryTests
//

import Foundation
import Testing
@testable import octosentry

struct SecurityEventSeverityTests {

    @Test func ordersLowToCritical() {
        #expect(SecurityEventSeverity.low < .medium)
        #expect(SecurityEventSeverity.medium < .high)
        #expect(SecurityEventSeverity.high < .critical)
        #expect(SecurityEventSeverity.critical > .low)
    }

    @Test func sortsAscendingByRawValue() {
        let sorted = SecurityEventSeverity.allCases.shuffled().sorted()
        #expect(sorted == [.low, .medium, .high, .critical])
    }

    // The minimum-severity filter is a `>=` comparison, so a threshold of
    // .high must admit exactly high and critical.
    @Test func thresholdComparisonAdmitsAtOrAboveOnly() {
        let admitted = SecurityEventSeverity.allCases.filter { $0 >= .high }
        #expect(admitted == [.high, .critical])
    }

    @Test func allCasesIsDeclarationOrder() {
        #expect(SecurityEventSeverity.allCases == [.low, .medium, .high, .critical])
    }

    // Raw values are written into state.json, so they are a file format.
    @Test func rawValuesAreStable() {
        #expect(SecurityEventSeverity.low.rawValue == 0)
        #expect(SecurityEventSeverity.medium.rawValue == 1)
        #expect(SecurityEventSeverity.high.rawValue == 2)
        #expect(SecurityEventSeverity.critical.rawValue == 3)
    }

    @Test func roundTripsThroughCodable() throws {
        for severity in SecurityEventSeverity.allCases {
            let data = try JSONEncoder().encode(severity)
            #expect(try JSONDecoder().decode(SecurityEventSeverity.self, from: data) == severity)
        }
    }

    @Test func hasADisplayNameForEveryCase() {
        #expect(SecurityEventSeverity.allCases.allSatisfy { !$0.displayName.isEmpty })
    }
}
