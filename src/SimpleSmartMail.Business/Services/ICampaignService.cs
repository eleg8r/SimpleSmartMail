using SimpleSmartMail.Models.DTOs;
using SimpleSmartMail.Models.Entities;
using SimpleSmartMail.Models.Enums;

namespace SimpleSmartMail.Business.Services;

public interface ICampaignService
{
    Task<int> CreateCampaignAsync(CreateCampaignRequest request);
    Task<EmailCampaign?> GetCampaignByIdAsync(int id);
    Task<List<EmailCampaign>> GetCampaignsByTenantIdAsync(string tenantId);
    Task UpdateCampaignStatusAsync(int campaignId, CampaignStatus status);
    Task StartCampaignAsync(int campaignId);
}
