namespace BookLessons.Api.Contracts.Bookings;

public record UpdateBookingStatusRequest(
    string Status,
    string? Notes,
    Guid? ChangedByUserId);
