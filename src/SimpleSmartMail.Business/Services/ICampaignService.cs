using SimpleSmartMail.Models.DTOs;
using SimpleSmartMail.Models.Entities;
using SimpleSmartMail.Models.Enums;

namespace SimpleSmartMail.Business.Services;

public interface ICampaignService
{
    Task<int> CreateCampaignAsync(CreateCampaignRequest request);
    Task<EmailCampaign?> GetCampaignByIdAsync(int id);
    Task<List<EmailCampaign>> GetAllCampaignsAsync(int pageNumber = 1, int pageSize = 50);
    Task UpdateCampaignStatusAsync(int campaignId, CampaignStatus status);
    Task StartCampaignAsync(int campaignId);
    Task AddProgramToCampaignAsync(int campaignId, int programId, string createdBy);
    Task RemoveProgramFromCampaignAsync(int campaignId, int programId);
    Task<List<EmailCampaignProgram>> GetCampaignProgramsAsync(int campaignId);
    Task<List<EmailCampaign>> GetCampaignsByProgramIdAsync(int programId);
}
