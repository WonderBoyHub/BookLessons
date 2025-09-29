namespace BookLessons.Api.Models;

public class PrivacyConsent
{
    public Guid Id { get; set; }
    public Guid UserId { get; set; }
    public string ConsentType { get; set; } = string.Empty;
    public DateTimeOffset GrantedAt { get; set; }
    public DateTimeOffset? WithdrawnAt { get; set; }
    public string? Notes { get; set; }
}
