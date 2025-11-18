using System.Net;
using System.Net.Mail;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using SimpleSmartMail.Models.Entities;

namespace SimpleSmartMail.Business.EmailProviders;

public class SmtpEmailProvider : IEmailProvider
{
    private readonly IConfiguration _configuration;
    private readonly ILogger<SmtpEmailProvider> _logger;

    public SmtpEmailProvider(IConfiguration configuration, ILogger<SmtpEmailProvider> logger)
    {
        _configuration = configuration;
        _logger = logger;
    }

    public async Task<bool> SendAsync(Email email, CancellationToken cancellationToken = default)
    {
        try
        {
            var smtpHost = _configuration["EmailSettings:Smtp:Host"] ?? "localhost";
            var smtpPort = int.Parse(_configuration["EmailSettings:Smtp:Port"] ?? "587");
            var smtpUsername = _configuration["EmailSettings:Smtp:Username"];
            var smtpPassword = _configuration["EmailSettings:Smtp:Password"];
            var enableSsl = bool.Parse(_configuration["EmailSettings:Smtp:EnableSsl"] ?? "true");

            using var smtpClient = new SmtpClient(smtpHost, smtpPort)
            {
                EnableSsl = enableSsl,
                UseDefaultCredentials = false,
                Credentials = new NetworkCredential(smtpUsername, smtpPassword)
            };

            using var message = new MailMessage
            {
                From = new MailAddress(email.FromAddress, email.FromName),
                Subject = email.Subject,
                Body = email.HtmlBody,
                IsBodyHtml = true
            };

            message.To.Add(new MailAddress(email.ToAddress, email.ToName));

            // Add CC recipients
            if (!string.IsNullOrEmpty(email.Cc))
            {
                var ccAddresses = email.Cc.Split(';', StringSplitOptions.RemoveEmptyEntries);
                foreach (var cc in ccAddresses)
                {
                    message.CC.Add(cc.Trim());
                }
            }

            // Add BCC recipients
            if (!string.IsNullOrEmpty(email.Bcc))
            {
                var bccAddresses = email.Bcc.Split(';', StringSplitOptions.RemoveEmptyEntries);
                foreach (var bcc in bccAddresses)
                {
                    message.Bcc.Add(bcc.Trim());
                }
            }

            // Add attachments
            foreach (var attachment in email.Attachments)
            {
                var stream = new MemoryStream(attachment.Content);
                message.Attachments.Add(new Attachment(stream, attachment.FileName, attachment.ContentType));
            }

            await smtpClient.SendMailAsync(message, cancellationToken);

            _logger.LogInformation("Email sent successfully via SMTP to {ToAddress}", email.ToAddress);
            return true;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to send email via SMTP to {ToAddress}", email.ToAddress);
            return false;
        }
    }

    public async Task<List<(bool Success, string ErrorMessage)>> SendBulkAsync(List<Email> emails, CancellationToken cancellationToken = default)
    {
        var results = new List<(bool Success, string ErrorMessage)>();

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
