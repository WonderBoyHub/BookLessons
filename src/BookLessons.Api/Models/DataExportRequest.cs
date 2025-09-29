namespace BookLessons.Api.Models;

public class DataExportRequest
{
    public Guid Id { get; set; }
    public Guid UserId { get; set; }
    public string Status { get; set; } = "pending";
    public DateTimeOffset RequestedAt { get; set; }
    public DateTimeOffset? ProcessedAt { get; set; }
    public string? ExportLocation { get; set; }
    public string? Notes { get; set; }
}
