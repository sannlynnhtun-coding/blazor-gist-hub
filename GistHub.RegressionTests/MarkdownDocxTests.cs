using System.IO.Compression;
using System.Xml;
using System.Xml.Linq;
using GistHub.Services;

static class MarkdownDocxTests
{
    public static void Run()
    {
        var bytes = MarkdownDocxConverter.Create("""
            <div xmlns="http://www.w3.org/1999/xhtml"><h1>Title &amp; မြန်မာ</h1>
            <p><strong>bold <em>both</em></strong> <del>removed</del><br/><a href="https://example.com/?x=1&amp;y=2">safe</a><a href="javascript:alert(1)">unsafe</a></p>
            <ol start="3"><li><p>first</p><p>continued</p><ul><li>nested</li></ul><p>after nested</p></li><li><strong>second</strong> <em>item</em></li></ol>
            <table><thead><tr><th>Header</th></tr></thead><tbody><tr><td>A &lt; B</td></tr></tbody></table>
            <pre><code>  if (x &lt; 2) {
              return;
            }</code></pre><hr/></div>
            """);
        using var zip = new ZipArchive(new MemoryStream(bytes));
        XDocument Read(string name) { using var stream = zip.GetEntry(name)!.Open(); return XDocument.Load(stream); }
        XNamespace w = "http://schemas.openxmlformats.org/wordprocessingml/2006/main";
        XNamespace rel = "http://schemas.openxmlformats.org/package/2006/relationships";
        var document = Read("word/document.xml");
        Check(zip.Entries.Count == 6 && zip.Entries.All(entry => Read(entry.FullName).Root is not null), "Every DOCX package part must be valid XML.");
        Check(document.Descendants(w + "pStyle").Single().Attribute(w + "val")?.Value == "Heading1", "Headings must use editable Word styles.");
        Check(document.Descendants(w + "t").Any(t => t.Value == "Title & မြန်မာ"), "Unicode and XML entities must round trip.");
        Check(document.Descendants(w + "r").Any(r => r.Element(w + "rPr")?.Element(w + "b") is not null && r.Element(w + "rPr")?.Element(w + "i") is not null), "Nested inline formatting must be retained.");
        var texts = document.Descendants(w + "t").Select(t => t.Value).ToList();
        Check(texts.IndexOf("continued") < texts.IndexOf("nested") && texts.IndexOf("nested") < texts.IndexOf("after nested"), "Nested and multi-paragraph list content must retain its order.");
        Check(document.Descendants(w + "p").Any(p => string.Concat(p.Descendants(w + "t").Select(t => t.Value)) == "second item"), "Spaces between formatted list text must survive.");
        Check(document.Descendants(w + "numPr").Count() == 3 && Read("word/numbering.xml").Descendants(w + "start").Any(e => e.Attribute(w + "val")?.Value == "3"), "Lists must use native numbering and preserve start values.");
        Check(document.Descendants(w + "tbl").Count() == 1 && document.Descendants(w + "tc").Count() == 2, "Tables must contain editable Word cells.");
        Check(document.Descendants(w + "rFonts").Any(e => e.Attribute(w + "ascii")?.Value == "Consolas") && texts.Contains("  if (x < 2) {"), "Code indentation and monospaced formatting must survive.");
        var links = Read("word/_rels/document.xml.rels").Descendants(rel + "Relationship").Where(e => e.Attribute("TargetMode")?.Value == "External").ToList();
        Check(links.Count == 1 && links[0].Attribute("Target")?.Value == "https://example.com/?x=1&y=2", "Only safe links may become external relationships.");
        Check(document.Descendants(w + "br").Any() && document.Descendants(w + "pBdr").Any(), "Line breaks and horizontal rules must survive.");
        try { MarkdownDocxConverter.Create("<!DOCTYPE div [<!ENTITY x SYSTEM 'file:///secret'>]><div>&x;</div>"); throw new Exception("DTD input must be rejected."); }
        catch (XmlException) { }
        using var empty = new ZipArchive(new MemoryStream(MarkdownDocxConverter.Create("<div/>")));
        Check(empty.GetEntry("word/document.xml") is not null, "Empty documents must still produce a valid package.");
        Console.WriteLine("PASS: Markdown DOCX preserves editable structure, list order, Unicode, and safe links.");
    }

    private static void Check(bool condition, string message) { if (!condition) throw new Exception(message); }
}
