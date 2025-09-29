using BookLessons.Api.Contracts.Chat;

namespace BookLessons.Api.Features.Chat;

public interface IChatService
{
    Task<ChatMessageResponse> SendMessageAsync(Guid threadId, SendMessageRequest request, CancellationToken cancellationToken);
    Task<IReadOnlyList<ChatMessageResponse>> GetMessagesAsync(Guid threadId, int limit, CancellationToken cancellationToken);
    IAsyncEnumerable<ChatMessageResponse> StreamMessagesAsync(Guid threadId, DateTimeOffset? since, CancellationToken cancellationToken);
}
