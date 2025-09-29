namespace BookLessons.Api.Models;

public class FraudAlert
{
    public Guid Id { get; set; }
    public Guid UserId { get; set; }
    public string Source { get; set; } = string.Empty;
    public string Reason { get; set; } = string.Empty;
    public string Severity { get; set; } = "low";
    public decimal? RiskScore { get; set; }
    public bool ManualReviewRequired { get; set; }
    public DateTimeOffset FlaggedAt { get; set; }
    public DateTimeOffset? ResolvedAt { get; set; }
    public string? ResolutionNotes { get; set; }
}
