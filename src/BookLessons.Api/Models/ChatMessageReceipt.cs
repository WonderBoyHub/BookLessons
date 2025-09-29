namespace BookLessons.Api.Models;

public class ChatMessageReceipt
{
    public Guid MessageId { get; set; }
    public Guid RecipientId { get; set; }
    public string ReceiptType { get; set; } = string.Empty;
    public DateTimeOffset RecordedAt { get; set; }
}
