using BookLessons.Api.Contracts.Fraud;
using BookLessons.Api.Models;

namespace BookLessons.Api.Features.Fraud;

public interface IFraudService
{
    Task<FraudAssessmentResponse> AssessBookingAsync(LessonBooking booking, CancellationToken cancellationToken);
    Task RecordSignalAsync(RecordFraudSignalRequest request, CancellationToken cancellationToken);
}
