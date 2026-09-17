import Foundation
import Testing
@testable import Folio

struct WikipediaEndpointTests {

    @Test("Spaces become underscores and reserved characters are encoded")
    func articleURLEncodesTitles() {
        let url = WikipediaEndpoint.articleURL(title: "Slash/Colon: A Title", language: "de")
        #expect(url?.absoluteString.hasPrefix("https://de.wikipedia.org/wiki/") == true)
        #expect(url?.absoluteString.contains("%2F") == true)
        #expect(url?.absoluteString.contains(" ") == false)
    }

    @Test("History URLs carry the title and the action")
    func historyURLIsWellFormed() {
        let url = WikipediaEndpoint.historyURL(title: "Bauhaus", language: "de")
        let string = try? #require(url?.absoluteString)
        #expect(string?.contains("action=history") == true)
        #expect(string?.contains("title=Bauhaus") == true)
    }
}
