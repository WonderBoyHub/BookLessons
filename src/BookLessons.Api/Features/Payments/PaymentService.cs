using System.Text.Json;
using BookLessons.Api.Contracts.Payments;
using BookLessons.Api.Data;
using BookLessons.Api.Models;
using BookLessons.Api.Services;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Stripe;

namespace BookLessons.Api.Features.Payments;

public class PaymentService : IPaymentService
{
    private readonly AppDbContext _dbContext;
    private readonly StripeOptions _options;
    private readonly IClock _clock;

    public PaymentService(AppDbContext dbContext, IOptions<StripeOptions> options, IClock clock)
    {
        _dbContext = dbContext;
        _clock = clock;
        _options = options.Value;
        if (string.IsNullOrWhiteSpace(_options.SecretKey))
        {
            throw new InvalidOperationException("Stripe secret key is not configured.");
        }

        StripeConfiguration.ApiKey = _options.SecretKey;
    }

    public async Task<PaymentIntentResponse> CreatePaymentIntentAsync(CreatePaymentIntentRequest request, CancellationToken cancellationToken)
    {
        if (request.Amount <= 0)
        {
            throw new ArgumentOutOfRangeException(nameof(request.Amount), "Amount must be positive.");
        }

        if (string.IsNullOrWhiteSpace(request.Currency))
        {
            throw new ArgumentException("Currency is required.", nameof(request.Currency));
        }

        if (string.IsNullOrWhiteSpace(request.CustomerEmail))
        {
            throw new ArgumentException("Customer email is required.", nameof(request.CustomerEmail));
        }

        var booking = await _dbContext.LessonBookings
            .AsNoTracking()
            .FirstOrDefaultAsync(b => b.Id == request.BookingId, cancellationToken)
            ?? throw new InvalidOperationException($"Booking {request.BookingId} not found.");

        var payment = new Payment
        {
            Id = Guid.NewGuid(),
            LessonBookingId = booking.Id,
            TutorId = booking.TutorId,
            StudentId = booking.StudentId,
            Amount = request.Amount,
            Currency = request.Currency,
            CreatedAt = _clock.UtcNow,
            Status = "pending",
            Provider = "stripe"
        };

        var paymentIntentService = new PaymentIntentService();
        var intent = await paymentIntentService.CreateAsync(new PaymentIntentCreateOptions
        {
            Amount = Convert.ToInt64(Math.Round(request.Amount * 100)),
            Currency = request.Currency.ToLowerInvariant(),
            Customer = null,
            ReceiptEmail = request.CustomerEmail,
            Metadata = new Dictionary<string, string>
            {
                ["bookingId"] = booking.Id.ToString(),
                ["tutorId"] = booking.TutorId.ToString(),
                ["studentId"] = booking.StudentId.ToString()
            },
            AutomaticPaymentMethods = new PaymentIntentAutomaticPaymentMethodsOptions
            {
                Enabled = true
            }
        }, cancellationToken: cancellationToken);

        payment.StripePaymentIntentId = intent.Id;
        payment.ProviderReference = intent.Id;
        payment.Status = intent.Status ?? "pending";
        var metadataDictionary = intent.Metadata ?? new Dictionary<string, string>();
        metadataDictionary["customerEmail"] = request.CustomerEmail;
        payment.Metadata = JsonSerializer.Serialize(metadataDictionary);
        if (string.Equals(intent.Status, "succeeded", StringComparison.OrdinalIgnoreCase))
        {
            payment.PaidAt = _clock.UtcNow;
        }

        _dbContext.Payments.Add(payment);
        await _dbContext.SaveChangesAsync(cancellationToken);

        return new PaymentIntentResponse(payment.Id, intent.ClientSecret!, payment.Status);
    }

    public async Task HandleWebhookAsync(string payload, string signature, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(_options.WebhookSecret))
        {
            throw new InvalidOperationException("Stripe webhook secret is not configured.");
        }

        var stripeEvent = EventUtility.ConstructEvent(payload, signature, _options.WebhookSecret);
        if (stripeEvent.Data.Object is PaymentIntent intent)
        {
            var payment = await _dbContext.Payments
                .FirstOrDefaultAsync(p => p.StripePaymentIntentId == intent.Id, cancellationToken);

            if (payment is null)
            {
                return;
            }

            payment.Status = intent.Status ?? payment.Status;
            payment.StripeChargeId = intent.LatestChargeId;
            if (intent.Status == "succeeded")
            {
                payment.PaidAt = _clock.UtcNow;
            }

            if (intent.Metadata is { Count: > 0 })
            {
                payment.Metadata = JsonSerializer.Serialize(intent.Metadata);
            }

            _dbContext.PaymentEvents.Add(new PaymentEvent
            {
                Id = Guid.NewGuid(),
                PaymentId = payment.Id,
                Type = stripeEvent.Type,
                Payload = payload,
                OccurredAt = _clock.UtcNow
            });

            await _dbContext.SaveChangesAsync(cancellationToken);
        }
    }
}
