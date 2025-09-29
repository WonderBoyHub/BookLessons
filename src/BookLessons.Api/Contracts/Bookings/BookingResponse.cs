namespace BookLessons.Api.Contracts.Bookings;

public record BookingResponse(
    Guid Id,
    Guid TutorId,
    Guid StudentId,
    DateTimeOffset ScheduledStart,
    int DurationMinutes,
    string Status,
    bool ManualReviewRequired,
    decimal? FraudRiskScore,
    string MeetingRoomName);
