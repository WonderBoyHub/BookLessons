namespace BookLessons.Api.Models;

public class TutorAvailabilityPattern
{
    public Guid Id { get; set; }
    public Guid TutorProfileId { get; set; }
    public int Weekday { get; set; }
    public TimeOnly StartTime { get; set; }
    public TimeOnly EndTime { get; set; }
    public int SlotMinutes { get; set; }
    public bool AllowIntroSessions { get; set; }
    public bool IsActive { get; set; }
    public string? Notes { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public TutorProfile? TutorProfile { get; set; }
}
