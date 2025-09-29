namespace BookLessons.Api.Models;

public class ChatThread
{
    public Guid Id { get; set; }
    public Guid TutorId { get; set; }
    public Guid StudentId { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset? LastMessageAt { get; set; }
    public ICollection<ChatMessage> Messages { get; set; } = new List<ChatMessage>();
}
