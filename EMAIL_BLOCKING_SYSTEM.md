# Email Blocking System - How It Works

## Overview

SimpleSmartMail has **3 layers of protection** to prevent emails from being sent to unsubscribed, bounced, or spam-complained recipients.

---

## Protection Mechanisms

### ✅ Layer 1: Unsubscribe Check (EmailService)

**Location:** `EmailService.SendEmailAsync()` - Lines 43-53

**Code:**
```csharp
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
```

**What it does:**
- Checks EVERY individual email send request
- Blocks email if recipient is globally unsubscribed
- Returns error message instead of sending
- Logs warning for audit trail

---

### ✅ Layer 2: Campaign Recipient Check (CampaignService)

**Location:** `CampaignService.ProcessCampaignAsync()` - Lines 196-208

**Code:**
```csharp
// Check if recipient is unsubscribed
var isUnsubscribed = await _trackingService.IsUnsubscribedAsync(recipient.EmailAddress, campaign.TenantId);
if (isUnsubscribed)
{
    _logger.LogInformation("Skipping unsubscribed recipient {EmailAddress} for campaign {CampaignId}",
        recipient.EmailAddress, campaign.Id);

    recipient.Sent = false;
    await _campaignRepository.UpdateRecipientAsync(recipient);
    emailsFailed++;
    continue; // Skip this recipient
}
```

**What it does:**
- Checks EACH recipient before sending campaign emails
- Skips unsubscribed recipients (continues to next recipient)
- Marks recipient as not sent in database
- Increments failed count for reporting

---

### ✅ Layer 3: Database Check (Stored Procedure)

**Location:** `database/scripts/05_TrackingTablesAndProcedures.sql` - Lines 428-440

**Code:**
```sql
CREATE PROCEDURE [dbo].[sp_Unsubscribe_IsUnsubscribed]
    @EmailAddress NVARCHAR(255),
    @TenantId NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT COUNT(*) AS IsUnsubscribed
    FROM UnsubscribeRequests
    WHERE EmailAddress = @EmailAddress
      AND TenantId = @TenantId
      AND GlobalUnsubscribe = 1;
END
```

**What it does:**
- Queries UnsubscribeRequests table
- Returns count of matching records (0 = OK to send, >0 = blocked)
- Only checks global unsubscribes (strongest protection)
- Tenant isolation (only checks within same tenant)

---

## How Recipients Get Unsubscribed

### 1. Manual Unsubscribe (User Clicks Link)

**Flow:**
1. User receives email with unsubscribe link at bottom
2. User clicks: `https://yourdomain.com/track/unsubscribe/{trackingId}`
3. `TrackingController.Unsubscribe()` is called
4. Creates `UnsubscribeRequest` with `GlobalUnsubscribe = false` (campaign-specific)
5. Email added to unsubscribe list

**Code (TrackingController.cs):**
```csharp
[HttpGet("unsubscribe/{trackingId}")]
public async Task<IActionResult> Unsubscribe(Guid trackingId, [FromQuery] string? reason = null)
{
    var request = new UnsubscribeRequest
    {
        TrackingId = trackingId,
        Reason = reason,
        GlobalUnsubscribe = false // Campaign-specific by default
    };

    await _trackingService.AddUnsubscribeRequestAsync(request);

    return Content("You've Been Unsubscribed", "text/html");
}
```

**Note:** Currently set to `GlobalUnsubscribe = false`, but the stored procedure only checks for `GlobalUnsubscribe = 1`. This means manual unsubscribes won't currently block emails!

**ISSUE IDENTIFIED:** Need to fix this! See "Issues & Fixes" section below.

---

### 2. Automatic Unsubscribe (Hard Bounce)

**Flow:**
1. Email provider (SendGrid/SMTP) sends bounce notification
2. Webhook hits: `POST /track/bounce/{emailId}`
3. `TrackingService.HandleBounceAsync()` is called
4. If hard bounce detected → creates `UnsubscribeRequest` with `GlobalUnsubscribe = true`
5. Recipient globally blocked from all future emails

**Code (TrackingService.cs):**
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
            GlobalUnsubscribe = true, // ✅ Global block!
            UnsubscribedAt = DateTime.UtcNow
        };

        await _trackingRepository.AddUnsubscribeRequestAsync(unsubscribeRequest);
    }
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
```

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

### 3. Automatic Unsubscribe (Spam Complaint)

**Flow:**
1. Recipient marks email as spam in their email client
2. Email provider sends spam complaint notification
3. Webhook hits: `POST /track/spam/{emailId}`
4. `TrackingService.HandleSpamComplaintAsync()` is called
5. Creates `UnsubscribeRequest` with `GlobalUnsubscribe = true`
6. Recipient globally blocked from ALL future emails (no exceptions)

**Code (TrackingService.cs):**
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
        GlobalUnsubscribe = true, // ✅ Always global for spam!
        UnsubscribedAt = DateTime.UtcNow
    };

    await _trackingRepository.AddUnsubscribeRequestAsync(unsubscribeRequest);
}
```

**Note:** Spam complaints ALWAYS result in global unsubscribe (most severe action).

---

## Complete Email Sending Flow

### Individual Email Send

```
1. API Request → POST /api/email/send
2. EmailService.SendEmailAsync() called
3. ✅ Check: IsUnsubscribedAsync(toAddress, tenantId)
4. IF unsubscribed:
   - Return error "Recipient has unsubscribed"
   - Email NOT sent
   - END
5. IF OK:
   - Create email entity
   - Inject tracking pixel
   - Replace links with tracked URLs
   - Inject unsubscribe link
   - Send via SMTP/SendGrid
   - Update status
```

### Campaign Email Send

```
1. API Request → POST /api/campaign/{id}/start
2. CampaignService.StartCampaignAsync() called
3. ProcessCampaignAsync() starts in background
4. For EACH recipient:
   4a. ✅ Check: IsUnsubscribedAsync(emailAddress, tenantId)
   4b. IF unsubscribed:
       - Log "Skipping unsubscribed recipient"
       - Mark recipient.Sent = false
       - Continue to next recipient
   4c. IF OK:
       - Apply personalization
       - Send email via EmailService
       - (EmailService does another check!)
       - Mark recipient.Sent = true
5. Update campaign statistics
6. Mark campaign complete
```

---

## Webhook Integration (Email Provider → SimpleSmartMail)

### SendGrid Webhook Setup

**1. Configure SendGrid Webhook:**
- Go to SendGrid Dashboard → Settings → Mail Settings → Event Webhook
- Add webhook URL: `https://yourdomain.com/track/bounce/{emailId}`
- Enable events: Bounce, Spam Report

**2. SendGrid sends POST request when bounce occurs:**
```json
{
  "event": "bounce",
  "email": "user@example.com",
  "reason": "550 5.1.1 User unknown",
  "status": "5.1.1"
}
```

**3. Your code maps this to:**
```bash
POST /track/bounce/123
{
  "bounceReason": "550 5.1.1 User unknown"
}
```

**4. SimpleSmartMail:**
- Detects "User unknown" → hard bounce
- Creates global unsubscribe
- Future emails blocked

---

## Database Schema

### UnsubscribeRequests Table

```sql
CREATE TABLE [dbo].[UnsubscribeRequests] (
    [Id] INT IDENTITY(1,1) PRIMARY KEY,
    [TenantId] NVARCHAR(50) NOT NULL,
    [EmailAddress] NVARCHAR(255) NOT NULL,
    [TrackingId] UNIQUEIDENTIFIER NULL,
    [CampaignId] INT NULL,
    [EmailId] INT NULL,
    [Reason] NVARCHAR(500) NULL,
    [GlobalUnsubscribe] BIT NOT NULL DEFAULT 0,
    [UnsubscribedAt] DATETIME2 NOT NULL,
    [IpAddress] NVARCHAR(50) NULL,
    [UserAgent] NVARCHAR(MAX) NULL,
    INDEX IX_UnsubscribeRequests_Email (TenantId, EmailAddress)
);
```

**Key Fields:**
- `GlobalUnsubscribe` - 1 = blocked from ALL emails, 0 = campaign-specific
- `EmailAddress` + `TenantId` - Used for lookups
- `Reason` - Why they unsubscribed (audit trail)

---

## Issues & Fixes

### ⚠️ ISSUE: Manual Unsubscribe Not Blocking Emails

**Problem:**
- Manual unsubscribe sets `GlobalUnsubscribe = false`
- Stored procedure only checks for `GlobalUnsubscribe = 1`
- **Result:** Manual unsubscribes don't block emails!

**Fix Option 1: Make Manual Unsubscribes Global**

Change TrackingController.cs:
```csharp
var request = new UnsubscribeRequest
{
    TrackingId = trackingId,
    Reason = reason,
    GlobalUnsubscribe = true // ✅ Changed to true
};
```

**Fix Option 2: Update Stored Procedure to Check Both**

```sql
CREATE PROCEDURE [dbo].[sp_Unsubscribe_IsUnsubscribed]
    @EmailAddress NVARCHAR(255),
    @TenantId NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    -- Check for ANY unsubscribe (global OR campaign-specific)
    SELECT COUNT(*) AS IsUnsubscribed
    FROM UnsubscribeRequests
    WHERE EmailAddress = @EmailAddress
      AND TenantId = @TenantId; -- Removed GlobalUnsubscribe = 1 check
END
```

**Recommendation:** Use Option 1 (simpler, safer).

---

## Testing the Protection

### Test 1: Manual Unsubscribe

```bash
# 1. Send an email
curl -X POST https://localhost:5001/api/email/send \
  -d '{"toAddress": "test@example.com", ...}'

# 2. Click unsubscribe link in email
# Opens: https://localhost:5001/track/unsubscribe/{trackingId}

# 3. Try to send another email to same address
curl -X POST https://localhost:5001/api/email/send \
  -d '{"toAddress": "test@example.com", ...}'

# Expected (after fix): {"success": false, "errorMessage": "Recipient has unsubscribed"}
```

### Test 2: Hard Bounce Auto-Unsubscribe

```bash
# 1. Simulate bounce notification
curl -X POST https://localhost:5001/track/bounce/123 \
  -d '{"bounceReason": "550 5.1.1 User unknown"}'

# 2. Check database
SELECT * FROM UnsubscribeRequests WHERE EmailAddress = 'bounced@example.com';
# Should show: GlobalUnsubscribe = 1

# 3. Try to send email
curl -X POST https://localhost:5001/api/email/send \
  -d '{"toAddress": "bounced@example.com", ...}'

# Expected: {"success": false, "errorMessage": "Recipient has unsubscribed"}
```

### Test 3: Spam Complaint Auto-Unsubscribe

```bash
# 1. Simulate spam complaint
curl -X POST https://localhost:5001/track/spam/456

# 2. Check database
SELECT * FROM UnsubscribeRequests WHERE EmailId = 456;
# Should show: GlobalUnsubscribe = 1, Reason = "Auto-unsubscribed: Spam complaint"

# 3. Try to send email to that address
# Expected: Blocked
```

---

## Summary

### ✅ What's Protected

1. **Individual Emails** - Checked before every send
2. **Campaign Emails** - Checked for each recipient
3. **Hard Bounces** - Auto-unsubscribed globally
4. **Spam Complaints** - Auto-unsubscribed globally

### ⚠️ What Needs Fixing

1. **Manual Unsubscribes** - Currently don't block (need to set GlobalUnsubscribe = true)

### 🔧 Recommended Fix

Update `TrackingController.Unsubscribe()` to set `GlobalUnsubscribe = true` for all manual unsubscribes.

Would you like me to implement this fix?
