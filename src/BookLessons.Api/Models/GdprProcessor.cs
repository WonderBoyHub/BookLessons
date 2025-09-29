namespace BookLessons.Api.Models;

public class GdprProcessor
{
    public Guid Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public string? ServiceDescription { get; set; }
    public bool DpaExecuted { get; set; }
    public bool EuRegionPinned { get; set; }
    public string[] DataCenterRegions { get; set; } = Array.Empty<string>();
    public string? ContactUrl { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
}
