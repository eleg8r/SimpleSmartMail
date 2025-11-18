using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using SendGrid;
using SendGrid.Helpers.Mail;
using SimpleSmartMail.Models.Entities;

namespace SimpleSmartMail.Business.EmailProviders;

public class SendGridEmailProvider : IEmailProvider
{
    private readonly IConfiguration _configuration;
    private readonly ILogger<SendGridEmailProvider> _logger;
    private readonly SendGridClient _client;

    public SendGridEmailProvider(IConfiguration configuration, ILogger<SendGridEmailProvider> logger)
    {
        _configuration = configuration;
        _logger = logger;
        var apiKey = _configuration["EmailSettings:SendGrid:ApiKey"]
            ?? throw new ArgumentNullException("SendGrid API Key not configured");
        _client = new SendGridClient(apiKey);
    }

    public async Task<bool> SendAsync(Email email, CancellationToken cancellationToken = default)
    {
        try
        {
            var from = new EmailAddress(email.FromAddress, email.FromName);
            var to = new EmailAddress(email.ToAddress, email.ToName);
            var msg = MailHelper.CreateSingleEmail(from, to, email.Subject, email.TextBody ?? string.Empty, email.HtmlBody);

            // Add CC recipients
            if (!string.IsNullOrEmpty(email.Cc))
            {
                var ccAddresses = email.Cc.Split(';', StringSplitOptions.RemoveEmptyEntries);
                foreach (var cc in ccAddresses)
                {
                    msg.AddCc(new EmailAddress(cc.Trim()));
                }
            }

            // Add BCC recipients
            if (!string.IsNullOrEmpty(email.Bcc))
            {
                var bccAddresses = email.Bcc.Split(';', StringSplitOptions.RemoveEmptyEntries);
                foreach (var bcc in bccAddresses)
                {
                    msg.AddBcc(new EmailAddress(bcc.Trim()));
                }
            }

            // Add attachments
            foreach (var attachment in email.Attachments)
            {
                var base64Content = Convert.ToBase64String(attachment.Content);
                msg.AddAttachment(attachment.FileName, base64Content, attachment.ContentType);
            }

            // Add tracking metadata
            msg.AddCustomArg("EmailId", email.Id.ToString());
            msg.AddCustomArg("TrackingId", email.TrackingId.ToString());
            if (email.CampaignId.HasValue)
            {
                msg.AddCustomArg("CampaignId", email.CampaignId.Value.ToString());
            }

            // Disable SendGrid's own tracking since we handle it
            msg.SetClickTracking(false, false);
            msg.SetOpenTracking(false);

            var response = await _client.SendEmailAsync(msg, cancellationToken);

            if (response.IsSuccessStatusCode)
            {
                _logger.LogInformation("Email sent successfully via SendGrid to {ToAddress}", email.ToAddress);
                return true;
            }
            else
            {
                var body = await response.Body.ReadAsStringAsync(cancellationToken);
                _logger.LogError("Failed to send email via SendGrid to {ToAddress}. Status: {StatusCode}, Body: {Body}",
                    email.ToAddress, response.StatusCode, body);
                return false;
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to send email via SendGrid to {ToAddress}", email.ToAddress);
            return false;
        }
    }

    public async Task<List<(bool Success, string ErrorMessage)>> SendBulkAsync(List<Email> emails, CancellationToken cancellationToken = default)
    {
        var results = new List<(bool Success, string ErrorMessage)>();

        // Note: SendGrid has a batch API but for simplicity we'll send sequentially
        // In production, you'd want to use their batch endpoint
        foreach (var email in emails)
        {
            try
            {
                var success = await SendAsync(email, cancellationToken);
                results.Add((success, success ? string.Empty : "Failed to send email"));
            }
            catch (Exception ex)
            {
                results.Add((false, ex.Message));
            }
        }

        return results;
    }
}
