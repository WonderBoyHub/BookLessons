namespace BookLessons.Api.Models;

public class AuditLogEntry
{
    public Guid Id { get; set; }
    public Guid? ActorId { get; set; }
    public string SubjectType { get; set; } = string.Empty;
    public Guid? SubjectId { get; set; }
    public string Action { get; set; } = string.Empty;
    public DateTimeOffset OccurredAt { get; set; }
    public string? IpAddress { get; set; }
    public string Metadata { get; set; } = "{}";
}
