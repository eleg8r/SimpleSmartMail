using SimpleSmartMail.Models.Entities;

namespace SimpleSmartMail.Data.Repositories;

public interface IEmailTemplateRepository
{
    Task<int> CreateAsync(EmailTemplate template);
    Task<EmailTemplate?> GetByIdAsync(int id);
    Task<List<EmailTemplate>> GetAllAsync(bool activeOnly = false);
    Task UpdateAsync(EmailTemplate template);
    Task DeleteAsync(int id);
}
