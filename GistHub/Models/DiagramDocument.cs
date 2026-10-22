namespace GistHub.Models;

public sealed class DiagramDocument
{
    public string Id { get; set; } = string.Empty;
    public string Title { get; set; } = string.Empty;
    public string Xml { get; set; } = string.Empty;
    public string Owner { get; set; } = string.Empty;
    public long Revision { get; set; }
    public string UpdatedAt { get; set; } = string.Empty;
    public string? GistId { get; set; }
    public string? GistFilename { get; set; }
    public string? RemoteXml { get; set; }
}
