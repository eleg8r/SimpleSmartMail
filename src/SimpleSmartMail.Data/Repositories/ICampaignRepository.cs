using SimpleSmartMail.Models.Entities;

namespace SimpleSmartMail.Data.Repositories;

public interface ICampaignRepository
{
    Task<int> CreateAsync(EmailCampaign campaign);
    Task<EmailCampaign?> GetByIdAsync(int id);
    Task<List<EmailCampaign>> GetAllAsync(int pageNumber = 1, int pageSize = 50);
    Task UpdateAsync(EmailCampaign campaign);
    Task UpdateStatisticsAsync(int campaignId, int emailsSent, int emailsDelivered, int emailsOpened, int emailsClicked, int emailsFailed);
    Task AddRecipientAsync(CampaignRecipient recipient);
    Task<List<CampaignRecipient>> GetRecipientsAsync(int campaignId);
    Task UpdateRecipientAsync(CampaignRecipient recipient);

    // EmailCampaignPrograms methods
    Task AddProgramAsync(int campaignId, int programId, string createdBy);
    Task RemoveProgramAsync(int campaignId, int programId);
    Task<List<EmailCampaignProgram>> GetProgramsByCampaignIdAsync(int campaignId);
    Task<List<EmailCampaign>> GetCampaignsByProgramIdAsync(int programId);
}
