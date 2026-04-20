#if DEBUG
import Foundation
import os

private let stubLogger = Logger(subsystem: "com.simpod", category: "StubFeed")

/// Intercepts `stub://` URL requests issued via `URLSession.shared` and returns
/// the matching XML fixture from `Resources/StubFeeds/feed_NNN.xml`. Any
/// request to `stub://` whose fixture is missing returns 599 so the leak is
/// loud rather than silent (plan §F.1).
///
/// Compiled only in DEBUG. Registered by `SimpodApp` when launched with
/// `SIMPOD_STUB_NETWORK=1`.
final class StubFeedURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.scheme == "stub"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        // stub://feed-001 → "feed-001"
        let host = url.host ?? url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let bundleResourceName = host.replacingOccurrences(of: "-", with: "_") // feed_001

        guard let fixtureURL = Bundle.main.url(forResource: bundleResourceName, withExtension: "xml"),
              let rawData = try? Data(contentsOf: fixtureURL),
              let body = Self.expandPubDateTokens(in: rawData) else {
            stubLogger.error("Stub fixture missing for \(host, privacy: .public)")
            let response = HTTPURLResponse(
                url: url, statusCode: 599, httpVersion: "HTTP/1.1", headerFields: nil
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data())
            client?.urlProtocolDidFinishLoading(self)
            return
        }

        let etag = "stub-\(host)-v1"

        // Conditional GET: respond 304 if If-None-Match matches our ETag.
        if request.value(forHTTPHeaderField: "If-None-Match") == etag {
            let response = HTTPURLResponse(
                url: url, statusCode: 304, httpVersion: "HTTP/1.1",
                headerFields: ["ETag": etag]
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocolDidFinishLoading(self)
            return
        }

        let response = HTTPURLResponse(
            url: url, statusCode: 200, httpVersion: "HTTP/1.1",
            headerFields: [
                "Content-Type": "application/rss+xml",
                "Content-Length": String(body.count),
                "ETag": etag
            ]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() { /* no-op */ }

    /// Substitute `{{HOURS_AGO:N}}` tokens with RFC822 dates N hours before now.
    /// Keeps fixtures eternally inside the inbox 24-hour recency window without
    /// requiring fixture file edits.
    private static func expandPubDateTokens(in data: Data) -> Data? {
        guard var text = String(data: data, encoding: .utf8) else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "GMT")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        let now = Date()

        let pattern = #"\{\{HOURS_AGO:(\d+)\}\}"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return data
        }
        let nsText = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
        for m in matches.reversed() {
            let hoursStr = nsText.substring(with: m.range(at: 1))
            let hours = Int(hoursStr) ?? 0
            let date = now.addingTimeInterval(-Double(hours) * 3600)
            let replacement = formatter.string(from: date)
            text = (text as NSString).replacingCharacters(in: m.range, with: replacement)
        }
        return text.data(using: .utf8)
    }
}
#endif
