namespace BookLessons.Api.Models;

public class Payment
{
    public Guid Id { get; set; }
    public Guid? LessonBookingId { get; set; }
    public Guid TutorId { get; set; }
    public Guid StudentId { get; set; }
    public decimal Amount { get; set; }
    public string Currency { get; set; } = "JPY";
    public string Status { get; set; } = "pending";
    public string? Provider { get; set; }
    public string? ProviderReference { get; set; }
    public string? StripeChargeId { get; set; }
    public string? StripePaymentIntentId { get; set; }
    public string? BillingCountry { get; set; }
    public string? CardCountry { get; set; }
    public string? BillingIp { get; set; }
    public string Metadata { get; set; } = "{}";
    public DateTimeOffset? PaidAt { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public ICollection<PaymentEvent> Events { get; set; } = new List<PaymentEvent>();
}
