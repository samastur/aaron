import Testing
import AaronCore
@testable import AaronPelican

struct PelicanDetectorTests {
    let post = "Title: Hello\nDate: 2026-01-01\n\nText"

    @Test func detectsPelicanMetadataWithTitle() {
        #expect(PelicanDetector.isPelican(post, detection: .automatic))
    }

    @Test func metadataWithoutTitleIsNotPelican() {
        #expect(!PelicanDetector.isPelican("Author: me\n\nText", detection: .automatic))
    }

    @Test func plainMarkdownIsNotPelican() {
        #expect(!PelicanDetector.isPelican("# Hello\n\nText", detection: .automatic))
    }

    @Test func yamlFrontMatterIsNotPelican() {
        #expect(!PelicanDetector.isPelican("---\ntitle: x\n---\nText", detection: .automatic))
    }

    @Test func detectionCanBeForced() {
        #expect(PelicanDetector.isPelican("# Hello", detection: .always))
        #expect(!PelicanDetector.isPelican(post, detection: .never))
    }
}
