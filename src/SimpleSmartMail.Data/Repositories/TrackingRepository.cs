using System.Data;
using System.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using SimpleSmartMail.Data.Common;
using SimpleSmartMail.Models.Entities;

namespace SimpleSmartMail.Data.Repositories;

public class TrackingRepository : BaseRepository, ITrackingRepository
{
    public TrackingRepository(IConfiguration configuration) : base(configuration)
    {
    }

    public async Task<int> RecordEmailOpenAsync(Guid trackingId, string? ipAddress, string? userAgent)
    {
        var parameters = new[]
        {
            new SqlParameter("@TrackingId", trackingId),
            new SqlParameter("@IpAddress", (object?)ipAddress ?? DBNull.Value),
            new SqlParameter("@UserAgent", (object?)userAgent ?? DBNull.Value)
        };

        var result = await ExecuteScalarAsync<int>("[emailCampaign].[sp_Tracking_RecordOpen]", parameters);
        return result;
    }

    public async Task<int> RecordEmailClickAsync(EmailClick click)
    {
        var parameters = new[]
        {
            new SqlParameter("@EmailId", click.EmailId),
            new SqlParameter("@CampaignId", (object?)click.CampaignId ?? DBNull.Value),
            new SqlParameter("@TrackingId", click.TrackingId),
            new SqlParameter("@RecipientEmail", click.RecipientEmail),
            new SqlParameter("@OriginalUrl", click.OriginalUrl),
            new SqlParameter("@TrackedUrl", click.TrackedUrl),
            new SqlParameter("@IpAddress", (object?)click.IpAddress ?? DBNull.Value),
            new SqlParameter("@UserAgent", (object?)click.UserAgent ?? DBNull.Value),
            new SqlParameter("@Country", (object?)click.Country ?? DBNull.Value),
            new SqlParameter("@City", (object?)click.City ?? DBNull.Value),
            new SqlParameter("@Device", (object?)click.Device ?? DBNull.Value)
        };

        var clickId = await ExecuteScalarAsync<int>("[emailCampaign].[sp_Tracking_RecordClick]", parameters);
        return clickId;
    }

    public async Task<List<EmailClick>> GetClicksByEmailIdAsync(int emailId)
    {
        var parameters = new[]
        {
            new SqlParameter("@EmailId", emailId)
        };

        var clicks = new List<EmailClick>();

        using var connection = CreateConnection();
        using var command = new SqlCommand("[emailCampaign].[sp_Tracking_GetClicksByEmailId]", connection)
        {
            CommandType = CommandType.StoredProcedure
        };
        command.Parameters.AddRange(parameters);

        await connection.OpenAsync();
        using var reader = await command.ExecuteReaderAsync();

        while (await reader.ReadAsync())
        {
            clicks.Add(MapClickFromReader(reader));
        }

        return clicks;
    }

    public async Task<List<EmailClick>> GetClicksByCampaignIdAsync(int campaignId)
    {
        var parameters = new[]
        {
            new SqlParameter("@CampaignId", campaignId)
        };

        var clicks = new List<EmailClick>();

        using var connection = CreateConnection();
        using var command = new SqlCommand("[emailCampaign].[sp_Tracking_GetClicksByCampaignId]", connection)
        {
            CommandType = CommandType.StoredProcedure
        };
        command.Parameters.AddRange(parameters);

        await connection.OpenAsync();
        using var reader = await command.ExecuteReaderAsync();

        while (await reader.ReadAsync())
        {
            clicks.Add(MapClickFromReader(reader));
        }

        return clicks;
    }

    public async Task<int> AddUnsubscribeRequestAsync(UnsubscribeRequest request)
    {
        var parameters = new[]
        {
            new SqlParameter("@EmailAddress", request.EmailAddress),
            new SqlParameter("@ProgramId", (object?)request.ProgramId ?? DBNull.Value),
            new SqlParameter("@CampaignId", (object?)request.CampaignId ?? DBNull.Value),
            new SqlParameter("@EmailId", (object?)request.EmailId ?? DBNull.Value),
            new SqlParameter("@TrackingId", (object?)request.TrackingId ?? DBNull.Value),
            new SqlParameter("@Reason", (object?)request.Reason ?? DBNull.Value),
            new SqlParameter("@IpAddress", (object?)request.IpAddress ?? DBNull.Value),
            new SqlParameter("@UserAgent", (object?)request.UserAgent ?? DBNull.Value)
        };

        var requestId = await ExecuteScalarAsync<int>("[emailCampaign].[sp_Unsubscribe_Create]", parameters);
        return requestId;
    }

    public async Task<bool> IsUnsubscribedAsync(string emailAddress, int? programId)
    {
        var parameters = new[]
        {
            new SqlParameter("@EmailAddress", emailAddress),
            new SqlParameter("@ProgramId", (object?)programId ?? DBNull.Value)
        };

        var result = await ExecuteScalarAsync<int>("[emailCampaign].[sp_Unsubscribe_IsUnsubscribed]", parameters);
        return result > 0;
    }

    public async Task<List<UnsubscribeRequest>> GetUnsubscribesByProgramIdAsync(int? programId)
    {
        var parameters = new[]
        {
            new SqlParameter("@ProgramId", (object?)programId ?? DBNull.Value)
        };

        var requests = new List<UnsubscribeRequest>();

        using var connection = CreateConnection();
        using var command = new SqlCommand("[emailCampaign].[sp_Unsubscribe_GetByProgramId]", connection)
        {
            CommandType = CommandType.StoredProcedure
        };
        command.Parameters.AddRange(parameters);

        await connection.OpenAsync();
        using var reader = await command.ExecuteReaderAsync();

        while (await reader.ReadAsync())
        {
            requests.Add(MapUnsubscribeFromReader(reader));
        }

        return requests;
    }

    public async Task<List<UnsubscribeRequest>> GetAllUnsubscribesAsync(int pageNumber = 1, int pageSize = 50)
    {
        var parameters = new[]
        {
            new SqlParameter("@PageNumber", pageNumber),
            new SqlParameter("@PageSize", pageSize)
        };

        var requests = new List<UnsubscribeRequest>();

        using var connection = CreateConnection();
        using var command = new SqlCommand("[emailCampaign].[sp_Unsubscribe_GetAll]", connection)
        {
            CommandType = CommandType.StoredProcedure
        };
        command.Parameters.AddRange(parameters);

        await connection.OpenAsync();
        using var reader = await command.ExecuteReaderAsync();

        while (await reader.ReadAsync())
        {
            requests.Add(MapUnsubscribeFromReader(reader));
        }

        return requests;
    }

    private EmailClick MapClickFromReader(SqlDataReader reader)
    {
        return new EmailClick
        {
            Id = reader.GetInt32("Id"),
            EmailId = reader.GetInt32("EmailId"),
            CampaignId = reader.IsDBNull("CampaignId") ? null : reader.GetInt32("CampaignId"),
            TrackingId = reader.GetGuid("TrackingId"),
            RecipientEmail = reader.GetString("RecipientEmail"),
            OriginalUrl = reader.GetString("OriginalUrl"),
            TrackedUrl = reader.GetString("TrackedUrl"),
            ClickedAt = reader.GetDateTime("ClickedAt"),
            IpAddress = reader.IsDBNull("IpAddress") ? null : reader.GetString("IpAddress"),
            UserAgent = reader.IsDBNull("UserAgent") ? null : reader.GetString("UserAgent"),
            Country = reader.IsDBNull("Country") ? null : reader.GetString("Country"),
            City = reader.IsDBNull("City") ? null : reader.GetString("City"),
            Device = reader.IsDBNull("Device") ? null : reader.GetString("Device")
        };
    }

    private UnsubscribeRequest MapUnsubscribeFromReader(SqlDataReader reader)
    {
        return new UnsubscribeRequest
        {
            Id = reader.GetInt32("Id"),
            EmailAddress = reader.GetString("EmailAddress"),
            ProgramId = reader.IsDBNull("ProgramId") ? null : reader.GetInt32("ProgramId"),
            CampaignId = reader.IsDBNull("CampaignId") ? null : reader.GetInt32("CampaignId"),
            EmailId = reader.IsDBNull("EmailId") ? null : reader.GetInt32("EmailId"),
            TrackingId = reader.IsDBNull("TrackingId") ? null : reader.GetGuid("TrackingId"),
            UnsubscribedAt = reader.GetDateTime("UnsubscribedAt"),
            Reason = reader.IsDBNull("Reason") ? null : reader.GetString("Reason"),
            IpAddress = reader.IsDBNull("IpAddress") ? null : reader.GetString("IpAddress"),
            UserAgent = reader.IsDBNull("UserAgent") ? null : reader.GetString("UserAgent")
        };
    }
}
