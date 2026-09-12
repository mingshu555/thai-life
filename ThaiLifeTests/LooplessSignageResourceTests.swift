@testable import ThaiLife
import XCTest
import UIKit

final class LooplessSignageResourceTests: XCTestCase {
    private var resourceBundle: Bundle {
        ContentRepository.resourceBundle
    }

    func testLooplessFontsAttributionAndSceneIllustrationsAreBundled() {
        XCTAssertNotNil(resourceBundle.url(forResource: "Sarabun-Regular", withExtension: "ttf", subdirectory: "Fonts"))
        XCTAssertNotNil(resourceBundle.url(forResource: "Prompt-Regular", withExtension: "ttf", subdirectory: "Fonts"))
        XCTAssertNotNil(resourceBundle.url(forResource: "loopless-signage-assets", withExtension: "md", subdirectory: "Attributions"))
        let registeredFonts = resourceBundle.object(forInfoDictionaryKey: "UIAppFonts") as? [String]
        XCTAssertEqual(registeredFonts, ["Fonts/Sarabun-Regular.ttf", "Fonts/Prompt-Regular.ttf"])

        for imageID in ["milk-tea", "discount", "open-close", "pharmacy", "station-exit"] {
            guard let url = resourceBundle.url(forResource: imageID, withExtension: "png", subdirectory: "LooplessSignage") else {
                return XCTFail("Missing text-bearing scene image: \(imageID)")
            }
            guard let image = UIImage(contentsOfFile: url.path) else {
                return XCTFail("Unreadable scene image: \(imageID)")
            }
            XCTAssertGreaterThanOrEqual(image.size.width, 1_000, "\(imageID) must use the full teaching signboard image, not a placeholder")
            XCTAssertGreaterThanOrEqual(image.size.height, 700, "\(imageID) must use the full teaching signboard image, not a placeholder")
        }
    }
}
