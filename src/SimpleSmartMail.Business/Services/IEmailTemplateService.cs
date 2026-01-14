using SimpleSmartMail.Models.DTOs;
using SimpleSmartMail.Models.Entities;

namespace SimpleSmartMail.Business.Services;

public interface IEmailTemplateService
{
    Task<int> CreateTemplateAsync(CreateTemplateRequest request);
    Task<EmailTemplate?> GetTemplateByIdAsync(int id);
    Task<List<EmailTemplate>> GetAllTemplatesAsync(bool activeOnly = false);
    Task UpdateTemplateAsync(EmailTemplate template);
    Task DeleteTemplateAsync(int id);
}
