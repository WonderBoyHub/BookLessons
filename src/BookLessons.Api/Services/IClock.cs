namespace BookLessons.Api.Services;

public interface IClock
{
    DateTimeOffset UtcNow { get; }
}
