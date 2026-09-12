@testable import ThaiLife
import XCTest

final class DialogueBreakdownTests: XCTestCase {
    func testBundledDialogueTurnsReconstructThaiAndChineseLines() throws {
        let dialogues = try ContentRepository.loadBundled().filter { $0.kind == .dialogue }
        XCTAssertEqual(dialogues.count, 11)

        for item in dialogues {
            let thaiLines = item.thai.split(separator: "\n").map(String.init)
            let meaningLines = item.meaningZhHans.split(separator: "\n").map(String.init)
            guard let turns = item.dialogueBreakdown else {
                return XCTFail("Missing breakdown for \(item.id)")
            }
            XCTAssertEqual(turns.count, thaiLines.count, item.id)
            XCTAssertEqual(turns.count, meaningLines.count, item.id)
            for (index, turn) in turns.enumerated() {
                XCTAssertEqual("\(turn.speaker): \(turn.thai)", thaiLines[index])
                XCTAssertEqual("\(turn.speaker): \(turn.meaningZhHans)", meaningLines[index])
                XCTAssertEqual(
                    turn.segments.map(\.thai).joined().replacingOccurrences(of: #"\s+"#, with: "", options: .regularExpression),
                    turn.thai.replacingOccurrences(of: #"\s+"#, with: "", options: .regularExpression)
                )
            }
        }
    }
}
