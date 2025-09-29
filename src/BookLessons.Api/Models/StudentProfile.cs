namespace BookLessons.Api.Models;

public class StudentProfile
{
    public Guid UserId { get; set; }
    public string? ProficiencyLevel { get; set; }
    public string? LearningGoal { get; set; }
    public string[] PreferredTopics { get; set; } = Array.Empty<string>();
    public int IntroMinutesRedeemed { get; set; }
    public bool JoinedViaReferral { get; set; }
    public bool ConsentedToRecordings { get; set; }
    public User? User { get; set; }
}
