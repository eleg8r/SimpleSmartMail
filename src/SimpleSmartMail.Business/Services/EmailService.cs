using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using SimpleSmartMail.Business.EmailProviders;
using SimpleSmartMail.Data.Repositories;
using SimpleSmartMail.Models.DTOs;
using SimpleSmartMail.Models.Entities;
using SimpleSmartMail.Models.Enums;

namespace SimpleSmartMail.Business.Services;

public class EmailService : IEmailService
{
    private readonly IEmailRepository _emailRepository;
    private readonly IConfiguration _configuration;
    private readonly ILogger<EmailService> _logger;
    private readonly Dictionary<EmailProviderType, IEmailProvider> _emailProviders;

    public EmailService(
        IEmailRepository emailRepository,
        IConfiguration configuration,
        ILogger<EmailService> logger,
        SmtpEmailProvider smtpProvider,
        SendGridEmailProvider sendGridProvider)
    {
        _emailRepository = emailRepository;
        _configuration = configuration;
        _logger = logger;

        _emailProviders = new Dictionary<EmailProviderType, IEmailProvider>
        {
            { EmailProviderType.Smtp, smtpProvider },
            { EmailProviderType.SendGrid, sendGridProvider }
        };
    }

    public async Task<SendEmailResponse> SendEmailAsync(SendEmailRequest request)
    {
        try
        {
            // Create email entity
            var email = new Email
            {
                TenantId = request.TenantId,
                FromAddress = request.FromAddress,
                FromName = request.FromName,
                ToAddress = request.ToAddress,
                ToName = request.ToName,
                Cc = request.Cc != null && request.Cc.Any() ? string.Join(";", request.Cc) : null,
                Bcc = request.Bcc != null && request.Bcc.Any() ? string.Join(";", request.Bcc) : null,
                Subject = request.Subject,
                HtmlBody = request.HtmlBody,
                TextBody = request.TextBody,
                Status = EmailStatus.Queued,
                TrackingId = Guid.NewGuid(),
                OpenTracked = false,
                ClickTracked = false,
                ScheduledAt = request.ScheduledAt,
                CreatedAt = DateTime.UtcNow
            };

            // Add attachments
            if (request.Attachments != null && request.Attachments.Any())
            {
                foreach (var attachmentDto in request.Attachments)
                {
                    email.Attachments.Add(new EmailAttachment
                    {
                        FileName = attachmentDto.FileName,
                        ContentType = attachmentDto.ContentType,
                        Content = attachmentDto.Content,
                        SizeInBytes = attachmentDto.Content.Length
                    });
                }
            }

            // Save to database
            var emailId = await _emailRepository.CreateAsync(email);
            email.Id = emailId;

            // Save attachments
            foreach (var attachment in email.Attachments)
            {
                attachment.EmailId = emailId;
                await _emailRepository.AddAttachmentAsync(attachment);
            }

            // Send email immediately if requested
            if (request.SendImmediately)
            {
                var providerType = GetDefaultEmailProvider();
                var success = await SendEmailWithRetryAsync(email, providerType);

                if (success)
                {
                    email.Status = EmailStatus.Sent;
                    email.SentAt = DateTime.UtcNow;
                    email.ProviderUsed = providerType.ToString();
                }
                else
                {
                    email.Status = EmailStatus.Failed;
                    email.ErrorMessage = "Failed to send email after retries";
                }

                await _emailRepository.UpdateAsync(email);

                return new SendEmailResponse
                {
                    Success = success,
                    EmailId = emailId,
                    TrackingId = email.TrackingId,
                    ErrorMessage = success ? null : email.ErrorMessage
                };
            }

            // Return success for scheduled emails
            return new SendEmailResponse
            {
                Success = true,
                EmailId = emailId,
                TrackingId = email.TrackingId
            };
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to process email request");
            return new SendEmailResponse
            {
                Success = false,
                ErrorMessage = ex.Message
            };
        }
    }

    public async Task<Email?> GetEmailByIdAsync(int id)
    {
        return await _emailRepository.GetByIdAsync(id);
    }

    public async Task<Email?> GetEmailByTrackingIdAsync(Guid trackingId)
    {
        return await _emailRepository.GetByTrackingIdAsync(trackingId);
    }

    public async Task<List<Email>> GetEmailsByTenantIdAsync(string tenantId, int pageNumber = 1, int pageSize = 50)
    {
        return await _emailRepository.GetByTenantIdAsync(tenantId, pageNumber, pageSize);
    }

    private async Task<bool> SendEmailWithRetryAsync(Email email, EmailProviderType providerType, int maxRetries = 3)
    {
        var provider = _emailProviders[providerType];

        for (int retry = 0; retry < maxRetries; retry++)
        {
            try
            {
                email.Status = EmailStatus.Processing;
                await _emailRepository.UpdateAsync(email);

                var success = await provider.SendAsync(email);

                if (success)
                {
                    return true;
                }

                email.RetryCount++;

                // Exponential backoff
                if (retry < maxRetries - 1)
                {
                    var delay = TimeSpan.FromSeconds(Math.Pow(2, retry));
                    _logger.LogWarning("Retrying email send in {Delay} seconds. Retry {Retry}/{MaxRetries}",
                        delay.TotalSeconds, retry + 1, maxRetries);
                    await Task.Delay(delay);
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error sending email on retry {Retry}", retry + 1);
                email.RetryCount++;
                email.ErrorMessage = ex.Message;
            }
        }

        return false;
    }

    private EmailProviderType GetDefaultEmailProvider()
    {
        var defaultProvider = _configuration["EmailSettings:DefaultProvider"] ?? "Smtp";
        return Enum.Parse<EmailProviderType>(defaultProvider, ignoreCase: true);
    }
}
