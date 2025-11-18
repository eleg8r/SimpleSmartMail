using SimpleSmartMail.Models.Entities;

namespace SimpleSmartMail.Data.Repositories;

public interface IEmailRepository
{
    Task<int> CreateAsync(Email email);
    Task<Email?> GetByIdAsync(int id);
    Task<Email?> GetByTrackingIdAsync(Guid trackingId);
    Task<List<Email>> GetByTenantIdAsync(string tenantId, int pageNumber = 1, int pageSize = 50);
    Task UpdateAsync(Email email);
    Task UpdateStatusAsync(int emailId, Models.Enums.EmailStatus status);
    Task AddAttachmentAsync(EmailAttachment attachment);
}
