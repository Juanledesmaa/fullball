import UIKit
import FirebaseStorage

/// Async portrait source: memory → disk → Firebase Storage. Replaces the old
/// hash-mapped bundled `AvatarAssets`. Quarantines Storage from the UI.
protocol PlayerImageStore: Sendable {
    func image(for id: String) async -> UIImage?
}

/// Disk cache under Caches/players. Pure path logic is testable.
enum DiskImageCache {
    static func filename(for id: String) -> String { "\(id).jpg" }

    static var dir: URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let d = base.appendingPathComponent("players", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }
    static func url(for id: String) -> URL { dir.appendingPathComponent(filename(for: id)) }

    /// Deals in `Data` (Sendable) so callers can run these off the main actor.
    static func loadData(_ id: String) -> Data? { try? Data(contentsOf: url(for: id)) }
    static func save(_ data: Data, _ id: String) {
        try? data.write(to: url(for: id), options: .atomic)
    }
}

/// Production store. Memory cache → disk cache → Firebase Storage download.
@MainActor
final class FirebaseImageStore: PlayerImageStore {
    private let mem = NSCache<NSString, UIImage>()
    private let storage = Storage.storage()
    private static let maxBytes: Int64 = 4 * 1024 * 1024

    func image(for id: String) async -> UIImage? {
        let key = id as NSString
        if let m = mem.object(forKey: key) { return m }
        // Disk read off the main actor (Data is Sendable; UIImage decode stays here).
        if let d = await Task.detached(priority: .utility, operation: { DiskImageCache.loadData(id) }).value,
           let img = UIImage(data: d) {
            mem.setObject(img, forKey: key); return img
        }
        // Closure API + continuation: the StorageReference stays on this actor;
        // only the Sendable `Data` crosses back. (The async `data(maxSize:)` API
        // trips strict concurrency by sending the non-Sendable reference.)
        let ref = storage.reference(withPath: "players/\(id).jpg")
        let data: Data? = await withCheckedContinuation { cont in
            ref.getData(maxSize: Self.maxBytes) { data, _ in
                cont.resume(returning: data)
            }
        }
        guard let data, let img = UIImage(data: data) else { return nil }   // → placeholder
        Task.detached(priority: .utility) { DiskImageCache.save(data, id) }   // write off-actor
        mem.setObject(img, forKey: key)
        return img
    }
}

/// Preview/offline impl: never resolves an image (UI shows placeholder).
struct MockImageStore: PlayerImageStore {
    func image(for id: String) async -> UIImage? { nil }
}
