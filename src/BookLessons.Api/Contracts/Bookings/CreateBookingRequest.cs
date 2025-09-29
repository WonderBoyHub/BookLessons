namespace BookLessons.Api.Contracts.Bookings;

public record CreateBookingRequest(
    Guid TutorId,
    Guid StudentId,
    DateTimeOffset ScheduledStart,
    int DurationMinutes,
    bool RequireManualReview,
    bool IsIntroSession,
    int? IntroMinutesApplied);
