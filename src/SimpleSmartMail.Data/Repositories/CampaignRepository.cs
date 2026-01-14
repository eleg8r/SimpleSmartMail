using System.Data;
using System.Data.SqlClient;
using System.Text.Json;
using Microsoft.Extensions.Configuration;
using SimpleSmartMail.Data.Common;
using SimpleSmartMail.Models.Entities;
using SimpleSmartMail.Models.Enums;

namespace SimpleSmartMail.Data.Repositories;

public class CampaignRepository : BaseRepository, ICampaignRepository
{
    public CampaignRepository(IConfiguration configuration) : base(configuration)
    {
    }

    public async Task<int> CreateAsync(EmailCampaign campaign)
    {
        var parameters = new[]
        {
            new SqlParameter("@Name", campaign.Name),
            new SqlParameter("@Description", campaign.Description),
            new SqlParameter("@Status", (int)campaign.Status),
            new SqlParameter("@FromAddress", campaign.FromAddress),
            new SqlParameter("@FromName", campaign.FromName),
            new SqlParameter("@Subject", campaign.Subject),
            new SqlParameter("@HtmlTemplate", campaign.HtmlTemplate),
            new SqlParameter("@TextTemplate", (object?)campaign.TextTemplate ?? DBNull.Value),
            new SqlParameter("@ScheduledStartDate", (object?)campaign.ScheduledStartDate ?? DBNull.Value),
            new SqlParameter("@BatchSize", (object?)campaign.BatchSize ?? DBNull.Value),
            new SqlParameter("@MaxEmailsPerHour", (object?)campaign.MaxEmailsPerHour ?? DBNull.Value),
            new SqlParameter("@EnableOpenTracking", campaign.EnableOpenTracking),
            new SqlParameter("@EnableClickTracking", campaign.EnableClickTracking),
            new SqlParameter("@TotalRecipients", campaign.TotalRecipients),
            new SqlParameter("@CreatedBy", campaign.CreatedBy)
        };

        var campaignId = await ExecuteScalarAsync<int>("[emailCampaign].[sp_Campaign_Create]", parameters);
        return campaignId;
    }

    public async Task<EmailCampaign?> GetByIdAsync(int id)
    {
        var parameters = new[]
        {
            new SqlParameter("@CampaignId", id)
        };

        using var connection = CreateConnection();
        using var command = new SqlCommand("[emailCampaign].[sp_Campaign_GetById]", connection)
        {
            CommandType = CommandType.StoredProcedure
        };
        command.Parameters.AddRange(parameters);

        await connection.OpenAsync();
        using var reader = await command.ExecuteReaderAsync();

        if (await reader.ReadAsync())
        {
            return MapCampaignFromReader(reader);
        }

        return null;
    }

    public async Task<List<EmailCampaign>> GetAllAsync(int pageNumber = 1, int pageSize = 50)
    {
        var parameters = new[]
        {
            new SqlParameter("@PageNumber", pageNumber),
            new SqlParameter("@PageSize", pageSize)
        };

        var campaigns = new List<EmailCampaign>();

        using var connection = CreateConnection();
        using var command = new SqlCommand("[emailCampaign].[sp_Campaign_GetAll]", connection)
        {
            CommandType = CommandType.StoredProcedure
        };
        command.Parameters.AddRange(parameters);

        await connection.OpenAsync();
        using var reader = await command.ExecuteReaderAsync();

        while (await reader.ReadAsync())
        {
            campaigns.Add(MapCampaignFromReader(reader));
        }

        return campaigns;
    }

    public async Task UpdateAsync(EmailCampaign campaign)
    {
        var parameters = new[]
        {
            new SqlParameter("@CampaignId", campaign.Id),
            new SqlParameter("@Name", campaign.Name),
            new SqlParameter("@Description", campaign.Description),
            new SqlParameter("@Status", (int)campaign.Status),
            new SqlParameter("@ScheduledStartDate", (object?)campaign.ScheduledStartDate ?? DBNull.Value),
            new SqlParameter("@StartedAt", (object?)campaign.StartedAt ?? DBNull.Value),
            new SqlParameter("@CompletedAt", (object?)campaign.CompletedAt ?? DBNull.Value),
            new SqlParameter("@UpdatedBy", campaign.UpdatedBy ?? string.Empty)
        };

        await ExecuteNonQueryAsync("[emailCampaign].[sp_Campaign_Update]", parameters);
    }

    public async Task UpdateStatisticsAsync(int campaignId, int emailsSent, int emailsDelivered,
        int emailsOpened, int emailsClicked, int emailsFailed)
    {
        var parameters = new[]
        {
            new SqlParameter("@CampaignId", campaignId),
            new SqlParameter("@EmailsSent", emailsSent),
            new SqlParameter("@EmailsDelivered", emailsDelivered),
            new SqlParameter("@EmailsOpened", emailsOpened),
            new SqlParameter("@EmailsClicked", emailsClicked),
            new SqlParameter("@EmailsFailed", emailsFailed)
        };

        await ExecuteNonQueryAsync("[emailCampaign].[sp_Campaign_UpdateStatistics]", parameters);
    }

    public async Task AddRecipientAsync(CampaignRecipient recipient)
    {
        var parameters = new[]
        {
            new SqlParameter("@CampaignId", recipient.CampaignId),
            new SqlParameter("@EmailAddress", recipient.EmailAddress),
            new SqlParameter("@RecipientName", (object?)recipient.RecipientName ?? DBNull.Value),
            new SqlParameter("@PersonalizationData", (object?)recipient.PersonalizationData ?? DBNull.Value)
        };

        await ExecuteNonQueryAsync("[emailCampaign].[sp_CampaignRecipient_Create]", parameters);
    }

    public async Task<List<CampaignRecipient>> GetRecipientsAsync(int campaignId)
    {
        var parameters = new[]
        {
            new SqlParameter("@CampaignId", campaignId)
        };

        var recipients = new List<CampaignRecipient>();

        using var connection = CreateConnection();
        using var command = new SqlCommand("[emailCampaign].[sp_CampaignRecipient_GetByCampaignId]", connection)
        {
            CommandType = CommandType.StoredProcedure
        };
        command.Parameters.AddRange(parameters);

        await connection.OpenAsync();
        using var reader = await command.ExecuteReaderAsync();

        while (await reader.ReadAsync())
        {
            recipients.Add(MapRecipientFromReader(reader));
        }

        return recipients;
    }

    public async Task UpdateRecipientAsync(CampaignRecipient recipient)
    {
        var parameters = new[]
        {
            new SqlParameter("@RecipientId", recipient.Id),
            new SqlParameter("@EmailId", (object?)recipient.EmailId ?? DBNull.Value),
            new SqlParameter("@Sent", recipient.Sent),
            new SqlParameter("@SentAt", (object?)recipient.SentAt ?? DBNull.Value)
        };

        await ExecuteNonQueryAsync("[emailCampaign].[sp_CampaignRecipient_Update]", parameters);
    }

    public async Task AddProgramAsync(int campaignId, int programId, string createdBy)
    {
        var parameters = new[]
        {
            new SqlParameter("@EmailCampaignId", campaignId),
            new SqlParameter("@ProgramId", programId),
            new SqlParameter("@CreatedBy", createdBy)
        };

        await ExecuteNonQueryAsync("[emailCampaign].[sp_EmailCampaignPrograms_AddProgram]", parameters);
    }

    public async Task RemoveProgramAsync(int campaignId, int programId)
    {
        var parameters = new[]
        {
            new SqlParameter("@EmailCampaignId", campaignId),
            new SqlParameter("@ProgramId", programId)
        };

        await ExecuteNonQueryAsync("[emailCampaign].[sp_EmailCampaignPrograms_RemoveProgram]", parameters);
    }

    public async Task<List<EmailCampaignProgram>> GetProgramsByCampaignIdAsync(int campaignId)
    {
        var parameters = new[]
        {
            new SqlParameter("@EmailCampaignId", campaignId)
        };

        var programs = new List<EmailCampaignProgram>();

        using var connection = CreateConnection();
        using var command = new SqlCommand("[emailCampaign].[sp_EmailCampaignPrograms_GetByCampaignId]", connection)
        {
            CommandType = CommandType.StoredProcedure
        };
        command.Parameters.AddRange(parameters);

        await connection.OpenAsync();
        using var reader = await command.ExecuteReaderAsync();

        while (await reader.ReadAsync())
        {
            programs.Add(new EmailCampaignProgram
            {
                EmailCampaignId = reader.GetInt32("EmailCampaignId"),
                ProgramId = reader.GetInt32("ProgramId"),
                CreatedAtUtc = reader.GetDateTime("CreatedAtUtc"),
                UpdatedAtUtc = reader.IsDBNull("UpdatedAtUtc") ? null : reader.GetDateTime("UpdatedAtUtc"),
                CreatedBy = reader.GetString("CreatedBy"),
                UpdatedBy = reader.IsDBNull("UpdatedBy") ? null : reader.GetString("UpdatedBy")
            });
        }

        return programs;
    }

    public async Task<List<EmailCampaign>> GetCampaignsByProgramIdAsync(int programId)
    {
        var parameters = new[]
        {
            new SqlParameter("@ProgramId", programId)
        };

        var campaigns = new List<EmailCampaign>();

        using var connection = CreateConnection();
        using var command = new SqlCommand("[emailCampaign].[sp_EmailCampaignPrograms_GetByProgramId]", connection)
        {
            CommandType = CommandType.StoredProcedure
        };
        command.Parameters.AddRange(parameters);

        await connection.OpenAsync();
        using var reader = await command.ExecuteReaderAsync();

        while (await reader.ReadAsync())
        {
            campaigns.Add(MapCampaignFromReader(reader));
        }

        return campaigns;
    }

    private EmailCampaign MapCampaignFromReader(SqlDataReader reader)
    {
        return new EmailCampaign
        {
            Id = reader.GetInt32("Id"),
            Name = reader.GetString("Name"),
            Description = reader.GetString("Description"),
            Status = (CampaignStatus)reader.GetInt32("Status"),
            FromAddress = reader.GetString("FromAddress"),
            FromName = reader.GetString("FromName"),
            Subject = reader.GetString("Subject"),
            HtmlTemplate = reader.GetString("HtmlTemplate"),
            TextTemplate = reader.IsDBNull("TextTemplate") ? null : reader.GetString("TextTemplate"),
            ScheduledStartDate = reader.IsDBNull("ScheduledStartDate") ? null : reader.GetDateTime("ScheduledStartDate"),
            BatchSize = reader.IsDBNull("BatchSize") ? null : reader.GetInt32("BatchSize"),
            MaxEmailsPerHour = reader.IsDBNull("MaxEmailsPerHour") ? null : reader.GetInt32("MaxEmailsPerHour"),
            EnableOpenTracking = reader.GetBoolean("EnableOpenTracking"),
            EnableClickTracking = reader.GetBoolean("EnableClickTracking"),
            TotalRecipients = reader.GetInt32("TotalRecipients"),
            EmailsSent = reader.GetInt32("EmailsSent"),
            EmailsDelivered = reader.GetInt32("EmailsDelivered"),
            EmailsOpened = reader.GetInt32("EmailsOpened"),
            EmailsClicked = reader.GetInt32("EmailsClicked"),
            EmailsFailed = reader.GetInt32("EmailsFailed"),
            StartedAt = reader.IsDBNull("StartedAt") ? null : reader.GetDateTime("StartedAt"),
            CompletedAt = reader.IsDBNull("CompletedAt") ? null : reader.GetDateTime("CompletedAt"),
            CreatedAt = reader.GetDateTime("CreatedAt"),
            UpdatedAt = reader.IsDBNull("UpdatedAt") ? null : reader.GetDateTime("UpdatedAt"),
            CreatedBy = reader.GetString("CreatedBy"),
            UpdatedBy = reader.IsDBNull("UpdatedBy") ? null : reader.GetString("UpdatedBy")
        };
    }

    private CampaignRecipient MapRecipientFromReader(SqlDataReader reader)
    {
        return new CampaignRecipient
        {
            Id = reader.GetInt32("Id"),
            CampaignId = reader.GetInt32("CampaignId"),
            EmailAddress = reader.GetString("EmailAddress"),
            RecipientName = reader.IsDBNull("RecipientName") ? null : reader.GetString("RecipientName"),
            PersonalizationData = reader.IsDBNull("PersonalizationData") ? null : reader.GetString("PersonalizationData"),
            EmailId = reader.IsDBNull("EmailId") ? null : reader.GetInt32("EmailId"),
            Sent = reader.GetBoolean("Sent"),
            SentAt = reader.IsDBNull("SentAt") ? null : reader.GetDateTime("SentAt")
        };
    }
}
