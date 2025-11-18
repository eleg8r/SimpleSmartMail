using SimpleSmartMail.Models.Entities;

namespace SimpleSmartMail.Data.Repositories;

public interface ITenantRepository
{
    Task<int> CreateAsync(Tenant tenant);
    Task<Tenant?> GetByIdAsync(int id);
    Task<Tenant?> GetByTenantIdAsync(string tenantId);
    Task<Tenant?> GetByApiKeyAsync(string apiKey);
    Task UpdateAsync(Tenant tenant);
}
