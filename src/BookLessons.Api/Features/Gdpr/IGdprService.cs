using BookLessons.Api.Contracts.Gdpr;

namespace BookLessons.Api.Features.Gdpr;

public interface IGdprService
{
    Task<DataSubjectRequest> CreateExportRequestAsync(CreateDataSubjectRequest request, CancellationToken cancellationToken);
    Task<DataSubjectRequest> CreateErasureRequestAsync(CreateDataSubjectRequest request, CancellationToken cancellationToken);
    Task<DataSubjectRequest?> CompleteRequestAsync(Guid requestId, string? exportLocation, CancellationToken cancellationToken);
    Task<IReadOnlyList<DataSubjectRequest>> GetOpenRequestsAsync(CancellationToken cancellationToken);
}
