using SimpleSmartMail.Data.Repositories;
using SimpleSmartMail.Models.DTOs;
using SimpleSmartMail.Models.Entities;

namespace SimpleSmartMail.Business.Services;

public class EmailTemplateService : IEmailTemplateService
{
    private readonly IEmailTemplateRepository _templateRepository;

    public EmailTemplateService(IEmailTemplateRepository templateRepository)
    {
        _templateRepository = templateRepository;
    }

    public async Task<int> CreateTemplateAsync(CreateTemplateRequest request)
    {
        var template = new EmailTemplate
        {
            TenantId = request.TenantId,
            Name = request.Name,
            Description = request.Description,
            Subject = request.Subject,
            HtmlTemplate = request.HtmlTemplate,
            TextTemplate = request.TextTemplate,
            IsActive = true,
            CreatedAt = DateTime.UtcNow,
            CreatedBy = request.CreatedBy
        };

        return await _templateRepository.CreateAsync(template);
    }

    public async Task<EmailTemplate?> GetTemplateByIdAsync(int id)
    {
        return await _templateRepository.GetByIdAsync(id);
    }

    public async Task<List<EmailTemplate>> GetTemplatesByTenantIdAsync(string tenantId)
    {
        return await _templateRepository.GetByTenantIdAsync(tenantId);
    }

    public async Task UpdateTemplateAsync(EmailTemplate template)
    {
        template.UpdatedAt = DateTime.UtcNow;
        await _templateRepository.UpdateAsync(template);
    }

    public async Task DeleteTemplateAsync(int id)
    {
        await _templateRepository.DeleteAsync(id);
    }
}
