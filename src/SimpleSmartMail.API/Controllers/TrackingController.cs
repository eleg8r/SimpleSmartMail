using Microsoft.AspNetCore.Mvc;
using SimpleSmartMail.Business.Services;
using SimpleSmartMail.Models.Entities;

namespace SimpleSmartMail.API.Controllers;

[ApiController]
[Route("track")]
public class TrackingController : ControllerBase
{
    private readonly ITrackingService _trackingService;
    private readonly ILogger<TrackingController> _logger;

    public TrackingController(ITrackingService trackingService, ILogger<TrackingController> logger)
    {
        _trackingService = trackingService;
        _logger = logger;
    }

    /// <summary>
    /// Track email open via 1x1 pixel image
    /// </summary>
    [HttpGet("open/{trackingId}")]
    public async Task<IActionResult> TrackOpen(Guid trackingId)
    {
        try
        {
            var ipAddress = HttpContext.Connection.RemoteIpAddress?.ToString();
            var userAgent = HttpContext.Request.Headers["User-Agent"].ToString();

            await _trackingService.RecordOpenAsync(trackingId, ipAddress, userAgent);

            // Return a 1x1 transparent GIF
            var transparentGif = Convert.FromBase64String("R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7");
            return File(transparentGif, "image/gif");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error tracking open for {TrackingId}", trackingId);
            // Still return the pixel even on error to avoid breaking the email display
            var transparentGif = Convert.FromBase64String("R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7");
            return File(transparentGif, "image/gif");
        }
    }

    /// <summary>
    /// Track link click and redirect to original URL
    /// </summary>
    [HttpGet("click/{trackingId}/{urlHash}")]
    public async Task<IActionResult> TrackClick(Guid trackingId, string urlHash)
    {
        try
        {
            var originalUrl = await _trackingService.GetOriginalUrlAsync(trackingId, urlHash);

            if (string.IsNullOrEmpty(originalUrl))
            {
                _logger.LogWarning("Original URL not found for tracking ID {TrackingId}, hash {UrlHash}", trackingId, urlHash);
                return NotFound("Link not found");
            }

            var ipAddress = HttpContext.Connection.RemoteIpAddress?.ToString();
            var userAgent = HttpContext.Request.Headers["User-Agent"].ToString();

            await _trackingService.RecordClickAsync(trackingId, originalUrl, ipAddress, userAgent);

            return Redirect(originalUrl);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error tracking click for {TrackingId}", trackingId);
            return StatusCode(500, "Error processing click");
        }
    }

    /// <summary>
    /// Handle unsubscribe request
    /// </summary>
    [HttpGet("unsubscribe/{trackingId}")]
    public async Task<IActionResult> Unsubscribe(Guid trackingId, [FromQuery] string? reason = null)
    {
        try
        {
            var ipAddress = HttpContext.Connection.RemoteIpAddress?.ToString();
            var userAgent = HttpContext.Request.Headers["User-Agent"].ToString();

            var request = new UnsubscribeRequest
            {
                TrackingId = trackingId,
                Reason = reason,
                IpAddress = ipAddress,
                UserAgent = userAgent,
                ProgramId = null // NULL = global unsubscribe
            };

            // This would need to be enhanced to get program and email info from tracking ID
            // For now, returning a simple page
            await _trackingService.AddUnsubscribeRequestAsync(request);

            return Content(@"
<!DOCTYPE html>
<html>
<head>
    <title>Unsubscribed</title>
    <style>
        body { font-family: Arial, sans-serif; text-align: center; padding: 50px; }
        .container { max-width: 600px; margin: 0 auto; }
        h1 { color: #333; }
        p { color: #666; }
    </style>
</head>
<body>
    <div class='container'>
        <h1>You've Been Unsubscribed</h1>
        <p>You will no longer receive emails from this campaign.</p>
        <p>If this was a mistake, please contact support.</p>
    </div>
</body>
</html>", "text/html");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error processing unsubscribe for {TrackingId}", trackingId);
            return StatusCode(500, "Error processing unsubscribe request");
        }
    }

    /// <summary>
    /// Get clicks for an email
    /// </summary>
    [HttpGet("clicks/email/{emailId}")]
    public async Task<ActionResult> GetEmailClicks(int emailId)
    {
        try
        {
            var clicks = await _trackingService.GetClicksByEmailIdAsync(emailId);
            return Ok(clicks);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving clicks for email {EmailId}", emailId);
            return StatusCode(500, new { Message = "Internal server error" });
        }
    }

    /// <summary>
    /// Get clicks for a campaign
    /// </summary>
    [HttpGet("clicks/campaign/{campaignId}")]
    public async Task<ActionResult> GetCampaignClicks(int campaignId)
    {
        try
        {
            var clicks = await _trackingService.GetClicksByCampaignIdAsync(campaignId);
            return Ok(clicks);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving clicks for campaign {CampaignId}", campaignId);
            return StatusCode(500, new { Message = "Internal server error" });
        }
    }

    /// <summary>
    /// Handle bounce notification from email provider
    /// </summary>
    [HttpPost("bounce/{emailId}")]
    public async Task<IActionResult> HandleBounce(int emailId, [FromBody] BounceNotificationRequest request)
    {
        try
        {
            await _trackingService.HandleBounceAsync(emailId, request.BounceReason ?? "Unknown bounce reason");
            return Ok(new { Message = "Bounce handled successfully" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error handling bounce for email {EmailId}", emailId);
            return StatusCode(500, new { Message = "Internal server error" });
        }
    }

    /// <summary>
    /// Handle spam complaint notification from email provider
    /// </summary>
    [HttpPost("spam/{emailId}")]
    public async Task<IActionResult> HandleSpamComplaint(int emailId)
    {
        try
        {
            await _trackingService.HandleSpamComplaintAsync(emailId);
            return Ok(new { Message = "Spam complaint handled successfully" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error handling spam complaint for email {EmailId}", emailId);
            return StatusCode(500, new { Message = "Internal server error" });
        }
    }
}

public class BounceNotificationRequest
{
    public string? BounceReason { get; set; }
}
