namespace BookLessons.Api.Services;

public class SseOptions
{
    public int PollIntervalSeconds { get; set; } = 3;
    public int LookbackMinutes { get; set; } = 5;
}
