using BookLessons.Api.Data;
using BookLessons.Api.Features.Bookings;
using BookLessons.Api.Features.Chat;
using BookLessons.Api.Features.Fraud;
using BookLessons.Api.Features.Gdpr;
using BookLessons.Api.Features.Payments;
using BookLessons.Api.Services;
using Microsoft.EntityFrameworkCore;
using Npgsql.EntityFrameworkCore.PostgreSQL;

namespace BookLessons.Api.Extensions;

public static class ServiceCollectionExtensions
{
    public static IServiceCollection AddBookLessonsServices(this IServiceCollection services, IConfiguration configuration)
    {
        services.AddDbContext<AppDbContext>(options =>
        {
            var connectionString = configuration.GetConnectionString("Default")
                ?? throw new InvalidOperationException("Connection string 'Default' is not configured.");
            options.UseNpgsql(connectionString)
                .UseSnakeCaseNamingConvention();
        });

        services.Configure<StripeOptions>(configuration.GetSection("Stripe"));
        services.Configure<SseOptions>(configuration.GetSection("Chat:Sse"));

        services.AddScoped<IClock, SystemClock>();
        services.AddScoped<IBookingService, BookingService>();
        services.AddScoped<IChatService, ChatService>();
        services.AddScoped<IFraudService, FraudService>();
        services.AddScoped<IGdprService, GdprService>();
        services.AddScoped<IPaymentService, PaymentService>();
        services.AddSingleton<IJitsiRoomNameFactory, JitsiRoomNameFactory>();

        return services;
    }
}
