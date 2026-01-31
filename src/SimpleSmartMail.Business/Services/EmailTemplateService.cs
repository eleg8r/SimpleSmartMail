using SimpleSmartMail.Data.Repositories;
using SimpleSmartMail.Models.DTOs;
using SimpleSmartMail.Models.Entities;

namespace SimpleSmartMail.Business.Services;

public class EmailTemplateService : IEmailTemplateService
{
    private readonly IEmailTemplateRepository templateRepository;

    public EmailTemplateService(IEmailTemplateRepository templateRepository)
    {
        this.templateRepository = templateRepository;
    }

    public async Task<int> CreateTemplateAsync(CreateTemplateRequest request)
    {
        var template = new EmailTemplate
        {
            Name = request.Name,
            Description = request.Description,
            Subject = request.Subject,
            HtmlTemplate = request.HtmlTemplate,
            TextTemplate = request.TextTemplate,
            IsActive = true,
            CreatedAt = DateTime.UtcNow,
            CreatedBy = request.CreatedBy
        };

        return await this.templateRepository.CreateAsync(template);
    }

    public async Task<EmailTemplate?> GetTemplateByIdAsync(int id)
    {
        return await this.templateRepository.GetByIdAsync(id);
    }

    public async Task<List<EmailTemplate>> GetAllTemplatesAsync(bool activeOnly = false)
    {
        return await this.templateRepository.GetAllAsync(activeOnly);
    }

    public async Task UpdateTemplateAsync(EmailTemplate template)
    {
        template.UpdatedAt = DateTime.UtcNow;
        await this.templateRepository.UpdateAsync(template);
    }

    public async Task DeleteTemplateAsync(int id)
    {
        await this.templateRepository.DeleteAsync(id);
    }
}
