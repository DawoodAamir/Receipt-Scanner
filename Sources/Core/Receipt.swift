import Foundation

public struct Receipt: Codable, Identifiable, Equatable {
    public let id: UUID
    public var merchant: String
    public var date: Date
    public var amount: Decimal
    public var currency: String
    public var category: String
    public var notes: String
    public var recognizedText: String
    public var image: Data?
    public init(
        id: UUID = UUID(), merchant: String = "", date: Date = Date(), amount: Decimal = 0,
        currency: String = "USD", category: String = "Other", notes: String = "",
        recognizedText: String = "", image: Data? = nil
    ) {
        self.id = id
        self.merchant = merchant
        self.date = date
        self.amount = amount
        self.currency = currency
        self.category = category
        self.notes = notes
        self.recognizedText = recognizedText
        self.image = image
    }
}

public enum ReceiptParser {
    public static func parse(_ text: String, referenceDate: Date = Date()) -> Receipt {
        let lines = text.components(separatedBy: .newlines).map {
            $0.trimmingCharacters(in: .whitespaces)
        }.filter { !$0.isEmpty }
        var receipt = Receipt(
            merchant: lines.first ?? "", date: referenceDate, recognizedText: text)
        let upper = text.uppercased()
        if upper.contains("EUR") || text.contains("€") {
            receipt.currency = "EUR"
        } else if upper.contains("GBP") || text.contains("£") {
            receipt.currency = "GBP"
        } else if upper.contains("PKR") {
            receipt.currency = "PKR"
        }
        let totalLines = lines.filter {
            let line = $0.uppercased()
            return (line.contains("TOTAL") || line.contains("AMOUNT DUE"))
                && !line.contains("SUBTOTAL") && !line.contains("SUB TOTAL")
        }
        for line in totalLines {
            if let range = line.range(
                of: #"[0-9]+(?:[.,][0-9]{3})*[.,][0-9]{2}(?![0-9])"#, options: .regularExpression,
                range: nil, locale: nil)
            {
                var number = String(line[range])
                if (number.lastIndex(of: ",") ?? number.startIndex)
                    > (number.lastIndex(of: ".") ?? number.startIndex)
                {
                    number = number.replacingOccurrences(of: ".", with: "").replacingOccurrences(
                        of: ",", with: ".")
                } else {
                    number = number.replacingOccurrences(of: ",", with: "")
                }
                receipt.amount =
                    Decimal(string: number, locale: Locale(identifier: "en_US_POSIX")) ?? 0
            }
        }
        for format in ["yyyy-MM-dd", "MM/dd/yyyy", "dd.MM.yyyy"] {
            let pattern =
                format == "yyyy-MM-dd"
                ? #"\d{4}-\d{2}-\d{2}"#
                : (format == "MM/dd/yyyy" ? #"\d{2}/\d{2}/\d{4}"# : #"\d{2}\.\d{2}\.\d{4}"#)
            if let range = text.range(of: pattern, options: .regularExpression) {
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.dateFormat = format
                formatter.isLenient = false
                if let date = formatter.date(from: String(text[range])) {
                    receipt.date = date
                    break
                }
            }
        }
        return receipt
    }
}

public enum ReceiptCSV {
    public static func encode(_ receipts: [Receipt]) -> String {
        func field(_ value: String) -> String {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            let safe =
                ["=", "+", "-", "@"].contains(String(trimmed.prefix(1))) ? "'" + value : value
            return "\"" + safe.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        let date = DateFormatter()
        date.locale = Locale(identifier: "en_US_POSIX")
        date.dateFormat = "yyyy-MM-dd"
        let rows = receipts.map { receipt in
            [
                date.string(from: receipt.date), receipt.merchant,
                NSDecimalNumber(decimal: receipt.amount).stringValue, receipt.currency,
                receipt.category, receipt.notes,
            ].map(field).joined(separator: ",")
        }
        return (["Date,Merchant,Amount,Currency,Category,Notes"] + rows).joined(separator: "\r\n")
            + "\r\n"
    }
}
