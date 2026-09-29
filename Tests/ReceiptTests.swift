import XCTest

@testable import ReceiptCore

final class ReceiptTests: XCTestCase {
    func testTotalDoesNotUseSubtotal() {
        let receipt = ReceiptParser.parse("Coffee Shop\nSUBTOTAL 12.50\nTAX 1.00\nTOTAL USD 13.50")
        XCTAssertEqual(receipt.amount, Decimal(string: "13.50"))
        XCTAssertEqual(receipt.merchant, "Coffee Shop")
    }
    func testEuropeanAmount() {
        XCTAssertEqual(
            ReceiptParser.parse("Market\nTOTAL EUR 1.234,56").amount, Decimal(string: "1234.56"))
    }
    func testMissingTotalRequiresReview() {
        XCTAssertEqual(ReceiptParser.parse("Shop\nItem 12.00").amount, 0)
    }
    func testCSVQuotesAndNeutralizesFormulas() {
        let csv = ReceiptCSV.encode([
            Receipt(merchant: "=HYPERLINK(\"bad\")", notes: "one, two\nthree")
        ])
        XCTAssertTrue(csv.contains("'=HYPERLINK"))
        XCTAssertTrue(csv.contains("\"\"bad\"\""))
        XCTAssertTrue(csv.contains("\"one, two\nthree\""))
    }
}
