import Foundation
import Testing
@testable import AaronCore

struct OpenRequestTests {
    @Test func roundTripsAwkwardPaths() throws {
        let request = OpenRequest(token: "abc", profile: "Blog 2&x",
                                  paths: ["/tmp/a b/c&d#e%f+g.md", "/tmp/čšž ü.md"])
        let decoded = try #require(OpenRequest(url: request.url))
        #expect(decoded == request)
    }

    @Test func roundTripsWithoutProfile() throws {
        let request = OpenRequest(token: "abc", profile: nil, paths: ["/a.md"])
        #expect(OpenRequest(url: request.url) == request)
    }

    @Test func rejectsOtherHostsMissingTokenOrPaths() {
        for text in ["aaron://close?token=t&path=%2Fa", "other://open?token=t&path=%2Fa",
                     "aaron://open?path=%2Fa", "aaron://open?token=&path=%2Fa", "aaron://open?token=t"] {
            #expect(OpenRequest(url: URL(string: text)!) == nil, "\(text)")
        }
    }

    @Test func decodesScriptStyleEncoding() throws {
        let request = try #require(OpenRequest(url: URL(string: "aaron://open?token=t&path=%2Ftmp%2Fa%20b%2Bc.md")!))
        #expect(request.paths == ["/tmp/a b+c.md"])
        #expect(request.profile == nil)
        #expect(request.token == "t")
    }
}
