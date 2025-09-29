using BookLessons.Api.Contracts.Payments;

namespace BookLessons.Api.Features.Payments;

public interface IPaymentService
{
    Task<PaymentIntentResponse> CreatePaymentIntentAsync(CreatePaymentIntentRequest request, CancellationToken cancellationToken);
    Task HandleWebhookAsync(string payload, string signature, CancellationToken cancellationToken);
}
