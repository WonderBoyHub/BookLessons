namespace BookLessons.Api.Contracts.Chat;

public record SendMessageRequest(
    Guid SenderId,
    string Body,
    string? Metadata);
