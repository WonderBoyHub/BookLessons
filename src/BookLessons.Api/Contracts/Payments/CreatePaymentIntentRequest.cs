namespace BookLessons.Api.Contracts.Payments;

public record CreatePaymentIntentRequest(
    Guid BookingId,
    decimal Amount,
    string Currency,
    string CustomerEmail);
