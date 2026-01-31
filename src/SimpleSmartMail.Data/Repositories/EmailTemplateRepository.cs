using System.Data;
using System.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using SimpleSmartMail.Data.Common;
using SimpleSmartMail.Models.Entities;

namespace SimpleSmartMail.Data.Repositories;

public class EmailTemplateRepository : BaseRepository, IEmailTemplateRepository
{
    public EmailTemplateRepository(IConfiguration configuration) : base(configuration)
    {
    }

    public async Task<int> CreateAsync(EmailTemplate template)
    {
        var parameters = new[]
        {
            new SqlParameter("@Name", template.Name),
            new SqlParameter("@Description", template.Description),
            new SqlParameter("@Subject", template.Subject),
            new SqlParameter("@HtmlTemplate", template.HtmlTemplate),
            new SqlParameter("@TextTemplate", (object?)template.TextTemplate ?? DBNull.Value),
            new SqlParameter("@IsActive", template.IsActive),
            new SqlParameter("@CreatedBy", template.CreatedBy)
        };

        var templateId = await ExecuteScalarAsync<int>("[emailCampaign].[EmailTemplate_Create]", parameters);
        return templateId;
    }

    public async Task<EmailTemplate?> GetByIdAsync(int id)
    {
        var parameters = new[]
        {
            new SqlParameter("@TemplateId", id)
        };

        using var connection = CreateConnection();
        using var command = new SqlCommand("[emailCampaign].[EmailTemplate_GetById]", connection)
        {
            CommandType = CommandType.StoredProcedure
        };
        command.Parameters.AddRange(parameters);

        await connection.OpenAsync();
        using var reader = await command.ExecuteReaderAsync();

        if (await reader.ReadAsync())
        {
            return MapTemplateFromReader(reader);
        }

        return null;
    }

    public async Task<List<EmailTemplate>> GetAllAsync(bool activeOnly = false)
    {
        var parameters = new[]
        {
            new SqlParameter("@ActiveOnly", activeOnly)
        };

        var templates = new List<EmailTemplate>();

        using var connection = CreateConnection();
        using var command = new SqlCommand("[emailCampaign].[EmailTemplate_GetAll]", connection)
        {
            CommandType = CommandType.StoredProcedure
        };
        command.Parameters.AddRange(parameters);

        await connection.OpenAsync();
        using var reader = await command.ExecuteReaderAsync();

        while (await reader.ReadAsync())
        {
            templates.Add(MapTemplateFromReader(reader));
        }

        return templates;
    }

    public async Task UpdateAsync(EmailTemplate template)
    {
        var parameters = new[]
        {
            new SqlParameter("@TemplateId", template.Id),
            new SqlParameter("@Name", template.Name),
            new SqlParameter("@Description", template.Description),
            new SqlParameter("@Subject", template.Subject),
            new SqlParameter("@HtmlTemplate", template.HtmlTemplate),
            new SqlParameter("@TextTemplate", (object?)template.TextTemplate ?? DBNull.Value),
            new SqlParameter("@IsActive", template.IsActive),
            new SqlParameter("@UpdatedBy", template.UpdatedBy ?? string.Empty)
        };

        await ExecuteNonQueryAsync("[emailCampaign].[EmailTemplate_Update]", parameters);
    }

    public async Task DeleteAsync(int id)
    {
        var parameters = new[]
        {
            new SqlParameter("@TemplateId", id)
        };

        await ExecuteNonQueryAsync("[emailCampaign].[EmailTemplate_Delete]", parameters);
    }

    private EmailTemplate MapTemplateFromReader(SqlDataReader reader)
    {
        return new EmailTemplate
        {
            Id = reader.GetInt32("Id"),
            Name = reader.GetString("Name"),
            Description = reader.GetString("Description"),
            Subject = reader.GetString("Subject"),
            HtmlTemplate = reader.GetString("HtmlTemplate"),
            TextTemplate = reader.IsDBNull("TextTemplate") ? null : reader.GetString("TextTemplate"),
            IsActive = reader.GetBoolean("IsActive"),
            CreatedAt = reader.GetDateTime("CreatedAt"),
            UpdatedAt = reader.IsDBNull("UpdatedAt") ? null : reader.GetDateTime("UpdatedAt"),
            CreatedBy = reader.GetString("CreatedBy"),
            UpdatedBy = reader.IsDBNull("UpdatedBy") ? null : reader.GetString("UpdatedBy")
        };
    }
}
