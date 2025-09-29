namespace BookLessons.Api.Models;

public class GdprAuditEvent
{
    public Guid Id { get; set; }
    public Guid ActorId { get; set; }
    public string EventType { get; set; } = string.Empty;
    public DateTimeOffset HappenedAt { get; set; }
    public string? Actor { get; set; }
    public string Details { get; set; } = "{}";
}
