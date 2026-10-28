using System.IO.Compression;
using System.Text;
using System.Xml;
using System.Xml.Linq;

namespace GistHub.Services;

public static class MarkdownDocxConverter
{
    private static readonly XNamespace W = "http://schemas.openxmlformats.org/wordprocessingml/2006/main";
    private static readonly XNamespace R = "http://schemas.openxmlformats.org/officeDocument/2006/relationships";
    private static readonly XNamespace Rel = "http://schemas.openxmlformats.org/package/2006/relationships";

    public static byte[] Create(string xhtml)
    {
        using var reader = XmlReader.Create(new StringReader(xhtml), new XmlReaderSettings { DtdProcessing = DtdProcessing.Prohibit, MaxCharactersInDocument = 8 * 1024 * 1024 });
        var source = XElement.Load(reader, LoadOptions.PreserveWhitespace);
        var relationships = new XElement(Rel + "Relationships");
        var numbering = new XElement(W + "numbering");
        var body = new XElement(W + "body");
        Blocks(source.Nodes(), body);
        if (!body.HasElements) body.Add(new XElement(W + "p"));
        body.Add(new XElement(W + "sectPr", new XElement(W + "pgSz", A("w", 12240), A("h", 15840)),
            new XElement(W + "pgMar", A("top", 1440), A("right", 1440), A("bottom", 1440), A("left", 1440))));
        var styles = new XElement(W + "styles", new XElement(W + "docDefaults",
            new XElement(W + "rPrDefault", new XElement(W + "rPr", new XElement(W + "rFonts", A("ascii", "Calibri"), A("hAnsi", "Calibri")), new XElement(W + "sz", A("val", 22))))));
        for (var level = 1; level <= 6; level++)
            styles.Add(new XElement(W + "style", A("type", "paragraph"), A("styleId", $"Heading{level}"),
                new XElement(W + "name", A("val", $"heading {level}")),
                new XElement(W + "pPr", new XElement(W + "keepNext"), new XElement(W + "outlineLvl", A("val", level - 1))),
                new XElement(W + "rPr", new XElement(W + "b"), new XElement(W + "sz", A("val", 36 - level * 2)))));

        using var output = new MemoryStream();
        using (var zip = new ZipArchive(output, ZipArchiveMode.Create, true))
        {
            XNamespace ct = "http://schemas.openxmlformats.org/package/2006/content-types";
            Add("[Content_Types].xml", new XElement(ct + "Types",
                new XElement(ct + "Default", new XAttribute("Extension", "rels"), new XAttribute("ContentType", "application/vnd.openxmlformats-package.relationships+xml")),
                new XElement(ct + "Default", new XAttribute("Extension", "xml"), new XAttribute("ContentType", "application/xml")),
                new[] { ("document", "document.main"), ("styles", "styles"), ("numbering", "numbering") }.Select(part =>
                    new XElement(ct + "Override", new XAttribute("PartName", $"/word/{part.Item1}.xml"), new XAttribute("ContentType", $"application/vnd.openxmlformats-officedocument.wordprocessingml.{part.Item2}+xml")))));
            Add("_rels/.rels", new XElement(Rel + "Relationships", Relationship("document", "officeDocument", "word/document.xml")));
            relationships.Add(Relationship("styles", "styles", "styles.xml"), Relationship("numbering", "numbering", "numbering.xml"));
            Add("word/document.xml", new XElement(W + "document", new XAttribute(XNamespace.Xmlns + "w", W), new XAttribute(XNamespace.Xmlns + "r", R), body));
            Add("word/styles.xml", styles);
            Add("word/numbering.xml", numbering);
            Add("word/_rels/document.xml.rels", relationships);

            void Add(string name, XElement xml)
            {
                using var writer = new StreamWriter(zip.CreateEntry(name).Open(), new UTF8Encoding(false));
                xml.Save(writer, SaveOptions.DisableFormatting);
            }
        }
        return output.ToArray();

        void Blocks(IEnumerable<XNode> nodes, XElement target, int depth = 0, XElement? listProperties = null)
        {
            foreach (var node in nodes)
            {
                if (node is XText text)
                {
                    if (!string.IsNullOrWhiteSpace(text.Value)) target.Add(Paragraph([text], listProperties));
                    continue;
                }
                if (node is not XElement element) continue;
                var tag = element.Name.LocalName;
                if (tag is "ul" or "ol")
                {
                    var id = numbering.Elements(W + "num").Count() + 1;
                    var level = Math.Min(depth, 8);
                    var start = int.TryParse(element.Attribute("start")?.Value, out var value) && value > 0 ? value : 1;
                    numbering.Add(new XElement(W + "abstractNum", A("abstractNumId", id), new XElement(W + "multiLevelType", A("val", "multilevel")),
                        new XElement(W + "lvl", A("ilvl", level), new XElement(W + "start", A("val", start)),
                            new XElement(W + "numFmt", A("val", tag == "ol" ? "decimal" : "bullet")),
                            new XElement(W + "lvlText", A("val", tag == "ol" ? $"%{level + 1}." : "•")),
                            new XElement(W + "pPr", new XElement(W + "ind", A("left", (level + 1) * 720), A("hanging", 360))))));
                    // Abstract definitions must precede numbering instances in WordprocessingML.
                    var definition = numbering.Elements(W + "abstractNum").Last();
                    definition.Remove();
                    numbering.AddFirst(definition);
                    numbering.Add(new XElement(W + "num", A("numId", id), new XElement(W + "abstractNumId", A("val", id))));
                    var properties = new XElement(W + "pPr", new XElement(W + "numPr", new XElement(W + "ilvl", A("val", level)), new XElement(W + "numId", A("val", id))));
                    foreach (var item in element.Elements().Where(e => e.Name.LocalName == "li"))
                    {
                        var content = new List<XNode>();
                        var first = true;
                        void Flush()
                        {
                            if (content.Count == 0) return;
                            target.Add(Paragraph(content, first ? properties : null));
                            first = false;
                            content.Clear();
                        }
                        foreach (var child in item.Nodes())
                        {
                            if (child is XElement block && block.Name.LocalName is "ul" or "ol" or "pre" or "blockquote" or "table" or "p")
                            {
                                Flush();
                                if (block.Name.LocalName == "p") { content.AddRange(block.Nodes()); Flush(); }
                                else { if (first) { target.Add(Paragraph([], properties)); first = false; } Blocks([block], target, depth + 1); }
                            }
                            else if (child is not XText whitespace || !string.IsNullOrWhiteSpace(whitespace.Value) || !whitespace.Value.Contains('\n')) content.Add(child);
                        }
                        Flush();
                        if (first) target.Add(Paragraph([], properties));
                    }
                }
                else if (tag == "table")
                {
                    var table = new XElement(W + "tbl", new XElement(W + "tblPr", new XElement(W + "tblBorders",
                        new[] { "top", "left", "bottom", "right", "insideH", "insideV" }.Select(edge => new XElement(W + edge, A("val", "single"), A("sz", 4), A("color", "CCCCCC"))))));
                    var rows = element.Descendants().Where(e => e.Name.LocalName == "tr").ToList();
                    var columns = rows.Select(row => row.Elements().Count()).DefaultIfEmpty(1).Max();
                    table.Add(new XElement(W + "tblGrid", Enumerable.Range(0, columns).Select(_ => new XElement(W + "gridCol", A("w", 9360 / Math.Max(1, columns))))));
                    foreach (var row in rows)
                    {
                        var wordRow = new XElement(W + "tr");
                        foreach (var cell in row.Elements()) wordRow.Add(new XElement(W + "tc", Paragraph(cell.Nodes(), bold: cell.Name.LocalName == "th")));
                        table.Add(wordRow);
                    }
                    target.Add(table, new XElement(W + "p"));
                }
                else if (tag == "blockquote")
                    Blocks(element.Nodes(), target, depth, new XElement(W + "pPr", new XElement(W + "ind", A("left", 720))));
                else if (tag == "pre")
                {
                    foreach (var line in element.Value.Replace("\r\n", "\n").TrimEnd('\n').Split('\n'))
                        target.Add(Paragraph([new XElement("code", line)]));
                }
                else if (tag is "div" or "section") Blocks(element.Nodes(), target, depth);
                else if (tag == "hr") target.Add(new XElement(W + "p", new XElement(W + "pPr",
                    new XElement(W + "pBdr", new XElement(W + "bottom", A("val", "single"), A("sz", 6), A("color", "CCCCCC"))))));
                else
                {
                    var properties = tag.Length == 2 && tag[0] == 'h' && tag[1] is >= '1' and <= '6'
                        ? new XElement(W + "pPr", new XElement(W + "pStyle", A("val", $"Heading{tag[1]}"))) : listProperties;
                    target.Add(Paragraph(element.Nodes(), properties));
                }
            }
        }

        XElement Paragraph(IEnumerable<XNode> nodes, XElement? properties = null, bool bold = false) =>
            new(W + "p", properties is null ? null : new XElement(properties), Inline(nodes, bold));

        IEnumerable<XElement> Inline(IEnumerable<XNode> nodes, bool bold = false, bool italic = false, bool code = false, bool strike = false)
        {
            foreach (var node in nodes)
            {
                if (node is XText text)
                    yield return new XElement(W + "r", new XElement(W + "rPr", bold ? new XElement(W + "b") : null,
                        italic ? new XElement(W + "i") : null, strike ? new XElement(W + "strike") : null,
                        code ? new XElement(W + "rFonts", A("ascii", "Consolas"), A("hAnsi", "Consolas")) : null),
                        new XElement(W + "t", new XAttribute(XNamespace.Xml + "space", "preserve"), text.Value));
                else if (node is XElement element)
                {
                    var tag = element.Name.LocalName;
                    if (tag == "br") { yield return new XElement(W + "r", new XElement(W + "br")); continue; }
                    var children = Inline(element.Nodes(), bold || tag is "strong" or "b", italic || tag is "em" or "i", code || tag == "code", strike || tag is "del" or "s").ToList();
                    var href = element.Attribute("href")?.Value;
                    if (tag == "a" && Uri.TryCreate(href, UriKind.Absolute, out var uri) && uri.Scheme is "https" or "http" or "mailto")
                    {
                        var id = $"link{relationships.Elements().Count()}";
                        var relationship = Relationship(id, "hyperlink", href!);
                        relationship.Add(new XAttribute("TargetMode", "External"));
                        relationships.Add(relationship);
                        yield return new XElement(W + "hyperlink", new XAttribute(R + "id", id), children);
                    }
                    else foreach (var child in children) yield return child;
                }
            }
        }
    }

    private static XAttribute A(string name, object value) => new(W + name, value);
    private static XElement Relationship(string id, string type, string target) => new(Rel + "Relationship",
        new XAttribute("Id", id), new XAttribute("Type", $"{R}/{type}"), new XAttribute("Target", target));
}
