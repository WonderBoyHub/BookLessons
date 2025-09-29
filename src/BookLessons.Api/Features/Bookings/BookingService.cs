using BookLessons.Api.Contracts.Bookings;
using BookLessons.Api.Data;
using BookLessons.Api.Features.Fraud;
using BookLessons.Api.Models;
using BookLessons.Api.Services;
using Microsoft.EntityFrameworkCore;

namespace BookLessons.Api.Features.Bookings;

public class BookingService(
    AppDbContext dbContext,
    IJitsiRoomNameFactory roomNameFactory,
    IFraudService fraudService,
    IClock clock) : IBookingService
{
    public async Task<BookingResponse> CreateBookingAsync(CreateBookingRequest request, CancellationToken cancellationToken)
    {
        _ = await dbContext.TutorProfiles
            .AsNoTracking()
            .FirstOrDefaultAsync(t => t.UserId == request.TutorId, cancellationToken)
            ?? throw new InvalidOperationException($"Tutor profile for {request.TutorId} not found.");

        _ = await dbContext.StudentProfiles
            .AsNoTracking()
            .FirstOrDefaultAsync(s => s.UserId == request.StudentId, cancellationToken)
            ?? throw new InvalidOperationException($"Student profile for {request.StudentId} not found.");

        if (request.DurationMinutes <= 0)
        {
            throw new ArgumentOutOfRangeException(nameof(request.DurationMinutes), "Duration must be positive.");
        }

        if (request.IntroMinutesApplied is { } introMinutes && introMinutes < 0)
        {
            throw new ArgumentOutOfRangeException(nameof(request.IntroMinutesApplied), "Intro minutes cannot be negative.");
        }

        if (request.IntroMinutesApplied is { } intro && intro > request.DurationMinutes)
        {
            throw new InvalidOperationException("Intro minutes cannot exceed the total duration.");
        }

        var now = clock.UtcNow;
        var bookingId = Guid.NewGuid();
        var booking = new LessonBooking
        {
            Id = bookingId,
            TutorId = request.TutorId,
            StudentId = request.StudentId,
            ScheduledStart = request.ScheduledStart,
            DurationMinutes = request.DurationMinutes,
            Status = "requested",
            IsIntroSession = request.IsIntroSession,
            IntroMinutesApplied = request.IsIntroSession ? request.IntroMinutesApplied ?? 0 : 0,
            ManualReviewRequired = request.RequireManualReview,
            MeetingRoomName = roomNameFactory.Create(request.TutorId, bookingId),
            CreatedAt = now,
            UpdatedAt = now
        };

        var assessment = await fraudService.AssessBookingAsync(booking, cancellationToken);
        booking.FraudRiskScore = assessment.RiskScore;
        booking.ManualReviewRequired = booking.ManualReviewRequired || assessment.RequiresManualReview;
        booking.Status = booking.ManualReviewRequired ? "requested" : "confirmed";

        dbContext.AuditLogEntries.Add(new AuditLogEntry
        {
            Id = Guid.NewGuid(),
            ActorId = request.StudentId,
            SubjectType = "lesson_booking",
            SubjectId = booking.Id,
            Action = "booking_created",
            OccurredAt = now,
            Metadata = "{}"
        });

        if (!booking.ManualReviewRequired)
        {
            dbContext.AuditLogEntries.Add(new AuditLogEntry
            {
                Id = Guid.NewGuid(),
                ActorId = request.StudentId,
                SubjectType = "lesson_booking",
                SubjectId = booking.Id,
                Action = "booking_confirmed",
                OccurredAt = now,
                Metadata = "{}"
            });
        }

        dbContext.LessonBookings.Add(booking);
        dbContext.LessonStatusHistory.Add(new LessonStatusHistory
        {
            Id = Guid.NewGuid(),
            LessonBookingId = booking.Id,
            PreviousStatus = null,
            NewStatus = booking.Status,
            Notes = "Booking created",
            ChangedByUserId = request.StudentId,
            ChangedAt = now
        });

        await dbContext.SaveChangesAsync(cancellationToken);

        return Map(booking);
    }

    public async Task<BookingResponse?> GetBookingAsync(Guid bookingId, CancellationToken cancellationToken)
    {
        var booking = await dbContext.LessonBookings
            .AsNoTracking()
            .FirstOrDefaultAsync(b => b.Id == bookingId, cancellationToken);

        return booking is null ? null : Map(booking);
    }

    public async Task<BookingResponse?> UpdateStatusAsync(Guid bookingId, UpdateBookingStatusRequest request, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(request.Status))
        {
            throw new ArgumentException("Status is required.", nameof(request.Status));
        }

        var booking = await dbContext.LessonBookings
            .FirstOrDefaultAsync(b => b.Id == bookingId, cancellationToken);

        if (booking is null)
        {
            return null;
        }

        var now = clock.UtcNow;
        var previousStatus = booking.Status;
        booking.Status = request.Status;
        booking.UpdatedAt = now;

        dbContext.AuditLogEntries.Add(new AuditLogEntry
        {
            Id = Guid.NewGuid(),
            ActorId = request.ChangedByUserId,
            SubjectType = "lesson_booking",
            SubjectId = booking.Id,
            Action = $"status_changed:{request.Status}",
            OccurredAt = now,
            Metadata = "{}"
        });

        dbContext.LessonStatusHistory.Add(new LessonStatusHistory
        {
            Id = Guid.NewGuid(),
            LessonBookingId = booking.Id,
            PreviousStatus = previousStatus,
            NewStatus = request.Status,
            Notes = request.Notes,
            ChangedByUserId = request.ChangedByUserId,
            ChangedAt = now
        });

        await dbContext.SaveChangesAsync(cancellationToken);

        return Map(booking);
    }

    private static BookingResponse Map(LessonBooking booking) => new(
        booking.Id,
        booking.TutorId,
        booking.StudentId,
        booking.ScheduledStart,
        booking.DurationMinutes,
        booking.Status,
        booking.ManualReviewRequired,
        booking.FraudRiskScore,
        booking.MeetingRoomName);
}
