namespace BookLessons.Api.Models;

public class FraudSignal
{
    public Guid Id { get; set; }
    public Guid? AlertId { get; set; }
    public Guid? LessonBookingId { get; set; }
    public Guid? PaymentId { get; set; }
    public string Type { get; set; } = string.Empty;
    public string? Value { get; set; }
    public string Metadata { get; set; } = "{}";
    public DateTimeOffset RecordedAt { get; set; }
}
