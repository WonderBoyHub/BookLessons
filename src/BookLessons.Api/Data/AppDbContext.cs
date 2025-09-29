using BookLessons.Api.Models;
using Microsoft.EntityFrameworkCore;

namespace BookLessons.Api.Data;

public class AppDbContext(DbContextOptions<AppDbContext> options) : DbContext(options)
{
    public DbSet<User> Users => Set<User>();
    public DbSet<TutorProfile> TutorProfiles => Set<TutorProfile>();
    public DbSet<TutorAvailabilityPattern> TutorAvailabilityPatterns => Set<TutorAvailabilityPattern>();
    public DbSet<TutorAvailabilityOverride> TutorAvailabilityOverrides => Set<TutorAvailabilityOverride>();
    public DbSet<StudentProfile> StudentProfiles => Set<StudentProfile>();
    public DbSet<LessonBooking> LessonBookings => Set<LessonBooking>();
    public DbSet<LessonStatusHistory> LessonStatusHistory => Set<LessonStatusHistory>();
    public DbSet<ChatThread> ChatThreads => Set<ChatThread>();
    public DbSet<ChatMessage> ChatMessages => Set<ChatMessage>();
    public DbSet<ChatMessageReceipt> ChatMessageReceipts => Set<ChatMessageReceipt>();
    public DbSet<Payment> Payments => Set<Payment>();
    public DbSet<PaymentEvent> PaymentEvents => Set<PaymentEvent>();
    public DbSet<FraudSignal> FraudSignals => Set<FraudSignal>();
    public DbSet<FraudAlert> FraudAlerts => Set<FraudAlert>();
    public DbSet<AuditLogEntry> AuditLogEntries => Set<AuditLogEntry>();
    public DbSet<PrivacyConsent> PrivacyConsents => Set<PrivacyConsent>();
    public DbSet<DataExportRequest> DataExportRequests => Set<DataExportRequest>();
    public DbSet<DataErasureRequest> DataErasureRequests => Set<DataErasureRequest>();
    public DbSet<GdprProcessor> GdprProcessors => Set<GdprProcessor>();
    public DbSet<GdprAuditEvent> GdprAuditEvents => Set<GdprAuditEvent>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        modelBuilder.Entity<TutorProfile>().HasKey(p => p.UserId);
        modelBuilder.Entity<StudentProfile>().HasKey(p => p.UserId);

        modelBuilder.Entity<TutorProfile>()
            .HasMany(p => p.AvailabilityPatterns)
            .WithOne(p => p.TutorProfile!)
            .HasForeignKey(p => p.TutorProfileId);

        modelBuilder.Entity<TutorProfile>()
            .HasMany(p => p.AvailabilityOverrides)
            .WithOne(p => p.TutorProfile!)
            .HasForeignKey(p => p.TutorProfileId);

        modelBuilder.Entity<LessonBooking>()
            .HasMany(b => b.StatusHistory)
            .WithOne()
            .HasForeignKey(h => h.LessonBookingId);

        modelBuilder.Entity<LessonBooking>()
            .HasMany(b => b.Payments)
            .WithOne()
            .HasForeignKey(p => p.LessonBookingId);

        modelBuilder.Entity<ChatThread>()
            .HasMany(t => t.Messages)
            .WithOne()
            .HasForeignKey(m => m.ThreadId);

        modelBuilder.Entity<ChatMessage>()
            .HasMany(m => m.Receipts)
            .WithOne()
            .HasForeignKey(r => r.MessageId);

        modelBuilder.Entity<ChatMessageReceipt>()
            .HasKey(r => new { r.MessageId, r.RecipientId, r.ReceiptType });
    }
}
