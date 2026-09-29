import SwiftUI
import VisionKit
import PhotosUI

struct ReceiptCamera: UIViewControllerRepresentable {
    let completed: ([UIImage]) -> Void
    let failure: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController(); controller.delegate = context.coordinator; return controller
    }
    func updateUIViewController(_ controller: VNDocumentCameraViewController, context: Context) {}
    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let parent: ReceiptCamera
        init(_ parent: ReceiptCamera) { self.parent = parent }
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            parent.dismiss(); parent.completed((0..<min(scan.pageCount, 5)).map { scan.imageOfPage(at: $0) })
        }
        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) { parent.dismiss() }
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) { parent.dismiss(); parent.failure(error.localizedDescription) }
    }
}
struct ReceiptPhotoPicker: UIViewControllerRepresentable {
    let selected: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(); config.filter = .images; config.selectionLimit = 1
        let controller = PHPickerViewController(configuration: config); controller.delegate = context.coordinator; return controller
    }
    func updateUIViewController(_ controller: PHPickerViewController, context: Context) {}
    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: ReceiptPhotoPicker
        init(_ parent: ReceiptPhotoPicker) { self.parent = parent }
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.dismiss()
            results.first?.itemProvider.loadObject(ofClass: UIImage.self) { object, _ in
                if let image = object as? UIImage { DispatchQueue.main.async { self.parent.selected(image) } }
            }
        }
    }
}
struct ReceiptExport: Identifiable { let id = UUID(); let url: URL }
struct ReceiptShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: items, applicationActivities: nil) }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
@MainActor
enum ReceiptPDF {
    static func create(_ receipt: Receipt) throws -> URL {
        let data = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 612, height: 792)).pdfData { context in
            context.beginPage()
            let text = "\(receipt.merchant)\n\n\(receipt.date.formatted(date: .long, time: .omitted))\n\n\(NSDecimalNumber(decimal: receipt.amount)) \(receipt.currency)\n\(receipt.category)"
            (text as NSString).draw(in: CGRect(x: 48, y: 48, width: 516, height: 350), withAttributes: [.font: UIFont.systemFont(ofSize: 20), .foregroundColor: UIColor.black])
            let words = receipt.notes.split(whereSeparator: \.isWhitespace)
            for start in stride(from: 0, to: words.count, by: 180) {
                context.beginPage()
                let page = words[start..<min(start + 180, words.count)].joined(separator: " ")
                (page as NSString).draw(in: CGRect(x: 48, y: 48, width: 516, height: 696), withAttributes: [.font: UIFont.systemFont(ofSize: 12), .foregroundColor: UIColor.black])
            }
            if let data = receipt.image, let image = UIImage(data: data) {
                context.beginPage()
                let ratio = min(516/image.size.width, 696/image.size.height)
                image.draw(in: CGRect(x: 48, y: 48, width: image.size.width * ratio, height: image.size.height * ratio))
            }
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Receipt-\(receipt.id.uuidString).pdf")
        try data.write(to: url, options: .atomic); return url
    }
}
