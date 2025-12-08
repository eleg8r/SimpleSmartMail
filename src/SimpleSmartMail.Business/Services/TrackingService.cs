using System.Text.RegularExpressions;
using Microsoft.Extensions.Logging;
using SimpleSmartMail.Data.Repositories;
using SimpleSmartMail.Models.Entities;
using SimpleSmartMail.Models.Enums;

namespace SimpleSmartMail.Business.Services;

public class TrackingService : ITrackingService
{
    private readonly ITrackingRepository _trackingRepository;
    private readonly IEmailRepository _emailRepository;
    private readonly ILogger<TrackingService> _logger;
    private static readonly Dictionary<string, string> _trackedUrls = new();

    public TrackingService(
        ITrackingRepository trackingRepository,
        IEmailRepository emailRepository,
        ILogger<TrackingService> logger)
    {
        _trackingRepository = trackingRepository;
        _emailRepository = emailRepository;
        _logger = logger;
    }

    public async Task<int> RecordOpenAsync(Guid trackingId, string? ipAddress, string? userAgent)
    {
        try
        {
            var result = await _trackingRepository.RecordEmailOpenAsync(trackingId, ipAddress, userAgent);

            // Update email status to Opened if it's not already
            var email = await _emailRepository.GetByTrackingIdAsync(trackingId);
            if (email != null && email.Status < EmailStatus.Opened)
            {
                email.Status = EmailStatus.Opened;
                email.OpenTracked = true;
                email.OpenedAt ??= DateTime.UtcNow;
                email.OpenCount++;
                await _emailRepository.UpdateAsync(email);
            }
            else if (email != null)
            {
                email.OpenCount++;
                await _emailRepository.UpdateAsync(email);
            }

            _logger.LogInformation("Recorded email open for tracking ID {TrackingId}", trackingId);
            return result;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error recording email open for tracking ID {TrackingId}", trackingId);
            return 0;
        }
    }

    public async Task<int> RecordClickAsync(Guid trackingId, string url, string? ipAddress, string? userAgent)
    {
        try
        {
            var email = await _emailRepository.GetByTrackingIdAsync(trackingId);
            if (email == null)
            {
                _logger.LogWarning("Email not found for tracking ID {TrackingId}", trackingId);
                return 0;
            }

            var click = new EmailClick
            {
                TenantId = email.TenantId,
                EmailId = email.Id,
                CampaignId = email.CampaignId,
                TrackingId = trackingId,
                RecipientEmail = email.ToAddress,
                OriginalUrl = url,
                TrackedUrl = $"/track/click/{trackingId}",
                ClickedAt = DateTime.UtcNow,
                IpAddress = ipAddress,
                UserAgent = userAgent
            };

            var clickId = await _trackingRepository.RecordEmailClickAsync(click);

            // Update email status to Clicked if it's not already
            if (email.Status < EmailStatus.Clicked)
            {
                email.Status = EmailStatus.Clicked;
            }

            email.ClickTracked = true;
            email.FirstClickedAt ??= DateTime.UtcNow;
            email.ClickCount++;
            await _emailRepository.UpdateAsync(email);

            _logger.LogInformation("Recorded click for tracking ID {TrackingId}, URL: {Url}", trackingId, url);
            return clickId;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error recording click for tracking ID {TrackingId}", trackingId);
            return 0;
        }
    }

    public Task<string> InjectTrackingPixelAsync(string htmlBody, Guid trackingId, string baseUrl)
    {
        var trackingPixel = $"<img src=\"{baseUrl}/track/open/{trackingId}\" width=\"1\" height=\"1\" alt=\"\" style=\"display:none;\" />";

        // Try to insert before closing body tag
        if (htmlBody.Contains("</body>", StringComparison.OrdinalIgnoreCase))
        {
            htmlBody = Regex.Replace(htmlBody, "</body>", $"{trackingPixel}</body>", RegexOptions.IgnoreCase);
        }
        else
        {
            // If no body tag, append to the end
            htmlBody += trackingPixel;
        }

        return Task.FromResult(htmlBody);
    }

    public Task<string> ReplaceLinksWithTrackedUrlsAsync(string htmlBody, Guid trackingId, string baseUrl)
    {
        // Match all <a> tags with href attributes
        var linkPattern = @"<a\s+(?:[^>]*?\s+)?href\s*=\s*[""']([^""']+)[""']([^>]*)>";

        htmlBody = Regex.Replace(htmlBody, linkPattern, match =>
        {
            var originalUrl = match.Groups[1].Value;
            var otherAttributes = match.Groups[2].Value;

            // Don't track tracking URLs or unsubscribe URLs
            if (originalUrl.Contains("/track/") || originalUrl.Contains("/unsubscribe/"))
            {
                return match.Value;
            }

            // Create tracked URL
            var urlHash = Math.Abs(originalUrl.GetHashCode()).ToString();
            var trackedUrl = $"{baseUrl}/track/click/{trackingId}/{urlHash}";

            // Store mapping for later retrieval
            var key = $"{trackingId}_{urlHash}";
            if (!_trackedUrls.ContainsKey(key))
            {
                _trackedUrls[key] = originalUrl;
            }

            return $"<a href=\"{trackedUrl}\"{otherAttributes}>";
        }, RegexOptions.IgnoreCase);

        return Task.FromResult(htmlBody);
    }

    public Task<string?> GetOriginalUrlAsync(Guid trackingId, string urlHash)
    {
        var key = $"{trackingId}_{urlHash}";
        return Task.FromResult(_trackedUrls.TryGetValue(key, out var url) ? url : null);
    }

    public Task<string> InjectUnsubscribeLinkAsync(string htmlBody, Guid trackingId, string baseUrl)
    {
        var unsubscribeUrl = $"{baseUrl}/track/unsubscribe/{trackingId}";
        var unsubscribeLink = $"<p style=\"text-align: center; font-size: 12px; color: #666; margin-top: 20px;\">" +
                             $"<a href=\"{unsubscribeUrl}\" style=\"color: #666; text-decoration: underline;\">Unsubscribe from this campaign</a>" +
                             $"</p>";

        // Insert before closing body tag or append at end
        if (htmlBody.Contains("</body>", StringComparison.OrdinalIgnoreCase))
        {
            htmlBody = Regex.Replace(htmlBody, "</body>", $"{unsubscribeLink}</body>", RegexOptions.IgnoreCase);
        }
        else
        {
            htmlBody += unsubscribeLink;
        }

        return Task.FromResult(htmlBody);
    }

    public async Task HandleBounceAsync(int emailId, string bounceReason)
    {
        var email = await _emailRepository.GetByIdAsync(emailId);
        if (email == null) return;

        // Mark email as bounced
        email.Status = EmailStatus.Failed;
        email.ErrorMessage = $"Bounced: {bounceReason}";
        await _emailRepository.UpdateAsync(email);

        // Auto-unsubscribe for hard bounces
        if (IsHardBounce(bounceReason))
        {
            var unsubscribeRequest = new UnsubscribeRequest
            {
                TenantId = email.TenantId,
                EmailAddress = email.ToAddress,
                TrackingId = email.TrackingId,
                Reason = $"Auto-unsubscribed: Hard bounce - {bounceReason}",
                GlobalUnsubscribe = true, // Prevent all future emails
                UnsubscribedAt = DateTime.UtcNow
            };

            await _trackingRepository.AddUnsubscribeRequestAsync(unsubscribeRequest);
            _logger.LogWarning("Auto-unsubscribed {EmailAddress} due to hard bounce", email.ToAddress);
        }
    }

    public async Task HandleSpamComplaintAsync(int emailId)
    {
        var email = await _emailRepository.GetByIdAsync(emailId);
        if (email == null) return;

        // Auto-unsubscribe for spam complaints (always global)
        var unsubscribeRequest = new UnsubscribeRequest
        {
            TenantId = email.TenantId,
            EmailAddress = email.ToAddress,
            TrackingId = email.TrackingId,
            Reason = "Auto-unsubscribed: Spam complaint",
            GlobalUnsubscribe = true,
            UnsubscribedAt = DateTime.UtcNow
        };

        await _trackingRepository.AddUnsubscribeRequestAsync(unsubscribeRequest);
        _logger.LogWarning("Spam complaint received for email {EmailId} to {EmailAddress}", emailId, email.ToAddress);
    }

    private bool IsHardBounce(string bounceReason)
    {
        var hardBounceIndicators = new[]
        {
            "invalid", "not exist", "unknown user", "mailbox not found",
            "no such user", "user unknown", "permanent failure", "address rejected"
        };

        return hardBounceIndicators.Any(indicator =>
            bounceReason.Contains(indicator, StringComparison.OrdinalIgnoreCase));
    }

    public async Task<int> AddUnsubscribeRequestAsync(UnsubscribeRequest request)
    {
        request.UnsubscribedAt = DateTime.UtcNow;
        return await _trackingRepository.AddUnsubscribeRequestAsync(request);
    }

    public async Task<bool> IsUnsubscribedAsync(string emailAddress, string tenantId)
    {
        return await _trackingRepository.IsUnsubscribedAsync(emailAddress, tenantId);
    }

    public async Task<List<EmailClick>> GetClicksByEmailIdAsync(int emailId)
    {
        return await _trackingRepository.GetClicksByEmailIdAsync(emailId);
    }

    public async Task<List<EmailClick>> GetClicksByCampaignIdAsync(int campaignId)
    {
        return await _trackingRepository.GetClicksByCampaignIdAsync(campaignId);
    }
}
