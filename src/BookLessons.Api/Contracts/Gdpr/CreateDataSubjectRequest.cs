namespace BookLessons.Api.Contracts.Gdpr;

public record CreateDataSubjectRequest(
    Guid UserId,
    string? Notes);
