import SwiftUI
import Vision

@MainActor
final class ReceiptStore: ObservableObject {
    @Published private(set) var receipts: [Receipt] = []
    @Published var error: String?
    @Published var scanning = false
    private let file: URL
    init() {
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("ReceiptScanner")
        file = folder.appendingPathComponent("receipts.json")
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: file.path) { receipts = try JSONDecoder().decode([Receipt].self, from: Data(contentsOf: file)) }
        } catch { self.error = error.localizedDescription }
    }
    @discardableResult func save(_ receipt: Receipt) -> Bool {
        var next = receipts
        if let index = next.firstIndex(where: { $0.id == receipt.id }) { next[index] = receipt } else { next.insert(receipt, at: 0) }
        return persist(next)
    }
    func delete(_ receipt: Receipt) { _ = persist(receipts.filter { $0.id != receipt.id }) }
    private func persist(_ next: [Receipt]) -> Bool {
        do { try JSONEncoder().encode(next).write(to: file, options: .atomic); receipts = next; return true }
        catch { self.error = error.localizedDescription; return false }
    }
    func recognize(_ images: [UIImage]) async -> Receipt? {
        guard !images.isEmpty else { return nil }
        scanning = true; defer { scanning = false }
        do {
            // Render upright before Vision so EXIF orientation does not rotate recognition.
            let normalized = images.prefix(5).map { image -> UIImage in
                let ratio = min(1, 2000 / max(image.size.width, image.size.height))
                let size = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
                return UIGraphicsImageRenderer(size: size).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
            }
            let text = try await Task.detached(priority: .userInitiated) {
                try normalized.map { image -> String in
                    guard let cg = image.cgImage else { return "" }
                    let request = VNRecognizeTextRequest(); request.recognitionLevel = .accurate; request.usesLanguageCorrection = true
                    try VNImageRequestHandler(cgImage: cg).perform([request])
                    return (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
                }.joined(separator: "\n")
            }.value
            var receipt = ReceiptParser.parse(text)
            receipt.image = normalized.first?.jpegData(compressionQuality: 0.6)
            if text.isEmpty { error = "No text was recognized. You can enter the receipt details manually." }
            return receipt
        } catch { self.error = error.localizedDescription; return nil }
    }
    func exportCSV() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Receipts-\(UUID().uuidString).csv")
        try ReceiptCSV.encode(receipts).write(to: url, atomically: true, encoding: .utf8); return url
    }
}
