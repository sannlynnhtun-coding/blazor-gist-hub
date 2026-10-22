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

public sealed class DiagramExportPreset
{
    public string Id { get; set; } = string.Empty;
    public string Name { get; set; } = "Default export";
    public string Format { get; set; } = "png";
    public double Scale { get; set; } = 1;
    public int Border { get; set; } = 10;
    public bool Transparent { get; set; }
    public bool CurrentPage { get; set; } = true;
}
