namespace BookLessons.Api.Contracts.Fraud;

public record RecordFraudSignalRequest(
    Guid? BookingId,
    Guid? PaymentId,
    string Type,
    string? Value,
    string Metadata);
