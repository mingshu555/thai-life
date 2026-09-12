import Foundation
import CryptoKit

enum ContentRepository {
    enum LoadError: LocalizedError {
        case bundledJSONNotFound
        case decodeFailed(Error)
        case manifestNotFound
        case manifestCountMismatch(expected: Int, actual: Int)
        case manifestChecksumMismatch

        var errorDescription: String? {
            switch self {
            case .bundledJSONNotFound: "未找到内容包 items.json"
            case .decodeFailed(let e): "内容解码失败: \(e.localizedDescription)"
            case .manifestNotFound: "未找到 content-manifest.json"
            case .manifestCountMismatch(let exp, let act):
                "内容数量不匹配: manifest 声明 \(exp)，实际 \(act)"
            case .manifestChecksumMismatch: "内容校验和不匹配"
            }
        }
    }

    static var resourceBundle: Bundle {
        class BundleFinder {}
        let bundle = Bundle(for: BundleFinder.self)
        if bundle.url(forResource: "items", withExtension: "json", subdirectory: "Content") != nil ||
           bundle.url(forResource: "items", withExtension: "json") != nil {
            return bundle
        }
        for b in Bundle.allBundles {
            if b.url(forResource: "items", withExtension: "json", subdirectory: "Content") != nil ||
               b.url(forResource: "items", withExtension: "json") != nil {
                return b
            }
        }
        return Bundle.main
    }

    static func loadBundled() throws -> [ContentItem] {
        let b = resourceBundle
        guard let url = b.url(forResource: "items", withExtension: "json", subdirectory: "Content") ??
                        b.url(forResource: "items", withExtension: "json") else {
            throw LoadError.bundledJSONNotFound
        }
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        let items = try decoder.decode([ContentItem].self, from: data)

        // Validate against manifest
        let manifest = try loadManifest()
        if items.count != manifest.itemCount {
            throw LoadError.manifestCountMismatch(expected: manifest.itemCount, actual: items.count)
        }

        // Verify checksum
        let computedChecksum = SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
        if computedChecksum != manifest.checksumSHA256 {
            throw LoadError.manifestChecksumMismatch
        }

        return items
    }

    static func loadManifest() throws -> ContentManifest {
        let b = resourceBundle
        guard let url = b.url(forResource: "content-manifest", withExtension: "json", subdirectory: "Content") ??
                        b.url(forResource: "content-manifest", withExtension: "json") else {
            throw LoadError.manifestNotFound
        }
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        return try decoder.decode(ContentManifest.self, from: data)
    }

    static func loadThaiMenuReference() throws -> ThaiMenuReference {
        let b = resourceBundle
        guard let url = b.url(forResource: "thai_menu_reference", withExtension: "json", subdirectory: "Content") ??
                        b.url(forResource: "thai_menu_reference", withExtension: "json") else {
            throw ThaiMenuLoadError.resourceNotFound
        }
        do {
            let reference = try JSONDecoder().decode(ThaiMenuReference.self, from: Data(contentsOf: url))
            try ThaiMenuValidator.validate(reference)
            return reference
        } catch let error as ThaiMenuValidator.ValidationError {
            throw ThaiMenuLoadError.invalid(error.localizedDescription)
        } catch {
            throw ThaiMenuLoadError.decode(error.localizedDescription)
        }
    }

    static func loadLooplessSignageReference() throws -> LooplessSignageReference {
        let b = resourceBundle
        guard let url = b.url(forResource: "loopless_signage_reference", withExtension: "json", subdirectory: "Content") ??
                        b.url(forResource: "loopless_signage_reference", withExtension: "json") else {
            throw LooplessSignageLoadError.resourceNotFound
        }
        do {
            let reference = try JSONDecoder().decode(LooplessSignageReference.self, from: Data(contentsOf: url))
            try LooplessSignageValidator.validate(reference)
            return reference
        } catch let error as LooplessSignageValidator.ValidationError {
            throw LooplessSignageLoadError.invalid(error.localizedDescription)
        } catch {
            throw LooplessSignageLoadError.decode(error.localizedDescription)
        }
    }

    static func loadWordFamilies() -> [WordFamily] {
        let b = resourceBundle
        guard let url = b.url(forResource: "word_families", withExtension: "json", subdirectory: "Content") ??
                        b.url(forResource: "word_families", withExtension: "json") else {
            return []
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([WordFamily].self, from: data)
        } catch {
            print("Failed to decode word_families.json: \(error)")
            return []
        }
    }
}
