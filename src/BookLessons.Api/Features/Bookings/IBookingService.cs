using BookLessons.Api.Contracts.Bookings;

namespace BookLessons.Api.Features.Bookings;

public interface IBookingService
{
    Task<BookingResponse> CreateBookingAsync(CreateBookingRequest request, CancellationToken cancellationToken);
    Task<BookingResponse?> GetBookingAsync(Guid bookingId, CancellationToken cancellationToken);
    Task<BookingResponse?> UpdateStatusAsync(Guid bookingId, UpdateBookingStatusRequest request, CancellationToken cancellationToken);
}
