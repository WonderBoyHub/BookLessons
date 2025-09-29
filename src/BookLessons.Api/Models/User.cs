namespace BookLessons.Api.Models;

public class User
{
    public Guid Id { get; set; }
    public string Email { get; set; } = string.Empty;
    public string? PhoneNumber { get; set; }
    public string FullName { get; set; } = string.Empty;
    public string Role { get; set; } = string.Empty; // "tutor" or "student"
    public bool IsActive { get; set; } = true;
    public bool MarketingOptIn { get; set; }
    public string TimeZone { get; set; } = "Asia/Tokyo";
    public string Locale { get; set; } = "ja-JP";
    public string? CountryCode { get; set; }
    public string? StripeCustomerId { get; set; }
    public string? AuthProviderId { get; set; }
    public string? LastSignInIp { get; set; }
    public DateTimeOffset? LastLoginAt { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }
    public DateTimeOffset? AnonymizedAt { get; set; }
    public DateTimeOffset? DataRetentionExpiresAt { get; set; }
    public TutorProfile? TutorProfile { get; set; }
    public StudentProfile? StudentProfile { get; set; }
}
