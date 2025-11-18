using System.Data;
using System.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using SimpleSmartMail.Data.Common;
using SimpleSmartMail.Models.Entities;
using SimpleSmartMail.Models.Enums;

namespace SimpleSmartMail.Data.Repositories;

public class TenantRepository : BaseRepository, ITenantRepository
{
    public TenantRepository(IConfiguration configuration) : base(configuration)
    {
    }

    public async Task<int> CreateAsync(Tenant tenant)
    {
        var parameters = new[]
        {
            new SqlParameter("@TenantId", tenant.TenantId),
            new SqlParameter("@Name", tenant.Name),
            new SqlParameter("@Description", tenant.Description),
            new SqlParameter("@IsActive", tenant.IsActive),
            new SqlParameter("@DefaultEmailProvider", (int)tenant.DefaultEmailProvider),
            new SqlParameter("@MaxAttachmentSizeInMb", tenant.MaxAttachmentSizeInMb),
            new SqlParameter("@MaxEmailsPerHour", (object?)tenant.MaxEmailsPerHour ?? DBNull.Value),
            new SqlParameter("@MaxEmailsPerDay", (object?)tenant.MaxEmailsPerDay ?? DBNull.Value),
            new SqlParameter("@EnableOpenTracking", tenant.EnableOpenTracking),
            new SqlParameter("@EnableClickTracking", tenant.EnableClickTracking),
            new SqlParameter("@ApiKey", (object?)tenant.ApiKey ?? DBNull.Value),
            new SqlParameter("@ApiKeyExpiresAt", (object?)tenant.ApiKeyExpiresAt ?? DBNull.Value),
            new SqlParameter("@ContactEmail", (object?)tenant.ContactEmail ?? DBNull.Value),
            new SqlParameter("@ContactName", (object?)tenant.ContactName ?? DBNull.Value)
        };

        var tenantDbId = await ExecuteScalarAsync<int>("sp_Tenant_Create", parameters);
        return tenantDbId;
    }

    public async Task<Tenant?> GetByIdAsync(int id)
    {
        var parameters = new[]
        {
            new SqlParameter("@Id", id)
        };

        using var connection = CreateConnection();
        using var command = new SqlCommand("sp_Tenant_GetById", connection)
        {
            CommandType = CommandType.StoredProcedure
        };
        command.Parameters.AddRange(parameters);

        await connection.OpenAsync();
        using var reader = await command.ExecuteReaderAsync();

        if (await reader.ReadAsync())
        {
            return MapTenantFromReader(reader);
        }

        return null;
    }

    public async Task<Tenant?> GetByTenantIdAsync(string tenantId)
    {
        var parameters = new[]
        {
            new SqlParameter("@TenantId", tenantId)
        };

        using var connection = CreateConnection();
        using var command = new SqlCommand("sp_Tenant_GetByTenantId", connection)
        {
            CommandType = CommandType.StoredProcedure
        };
        command.Parameters.AddRange(parameters);

        await connection.OpenAsync();
        using var reader = await command.ExecuteReaderAsync();

        if (await reader.ReadAsync())
        {
            return MapTenantFromReader(reader);
        }

        return null;
    }

    public async Task<Tenant?> GetByApiKeyAsync(string apiKey)
    {
        var parameters = new[]
        {
            new SqlParameter("@ApiKey", apiKey)
        };

        using var connection = CreateConnection();
        using var command = new SqlCommand("sp_Tenant_GetByApiKey", connection)
        {
            CommandType = CommandType.StoredProcedure
        };
        command.Parameters.AddRange(parameters);

        await connection.OpenAsync();
        using var reader = await command.ExecuteReaderAsync();

        if (await reader.ReadAsync())
        {
            return MapTenantFromReader(reader);
        }

        return null;
    }

    public async Task UpdateAsync(Tenant tenant)
    {
        var parameters = new[]
        {
            new SqlParameter("@Id", tenant.Id),
            new SqlParameter("@Name", tenant.Name),
            new SqlParameter("@Description", tenant.Description),
            new SqlParameter("@IsActive", tenant.IsActive),
            new SqlParameter("@DefaultEmailProvider", (int)tenant.DefaultEmailProvider),
            new SqlParameter("@MaxAttachmentSizeInMb", tenant.MaxAttachmentSizeInMb),
            new SqlParameter("@MaxEmailsPerHour", (object?)tenant.MaxEmailsPerHour ?? DBNull.Value),
            new SqlParameter("@MaxEmailsPerDay", (object?)tenant.MaxEmailsPerDay ?? DBNull.Value),
            new SqlParameter("@EnableOpenTracking", tenant.EnableOpenTracking),
            new SqlParameter("@EnableClickTracking", tenant.EnableClickTracking),
            new SqlParameter("@ApiKey", (object?)tenant.ApiKey ?? DBNull.Value),
            new SqlParameter("@ApiKeyExpiresAt", (object?)tenant.ApiKeyExpiresAt ?? DBNull.Value),
            new SqlParameter("@ContactEmail", (object?)tenant.ContactEmail ?? DBNull.Value),
            new SqlParameter("@ContactName", (object?)tenant.ContactName ?? DBNull.Value)
        };

        await ExecuteNonQueryAsync("sp_Tenant_Update", parameters);
    }

    private Tenant MapTenantFromReader(SqlDataReader reader)
    {
        return new Tenant
        {
            Id = reader.GetInt32("Id"),
            TenantId = reader.GetString("TenantId"),
            Name = reader.GetString("Name"),
            Description = reader.GetString("Description"),
            IsActive = reader.GetBoolean("IsActive"),
            DefaultEmailProvider = (EmailProviderType)reader.GetInt32("DefaultEmailProvider"),
            MaxAttachmentSizeInMb = reader.GetInt32("MaxAttachmentSizeInMb"),
            MaxEmailsPerHour = reader.IsDBNull("MaxEmailsPerHour") ? null : reader.GetInt32("MaxEmailsPerHour"),
            MaxEmailsPerDay = reader.IsDBNull("MaxEmailsPerDay") ? null : reader.GetInt32("MaxEmailsPerDay"),
            EnableOpenTracking = reader.GetBoolean("EnableOpenTracking"),
            EnableClickTracking = reader.GetBoolean("EnableClickTracking"),
            ApiKey = reader.IsDBNull("ApiKey") ? null : reader.GetString("ApiKey"),
            ApiKeyCreatedAt = reader.IsDBNull("ApiKeyCreatedAt") ? null : reader.GetDateTime("ApiKeyCreatedAt"),
            ApiKeyExpiresAt = reader.IsDBNull("ApiKeyExpiresAt") ? null : reader.GetDateTime("ApiKeyExpiresAt"),
            ContactEmail = reader.IsDBNull("ContactEmail") ? null : reader.GetString("ContactEmail"),
            ContactName = reader.IsDBNull("ContactName") ? null : reader.GetString("ContactName"),
            CreatedAt = reader.GetDateTime("CreatedAt"),
            UpdatedAt = reader.IsDBNull("UpdatedAt") ? null : reader.GetDateTime("UpdatedAt")
        };
    }
}
