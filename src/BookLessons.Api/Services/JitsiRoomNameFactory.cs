namespace BookLessons.Api.Services;

public class JitsiRoomNameFactory : IJitsiRoomNameFactory
{
    public string Create(Guid tutorId, Guid bookingId)
        => $"tutor{tutorId:N}_booking{bookingId:N}";
}
