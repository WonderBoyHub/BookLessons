namespace BookLessons.Api.Models;

public class LessonStatusHistory
{
    public Guid Id { get; set; }
    public Guid LessonBookingId { get; set; }
    public string? PreviousStatus { get; set; }
    public string NewStatus { get; set; } = string.Empty;
    public Guid? ChangedByUserId { get; set; }
    public DateTimeOffset ChangedAt { get; set; }
    public string? Notes { get; set; }
}
