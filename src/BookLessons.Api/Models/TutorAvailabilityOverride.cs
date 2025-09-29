namespace BookLessons.Api.Models;

public class TutorAvailabilityOverride
{
    public Guid Id { get; set; }
    public Guid TutorProfileId { get; set; }
    public DateTimeOffset StartAt { get; set; }
    public DateTimeOffset EndAt { get; set; }
    public int? AvailableMinutes { get; set; }
    public string OverrideType { get; set; } = string.Empty;
    public string? Notes { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public TutorProfile? TutorProfile { get; set; }
}
