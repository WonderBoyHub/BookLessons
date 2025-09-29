namespace BookLessons.Api.Contracts.Gdpr;

public record DataSubjectRequest(
    Guid Id,
    Guid UserId,
    string Status,
    DateTimeOffset RequestedAt,
    DateTimeOffset? CompletedAt,
    string? ExportLocation,
    string? Notes);
