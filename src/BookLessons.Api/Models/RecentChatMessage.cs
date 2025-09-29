namespace BookLessons.Api.Models;

public class RecentChatMessage
{
    public Guid ThreadId { get; set; }
    public Guid MessageId { get; set; }
    public Guid SenderId { get; set; }
    public string Body { get; set; } = string.Empty;
    public DateTimeOffset SentAt { get; set; }
    public string Metadata { get; set; } = "{}";
}
