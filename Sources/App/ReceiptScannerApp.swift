import SwiftUI
import VisionKit

@main
struct ReceiptScannerApp: App {
    @StateObject private var store = ReceiptStore()
    var body: some Scene {
        WindowGroup { ReceiptsView().environmentObject(store).tint(Color("AccentColor")) }
    }
}

struct ReceiptsView: View {
    @EnvironmentObject private var store: ReceiptStore
    @State private var draft: Receipt?
    @State private var camera = false
    @State private var photos = false
    @State private var query = ""
    @State private var export: ReceiptExport?
    var filtered: [Receipt] {
        store.receipts.filter {
            query.isEmpty || $0.merchant.localizedCaseInsensitiveContains(query)
                || $0.category.localizedCaseInsensitiveContains(query)
        }
    }
    var body: some View {
        NavigationView {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Every receipt,\nin its place.").font(
                            .system(.largeTitle, design: .serif)
                        ).fontWeight(.semibold).fixedSize(horizontal: false, vertical: true)
                        Text(
                            "Scan, check the details, and keep a clean record. Recognition happens on your device."
                        ).foregroundColor(.secondary)
                    }.padding(.vertical, 12)
                    ForEach(Array(Set(store.receipts.map(\.currency))).sorted(), id: \.self) {
                        currency in
                        HStack {
                            Text("Total · \(currency)")
                            Spacer()
                            Text(
                                store.receipts.filter { $0.currency == currency }.reduce(Decimal(0))
                                { $0 + $1.amount }, format: .currency(code: currency)
                            ).bold()
                        }
                    }
                }
                Section("Receipts") {
                    if filtered.isEmpty {
                        Text(
                            query.isEmpty
                                ? "No receipts yet. Scan one or try the sample."
                                : "No matching receipts."
                        ).foregroundColor(.secondary)
                    }
                    ForEach(filtered) { receipt in
                        Button {
                            draft = receipt
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(receipt.merchant).font(.headline).foregroundColor(.primary)
                                    Text(
                                        "\(receipt.category) · \(receipt.date.formatted(date: .abbreviated, time: .omitted))"
                                    ).font(.caption).foregroundColor(.secondary)
                                }
                                Spacer()
                                Text(receipt.amount, format: .currency(code: receipt.currency))
                                    .foregroundColor(.primary)
                            }.padding(.vertical, 5)
                        }.swipeActions {
                            Button("Delete", role: .destructive) { store.delete(receipt) }
                        }
                    }
                }
                Section {
                    Button("Try a sample receipt") {
                        if let image = UIImage(named: "sample-receipt.png") {
                            Task { draft = await store.recognize([image]) }
                        } else {
                            draft = ReceiptParser.parse(
                                "NORTH STREET COFFEE\n2026-09-20\nCoffee 4.50\nSandwich 8.00\nSUBTOTAL 12.50\nTAX 1.00\nTOTAL USD 13.50"
                            )
                        }
                    }
                    Button("Export CSV") {
                        do { export = ReceiptExport(url: try store.exportCSV()) } catch {
                            store.error = error.localizedDescription
                        }
                    }.disabled(store.receipts.isEmpty)
                }
            }.navigationTitle("Receipts").searchable(text: $query, prompt: "Merchant or category")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            Button("Scan with camera") { camera = true }.disabled(
                                !VNDocumentCameraViewController.isSupported)
                            Button("Import photo") { photos = true }
                            Button("Enter manually") { draft = Receipt() }
                        } label: {
                            Image(systemName: "plus")
                        }.accessibilityLabel("Add receipt").disabled(store.scanning)
                    }
                }
                .overlay {
                    if store.scanning {
                        ProgressView("Reading receipt…").padding(24).background(.regularMaterial)
                            .cornerRadius(12)
                    }
                }
        }.navigationViewStyle(.stack)
            .sheet(item: $draft) { ReceiptEditor(receipt: $0) }
            .sheet(isPresented: $camera) {
                ReceiptCamera { images in
                    Task { draft = await store.recognize(images) }
                } failure: {
                    store.error = $0
                }
            }
            .sheet(isPresented: $photos) {
                ReceiptPhotoPicker { image in Task { draft = await store.recognize([image]) } }
            }
            .sheet(item: $export) { ReceiptShareSheet(items: [$0.url]) }
            .alert(
                "Receipt scanner",
                isPresented: Binding(
                    get: { store.error != nil }, set: { if !$0 { store.error = nil } })
            ) {
                Button("OK") { store.error = nil }
            } message: {
                Text(store.error ?? "")
            }
    }
}

struct ReceiptEditor: View {
    @State var receipt: Receipt
    @EnvironmentObject private var store: ReceiptStore
    @Environment(\.dismiss) private var dismiss
    @State private var amount = ""
    @State private var export: ReceiptExport?
    private var parsedAmount: Decimal? {
        Decimal(
            string: amount.replacingOccurrences(of: ",", with: "."),
            locale: Locale(identifier: "en_US_POSIX"))
    }
    var body: some View {
        NavigationView {
            Form {
                Section {
                    Text(
                        "Check the merchant, date, currency, and total before saving. OCR suggestions can be wrong."
                    ).foregroundColor(.secondary)
                }
                Section("Details") {
                    TextField("Merchant", text: $receipt.merchant)
                    DatePicker("Date", selection: $receipt.date, displayedComponents: .date)
                    TextField("Total", text: $amount).keyboardType(.decimalPad)
                    Picker("Currency", selection: $receipt.currency) {
                        ForEach(["USD", "EUR", "GBP", "PKR", "CAD", "AUD", "JPY"], id: \.self) {
                            Text($0)
                        }
                    }
                    Picker("Category", selection: $receipt.category) {
                        ForEach(["Meals", "Travel", "Office", "Equipment", "Other"], id: \.self) {
                            Text($0)
                        }
                    }
                }
                Section("Notes") { TextEditor(text: $receipt.notes).frame(minHeight: 80) }
                if let data = receipt.image, let image = UIImage(data: data) {
                    Section("Original") { Image(uiImage: image).resizable().scaledToFit() }
                }
                if !receipt.recognizedText.isEmpty {
                    Section {
                        DisclosureGroup("Recognized text") {
                            Text(receipt.recognizedText).font(.caption).textSelection(.enabled)
                        }
                    }
                }
                Section {
                    Button("Export PDF") {
                        do {
                            var copy = receipt
                            copy.amount = parsedAmount ?? receipt.amount
                            export = ReceiptExport(url: try ReceiptPDF.create(copy))
                        } catch { store.error = error.localizedDescription }
                    }
                }
            }.navigationTitle("Review receipt")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            guard let value = parsedAmount else { return }
                            receipt.amount = value
                            if store.save(receipt) { dismiss() }
                        }.disabled(
                            receipt.merchant.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                || parsedAmount == nil)
                    }
                }
        }.onAppear { amount = NSDecimalNumber(decimal: receipt.amount).stringValue }
            .sheet(item: $export) { ReceiptShareSheet(items: [$0.url]) }
    }
}
