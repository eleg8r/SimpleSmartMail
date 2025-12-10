# Email Validation Implementation - All Code Changes

## Overview
This file contains ALL code changes needed to implement email validation with an `IsValid` column in the database.

---

## PART 1: Database Changes

### 1.1 Add IsValid Column to Emails Table

**File:** `database/scripts/02_EmailStoredProcedures.sql`

**Add after line creating Emails table (around line 20):**

```sql
-- Add IsValid column to Emails table
IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[Emails]') AND name = 'IsValid')
BEGIN
    ALTER TABLE [dbo].[Emails]
    ADD [IsValid] BIT NOT NULL DEFAULT 1;
END
GO

-- Add index for filtering invalid emails
CREATE NONCLUSTERED INDEX IX_Emails_IsValid
ON [dbo].[Emails] ([IsValid])
INCLUDE ([TenantId], [ToAddress], [Status]);
GO
```

### 1.2 Update sp_Email_Create to Include IsValid

**Replace existing sp_Email_Create with:**

```sql
CREATE PROCEDURE [dbo].[sp_Email_Create]
    @TenantId NVARCHAR(50),
    @FromAddress NVARCHAR(255),
    @FromName NVARCHAR(255),
    @ToAddress NVARCHAR(255),
    @ToName NVARCHAR(255),
    @Cc NVARCHAR(MAX) = NULL,
    @Bcc NVARCHAR(MAX) = NULL,
    @ReplyTo NVARCHAR(255) = NULL,
    @Subject NVARCHAR(500),
    @HtmlBody NVARCHAR(MAX),
    @TextBody NVARCHAR(MAX) = NULL,
    @Status INT,
    @TrackingId UNIQUEIDENTIFIER,
    @ScheduledAt DATETIME2 = NULL,
    @IsValid BIT = 1  -- NEW PARAMETER
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO Emails (
        TenantId, FromAddress, FromName, ToAddress, ToName, Cc, Bcc, ReplyTo,
        Subject, HtmlBody, TextBody, Status, TrackingId, ScheduledAt, IsValid, CreatedAt
    )
    VALUES (
        @TenantId, @FromAddress, @FromName, @ToAddress, @ToName, @Cc, @Bcc, @ReplyTo,
        @Subject, @HtmlBody, @TextBody, @Status, @TrackingId, @ScheduledAt, @IsValid, GETUTCDATE()
    );

    SELECT CAST(SCOPE_IDENTITY() AS INT) AS EmailId;
END
GO
```

### 1.3 Update sp_Email_Update to Include IsValid

**Replace existing sp_Email_Update with (add @IsValid parameter):**

```sql
CREATE PROCEDURE [dbo].[sp_Email_Update]
    @EmailId INT,
    @Status INT,
    @SentAt DATETIME2 = NULL,
    @OpenTracked BIT = NULL,
    @OpenedAt DATETIME2 = NULL,
    @OpenCount INT = NULL,
    @ClickTracked BIT = NULL,
    @FirstClickedAt DATETIME2 = NULL,
    @ClickCount INT = NULL,
    @ProviderUsed NVARCHAR(50) = NULL,
    @ErrorMessage NVARCHAR(MAX) = NULL,
    @RetryCount INT = NULL,
    @IsValid BIT = NULL  -- NEW PARAMETER
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE Emails
    SET
        Status = @Status,
        SentAt = COALESCE(@SentAt, SentAt),
        OpenTracked = COALESCE(@OpenTracked, OpenTracked),
        OpenedAt = COALESCE(@OpenedAt, OpenedAt),
        OpenCount = COALESCE(@OpenCount, OpenCount),
        ClickTracked = COALESCE(@ClickTracked, ClickTracked),
        FirstClickedAt = COALESCE(@FirstClickedAt, FirstClickedAt),
        ClickCount = COALESCE(@ClickCount, ClickCount),
        ProviderUsed = COALESCE(@ProviderUsed, ProviderUsed),
        ErrorMessage = COALESCE(@ErrorMessage, ErrorMessage),
        RetryCount = COALESCE(@RetryCount, RetryCount),
        IsValid = COALESCE(@IsValid, IsValid),  -- NEW LINE
        UpdatedAt = GETUTCDATE()
    WHERE Id = @EmailId;
END
GO
```

### 1.4 Add Stored Procedure to Get Invalid Emails

```sql
-- Get invalid emails for reporting
CREATE PROCEDURE [dbo].[sp_Email_GetInvalidByTenantId]
    @TenantId NVARCHAR(50),
    @PageNumber INT = 1,
    @PageSize INT = 50
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Offset INT = (@PageNumber - 1) * @PageSize;

    SELECT
        Id, TenantId, FromAddress, ToAddress, Subject, Status,
        ErrorMessage, CreatedAt, IsValid
    FROM Emails
    WHERE TenantId = @TenantId
      AND IsValid = 0
    ORDER BY CreatedAt DESC
    OFFSET @Offset ROWS
    FETCH NEXT @PageSize ROWS ONLY;
END
GO
```

---

## PART 2: Entity Changes

### 2.1 Update Email Entity

**File:** `src/SimpleSmartMail.Models/Entities/Email.cs`

**Add property (around line 35, after RetryCount):**

```csharp
public int RetryCount { get; set; }
public bool IsValid { get; set; } = true; // NEW PROPERTY - Email address validation status
public DateTime CreatedAt { get; set; }
```

---

## PART 3: DTO Changes (Add Data Annotations)

### 3.1 Update SendEmailRequest

**File:** `src/SimpleSmartMail.Models/DTOs/SendEmailRequest.cs`

**Replace entire file with:**

```csharp
using System.ComponentModel.DataAnnotations;

namespace SimpleSmartMail.Models.DTOs;

public class SendEmailRequest
{
    [Required(ErrorMessage = "TenantId is required")]
    public string TenantId { get; set; } = string.Empty;

    [Required(ErrorMessage = "From address is required")]
    [EmailAddress(ErrorMessage = "Invalid from email address")]
    public string FromAddress { get; set; } = string.Empty;

    public string FromName { get; set; } = string.Empty;

    [Required(ErrorMessage = "To address is required")]
    [EmailAddress(ErrorMessage = "Invalid to email address")]
    public string ToAddress { get; set; } = string.Empty;

    public string ToName { get; set; } = string.Empty;
    public List<string>? Cc { get; set; }
    public List<string>? Bcc { get; set; }

    [Required(ErrorMessage = "Subject is required")]
    [MaxLength(500, ErrorMessage = "Subject cannot exceed 500 characters")]
    public string Subject { get; set; } = string.Empty;

    [Required(ErrorMessage = "Email body is required")]
    public string HtmlBody { get; set; } = string.Empty;

    public string? TextBody { get; set; }
    public List<AttachmentDto>? Attachments { get; set; }
    public bool SendImmediately { get; set; } = true;
    public DateTime? ScheduledAt { get; set; }
    public bool EnableOpenTracking { get; set; } = true;
    public bool EnableClickTracking { get; set; } = true;
}

public class AttachmentDto
{
    [Required]
    public string FileName { get; set; } = string.Empty;

    [Required]
    public string ContentType { get; set; } = string.Empty;

    [Required]
    public byte[] Content { get; set; } = Array.Empty<byte>();
}
```

### 3.2 Update CreateCampaignRequest

**File:** `src/SimpleSmartMail.Models/DTOs/CreateCampaignRequest.cs`

**Replace entire file with:**

```csharp
using System.ComponentModel.DataAnnotations;

namespace SimpleSmartMail.Models.DTOs;

public class CreateCampaignRequest
{
    [Required]
    public string TenantId { get; set; } = string.Empty;

    [Required]
    [MaxLength(200)]
    public string Name { get; set; } = string.Empty;

    public string Description { get; set; } = string.Empty;

    [Required]
    [EmailAddress]
    public string FromAddress { get; set; } = string.Empty;

    [Required]
    public string FromName { get; set; } = string.Empty;

    [Required]
    [MaxLength(500)]
    public string Subject { get; set; } = string.Empty;

    [Required]
    public string HtmlTemplate { get; set; } = string.Empty;

    public string? TextTemplate { get; set; }
    public DateTime? ScheduledStartDate { get; set; }
    public int? BatchSize { get; set; }
    public int? MaxEmailsPerHour { get; set; }
    public bool EnableOpenTracking { get; set; } = true;
    public bool EnableClickTracking { get; set; } = true;
    public bool AutoGenerateAuthTokens { get; set; } = false;
    public string? AutoAuthBaseUrl { get; set; }
    public string? AutoAuthTokenKey { get; set; }

    [Required]
    [MinLength(1, ErrorMessage = "At least one recipient is required")]
    public List<CampaignRecipientDto> Recipients { get; set; } = new();

    public string CreatedBy { get; set; } = string.Empty;
}

public class CampaignRecipientDto
{
    [Required]
    [EmailAddress]
    public string EmailAddress { get; set; } = string.Empty;

    public string? RecipientName { get; set; }
    public string? UserId { get; set; }
    public Dictionary<string, string>? PersonalizationData { get; set; }
}
```

---

## PART 4: Email Validation Service

### 4.1 Create IEmailValidationService Interface

**File:** `src/SimpleSmartMail.Business/Services/IEmailValidationService.cs` (NEW FILE)

```csharp
namespace SimpleSmartMail.Business.Services;

public interface IEmailValidationService
{
    /// <summary>
    /// Validates email address format and optionally checks domain
    /// </summary>
    Task<EmailValidationResult> ValidateEmailAsync(string emailAddress, bool checkDomain = false);

    /// <summary>
    /// Validates multiple email addresses
    /// </summary>
    Task<Dictionary<string, EmailValidationResult>> ValidateEmailsAsync(IEnumerable<string> emailAddresses, bool checkDomain = false);
}

public class EmailValidationResult
{
    public bool IsValid { get; set; }
    public string EmailAddress { get; set; } = string.Empty;
    public List<string> Errors { get; set; } = new();
    public string? ValidationLevel { get; set; } // "Format", "Domain", "MX"

    public static EmailValidationResult Valid(string email, string level = "Format")
    {
        return new EmailValidationResult
        {
            IsValid = true,
            EmailAddress = email,
            ValidationLevel = level
        };
    }

    public static EmailValidationResult Invalid(string email, params string[] errors)
    {
        return new EmailValidationResult
        {
            IsValid = false,
            EmailAddress = email,
            Errors = errors.ToList()
        };
    }
}
```

### 4.2 Create EmailValidationService Implementation

**File:** `src/SimpleSmartMail.Business/Services/EmailValidationService.cs` (NEW FILE)

```csharp
using System.Net;
using System.Net.Mail;
using System.Text.RegularExpressions;
using Microsoft.Extensions.Logging;

namespace SimpleSmartMail.Business.Services;

public class EmailValidationService : IEmailValidationService
{
    private readonly ILogger<EmailValidationService> _logger;

    // RFC 5322 compliant email regex (simplified)
    private static readonly Regex EmailRegex = new Regex(
        @"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$",
        RegexOptions.Compiled | RegexOptions.IgnoreCase);

    public EmailValidationService(ILogger<EmailValidationService> logger)
    {
        _logger = logger;
    }

    public async Task<EmailValidationResult> ValidateEmailAsync(string emailAddress, bool checkDomain = false)
    {
        if (string.IsNullOrWhiteSpace(emailAddress))
        {
            return EmailValidationResult.Invalid(emailAddress, "Email address is required");
        }

        // Trim whitespace
        emailAddress = emailAddress.Trim();

        // 1. Basic format validation
        var formatValidation = ValidateFormat(emailAddress);
        if (!formatValidation.IsValid)
        {
            return formatValidation;
        }

        // 2. Domain validation (if enabled)
        if (checkDomain)
        {
            var domainValidation = await ValidateDomainAsync(emailAddress);
            if (!domainValidation.IsValid)
            {
                return domainValidation;
            }
        }

        return EmailValidationResult.Valid(emailAddress, checkDomain ? "Domain" : "Format");
    }

    public async Task<Dictionary<string, EmailValidationResult>> ValidateEmailsAsync(
        IEnumerable<string> emailAddresses,
        bool checkDomain = false)
    {
        var results = new Dictionary<string, EmailValidationResult>();

        foreach (var email in emailAddresses)
        {
            var result = await ValidateEmailAsync(email, checkDomain);
            results[email] = result;
        }

        return results;
    }

    private EmailValidationResult ValidateFormat(string emailAddress)
    {
        var errors = new List<string>();

        // Check length
        if (emailAddress.Length > 254)
        {
            errors.Add("Email address exceeds maximum length of 254 characters");
        }

        // Check for @ symbol
        if (!emailAddress.Contains('@'))
        {
            errors.Add("Email address must contain @ symbol");
        }
        else
        {
            var parts = emailAddress.Split('@');
            if (parts.Length != 2)
            {
                errors.Add("Email address must contain exactly one @ symbol");
            }
            else
            {
                var localPart = parts[0];
                var domainPart = parts[1];

                // Validate local part (before @)
                if (string.IsNullOrEmpty(localPart))
                {
                    errors.Add("Email address local part cannot be empty");
                }
                else if (localPart.Length > 64)
                {
                    errors.Add("Email address local part exceeds maximum length of 64 characters");
                }
                else if (localPart.StartsWith(".") || localPart.EndsWith("."))
                {
                    errors.Add("Email address local part cannot start or end with a dot");
                }
                else if (localPart.Contains(".."))
                {
                    errors.Add("Email address local part cannot contain consecutive dots");
                }

                // Validate domain part (after @)
                if (string.IsNullOrEmpty(domainPart))
                {
                    errors.Add("Email address domain cannot be empty");
                }
                else if (domainPart.Length > 253)
                {
                    errors.Add("Email address domain exceeds maximum length of 253 characters");
                }
                else if (domainPart.StartsWith("-") || domainPart.EndsWith("-"))
                {
                    errors.Add("Email address domain cannot start or end with hyphen");
                }
                else if (!domainPart.Contains('.'))
                {
                    errors.Add("Email address domain must contain at least one dot");
                }
            }
        }

        // Regex validation
        if (!EmailRegex.IsMatch(emailAddress))
        {
            errors.Add("Email address contains invalid characters");
        }

        // Try MailAddress constructor
        try
        {
            var mailAddress = new MailAddress(emailAddress);
            if (mailAddress.Address != emailAddress)
            {
                errors.Add("Email address format is invalid");
            }
        }
        catch (FormatException ex)
        {
            errors.Add($"Invalid email format: {ex.Message}");
        }

        if (errors.Any())
        {
            return EmailValidationResult.Invalid(emailAddress, errors.ToArray());
        }

        return EmailValidationResult.Valid(emailAddress, "Format");
    }

    private async Task<EmailValidationResult> ValidateDomainAsync(string emailAddress)
    {
        try
        {
            var domain = emailAddress.Split('@')[1];

            // Check if domain resolves
            var hostEntry = await Dns.GetHostEntryAsync(domain);

            if (hostEntry == null || hostEntry.AddressList.Length == 0)
            {
                return EmailValidationResult.Invalid(emailAddress, "Domain does not resolve to any IP address");
            }

            return EmailValidationResult.Valid(emailAddress, "Domain");
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Domain validation failed for {Email}", emailAddress);
            return EmailValidationResult.Invalid(emailAddress, $"Domain validation failed: {ex.Message}");
        }
    }
}
```

---

## PART 5: Update EmailService

**File:** `src/SimpleSmartMail.Business/Services/EmailService.cs`

**Add IEmailValidationService dependency:**

```csharp
public class EmailService : IEmailService
{
    private readonly IEmailRepository _emailRepository;
    private readonly ITrackingService _trackingService;
    private readonly IEmailValidationService _emailValidationService; // NEW
    private readonly IConfiguration _configuration;
    private readonly ILogger<EmailService> _logger;
    private readonly Dictionary<EmailProviderType, IEmailProvider> _emailProviders;

    public EmailService(
        IEmailRepository emailRepository,
        ITrackingService trackingService,
        IEmailValidationService emailValidationService, // NEW
        IConfiguration configuration,
        ILogger<EmailService> logger,
        SmtpEmailProvider smtpProvider,
        SendGridEmailProvider sendGridProvider)
    {
        _emailRepository = emailRepository;
        _trackingService = trackingService;
        _emailValidationService = emailValidationService; // NEW
        _configuration = configuration;
        _logger = logger;

        _emailProviders = new Dictionary<EmailProviderType, IEmailProvider>
        {
            { EmailProviderType.Smtp, smtpProvider },
            { EmailProviderType.SendGrid, sendGridProvider }
        };
    }
```

**Update SendEmailAsync method (add validation BEFORE unsubscribe check):**

```csharp
public async Task<SendEmailResponse> SendEmailAsync(SendEmailRequest request)
{
    try
    {
        // ===== NEW: Validate email addresses =====
        var validationErrors = new List<string>();

        // Validate To address
        var toValidation = await _emailValidationService.ValidateEmailAsync(request.ToAddress);
        if (!toValidation.IsValid)
        {
            validationErrors.Add($"To: {string.Join(", ", toValidation.Errors)}");
        }

        // Validate From address
        var fromValidation = await _emailValidationService.ValidateEmailAsync(request.FromAddress);
        if (!fromValidation.IsValid)
        {
            validationErrors.Add($"From: {string.Join(", ", fromValidation.Errors)}");
        }

        // Validate CC addresses
        if (request.Cc != null && request.Cc.Any())
        {
            foreach (var cc in request.Cc)
            {
                var ccValidation = await _emailValidationService.ValidateEmailAsync(cc);
                if (!ccValidation.IsValid)
                {
                    validationErrors.Add($"CC ({cc}): {string.Join(", ", ccValidation.Errors)}");
                }
            }
        }

        // Validate BCC addresses
        if (request.Bcc != null && request.Bcc.Any())
        {
            foreach (var bcc in request.Bcc)
            {
                var bccValidation = await _emailValidationService.ValidateEmailAsync(bcc);
                if (!bccValidation.IsValid)
                {
                    validationErrors.Add($"BCC ({bcc}): {string.Join(", ", bccValidation.Errors)}");
                }
            }
        }

        // If validation failed, return error
        if (validationErrors.Any())
        {
            _logger.LogWarning("Email validation failed: {Errors}", string.Join("; ", validationErrors));
            return new SendEmailResponse
            {
                Success = false,
                ErrorMessage = $"Email validation failed: {string.Join("; ", validationErrors)}"
            };
        }
        // ===== END NEW VALIDATION =====

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
            IsValid = true, // NEW - Set to true since we validated above
            CreatedAt = DateTime.UtcNow
        };

        // ... rest of method continues unchanged
```

---

## PART 6: Update CampaignService

**File:** `src/SimpleSmartMail.Business/Services/CampaignService.cs`

**Add IEmailValidationService dependency:**

```csharp
public class CampaignService : ICampaignService
{
    private readonly ICampaignRepository _campaignRepository;
    private readonly IEmailService _emailService;
    private readonly ITrackingService _trackingService;
    private readonly IAutoAuthTokenService _autoAuthTokenService;
    private readonly IEmailValidationService _emailValidationService; // NEW
    private readonly IConfiguration _configuration;
    private readonly ILogger<CampaignService> _logger;

    public CampaignService(
        ICampaignRepository campaignRepository,
        IEmailService emailService,
        ITrackingService trackingService,
        IAutoAuthTokenService autoAuthTokenService,
        IEmailValidationService emailValidationService, // NEW
        IConfiguration configuration,
        ILogger<CampaignService> logger)
    {
        _campaignRepository = campaignRepository;
        _emailService = emailService;
        _trackingService = trackingService;
        _autoAuthTokenService = autoAuthTokenService;
        _emailValidationService = emailValidationService; // NEW
        _configuration = configuration;
        _logger = logger;
    }
```

**Update ProcessCampaignAsync (add validation in the recipient loop):**

```csharp
foreach (var recipient in unsentRecipients)
{
    try
    {
        // ===== NEW: Validate recipient email address =====
        var validation = await _emailValidationService.ValidateEmailAsync(recipient.EmailAddress);
        if (!validation.IsValid)
        {
            _logger.LogWarning("Invalid email address for recipient {Email}: {Errors}",
                recipient.EmailAddress,
                string.Join(", ", validation.Errors));

            recipient.Sent = false;
            await _campaignRepository.UpdateRecipientAsync(recipient);
            emailsFailed++;
            continue; // Skip this recipient
        }
        // ===== END NEW VALIDATION =====

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

        // ... rest of processing continues
```

---

## PART 7: Update EmailRepository

**File:** `src/SimpleSmartMail.Data/Repositories/EmailRepository.cs`

**Update CreateAsync to include IsValid:**

```csharp
public async Task<int> CreateAsync(Email email)
{
    var parameters = new[]
    {
        new SqlParameter("@TenantId", email.TenantId),
        new SqlParameter("@FromAddress", email.FromAddress),
        new SqlParameter("@FromName", email.FromName ?? string.Empty),
        new SqlParameter("@ToAddress", email.ToAddress),
        new SqlParameter("@ToName", email.ToName ?? string.Empty),
        new SqlParameter("@Cc", (object?)email.Cc ?? DBNull.Value),
        new SqlParameter("@Bcc", (object?)email.Bcc ?? DBNull.Value),
        new SqlParameter("@ReplyTo", (object?)email.ReplyTo ?? DBNull.Value),
        new SqlParameter("@Subject", email.Subject),
        new SqlParameter("@HtmlBody", email.HtmlBody ?? string.Empty),
        new SqlParameter("@TextBody", (object?)email.TextBody ?? DBNull.Value),
        new SqlParameter("@Status", (int)email.Status),
        new SqlParameter("@TrackingId", email.TrackingId),
        new SqlParameter("@ScheduledAt", (object?)email.ScheduledAt ?? DBNull.Value),
        new SqlParameter("@IsValid", email.IsValid) // NEW PARAMETER
    };

    var emailId = await ExecuteScalarAsync<int>("sp_Email_Create", parameters);
    return emailId;
}
```

**Update UpdateAsync to include IsValid:**

```csharp
public async Task UpdateAsync(Email email)
{
    var parameters = new[]
    {
        new SqlParameter("@EmailId", email.Id),
        new SqlParameter("@Status", (int)email.Status),
        new SqlParameter("@SentAt", (object?)email.SentAt ?? DBNull.Value),
        new SqlParameter("@OpenTracked", email.OpenTracked),
        new SqlParameter("@OpenedAt", (object?)email.OpenedAt ?? DBNull.Value),
        new SqlParameter("@OpenCount", email.OpenCount),
        new SqlParameter("@ClickTracked", email.ClickTracked),
        new SqlParameter("@FirstClickedAt", (object?)email.FirstClickedAt ?? DBNull.Value),
        new SqlParameter("@ClickCount", email.ClickCount),
        new SqlParameter("@ProviderUsed", (object?)email.ProviderUsed ?? DBNull.Value),
        new SqlParameter("@ErrorMessage", (object?)email.ErrorMessage ?? DBNull.Value),
        new SqlParameter("@RetryCount", email.RetryCount),
        new SqlParameter("@IsValid", email.IsValid) // NEW PARAMETER
    };

    await ExecuteNonQueryAsync("sp_Email_Update", parameters);
}
```

---

## PART 8: Service Registration

**File:** `src/SimpleSmartMail.API/Program.cs`

**Add service registration:**

```csharp
// Register services
builder.Services.AddScoped<IEmailService, EmailService>();
builder.Services.AddScoped<IEmailTemplateService, EmailTemplateService>();
builder.Services.AddScoped<ICampaignService, CampaignService>();
builder.Services.AddScoped<ITrackingService, TrackingService>();
builder.Services.AddScoped<IAutoAuthTokenService, AutoAuthTokenService>();
builder.Services.AddScoped<IEmailValidationService, EmailValidationService>(); // NEW LINE
```

---

## PART 9: Configuration (Optional)

**File:** `src/SimpleSmartMail.API/appsettings.json`

**Add validation settings (optional):**

```json
{
  "EmailValidation": {
    "EnableDomainValidation": false,
    "EnableMxRecordValidation": false,
    "AllowedDomains": [],
    "BlockedDomains": ["tempmail.com", "throwaway.email"]
  }
}
```

---

## Summary of Changes

### Database (1 file):
1. ✅ Add `IsValid` BIT column to Emails table
2. ✅ Update `sp_Email_Create` to accept @IsValid
3. ✅ Update `sp_Email_Update` to accept @IsValid
4. ✅ Add `sp_Email_GetInvalidByTenantId` stored procedure
5. ✅ Add index on IsValid column

### Models (3 files):
1. ✅ Add `IsValid` property to Email entity
2. ✅ Add `[EmailAddress]` and `[Required]` attributes to SendEmailRequest
3. ✅ Add `[EmailAddress]` and `[Required]` attributes to CreateCampaignRequest

### Business Logic (4 files):
1. ✅ Create `IEmailValidationService` interface (NEW FILE)
2. ✅ Create `EmailValidationService` implementation (NEW FILE)
3. ✅ Update `EmailService` to validate before sending
4. ✅ Update `CampaignService` to validate recipients

### Data (1 file):
1. ✅ Update `EmailRepository.CreateAsync()` to include IsValid
2. ✅ Update `EmailRepository.UpdateAsync()` to include IsValid

### API (1 file):
1. ✅ Register `IEmailValidationService` in Program.cs

---

## Testing

### Test 1: Invalid Email Format
```bash
curl -X POST https://localhost:5001/api/email/send \
  -H "Content-Type: application/json" \
  -d '{
    "tenantId": "test",
    "fromAddress": "invalid-email",
    "toAddress": "test@example.com",
    "subject": "Test",
    "htmlBody": "<p>Test</p>"
  }'

# Expected: 400 Bad Request with validation error
```

### Test 2: Valid Email
```bash
curl -X POST https://localhost:5001/api/email/send \
  -H "Content-Type: application/json" \
  -d '{
    "tenantId": "test",
    "fromAddress": "sender@example.com",
    "toAddress": "recipient@example.com",
    "subject": "Test",
    "htmlBody": "<p>Test</p>"
  }'

# Expected: 200 OK, email sent, IsValid = 1 in database
```

### Test 3: Query Invalid Emails
```sql
SELECT * FROM Emails WHERE IsValid = 0;
```

---

## Validation Rules Implemented

✅ **Format Validation:**
- Email must contain exactly one @ symbol
- Local part (before @) max 64 characters
- Domain part (after @) max 253 characters
- Total length max 254 characters
- No consecutive dots in local part
- No leading/trailing dots in local part
- RFC 5322 compliant regex
- MailAddress constructor validation

✅ **Domain Validation (Optional):**
- Domain must resolve to IP address
- Can be enabled via `checkDomain` parameter

✅ **Database Tracking:**
- IsValid column tracks validation status
- Invalid emails stored but not sent
- Easy reporting via sp_Email_GetInvalidByTenantId

---

## Migration Steps

1. **Run database script** to add IsValid column
2. **Update all .cs files** as shown above
3. **Rebuild solution**
4. **Test with valid and invalid emails**
5. **Check database** for IsValid values
