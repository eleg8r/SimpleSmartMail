using SimpleSmartMail.Models.Entities;

namespace SimpleSmartMail.Business.Services;

public interface ITrackingService
{
    Task<int> RecordOpenAsync(Guid trackingId, string? ipAddress, string? userAgent);
    Task<int> RecordClickAsync(Guid trackingId, string url, string? ipAddress, string? userAgent);
    Task<string> InjectTrackingPixelAsync(string htmlBody, Guid trackingId, string baseUrl);
    Task<string> ReplaceLinksWithTrackedUrlsAsync(string htmlBody, Guid trackingId, string baseUrl);
    Task<string> InjectUnsubscribeLinkAsync(string htmlBody, Guid trackingId, string baseUrl);
    Task<string?> GetOriginalUrlAsync(Guid trackingId, string trackedUrl);
    Task<int> AddUnsubscribeRequestAsync(UnsubscribeRequest request);
    Task<bool> IsUnsubscribedAsync(string emailAddress, string tenantId);
    Task HandleBounceAsync(int emailId, string bounceReason);
    Task HandleSpamComplaintAsync(int emailId);
    Task<List<EmailClick>> GetClicksByEmailIdAsync(int emailId);
    Task<List<EmailClick>> GetClicksByCampaignIdAsync(int campaignId);
}
