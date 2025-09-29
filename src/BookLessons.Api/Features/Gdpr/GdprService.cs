using System.Text.Json;
using BookLessons.Api.Contracts.Gdpr;
using BookLessons.Api.Data;
using BookLessons.Api.Models;
using BookLessons.Api.Services;
using Microsoft.EntityFrameworkCore;

namespace BookLessons.Api.Features.Gdpr;

public class GdprService(AppDbContext dbContext, IClock clock) : IGdprService
{
    public async Task<DataSubjectRequest> CreateExportRequestAsync(CreateDataSubjectRequest request, CancellationToken cancellationToken)
    {
        var entity = new DataExportRequest
        {
            Id = Guid.NewGuid(),
            UserId = request.UserId,
            Status = "pending",
            RequestedAt = clock.UtcNow,
            ProcessedAt = null,
            ExportLocation = null,
            Notes = request.Notes
        };

        dbContext.DataExportRequests.Add(entity);
        dbContext.GdprAuditEvents.Add(new GdprAuditEvent
        {
            Id = Guid.NewGuid(),
            ActorId = request.UserId,
            EventType = "export_requested",
            Details = JsonSerializer.Serialize(new
            {
                notes = request.Notes
            }),
            HappenedAt = clock.UtcNow,
            Actor = "data_subject"
        });

        await dbContext.SaveChangesAsync(cancellationToken);

        return Map(entity, null);
    }

    public async Task<DataSubjectRequest> CreateErasureRequestAsync(CreateDataSubjectRequest request, CancellationToken cancellationToken)
    {
        var entity = new DataErasureRequest
        {
            Id = Guid.NewGuid(),
            UserId = request.UserId,
            Status = "pending",
            RequestedAt = clock.UtcNow,
            CompletedAt = null,
            Notes = request.Notes
        };

        dbContext.DataErasureRequests.Add(entity);
        dbContext.GdprAuditEvents.Add(new GdprAuditEvent
        {
            Id = Guid.NewGuid(),
            ActorId = request.UserId,
            EventType = "erasure_requested",
            Details = JsonSerializer.Serialize(new
            {
                notes = request.Notes
            }),
            HappenedAt = clock.UtcNow,
            Actor = "data_subject"
        });

        await dbContext.SaveChangesAsync(cancellationToken);

        return Map(null, entity);
    }

    public async Task<DataSubjectRequest?> CompleteRequestAsync(Guid requestId, string? exportLocation, CancellationToken cancellationToken)
    {
        var export = await dbContext.DataExportRequests.FirstOrDefaultAsync(r => r.Id == requestId, cancellationToken);
        if (export is not null)
        {
            export.Status = "completed";
            export.ProcessedAt = clock.UtcNow;
            export.ExportLocation = exportLocation;
            await dbContext.SaveChangesAsync(cancellationToken);
            return Map(export, null);
        }

        var erasure = await dbContext.DataErasureRequests.FirstOrDefaultAsync(r => r.Id == requestId, cancellationToken);
        if (erasure is not null)
        {
            erasure.Status = "completed";
            erasure.CompletedAt = clock.UtcNow;
            await dbContext.SaveChangesAsync(cancellationToken);
            return Map(null, erasure);
        }

        return null;
    }

    public async Task<IReadOnlyList<DataSubjectRequest>> GetOpenRequestsAsync(CancellationToken cancellationToken)
    {
        var exports = await dbContext.DataExportRequests
            .AsNoTracking()
            .Where(r => r.Status != "completed")
            .Select(r => Map(r, null))
            .ToListAsync(cancellationToken);

        var erasures = await dbContext.DataErasureRequests
            .AsNoTracking()
            .Where(r => r.Status != "completed")
            .Select(r => Map(null, r))
            .ToListAsync(cancellationToken);

        return exports.Concat(erasures).OrderBy(r => r.RequestedAt).ToList();
    }

    private static DataSubjectRequest Map(DataExportRequest? export, DataErasureRequest? erasure)
    {
        if (export is not null)
        {
            return new DataSubjectRequest(export.Id, export.UserId, export.Status, export.RequestedAt, export.ProcessedAt, export.ExportLocation, export.Notes);
        }

        if (erasure is not null)
        {
            return new DataSubjectRequest(erasure.Id, erasure.UserId, erasure.Status, erasure.RequestedAt, erasure.CompletedAt, null, erasure.Notes);
        }

        throw new InvalidOperationException("Unable to map GDPR request.");
    }
}
