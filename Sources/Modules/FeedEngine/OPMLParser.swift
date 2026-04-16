import Foundation

/// Parses OPML XML files to extract podcast feed URLs.
/// One-sentence test: OPMLParser extracts podcast feed URLs from OPML XML data.
enum OPMLParser {

    /// Parse an OPML document and return all unique `xmlUrl` values found in `<outline>` elements.
    ///
    /// - Handles nested outline groups (category folders containing feed outlines).
    /// - Uses the presence of `xmlUrl` as the feed indicator — does not filter on `type`.
    /// - Deduplicates URLs, preserving first-occurrence order.
    /// - Throws `OPMLError.parseFailure` if the XML is malformed.
    /// - Throws `OPMLError.noFeedsFound` if parsing succeeds but no feed URLs are found.
    static func parseFeedURLs(from data: Data) throws -> [String] {
        let delegate = OPMLParserDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate

        let success = parser.parse()

        if !success || delegate.parseError != nil {
            let reason = delegate.parseError?.localizedDescription
                ?? parser.parserError?.localizedDescription
                ?? "Unknown XML parse error"
            throw OPMLError.parseFailure(reason)
        }

        if delegate.feedURLs.isEmpty {
            throw OPMLError.noFeedsFound
        }

        return delegate.feedURLs
    }
}

// MARK: - OPMLError

enum OPMLError: LocalizedError, Equatable {
    case parseFailure(String)
    case noFeedsFound

    var errorDescription: String? {
        switch self {
        case .parseFailure(let reason):
            return "OPML parse failure: \(reason)"
        case .noFeedsFound:
            return "No podcast feed URLs found in OPML document"
        }
    }
}

// MARK: - Private XMLParserDelegate

/// Internal delegate that accumulates `xmlUrl` attributes from every `<outline>` element.
/// Nesting is handled automatically — XMLParser fires `didStartElement` for every element
/// regardless of depth.
private final class OPMLParserDelegate: NSObject, XMLParserDelegate, @unchecked Sendable {

    /// Unique feed URLs in first-occurrence order.
    private(set) var feedURLs: [String] = []

    /// Non-nil when the parser encounters a fatal error.
    private(set) var parseError: Error?

    /// Tracks seen URLs for O(1) deduplication while preserving insertion order.
    private var seen: Set<String> = []

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        guard elementName.lowercased() == "outline",
              let xmlUrl = attributeDict["xmlUrl"] ?? attributeDict["xmlurl"],
              !xmlUrl.isEmpty
        else { return }

        if seen.insert(xmlUrl).inserted {
            feedURLs.append(xmlUrl)
        }
    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        self.parseError = parseError
    }

    func parser(_ parser: XMLParser, validationErrorOccurred validationError: Error) {
        self.parseError = validationError
    }
}
