using SimpleSmartMail.Models.Entities;

namespace SimpleSmartMail.Data.Repositories;

public interface ITrackingRepository
{
    Task<int> RecordEmailOpenAsync(Guid trackingId, string? ipAddress, string? userAgent);
    Task<int> RecordEmailClickAsync(EmailClick click);
    Task<List<EmailClick>> GetClicksByEmailIdAsync(int emailId);
    Task<List<EmailClick>> GetClicksByCampaignIdAsync(int campaignId);
    Task<int> AddUnsubscribeRequestAsync(UnsubscribeRequest request);
    Task<bool> IsUnsubscribedAsync(string emailAddress, string tenantId);
    Task<List<UnsubscribeRequest>> GetUnsubscribesByTenantIdAsync(string tenantId);
}
