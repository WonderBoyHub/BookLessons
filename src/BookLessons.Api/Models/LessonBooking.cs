namespace BookLessons.Api.Models;

public class LessonBooking
{
    public Guid Id { get; set; }
    public Guid TutorId { get; set; }
    public Guid StudentId { get; set; }
    public DateTimeOffset ScheduledStart { get; set; }
    public int DurationMinutes { get; set; }
    public string Status { get; set; } = "requested";
    public bool IsIntroSession { get; set; }
    public int IntroMinutesApplied { get; set; }
    public string? MeetingLink { get; set; }
    public string? Location { get; set; }
    public decimal? PricePerMinute { get; set; }
    public string? StripePaymentIntentId { get; set; }
    public string JitsiDomain { get; set; } = "meet.jit.si";
    public string MeetingRoomName { get; set; } = string.Empty;
    public string? CancellationReason { get; set; }
    public Guid? CancelledBy { get; set; }
    public decimal? FraudRiskScore { get; set; }
    public bool ManualReviewRequired { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }
    public ICollection<LessonStatusHistory> StatusHistory { get; set; } = new List<LessonStatusHistory>();
    public ICollection<Payment> Payments { get; set; } = new List<Payment>();
}
