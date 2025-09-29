namespace BookLessons.Api.Models;

public class TutorProfile
{
    public Guid UserId { get; set; }
    public string? Introduction { get; set; }
    public string NativeLanguage { get; set; } = "Japanese";
    public string[] TeachingLanguages { get; set; } = Array.Empty<string>();
    public decimal? HourlyRate { get; set; }
    public int IntroOfferMinutes { get; set; }
    public bool IntroOfferEnabled { get; set; }
    public int DefaultSessionMinutes { get; set; }
    public int BookingIncrementMinutes { get; set; }
    public int? MaxDailyMinutes { get; set; }
    public string? CalendarTimezone { get; set; }
    public string? NotificationEmail { get; set; }
    public string? JitsiDisplayName { get; set; }
    public int AvailabilityBufferMinutes { get; set; }
    public string? Notes { get; set; }
    public User? User { get; set; }
    public ICollection<TutorAvailabilityPattern> AvailabilityPatterns { get; set; } = new List<TutorAvailabilityPattern>();
    public ICollection<TutorAvailabilityOverride> AvailabilityOverrides { get; set; } = new List<TutorAvailabilityOverride>();
}
