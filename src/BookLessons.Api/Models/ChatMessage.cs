namespace BookLessons.Api.Models;

public class ChatMessage
{
    public Guid Id { get; set; }
    public Guid ThreadId { get; set; }
    public Guid SenderId { get; set; }
    public string Body { get; set; } = string.Empty;
    public DateTimeOffset SentAt { get; set; }
    public DateTimeOffset? DeliveredAt { get; set; }
    public DateTimeOffset? ReadAt { get; set; }
    public Guid? SseEventId { get; set; }
    public string Metadata { get; set; } = "{}";
    public ICollection<ChatMessageReceipt> Receipts { get; set; } = new List<ChatMessageReceipt>();
}
