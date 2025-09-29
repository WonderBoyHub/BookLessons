namespace BookLessons.Api.Services;

public interface IJitsiRoomNameFactory
{
    string Create(Guid tutorId, Guid bookingId);
}
