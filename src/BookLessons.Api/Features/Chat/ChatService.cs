using System.Runtime.CompilerServices;
using System.Text.Json;
using BookLessons.Api.Contracts.Chat;
using BookLessons.Api.Data;
using BookLessons.Api.Models;
using BookLessons.Api.Services;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;

namespace BookLessons.Api.Features.Chat;

public class ChatService : IChatService
{
    private readonly AppDbContext _dbContext;
    private readonly SseOptions _options;
    private readonly IClock _clock;

    public ChatService(AppDbContext dbContext, IOptions<SseOptions> options, IClock clock)
    {
        _dbContext = dbContext;
        _clock = clock;
        _options = options.Value;
    }

    public async Task<ChatMessageResponse> SendMessageAsync(Guid threadId, SendMessageRequest request, CancellationToken cancellationToken)
    {
        var thread = await _dbContext.ChatThreads
            .FirstOrDefaultAsync(t => t.Id == threadId, cancellationToken);

        if (thread is null)
        {
            throw new InvalidOperationException($"Chat thread {threadId} not found.");
        }

        var metadata = string.IsNullOrWhiteSpace(request.Metadata) ? "{}" : request.Metadata!;
        using var _ = JsonDocument.Parse(metadata);

        var message = new ChatMessage
        {
            Id = Guid.NewGuid(),
            ThreadId = threadId,
            SenderId = request.SenderId,
            Body = request.Body,
            SentAt = _clock.UtcNow,
            SseEventId = Guid.NewGuid(),
            Metadata = metadata,
            DeliveredAt = _clock.UtcNow
        };

        _dbContext.ChatMessages.Add(message);
        thread.LastMessageAt = message.SentAt;

        await _dbContext.SaveChangesAsync(cancellationToken);

        return Map(message);
    }

    public async Task<IReadOnlyList<ChatMessageResponse>> GetMessagesAsync(Guid threadId, int limit, CancellationToken cancellationToken)
    {
        var messages = await _dbContext.ChatMessages
            .AsNoTracking()
            .Where(m => m.ThreadId == threadId)
            .OrderByDescending(m => m.SentAt)
            .Take(limit)
            .OrderBy(m => m.SentAt)
            .ToListAsync(cancellationToken);

        return messages.Select(Map).ToList();
    }

    public async IAsyncEnumerable<ChatMessageResponse> StreamMessagesAsync(Guid threadId, DateTimeOffset? since, [EnumeratorCancellation] CancellationToken cancellationToken)
    {
        var cursor = since ?? _clock.UtcNow.AddMinutes(-_options.LookbackMinutes);

        while (!cancellationToken.IsCancellationRequested)
        {
            var messages = await _dbContext.ChatMessages
                .AsNoTracking()
                .Where(m => m.ThreadId == threadId && m.SentAt > cursor)
                .OrderBy(m => m.SentAt)
                .ToListAsync(cancellationToken);

            foreach (var message in messages)
            {
                cursor = message.SentAt;
                yield return Map(message);
            }

            try
            {
                await Task.Delay(TimeSpan.FromSeconds(_options.PollIntervalSeconds), cancellationToken);
            }
            catch (TaskCanceledException)
            {
                yield break;
            }
        }
    }

    private static ChatMessageResponse Map(ChatMessage message) => new(
        message.Id,
        message.ThreadId,
        message.SenderId,
        message.Body,
        message.SentAt,
        message.DeliveredAt,
        message.ReadAt,
        message.Metadata);
}
