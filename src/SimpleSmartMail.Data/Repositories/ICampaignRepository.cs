using SimpleSmartMail.Models.Entities;

namespace SimpleSmartMail.Data.Repositories;

public interface ICampaignRepository
{
    Task<int> CreateAsync(EmailCampaign campaign);
    Task<EmailCampaign?> GetByIdAsync(int id);
    Task<List<EmailCampaign>> GetByTenantIdAsync(string tenantId);
    Task UpdateAsync(EmailCampaign campaign);
    Task UpdateStatisticsAsync(int campaignId, int emailsSent, int emailsDelivered, int emailsOpened, int emailsClicked, int emailsFailed);
    Task AddRecipientAsync(CampaignRecipient recipient);
    Task<List<CampaignRecipient>> GetRecipientsAsync(int campaignId);
    Task UpdateRecipientAsync(CampaignRecipient recipient);
}
