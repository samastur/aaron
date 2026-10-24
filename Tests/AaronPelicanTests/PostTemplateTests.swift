import Foundation
import Testing
@testable import AaronPelican

struct PostTemplateTests {
    let date: Date = {
        var c = DateComponents()
        c.year = 2026; c.month = 3; c.day = 4; c.hour = 9; c.minute = 5
        return Calendar.current.date(from: c)!
    }()

    @Test func expandsDatePlaceholders() {
        let text = PostTemplate.expand("Date: {date}\nDay: {day}", date: date)
        #expect(text == "Date: 2026-03-04 09:05\nDay: 2026-03-04")
    }

    @Test func leavesOtherTextAlone() {
        #expect(PostTemplate.expand("Title: {title}", date: date) == "Title: {title}")
    }
}
