# Tracking and Unsubscribe Integration Guide

## Overview

This document explains the tracking and unsubscribe features in SimpleSmartMail, addressing:
1. Unsubscribe functionality for bounced/spam emails
2. Custom URL links via PersonalizationData (e.g., "Connect to Tutor" with auto-auth)
3. Email open tracking integration
4. Click tracking mechanism

---

## 1. Unsubscribe Feature Implementation

### Current Status

**Unsubscribe Infrastructure:** ✅ Complete
- `UnsubscribeRequest` entity exists
- `sp_Unsubscribe_Create`, `sp_Unsubscribe_IsUnsubscribed` stored procedures exist
- `TrackingController.Unsubscribe()` endpoint exists at `GET /track/unsubscribe/{trackingId}`

**Missing Integration:** ❌ Not Integrated
- Unsubscribe link NOT automatically added to email HTML
- Bounce/spam handling NOT implemented
- Unsubscribe check NOT enforced before sending

### What Needs to Be Added

#### 1.1 Automatic Unsubscribe Link Injection

**Method in TrackingService:**
```csharp
public Task<string> InjectUnsubscribeLinkAsync(string htmlBody, Guid trackingId, string baseUrl)
{
    var unsubscribeUrl = $"{baseUrl}/track/unsubscribe/{trackingId}";
    var unsubscribeLink = $"<p style=\"text-align: center; font-size: 12px; color: #666; margin-top: 20px;\">" +
                         $"<a href=\"{unsubscribeUrl}\" style=\"color: #666; text-decoration: underline;\">Unsubscribe from this campaign</a>" +
                         $"</p>";

    // Insert before </body> tag or append at end
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

**Example Email HTML Before:**
```html
<html>
<body>
<h1>Welcome!</h1>
<p>This is your email content.</p>
</body>
</html>
```

**Example Email HTML After:**
```html
<html>
<body>
<h1>Welcome!</h1>
<p>This is your email content.</p>
<p style="text-align: center; font-size: 12px; color: #666; margin-top: 20px;">
  <a href="https://yourdomain.com/track/unsubscribe/123e4567-e89b-12d3-a456-426614174000"
     style="color: #666; text-decoration: underline;">
    Unsubscribe from this campaign
  </a>
</p>
</body>
</html>
```

#### 1.2 Bounce and Spam Handling

**Add to EmailService:**
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

    _logger.LogWarning("Spam complaint received for email {EmailId} to {EmailAddress}",
                       emailId, email.ToAddress);
}

private bool IsHardBounce(string bounceReason)
{
    var hardBounceIndicators = new[]
    {
        "invalid", "not exist", "unknown user", "mailbox not found",
        "no such user", "user unknown", "permanent failure"
    };

    return hardBounceIndicators.Any(indicator =>
        bounceReason.Contains(indicator, StringComparison.OrdinalIgnoreCase));
}
```

#### 1.3 Unsubscribe Check Before Sending

**Add to EmailService.SendEmailAsync:**
```csharp
public async Task<SendEmailResponse> SendEmailAsync(SendEmailRequest request)
{
    // Check if recipient is unsubscribed
    var isUnsubscribed = await _trackingRepository.IsUnsubscribedAsync(
        request.TenantId,
        request.ToAddress,
        request.CampaignId);

    if (isUnsubscribed)
    {
        _logger.LogWarning("Email to {EmailAddress} blocked - recipient unsubscribed",
                          request.ToAddress);
        return new SendEmailResponse
        {
            Success = false,
            ErrorMessage = "Recipient has unsubscribed"
        };
    }

    // ... rest of sending logic
}
```

**Add stored procedure:**
```sql
CREATE PROCEDURE [dbo].[sp_Unsubscribe_IsUnsubscribed]
    @TenantId NVARCHAR(50),
    @EmailAddress NVARCHAR(255),
    @CampaignId INT = NULL
AS
BEGIN
    -- Check for global unsubscribe
    IF EXISTS (
        SELECT 1 FROM UnsubscribeRequests
        WHERE TenantId = @TenantId
        AND EmailAddress = @EmailAddress
        AND GlobalUnsubscribe = 1
    )
    BEGIN
        SELECT CAST(1 AS BIT) AS IsUnsubscribed;
        RETURN;
    END

    -- Check for campaign-specific unsubscribe
    IF @CampaignId IS NOT NULL
    BEGIN
        IF EXISTS (
            SELECT 1 FROM UnsubscribeRequests ur
            INNER JOIN Emails e ON e.TrackingId = ur.TrackingId
            WHERE ur.TenantId = @TenantId
            AND ur.EmailAddress = @EmailAddress
            AND e.CampaignId = @CampaignId
            AND ur.GlobalUnsubscribe = 0
        )
        BEGIN
            SELECT CAST(1 AS BIT) AS IsUnsubscribed;
            RETURN;
        END
    END

    SELECT CAST(0 AS BIT) AS IsUnsubscribed;
END
```

---

## 2. Custom URL Links via PersonalizationData

### How It Works

PersonalizationData is a `Dictionary<string, string>` that supports ANY custom data, including URLs.

### Example: "Connect to Tutor" Link with Auto-Auth

**Campaign Creation Request:**
```json
{
  "tenantId": "tutor-company",
  "name": "Weekly Tutoring Reminders",
  "subject": "Your tutor is waiting, {{StudentName}}!",
  "htmlTemplate": "<html><body><h1>Hi {{StudentName}},</h1><p>Your next session is ready!</p><p><a href='{{TutorConnectUrl}}'>Connect to Tutor Now</a></p></body></html>",
  "recipients": [
    {
      "emailAddress": "student1@example.com",
      "recipientName": "Alice Johnson",
      "personalizationData": {
        "StudentName": "Alice",
        "TutorConnectUrl": "https://leo.tutor.com/ondemand?token=abc123&session=456&student=alice"
      }
    },
    {
      "emailAddress": "student2@example.com",
      "recipientName": "Bob Smith",
      "personalizationData": {
        "StudentName": "Bob",
        "TutorConnectUrl": "https://leo.tutor.com/ondemand?token=xyz789&session=789&student=bob"
      }
    }
  ]
}
```

**How Tokens Are Replaced:**

The `CampaignService.ProcessCampaignAsync()` method replaces `{{TokenName}}` with values from PersonalizationData:

```csharp
if (!string.IsNullOrEmpty(recipient.PersonalizationData))
{
    var personalizationDict = JsonSerializer.Deserialize<Dictionary<string, string>>(
        recipient.PersonalizationData);

    foreach (var kvp in personalizationDict)
    {
        // Replace {{StudentName}} → "Alice"
        // Replace {{TutorConnectUrl}} → "https://leo.tutor.com/ondemand?token=abc123..."
        htmlBody = htmlBody.Replace($"{{{{{kvp.Key}}}}}", kvp.Value);
        subject = subject.Replace($"{{{{{kvp.Key}}}}}", kvp.Value);
    }
}
```

**Result for Alice:**
```html
<html>
<body>
  <h1>Hi Alice,</h1>
  <p>Your next session is ready!</p>
  <p>
    <a href='https://leo.tutor.com/ondemand?token=abc123&session=456&student=alice'>
      Connect to Tutor Now
    </a>
  </p>
</body>
</html>
```

### Implementation Strategy for Auto-Auth

**Option 1: Generate Tokens Server-Side (Recommended)**

Add to `CampaignService.CreateCampaignAsync()`:

```csharp
// Before creating campaign, enhance PersonalizationData with auto-auth URLs
foreach (var recipient in request.Recipients)
{
    if (recipient.PersonalizationData == null)
        recipient.PersonalizationData = new Dictionary<string, string>();

    // Generate JWT or session token for auto-login
    var authToken = await _authService.GenerateAutoLoginTokenAsync(
        tenantId: request.TenantId,
        emailAddress: recipient.EmailAddress,
        expiresIn: TimeSpan.FromHours(24)
    );

    // Add to personalization data
    recipient.PersonalizationData["TutorConnectUrl"] =
        $"https://leo.tutor.com/ondemand?token={authToken}";
}
```

**Option 2: Client Provides Pre-Generated URLs**

Client application generates tokens and includes them in the campaign creation request (as shown in JSON example above).

---

## 3. Email Open Tracking Integration

### Current Status

**Infrastructure:** ✅ Complete
- `TrackingService.InjectTrackingPixelAsync()` method exists
- `TrackingController.TrackOpen()` endpoint exists at `GET /track/open/{trackingId}`
- Returns 1x1 transparent GIF
- Records open event in database

**Missing Integration:** ❌ Not Called
- `InjectTrackingPixelAsync()` is NEVER called in `EmailService`
- `InjectTrackingPixelAsync()` is NEVER called in `CampaignService`

### How Open Tracking Works

#### Step 1: Tracking Pixel Injection

**When email is sent, this method SHOULD be called but ISN'T:**

```csharp
// In TrackingService.cs
public Task<string> InjectTrackingPixelAsync(string htmlBody, Guid trackingId, string baseUrl)
{
    var trackingPixel = $"<img src=\"{baseUrl}/track/open/{trackingId}\" " +
                       $"width=\"1\" height=\"1\" alt=\"\" style=\"display:none;\" />";

    // Insert before </body> tag
    if (htmlBody.Contains("</body>", StringComparison.OrdinalIgnoreCase))
    {
        htmlBody = Regex.Replace(htmlBody, "</body>",
                                $"{trackingPixel}</body>",
                                RegexOptions.IgnoreCase);
    }
    else
    {
        htmlBody += trackingPixel;
    }

    return Task.FromResult(htmlBody);
}
```

#### Step 2: Email HTML Before and After

**Original HTML Template:**
```html
<html>
<body>
  <h1>Welcome to SimpleSmartMail!</h1>
  <p>This is your email content.</p>
</body>
</html>
```

**After InjectTrackingPixelAsync (what SHOULD happen):**
```html
<html>
<body>
  <h1>Welcome to SimpleSmartMail!</h1>
  <p>This is your email content.</p>
  <img src="https://yourdomain.com/track/open/123e4567-e89b-12d3-a456-426614174000"
       width="1" height="1" alt="" style="display:none;" />
</body>
</html>
```

#### Step 3: When User Opens Email

1. Email client (Gmail, Outlook, etc.) renders HTML
2. Email client loads the 1x1 pixel image from `https://yourdomain.com/track/open/{trackingId}`
3. Request hits `TrackingController.TrackOpen()`
4. Controller records IP, user agent, timestamp
5. Updates `Emails` table: `OpenTracked = 1`, `OpenCount++`, `OpenedAt = Now`
6. Returns transparent GIF (so email displays correctly)

#### Step 4: Where Integration Is Missing

**In EmailService.cs - NEEDS TO BE ADDED:**
```csharp
public async Task<SendEmailResponse> SendEmailAsync(SendEmailRequest request)
{
    // ... create email record ...

    // ⚠️ THIS IS MISSING - NEEDS TO BE ADDED
    if (request.EnableOpenTracking)
    {
        var baseUrl = _configuration["TrackingSettings:BaseUrl"];
        email.HtmlBody = await _trackingService.InjectTrackingPixelAsync(
            email.HtmlBody,
            email.TrackingId,
            baseUrl);
    }

    // ... send email ...
}
```

**In CampaignService.cs - NEEDS TO BE ADDED:**
```csharp
private async Task ProcessCampaignAsync(EmailCampaign campaign)
{
    foreach (var recipient in unsentRecipients)
    {
        // Apply personalization...

        // ⚠️ THIS IS MISSING - NEEDS TO BE ADDED
        if (campaign.EnableOpenTracking)
        {
            var baseUrl = _configuration["TrackingSettings:BaseUrl"];
            htmlBody = await _trackingService.InjectTrackingPixelAsync(
                htmlBody,
                trackingId,
                baseUrl);
        }

        // Send email...
    }
}
```

---

## 4. Click Tracking Mechanism

### Current Status

**Infrastructure:** ✅ Complete
- `TrackingService.ReplaceLinksWithTrackedUrlsAsync()` method exists
- `TrackingController.TrackClick()` endpoint exists at `GET /track/click/{trackingId}/{urlHash}`
- Redirects to original URL after recording click

**Missing Integration:** ❌ Not Called
- `ReplaceLinksWithTrackedUrlsAsync()` is NEVER called in `EmailService`
- `ReplaceLinksWithTrackedUrlsAsync()` is NEVER called in `CampaignService`

### How Click Tracking Works

#### Step 1: Link Replacement

**When email is sent, this method SHOULD be called but ISN'T:**

```csharp
// In TrackingService.cs
public Task<string> ReplaceLinksWithTrackedUrlsAsync(string htmlBody, Guid trackingId, string baseUrl)
{
    var linkPattern = @"<a\s+(?:[^>]*?\s+)?href\s*=\s*[""']([^""']+)[""']([^>]*)>";

    htmlBody = Regex.Replace(htmlBody, linkPattern, match =>
    {
        var originalUrl = match.Groups[1].Value;

        // Don't track tracking URLs (avoid recursion)
        if (originalUrl.Contains("/track/") || originalUrl.Contains("/unsubscribe/"))
        {
            return match.Value;
        }

        // Create hash of URL
        var urlHash = Math.Abs(originalUrl.GetHashCode()).ToString();

        // Generate tracked URL
        var trackedUrl = $"{baseUrl}/track/click/{trackingId}/{urlHash}";

        // Store mapping for later retrieval
        var key = $"{trackingId}_{urlHash}";
        if (!_trackedUrls.ContainsKey(key))
        {
            _trackedUrls[key] = originalUrl;
        }

        // Replace with tracked URL
        return $"<a href=\"{trackedUrl}\"{match.Groups[2].Value}>";
    }, RegexOptions.IgnoreCase);

    return Task.FromResult(htmlBody);
}
```

#### Step 2: HTML Before and After

**Original HTML:**
```html
<html>
<body>
  <h1>Check out these resources!</h1>
  <p><a href="https://example.com/article1">Read Article 1</a></p>
  <p><a href="https://example.com/article2" target="_blank">Read Article 2</a></p>
  <p><a href="https://yourdomain.com/track/unsubscribe/123">Unsubscribe</a></p>
</body>
</html>
```

**After ReplaceLinksWithTrackedUrlsAsync:**
```html
<html>
<body>
  <h1>Check out these resources!</h1>
  <p><a href="https://yourdomain.com/track/click/123e4567-e89b-12d3-a456-426614174000/987654321">Read Article 1</a></p>
  <p><a href="https://yourdomain.com/track/click/123e4567-e89b-12d3-a456-426614174000/123456789" target="_blank">Read Article 2</a></p>
  <p><a href="https://yourdomain.com/track/unsubscribe/123">Unsubscribe</a></p>
</body>
</html>
```

**Notice:**
- Original links are replaced with tracked URLs containing `trackingId` and `urlHash`
- Unsubscribe link is NOT modified (to avoid recursion)
- Link attributes like `target="_blank"` are preserved

#### Step 3: When User Clicks Link

1. User clicks "Read Article 1"
2. Browser navigates to `https://yourdomain.com/track/click/123e4567.../987654321`
3. Request hits `TrackingController.TrackClick(trackingId, urlHash)`
4. Controller looks up original URL using `TrackingService.GetOriginalUrlAsync()`
5. Controller records click event: IP, user agent, timestamp, URL
6. Inserts into `EmailClicks` table
7. Updates `Emails.ClickCount++`
8. Returns `Redirect(originalUrl)` → user lands on `https://example.com/article1`

#### Step 4: URL Mapping Storage

**TrackingService maintains in-memory cache:**
```csharp
private readonly ConcurrentDictionary<string, string> _trackedUrls = new();

// When replacing links:
_trackedUrls[$"{trackingId}_{urlHash}"] = "https://example.com/article1";

// When retrieving:
public Task<string> GetOriginalUrlAsync(Guid trackingId, string urlHash)
{
    var key = $"{trackingId}_{urlHash}";
    _trackedUrls.TryGetValue(key, out var originalUrl);
    return Task.FromResult(originalUrl ?? string.Empty);
}
```

**⚠️ ISSUE:** This in-memory cache is lost on app restart!

**Better Approach:** Store URL mappings in database

```sql
CREATE TABLE [dbo].[TrackedUrls] (
    [Id] INT IDENTITY(1,1) PRIMARY KEY,
    [TrackingId] UNIQUEIDENTIFIER NOT NULL,
    [UrlHash] NVARCHAR(50) NOT NULL,
    [OriginalUrl] NVARCHAR(MAX) NOT NULL,
    INDEX IX_TrackedUrls_Lookup (TrackingId, UrlHash)
);

CREATE PROCEDURE [dbo].[sp_TrackedUrl_Create]
    @TrackingId UNIQUEIDENTIFIER,
    @UrlHash NVARCHAR(50),
    @OriginalUrl NVARCHAR(MAX)
AS
BEGIN
    IF NOT EXISTS (SELECT 1 FROM TrackedUrls WHERE TrackingId = @TrackingId AND UrlHash = @UrlHash)
    BEGIN
        INSERT INTO TrackedUrls (TrackingId, UrlHash, OriginalUrl)
        VALUES (@TrackingId, @UrlHash, @OriginalUrl);
    END
END

CREATE PROCEDURE [dbo].[sp_TrackedUrl_GetOriginal]
    @TrackingId UNIQUEIDENTIFIER,
    @UrlHash NVARCHAR(50)
AS
BEGIN
    SELECT OriginalUrl FROM TrackedUrls
    WHERE TrackingId = @TrackingId AND UrlHash = @UrlHash;
END
```

#### Step 5: Where Integration Is Missing

**In EmailService.cs - NEEDS TO BE ADDED:**
```csharp
public async Task<SendEmailResponse> SendEmailAsync(SendEmailRequest request)
{
    // ... create email record ...

    // ⚠️ THIS IS MISSING - NEEDS TO BE ADDED
    if (request.EnableClickTracking)
    {
        var baseUrl = _configuration["TrackingSettings:BaseUrl"];
        email.HtmlBody = await _trackingService.ReplaceLinksWithTrackedUrlsAsync(
            email.HtmlBody,
            email.TrackingId,
            baseUrl);
    }

    // ... send email ...
}
```

**In CampaignService.cs - NEEDS TO BE ADDED:**
```csharp
private async Task ProcessCampaignAsync(EmailCampaign campaign)
{
    foreach (var recipient in unsentRecipients)
    {
        // Apply personalization...

        // ⚠️ THIS IS MISSING - NEEDS TO BE ADDED
        if (campaign.EnableClickTracking)
        {
            var baseUrl = _configuration["TrackingSettings:BaseUrl"];
            htmlBody = await _trackingService.ReplaceLinksWithTrackedUrlsAsync(
                htmlBody,
                trackingId,
                baseUrl);
        }

        // Send email...
    }
}
```

---

## Summary: What's Implemented vs What Needs Integration

### ✅ Fully Implemented
- All tracking database tables and stored procedures
- TrackingService with all methods
- TrackingController with all endpoints
- UnsubscribeRequest infrastructure

### ❌ Missing Integration (Needs Code Changes)

| Feature | Method Exists | Called in EmailService | Called in CampaignService |
|---------|---------------|------------------------|---------------------------|
| Open Tracking Pixel | ✅ Yes | ❌ No | ❌ No |
| Click Tracking URLs | ✅ Yes | ❌ No | ❌ No |
| Unsubscribe Link | ❌ No | ❌ No | ❌ No |
| Unsubscribe Check | ✅ Partial | ❌ No | ❌ No |
| Bounce Handling | ❌ No | ❌ No | N/A |
| Spam Handling | ❌ No | ❌ No | N/A |

### Required Code Changes

See next section for complete implementation files with all integrations.
