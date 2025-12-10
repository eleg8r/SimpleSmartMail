using System.Text.Json;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using SimpleSmartMail.Data.Repositories;
using SimpleSmartMail.Models.DTOs;
using SimpleSmartMail.Models.Entities;
using SimpleSmartMail.Models.Enums;

namespace SimpleSmartMail.Business.Services;

public class CampaignService : ICampaignService
{
    private readonly ICampaignRepository _campaignRepository;
    private readonly IEmailService _emailService;
    private readonly ITrackingService _trackingService;
    private readonly IAutoAuthTokenService _autoAuthTokenService;
    private readonly IEmailValidationService _emailValidationService;
    private readonly IConfiguration _configuration;
    private readonly ILogger<CampaignService> _logger;

    public CampaignService(
        ICampaignRepository campaignRepository,
        IEmailService emailService,
        ITrackingService trackingService,
        IAutoAuthTokenService autoAuthTokenService,
        IEmailValidationService emailValidationService,
        IConfiguration configuration,
        ILogger<CampaignService> logger)
    {
        _campaignRepository = campaignRepository;
        _emailService = emailService;
        _trackingService = trackingService;
        _autoAuthTokenService = autoAuthTokenService;
        _emailValidationService = emailValidationService;
        _configuration = configuration;
        _logger = logger;
    }

    public async Task<int> CreateCampaignAsync(CreateCampaignRequest request)
    {
        var campaign = new EmailCampaign
        {
            TenantId = request.TenantId,
            Name = request.Name,
            Description = request.Description,
            Status = CampaignStatus.Draft,
            FromAddress = request.FromAddress,
            FromName = request.FromName,
            Subject = request.Subject,
            HtmlTemplate = request.HtmlTemplate,
            TextTemplate = request.TextTemplate,
            ScheduledStartDate = request.ScheduledStartDate,
            BatchSize = request.BatchSize,
            MaxEmailsPerHour = request.MaxEmailsPerHour,
            EnableOpenTracking = request.EnableOpenTracking,
            EnableClickTracking = request.EnableClickTracking,
            TotalRecipients = request.Recipients.Count,
            CreatedAt = DateTime.UtcNow,
            CreatedBy = request.CreatedBy
        };

        var campaignId = await _campaignRepository.CreateAsync(campaign);

        // Auto-generate authentication tokens if enabled
        if (request.AutoGenerateAuthTokens && !string.IsNullOrEmpty(request.AutoAuthBaseUrl))
        {
            var tokenKey = request.AutoAuthTokenKey ?? "TutorConnectUrl";

            foreach (var recipientDto in request.Recipients)
            {
                // Only generate token if recipient has a UserId
                if (!string.IsNullOrEmpty(recipientDto.UserId))
                {
                    try
                    {
                        // Initialize PersonalizationData if null
                        recipientDto.PersonalizationData ??= new Dictionary<string, string>();

                        // Generate auto-login URL with JWT token
                        var autoAuthUrl = _autoAuthTokenService.GenerateTutorConnectUrl(
                            userId: recipientDto.UserId,
                            email: recipientDto.EmailAddress,
                            baseUrl: request.AutoAuthBaseUrl
                        );

                        // Add to personalization data
                        recipientDto.PersonalizationData[tokenKey] = autoAuthUrl;

                        _logger.LogInformation(
                            "Generated auto-auth token for recipient {Email} with UserId {UserId}",
                            recipientDto.EmailAddress,
                            recipientDto.UserId);
                    }
                    catch (Exception ex)
                    {
                        _logger.LogError(ex,
                            "Failed to generate auto-auth token for recipient {Email}",
                            recipientDto.EmailAddress);
                        // Continue processing other recipients
                    }
                }
            }
        }

        // Add recipients
        foreach (var recipientDto in request.Recipients)
        {
            var recipient = new CampaignRecipient
            {
                CampaignId = campaignId,
                EmailAddress = recipientDto.EmailAddress,
                RecipientName = recipientDto.RecipientName,
                PersonalizationData = recipientDto.PersonalizationData != null
                    ? JsonSerializer.Serialize(recipientDto.PersonalizationData)
                    : null
            };

            await _campaignRepository.AddRecipientAsync(recipient);
        }

        _logger.LogInformation("Campaign created with ID {CampaignId} and {RecipientCount} recipients",
            campaignId, request.Recipients.Count);

        return campaignId;
    }

    public async Task<EmailCampaign?> GetCampaignByIdAsync(int id)
    {
        return await _campaignRepository.GetByIdAsync(id);
    }

    public async Task<List<EmailCampaign>> GetCampaignsByTenantIdAsync(string tenantId)
    {
        return await _campaignRepository.GetByTenantIdAsync(tenantId);
    }

    public async Task UpdateCampaignStatusAsync(int campaignId, CampaignStatus status)
    {
        var campaign = await _campaignRepository.GetByIdAsync(campaignId);
        if (campaign == null)
        {
            throw new ArgumentException($"Campaign with ID {campaignId} not found");
        }

        campaign.Status = status;

        if (status == CampaignStatus.InProgress && !campaign.StartedAt.HasValue)
        {
            campaign.StartedAt = DateTime.UtcNow;
        }
        else if (status == CampaignStatus.Completed && !campaign.CompletedAt.HasValue)
        {
            campaign.CompletedAt = DateTime.UtcNow;
        }

        await _campaignRepository.UpdateAsync(campaign);
    }

    public async Task StartCampaignAsync(int campaignId)
    {
        var campaign = await _campaignRepository.GetByIdAsync(campaignId);
        if (campaign == null)
        {
            throw new ArgumentException($"Campaign with ID {campaignId} not found");
        }

        if (campaign.Status != CampaignStatus.Draft && campaign.Status != CampaignStatus.Scheduled)
        {
            throw new InvalidOperationException($"Campaign cannot be started from status {campaign.Status}");
        }

        campaign.Status = CampaignStatus.InProgress;
        campaign.StartedAt = DateTime.UtcNow;
        await _campaignRepository.UpdateAsync(campaign);

        // Start sending emails in background (simplified - in production use a job queue)
        _ = Task.Run(async () => await ProcessCampaignAsync(campaign));

        _logger.LogInformation("Campaign {CampaignId} started", campaignId);
    }

    private async Task ProcessCampaignAsync(EmailCampaign campaign)
    {
        try
        {
            var recipients = await _campaignRepository.GetRecipientsAsync(campaign.Id);
            var unsentRecipients = recipients.Where(r => !r.Sent).ToList();

            _logger.LogInformation("Processing campaign {CampaignId} with {RecipientCount} unsent recipients",
                campaign.Id, unsentRecipients.Count);

            int emailsSent = 0;
            int emailsFailed = 0;

            foreach (var recipient in unsentRecipients)
            {
                try
                {
                    // Validate recipient email address
                    var validation = await _emailValidationService.ValidateEmailAsync(recipient.EmailAddress);
                    if (!validation.IsValid)
                    {
                        _logger.LogWarning("Invalid email address for recipient {Email}: {Errors}",
                            recipient.EmailAddress,
                            string.Join(", ", validation.Errors));

                        recipient.Sent = false;
                        await _campaignRepository.UpdateRecipientAsync(recipient);
                        emailsFailed++;
                        continue;
                    }

                    // Check if recipient is unsubscribed
                    var isUnsubscribed = await _trackingService.IsUnsubscribedAsync(recipient.EmailAddress, campaign.TenantId);
                    if (isUnsubscribed)
                    {
                        _logger.LogInformation("Skipping unsubscribed recipient {EmailAddress} for campaign {CampaignId}",
                            recipient.EmailAddress, campaign.Id);

                        recipient.Sent = false;
                        await _campaignRepository.UpdateRecipientAsync(recipient);
                        emailsFailed++;
                        continue;
                    }

                    // Apply personalization (simplified - just replace placeholders)
                    var htmlBody = campaign.HtmlTemplate;
                    var subject = campaign.Subject;

                    if (!string.IsNullOrEmpty(recipient.PersonalizationData))
                    {
                        var personalizationDict = JsonSerializer.Deserialize<Dictionary<string, string>>(recipient.PersonalizationData);
                        if (personalizationDict != null)
                        {
                            foreach (var kvp in personalizationDict)
                            {
                                htmlBody = htmlBody.Replace($"{{{{{kvp.Key}}}}}", kvp.Value);
                                subject = subject.Replace($"{{{{{kvp.Key}}}}}", kvp.Value);
                            }
                        }
                    }

                    var emailRequest = new SendEmailRequest
                    {
                        TenantId = campaign.TenantId,
                        FromAddress = campaign.FromAddress,
                        FromName = campaign.FromName,
                        ToAddress = recipient.EmailAddress,
                        ToName = recipient.RecipientName ?? recipient.EmailAddress,
                        Subject = subject,
                        HtmlBody = htmlBody,
                        TextBody = campaign.TextTemplate,
                        SendImmediately = true,
                        EnableOpenTracking = campaign.EnableOpenTracking,
                        EnableClickTracking = campaign.EnableClickTracking
                    };

                    var result = await _emailService.SendEmailAsync(emailRequest);

                    if (result.Success)
                    {
                        recipient.Sent = true;
                        recipient.SentAt = DateTime.UtcNow;
                        recipient.EmailId = result.EmailId;
                        emailsSent++;
                    }
                    else
                    {
                        emailsFailed++;
                    }

                    await _campaignRepository.UpdateRecipientAsync(recipient);

                    // Rate limiting
                    if (campaign.MaxEmailsPerHour.HasValue)
                    {
                        var delayMs = (int)(3600000.0 / campaign.MaxEmailsPerHour.Value);
                        await Task.Delay(delayMs);
                    }
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Failed to send email to {EmailAddress} for campaign {CampaignId}",
                        recipient.EmailAddress, campaign.Id);
                    emailsFailed++;
                }
            }

            // Update campaign statistics
            await _campaignRepository.UpdateStatisticsAsync(campaign.Id, emailsSent, 0, 0, 0, emailsFailed);

            // Mark campaign as completed
            campaign.Status = CampaignStatus.Completed;
            campaign.CompletedAt = DateTime.UtcNow;
            await _campaignRepository.UpdateAsync(campaign);

            _logger.LogInformation("Campaign {CampaignId} completed. Sent: {Sent}, Failed: {Failed}",
                campaign.Id, emailsSent, emailsFailed);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to process campaign {CampaignId}", campaign.Id);
            campaign.Status = CampaignStatus.Failed;
            await _campaignRepository.UpdateAsync(campaign);
        }
    }
}
