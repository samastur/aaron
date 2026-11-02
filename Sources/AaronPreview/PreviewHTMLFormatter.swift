import Markdown

/// Turns a swift-markdown tree into HTML. Unlike swift-markdown's own
/// `HTMLFormatter`, it escapes text, code and attribute values (so
/// `` `<div>` `` shows as code instead of becoming a tag), keeps inline
/// formatting in headings and writes the alt text of images. Raw HTML in
/// the document is passed through.
struct PreviewHTMLFormatter: MarkupWalker {
    private(set) var result = ""
    private var inTableHead = false
    private var columnAlignments: [Table.ColumnAlignment?] = []
    private var column = 0

    static func format(_ markup: Markup) -> String {
        var formatter = PreviewHTMLFormatter()
        formatter.visit(markup)
        return formatter.result
    }

    // MARK: Blocks

    mutating func visitBlockQuote(_ blockQuote: BlockQuote) {
        result += "<blockquote>\n"
        descendInto(blockQuote)
        result += "</blockquote>\n"
    }

    mutating func visitCodeBlock(_ codeBlock: CodeBlock) {
        let language = codeBlock.language.map { #" class="language-\#(HTML.escape($0))""# } ?? ""
        result += "<pre><code\(language)>\(HTML.escape(codeBlock.code))</code></pre>\n"
    }

    mutating func visitHeading(_ heading: Heading) {
        result += "<h\(heading.level)>"
        descendInto(heading)
        result += "</h\(heading.level)>\n"
    }

    mutating func visitThematicBreak(_ thematicBreak: ThematicBreak) {
        result += "<hr>\n"
    }

    mutating func visitHTMLBlock(_ html: HTMLBlock) {
        result += html.rawHTML
    }

    mutating func visitListItem(_ listItem: ListItem) {
        result += "<li>"
        if let checkbox = listItem.checkbox {
            result += #"<input type="checkbox" disabled\#(checkbox == .checked ? " checked" : "")> "#
        }
        descendInto(listItem)
        result += "</li>\n"
    }

    mutating func visitOrderedList(_ orderedList: OrderedList) {
        let start = orderedList.startIndex != 1 ? #" start="\#(orderedList.startIndex)""# : ""
        result += "<ol\(start)>\n"
        descendInto(orderedList)
        result += "</ol>\n"
    }

    mutating func visitUnorderedList(_ unorderedList: UnorderedList) {
        result += "<ul>\n"
        descendInto(unorderedList)
        result += "</ul>\n"
    }

    mutating func visitParagraph(_ paragraph: Paragraph) {
        result += "<p>"
        descendInto(paragraph)
        result += "</p>\n"
    }

    mutating func visitTable(_ table: Table) {
        result += "<table>\n"
        columnAlignments = table.columnAlignments
        descendInto(table)
        columnAlignments = []
        result += "</table>\n"
    }

    mutating func visitTableHead(_ tableHead: Table.Head) {
        result += "<thead>\n<tr>\n"
        inTableHead = true
        column = 0
        descendInto(tableHead)
        inTableHead = false
        result += "</tr>\n</thead>\n"
    }

    mutating func visitTableBody(_ tableBody: Table.Body) {
        guard !tableBody.isEmpty else { return }
        result += "<tbody>\n"
        descendInto(tableBody)
        result += "</tbody>\n"
    }

    mutating func visitTableRow(_ tableRow: Table.Row) {
        result += "<tr>\n"
        column = 0
        descendInto(tableRow)
        result += "</tr>\n"
    }

    mutating func visitTableCell(_ tableCell: Table.Cell) {
        guard column < columnAlignments.count, tableCell.colspan > 0, tableCell.rowspan > 0 else { return }
        let element = inTableHead ? "th" : "td"
        result += "<\(element)"
        if let alignment = columnAlignments[column] {
            result += #" align="\#(alignment)""#
        }
        column += 1
        if tableCell.rowspan > 1 { result += #" rowspan="\#(tableCell.rowspan)""# }
        if tableCell.colspan > 1 { result += #" colspan="\#(tableCell.colspan)""# }
        result += ">"
        descendInto(tableCell)
        result += "</\(element)>\n"
    }

    // MARK: Inline

    private mutating func wrap(_ tag: String, _ markup: Markup) {
        result += "<\(tag)>"
        descendInto(markup)
        result += "</\(tag)>"
    }

    mutating func visitInlineCode(_ inlineCode: InlineCode) {
        result += "<code>\(HTML.escape(inlineCode.code))</code>"
    }

    mutating func visitEmphasis(_ emphasis: Emphasis) { wrap("em", emphasis) }
    mutating func visitStrong(_ strong: Strong) { wrap("strong", strong) }
    mutating func visitStrikethrough(_ strikethrough: Strikethrough) { wrap("del", strikethrough) }

    mutating func visitImage(_ image: Image) {
        result += "<img"
        if let source = image.source, !source.isEmpty { result += #" src="\#(HTML.escape(source))""# }
        result += #" alt="\#(HTML.escape(image.plainText))""#
        if let title = image.title, !title.isEmpty { result += #" title="\#(HTML.escape(title))""# }
        result += ">"
    }

    mutating func visitLink(_ link: Link) {
        result += "<a"
        if let destination = link.destination { result += #" href="\#(HTML.escape(destination))""# }
        if let title = link.title, !title.isEmpty { result += #" title="\#(HTML.escape(title))""# }
        result += ">"
        descendInto(link)
        result += "</a>"
    }

    mutating func visitInlineHTML(_ inlineHTML: InlineHTML) {
        result += inlineHTML.rawHTML
    }

    mutating func visitLineBreak(_ lineBreak: LineBreak) {
        result += "<br>\n"
    }

    mutating func visitSoftBreak(_ softBreak: SoftBreak) {
        result += "\n"
    }

    mutating func visitText(_ text: Text) {
        result += HTML.escape(text.string)
    }

    mutating func visitSymbolLink(_ symbolLink: SymbolLink) {
        if let destination = symbolLink.destination { result += "<code>\(HTML.escape(destination))</code>" }
    }

    mutating func visitInlineAttributes(_ attributes: InlineAttributes) {
        descendInto(attributes)
    }
}
