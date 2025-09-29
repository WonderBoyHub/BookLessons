using System.Text.Json;
using BookLessons.Api.Contracts.Fraud;
using BookLessons.Api.Data;
using BookLessons.Api.Models;
using BookLessons.Api.Services;
using Microsoft.EntityFrameworkCore;

namespace BookLessons.Api.Features.Fraud;

public class FraudService(AppDbContext dbContext, IClock clock) : IFraudService
{
    private static readonly Dictionary<string, decimal> SeverityWeights = new()
    {
        ["low"] = 10m,
        ["medium"] = 40m,
        ["high"] = 90m
    };

    public async Task<FraudAssessmentResponse> AssessBookingAsync(LessonBooking booking, CancellationToken cancellationToken)
    {
        var signals = await dbContext.FraudSignals
            .AsNoTracking()
            .Where(s => s.LessonBookingId == booking.Id)
            .ToListAsync(cancellationToken);

        var triggeredSignals = new List<string>();
        decimal riskScore = 0m;

        foreach (var signal in signals)
        {
            var weight = SeverityWeights.TryGetValue(signal.Severity.ToLowerInvariant(), out var value)
                ? value
                : 0.2m;
            riskScore += weight;
            triggeredSignals.Add(signal.Type);
        }

        if (booking.ManualReviewRequired)
        {
            riskScore += 50m;
            triggeredSignals.Add("manual_review_requested");
        }

        riskScore = Math.Clamp(riskScore, 0m, 100m);
        var requiresReview = riskScore >= 60m;

        var distinctSignals = triggeredSignals.Distinct().ToList();

        if (requiresReview)
        {
            var severity = riskScore switch
            {
                >= 80m => "high",
                >= 60m => "medium",
                _ => "low"
            };

            dbContext.FraudAlerts.Add(new FraudAlert
            {
                Id = Guid.NewGuid(),
                UserId = booking.StudentId,
                Source = "booking",
                Reason = string.Join(", ", distinctSignals),
                Severity = severity,
                RiskScore = riskScore,
                ManualReviewRequired = true,
                FlaggedAt = clock.UtcNow
            });
        }

        return new FraudAssessmentResponse(booking.Id, riskScore, requiresReview, distinctSignals);
    }

    public async Task RecordSignalAsync(RecordFraudSignalRequest request, CancellationToken cancellationToken)
    {
        var metadata = string.IsNullOrWhiteSpace(request.Metadata) ? "{}" : request.Metadata;
        using var _ = JsonDocument.Parse(metadata);

        dbContext.FraudSignals.Add(new FraudSignal
        {
            Id = Guid.NewGuid(),
            LessonBookingId = request.BookingId,
            PaymentId = request.PaymentId,
            Type = request.Type,
            Value = request.Value,
            Metadata = metadata,
            RecordedAt = clock.UtcNow
        });

        await dbContext.SaveChangesAsync(cancellationToken);
    }
}
