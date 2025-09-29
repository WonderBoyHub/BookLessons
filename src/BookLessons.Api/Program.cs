using System.IO;
using System.Text.Json;
using BookLessons.Api.Contracts.Bookings;
using BookLessons.Api.Contracts.Chat;
using BookLessons.Api.Contracts.Fraud;
using BookLessons.Api.Contracts.Gdpr;
using BookLessons.Api.Contracts.Payments;
using BookLessons.Api.Extensions;
using BookLessons.Api.Features.Bookings;
using BookLessons.Api.Features.Chat;
using BookLessons.Api.Features.Fraud;
using BookLessons.Api.Features.Gdpr;
using BookLessons.Api.Features.Payments;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddBookLessonsServices(builder.Configuration);
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();
builder.Services.AddCors(options =>
{
    options.AddDefaultPolicy(policy =>
        policy.AllowAnyOrigin().AllowAnyHeader().AllowAnyMethod());
});

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseCors();
app.UseHttpsRedirection();

app.MapPost("/api/bookings", async (CreateBookingRequest request, IBookingService bookingService, CancellationToken token) =>
    {
        var booking = await bookingService.CreateBookingAsync(request, token);
        return Results.Created($"/api/bookings/{booking.Id}", booking);
    })
    .WithName("CreateBooking");

app.MapGet("/api/bookings/{bookingId:guid}", async (Guid bookingId, IBookingService bookingService, CancellationToken token) =>
    {
        var booking = await bookingService.GetBookingAsync(bookingId, token);
        return booking is null ? Results.NotFound() : Results.Ok(booking);
    })
    .WithName("GetBooking");

app.MapPost("/api/bookings/{bookingId:guid}/status",
        async (Guid bookingId, UpdateBookingStatusRequest request, IBookingService bookingService, CancellationToken token) =>
        {
            var booking = await bookingService.UpdateStatusAsync(bookingId, request, token);
            return booking is null ? Results.NotFound() : Results.Ok(booking);
        })
    .WithName("UpdateBookingStatus");

app.MapPost("/api/chat/threads/{threadId:guid}/messages",
        async (Guid threadId, SendMessageRequest request, IChatService chatService, CancellationToken token)
            => Results.Ok(await chatService.SendMessageAsync(threadId, request, token)))
    .WithName("SendChatMessage");

app.MapGet("/api/chat/threads/{threadId:guid}/messages",
        async (Guid threadId, int? limit, IChatService chatService, CancellationToken token) =>
        {
            var messages = await chatService.GetMessagesAsync(threadId, limit ?? 50, token);
            return Results.Ok(messages);
        })
    .WithName("GetChatMessages");

app.MapGet("/api/chat/threads/{threadId:guid}/stream", async (HttpContext context, Guid threadId, DateTimeOffset? since, IChatService chatService, CancellationToken token) =>
    {
        context.Response.Headers.CacheControl = "no-cache";
        context.Response.Headers.Connection = "keep-alive";
        context.Response.ContentType = "text/event-stream";

        await foreach (var message in chatService.StreamMessagesAsync(threadId, since, token))
        {
            var payload = JsonSerializer.Serialize(message);
            await context.Response.WriteAsync($"data: {payload}\n\n", token);
            await context.Response.Body.FlushAsync(token);
        }
    })
    .WithName("StreamChatMessages");

app.MapPost("/api/gdpr/export", async (CreateDataSubjectRequest request, IGdprService gdprService, CancellationToken token)
        => Results.Ok(await gdprService.CreateExportRequestAsync(request, token)))
    .WithName("CreateExportRequest");

app.MapPost("/api/gdpr/erasure", async (CreateDataSubjectRequest request, IGdprService gdprService, CancellationToken token)
        => Results.Ok(await gdprService.CreateErasureRequestAsync(request, token)))
    .WithName("CreateErasureRequest");

app.MapPost("/api/gdpr/{requestId:guid}/complete",
        async (Guid requestId, string? exportLocation, IGdprService gdprService, CancellationToken token) =>
        {
            var result = await gdprService.CompleteRequestAsync(requestId, exportLocation, token);
            return result is null ? Results.NotFound() : Results.Ok(result);
        })
    .WithName("CompleteGdprRequest");

app.MapGet("/api/gdpr/open", async (IGdprService gdprService, CancellationToken token)
        => Results.Ok(await gdprService.GetOpenRequestsAsync(token)))
    .WithName("GetOpenGdprRequests");

app.MapPost("/api/payments/intents", async (CreatePaymentIntentRequest request, IPaymentService paymentService, CancellationToken token)
        => Results.Ok(await paymentService.CreatePaymentIntentAsync(request, token)))
    .WithName("CreatePaymentIntent");

app.MapPost("/api/payments/webhook", async (HttpContext context, IPaymentService paymentService, CancellationToken token) =>
    {
        using var reader = new StreamReader(context.Request.Body);
        var payload = await reader.ReadToEndAsync();
        if (!context.Request.Headers.TryGetValue("Stripe-Signature", out var signature))
        {
            return Results.BadRequest("Missing Stripe signature");
        }

        await paymentService.HandleWebhookAsync(payload, signature.ToString(), token);
        return Results.Ok();
    })
    .WithName("HandleStripeWebhook");

app.MapPost("/api/fraud/signals", async (RecordFraudSignalRequest request, IFraudService fraudService, CancellationToken token) =>
    {
        await fraudService.RecordSignalAsync(request, token);
        return Results.Accepted();
    })
    .WithName("RecordFraudSignal");

app.Run();
