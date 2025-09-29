namespace BookLessons.Api.Contracts.Payments;

public record PaymentIntentResponse(
    Guid PaymentId,
    string StripeClientSecret,
    string Status);
