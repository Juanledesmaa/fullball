import Testing
@testable import Fullball

struct DeviceSeedTests {
    @Test func sharedSeedIsStableForASlateID() {
        #expect(DeviceSeed.sharedSeed(for: "20260617-1") == DeviceSeed.sharedSeed(for: "20260617-1"))
    }

    @Test func sharedSeedDiffersBySlateID() {
        #expect(DeviceSeed.sharedSeed(for: "20260617-1") != DeviceSeed.sharedSeed(for: "20260617-2"))
    }

    @Test func sharedSeedIsDeviceIndependent() {
        // It must NOT mix in the device base — so it differs from the
        // device-mixed seed (unless deviceBase is 0, which it never is).
        #expect(DeviceSeed.sharedSeed(for: "20260617-1") != DeviceSeed.seed(for: "20260617-1")
                || DeviceSeed.deviceBase == 0)
        #expect(DeviceSeed.sharedSeed(for: "20260617-1") != 0)
    }
}
