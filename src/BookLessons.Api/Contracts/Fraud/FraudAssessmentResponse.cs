namespace BookLessons.Api.Contracts.Fraud;

public record FraudAssessmentResponse(
    Guid BookingId,
    decimal RiskScore,
    bool RequiresManualReview,
    IEnumerable<string> TriggeredSignals);
