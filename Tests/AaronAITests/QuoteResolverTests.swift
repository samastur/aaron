import Foundation
import Testing
@testable import AaronAI

struct QuoteResolverTests {
    let doc = "Docker is a virtual machine that makes deployment easier.\n\nA virtual machine is heavier."

    @Test func resolvesUniqueQuotationWithContext() {
        let quote = Quotation(original: "virtual machine", prefix: "Docker is a ", suffix: " that makes")
        #expect(QuoteResolver.resolve(quote, in: doc) == .resolved(NSRange(location: 12, length: 15)))
    }

    @Test func usesContextToDisambiguateRepeatedText() {
        let quote = Quotation(original: "virtual machine", prefix: "A ", suffix: " is heavier")
        let expected = (doc as NSString).range(of: "virtual machine", options: .backwards)
        #expect(QuoteResolver.resolve(quote, in: doc) == .resolved(expected))
    }

    @Test func repeatedTextWithoutContextIsAmbiguous() {
        let quote = Quotation(original: "virtual machine", prefix: nil, suffix: nil)
        #expect(QuoteResolver.resolve(quote, in: doc) == .ambiguous(count: 2))
    }

    @Test func missingTextIsNotFound() {
        let quote = Quotation(original: "container", prefix: nil, suffix: nil)
        #expect(QuoteResolver.resolve(quote, in: doc) == .notFound)
    }

    @Test func emptyOriginalIsNotFound() {
        #expect(QuoteResolver.resolve(Quotation(original: "", prefix: "a", suffix: nil), in: doc) == .notFound)
    }

    @Test func uniqueTextWithWrongContextFallsBackToTheOnlyOccurrence() {
        let quote = Quotation(original: "deployment", prefix: "WRONG ", suffix: nil)
        #expect(QuoteResolver.resolve(quote, in: doc) == .resolved((doc as NSString).range(of: "deployment")))
    }

    @Test func repeatedTextWithWrongContextIsAmbiguous() {
        let quote = Quotation(original: "virtual machine", prefix: "WRONG ", suffix: nil)
        #expect(QuoteResolver.resolve(quote, in: doc) == .ambiguous(count: 2))
    }

    @Test func prefixAtDocumentStartMatchesEmptyPrefix() {
        let quote = Quotation(original: "Docker", prefix: "", suffix: " is")
        #expect(QuoteResolver.resolve(quote, in: doc) == .resolved(NSRange(location: 0, length: 6)))
    }

    @Test func quotationMaySpanLines() {
        let quote = Quotation(original: "easier.\n\nA virtual", prefix: "deployment ", suffix: nil)
        #expect(QuoteResolver.resolve(quote, in: doc) == .resolved((doc as NSString).range(of: "easier.\n\nA virtual")))
    }

    @Test func rangesAreUTF16Offsets() {
        let text = "Emoji 😀 then café and café again"
        let quote = Quotation(original: "café", prefix: "then ", suffix: nil)
        // "Emoji " = 6, emoji = 2 UTF-16 units, " then " = 6 -> 14
        #expect(QuoteResolver.resolve(quote, in: text) == .resolved(NSRange(location: 14, length: 4)))
    }

    @Test func overlappingOccurrencesAreAllCounted() {
        let quote = Quotation(original: "aa", prefix: nil, suffix: nil)
        #expect(QuoteResolver.resolve(quote, in: "aaa") == .ambiguous(count: 2))
    }
}
