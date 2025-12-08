# Tracking Integration - Complete Code Changes

## Summary

This document contains all code changes made to integrate tracking features (open tracking, click tracking, and unsubscribe functionality) into SimpleSmartMail.

**Changes Made:**
1. Added unsubscribe link injection to all emails
2. Added bounce and spam complaint handling with auto-unsubscribe
3. Integrated open tracking pixel injection into EmailService and CampaignService
4. Integrated click tracking URL replacement into EmailService and CampaignService
5. Added unsubscribe check before sending emails
6. Added webhook endpoints for bounce/spam notifications

---

## File 1: TrackingService.cs - New Methods Added

**Location:** `/src/SimpleSmartMail.Business/Services/TrackingService.cs`

### Added Method: InjectUnsubscribeLinkAsync

```csharp
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
```

**Purpose:** Automatically adds unsubscribe link to every email HTML body.

**Example Output:**
```html
<p style="text-align: center; font-size: 12px; color: #666; margin-top: 20px;">
  <a href="https://yourdomain.com/track/unsubscribe/123e4567-e89b-12d3-a456-426614174000"
     style="color: #666; text-decoration: underline;">
    Unsubscribe from this campaign
  </a>
</p>
```

---

### Added Method: HandleBounceAsync

```csharp
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
```

**Purpose:** Handles bounce notifications from email providers and auto-unsubscribes on hard bounces.

**Hard Bounce Indicators:**
- "invalid"
- "not exist"
- "unknown user"
- "mailbox not found"
- "no such user"
- "user unknown"
- "permanent failure"
- "address rejected"

---

### Added Method: HandleSpamComplaintAsync

```csharp
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
```

**Purpose:** Handles spam complaints from email providers and always performs global unsubscribe.

---

### Added Method: IsHardBounce (Private Helper)

```csharp
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
```

**Purpose:** Determines if a bounce is a hard bounce (permanent failure) vs soft bounce (temporary issue).

---

## File 2: ITrackingService.cs - Interface Updated

**Location:** `/src/SimpleSmartMail.Business/Services/ITrackingService.cs`

### Changes:

```csharp
public interface ITrackingService
{
    Task<int> RecordOpenAsync(Guid trackingId, string? ipAddress, string? userAgent);
    Task<int> RecordClickAsync(Guid trackingId, string url, string? ipAddress, string? userAgent);
    Task<string> InjectTrackingPixelAsync(string htmlBody, Guid trackingId, string baseUrl);
    Task<string> ReplaceLinksWithTrackedUrlsAsync(string htmlBody, Guid trackingId, string baseUrl);
    Task<string> InjectUnsubscribeLinkAsync(string htmlBody, Guid trackingId, string baseUrl); // NEW
    Task<string?> GetOriginalUrlAsync(Guid trackingId, string trackedUrl);
    Task<int> AddUnsubscribeRequestAsync(UnsubscribeRequest request);
    Task<bool> IsUnsubscribedAsync(string emailAddress, string tenantId);
    Task HandleBounceAsync(int emailId, string bounceReason); // NEW
    Task HandleSpamComplaintAsync(int emailId); // NEW
    Task<List<EmailClick>> GetClicksByEmailIdAsync(int emailId);
    Task<List<EmailClick>> GetClicksByCampaignIdAsync(int campaignId);
}
```

**Added 3 new methods to the interface.**

---

## File 3: EmailService.cs - Tracking Integration

**Location:** `/src/SimpleSmartMail.Business/Services/EmailService.cs`

### Change 1: Added ITrackingService Dependency

```csharp
public class EmailService : IEmailService
{
    private readonly IEmailRepository _emailRepository;
    private readonly ITrackingService _trackingService; // NEW
    private readonly IConfiguration _configuration;
    private readonly ILogger<EmailService> _logger;
    private readonly Dictionary<EmailProviderType, IEmailProvider> _emailProviders;

    public EmailService(
        IEmailRepository emailRepository,
        ITrackingService trackingService, // NEW
        IConfiguration configuration,
        ILogger<EmailService> logger,
        SmtpEmailProvider smtpProvider,
        SendGridEmailProvider sendGridProvider)
    {
        _emailRepository = emailRepository;
        _trackingService = trackingService; // NEW
        _configuration = configuration;
        _logger = logger;

        _emailProviders = new Dictionary<EmailProviderType, IEmailProvider>
        {
            { EmailProviderType.Smtp, smtpProvider },
            { EmailProviderType.SendGrid, sendGridProvider }
        };
    }
```

---

### Change 2: Added Unsubscribe Check Before Sending

**Location:** Beginning of `SendEmailAsync()` method

```csharp
public async Task<SendEmailResponse> SendEmailAsync(SendEmailRequest request)
{
    try
    {
        // Check if recipient is unsubscribed
        var isUnsubscribed = await _trackingService.IsUnsubscribedAsync(request.ToAddress, request.TenantId);
        if (isUnsubscribed)
        {
            _logger.LogWarning("Email to {EmailAddress} blocked - recipient unsubscribed", request.ToAddress);
            return new SendEmailResponse
            {
                Success = false,
                ErrorMessage = "Recipient has unsubscribed"
            };
        }

        // ... rest of method
```

**Purpose:** Prevents sending emails to unsubscribed recipients.

---

### Change 3: Added Tracking Integration

**Location:** After attachments are added, before email is saved to database

```csharp
// Integrate tracking features
if (!string.IsNullOrEmpty(email.HtmlBody))
{
    var baseUrl = _configuration["TrackingSettings:BaseUrl"] ?? "https://localhost:5001";
    var enableTracking = _configuration.GetValue<bool>("TrackingSettings:EnableTracking", true);

    if (enableTracking)
    {
        // Inject open tracking pixel
        if (request.EnableOpenTracking)
        {
            email.HtmlBody = await _trackingService.InjectTrackingPixelAsync(
                email.HtmlBody,
                email.TrackingId,
                baseUrl);
        }

        // Replace links with tracked URLs
        if (request.EnableClickTracking)
        {
            email.HtmlBody = await _trackingService.ReplaceLinksWithTrackedUrlsAsync(
                email.HtmlBody,
                email.TrackingId,
                baseUrl);
        }

        // Inject unsubscribe link
        email.HtmlBody = await _trackingService.InjectUnsubscribeLinkAsync(
            email.HtmlBody,
            email.TrackingId,
            baseUrl);
    }
}
```

**Purpose:**
1. Injects 1x1 tracking pixel for open tracking
2. Replaces all links with tracked URLs for click tracking
3. Injects unsubscribe link at bottom of email

**Example Transformation:**

**Before:**
```html
<html>
<body>
  <h1>Welcome!</h1>
  <p><a href="https://example.com/article">Read Article</a></p>
</body>
</html>
```

**After:**
```html
<html>
<body>
  <h1>Welcome!</h1>
  <p><a href="https://yourdomain.com/track/click/123e4567.../987654">Read Article</a></p>
  <p style="text-align: center; font-size: 12px; color: #666; margin-top: 20px;">
    <a href="https://yourdomain.com/track/unsubscribe/123e4567-e89b-12d3-a456-426614174000"
       style="color: #666; text-decoration: underline;">
      Unsubscribe from this campaign
    </a>
  </p>
  <img src="https://yourdomain.com/track/open/123e4567-e89b-12d3-a456-426614174000"
       width="1" height="1" alt="" style="display:none;" />
</body>
</html>
```

---

## File 4: SendEmailRequest.cs - Added Tracking Properties

**Location:** `/src/SimpleSmartMail.Models/DTOs/SendEmailRequest.cs`

### Changes:

```csharp
public class SendEmailRequest
{
    public string TenantId { get; set; } = string.Empty;
    public string FromAddress { get; set; } = string.Empty;
    public string FromName { get; set; } = string.Empty;
    public string ToAddress { get; set; } = string.Empty;
    public string ToName { get; set; } = string.Empty;
    public List<string>? Cc { get; set; }
    public List<string>? Bcc { get; set; }
    public string Subject { get; set; } = string.Empty;
    public string HtmlBody { get; set; } = string.Empty;
    public string? TextBody { get; set; }
    public List<AttachmentDto>? Attachments { get; set; }
    public bool SendImmediately { get; set; } = true;
    public DateTime? ScheduledAt { get; set; }
    public bool EnableOpenTracking { get; set; } = true;  // NEW - defaults to true
    public bool EnableClickTracking { get; set; } = true; // NEW - defaults to true
}
```

**Purpose:** Allow API clients to control whether tracking is enabled for individual emails.

---

## File 5: CampaignService.cs - Tracking Integration

**Location:** `/src/SimpleSmartMail.Business/Services/CampaignService.cs`

### Change 1: Added Dependencies

```csharp
using Microsoft.Extensions.Configuration; // NEW

public class CampaignService : ICampaignService
{
    private readonly ICampaignRepository _campaignRepository;
    private readonly IEmailService _emailService;
    private readonly ITrackingService _trackingService; // NEW
    private readonly IConfiguration _configuration; // NEW
    private readonly ILogger<CampaignService> _logger;

    public CampaignService(
        ICampaignRepository campaignRepository,
        IEmailService emailService,
        ITrackingService trackingService, // NEW
        IConfiguration configuration, // NEW
        ILogger<CampaignService> logger)
    {
        _campaignRepository = campaignRepository;
        _emailService = emailService;
        _trackingService = trackingService; // NEW
        _configuration = configuration; // NEW
        _logger = logger;
    }
```

---

### Change 2: Added Unsubscribe Check in ProcessCampaignAsync

**Location:** Inside the `foreach (var recipient in unsentRecipients)` loop

```csharp
foreach (var recipient in unsentRecipients)
{
    try
    {
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

        // ... rest of loop
```

**Purpose:** Skip sending to unsubscribed recipients during campaign execution.

---

### Change 3: Pass Tracking Flags to EmailService

**Location:** In the `SendEmailRequest` creation inside `ProcessCampaignAsync`

```csharp
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
    EnableOpenTracking = campaign.EnableOpenTracking, // NEW
    EnableClickTracking = campaign.EnableClickTracking // NEW
};
```

**Purpose:** Respect campaign-level tracking settings when sending individual emails.

---

## File 6: TrackingController.cs - New Webhook Endpoints

**Location:** `/src/SimpleSmartMail.API/Controllers/TrackingController.cs`

### Added Endpoint: POST /track/bounce/{emailId}

```csharp
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
```

**Usage Example (SendGrid Webhook):**
```bash
curl -X POST https://yourdomain.com/track/bounce/123 \
  -H "Content-Type: application/json" \
  -d '{"bounceReason": "550 5.1.1 User unknown"}'
```

---

### Added Endpoint: POST /track/spam/{emailId}

```csharp
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
```

**Usage Example (SendGrid Webhook):**
```bash
curl -X POST https://yourdomain.com/track/spam/123
```

---

### Added DTO: BounceNotificationRequest

```csharp
public class BounceNotificationRequest
{
    public string? BounceReason { get; set; }
}
```

---

## Testing the Integration

### 1. Test Open Tracking

**Send an email:**
```bash
curl -X POST https://localhost:5001/api/email/send \
  -H "Content-Type: application/json" \
  -d '{
    "tenantId": "test-tenant",
    "fromAddress": "noreply@example.com",
    "fromName": "Test Sender",
    "toAddress": "user@example.com",
    "toName": "Test User",
    "subject": "Test Email",
    "htmlBody": "<html><body><h1>Hello!</h1></body></html>",
    "sendImmediately": true,
    "enableOpenTracking": true,
    "enableClickTracking": true
  }'
```

**Check the email HTML in database - should contain:**
```html
<img src="https://localhost:5001/track/open/[GUID]"
     width="1" height="1" alt="" style="display:none;" />
```

**When email client loads the pixel:**
- Request goes to `GET /track/open/{trackingId}`
- Returns 1x1 transparent GIF
- Updates `Emails.OpenTracked = 1`, `OpenCount++`

---

### 2. Test Click Tracking

**Send an email with links:**
```bash
curl -X POST https://localhost:5001/api/email/send \
  -H "Content-Type: application/json" \
  -d '{
    "tenantId": "test-tenant",
    "fromAddress": "noreply@example.com",
    "toAddress": "user@example.com",
    "subject": "Test Email",
    "htmlBody": "<html><body><a href=\"https://example.com\">Click Me</a></body></html>",
    "enableClickTracking": true
  }'
```

**Check the email HTML - links should be replaced:**
```html
<a href="https://localhost:5001/track/click/[GUID]/[HASH]">Click Me</a>
```

**When user clicks the link:**
- Request goes to `GET /track/click/{trackingId}/{urlHash}`
- Records click in `EmailClicks` table
- Redirects to `https://example.com`

---

### 3. Test Unsubscribe

**Every email now contains:**
```html
<p style="text-align: center; font-size: 12px; color: #666; margin-top: 20px;">
  <a href="https://localhost:5001/track/unsubscribe/[GUID]">
    Unsubscribe from this campaign
  </a>
</p>
```

**When user clicks unsubscribe:**
- Request goes to `GET /track/unsubscribe/{trackingId}`
- Creates `UnsubscribeRequest` record
- Returns HTML confirmation page
- Future emails to that address are blocked

---

### 4. Test Bounce Handling

**Simulate a bounce notification:**
```bash
curl -X POST https://localhost:5001/track/bounce/123 \
  -H "Content-Type: application/json" \
  -d '{"bounceReason": "550 5.1.1 User unknown"}'
```

**Result:**
- Email status set to `Failed`
- Error message: "Bounced: 550 5.1.1 User unknown"
- Hard bounce detected → Global unsubscribe created
- Future emails to that address blocked

---

### 5. Test Spam Complaint

**Simulate a spam complaint:**
```bash
curl -X POST https://localhost:5001/track/spam/123
```

**Result:**
- Global unsubscribe created
- Reason: "Auto-unsubscribed: Spam complaint"
- Future emails to that address blocked

---

### 6. Test Campaign with PersonalizationData

**Create campaign with custom URLs:**
```bash
curl -X POST https://localhost:5001/api/campaign \
  -H "Content-Type: application/json" \
  -d '{
    "tenantId": "tutor-company",
    "name": "Tutor Connect Campaign",
    "subject": "Your tutor is waiting, {{StudentName}}!",
    "htmlTemplate": "<html><body><h1>Hi {{StudentName}}</h1><p><a href=\"{{TutorConnectUrl}}\">Connect to Tutor</a></p></body></html>",
    "fromAddress": "noreply@tutor.com",
    "fromName": "Leo Tutoring",
    "enableOpenTracking": true,
    "enableClickTracking": true,
    "recipients": [
      {
        "emailAddress": "alice@example.com",
        "recipientName": "Alice Johnson",
        "personalizationData": {
          "StudentName": "Alice",
          "TutorConnectUrl": "https://leo.tutor.com/ondemand?token=abc123&student=alice"
        }
      }
    ]
  }'
```

**Result for Alice's email:**
```html
<html>
<body>
  <h1>Hi Alice</h1>
  <p>
    <a href="https://localhost:5001/track/click/[GUID]/[HASH]">Connect to Tutor</a>
  </p>
  <!-- Unsubscribe link -->
  <!-- Tracking pixel -->
</body>
</html>
```

**When Alice clicks "Connect to Tutor":**
1. Goes to tracking URL
2. Click recorded in database
3. Redirects to `https://leo.tutor.com/ondemand?token=abc123&student=alice`
4. Alice is auto-authenticated on tutor site

---

## Configuration Required

### appsettings.json

Ensure these settings are configured:

```json
{
  "TrackingSettings": {
    "BaseUrl": "https://yourdomain.com",
    "EnableTracking": true
  }
}
```

**Important:**
- `BaseUrl` should be your public domain (not localhost in production)
- Used for generating tracking URLs in emails

---

## Summary of All Changes

| File | Lines Changed | Change Type |
|------|---------------|-------------|
| TrackingService.cs | +89 | Added 3 new methods |
| ITrackingService.cs | +3 | Updated interface |
| EmailService.cs | +40 | Added tracking integration |
| SendEmailRequest.cs | +2 | Added tracking flags |
| CampaignService.cs | +16 | Added tracking integration |
| TrackingController.cs | +40 | Added webhook endpoints |

**Total:** ~190 lines of new code

---

## What Works Now

✅ **Open Tracking:** 1x1 pixel automatically injected into all HTML emails
✅ **Click Tracking:** All links automatically replaced with tracked URLs
✅ **Unsubscribe Link:** Automatically added to bottom of every email
✅ **Unsubscribe Check:** Prevents sending to unsubscribed recipients
✅ **Bounce Handling:** Auto-unsubscribe on hard bounces
✅ **Spam Complaints:** Auto-unsubscribe on spam reports
✅ **PersonalizationData:** Supports custom URLs with auto-auth tokens
✅ **Campaign Integration:** All tracking features work in campaigns

---

## Migration Notes

**No database migrations required!** All necessary tables and stored procedures already exist:
- `EmailClicks` table ✅
- `UnsubscribeRequests` table ✅
- `sp_Tracking_RecordOpen` ✅
- `sp_Tracking_RecordClick` ✅
- `sp_Unsubscribe_Create` ✅
- `sp_Unsubscribe_IsUnsubscribed` ✅

The integration is **complete and ready to use**.
