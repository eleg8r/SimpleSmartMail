using System.Data;
using System.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using SimpleSmartMail.Data.Common;
using SimpleSmartMail.Models.Entities;
using SimpleSmartMail.Models.Enums;

namespace SimpleSmartMail.Data.Repositories;

public class EmailRepository : BaseRepository, IEmailRepository
{
    public EmailRepository(IConfiguration configuration) : base(configuration)
    {
    }

    public async Task<int> CreateAsync(Email email)
    {
        var parameters = new[]
        {
            new SqlParameter("@FromAddress", email.FromAddress),
            new SqlParameter("@FromName", email.FromName),
            new SqlParameter("@ToAddress", email.ToAddress),
            new SqlParameter("@ToName", email.ToName),
            new SqlParameter("@Cc", (object?)email.Cc ?? DBNull.Value),
            new SqlParameter("@Bcc", (object?)email.Bcc ?? DBNull.Value),
            new SqlParameter("@Subject", email.Subject),
            new SqlParameter("@HtmlBody", email.HtmlBody),
            new SqlParameter("@TextBody", (object?)email.TextBody ?? DBNull.Value),
            new SqlParameter("@Status", (int)email.Status),
            new SqlParameter("@CampaignId", (object?)email.CampaignId ?? DBNull.Value),
            new SqlParameter("@TrackingId", email.TrackingId),
            new SqlParameter("@OpenTracked", email.OpenTracked),
            new SqlParameter("@ClickTracked", email.ClickTracked),
            new SqlParameter("@ScheduledAt", (object?)email.ScheduledAt ?? DBNull.Value),
            new SqlParameter("@ProviderUsed", (object?)email.ProviderUsed ?? DBNull.Value),
            new SqlParameter("@Metadata", (object?)email.Metadata ?? DBNull.Value),
            new SqlParameter("@IsValid", email.IsValid)
        };

        var emailId = await ExecuteScalarAsync<int>("[emailCampaign].[sp_Email_Create]", parameters);
        return emailId;
    }

    public async Task<Email?> GetByIdAsync(int id)
    {
        var parameters = new[]
        {
            new SqlParameter("@EmailId", id)
        };

        using var connection = CreateConnection();
        using var command = new SqlCommand("[emailCampaign].[sp_Email_GetById]", connection)
        {
            CommandType = CommandType.StoredProcedure
        };
        command.Parameters.AddRange(parameters);

        await connection.OpenAsync();
        using var reader = await command.ExecuteReaderAsync();

        if (await reader.ReadAsync())
        {
            return MapEmailFromReader(reader);
        }

        return null;
    }

    public async Task<Email?> GetByTrackingIdAsync(Guid trackingId)
    {
        var parameters = new[]
        {
            new SqlParameter("@TrackingId", trackingId)
        };

        using var connection = CreateConnection();
        using var command = new SqlCommand("[emailCampaign].[sp_Email_GetByTrackingId]", connection)
        {
            CommandType = CommandType.StoredProcedure
        };
        command.Parameters.AddRange(parameters);

        await connection.OpenAsync();
        using var reader = await command.ExecuteReaderAsync();

        if (await reader.ReadAsync())
        {
            return MapEmailFromReader(reader);
        }

        return null;
    }

    public async Task<List<Email>> GetAllAsync(int pageNumber = 1, int pageSize = 50)
    {
        var parameters = new[]
        {
            new SqlParameter("@PageNumber", pageNumber),
            new SqlParameter("@PageSize", pageSize)
        };

        var emails = new List<Email>();

        using var connection = CreateConnection();
        using var command = new SqlCommand("[emailCampaign].[sp_Email_GetAll]", connection)
        {
            CommandType = CommandType.StoredProcedure
        };
        command.Parameters.AddRange(parameters);

        await connection.OpenAsync();
        using var reader = await command.ExecuteReaderAsync();

        while (await reader.ReadAsync())
        {
            emails.Add(MapEmailFromReader(reader));
        }

        return emails;
    }

    public async Task UpdateAsync(Email email)
    {
        var parameters = new[]
        {
            new SqlParameter("@EmailId", email.Id),
            new SqlParameter("@Status", (int)email.Status),
            new SqlParameter("@OpenTracked", email.OpenTracked),
            new SqlParameter("@OpenedAt", (object?)email.OpenedAt ?? DBNull.Value),
            new SqlParameter("@OpenCount", email.OpenCount),
            new SqlParameter("@ClickTracked", email.ClickTracked),
            new SqlParameter("@FirstClickedAt", (object?)email.FirstClickedAt ?? DBNull.Value),
            new SqlParameter("@ClickCount", email.ClickCount),
            new SqlParameter("@SentAt", (object?)email.SentAt ?? DBNull.Value),
            new SqlParameter("@DeliveredAt", (object?)email.DeliveredAt ?? DBNull.Value),
            new SqlParameter("@ErrorMessage", (object?)email.ErrorMessage ?? DBNull.Value),
            new SqlParameter("@RetryCount", email.RetryCount),
            new SqlParameter("@ProviderUsed", (object?)email.ProviderUsed ?? DBNull.Value),
            new SqlParameter("@IsValid", email.IsValid)
        };

        await ExecuteNonQueryAsync("[emailCampaign].[sp_Email_Update]", parameters);
    }

    public async Task UpdateStatusAsync(int emailId, EmailStatus status)
    {
        var parameters = new[]
        {
            new SqlParameter("@EmailId", emailId),
            new SqlParameter("@Status", (int)status)
        };

        await ExecuteNonQueryAsync("[emailCampaign].[sp_Email_UpdateStatus]", parameters);
    }

    public async Task AddAttachmentAsync(EmailAttachment attachment)
    {
        var parameters = new[]
        {
            new SqlParameter("@EmailId", attachment.EmailId),
            new SqlParameter("@FileName", attachment.FileName),
            new SqlParameter("@ContentType", attachment.ContentType),
            new SqlParameter("@SizeInBytes", attachment.SizeInBytes),
            new SqlParameter("@Content", attachment.Content)
        };

        await ExecuteNonQueryAsync("[emailCampaign].[sp_EmailAttachment_Create]", parameters);
    }

    private Email MapEmailFromReader(SqlDataReader reader)
    {
        return new Email
        {
            Id = reader.GetInt32("Id"),
            FromAddress = reader.GetString("FromAddress"),
            FromName = reader.GetString("FromName"),
            ToAddress = reader.GetString("ToAddress"),
            ToName = reader.GetString("ToName"),
            Cc = reader.IsDBNull("Cc") ? null : reader.GetString("Cc"),
            Bcc = reader.IsDBNull("Bcc") ? null : reader.GetString("Bcc"),
            Subject = reader.GetString("Subject"),
            HtmlBody = reader.GetString("HtmlBody"),
            TextBody = reader.IsDBNull("TextBody") ? null : reader.GetString("TextBody"),
            Status = (EmailStatus)reader.GetInt32("Status"),
            CampaignId = reader.IsDBNull("CampaignId") ? null : reader.GetInt32("CampaignId"),
            TrackingId = reader.GetGuid("TrackingId"),
            OpenTracked = reader.GetBoolean("OpenTracked"),
            OpenedAt = reader.IsDBNull("OpenedAt") ? null : reader.GetDateTime("OpenedAt"),
            OpenCount = reader.GetInt32("OpenCount"),
            ClickTracked = reader.GetBoolean("ClickTracked"),
            FirstClickedAt = reader.IsDBNull("FirstClickedAt") ? null : reader.GetDateTime("FirstClickedAt"),
            ClickCount = reader.GetInt32("ClickCount"),
            ScheduledAt = reader.IsDBNull("ScheduledAt") ? null : reader.GetDateTime("ScheduledAt"),
            SentAt = reader.IsDBNull("SentAt") ? null : reader.GetDateTime("SentAt"),
            DeliveredAt = reader.IsDBNull("DeliveredAt") ? null : reader.GetDateTime("DeliveredAt"),
            ErrorMessage = reader.IsDBNull("ErrorMessage") ? null : reader.GetString("ErrorMessage"),
            RetryCount = reader.GetInt32("RetryCount"),
            ProviderUsed = reader.IsDBNull("ProviderUsed") ? null : reader.GetString("ProviderUsed"),
            Metadata = reader.IsDBNull("Metadata") ? null : reader.GetString("Metadata"),
            CreatedAt = reader.GetDateTime("CreatedAt"),
            UpdatedAt = reader.IsDBNull("UpdatedAt") ? null : reader.GetDateTime("UpdatedAt")
        };
    }
}
