//
//  UpdateStoreTests.swift
//  octosentryTests
//
//  isNewer decides whether anyone ever hears about a release: too strict and
//  updates go unnoticed, too loose and every user is nagged to install what
//  they already have.
//

import Foundation
import Testing
@testable import octosentry

// isNewer is a pure function but inherits the target's MainActor isolation.
@MainActor
struct UpdateStoreTests {

    // MARK: - Ordering

    @Test func aNewerPatchMinorOrMajorIsOffered() {
        #expect(UpdateStore.isNewer("1.1.1", than: "1.1.0"))
        #expect(UpdateStore.isNewer("1.2.0", than: "1.1.9"))
        #expect(UpdateStore.isNewer("2.0.0", than: "1.9.9"))
    }

    @Test func theSameVersionIsNotOffered() {
        #expect(!UpdateStore.isNewer("1.1.1", than: "1.1.1"))
        #expect(!UpdateStore.isNewer("1.0.0", than: "1.0.0"))
    }

    @Test func anOlderReleaseIsNotOffered() {
        #expect(!UpdateStore.isNewer("1.1.0", than: "1.1.1"))
        #expect(!UpdateStore.isNewer("1.0.1", than: "1.1.0"))
        #expect(!UpdateStore.isNewer("0.7.0", than: "1.0.0"))
    }

    // A local build ahead of the latest release must not prompt for the
    // release it already contains.
    @Test func aBundleAheadOfTheLatestReleaseIsNotPrompted() {
        #expect(!UpdateStore.isNewer("1.1", than: "1.1.1"))
    }

    // MARK: - Numeric, not lexical

    // The comparison that a string compare gets wrong: "1.10" sorts before
    // "1.9" as text, and after it as versions.
    @Test func componentsCompareNumericallyNotAsText() {
        #expect(UpdateStore.isNewer("1.10.0", than: "1.9.0"))
        #expect(!UpdateStore.isNewer("1.9.0", than: "1.10.0"))
        #expect(UpdateStore.isNewer("1.1.10", than: "1.1.9"))
    }

    // MARK: - Shapes the tag names actually take

    @Test func missingTrailingComponentsCountAsZero() {
        #expect(!UpdateStore.isNewer("1.1", than: "1.1.0"))
        #expect(!UpdateStore.isNewer("1.1.0", than: "1.1"))
        #expect(UpdateStore.isNewer("1.1.1", than: "1.1"))
    }

    @Test func aLeadingVIsIgnored() {
        #expect(UpdateStore.isNewer("v1.1.1", than: "1.1.0"))
        #expect(!UpdateStore.isNewer("v1.1.1", than: "1.1.1"))
        #expect(UpdateStore.isNewer("v2.0.0", than: "v1.9.9"))
    }

    // Rather than crash or throw on a tag that isn't a version.
    @Test func unparseableComponentsCountAsZero() {
        #expect(!UpdateStore.isNewer("nightly", than: "1.1.1"))
        #expect(UpdateStore.isNewer("1.1.1", than: "nightly"))
    }

    // MARK: - This repo's real tags

    @Test func everyShippedTagIsNewerThanTheOneBefore() {
        let shipped = ["0.1.0", "0.3.0", "0.4.0", "0.5.0", "0.6.0", "0.7.0", "1.0.0", "1.0.1", "1.1", "1.1.1"]

        for (earlier, later) in zip(shipped, shipped.dropFirst()) {
            #expect(UpdateStore.isNewer(later, than: earlier), "\(later) should be newer than \(earlier)")
            #expect(!UpdateStore.isNewer(earlier, than: later), "\(earlier) should not be newer than \(later)")
        }
    }
}
