namespace BookLessons.Api.Contracts.Chat;

public record ChatMessageResponse(
    Guid Id,
    Guid ThreadId,
    Guid SenderId,
    string Body,
    DateTimeOffset SentAt,
    DateTimeOffset? DeliveredAt,
    DateTimeOffset? ReadAt,
    string Metadata);
