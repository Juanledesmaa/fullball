import Testing
@testable import Fullball

struct PlayerImageStoreTests {
    @Test func diskFilenameIsIdDotJpg() {
        #expect(DiskImageCache.filename(for: "P007") == "P007.jpg")
    }
}
